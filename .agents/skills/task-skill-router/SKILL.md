---
name: task-skill-router
description: Select and apply the smallest relevant set of installed workspace skills before handling a user task. Use for task planning, coding, debugging, database work, and UI/UX work; skip only when the user explicitly asks.
---

# Task Skill Router

Before acting on a user request:

1. Read the task and determine whether it requests an explanation, investigation, plan, code change, UI/UX work, database operation, or a combination.
2. Inspect available `.agents/skills/*/SKILL.md` files and choose only skills relevant to the task. Read the selected skill instructions before proceeding.
3. Follow required sequencing and approval gates from those skills. In particular, do not implement an architectural proposal before required design/spec/plan approvals.
4. For UI/UX tasks, add `ui-ux-pro-max` when available. For Supabase/SQL tasks, also read `.agents/rules/supabase_edge_functions.md` and use configured database MCP tools when available.
5. If the user explicitly says not to use a skill, honor that instruction for the specified task. Otherwise, do not ask the user to choose a skill.
6. If no relevant skill is installed or discoverable, continue with repository conventions and state that limitation only when it materially affects the work.

Keep routing lightweight: do not load all skills, do not use subagents unless a selected skill and task scope call for them, and do not let skill discovery replace doing the requested work.
