---
name: supabase_edge_functions
description: Critical deployment checklist and secrets management for Supabase Edge Functions.
---

# Supabase Edge Functions Deployment Checklist

When deploying or troubleshooting a Supabase Edge Function that relies on environment variables (e.g., SMTP credentials, API keys), follow these rules:

1. **Edge Functions are Isolated:** Edge Functions run in a secure Deno runtime on the cloud. They **DO NOT** have access to the local `.env` file of the Flutter/web application.
2. **Identify Required Secrets:** Scan the `index.ts` file of the edge function for `Deno.env.get('SECRET_KEY')`.
3. **Set Secrets via CLI:** You MUST instruct the user to upload these secrets to the remote Supabase project using the CLI before the function can execute successfully:
   ```bash
   npx supabase secrets set KEY1=value1 KEY2=value2
   ```
4. **Validation:** Do not tell the user to test the feature until you have confirmed that the secrets have been successfully set on the remote project.
