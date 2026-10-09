---
name: session-log-on-desktop
description: After every finished LFMS session (mine or a merged Codex one), append a concise summary of what was built and the new screens to ~/Desktop/Dangana build log.docx
metadata:
  type: feedback
---

After each session is done, append a concise entry (what was built, new screens or additions) to `~/Desktop/Dangana build log.docx`. Write a JSON `{title, date, built[], screens[], notes[]}` in the scratchpad and run `~/.local/share/lfms-notes-venv/bin/python ~/.local/share/lfms-notes-venv/append_log.py <json>` (python-docx installed there with uv).

**Why:** owner, 1 Oct 2026: "create a word file in the desktop and after every session is done, you write a concise summary of what's built and the new screens or additions."

**How to apply:** after EVERY build (each session, each fix round, each merged Codex session), one short entry: a few bullets of what was built and the screens added or changed. Concise, never long paragraphs (owner, 1 Oct: "just concise summary, not huge text"). Related: [[never-stop-between-milestones]], [[codex-lane-owns-sessions]].
