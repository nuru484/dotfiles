# Reference: Data Lifecycle (exports, imports, account deletion & PII erasure)

Read this before building an export/download, a bulk import, or account
deletion. Three house patterns live here: the synchronous CSV stream, the
Task-with-status job pattern, and the PII erasure path. All of them ride the
existing conventions (typed pg-boss queue, CustomError subclasses, envelope,
signed uploads); nothing here introduces new infrastructure.

## Exports

Exports are for PEOPLE: human-readable columns, openable in Excel. The API
itself stays minor-units-and-ISO; the export layer is where formatting for
humans happens (see CSV rules below).

### Small exports (<= ~10k rows, seconds of work): synchronous stream

Stream straight from the query to the response with
`Content-Disposition: attachment` and `text/csv`. This is THE one sanctioned
non-envelope success response in the whole API (recorded in api-contracts);
the JSON list `limit` cap does not apply to export streams.

```ts
// controllers/donation/export-donations-controllers.ts
const handleExport = asyncHandler(async (req: Request, res: Response): Promise<void> => {
  const filters = req.query as unknown as IDonationExportFilters; // validated upstream
  const stamp = new Date().toISOString().slice(0, 10);
  res.setHeader("Content-Type", "text/csv; charset=utf-8");
  res.setHeader("Content-Disposition", `attachment; filename="donations-${stamp}.csv"`);
  res.write("\uFEFF"); // UTF-8 BOM so Excel detects the encoding
  await streamDonationsCsv(filters, res); // service writes RFC 4180 rows to the stream
  res.end();
});
```

The service reads in batches (`findMany` with `skip`/`take` or keyset) so
memory stays flat, and escapes every field per RFC 4180:

```ts
// utils/csv.ts - RFC 4180: quote when needed, double embedded quotes
export const csvField = (value: string | number | null | undefined): string => {
  const s = value == null ? "" : String(value);
  return /[",\r\n]/.test(s) ? `"${s.replaceAll('"', '""')}"` : s;
};
```

(Or use `csv-stringify`; either way, never hand-join naked values.)

### Large exports: pg-boss job + Task row (THE long-running-job pattern)

Anything beyond seconds of work becomes a queued job with a pollable task
row. This Task-with-status pattern is THE house convention for ALL
long-running user-visible jobs - imports, report generation, bulk operations,
not just exports. Same status enum, same 202 + poll, same progress column.
Never invent a per-feature job-status shape.

```prisma
enum TaskStatus {
  PENDING
  RUNNING
  DONE
  FAILED
}

model ExportTask {
  id        String     @id @default(cuid())
  userId    String                    // or orgId; whoever may poll and download
  type      String                    // "donations-csv", "audit-report", ...
  status    TaskStatus @default(PENDING)
  progress  Int        @default(0)    // 0-100; the job updates in coarse steps
  resultUrl String?                   // storage locator (e.g. Cloudinary raw publicId)
  error     String?                   // human-readable failure, set with FAILED
  createdAt DateTime   @default(now())
  updatedAt DateTime   @updatedAt

  @@index([userId, createdAt])
}
```

Flow:

1. `POST /exports` validates filters, creates the task row, enqueues
   `"exports.generate"` with `{ taskId }` (add it to `JobPayloads` +
   `JOB_NAMES` as usual), responds `202 { message: "Export started", data: task }`.
2. The job flips the row to `RUNNING`, streams the query in batches, writes
   CSV under the same rules, bumps `progress` per batch (never per row),
   uploads the finished file to Cloudinary as a `raw` asset (or the provider
   store the repo already uses), then sets `status: DONE` + `resultUrl`.
3. The client polls `GET /exports/:id` (normal `{ message, data }` envelope;
   the service asserts ownership). When `DONE`, the response carries a
   SHORT-LIVED signed download URL derived from `resultUrl` at read time
   (Cloudinary authenticated/private raw delivery or the store's signed URL),
   never a permanent public link.
4. Idempotent under re-delivery: a handler that finds `status: DONE` exits.
   On error it sets `FAILED` + `error` and rethrows so the house retry policy
   applies (a retry flips it back to `RUNNING`); after `retryLimit` the row
   stays `FAILED` and the poll surfaces the message.

## Imports

File bytes NEVER ride `express.json` - the global 100kb body cap is
deliberate (security-hardening). The client uploads the CSV through the
EXISTING signed-upload path (reference/media.md; a `documents`-style folder,
raw resource type), records the Media row, then starts the import:

1. `POST /imports` with a small JSON body `{ mediaId, type }` (normal path).
   Creates an `ImportTask` (same Task shape as above plus `report Json?`),
   enqueues `"imports.process"` with `{ taskId }`, responds
   `202 { message, data: task }`.
2. The job STREAMS the file from storage through `csv-parse` (never
   `readFileSync` on user files), validates EVERY row against the SAME Zod
   schemas the API endpoints use (one source of validation truth), and
   inserts valid rows in batches with `p-map` bounded concurrency.
3. It finishes with a per-row error report stored on the task:
   `report: [{ row: 17, field: "email", message: "Invalid email" }, ...]`.
   The poll endpoint returns it in the normal envelope so the UI can render
   "213 imported, 4 failed" with row-level detail.

```ts
// jobs/imports/process.job.ts (sketch)
import { parse } from "csv-parse";
import pMap from "p-map";

const BATCH_SIZE = 500;
// stream from storage -> parse({ columns: true, bom: true, trim: true })
// -> accumulate BATCH_SIZE rows -> per batch:
//      rows.map((row, i) => schema.safeParse(row))        // SAME Zod schema as the API
//      collect failures as { row: offset + i + 2, field, message } // +2: 1-based + header
//      await pMap(validChunks, insertChunk, { concurrency: 4 });
// -> bump progress per batch; write report + final status at the end
```

**Partial-success semantics, decided per domain invariant:** the default is
partial success - valid rows commit (batch by batch), invalid rows are
reported and skipped. When the domain demands atomicity (a ledger where half
an import is worse than none), run the whole import in one transaction and
fail it entirely while still reporting every row error. Decide per invariant,
record the choice, and never silently mix the two modes in one importer.

## CSV rules (both directions)

- **RFC 4180 quoting:** fields containing commas, quotes, or newlines are
  double-quoted; embedded quotes are doubled (`""`). Use `csv-stringify` /
  `csv-parse` (with `bom: true`) or the `csvField` helper; never split or
  join on bare commas.
- **UTF-8 BOM on exports** (`\uFEFF` first) so Excel renders accents and
  currency symbols correctly; accept and strip a BOM on import.
- **Dates are ISO:** `yyyy-mm-dd` for date-only columns, full ISO 8601 UTC
  for timestamps. Never locale formats (`03/04/2026` is ambiguous).
- **Money is decimal-with-currency columns for humans:** `amount` `245.00`
  plus `currency` `GHS`. Exports are for people; the API and DB stay integer
  minor units. Minor -> decimal conversion happens ONLY in the export layer;
  imports parse the decimal back to minor units at the validation boundary.

## Account deletion & PII erasure

The soft-delete convention (`deletedAt`) is for BUSINESS records - orders,
posts, donations - where "delete" means hide-and-keep. PERSONAL data is
different: a user-initiated account deletion gets a REAL erasure path.
Soft-deleting a User row erases nothing.

Flow:

1. **Request:** the user asks for deletion (re-authenticate first). Set
   `deletionRequestedAt` on the User, send a confirmation email via the
   queue, and enqueue `"users.erase"` with `startAfter` at the grace
   deadline.
2. **Grace period:** default 14 days, REVERSIBLE - cancelling clears
   `deletionRequestedAt`. The job re-checks the mark before scrubbing, so
   cancellation wins and re-delivery is a no-op.
3. **Hard scrub:** one erasure service does everything, so the PII column
   list lives in ONE place. Any model that grows a PII column gets it added
   here and nowhere else.

```ts
// services/users/erase-user.service.ts - THE one PII column list
import { randomBytes } from "node:crypto";

export const eraseUser = async (userId: string): Promise<void> => {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, deletionRequestedAt: true },
  });
  if (!user?.deletionRequestedAt) return; // cancelled or already erased: no-op

  // 1. Destroy media provider-side first (reference/media.md hardDeleteMedia:
  //    Cloudinary destroy + row delete; idempotent).
  const media = await prisma.media.findMany({
    where: { uploadedById: userId },
    select: { id: true },
  });
  for (const m of media) await hardDeleteMedia({ mediaId: m.id });

  await prisma.$transaction(async (tx) => {
    // 2. Anonymize the User row IN PLACE (FKs on retained rows stay valid).
    await tx.user.update({
      where: { id: userId },
      data: {
        email: `deleted+${userId}@invalid`, // frees the address; cannot receive mail
        fullName: "Deleted user",
        phone: null,
        passwordHash: await dummyPasswordHash(), // valid-but-unmatchable argon2 hash (raw hex would make verify() throw; see auth flows.md)
        deletionRequestedAt: null,
        erasedAt: new Date(),
      },
    });
    // 3. Revoke every credential: sessions, refresh/reset tokens, API keys.
    await tx.refreshToken.deleteMany({ where: { userId } });
    // 4. Null PII columns on RETAINED business rows; keep non-PII references.
    await tx.order.updateMany({
      where: { customerId: userId },
      data: { shippingAddress: null, contactPhone: null },
    });
    // ...every other model with PII columns, listed HERE and nowhere else
  });
};
```

Rules:

- **Anonymize in place, do not delete the User row:** business and audit rows
  keep a valid non-PII foreign key, and the anonymized row carries nothing
  personal.
- **Retention decision:** audit and financial records (payments, invoices,
  AuditLog) are NOT erased; they keep the opaque userId reference for the
  legally required retention window. Record that window (commonly ~6 years
  for financial records, jurisdiction-dependent) as an explicit
  app-blueprint-style assumption in the design doc.
- The whole path is idempotent: the `deletionRequestedAt` check plus
  in-place writes converge under job re-delivery.
- security-hardening's checklist carries the matching line: a PII erasure
  path must exist for user-initiated deletion.
