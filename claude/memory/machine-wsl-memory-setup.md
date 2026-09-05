---
name: machine-wsl-memory-setup
description: "Dell 16GB laptop, WSL2; .wslconfig raised to 11GB + 8GB swap on 2026-07-28; RAV/SupportAssist uninstall pending"
metadata: 
  node_type: memory
  type: project
  originSessionId: c4a60536-9202-4145-b906-b400b0cca786
  modified: 2026-07-28T22:32:54.157Z
---

The user's machine is a Dell laptop, 16GB RAM, dev work inside WSL2 (Ubuntu).

- `.wslconfig` at `C:\Users\DELL\.wslconfig`: set 2026-07-28 to memory=11GB, swap=8GB, autoMemoryReclaim=gradual (was memory=8GB, which caused the "can't run next dev + claude together" OOMs in [[khadys-dev-testing-notes]]). Needs `wsl --shutdown` to apply - verify with `free -h` (~11GB) if OOM issues recur.
- Debloat done 2026-07-28: Dell services DellTechHub, DellClientManagementService, DellDigitalDelivery stopped and disabled.
- Pending (UAC was declined, user to run later): elevated script `C:\Users\DELL\AppData\Local\Temp\claude-debloat2.ps1` uninstalls RAV Endpoint Protection (ReasonLabs, bundled bloatware, 6 services) and Dell SupportAssist/Digital Delivery/Recovery Assistant.
- Ollama service in WSL auto-starts; user was advised to disable (`sudo systemctl disable --now ollama`), needs their password.
- Windows side typically has Chrome ~2GB+ across many processes.
