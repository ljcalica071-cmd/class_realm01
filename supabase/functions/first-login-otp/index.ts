import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer";
import { requireFirebaseUser } from "../_shared/firebase_admin.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-supabase-api-version, prefer",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS, PUT, DELETE",
};

const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

function requiredEnv(name: string) {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} is not configured.`);
  return value;
}

async function hashCode(uid: string, code: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(requiredEnv("FIRST_LOGIN_OTP_SECRET")),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${uid}:${code}`),
  );
  return Array.from(new Uint8Array(signature), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function escapeHtml(value: string) {
  return value.replace(/[&<>"']/g, (character) => {
    const entities: Record<string, string> = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;",
    };
    return entities[character];
  });
}

async function sendCode(email: string, name: string, code: string) {
  const host = Deno.env.get("SMTP_HOSTNAME") ?? "smtp.gmail.com";
  const port = Number(Deno.env.get("SMTP_PORT") ?? "465");
  const username = requiredEnv("SMTP_USERNAME");
  const password = requiredEnv("SMTP_PASSWORD");
  const transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: { user: username, pass: password },
  });

  await transporter.sendMail({
    from: `"ClassRealm" <${username}>`,
    to: email,
    subject: "ClassRealm password change verification",
    html: `
      <div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;color:#172033">
        <h2>Verify your password change</h2>
        <p>Hello ${escapeHtml(name)},</p>
        <p>Enter this code in ClassRealm to finish setting your new password:</p>
        <p style="font-size:30px;font-weight:700;letter-spacing:8px">${code}</p>
        <p>This code expires in 60 seconds. If you did not request this change, ignore this message.</p>
      </div>`,
  });
}

async function getFirstLoginAccount(database: ReturnType<typeof createClient>, uid: string) {
  const { data: user, error: userError } = await database
    .from("users")
    .select("id, email, role")
    .eq("id", uid)
    .maybeSingle();
  if (userError) throw userError;
  if (!user || !["teacher", "student"].includes(user.role)) return null;

  const table = user.role === "teacher" ? "teacher_info" : "student_info";
  const idColumn = user.role === "teacher" ? "teacher_id" : "student_id";
  const { data: account, error } = await database
    .from(table)
    .select(user.role === "teacher" ? "status" : "status, student_profile(firstname, lastname)")
    .eq(idColumn, uid)
    .maybeSingle();
  if (error) throw error;
  if (!account) return null;

  const status = String(account.status ?? "").toLowerCase().replace(/[\s_-]/g, "");
  if (!["pendingfirstlogin", "pendingfirstlogon"].includes(status)) return null;
  const profileRaw = account.student_profile;
  const profile = Array.isArray(profileRaw) ? profileRaw[0] : profileRaw;
  const displayName = user.role === "student"
    ? [profile?.firstname, profile?.lastname].filter(Boolean).join(" ")
    : "Teacher";
  return { email: String(user.email), displayName };
}

serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return jsonResponse({ error: "Method not allowed." }, 405);

  try {
    const caller = await requireFirebaseUser(request);
    const database = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
    const account = await getFirstLoginAccount(database, caller.uid);
    if (!account || caller.email?.toLowerCase() !== account.email.toLowerCase()) {
      return jsonResponse({ error: "This account is not awaiting first-login password setup." }, 403);
    }

    const body = await request.json();
    const action = String(body.action ?? "");

    if (action === "send") {
      const code = crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000;
      const codeText = code.toString().padStart(6, "0");
      const { data, error } = await database.rpc("issue_first_login_otp", {
        p_user_id: caller.uid,
        p_code_hash: await hashCode(caller.uid, codeText),
      });
      if (error) throw error;
      const result = data as Record<string, unknown>;

      if (result.issued === true) {
        await sendCode(account.email, account.displayName, codeText);
        return jsonResponse({
          sent: true,
          expiresIn: Number(result.expires_in ?? 60),
          resendAfter: Number(result.resend_after ?? 90),
          resendCount: Number(result.resend_count ?? 0),
        });
      }

      const reason = String(result.reason ?? "rate_limited");
      const retryAfter = Number(result.retry_after ?? 0);
      return jsonResponse({
        sent: false,
        reason,
        retryAfter,
        expiresIn: Number(result.expires_in ?? 0),
        resendCount: Number(result.resend_count ?? 0),
      }, 429);
    }

    if (action === "verify") {
      const code = String(body.code ?? "").trim();
      if (!/^\d{6}$/.test(code)) return jsonResponse({ verified: false, reason: "invalid_format" }, 400);
      const { data, error } = await database.rpc("verify_first_login_otp", {
        p_user_id: caller.uid,
        p_code_hash: await hashCode(caller.uid, code),
      });
      if (error) throw error;
      return jsonResponse(data);
    }

    return jsonResponse({ error: "Unsupported OTP action." }, 400);
  } catch (error) {
    console.error("First-login OTP request failed:", error);
    return jsonResponse({ error: error instanceof Error ? error.message : "OTP request failed." }, 500);
  }
});
