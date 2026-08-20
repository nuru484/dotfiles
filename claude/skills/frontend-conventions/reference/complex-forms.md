# Reference: Complex Forms (wizards, field arrays, dirty guards)

Read this before building a multi-step form, a form with repeating rows, or
any long form a user could lose work in. The base form rules
(`zodResolver`, schema in `validations/` mirroring the backend, disable
submit while pending, toast on error) live in
`reference/components-forms.md` and still apply; this file is the canon for
the three hard shapes.

## Multi-step wizards

The canon: **ONE react-hook-form instance + ONE Zod schema** for the whole
wizard. Steps are a presentation concern - not separate forms, not separate
schemas, not a separate store.

- **One `useForm` + one schema** in `validations/` (mirroring the backend
  contract of the final endpoint). Per-step forms fork validation and lose
  values between steps.
- **Advance = validate the step's field subset**:
  `await form.trigger(step.fields, { shouldFocus: true })`. `shouldFocus`
  moves focus to the first invalid control - the per-step error focus
  `reference/a11y-seo.md` requires. Going BACK never validates.
- **Step index is plain component state.** Wizard data NEVER goes in the
  URL: half-entered form values are not shareable view state (that rule is
  for tables/filters, see `data-tables.md`), and query strings leak into
  history, logs, and referrers.
- **Submit fires only on the final step.** On earlier steps the Enter key
  advances (with validation) instead of posting half a wizard - route the
  form's `onSubmit` accordingly (see code).
- RHF keeps values of unmounted fields by default (`shouldUnregister:
  false`), so render only the active step's fields; hidden steps keep their
  values.
- **Server draft persistence ONLY when the spec asks for it.** Default:
  everything stays client-side until the final POST. When the spec demands
  resumable drafts, use the autosave pattern at the bottom of this file.

```tsx
// validations/org-wizard-validation.ts - ONE schema for the whole wizard.
// Mirrors backend createOrganization validation.
import { z } from "zod";
import { SUPPORTED_COUNTRIES } from "@/static-data/countries";

export const orgWizardSchema = z.object({
  // step 1 - profile
  name: z.string().min(1, "Name is required").max(150).trim(),
  email: z.string().email("Enter a valid email"),
  // step 2 - address
  country: z.enum(SUPPORTED_COUNTRIES),
  city: z.string().min(1, "City is required").max(100),
  // step 3 - billing
  plan: z.enum(["free", "pro"]),
  billingEmail: z.string().email().optional(),
});
export type OrgWizardValues = z.infer<typeof orgWizardSchema>;
```

```tsx
// components/organizations/forms/org-wizard.tsx
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";

import { orgWizardSchema, type OrgWizardValues } from "@/validations/org-wizard-validation";
import { useCreateOrganizationMutation } from "@/redux/organizations-api";
import { useUnsavedChangesGuard } from "@/hooks/use-unsaved-changes-guard";
import { extractApiErrorMessage } from "@/utils/api-error";
// shadcn imports elided: Button, Input, Label, Select*

const STEPS: { id: string; title: string; fields: (keyof OrgWizardValues)[] }[] = [
  { id: "profile", title: "Profile", fields: ["name", "email"] },
  { id: "address", title: "Address", fields: ["country", "city"] },
  { id: "billing", title: "Billing", fields: ["plan", "billingEmail"] },
];

export function OrgWizard() {
  const router = useRouter();
  // Step index: plain component state. Never the URL.
  const [step, setStep] = useState(0);
  const isLast = step === STEPS.length - 1;

  // ONE form instance + ONE schema across all steps.
  const form = useForm<OrgWizardValues>({
    resolver: zodResolver(orgWizardSchema),
    mode: "onTouched",
    defaultValues: {
      name: "", email: "", country: "GH", city: "", plan: "free", billingEmail: undefined,
    },
  });

  useUnsavedChangesGuard(form.formState.isDirty);

  const [createOrg, { isLoading }] = useCreateOrganizationMutation();

  const next = async () => {
    // Validate ONLY this step's fields; shouldFocus puts focus on the first
    // invalid control (per-step error focus, a11y-seo).
    const ok = await form.trigger(STEPS[step].fields, { shouldFocus: true });
    if (ok) setStep((s) => s + 1);
  };

  const onSubmit = form.handleSubmit(async (values) => {
    try {
      const res = await createOrg(values).unwrap();
      toast.success("Organization created");
      form.reset(values); // clears isDirty so the guard releases BEFORE the redirect
      router.push(`/organizations/${res.data.id}`);
    } catch (err) {
      toast.error(extractApiErrorMessage(err));
    }
  });

  return (
    <form
      // Submit only on the last step; Enter on earlier steps advances
      // (with validation) instead of submitting half a wizard.
      onSubmit={isLast ? onSubmit : (e) => { e.preventDefault(); void next(); }}
      aria-labelledby="wizard-title"
      className="space-y-6"
    >
      <h1 id="wizard-title">Create organization</h1>
      <p aria-live="polite" className="text-sm text-muted-foreground">
        Step {step + 1} of {STEPS.length}: {STEPS[step].title}
      </p>

      {step === 0 && (
        <div className="space-y-4">
          <div>
            <Label htmlFor="name">Organization name</Label>
            <Input
              id="name"
              aria-invalid={!!form.formState.errors.name}
              aria-describedby={form.formState.errors.name ? "name-error" : undefined}
              {...form.register("name")}
            />
            {form.formState.errors.name && (
              <p id="name-error" role="alert" className="text-sm text-destructive">
                {form.formState.errors.name.message}
              </p>
            )}
          </div>
          {/* email: same label/aria-describedby/role=alert shape */}
        </div>
      )}
      {step === 1 && <div className="space-y-4">{/* country + city, same shape */}</div>}
      {step === 2 && <div className="space-y-4">{/* plan + billingEmail, same shape */}</div>}

      {/* Buttons stack full-width on phones, primary on top (mobile-first-ui) */}
      <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-between">
        <Button
          type="button"
          variant="outline"
          onClick={() => setStep((s) => s - 1)} // back never validates
          disabled={step === 0}
        >
          Back
        </Button>
        <Button type="submit" disabled={isLast && isLoading}>
          {isLast ? "Create organization" : "Continue"}
        </Button>
      </div>
    </form>
  );
}
```

## Dynamic field arrays (useFieldArray)

For repeating rows (invoice line items, contacts, criteria): `useFieldArray`
+ a Zod array schema. The money/line-items example is the canonical one.

```ts
// validations/invoice-validation.ts
// Mirrors backend createInvoice validation.
import { z } from "zod";

const lineItemSchema = z.object({
  description: z.string().min(1, "Description is required").max(255).trim(),
  quantity: z.coerce.number().int().min(1, "Quantity must be at least 1"),
  // Major units in the form (human input); converted to integer minor units
  // at the API boundary per api-contracts - never floats as money on the wire.
  unitPrice: z.coerce.number().positive("Price must be greater than 0"),
});

export const invoiceSchema = z.object({
  customerName: z.string().min(1, "Customer is required").max(150).trim(),
  lineItems: z
    .array(lineItemSchema)
    .min(1, "Add at least one line item")
    .max(50, "An invoice is limited to 50 line items"),
});
export type InvoiceValues = z.infer<typeof invoiceSchema>;
```

```tsx
"use client";
// inside the invoice form component (useForm as usual, zodResolver(invoiceSchema))

const { fields, append, remove } = useFieldArray({
  control: form.control,
  name: "lineItems",
});

// Array-LEVEL errors (min/max) surface at the group. With zodResolver they
// land on `.root` when rows also have errors, or directly on the array key -
// read both.
const arrayError =
  form.formState.errors.lineItems?.root?.message ??
  form.formState.errors.lineItems?.message;

// Totals are DERIVED from the watched rows - never a second piece of state.
const lineItems = useWatch({ control: form.control, name: "lineItems" });
const totalMinor = lineItems.reduce(
  (sum, li) => sum + Math.round((Number(li.unitPrice) || 0) * 100) * (Number(li.quantity) || 0),
  0,
);

return (
  <fieldset className="space-y-3" aria-describedby={arrayError ? "line-items-error" : undefined}>
    <legend className="font-medium">Line items</legend>
    {arrayError && (
      <p id="line-items-error" role="alert" className="text-sm text-destructive">
        {arrayError}
      </p>
    )}

    {fields.map((field, index) => (
      // key MUST be field.id (stable per row). key={index} re-associates
      // values with the wrong row on remove/reorder - the classic bug.
      <div key={field.id} className="@container">
        <div className="grid gap-2 @[420px]:grid-cols-[1fr_6rem_8rem_auto]">
          <Input
            aria-label={`Line item ${index + 1} description`}
            aria-invalid={!!form.formState.errors.lineItems?.[index]?.description}
            {...form.register(`lineItems.${index}.description`)}
          />
          <Input
            type="number"
            inputMode="numeric"
            aria-label={`Line item ${index + 1} quantity`}
            {...form.register(`lineItems.${index}.quantity`)}
          />
          <Input
            type="number"
            inputMode="decimal"
            step="0.01"
            aria-label={`Line item ${index + 1} unit price`}
            {...form.register(`lineItems.${index}.unitPrice`)}
          />
          <Button
            type="button"
            variant="ghost"
            size="icon"
            aria-label={`Remove line item ${index + 1}`}
            onClick={() => remove(index)}
            disabled={fields.length <= 1} // UI enforces the Zod min too
          >
            <Trash2 aria-hidden="true" />
          </Button>
        </div>
        {/* per-row errors are ordinary field errors:
            form.formState.errors.lineItems?.[index]?.unitPrice?.message */}
      </div>
    ))}

    <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
      <Button
        type="button"
        variant="outline"
        onClick={() => append({ description: "", quantity: 1, unitPrice: 0 })}
        disabled={fields.length >= 50} // UI enforces the Zod max too
      >
        Add line item
      </Button>
      <Money amountMinor={totalMinor} currency="GHS" className="font-medium" />
    </div>
  </fieldset>
);

// API boundary: convert to minor units, per api-contracts.
const onSubmit = form.handleSubmit(async (values) => {
  await createInvoice({
    customerName: values.customerName,
    lineItems: values.lineItems.map((li) => ({
      description: li.description,
      quantity: li.quantity,
      unitPriceMinor: Math.round(li.unitPrice * 100),
    })),
  }).unwrap();
});
```

Rules:
- **Keys from `field.id`, never the index.**
- **Array-level errors render at the group** (`role="alert"`, tied via
  `aria-describedby` on the fieldset); per-row errors stay on their fields.
- **Min/max enforced twice**: in Zod (the contract) AND in the UI (disable
  Add at max, disable Remove at min) so users cannot build a state they only
  learn is invalid at submit.
- New rows are appended with FULL default values so controlled inputs never
  start `undefined`.
- Rows follow mobile-first-ui: container-queried grids, no text squeezed
  beside action buttons below `sm`, icon buttons `aria-label`led.

## Unsaved-changes guard: useUnsavedChangesGuard(isDirty)

One hook guards any dirty form against lost work. Feed it RHF's
`form.formState.isDirty`.

**The honest limitation first**: the App Router has NO router events
(`routeChangeStart` died with the pages router), so there is no supported
way to intercept every soft navigation. The house pattern is a
document-level capture-phase click listener that intercepts anchor clicks -
which covers every `<Link>` without wrapping any of them - plus
`beforeunload` for hard navigations. A `<GuardedLink>` wrapper is NOT the
house pattern: a wrapper only guards links that remembered to use it, and
one plain `<Link>` in a menu bypasses it silently.

Coverage:
- Covered: tab close, reload, external URLs (`beforeunload`); every
  same-origin `<a>`/`<Link>` click (the capture listener runs before
  next/link's own handler).
- NOT covered: programmatic `router.push` in your own code - call
  `confirmLeave(isDirty)` first at those call sites; browser back/forward -
  `popstate` fires after the history entry has already changed and cannot be
  reliably cancelled. Accept this; do not add fragile popstate hacks.

```tsx
// hooks/use-unsaved-changes-guard.ts
"use client";

import { useEffect, useRef } from "react";

const DEFAULT_MESSAGE = "You have unsaved changes. Leave this page and discard them?";

/** For programmatic navigation: `if (confirmLeave(isDirty)) router.push(...)` */
export const confirmLeave = (isDirty: boolean, message = DEFAULT_MESSAGE): boolean =>
  !isDirty || window.confirm(message);

export function useUnsavedChangesGuard(isDirty: boolean, message = DEFAULT_MESSAGE): void {
  // Ref, not dep: listeners bind once and always read the latest dirtiness.
  const dirtyRef = useRef(isDirty);
  dirtyRef.current = isDirty;

  useEffect(() => {
    // 1. Hard navigations: tab close, reload, external URL.
    const onBeforeUnload = (e: BeforeUnloadEvent) => {
      if (!dirtyRef.current) return;
      e.preventDefault();
      e.returnValue = ""; // legacy channel; browsers show their own wording
    };

    // 2. Soft navigations: capture-phase anchor interception. Capture runs
    //    BEFORE next/link's click handler, so preventDefault stops the route.
    const onClickCapture = (e: MouseEvent) => {
      if (!dirtyRef.current || e.defaultPrevented) return;
      // Modified clicks open new tabs/windows - the form stays; allow them.
      if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
      const anchor = (e.target as Element | null)?.closest?.("a[href]");
      if (!(anchor instanceof HTMLAnchorElement)) return;
      if (anchor.target === "_blank" || anchor.hasAttribute("download")) return;
      const dest = new URL(anchor.href, window.location.href);
      if (dest.origin !== window.location.origin) return; // beforeunload covers it
      if (
        dest.pathname === window.location.pathname &&
        dest.search === window.location.search
      ) {
        return; // hash-only movement, not a route change
      }
      if (!window.confirm(message)) {
        e.preventDefault();
        e.stopPropagation();
      }
    };

    window.addEventListener("beforeunload", onBeforeUnload);
    document.addEventListener("click", onClickCapture, true);
    return () => {
      window.removeEventListener("beforeunload", onBeforeUnload);
      document.removeEventListener("click", onClickCapture, true);
    };
  }, [message]);
}
```

Usage: call once in the form component with `form.formState.isDirty`. After
a successful submit, `form.reset(values)` BEFORE navigating so the guard
releases (the wizard example above does this).

## Autosave stance

**Default: NO autosave.** The dirty guard above is the house answer to lost
work. Autosave on a validated form is a trap: it persists half-valid
records, fights the backend validation contract, and turns keystrokes into
writes.

When a spec explicitly demands drafts (long applications, CMS content):

- The backend exposes a DRAFT endpoint with relaxed validation - drafts are
  a distinct resource state, never half-valid "real" records.
- Debounced PATCH to that draft endpoint (~2s after the last change).
- **Always a visible indicator**, never silent: "Saving…" -> "Draft saved"
  in an `aria-live="polite"` region, and failures surface ("Couldn't save
  draft - will retry on next change").
- The final submit still validates the FULL schema and hits the real
  endpoint; a saved draft is not a submitted record.

```tsx
// sketch - only when the spec demands drafts
const [saveDraft] = useSaveDraftMutation();
const [draftState, setDraftState] = useState<"idle" | "saving" | "saved" | "error">("idle");
const values = useWatch({ control: form.control }); // new reference per change

useEffect(() => {
  if (!form.formState.isDirty) return;
  const t = setTimeout(async () => {
    try {
      setDraftState("saving");
      await saveDraft({ id: draftId, body: values }).unwrap();
      setDraftState("saved");
    } catch {
      setDraftState("error"); // surfaced below - never silent
    }
  }, 2000);
  return () => clearTimeout(t);
}, [values, form.formState.isDirty, draftId, saveDraft]);

<p aria-live="polite" className="text-sm text-muted-foreground">
  {draftState === "saving" && "Saving draft…"}
  {draftState === "saved" && "Draft saved"}
  {draftState === "error" && "Couldn't save draft - will retry on next change"}
</p>
```
