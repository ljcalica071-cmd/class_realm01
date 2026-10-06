import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { firebaseAdminAuth, requireFirebaseUser } from "../_shared/firebase_admin.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed." }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

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
    const { data: admin, error: adminError } = await database
      .from("users")
      .select("role")
      .eq("id", caller.uid)
      .maybeSingle();
    if (adminError) throw adminError;
    if (admin?.role !== "admin") {
      return new Response(JSON.stringify({ error: "Only an administrator can delete Firebase accounts." }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await request.json();
    const uid = String(body.uid ?? "").trim();
    if (!uid || uid === caller.uid) {
      return new Response(JSON.stringify({ error: "A valid target UID is required." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    await firebaseAdminAuth().deleteUser(uid);
    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Firebase account deletion failed:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Firebase account deletion failed." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
