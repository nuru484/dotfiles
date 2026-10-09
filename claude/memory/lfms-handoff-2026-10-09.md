---
name: lfms-handoff-2026-10-09
description: "READ FIRST on restart (9 Oct late): S39 + auth + C3-C5 pushed; S40 paused for the owner"
metadata:
  node_type: memory
  type: project
  originSessionId: 7134d0d2-3d09-4e60-8c47-59cb7e6774ed
  modified: 2026-10-09T08:55:31.393Z
---

Session closed by the owner 9 Oct ~09:00 after the machine ran out of memory (full gate + 2 dev servers + Playwright).

**Final 9 Oct (supersedes below):** ALL PUSHED and gated: terms agreement stored (legal_acceptance, tick on invitations, recorded once per version at sign-in), partner filters by server grades, invitation pages two-column with InviteeCard, layout rules moved to lfms-web/docs/LAYOUT-RULES.md. NEXT: the owner's rebrand of the system and site, plus site fixes; start by asking for the brand assets and the site fix list. S40 paused.

**Update 9 Oct late (supersedes below):** PUSHED api 35f7e8e1, web fa9ddb8d, site (C5 merge). Shipped: S39 funds requests (+portal, bill replenishment, outstanding report), auth pages redesign (provider buttons, consent lines, focused reset steps, portal split sign-in, firm portal terms/privacy settings), cloud C3/C4/C5 merged. S40 PAUSED by the owner after the auth fix; ask before resuming. C3 follow-up owed: budget report partner filter narrows one searched page in the browser (users list takes one grade). Not saved: per-person acceptance of terms (owner may want it). Gate scripts: scratchpad gate-all.sh / gate-web.sh.

**Update 9 Oct evening (supersedes the rest of this note where they differ):** ALL PUSHED: api `b79d993b` (S35, P12.4, party-merge fix, delegation kinds migration 20261009130000, C3/C4/C5 cloud specs, P10C SMS decisions), web `43301156` (UI round, C1, C2, rules), site `494cf94`. Gate worktrees at ~/repos/worktrees/gate/{lfms-api,lfms-web,lfms-site} on branches gate-api/gate-web/gate-site (api needs `npx prisma generate` there; lint with its own cache dir; web tests in 8 shards x 2 workers, the full run loses a worker). Now building S39 with the owner's three additions (spec 4a portal, 4b replenishment on the bill, 4c outstanding funds report); S39 migrations renamed to 20261009140000/140100 (dev DB updated). Codex resumed P14.2 12:39; after it, P10C (brief to write: Frog primary, Arkesel failover with token, Twilio abroad off by default). Cloud: C3, C4, C5 handed to the owner.

**Order for the next session (owner):**
1. **UI fixes and updates first.** The owner brings a list; do those before anything else.
2. Then the full gate (pushes S35 + P12.4), then finish S39.

**P12.4 portal sign-in: MERGED into main 9 Oct, NOT pushed.**
- Commits: api a52c2479 + 85e9cff8 (guard fixes), web 2bcc27a3, site 494cf94.
- The migration was renamed to `20261009120000_portal_sign_in` and is applied to the dev DB.
- Checked: API tsc, portal integration (67 tests), unit 2002, the guards; web tsc, unit and the portal component tests.
- Not done: the browser walk of the portal Security tab, detail changes and phone sign-in. It goes out with the next full gate.

**S35 dunning ladders: built, committed, NOT pushed.**
- Unpushed on main: the S35 commits, the docs commit 7c2c0eba and the P12.4 merge. web and site carry S35 plus P12.4.
- The full gate's API suite failed on two things; both are fixed but sit uncommitted in lfms-api, mixed with S39 work:
  - `src/modules/billing/infra/party-merge.ts`: collectionsReferral and clientCollections now covered by the party merge;
  - `src/platform/audit/entity-types.ts`: bill_dispute, client_collections, collections_referral, dunning_ladder added.
- Next: commit those, then run the full gate with the dev servers stopped. It pushes on green.
- The gate worktrees (`~/repos/worktrees/gate/*`) were removed 9 Oct. Recreate them before gating:
  - `git worktree add --detach worktrees/gate/<repo> main` for each repo;
  - web: `cp -al` node_modules, because Turbopack rejects a symlink;
  - site: symlink `.env.local`;
  - api: symlink `.env`.
- The old scratchpad's gate scripts were lost in the crash. Run `push-gate-main.sh` from the old scratchpad (`/tmp/claude-1000/-home-nurudeen-repos/7134d0d2-3d09-4e60-8c47-59cb7e6774ed/scratchpad`). If it is gone, its steps are: api format, lint, tsc at 10 GB, depcruise, the check:* scripts, vitest at 4 workers; web format, lint, next typegen, tsc, vitest at 4 workers, build; site format, lint, typegen, typecheck, build; push only if all pass.

**S39 funds requests + evergreen retainers: about 40%, all uncommitted in lfms-api, sitting on top of the P12.4 merge.**
- Spec: `docs/specs/spec-s39-funds-requests.md`. The arrangement field is named `evergreen`, because `retainer` was already the fee.
- Migrations `20261009110000_funds_requests` and `20261009110100_funds_request_numbering` (the NumberedObject enum) are applied to the dev DB.
- Written, never typechecked or tested:
  - `client-account/funds-requests.{schemas,usecase}.ts`, the router in `routes.ts`;
  - `infra/funds-matching.ts` (receipt listener), `funds-reminders.ts`, `evergreen.ts`, `funds-request-document.ts`;
  - the facades `billing/infra/evergreen-terms.ts` and `payments/infra/evergreen-schedules.ts`;
  - the stopped-work seam now takes many readers, each carrying its own mode;
  - the test file `test/integration/client-account/funds-requests.test.ts`.
- The payer must be a client of the matter (security fix). The last lint run was interrupted by the crash.
- Next: lint, tsc, the targeted tests, the guards; then the web screens (Funds requests tab, request page and record, matter client-money tab, the arrangement's evergreen fields, 3 settings), help, walk, gate, push.

**Codex lane:** P14.2 company secretarial, API at about 25% and uncommitted in `~/repos/worktrees/s18/lfms-api`. Relaunched 08:39 after the crash. The keepalive does not relaunch after a crash, because the status line reads "resumed".
- Suggested next lane work, to be discussed with the owner first: S37, S32, S25, S30, S33, S38, S31, S26.
- Hold S19, S36, S29 and S44 until S40 is done, since they edit the same code as the money work.

**Cloud Claude (owner's ~$43 credit):** specs `docs/specs/cloud/C1-budget-report-screen.md` and `C2-searched-people-pickers.md`, both web-only, to be built on a branch. The lead reviews and merges.

**Roadmap:** the reporting rework moved after v1 as session REP. The main line is now items 1–10.

**Cleared 9 Oct (owner):** the lane2, lane3, lead and gate worktrees (merged lane branches deleted), the walk screenshots in `~/repos` and `ms/`, `.playwright-mcp/` and `portal-gate-fixes/` (already on main). Only Codex's `worktrees/s18` remains. Save walk screenshots in the scratchpad from now on, never in `~/repos`.
