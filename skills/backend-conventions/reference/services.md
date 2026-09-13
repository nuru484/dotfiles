# Reference: Controllers, Services & Validation

Read this before writing a new endpoint or moving logic out of a controller.

## The shape of a feature

```
routes/donation/financial-donation-routes.ts   # thin router, auth at router level
controllers/donation/financial-donation-*.ts    # parse → call service → respond
services/financial-donation.service.ts           # writes (domain logic)
services/financial-donation-query.service.ts      # reads (list/get + filters)
validations/donation/financial-donation-validation.ts  # Zod schemas
types/donation/financial-donation.types.ts        # input + response types
```

## Route - thin, auth at the router level

```ts
import { Router } from "express";
import { createAdminDonation, getAllFinancialDonations } from "#controllers/donation/index.js";
import authenticateJWT from "#middlewares/authenticate-jwt.js";

const financialDonationRoutes = Router();

// Admin-only router. Public routes (provider init/webhook) live in a separate
// router that does NOT apply this middleware.
financialDonationRoutes.use(authenticateJWT);

financialDonationRoutes.post("/", ...createAdminDonation);
financialDonationRoutes.get("/", ...getAllFinancialDonations);

export default financialDonationRoutes;
```

## Controller - thin adapter, exports `RequestHandler[]`

```ts
const handleGetAll = asyncHandler(async (req: Request, res: Response): Promise<void> => {
  // Safe ONLY because validationMiddleware.query(financialDonationQueryValidation)
  // ran first and wrote the parsed result back to req.query; the assertion
  // restates what the middleware guarantees. Never use this cast on
  // unvalidated input.
  const filters = req.query as unknown as IFinancialDonationQueryFilters;
  const { data, total, page, limit, summary } = await listFinancialDonations(filters);
  res.status(HTTP_STATUS_CODES.OK).json({
    message: "Donations retrieved successfully",
    data,
    meta: buildMeta(total, page, limit), // shared helper - never inline Math.ceil
    summary,
  });
});

// Validation middleware + handler, spread into the route.
export const getAllFinancialDonations: RequestHandler[] = [
  ...validationMiddleware.query(financialDonationQueryValidation),
  handleGetAll,
];
```

Rules:
- Controller does **only**: read params/body, call a service, send the envelope.
- No Prisma, no `$transaction`, no Cloudinary, no domain branching here.
- Always `asyncHandler` so thrown errors reach the central handler.

## Service - pure, typed, framework-free

```ts
// Shared relation selection defined ONCE; the return type derives from it.
const donationInclude = {
  donor: { select: { id: true, fullName: true, phone: true, email: true } },
  campaign: { select: { id: true, title: true, slug: true, type: true } },
} as const;

type DonationWithRelations = Prisma.FinancialDonationGetPayload<{
  include: typeof donationInclude;
}>;

/** Records an admin-entered financial donation. */
export const createAdminDonation = async (
  input: IAdminDonationCreateInput,
  actorId: string | null,          // <- actor threaded in for audit
): Promise<DonationWithRelations> => {
  // ...domain rules, throwing typed errors...
  if (!donor) throw new NotFoundError("Donor not found");

  return prisma.financialDonation.create({
    data: { /* ... */ createdById: actorId },
    include: donationInclude,
  });
};
```

Rules:
- **Pure where possible**: inputs in → value out. No `req`, no globals beyond the
  imported `prisma`/`ENV`.
- **Dependency-injectable I/O**: a function that runs inside a transaction takes
  `tx: TransactionClient` as a parameter instead of importing the singleton - so
  it can be composed and tested. (See `transactions.md`.)
- **Mutations take `actorId`** and stamp `createdById`/`updatedById`.
- **Reads vs writes** split into `*.service.ts` and `*-query.service.ts`.
- **Narrow `select`** for existence checks: `select: { id: true }`.
- Throw typed errors; never return `{ error: ... }`.

## Mapper / DTO boundary

Don't leak raw Prisma rows to clients. When the API shape differs from the row,
map it in `utils/mappers/`:

```ts
export const toDonationDTO = (d: DonationWithRelations): IDonationResponse => ({
  id: d.id,
  amount: d.amount,
  currency: d.currency,
  donor: d.donor && { id: d.donor.id, name: d.donor.fullName },
});
```

*Why:* internal columns (audit fields, soft-delete flags, FKs) stay internal;
the response contract is explicit and stable.

## Validation - Zod at the boundary

```ts
export const validateRequest =
  <T extends ZodType>(schema: T, target: "body" | "query" | "params" = "body") =>
  (req: Request, _res: Response, next: NextFunction): void => {
    try {
      const parsed = schema.parse(req[target]);
      // Express 5: req.query is a getter - redefine it; body/params are writable.
      if (target === "query") {
        Object.defineProperty(req, "query", { value: parsed, writable: true, configurable: true, enumerable: true });
      } else {
        (req as unknown as Record<string, unknown>)[target] = parsed;
      }
      next();
    } catch (err) {
      if (err instanceof ZodError) {
        return next(new ValidationError("Validation Error", {
          layer: "Request Validation",
          code: "VALIDATION_ERROR",
          context: { errors: err.issues.map((i) => ({ field: i.path.join("."), message: i.message })) },
        }));
      }
      next(err);
    }
  };
```

Rules:
- One validation library: **Zod**. Use `validationMiddleware.{create,update,query,custom}` -
  thin wrappers over `validateRequest` (create/update target `body`, query targets
  `query`; canonical source in `project-scaffold` → `reference/backend-infra.md`).
- The parsed (coerced) result is written back to `req`, so the handler reads typed
  values and the schema's inferred type doubles as the service input type.
