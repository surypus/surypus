---
description: Archive accumulated phase directories from completed milestones
requires: [phase]
tools:
  read: true
  write: true
  bash: true
  grep: true
  question: true
---
<objective>
Archive phase directories from completed milestones into `.planning/milestones/v{X.Y}-phases/`.

Use when `.planning/phases/` has accumulated directories from past milestones.
</objective>

<execution_context>
@/home/dominicusin/src/surypus/.kilo/gsd-core/workflows/cleanup.md
</execution_context>

<process>
Execute end-to-end.
Identify completed milestones, show a dry-run summary, and archive on confirmation.
</process>
