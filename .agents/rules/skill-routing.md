---
name: skill-routing
description: Always-on guidance for selecting and following relevant workspace skills for each task.
---

# Route each task through relevant skills

At the start of every user task, unless the user explicitly asks to skip skills:

1. Review the installed skills under `.agents/skills/` and identify the smallest relevant set by reading their `SKILL.md` instructions. Do not load or apply unrelated skills.
2. Follow the selected skill's required process, including any approval gates, before editing files or taking consequential actions.
3. For UI/UX design, implementation, or review, include `ui-ux-pro-max` when it is installed and relevant.
4. For database, SQL, or Supabase tasks, follow `.agents/rules/supabase_edge_functions.md` and use the configured MCP when available. Respect MCP permissions; do not treat this rule as blanket approval for destructive queries.
5. If no installed skill fits, proceed using repository conventions without inventing a skill or delaying the task.
6. Do not run every skill on every request. Honor a user's explicit instruction to skip a skill or skill workflow for that task.

Briefly state which skill or skills are being applied when work begins. Do not require the user to name skills in their prompt.
