---
name: supabase_edge_functions
description: Critical deployment checklist and secrets management for Supabase Edge Functions.
---

# Supabase Operations and Edge Function Secrets

This rule applies to Supabase Edge Function deployment and secrets management. It does not block or replace the configured Supabase MCP workflow for SQL/database tasks.

## SQL and database tasks

- For a database task the user requests, use the configured Supabase MCP directly when available; do not ask the user to copy and paste SQL into a separate editor.
- Confirm the target project/environment when it is not unambiguously identified. Do not assume production or switch projects.
- Keep mutations within the user's requested scope. For destructive or broad changes, inspect/preview affected rows first when practical. Never remove MCP/tool approval requirements or claim a query ran if the MCP reports cancellation or failure.

## Edge Function secrets

When deploying or troubleshooting an Edge Function that reads environment variables:

1. Edge Functions run in a cloud Deno runtime and do not read the Flutter/web app's local `.env` file.
2. Inspect the function source for `Deno.env.get('SECRET_KEY')` to identify required secret names. Do not expose secret values in logs, prompts, or source code.
3. Check whether the required secrets are configured for the intended Supabase project. If they are missing, explain the supported way to configure them; do not imply that the user must re-upload secrets that are already configured.
   ```bash
   npx supabase secrets set KEY1=value1 KEY2=value2
   ```
4. Report deployment/secret status accurately. Do not claim a function is ready until deployment and required secret configuration are confirmed.
