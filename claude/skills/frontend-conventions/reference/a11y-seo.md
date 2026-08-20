# Reference: Accessibility & SEO (the invisible layer)

Read this before building any page, form, or interactive component. These are
WRITE-TIME rules: they are applied while coding, not discovered later by the
`web-design-guidelines` audit (which remains the after-the-fact gate).

## Why this file exists

Users of assistive tech, search crawlers, and keyboard-only users all consume
the page through its non-visual structure. If that structure is wrong, no
amount of visual polish makes the output professional. None of this is
optional for production work.

## Accessibility: the write-time contract

### Semantic structure first, ARIA second

- Landmarks on every page: `<header>`, `<nav>`, `<main>` (exactly one),
  `<footer>`; `<aside>` for complementary content. Screen-reader users
  navigate by landmarks the way sighted users scan visually.
- Exactly one `<h1>` per page; headings descend without skipping levels
  (h2 then h3, never h2 then h4). Headings are an outline, not a font-size
  picker; style size with classes, not by choosing a different level.
- `<button>` for actions, `<a>`/`<Link>` for navigation. A `<div onClick>`
  is invisible to keyboards and screen readers; this is never acceptable.
- Lists of things are `<ul>`/`<ol>`, tabular data is `<table>` with `<th scope>`.
- ARIA is the fallback when no semantic element exists, never a substitute:
  "No ARIA is better than bad ARIA."

### The ARIA recipes actually needed in this stack

shadcn/Radix primitives already carry correct roles, focus traps, Escape
handling, and `aria-expanded` - USE the primitives instead of hand-rolling,
and don't duplicate their ARIA. What you still add yourself:

```tsx
// Icon-only button: name it
<Button size="icon" aria-label="Delete donation"><Trash2 aria-hidden="true" /></Button>

// Async region updates (search results, counts) announce politely
<div aria-live="polite">{isLoading ? "Loading results…" : `${total} results`}</div>

// Form field errors: tie message to input, mark invalid, focus first error on submit
<Input id="email" aria-invalid={!!errors.email} aria-describedby="email-error" />
{errors.email && <p id="email-error" role="alert">{errors.email.message}</p>}

// Current page in nav
<Link href="/donations" aria-current={isActive ? "page" : undefined}>

// Screen-reader-only context where the visual layout carries meaning
<span className="sr-only">Donation status:</span> <StatusBadge status={s} />
```

Toasts: sonner already announces via a live region; don't wrap it in another.

### Keyboard & focus

- Every flow must be completable with keyboard alone (Tab/Shift+Tab, Enter,
  Space, Escape, arrows in composite widgets). Radix handles composite-widget
  keys; your job is to not break them and to keep custom interactive elements
  as real `<button>`/`<a>`.
- Visible focus: `focus-visible:` ring on every interactive element; never
  remove an outline without replacing it. Sticky headers must not cover the
  focused element (`scroll-margin-top` on anchor targets).
- Focus management: on modal/sheet close, focus returns to the trigger
  (Radix does this); after a client-side route change to a new "page",
  move focus to the new h1 or main region if the page has app-like flows.

### Contrast (the most common silent failure)

- WCAG AA minimums, checked in BOTH themes: **4.5:1** for body text,
  **3:1** for large text (24px+, or 18.66px bold) and for UI component
  boundaries (input borders, focus rings, icons that convey meaning).
- Never encode meaning in color alone: pair status colors with an icon or
  text (a red/green dot alone excludes colorblind users).
- Placeholder text is not a label and its low contrast is fine ONLY because
  a real label is present.

### Everything else that ships by default

- Images: meaningful ones get descriptive `alt`; decorative ones get
  `alt=""` (never omit the attribute). Icons beside text: `aria-hidden`.
- `<html lang="en">` (or the app's language) in the root layout; `Intl.*`
  for all dates/numbers (also an i18n rule, see the audit snapshot).
- Zoom is never disabled (`user-scalable=no` is banned); touch targets
  ≥ 44px (mobile-first-ui); `prefers-reduced-motion` respected
  (emil-design-eng/animate own the motion rules).
- Videos with speech get captions; audio content gets transcripts.

## SEO: conventions for the Next.js App Router

Scope rule first: **public pages get the full treatment; authed app surfaces
(dashboard, admin) get `robots: { index: false }` and nothing else.** Do not
spend SEO effort on pages behind a login, and never let them be indexed.

### Metadata (every public page)

```tsx
// app/layout.tsx - the template
// (add SITE_URL to PUBLIC_ENV from NEXT_PUBLIC_SITE_URL, the frontend's own
// public origin - distinct from SERVER_URI which is the API)
export const metadata: Metadata = {
  metadataBase: new URL(PUBLIC_ENV.SITE_URL),
  title: { template: "%s | Acme Relief", default: "Acme Relief" },
  description: "…",  // 150-160 chars, front-load the value
  openGraph: { type: "website", siteName: "Acme Relief" },
};

// app/(public)/campaigns/[slug]/page.tsx - dynamic pages derive metadata
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const campaign = await getCampaign(slug); // same fetch as the page: React cache dedupes
  if (!campaign) return { title: "Not found", robots: { index: false } };
  return {
    title: campaign.title,
    description: campaign.summary,
    alternates: { canonical: `/campaigns/${slug}` },
    openGraph: { title: campaign.title, description: campaign.summary,
                 images: [{ url: campaign.coverUrl, width: 1200, height: 630 }] },
  };
}

// app/(dashboard)/layout.tsx - authed surfaces
export const metadata: Metadata = { robots: { index: false, follow: false } };
```

### The route files every public site ships

- `app/sitemap.ts`: static routes + dynamic entries queried from the API/DB
  (`MetadataRoute.Sitemap`); lastModified from `updatedAt`.
- `app/robots.ts`: allow public paths, `disallow: ["/dashboard", "/admin", "/api"]`,
  point at the sitemap.
- `app/icon.png` + `app/opengraph-image` (static 1200x630 image, or
  `opengraph-image.tsx` to generate per-page OG images with next/og).
- `app/not-found.tsx` returning a real 404 (and the API's 404 handler) so
  crawlers don't index error content as 200s.

### Structured data (JSON-LD) where an entity type fits

```tsx
const jsonLd = {
  "@context": "https://schema.org",
  "@type": "Event", // or Organization, Product, Article, FAQPage - match the real entity
  name: campaign.title,
  startDate: campaign.startsAt,
};
<script type="application/ld+json"
  dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd).replace(/</g, "\\u003c") }} />
```

Only claim what is true on the page; fake structured data earns penalties.
The `<` escaping is mandatory (prevents script injection via entity fields).

### Content & rendering rules that ARE the SEO

- Public content renders on the server (frontend-conventions rule 1): no
  client-only data gates hiding content from crawlers, no "loading…" as the
  crawlable content.
- The heading outline (above) doubles as the crawler's document structure;
  descriptive link text ("View the education campaign", never "click here").
- Stable, lowercase, kebab-case slugs; one canonical URL per resource
  (redirect variants, declare `alternates.canonical`).
- Performance is a ranking factor: image `width`/`height` (CLS), `next/image`
  with `priority` on the LCP image, lazy-loading below the fold - the
  vercel-react-best-practices rules serve SEO directly.

## Self-audit (run with the component/page checklist)

```
[ ] Landmarks + single h1 + no skipped heading levels
[ ] All interactivity on real <button>/<a>; icon buttons aria-labelled
[ ] Forms: labels tied, errors aria-describedby + role=alert, first error focused
[ ] Async updates announced (aria-live) where results change out of band
[ ] Contrast AA (4.5:1 / 3:1) verified in light AND dark; meaning never color-only
[ ] Keyboard-only pass reasoned through; focus visible everywhere
[ ] alt on every image (empty for decorative); html lang set
[ ] Public page: metadata + canonical + OG; in sitemap.ts
[ ] Authed page: robots noindex
[ ] JSON-LD added where a schema.org type genuinely matches
```
