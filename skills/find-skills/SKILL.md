---
name: find-skills
description: "Find or install an agent skill when the user explicitly requests discovery or installation. Check capability, compatibility, overlap, and installation target; ordinary implementation questions do not require marketplace searches."
---

# Discover or install an agent skill

Use only for an explicit discovery or installation request. Determine the desired
capability and active host before searching. A Claude-only memory or hook integration
belongs in claude/skills or Claude plugin configuration, not the shared library.

Search the requested source or ecosystem with a concrete query. Check the selected
installer's current help before using its flags. Do not start a blocking interactive
CLI flow in a noninteractive session.

Read the skill and relevant executable resources before recommending installation.
Check task boundaries, dependencies, host-specific tools, license, and overlap with
installed skills. Popularity can inform provenance but is not a correctness test or
a requirement for the user's own skill. Do not invent install counts or stars.

Install when the user has authorized that specific installation; do not ask twice.
Use the host's supported installer, or this repo's shared/host-only directories and
installer. Preserve unrelated skills. Verify discovery and resource paths after
installation, and report any required external configuration separately.

For discovery without installation, return the capability, source, compatibility,
and relevant tradeoffs. If no suitable skill exists, explain the gap instead of
installing a weak match or redirecting ordinary implementation work to a marketplace.
