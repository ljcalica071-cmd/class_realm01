import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer";
import { requireFirebaseUser } from "../_shared/firebase_admin.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-firebase-token, x-firebase-api-key",
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

function makeTemporaryPassword() {
  const bytes = crypto.getRandomValues(new Uint8Array(24));
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
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

async function sendCredentials(
  email: string,
  fullName: string,
  lrn: string,
  temporaryPassword: string,
) {
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
    subject: "Your ClassRealm student account",
    html: `
      <div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;color:#172033">
        <h2>Welcome to ClassRealm, ${escapeHtml(fullName)}.</h2>
        <p>Your teacher created your student account. Sign in with these temporary credentials:</p>
        <p><strong>Email:</strong> ${escapeHtml(email)}<br>
        <strong>LRN:</strong> ${escapeHtml(lrn)}<br>
        <strong>Temporary password:</strong> ${escapeHtml(temporaryPassword)}</p>
        <p>On your first sign-in, you must set a new password and verify the change using a code sent to this email.</p>
      </div>`,
  });
}

serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return jsonResponse({ error: "Method not allowed." }, 405);

  let firebaseUid: string | undefined;
  let createdStudentUid: string | undefined;
  let database: ReturnType<typeof createClient> | undefined;
  let credentialsEmail: {
    email: string;
    fullName: string;
    lrn: string;
    temporaryPassword: string;
  } | undefined;

  try {
    const caller = await requireFirebaseUser(request);
    firebaseUid = caller.uid;
    const body = await request.json();
    const lrn = String(body.lrn ?? "").trim();
    const firstName = String(body.firstName ?? "").trim();
    const middleName = String(body.middleName ?? "").trim();
    const lastName = String(body.lastName ?? "").trim();
    const birthday = String(body.birthday ?? "").trim();
    const email = String(body.email ?? "").trim().toLowerCase();
    const gender = String(body.gender ?? "").trim();
    const subjectId = String(body.subjectId ?? "").trim();

    if (!/^\d{12}$/.test(lrn)) return jsonResponse({ error: "LRN must be exactly 12 digits." }, 400);
    if (firstName.length < 2 || lastName.length < 2) return jsonResponse({ error: "Enter a valid student name." }, 400);
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return jsonResponse({ error: "Enter a valid student email address." }, 400);
    if (!["Male", "Female"].includes(gender)) return jsonResponse({ error: "Select a valid gender." }, 400);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(birthday) || Number.isNaN(Date.parse(birthday))) {
      return jsonResponse({ error: "Enter a valid student birthday." }, 400);
    }
    if (!/^[0-9a-f-]{36}$/i.test(subjectId)) return jsonResponse({ error: "Select a valid subject and section." }, 400);

    database = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false, autoRefreshToken: false } },
    );

    const { data: teacher, error: teacherError } = await database
      .from("users")
      .select("id, role")
      .eq("id", firebaseUid)
      .maybeSingle();
    if (teacherError) throw teacherError;
    if (!teacher || teacher.role !== "teacher") return jsonResponse({ error: "Only a teacher can create student enrollments." }, 403);

    const { data: teacherStatus, error: statusError } = await database
      .from("teacher_info")
      .select("status")
      .eq("teacher_id", firebaseUid)
      .maybeSingle();
    if (statusError) throw statusError;
    if (!teacherStatus || !["active", "Active"].includes(String(teacherStatus.status))) {
      return jsonResponse({ error: "Only active teachers can create student enrollments." }, 403);
    }

    const { data: subject, error: subjectError } = await database
      .from("subjects")
      .select("id, teacher_id, subject_name, section_name")
      .eq("id", subjectId)
      .maybeSingle();
    if (subjectError) throw subjectError;
    if (!subject || subject.teacher_id !== firebaseUid) {
      return jsonResponse({ error: "You can only enroll students in your own subject and section." }, 403);
    }

    const { data: existingStudent, error: existingStudentError } = await database
      .from("student_info")
      .select("student_id, lrn, email, student_profile(firstname, lastname)")
      .eq("lrn", lrn)
      .maybeSingle();
    if (existingStudentError) throw existingStudentError;

    let studentUid: string;
    let createdAccount = false;

    if (existingStudent) {
      const rawProfile = existingStudent.student_profile;
      const profile = Array.isArray(rawProfile) ? rawProfile[0] : rawProfile;
      if (
        String(profile?.firstname ?? "").toLowerCase() !== firstName.toLowerCase() ||
        String(profile?.lastname ?? "").toLowerCase() !== lastName.toLowerCase()
      ) {
        return jsonResponse({ error: "The LRN matches a student, but the name does not. Verify the LRN and student details." }, 409);
      }
      if (String(existingStudent.email ?? "").toLowerCase() !== email) {
        return jsonResponse({ error: "This LRN already has an account with a different email. Use the existing student account email." }, 409);
      }
      studentUid = String(existingStudent.student_id);

      const { data: linkedUser, error: linkedUserError } = await database
        .from("users")
        .select("role")
        .eq("id", studentUid)
        .maybeSingle();
      if (linkedUserError) throw linkedUserError;
      if (!linkedUser || linkedUser.role !== "student") {
        return jsonResponse({ error: "The existing student account is incomplete. Contact an administrator." }, 409);
      }
    } else {
      const { data: emailOwner, error: emailError } = await database
        .from("users")
        .select("id, role")
        .eq("email", email)
        .maybeSingle();
      if (emailError) throw emailError;
      if (emailOwner) return jsonResponse({ error: "This email is already registered to another account." }, 409);

      const formattedLastName = lastName.replace(/\s+/g, "").toLowerCase();
      const formattedBirthday = birthday.replace(/-/g, "");
      const temporaryPassword = `${formattedLastName}${formattedBirthday}`;
      const fullName = [firstName, middleName, lastName].filter(Boolean).join(" ");
      
      const apiKey = request.headers.get("x-firebase-api-key") ?? Deno.env.get("FIREBASE_API_KEY");
      if (!apiKey) throw new Error("Firebase API Key is missing.");

      const signUpRes = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password: temporaryPassword, returnSecureToken: true })
      });
      const signUpData = await signUpRes.json();
      if (!signUpRes.ok) throw new Error(signUpData.error?.message || "Failed to create Firebase user");
      
      studentUid = signUpData.localId;
      createdStudentUid = studentUid;

      // Update Display Name
      await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:update?key=${apiKey}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ idToken: signUpData.idToken, displayName: fullName })
      });

      const { error: userInsertError } = await database.from("users").insert({
        id: studentUid,
        email,
        role: "student",
      });
      if (userInsertError) throw userInsertError;

      const { error: infoInsertError } = await database.from("student_info").insert({
        student_id: studentUid,
        lrn,
        email,
        status: "pending_first_login",
      });
      if (infoInsertError) throw infoInsertError;

      const { error: profileInsertError } = await database.from("student_profile").insert({
        student_id: studentUid,
        firstname: firstName,
        middlename: middleName || null,
        lastname: lastName,
        birthday,
        gender,
      });
      if (profileInsertError) throw profileInsertError;

      credentialsEmail = { email, fullName, lrn, temporaryPassword };
      createdAccount = true;
    }

    const { error: enrollmentError } = await database.from("student_enrollments").insert({
      student_id: studentUid,
      subject_id: subjectId,
      status: "Enrolled",
    });
    if (enrollmentError) {
      if (enrollmentError.code === "23505") {
        if (createdStudentUid) {
          await database.from("users").delete().eq("id", createdStudentUid);
          
          const apiKey = request.headers.get("x-firebase-api-key") ?? Deno.env.get("FIREBASE_API_KEY");
          if (apiKey) {
             await fetch(`https://identitytoolkit.googleapis.com/v1/projects/classrealm01/accounts/${createdStudentUid}?key=${apiKey}`, {
               method: "DELETE"
             }).catch(() => {});
          }
          createdStudentUid = undefined;
        }
        return jsonResponse({ error: "Student is already enrolled in this subject and section." }, 409);
      }
      throw enrollmentError;
    }

    if (credentialsEmail) {
      await sendCredentials(
        credentialsEmail.email,
        credentialsEmail.fullName,
        credentialsEmail.lrn,
        credentialsEmail.temporaryPassword,
      );
    }

    return jsonResponse({ studentId: studentUid, createdAccount, emailSent: createdAccount });
  } catch (error) {
    if (createdStudentUid) {
      if (database) await database.from("users").delete().eq("id", createdStudentUid);
      const apiKey = request.headers.get("x-firebase-api-key") ?? Deno.env.get("FIREBASE_API_KEY");
      if (apiKey) {
         await fetch(`https://identitytoolkit.googleapis.com/v1/projects/classrealm01/accounts/${createdStudentUid}?key=${apiKey}`, {
           method: "DELETE"
         }).catch((cleanupError) => {
           console.error("Could not remove incomplete Firebase student account:", cleanupError);
         });
      }
    }
    console.error("Student provisioning failed:", error);
    return jsonResponse({ error: error instanceof Error ? error.message : "Student provisioning failed." }, 500);
  }
});
