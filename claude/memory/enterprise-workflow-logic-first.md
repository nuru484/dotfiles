---
name: enterprise-workflow-logic-first
description: "LFMS upgrade round: every build is enterprise grade, judged first against the firm's real workflow, then its logic (what must be true before a state change); raise flaws unasked"
metadata:
  node_type: memory
  type: feedback
  originSessionId: fd6045f7-4a8c-47a2-ae49-5befc426edac
  modified: 2026-09-30T09:14:42.322Z
---

This round upgrades LFMS to enterprise grade: nothing is a shallow build. Judge every feature, in this order: (1) does it meet how firms actually run the work, (2) does its logic hold: what must be true before a record changes state (retire, close, deactivate, delete, transfer), what still depends on it, who may do it, with what reason and audit. Raise a flaw the moment it is seen, even outside the task asked for, and fix the class.

**Why:** owner, 30 Sep 2026, after finding a court could be deactivated with open cases, listed hearings and posted judges: "this upgrade is not just another shallow builds ... I don't know why you didn't even raise that ... ensure everything is enterprise grade, meets the workflow and logic, in that order."

**How to apply:** for every state change a screen offers, check the preconditions and dependents before building or accepting it; a toggle with no precondition, no reason and no refusal naming what blocks it is a defect. Put the same instruction in every brief handed to another agent (Codex lanes). See [[fix-the-class-not-the-instance]], [[enterprise-complete-linked-entities]].
