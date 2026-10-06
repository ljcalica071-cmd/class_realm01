import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer";
import { firebaseAdminAuth, requireFirebaseUser } from "../_shared/firebase_admin.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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

function temporaryPassword() {
  const upper = "ABCDEFGHJKLMNPQRSTUVWXYZ";
  const lower = "abcdefghijkmnopqrstuvwxyz";
  const digits = "23456789";
  const all = upper + lower + digits;
  const bytes = crypto.getRandomValues(new Uint8Array(24));
  const characters = [
    upper[bytes[0] % upper.length],
    lower[bytes[1] % lower.length],
    digits[bytes[2] % digits.length],
    ...Array.from(bytes.slice(3), (byte) => all[byte % all.length]),
  ];

  for (let index = characters.length - 1; index > 0; index--) {
    const swapIndex = bytes[index % bytes.length] % (index + 1);
    [characters[index], characters[swapIndex]] = [characters[swapIndex], characters[index]];
  }
  return characters.join("");
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
    const { data: admin, error: adminError } = await database
      .from("users")
      .select("role")
      .eq("id", caller.uid)
      .maybeSingle();
    if (adminError) throw adminError;
    if (admin?.role !== "admin") return jsonResponse({ error: "Only administrators can approve teachers." }, 403);

    const body = await request.json();
    const teacherId = String(body.teacherId ?? "").trim();
    if (!teacherId || teacherId === caller.uid) return jsonResponse({ error: "A valid teacher ID is required." }, 400);

    const { data: teacher, error: teacherError } = await database
      .from("users")
      .select("id, email, role, teacher_info(status), teacher_profile(firstname, lastname)")
      .eq("id", teacherId)
      .maybeSingle();
    if (teacherError) throw teacherError;
    if (!teacher || teacher.role !== "teacher") return jsonResponse({ error: "Teacher account was not found." }, 404);

    const infoRaw = teacher.teacher_info;
    const info = Array.isArray(infoRaw) ? infoRaw[0] : infoRaw;
    if (String(info?.status ?? "").toLowerCase() !== "pending") {
      return jsonResponse({ error: "This teacher account is no longer pending approval." }, 409);
    }

    const profileRaw = teacher.teacher_profile;
    const profile = Array.isArray(profileRaw) ? profileRaw[0] : profileRaw;
    const fullName = [profile?.firstname, profile?.lastname].filter(Boolean).join(" ") || "Teacher";
    const password = temporaryPassword();
    await firebaseAdminAuth().updateUser(teacherId, { password });

    const host = Deno.env.get("SMTP_HOSTNAME") ?? "smtp.gmail.com";
    const port = Number(Deno.env.get("SMTP_PORT") ?? "465");
    const username = requiredEnv("SMTP_USERNAME");
    const smtpPassword = requiredEnv("SMTP_PASSWORD");
    const transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: { user: username, pass: smtpPassword },
    });
    await transporter.sendMail({
      from: `"ClassRealm" <${username}>`,
      to: teacher.email,
      subject: "Your ClassRealm teacher account is approved",
      html: `
        <div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;color:#172033">
          <h2>Welcome to ClassRealm, ${escapeHtml(fullName)}.</h2>
          <p>Your teacher account has been approved. Sign in using:</p>
          <p><strong>Email:</strong> ${escapeHtml(teacher.email)}<br>
          <strong>Temporary password:</strong> ${escapeHtml(password)}</p>
          <p>On your first sign-in, set a new password and verify the change using the code sent to this email.</p>
        </div>`,
    });

    const { error: updateError } = await database
      .from("teacher_info")
      .update({ status: "pending_first_login" })
      .eq("teacher_id", teacherId);
    if (updateError) throw updateError;

    return jsonResponse({ approved: true });
  } catch (error) {
    console.error("Teacher approval failed:", error);
    return jsonResponse({ error: error instanceof Error ? error.message : "Teacher approval failed." }, 500);
  }
});
