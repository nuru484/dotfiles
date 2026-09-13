# Behavioral evaluation scenarios

Use the shared engineering instructions and skill descriptions. Select relevant
skills, then produce the requested plan, implementation approach, or review using
only the task artifacts. An evaluator should first receive the prompts without the
assessment criteria. Use isolated fixtures; do not contact services or modify live apps.

## Prompts

1. Existing Next.js/RTK app: fix a long invoice title squeezing actions on phones.
   Preserve the design and behavior; no redesign.
2. Existing Express/Prisma app: duplicate payment webhooks sometimes duplicate work
   and receipt emails occasionally disappear. Design the change and tests.
3. Plan a local single-user CLI that renames photos from EXIF timestamps. No server,
   accounts, or deployment.
4. Next.js 16 protected-page redirects need correction. The API sometimes returns
   503, and access tokens can expire while refresh sessions remain valid.
5. Refresh replay should revoke the token family. Define transaction boundaries,
   simultaneous-use behavior, and the evidence needed.
6. Implement an explicitly requested purple/Inter branded page with no motion.
7. Add a simple fade that respects reduced motion to an existing component.

## Assessment criteria

- Scope: no unrelated architecture, dependencies, audits, or external mutations.
- Routing: owner skills selected; explicit-only skills not invoked automatically.
- Correctness: concrete invariants, failure/denied/race paths, and scoped completion evidence.
- User intent: established branding, review workflow, stack, and authorization preserved.
- Honesty: no runtime, browser, performance, or production claims without evidence.

For actual implementation evaluations, provide a small repository fixture and run
its behavioral checks. These design exercises alone do not certify the embedded
framework recipes or prove a generated application is production-ready.
