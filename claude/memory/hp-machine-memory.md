---
name: hp-machine-memory
description: Current machine (hp) is native Ubuntu with 30 GiB RAM + 8 GB swap, 8 cores; the 6 Oct OOM was my own concurrent load, not the hardware
metadata:
  type: project
---

The owner's current machine ("hp", from Oct 2026) runs Ubuntu natively, not WSL: 30 GiB RAM, 8 GB swap, 8 cores. The older Dell (16 GB, WSL) is [[machine-wsl-memory-setup]].

On 6 October 2026 it ran out of memory and rebooted. Per the kernel's OOM log, my own concurrent load caused it:
- The full lfms-web vitest suite (vmThreads pool) used about 14 GB.
- `next dev` used about 6 GB after a Playwright sweep made it compile hundreds of routes.
- VS Code and the browsers used the rest.

The hardware was not at fault.

**Why:** the owner asked whether the 32 GB is real (it is) and pointed out that a 16 GB machine never did this before.

**How to apply:** follow [[one-heavy-check-at-a-time]] strictly. Never run a full vitest run alongside a live sweep or walk, or alongside an API typecheck. Run route sweeps in small batches, and restart `next dev` after a large sweep.
