# Route Task Through Skills

Use this workflow at the start of a task when you want to explicitly trigger skill routing with `/route-task`.

1. Inspect the request and identify its task domains.
2. Read only the relevant `.agents/skills/*/SKILL.md` instructions.
3. Follow their required process and approval gates.
4. For UI/UX tasks, include `ui-ux-pro-max` when installed and relevant.
5. For Supabase/SQL tasks, read `.agents/rules/supabase_edge_functions.md` and use configured MCP tools where available; respect MCP permission prompts and do not treat this workflow as blanket approval for destructive queries.
6. Honor an explicit request to skip skills for this task.
7. Continue with the requested work; do not stop after listing the skills.
