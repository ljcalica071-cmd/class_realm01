import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { requireFirebaseUser } from "../_shared/firebase_admin.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return jsonResponse({ error: "Method not allowed." }, 405);

  try {
    const caller = await requireFirebaseUser(request);
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Supabase service environment is not configured.");
    }

    const database = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: user, error: userError } = await database
      .from("users")
      .select("role")
      .eq("id", caller.uid)
      .maybeSingle();
    if (userError) throw userError;
    if (!user || !["teacher", "student"].includes(user.role)) {
      return jsonResponse({ error: "This account cannot complete first-login setup." }, 403);
    }

    const table = user.role === "teacher" ? "teacher_info" : "student_info";
    const idColumn = user.role === "teacher" ? "teacher_id" : "student_id";
    const { data: account, error: accountError } = await database
      .from(table)
      .select("status")
      .eq(idColumn, caller.uid)
      .maybeSingle();
    if (accountError) throw accountError;
    const status = String(account?.status ?? "").toLowerCase().replace(/[\s_-]/g, "");
    if (!["pendingfirstlogin", "pendingfirstlogon"].includes(status)) {
      return jsonResponse({ error: "This account is not awaiting first-login setup." }, 403);
    }

    const { data: verification, error: verificationError } = await database
      .from("first_login_otp_verifications")
      .select("expires_at")
      .eq("user_id", caller.uid)
      .maybeSingle();
    if (verificationError) throw verificationError;
    if (!verification || Date.parse(verification.expires_at) <= Date.now()) {
      return jsonResponse({ error: "Verify the email code before completing password setup." }, 403);
    }

    const { error: updateError } = await database
      .from(table)
      .update({ status: "active" })
      .eq(idColumn, caller.uid);
    if (updateError) throw updateError;

    const { error: deleteVerificationError } = await database
      .from("first_login_otp_verifications")
      .delete()
      .eq("user_id", caller.uid);
    if (deleteVerificationError) throw deleteVerificationError;

    return jsonResponse({ completed: true });
  } catch (error) {
    console.error("First-login completion failed:", error);
    return jsonResponse({ error: error instanceof Error ? error.message : "First-login setup failed." }, 500);
  }
});
