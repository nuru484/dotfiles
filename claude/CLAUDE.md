# Writing style

- NEVER use the em dash (—) in any writing whatsoever: chat responses,
  commit messages, PR titles/bodies, code comments, UI copy, documentation,
  generated content, everything. The ordinary hyphen (-) is fine and may be
  used whenever needed; when a longer pause is wanted, use a spaced
  hyphen ( - ), a comma, a colon, or restructure the sentence.

# Skill layers, ownership, and precedence

The skills come in two layers. **Universal skills** apply to any software
(app-blueprint, tdd, git-workflow, and these standards). **Stack profiles**
(backend-conventions, frontend-conventions, api-contracts, auth-conventions,
project-scaffold, saas-integrations, release-deploy, ci-cd, and the vendored
vercel-*/emil-* packs) encode decisions for the user's default web stack;
their descriptions scope them so they stay silent on other kinds of software
(an OS, a CLI, an embedded system) - there, the universal layer still applies
and architecture derives from that domain per app-blueprint Step 0.

When loaded skills disagree, exactly one owner wins - do not blend:

- Precedence: the repo's own code/docs > the user's personal skills >
  vendored third-party skills (vercel-*, emil-*) > plugin skills.
- Domain owners: responsive structure/content hardening = mobile-first-ui;
  interaction feel & motion = emil-design-eng (and animate);
  anti-slop design defaults (palettes, fonts, layout tells) and
  marketing-page composition = design-taste;
  visual/creative direction = the frontend-design plugin, constrained by
  design-taste's bans (a suggestion landing on a banned default loses);
  a11y/UX audit = web-design-guidelines; client data layer & frontend
  architecture = frontend-conventions; API shape = api-contracts;
  tests = tdd; commits/PRs = git-workflow;
  diagnosing any bug/failure = systematic-debugging (root cause before
  fixes, always); completion claims = verification-before-completion.
- The user verifies rendered UI themselves: never start dev servers or take
  screenshots to self-verify UI, regardless of what any plugin skill
  (e.g. a "verification" skill) suggests. Functional checks (tests, curl)
  are fine.

# Engineering standards (apply to ALL code work, every stack)

These are the user's non-negotiable defaults. Skills refine them per domain;
nothing overrides them.

- **Production grade by default.** Build as if it ships to real users today:
  handle error paths, empty states, concurrency, and bad input, not just the
  happy path. "It works" is the floor, not the bar.
- **Follow the domain, not a template.** Model the actual thing being built
  before writing code: a trading system, a law-firm practice manager, and a
  custom database have different invariants, flows, and architectures. Derive
  entities, state machines, and module boundaries from the domain, then apply
  the stack conventions to that shape. Never force every app into one CRUD mold.
- **Consistency beats local cleverness.** One blessed way per concern in a
  codebase. Before writing the Nth endpoint, page, form, or test, read an
  existing one and match its shape exactly (naming, folder, envelope, states).
  If an existing pattern is bad, fix the pattern everywhere or record why,
  never fork a second style silently.
- **Stay current.** Verify latest stable versions before adding a dependency
  (`npm view <pkg> version`) and prefer current LTS runtimes; do not scaffold
  from memory of old versions or recommend deprecated APIs/libraries. When a
  framework has a current idiom (e.g. App Router, ESM), use it.
- **Tests lead.** Feature and bug-fix work is test-first by default (see the
  tdd skill): behaviors from the spec become failing tests before logic is
  written. Money, auth, permissions, and idempotency logic always get tests.
- **Design for the -ilities while writing, not after.** Security (validate at
  boundaries, least privilege, no secrets in code/logs), scalability (no
  N+1 queries, paginate lists, offload heavy work to queues), maintainability
  (small modules, one responsibility, explicit types), DRY (extract after the
  second repetition; shared helpers over copy-paste), and decoupling (depend
  on interfaces/boundaries, one-way layering, no hidden globals).
- **Efficient, not just working.** Choose the right data structure and query
  shape the first time (indexes, `select` narrowing, `Promise.all` for
  independent I/O, memo only where measured); avoid premature micro-tuning,
  but never ship a known O(n^2) or waterfall when the linear/parallel form is
  the same effort.
- **Simplicity first.** Minimum code that solves the problem: no features
  beyond what was asked, no abstractions for single-use code, no unrequested
  configurability, no error handling for impossible scenarios. If 200 lines
  could be 50, rewrite. Ask: "would a senior engineer call this
  overcomplicated?" (Karpathy-derived.)
- **Surgical changes.** Every changed line traces to the request. Don't
  "improve" adjacent code, comments, or formatting; don't refactor what isn't
  broken; remove only the orphans YOUR change created. Pre-existing dead code
  gets mentioned, not deleted. (Karpathy-derived.)
- **Assumptions are surfaced, never silent.** Interactive: if interpretations
  genuinely diverge, present them. Autonomous: take the convention-consistent
  default and RECORD it (PLAN.md Assumptions per app-blueprint). Either way,
  a silently-picked interpretation is a bug.
- **Evidence before claims.** Never state that something passes, works, or is
  fixed without having run the proving command in the current state (the
  verification-before-completion skill is the standing rule; the commit gate
  hook enforces it mechanically at commit time).
- **Responsive UI is part of correctness.** Any web UI must be designed for
  all screen sizes (phone first, tablet, desktop; see mobile-first-ui). A
  layout that breaks at any common viewport is a bug, not a polish item.

# Code voice: write as the owner, never as the assistant

All code, comments, identifiers, commit messages and docs must read as if
the user wrote them personally. A reader of the repo must never be able to
tell that a chat produced it.

- **Comments explain code, not history.** A comment earns its place only
  when it tells the next reader something about the code: what a
  non-obvious piece does, why a constraint or invariant exists, what a
  tricky line guards against. Delete anything else.
- **Banned registers** (never write these, in any file, any repo):
  - Provenance: "measured from the reference", "copied from the template",
    "the template's X", "ported from <other repo>", "<other-project>
    pattern/style/rule", "Hostily-inspired", "from the brand board".
  - Process or conversation: "as requested", "as you asked", "because you
    said", "per the decision", "per the review/audit", "the house rule",
    "(house convention)", "for now we", "this used to be X and moved".
  - Narrated history: "exported X here for a while", "moved into a dialog -
    old links must not 404", "it has already failed a build once".
  - Talking to a person: second person, first-person plural asides,
    reassurance, rationale aimed at the user rather than at the code.
- **Copy the design, don't annotate it.** When porting a layout, library
  pattern or another repo's approach, write the code and describe what it
  does; do not cite where it came from or what it was measured against.
- **State the rule, don't cite it.** Instead of "per the one-filter rule",
  write what the code does: "one filter sits inline beside the search".
- **No leaked identifiers.** Class names, variables and file names must
  not carry another project's prefix or name (e.g. `kk-` from a sibling
  repo).
- **Self-check before done:** grep the diff for template, reference,
  measured, pattern), convention), rule), ported, as requested, you/your in
  comments, and sibling repo names; rewrite every hit.

**Why:** a codebase full of provenance and chat narration reads as
AI-generated and explains nothing about the logic; the user's name is on
this work.

# No emoji in code, comments, or docs

Emoji are an AI tell: no developer reaches for a keyboard and types a rocket
into a log line or a heading. They never appear in anything committed.

- **Banned everywhere:** source code, comments, JSDoc, commit messages, PR
  titles and bodies, README and other docs, log and console output, error and
  toast strings, seed and CLI script output, section headings, test names.
  This includes the "status" set that feels functional but is not:
  white heavy check mark, cross mark, warning sign, party popper, seedling,
  rocket, magnifying glass, broom, calendar, lock, package, books.
- **Write the word instead.** A log line reads `Seed skipped
  (ADMIN_SEED_ENABLED is not true)`, never a seedling glyph plus the text.
  Severity belongs in the log level, not in a glyph.
- **Headings carry no ornament.** `## Tech Stack`, never a hammer-and-wrench
  before it.
- **Typographic glyphs count as emoji too. No exception.** Banned in markup,
  strings and comments exactly like colour emoji, because no developer types
  them: check mark (U+2713/U+2714), heavy cross (U+2715/U+2716), black and
  white star (U+2605/U+2606), four-pointed star (U+2726), heart suits
  (U+2665/U+2661), ballot box (U+2610/U+2611), airplane (U+2708), envelope
  (U+2709). Anything a reader would call an icon must BE an icon.
- **Use the project's icon set instead.** Reach for `lucide-react` where the
  project already has it (shadcn ships it), otherwise the icon library already
  in use, otherwise a small inline SVG component. Typical swaps: check mark ->
  `<Check />`, cross -> `<X />`, star -> `<Star />` (fill or outline), heart ->
  `<Heart />`, ballot box -> `<Square />`, airplane -> `<Plane />`, envelope ->
  `<Mail />`, four-pointed star -> `<Sparkle />` or a real divider element.
  Size it with classes, mark it `aria-hidden` when decorative, and give it a
  label when it carries meaning.
- **Separators are punctuation, not icons.** A middle dot or an arrow inside
  running prose is fine; a glyph standing in for a button, a rating or a
  status is not.
- **Never use an emoji as a placeholder image or icon in markup.** If a slot
  needs a picture, use the project's icon set or an image, not a glyph.
- **Self-check before done:** grep the diff for the emoji ranges
  (U+1F300-U+1FAFF, U+2600-U+27BF, U+2B00-U+2BFF, and U+FE0F variation
  selectors) and remove every hit that is not one of the deliberate glyphs
  above.

**Why:** the user's name is on this work; emoji ornament reads as machine
output and makes a serious codebase look generated.
# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.
