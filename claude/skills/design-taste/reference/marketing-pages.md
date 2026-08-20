# Marketing-Page Composition Protocol

Scope: landing pages, portfolios, editorial pages, and the PUBLIC pages of
an app (home, campaigns, about, pricing). Product/admin/dashboard UI is out
of scope here - house conventions + mobile-first-ui own it. Adapted from
Leonxlnx/taste-skill (MIT) for this skill set.

## Contents
1. Design system selection
2. Hero discipline
3. Section discipline
4. Content density
5. Quotes & testimonials
6. Image & asset strategy
7. Motion on marketing pages
8. Redesign protocol
9. Pre-flight checklist

## 1. Design system selection

- **House default**: shadcn/ui + Tailwind (frontend-conventions), customized
  to the brand - never default-state shadcn on a public page.
- **When the brief names an ecosystem, use the OFFICIAL package** rather
  than hand-recreating its look: Fluent (`@fluentui/react-components`) for
  Microsoft-style enterprise, Material 3 (`@material/web`), Carbon
  (`@carbon/react`) for IBM-style analytics, GOV.UK Frontend / USWDS for
  public sector (often legally expected), Polaris for Shopify surfaces,
  Primer for GitHub-style devtools. Verify current install commands from the
  official docs before pinning (CLAUDE.md currency rule).
- **One system per project.** Never mix component systems in one tree, and
  never import a system's tokens only to override most of them.
- **When the brief is an aesthetic, not a system** (glassmorphism, bento,
  brutalism, editorial, dark-tech, aurora), there is no official package:
  build with Tailwind + native CSS and label borrowed approximations
  honestly (e.g. "Apple Liquid Glass" on the web is an approximation with
  `backdrop-filter`; provide a solid fallback under
  `prefers-reduced-transparency`).

## 2. Hero discipline

- **The hero fits the initial viewport**: headline max 2 lines at desktop,
  subtext max 20 words and 3-4 lines, CTA visible without scrolling. If the
  copy doesn't fit, the copy or the font scale shrinks - never the rule. A
  4-line headline is a font-size error.
- **Font scale planned with the asset**: `text-4xl md:text-5xl lg:text-6xl`
  for most heroes; `text-6xl/7xl` only for 3-5 word headlines.
- **Top padding cap ~`pt-24`** at desktop; a hero floating halfway down the
  viewport reads as a bug, not as air.
- **Max 4 text elements**: (eyebrow OR brand strip OR neither) + headline +
  subtext + CTAs (1 primary + max 1 secondary). Banned inside the hero:
  taglines under CTAs, trust micro-strips, pricing teasers, feature bullets,
  avatar rows - all of that gets its own section below.
- **The logo wall lives UNDER the hero**, never inside it, and it is logos
  only: real SVG marks (Simple Icons CDN or package; generated monogram
  SVGs for invented brands), no category labels under each logo, rendered
  correctly in both themes.
- **A hero needs a real visual.** Text plus a gradient blob is a
  placeholder, not a hero (see section 6).
- **No version labels** (`BETA`, `V0.6`) unless the brief IS a launch.

## 3. Section discipline

- **Layout-family repetition ban.** A layout family (3-col cards,
  split-text-image, full-width quote, bento...) appears at most twice per
  page and never in two adjacent sections - except the image/text zigzag,
  which MAY run 2 consecutive sections but never 3 (the third fails
  pre-flight). 8 sections need at least 4 distinct families. "Selected work"
  must not look like "What we do".
- **Eyebrow rationing (the most-violated rule).** Small uppercase
  wide-tracking labels above headlines: max 1 per 3 sections, hero counts.
  Mechanical check: count `uppercase tracking` instances across section
  components; count must be <= ceil(sections / 3). Instead of an eyebrow:
  nothing - the headline is enough.
- **Split-header ban.** "Big headline left + small floating explainer
  right" as a section header is banned as a default; stack them (headline,
  then body at `max-w-[65ch]`). The split earns its place only when the
  right column holds a real visual or interactive element.
- **Bento rules.** Exactly as many cells as real content items (never a
  filler tile); rhythm over repetition (vary tile sizes/rows); at least 2-3
  cells carry real visual variation (image, brand gradient, pattern) - an
  all-white-text bento is the boring default even on a good page.
- **Navigation: one line at desktop, height <= 80px** (default 64-72px).
  Items that don't fit get condensed or moved behind a menu - a two-line
  desktop nav is broken.
- **Mobile collapse declared per section** in the same component; never
  "Tailwind will handle it" (mobile-first-ui owns the mechanics).

## 4. Content density

- Default section shape: headline <= 8 words + sub-paragraph <= 25 words +
  one visual OR one CTA. More needs a reason.
- **No data dumps on marketing pages**: a 20-row table or giant pricing
  matrix is the wrong layout - top 3-5 highlights + "view full list", a
  carousel/marquee for breadth, or a dedicated page.
- **Long lists (>5 items) get a different component**, not a longer `<ul>`:
  grouped 2-col split, card grid, tabs/accordion, scroll-snap pills, or a
  marquee. A 10-row spec list with a hairline under every row is the
  laziest default: group into 2-3 clusters, feature 3-4 hero specs as
  display tiles with the rest behind a disclosure, or card-per-spec.
- Never `border-t` AND `border-b` on every row of anything.
- **One copy register per page**: don't mix technical-mono, editorial prose,
  and marketing punch unless the brand voice demands it.

## 5. Quotes & testimonials

- Max 3 lines of quote body - cut the original if longer; a landing-page
  quote is a snippet.
- Attribution: name + role (+ company). Never a bare first name.
- Real typographic quote marks or none; no dashes as flourish.

## 6. Image & asset strategy

Marketing pages are visual products; text-only pages with fake-screenshot
divs are slop. Priority order:

1. **Image-generation tool first** when one is available in the session:
   generate section-specific assets (hero photography, product shots,
   textures) at the right aspect ratio.
2. **Real images second**: brand-supplied URLs, or seeded placeholders
   (`https://picsum.photos/seed/<descriptive-seed>/<w>/<h>`) with the seed
   describing the section; open-license sources when allowed.
3. **Last resort**: clearly labeled placeholder slots
   (`<!-- TODO: hero product photo 1600x1200 -->`) plus a closing note
   listing every placement that needs a real image. NEVER fill the gap with
   hand-rolled SVG illustrations or div-built fake screenshots.

Even a minimalist page needs 2-3 real images; pure text is not minimalism,
it is unfinished. Product previews are real screenshots, generated images,
or a real working mini-component - never a divs-pretending-to-be-an-app.
`next/image` with dimensions and `priority` on the LCP asset (a11y-seo +
vercel rules cover the mechanics).

## 7. Motion on marketing pages

Decision rules (should it animate, easing, duration, springs) belong to
`emil-design-eng`/`animate` - apply them here too. This file adds only the
composition-level rules:

- **Marquee: max one per page.** Two scrolling strips is filler.
- **Motion claimed = motion shown.** If the dial says `MOTION_INTENSITY > 4`
  the page actually moves (hero entrance, scroll reveals, CTA hover
  physics); if you can't ship working motion, drop the dial to 3 and ship
  clean static. Never half-built motion (jumpy pins, missing cleanup).
- **Every animation names its purpose in one line** (hierarchy, narrative,
  feedback, state) - "GSAP because GSAP is available" fails review.
- Pinned stacks and scroll hijacks: use the canonical skeletons in
  `scroll-patterns.md` (sibling file), never improvised ScrollTrigger configs.

## 8. Redesign protocol

Misclassifying the mode is the biggest source of bad redesign output.
Detect first: **greenfield** / **redesign-preserve** / **redesign-overhaul**
(new visuals, same content and IA). Ambiguous? Ask once: "preserve the
existing brand, or start visually from scratch?"

- **Audit before touching**: brand tokens (colors, type, radii), information
  architecture and conversion paths, content blocks worth keeping, signature
  patterns to preserve, tells to retire, and the SEO baseline (ranking
  pages, meta, structured data). **SEO migration is the #1 redesign risk**:
  keep slugs, anchor IDs, and nav labels stable unless told otherwise.
- **Preserve**: brand colors override the palette rules (a purple brand
  stays purple, executed well), copy voice stays unless a rewrite was
  requested, existing a11y wins are never regressed, analytics-tracked
  names/ids/field orders are never renamed silently.
- **Modernization levers, in order of lift-per-risk**: typography refresh,
  spacing/rhythm, color recalibration, motion layer, hero/key-section
  recomposition, full block replacement (last, only for unsalvageable
  blocks). IA/content/SEO sound = targeted evolution (levers 1-4) beats a
  full redesign.
- **Never change silently**: URL structure, primary nav labels, form field
  names/order, the logo, legal/consent copy.

## 9. Pre-flight checklist (mechanical - run before delivering)

```
READ & DIALS
[ ] Design read declared; dials set from the read, not silently baseline
LOCKS (ai-tells.md)
[ ] One accent, identical across sections; one gray family; no banned palette
[ ] One radius system; one theme, no mid-page inversion; fonts per discipline
HERO
[ ] Fits viewport: headline <= 2 lines, subtext <= 20 words, CTA visible
[ ] Max 4 text elements; top padding <= pt-24; real visual present
[ ] Logo wall (if any) below hero, real SVG logos, logos only
SECTIONS
[ ] Eyebrow count <= ceil(sections/3)   [ ] No 3+ consecutive zigzags
[ ] >= 4 layout families per 8 sections [ ] No split-headers by default
[ ] Bento: exact cell count + visual variation
[ ] Nav one line, <= 80px
CONTENT
[ ] No data dumps; long lists use a real component; quotes <= 3 lines
[ ] Copy self-audit done; no decoration tells (ai-tells.md section 7)
[ ] No duplicate CTA intent (one label per intent across the page)
[ ] CTA labels never wrap at desktop; every CTA passes contrast (a11y-seo)
IMAGES & MOTION
[ ] Real images per section 6; zero div-screenshots; zero hand-rolled icons
[ ] Marquee <= 1; motion purposeful, reduced-motion handled (emil skills)
[ ] Scroll patterns use the canonical skeletons; no window scroll listeners
```

A box that cannot honestly be ticked means the page is not done.
