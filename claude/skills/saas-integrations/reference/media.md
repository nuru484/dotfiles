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
// Repos with CSV import (data-lifecycle.md) extend this list and the MIME
// mirror below with csv (resource_type "raw") for the imports folder only.
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
  // Media stores resourceType ("image" | "raw"); the API defaults to image,
  // so raw assets (CSV imports, generated exports) 404 without it.
  const resource = await cloudinary.api.resource(input.publicId, {
    resource_type: input.resourceType ?? "image",
  });
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

Why XMLHttpRequest and not `fetch` for the Cloudinary POST: `fetch` cannot
report upload progress, so on the flaky, low-bandwidth networks this file
already designs for (see Rendering), a multi-MB upload is indistinguishable
from a hang and users resubmit. `xhr.upload.onprogress` gives a real percent,
`xhr.abort()` gives cancel. Every security property is unchanged: signed
constrained params from our API, bytes go direct to Cloudinary, the server
re-verifies in `createMedia` before recording.

```ts
// frontend: hooks/use-upload.ts
"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  useCreateMediaMutation,
  useGetUploadSignatureMutation,
} from "@/redux/media-api";
import type { Media, UploadSignature } from "@/types/media.types";

/**
 * Client-side pre-validation MIRROR of the server constraints in
 * upload-signature.service.ts (ALLOWED_FORMATS, MAX_BYTES) - keep in sync.
 * Rejecting locally saves a signature round trip for a file Cloudinary would
 * refuse anyway. This is UX only; the signed upload preset stays the
 * security boundary.
 */
const ACCEPTED_MIME_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "application/pdf",
] as const;
const MAX_BYTES = 10 * 1024 * 1024;

/** Reuse signed params for retries while comfortably inside Cloudinary's ~1h window. */
const SIGNATURE_REUSE_MS = 45 * 60 * 1000;

export type UploadStatus = "queued" | "uploading" | "done" | "error" | "cancelled";

export interface UploadItem {
  id: string; // local queue id (crypto.randomUUID)
  file: File;
  /** Object URL for image previews (null for non-images). Revoked on unmount. */
  previewUrl: string | null;
  status: UploadStatus;
  progress: number; // 0-100, driven by xhr.upload.onprogress
  error: string | null;
  media: Media | null; // set on success; media.publicId feeds form state
}

interface CloudinaryUploadResult {
  public_id: string;
  format: string;
  width?: number;
  height?: number;
  bytes: number;
}

export const useUpload = (folder: string) => {
  const [items, setItems] = useState<UploadItem[]>([]);
  const [getSignature] = useGetUploadSignatureMutation();
  const [createMedia] = useCreateMediaMutation();

  const itemsRef = useRef<UploadItem[]>([]);
  const queueRef = useRef<UploadItem[]>([]);
  const xhrsRef = useRef(new Map<string, XMLHttpRequest>());
  const signatureRef = useRef<{ sig: UploadSignature; mintedAt: number } | null>(null);
  const drainingRef = useRef(false);

  useEffect(() => {
    itemsRef.current = items;
  }, [items]);

  const patch = useCallback((id: string, changes: Partial<UploadItem>) => {
    setItems((prev) => prev.map((it) => (it.id === id ? { ...it, ...changes } : it)));
  }, []);

  /** Retry-aware signature: reuse within the validity window, else re-sign. */
  const freshSignature = useCallback(async (): Promise<UploadSignature> => {
    const cached = signatureRef.current;
    if (cached && Date.now() - cached.mintedAt < SIGNATURE_REUSE_MS) return cached.sig;
    const sig = await getSignature({ folder }).unwrap();
    signatureRef.current = { sig, mintedAt: Date.now() };
    return sig;
  }, [folder, getSignature]);

  const postToCloudinary = useCallback(
    (item: UploadItem, sig: UploadSignature) =>
      new Promise<CloudinaryUploadResult>((resolve, reject) => {
        const xhr = new XMLHttpRequest(); // fetch cannot report upload progress
        xhrsRef.current.set(item.id, xhr);
        const settle = () => xhrsRef.current.delete(item.id);

        xhr.upload.onprogress = (e) => {
          if (e.lengthComputable) {
            patch(item.id, { progress: Math.round((e.loaded / e.total) * 100) });
          }
        };
        xhr.onload = () => {
          settle();
          if (xhr.status >= 200 && xhr.status < 300) {
            resolve(JSON.parse(xhr.responseText) as CloudinaryUploadResult);
          } else {
            reject(new Error(`Upload rejected (${xhr.status})`));
          }
        };
        xhr.onerror = () => {
          settle();
          reject(new Error("Network error during upload"));
        };
        xhr.onabort = () => {
          settle();
          reject(new DOMException("Upload cancelled", "AbortError"));
        };

        const form = new FormData();
        form.append("file", item.file);
        form.append("api_key", sig.apiKey);
        form.append("timestamp", String(sig.timestamp));
        form.append("signature", sig.signature);
        form.append("folder", sig.folder);
        form.append("allowed_formats", sig.allowedFormats);

        // Direct to Cloudinary: our API never sees the bytes.
        xhr.open("POST", `https://api.cloudinary.com/v1_1/${sig.cloudName}/auto/upload`);
        xhr.send(form);
      }),
    [patch],
  );

  const runItem = useCallback(
    async (item: UploadItem) => {
      patch(item.id, { status: "uploading", progress: 0, error: null });
      try {
        const sig = await freshSignature();
        const uploaded = await postToCloudinary(item, sig);
        // Record it in our DB (server re-verifies against Cloudinary).
        const media = await createMedia({
          publicId: uploaded.public_id,
          format: uploaded.format,
          width: uploaded.width,
          height: uploaded.height,
          bytes: uploaded.bytes,
        }).unwrap();
        patch(item.id, { status: "done", progress: 100, media });
      } catch (err) {
        if (err instanceof DOMException && err.name === "AbortError") {
          patch(item.id, { status: "cancelled", progress: 0 });
        } else {
          patch(item.id, {
            status: "error",
            error: err instanceof Error ? err.message : "Upload failed",
          });
        }
      }
    },
    [createMedia, freshSignature, patch, postToCloudinary],
  );

  /**
   * SEQUENTIAL by default: parallel uploads on a low-bandwidth link starve
   * each other and all look stalled. For a context known to be fast (an
   * internal admin tool), swap the loop for Promise.all over the queued items.
   */
  const drain = useCallback(async () => {
    if (drainingRef.current) return;
    drainingRef.current = true;
    let next = queueRef.current.shift();
    while (next) {
      await runItem(next);
      next = queueRef.current.shift();
    }
    drainingRef.current = false;
  }, [runItem]);

  const addFiles = useCallback(
    (files: FileList | File[]) => {
      const accepted: UploadItem[] = [];
      const invalid: UploadItem[] = [];
      for (const file of Array.from(files)) {
        const item: UploadItem = {
          id: crypto.randomUUID(),
          file,
          previewUrl: file.type.startsWith("image/") ? URL.createObjectURL(file) : null,
          status: "queued",
          progress: 0,
          error: null,
          media: null,
        };
        // Pre-validate type/size BEFORE any signature request (server mirror).
        if (!(ACCEPTED_MIME_TYPES as readonly string[]).includes(file.type)) {
          invalid.push({ ...item, status: "error", error: "File type not allowed" });
        } else if (file.size > MAX_BYTES) {
          invalid.push({ ...item, status: "error", error: "File exceeds 10 MB" });
        } else {
          accepted.push(item);
        }
      }
      setItems((prev) => [...prev, ...invalid, ...accepted]);
      queueRef.current.push(...accepted);
      void drain();
    },
    [drain],
  );

  /** AbortController-style cancel: abort the in-flight XHR, or unqueue. */
  const cancel = useCallback(
    (id: string) => {
      const xhr = xhrsRef.current.get(id);
      if (xhr) {
        xhr.abort(); // onabort marks the item cancelled
        return;
      }
      queueRef.current = queueRef.current.filter((it) => it.id !== id);
      patch(id, { status: "cancelled" });
    },
    [patch],
  );

  /** Per-file retry; freshSignature decides whether to reuse or re-sign. */
  const retry = useCallback(
    (id: string) => {
      const item = itemsRef.current.find((it) => it.id === id);
      if (!item || (item.status !== "error" && item.status !== "cancelled")) return;
      patch(id, { status: "queued", progress: 0, error: null });
      queueRef.current.push(item);
      void drain();
    },
    [drain, patch],
  );

  // Cleanup: abort in-flight uploads, revoke preview object URLs (they leak
  // memory until revoked or the document unloads).
  useEffect(() => {
    const xhrs = xhrsRef.current;
    return () => {
      for (const xhr of xhrs.values()) xhr.abort();
      for (const item of itemsRef.current) {
        if (item.previewUrl) URL.revokeObjectURL(item.previewUrl);
      }
    };
  }, []);

  const isUploading = items.some(
    (it) => it.status === "queued" || it.status === "uploading",
  );

  return { items, addFiles, cancel, retry, isUploading };
};
```

### FileUpload component

Renders the queue: image preview (from the object URL), per-file progress
bar, cancel while uploading, retry after failure. Generic, so it lives in
`components/shared/`.

```tsx
// frontend: components/shared/file-upload.tsx
"use client";

import { useRef } from "react";
import { Button } from "@/components/ui/button";
import type { UploadItem } from "@/hooks/use-upload";

interface FileUploadProps {
  items: UploadItem[];
  onFiles: (files: FileList) => void;
  onCancel: (id: string) => void;
  onRetry: (id: string) => void;
  accept?: string;
  multiple?: boolean;
}

export function FileUpload({
  items,
  onFiles,
  onCancel,
  onRetry,
  accept = "image/jpeg,image/png,image/webp,application/pdf",
  multiple = true,
}: FileUploadProps) {
  const inputRef = useRef<HTMLInputElement>(null);

  return (
    <div className="space-y-3">
      <input
        ref={inputRef}
        type="file"
        accept={accept}
        multiple={multiple}
        className="sr-only"
        onChange={(e) => {
          if (e.target.files?.length) onFiles(e.target.files);
          e.target.value = ""; // allow re-selecting the same file
        }}
      />
      <Button type="button" variant="outline" onClick={() => inputRef.current?.click()}>
        Choose {multiple ? "files" : "file"}
      </Button>

      {items.length > 0 ? (
        <ul className="space-y-2">
          {items.map((item) => (
            <li key={item.id} className="flex items-center gap-3 rounded-md border p-2">
              {item.previewUrl ? (
                // Local object URL: plain <img>; next/image loaders don't apply.
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={item.previewUrl}
                  alt=""
                  className="h-10 w-10 flex-none rounded object-cover"
                />
              ) : (
                <div className="h-10 w-10 flex-none rounded bg-muted" aria-hidden="true" />
              )}
              <div className="min-w-0 flex-1">
                <p className="min-w-0 line-clamp-1 whitespace-normal [overflow-wrap:anywhere] text-sm">
                  {item.file.name}
                </p>
                {item.status === "uploading" ? (
                  <div
                    role="progressbar"
                    aria-valuenow={item.progress}
                    aria-valuemin={0}
                    aria-valuemax={100}
                    aria-label={`Uploading ${item.file.name}`}
                    className="mt-1 h-1.5 w-full overflow-hidden rounded bg-muted"
                  >
                    <div
                      className="h-full bg-primary transition-[width]"
                      style={{ width: `${item.progress}%` }}
                    />
                  </div>
                ) : null}
                {item.status === "error" ? (
                  <p className="text-xs text-destructive" role="alert">
                    {item.error}
                  </p>
                ) : null}
              </div>
              {item.status === "queued" || item.status === "uploading" ? (
                <Button type="button" variant="ghost" size="sm" onClick={() => onCancel(item.id)}>
                  Cancel
                </Button>
              ) : null}
              {item.status === "error" || item.status === "cancelled" ? (
                <Button type="button" variant="ghost" size="sm" onClick={() => onRetry(item.id)}>
                  Retry
                </Button>
              ) : null}
              {item.status === "done" ? (
                <span className="text-xs text-muted-foreground">Uploaded</span>
              ) : null}
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  );
}
```

### react-hook-form integration

The upload feeds form state; the form never submits with an upload in flight.

```tsx
// frontend: inside the form component (react-hook-form + zodResolver)
const form = useForm<PostFormValues>({ resolver: zodResolver(postFormSchema) });
const { items, addFiles, cancel, retry, isUploading } = useUpload("posts");
const [createPost, { isLoading: isSubmitting }] = useCreatePostMutation();

// Upload completes -> publicId into form state (single-file field shown).
useEffect(() => {
  const done = items.find((it) => it.status === "done" && it.media);
  if (done?.media) {
    form.setValue("coverPublicId", done.media.publicId, {
      shouldValidate: true,
      shouldDirty: true,
    });
  }
}, [items, form]);

return (
  <form onSubmit={onSubmit}>
    {/* ...other fields... */}
    <FileUpload
      items={items}
      onFiles={addFiles}
      onCancel={cancel}
      onRetry={retry}
      multiple={false}
    />
    {/* Submit blocked while any upload is queued or in flight. */}
    <Button type="submit" disabled={isUploading || isSubmitting}>
      {isUploading ? "Uploading..." : "Publish"}
    </Button>
  </form>
);
```

Rules:

- The Zod schema requires the field (`coverPublicId: z.string().min(1,
  "Upload an image")`), so an unfinished upload blocks submit through
  validation as well as the disabled button.
- Uploaded but form abandoned: the user uploads, `createMedia` records the
  row, then they navigate away without submitting. Do NOT build client-side
  "delete on unmount" cleanup - it fires on flaky navigations and races the
  submit. The existing orphan-sweep job (Delete lifecycle below) handles
  these orphans.

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
  await cloudinary.uploader.destroy(media.publicId, {
    resource_type: media.resourceType ?? "image", // raw assets need it or destroy no-ops
  }); // idempotent on Cloudinary side
  await prisma.media.delete({ where: { id: media.id } });
};
```

```ts
// jobs/media/orphan-sweep.job.ts (scheduled weekly, see reference/email-jobs.md)
// 1. Media rows soft-deleted more than 30 days ago -> hardDeleteMedia (grace window over).
// 2. Cloudinary assets in our folders with no Media row (upload succeeded but
//    createMedia never ran) older than 24h -> uploader.destroy.
// 3. Media rows never attached to an owning entity (upload + createMedia ran,
//    but the form was abandoned before submit) older than 24h ->
//    softDeleteMedia; pass 1 hard-deletes them after the grace window.
// All passes are idempotent, so re-delivery is safe.
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
