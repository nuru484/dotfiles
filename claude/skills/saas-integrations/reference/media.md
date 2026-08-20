# Reference: Media (Cloudinary signed direct uploads)

Read this before writing any upload, image, or media-storage code. The rule:
file bytes go client -> Cloudinary directly; our API only signs, records, and
deletes. Express never proxies file bytes (no multer streaming to Cloudinary).

## ENV additions (config/env.ts)

```ts
export const ENV = {
  // ...existing vars
  CLOUDINARY_CLOUD_NAME: envRequired("CLOUDINARY_CLOUD_NAME"),
  CLOUDINARY_API_KEY: envRequired("CLOUDINARY_API_KEY"),
  CLOUDINARY_API_SECRET: envRequired("CLOUDINARY_API_SECRET"),
};
```

```ts
// lib/cloudinary.ts
import { v2 as cloudinary } from "cloudinary";
import { ENV } from "#config/env.js";

cloudinary.config({
  cloud_name: ENV.CLOUDINARY_CLOUD_NAME,
  api_key: ENV.CLOUDINARY_API_KEY,
  api_secret: ENV.CLOUDINARY_API_SECRET,
  secure: true,
});
export { cloudinary };
```

## Prisma model sketch

Store identity and intrinsics, never full URLs: URLs are derived at render time
so transforms (`f_auto,q_auto`, sizes) can change without a migration.

```prisma
model Media {
  id        String    @id @default(cuid())
  publicId  String    @unique          // Cloudinary public_id incl. folder
  format    String                     // "jpg", "webp", "pdf"
  width     Int?
  height    Int?
  bytes     Int
  uploadedById String
  uploadedBy   User   @relation(fields: [uploadedById], references: [id])
  // attach to owning entities as needed, e.g. postId String?
  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt
  deletedAt DateTime?                  // house soft delete
}
```

## Signature endpoint (authed, constrained)

The client asks us for signed params, then POSTs the file to Cloudinary itself.
Sign ONLY a constrained parameter set: folder, allowed formats, timestamp. An
unconstrained signature is an open upload endpoint on your cloud.

```ts
// services/media/upload-signature.service.ts
import { cloudinary } from "#lib/cloudinary.js";
import { ENV } from "#config/env.js";
import { BadRequestError } from "#utils/errors.js";

const ALLOWED_FOLDERS = ["avatars", "posts", "documents"] as const;
const ALLOWED_FORMATS = "jpg,png,webp,pdf";
const MAX_BYTES = 10 * 1024 * 1024; // 10 MB; also enforced by Cloudinary preset

interface SignatureInput {
  actorId: string;
  folder: (typeof ALLOWED_FOLDERS)[number]; // Zod-validated enum at the route
}

export const createUploadSignature = (input: SignatureInput) => {
  if (!ALLOWED_FOLDERS.includes(input.folder)) {
    throw new BadRequestError(`folder must be one of ${ALLOWED_FOLDERS.join(", ")}`);
  }
  const timestamp = Math.round(Date.now() / 1000); // signature valid ~1h (Cloudinary window)
  const paramsToSign = {
    timestamp,
    folder: input.folder,
    allowed_formats: ALLOWED_FORMATS,
    // pair with an upload preset that enforces max bytes server-side:
    // upload_preset: "signed_default",
  };
  const signature = cloudinary.utils.api_sign_request(paramsToSign, ENV.CLOUDINARY_API_SECRET);
  return {
    signature,
    timestamp,
    folder: input.folder,
    allowedFormats: ALLOWED_FORMATS,
    maxBytes: MAX_BYTES, // client pre-checks size before uploading
    apiKey: ENV.CLOUDINARY_API_KEY,
    cloudName: ENV.CLOUDINARY_CLOUD_NAME,
  };
};
```

Route: `POST /media/upload-signature`, behind auth middleware, Zod-validated
body `{ folder }`, responds `{ message: "Upload signature created", data }`.
Size enforcement note: `api_sign_request` cannot sign a byte cap directly;
create a signed upload preset in the Cloudinary console with the byte limit and
allowed formats, sign the `upload_preset` name, and keep the client-side
`maxBytes` check as UX, not security.

## Record the upload (after Cloudinary responds to the client)

```ts
// services/media/create-media.service.ts
interface CreateMediaInput {
  actorId: string;
  publicId: string;
  format: string;
  width?: number;
  height?: number;
  bytes: number;
}

export const createMedia = async (input: CreateMediaInput) => {
  // Trust check: confirm the asset really exists on our cloud before recording.
  const resource = await cloudinary.api.resource(input.publicId);
  return prisma.media.create({
    data: {
      publicId: input.publicId,
      format: resource.format,
      width: resource.width,
      height: resource.height,
      bytes: resource.bytes, // take truth from Cloudinary, not the client
      uploadedById: input.actorId,
    },
  });
};
```

## Client upload flow (RTK Query, Next.js)

Feature api files live at `redux/<feature>-api.ts` and inject into the ONE
`apiSlice` (house rule; see project-scaffold frontend-infra.md). Envelope
types are the house `IApiResponse<T>` from `types/api.ts`, never an invented
one.

```ts
// frontend: redux/media-api.ts
import { apiSlice } from "./api-slice";
import type { IApiResponse } from "@/types/api";
import type { CreateMediaBody, Media, UploadSignature } from "@/types/media.types";

export const mediaApi = apiSlice.injectEndpoints({
  endpoints: (build) => ({
    getUploadSignature: build.mutation<UploadSignature, { folder: string }>({
      query: (body) => ({ url: "/media/upload-signature", method: "POST", body }),
      transformResponse: (res: IApiResponse<UploadSignature>) => res.data,
    }),
    createMedia: build.mutation<Media, CreateMediaBody>({
      query: (body) => ({ url: "/media", method: "POST", body }),
      transformResponse: (res: IApiResponse<Media>) => res.data,
    }),
  }),
});

export const { useGetUploadSignatureMutation, useCreateMediaMutation } = mediaApi;
```

```ts
// frontend: hooks/use-upload.ts
import { useCreateMediaMutation, useGetUploadSignatureMutation } from "@/redux/media-api";

export const useUpload = () => {
  const [getSignature] = useGetUploadSignatureMutation();
  const [createMedia] = useCreateMediaMutation();

  return async (file: File, folder: string) => {
    const sig = await getSignature({ folder }).unwrap();
    if (file.size > sig.maxBytes) throw new Error("File too large");

    const form = new FormData();
    form.append("file", file);
    form.append("api_key", sig.apiKey);
    form.append("timestamp", String(sig.timestamp));
    form.append("signature", sig.signature);
    form.append("folder", sig.folder);
    form.append("allowed_formats", sig.allowedFormats);

    // Direct to Cloudinary: our API never sees the bytes.
    const res = await fetch(
      `https://api.cloudinary.com/v1_1/${sig.cloudName}/auto/upload`,
      { method: "POST", body: form },
    );
    if (!res.ok) throw new Error("Upload failed");
    const uploaded = (await res.json()) as {
      public_id: string; format: string; width?: number; height?: number; bytes: number;
    };

    // Record it in our DB (server re-verifies against Cloudinary).
    return createMedia({
      publicId: uploaded.public_id,
      format: uploaded.format,
      width: uploaded.width,
      height: uploaded.height,
      bytes: uploaded.bytes,
    }).unwrap();
  };
};
```

## Delete lifecycle

Soft delete follows the house rule; Cloudinary `destroy` happens only on hard
delete, plus a sweep for uploads that never got attached or whose rows are gone.

```ts
// services/media/delete-media.service.ts
export const softDeleteMedia = async (input: { actorId: string; mediaId: string }) => {
  const { count } = await prisma.media.updateMany({
    where: { id: input.mediaId, deletedAt: null },
    data: { deletedAt: new Date() },
  });
  if (count === 0) throw new NotFoundError("Media not found");
  // Asset stays on Cloudinary while soft-deleted: restore stays cheap.
};

export const hardDeleteMedia = async (input: { mediaId: string }) => {
  const media = await prisma.media.findUnique({ where: { id: input.mediaId } });
  if (!media) return; // idempotent
  await cloudinary.uploader.destroy(media.publicId); // idempotent on Cloudinary side
  await prisma.media.delete({ where: { id: media.id } });
};
```

```ts
// jobs/media/orphan-sweep.job.ts (scheduled weekly, see reference/email-jobs.md)
// 1. Media rows soft-deleted more than 30 days ago -> hardDeleteMedia (grace window over).
// 2. Cloudinary assets in our folders with no Media row (upload succeeded but
//    createMedia never ran) older than 24h -> uploader.destroy.
// Both passes are idempotent, so re-delivery is safe.
```

## Rendering (Next.js, next/image)

Never store or hardcode delivery URLs; derive with transforms at render time.
Never read `process.env` directly in components or lib code: add the cloud
name to the typed frontend env module (`PUBLIC_ENV` in `lib/env.ts`, see
project-scaffold frontend-infra.md 1) in repos that use media uploads, and
put `NEXT_PUBLIC_CLOUDINARY_CLOUD_NAME` in `.env.local` (see project-scaffold
local-dev.md).

```ts
// frontend: lib/env.ts (PUBLIC_ENV): add the cloud name entry
export const PUBLIC_ENV = {
  SERVER_URI: required("NEXT_PUBLIC_SERVER_URI", process.env.NEXT_PUBLIC_SERVER_URI),
  CLOUDINARY_CLOUD_NAME: required(
    "NEXT_PUBLIC_CLOUDINARY_CLOUD_NAME",
    process.env.NEXT_PUBLIC_CLOUDINARY_CLOUD_NAME,
  ),
} as const;
```

```ts
// frontend: lib/cloudinary-loader.ts
import type { ImageLoader } from "next/image";
import { PUBLIC_ENV } from "@/lib/env";

export const cloudinaryLoader: ImageLoader = ({ src, width, quality }) =>
  `https://res.cloudinary.com/${PUBLIC_ENV.CLOUDINARY_CLOUD_NAME}` +
  `/image/upload/f_auto,q_${quality ?? "auto"},w_${width},c_limit/${src}`;
// src is the stored publicId, e.g. "posts/abc123"
```

```tsx
<Image
  loader={cloudinaryLoader}
  src={media.publicId}
  alt={post.title}
  width={media.width ?? 1200}
  height={media.height ?? 800}
  sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 600px"
/>
```

`f_auto,q_auto` lets Cloudinary serve AVIF/WebP at tuned quality; a real
`sizes` attribute stops mobile phones downloading desktop-width images. Both
matter double on the low-bandwidth connections common in the user's markets.
