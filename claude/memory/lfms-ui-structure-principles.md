---
name: lfms-ui-structure-principles
description: "How the user wants the LFMS console (and any large app of theirs) structured: sidebar for the work only, settings as its own area with a grouped menu, account in the user menu, tabs on routes for multi-section pages, short desktop-only sub-headings, empty registers keep their action; what they rejected and why"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b90ced91-69c6-48da-8759-629929cc8bf5
  modified: 2026-09-05T19:20:02.160Z
---

The user's standard for a large product UI (set on the LFMS console, ~/repos/lfms-web, 2026-09-05, and applies to any similar app of theirs): "GitHub and Vercel have countless pages too, but everything is structured, not bare bones, and still easy to reach." A flat sidebar listing every page reads as a prototype, not production.

**The structure they approved and that is now built into LFMS** (`docs/CONVENTIONS.md` section "Navigation and where a screen lives" is the binding rulebook; `src/static-data/nav.ts` is the one navigation data file):
- Sidebar = the work only: workspaces (Dashboard, Parties, Conflicts, later Matters, Calendar, Documents, Time, Billing, Client accounts, Reports) plus one Settings entry at the foot. Never account pages, never configuration registers.
- Settings = its own area at `/settings/<page>` with a grouped secondary menu drawn in the sidebar's place (Firm, People and access, Practice, Finance, System), a chevron-left "Workspace" link at the top (the words are just "Workspace", not "Back to workspace"), breadcrumbs Settings, group, page, record. Every new admin screen is a settings page in a group, never a sidebar item.
- Account = the avatar menu and the sidebar footer only (Profile, Sessions, Security, Leave, My standing, Notifications, Lock screen, Sign out), read as tabs of `/me`.
- A page with several sections carries them as tabs on nested routes (`PageTabs`), one page header per page, e.g. Tax: Standard rated, Exempt and out of scope, Withholding, Calculator. Never a long page of stacked registers.
- Ctrl+K command palette: static pages filtered client-side, records searched on the server (parties today, matters and documents later). Anything in the bar must be real, not a client-side stub.
- Still owed (the user will give a spec): use the band under the top bar the way GitHub repo tabs / Vercel project tabs do for an area's sections, so the sidebar thins further. Do not build it ahead of the spec.

**Sub-headings and headings:** a section's or page's description is drawn on desktop only (hidden below `lg`), one short sentence, and the heading block (title plus description) takes at most 60 percent of the row so controls keep their room. They rejected 70 percent and rejected long descriptions on desktop.

**Sidebar details:** groups sit close together (small vertical padding); descriptions must not be scattered.

**Registers:** a register's toolbar hides while the register is empty, so every register with a toolbar action must pass `emptyAction` to `DataTable` (source test `test/unit/empty-register-action.test.ts` enforces it). The user found "Request leave" missing for exactly this reason.

**Person records:** the name beside the photo truncates to one line (80 percent of the line on one's own profile, 60 percent on a user's record opened from the register); the band on a user's record is taller than on one's own.

**Why:** the user's name is on the product; it is sold to law firms and must look production-grade. They review every milestone on screen and send fixes; anything that reads as a side project gets sent back.

**How to apply:** before adding a screen, place it in the navigation model (workspace item, settings group page, account tab, or a tab of an existing page); reuse `PageTabs`, `SectionCard`, the DataTable kit and `RecordLayout`; keep descriptions short; never add a sidebar item for configuration. Related: [[mobile-keyboard-safe-overlays]], [[design-for-worst-case-content]], [[parallel-agents-both-repos]], [[commit-no-ai-attribution]].
