---
name: design-taste
description: >-
  Anti-slop design defaults and marketing-page composition. Two layers:
  (1) the AI-tells catalog applies AUTOMATICALLY and ALWAYS to ANY UI work in
  any project - banned default palettes (AI purple, beige+brass), font
  discipline (no Inter-by-default, serif rules), fake content, layout tells,
  consistency locks; (2) the full composition protocol applies when building
  or redesigning landing pages, portfolios, marketing sites, editorial pages,
  or the public pages of an app - heroes, sections, content density, images,
  redesigns. Load BEFORE writing UI so defaults are overridden at write time.
---

# Design Taste

<!-- Adapted from Leonxlnx/taste-skill (MIT), curated for this skill set:
motion decision rules live in emil-design-eng/animate, responsive structure
in mobile-first-ui, a11y/SEO in frontend-conventions reference/a11y-seo.md,
stack choices in frontend-conventions. This skill owns what none of those
do: the LLM's default aesthetic instincts, and marketing-page composition. -->

LLMs have trained-in visual defaults that make every generated interface look
the same: the same purple gradients, the same beige "premium" palette, the
same three feature cards, the same Inter-on-slate. Users recognize these
instantly as AI output. This skill exists to override those instincts with
deliberate decisions.

## Scope and seams

- **Layer 1 - AI-tells catalog** (`reference/ai-tells.md`): applies to EVERY
  piece of UI, app or marketing, any project. Read it before styling anything.
- **Layer 2 - marketing composition** (`reference/marketing-pages.md`):
  applies to landing pages, portfolios, editorial, and an app's public pages.
  Product/admin/dashboard UI is NOT this layer's job - the house conventions
  and mobile-first-ui own that; do not apply hero/section rules to a settings
  screen.
- Scroll-driven patterns (pinned stacks, horizontal pans) and their hard
  bans: `reference/scroll-patterns.md`.
- Motion decisions (should it animate, easing, duration, springs) belong to
  `emil-design-eng`/`animate`. A11y/contrast/SEO belong to
  frontend-conventions `reference/a11y-seo.md`. The `frontend-design` plugin
  supplies creative direction; this skill's bans CONSTRAIN it - a plugin
  suggestion that lands on a banned default loses.

## Step 0: the design read (before any UI code on a public surface)

State in one line what you are building before building it:
"Reading this as: <page kind> for <audience>, with a <vibe> language,
leaning toward <aesthetic family or design system>."

Derive it from the brief's signals: page kind, vibe words the user used,
references they linked, the audience, existing brand assets, and quiet
constraints (public-sector, accessibility-critical, regulated - these
OVERRIDE aesthetic preference). If the read genuinely diverges two ways, ask
ONE question; otherwise declare it and proceed (autonomous builds record it
in PLAN.md per app-blueprint).

## The three dials

Set once per page from the design read; they gate layout, motion, and
spacing decisions in the references:

- `DESIGN_VARIANCE` 1-10 (perfect symmetry -> artsy chaos)
- `MOTION_INTENSITY` 1-10 (static -> cinematic)
- `VISUAL_DENSITY` 1-10 (art gallery -> cockpit)

| Read | VARIANCE | MOTION | DENSITY |
| --- | --- | --- | --- |
| Minimalist / calm / Linear-style | 5-6 | 3-4 | 2-3 |
| Premium consumer / Apple-y | 7-8 | 5-7 | 3-4 |
| Playful / experimental / agency | 9-10 | 8-10 | 3-4 |
| Standard SaaS landing (default) | 7 | 6 | 4 |
| Trust-first / public-sector / regulated | 3-4 | 2-3 | 4-5 |
| App product UI (dashboards, admin) | out of scope - house conventions |

High variance NEVER survives below 768px: asymmetric layouts collapse to
single column on phones (mobile-first-ui owns the mechanics).

## The non-negotiables (full catalog in reference/ai-tells.md)

- **Anti-default discipline.** Never reach for: AI-purple gradients, centered
  hero over dark mesh, three equal feature cards, glassmorphism-on-everything,
  Inter + slate-900, the beige+brass "premium" palette. These are the LLM's
  trained defaults; reach past them deliberately based on the design read.
- **One accent color per page, locked.** Neutral base (zinc/slate/stone) +
  one high-contrast accent used identically in every section.
- **One corner-radius system, one theme, one type system per page.** Locks,
  not preferences: mixed radii, mid-page theme flips, and random serif words
  inside sans headlines all read as broken.
- **Real content, real images.** No Jane Doe, no Acme, no fake-precise
  numbers, no div-built fake screenshots, no hand-rolled SVG icon paths.
- **Copy self-audit before done.** Re-read every visible string; rewrite
  anything grammatically broken, AI-cute, or performative. Plain beats clever.

## Pre-flight check

Before delivering any public-surface page, run the mechanical checklist at
the bottom of `reference/marketing-pages.md` (hero fits viewport, eyebrow
count <= ceil(sections/3), no repeated layout families, palette/shape/theme
locks, image reality, copy audit). For app UI, the ai-tells catalog plus the
house checklists (frontend-conventions, mobile-first-ui) are the gate.

## When unsure

When the brief is silent on aesthetics, default to restraint: neutral base,
one accent, strong typography, real spacing - and record the choice. A calm
page that doesn't look AI-made beats a decorated one that does.
