m const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed." });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const firebaseApiKey = Deno.env.get("FIREBASE_WEB_API_KEY");
  if (!supabaseUrl || !serviceRoleKey || !firebaseApiKey) {
    console.error("Maintenance function is missing required server configuration.");
    return jsonResponse(500, { error: "Maintenance service is not configured." });
  }

  try {
    const body = await request.json();
    const idToken = typeof body.idToken === "string" ? body.idToken : "";
    const enabled = body.enabled;
    if (!idToken || typeof enabled !== "boolean") {
      return jsonResponse(400, { error: "A valid session and maintenance state are required." });
    }

    const tokenResponse = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(firebaseApiKey)}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ idToken }),
      },
    );
    if (!tokenResponse.ok) {
      return jsonResponse(401, { error: "Your session could not be verified. Please log in again." });
    }

    const tokenData = await tokenResponse.json();
    const firebaseUser = tokenData.users?.[0];
    const userId = firebaseUser?.localId;
    if (!userId || firebaseUser.disabled === true) {
      return jsonResponse(401, { error: "Your session is invalid or disabled." });
    }

    const restHeaders = {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json",
    };
    const profileResponse = await fetch(
      `${supabaseUrl}/rest/v1/users?id=eq.${encodeURIComponent(userId)}&select=id,role,is_archived`,
      { headers: restHeaders },
    );
    if (!profileResponse.ok) {
      console.error("Could not verify the administrator profile.", profileResponse.status);
      return jsonResponse(500, { error: "Could not verify administrator access." });
    }

    const profiles = await profileResponse.json();
    if (profiles[0]?.role !== "admin" || profiles[0]?.is_archived === true) {
      return jsonResponse(403, { error: "Administrator access is required." });
    }

    const updateResponse = await fetch(
      `${supabaseUrl}/rest/v1/system_settings?on_conflict=id`,
      {
        method: "POST",
        headers: { ...restHeaders, Prefer: "resolution=merge-duplicates,return=minimal" },
        body: JSON.stringify({
          id: true,
          is_maintenance_mode: enabled,
          maintenance_updated_at: new Date().toISOString(),
          maintenance_updated_by: userId,
        }),
      },
    );
    if (!updateResponse.ok) {
      console.error("Maintenance settings update failed.", updateResponse.status);
      return jsonResponse(500, { error: "The maintenance setting could not be saved." });
    }

    return jsonResponse(200, { success: true, enabled });
  } catch (error) {
    console.error("Maintenance function request failed.", error);
    return jsonResponse(500, { error: "The maintenance setting could not be updated." });
  }
});
