# The AI-Tells Catalog (applies to ALL UI, every project)

These are the signatures that make output recognizable as AI-generated,
distilled from production tests of LLM-built pages (source: Leonxlnx/
taste-skill, MIT). Each is banned AS A DEFAULT: an explicit brief or brand
requirement overrides any of them, a habit never does.

## 1. Color

- **The LILA rule.** The AI-purple/violet glow aesthetic is banned as a
  default: no purple button glows, no purple-to-blue mesh gradients, no neon
  accents "for tech feel". Use a neutral base (zinc, slate, stone) with ONE
  high-contrast accent (emerald, electric blue, deep rose, burnt orange...).
  Override: the brand actually IS purple - then execute purple with intent:
  one consistent palette, harmonized neutrals, restrained gradients.
- **The premium-consumer palette ban** (the second-most-recurring tell).
  For premium/artisan/wellness/luxury/DTC briefs the LLM default is warm
  beige/cream backgrounds + brass/clay/oxblood/ochre accents + espresso
  near-black text. Banned hex families as defaults:
  - Backgrounds: `#f5f1ea` `#f7f5f1` `#fbf8f1` `#efeae0` `#ece6db` `#faf7f1` `#e8dfcb`
  - Accents: `#b08947` `#b6553a` `#9a2436` `#9c6e2a` `#bc7c3a` `#7d5621`
  - Text: `#1a1714` `#1a1814` `#1b1814`
  Rotate real alternatives instead: cold luxury (silver/chrome/smoke),
  forest (deep green + bone + amber), black-and-tan (true off-black + warm
  tan, no beige), cobalt + cream, terracotta + slate, olive + brick + paper,
  or pure monochrome + one saturated pop. Never ship the same family as the
  previous project of the same kind. Override: the brand brief literally
  names those colors.
- **One accent color per page, locked.** Chosen once, used identically in
  every section. A warm-gray site does not grow a teal badge in the footer.
- **Max 1 accent, saturation < 80% by default.** Desaturate accents to sit
  with the neutrals.
- **No pure `#000000` or pure `#ffffff`.** Off-black (zinc-950) and
  off-white; pure values kill depth.
- **One gray family per project.** Never mix warm and cool grays.
- **No neon/outer glows, no gradient text on large headers, no
  oversaturated accents.** Inner borders and subtle tinted shadows instead;
  shadows tinted toward the background hue, never pure black on light.

## 2. Typography

- **Inter is discouraged as the default.** Reach first for Geist, Outfit,
  Cabinet Grotesk, Satoshi, or a brand-appropriate face. Known pairings:
  Geist + Geist Mono, Satoshi + JetBrains Mono, Cabinet Grotesk + Inter
  Tight. Override: the brief asks for neutral/Linear-style, or the site is
  public-sector/accessibility-first - then Inter is fine. Load via
  `next/font` (or self-hosted `@font-face` + `font-display: swap`); never a
  Google Fonts `<link>` in production.
- **Serif discipline (the #1 tested tell).** "Creative/premium brief" is NOT
  a reason to reach for a serif. Serif is acceptable only when the brand
  names one, or the aesthetic is genuinely editorial/luxury/publication AND
  you can say why this serif fits this brand. `Fraunces` and
  `Instrument Serif` (the two LLM-favorite display serifs) are banned as
  defaults outright. Default display type is a sans (Geist, Cabinet Grotesk
  Display, GT Walsheim, PP Neue Montreal...) - sans is the default for the
  same reason black is the default in fashion.
- **Emphasis rule.** To emphasize a word in a headline, use italic or bold
  of the SAME family. Never inject a serif word into a sans headline for
  visual interest - mixed-family emphasis is amateur.
- **Italic descender clearance.** Italic display words containing
  `y g j p q` clip under `leading-none`; use `leading-[1.1]` minimum plus a
  small bottom reserve, and audit every italic headline word.
- **Hierarchy through weight and color, not raw scale.** No screaming
  oversized H1s; body defaults `text-base leading-relaxed max-w-[65ch]`.
- **Numbers that update or align use `tabular-nums`.** (House addition, via
  the web-design-guidelines snapshot; upstream's related rule is font-mono
  for numbers on dense data surfaces.)

## 3. Layout & shape

- **No three-equal-feature-cards row.** The generic "three identical cards"
  feature section is the canonical AI layout. Use a 2-column zigzag (max 2
  in a row), an asymmetric grid, or a different family entirely.
- **Anti-center bias.** With `DESIGN_VARIANCE > 4`, avoid the centered
  hero/H1 default; use split, left-aligned + asset, or asymmetric
  whitespace. Centered is fine for manifesto/editorial briefs.
- **Shape consistency lock.** One corner-radius system per page (all-sharp,
  all-soft ~12-16px, or all-pill), or a documented per-role rule followed
  everywhere. Round buttons on a square page is broken design.
- **Page theme lock.** One theme per page; sections never flip from dark to
  a cream section mid-scroll. Same-family tint shifts (zinc-950 next to
  zinc-900) are fine. A deliberate one-time color-block device is allowed
  once, only when the brief calls for it.
- **Cards only when elevation means something.** Otherwise group with
  borders, dividers, or space. Data-dense surfaces drop card chrome.
- **Glassmorphism restraint.** Frosted glass on everything is a trained
  default; use it only when the design read is premium/Apple-adjacent/media
  overlay - never on dashboards, public-sector, or plain B2B. When used, go
  beyond `backdrop-blur`: a 1px `border-white/10` inner border and a subtle
  inset highlight for the edge, plus a solid-fill fallback under
  `prefers-reduced-transparency`.
- **Z-index restraint.** A documented scale for systemic layers only
  (nav, modal, overlay); no ad-hoc `z-50` sprinkled to win fights.

## 4. Content realism (the "Jane Doe" effect)

- **No generic names** (John Doe, Sarah Chan) - locale-appropriate,
  believable names. (House note: for Ghana-facing apps that means real
  Ghanaian names.)
- **No generic avatars** (SVG egg, user-icon placeholder) - believable photo
  placeholders or styled initials.
- **No fake-perfect numbers** (`99.99%`, `50%`, `1234567`) - organic values
  (`47.2%`, or house example `GHS 12,840`); and no fake-precise engineering
  specs the brand never claimed (`5.8 mm`, `4.1x`) unless labeled as mock data.
- **No startup-slop brand names** (Acme, Nexus, SmartFlow, Cloudly) - invent
  contextual names that sound real.
- **No filler verbs**: "Elevate", "Seamless", "Unleash", "Next-Gen",
  "Revolutionize" - concrete verbs only.

## 5. Components & assets

- **Never hand-roll SVG icon paths.** Icons come from one library per
  project with a standardized `strokeWidth`. House note: shadcn ships
  lucide-react, so **lucide is the house default** - consistency beats the
  upstream preference for Phosphor. On non-shadcn marketing sites, Phosphor,
  HugeIcons, Radix Icons, or Tabler are all fine; never two families in one
  tree.
- **No div-built fake screenshots.** Fake task lists, fake terminals, fake
  dashboards assembled from styled `<div>`s are the #1 visual tell. Use a
  real screenshot, a generated image, a real embedded component, or nothing.
- **No decorative status dots.** A colored dot means live semantic state
  (server up, slot open) or it doesn't exist. Never one per nav item/row.
- **Middle-dot rationing.** `·` at most once per metadata line, never as the
  universal separator.
- **shadcn components never ship in default state** on branded surfaces:
  customize radius, colors, shadows, and type to the project.
- **Emoji discouraged in UI copy and markup** - icon glyphs instead, unless
  the brief is explicitly playful/chat-native.

## 6. Copy tells (run the copy self-audit before "done")

Re-read every visible string (headlines, labels, buttons, captions, alt
text, errors) and rewrite anything that is:

- Grammatically broken or unclear-referent ("free on its past")
- AI-cute wordplay or forced metaphor ("elegant nothing")
- Performative-craftsman labels: "Quietly trusted by", "From the field",
  "Field notes", "On our desks" - use plain labels ("Trusted by",
  "Testimonials", "Latest writing") or none
- Mock-humble asides ("We respect the French ones")
- Micro-meta sentences under section headings explaining the section
- Generic step labels ("Step 1 / Stage 2 / Phase 03") - the verb IS the
  label ("Install", "Configure", "Ship")

Dashes: the em dash is globally banned (CLAUDE.md); use ranges with a plain
hyphen (`2018-2026`, `GHS 40-80k`). Real typographic quotes or none.

## 7. Decoration tells (banned unless the brief demands them)

Version labels in heroes (`V0.6`, `BETA`), section-number eyebrows
(`001 · Capabilities`), pagination labels on images (`01 / 4`), scroll cues
(`Scroll to explore`), decoration strips (`BRAND. MOTION. SPATIAL.`),
rotated vertical text, crosshair/hairline grid decoration, pills overlaid
on photos (`Plate 03 · House archive`), photo-credit captions for stock
images, version footers on marketing pages (`v1.4.2 · main`), live-stock
counters (`Reservation 412 of 800`), locale/time/weather strips
(`LIS 14:23 · 18C`), custom mouse cursors.

Each of these is decoration pretending to be craft. If it carries no real
information for this specific brief, it does not ship.
