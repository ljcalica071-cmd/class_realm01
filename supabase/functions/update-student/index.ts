import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { firebaseAdminAuth, requireFirebaseUser } from "../_shared/firebase_admin.ts";

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

serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return jsonResponse({ error: "Method not allowed." }, 405);

  try {
    const caller = await requireFirebaseUser(request);
    const body = await request.json();
    const studentId = String(body.studentId ?? "").trim();
    const subjectId = String(body.subjectId ?? "").trim();
    const lrn = String(body.lrn ?? "").trim();
    const firstName = String(body.firstName ?? "").trim();
    const middleName = String(body.middleName ?? "").trim();
    const lastName = String(body.lastName ?? "").trim();
    const email = String(body.email ?? "").trim().toLowerCase();
    const gender = String(body.gender ?? "").trim();
    const birthday = String(body.birthday ?? "").trim();

    if (!studentId || !/^[0-9a-f-]{36}$/i.test(subjectId)) {
      return jsonResponse({ error: "The student or enrollment could not be identified." }, 400);
    }
    if (!/^\d{12}$/.test(lrn)) return jsonResponse({ error: "LRN must be exactly 12 digits." }, 400);
    if (firstName.length < 2 || firstName.length > 30 || lastName.length < 2 || lastName.length > 30) {
      return jsonResponse({ error: "Enter a valid student name." }, 400);
    }
    if (middleName.length > 30) return jsonResponse({ error: "Middle name must be 30 characters or fewer." }, 400);
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return jsonResponse({ error: "Enter a valid student email address." }, 400);
    }
    if (!["Male", "Female"].includes(gender)) return jsonResponse({ error: "Select a valid gender." }, 400);
    const dateMatch = /^(\d{4})-(\d{2})-(\d{2})$/.exec(birthday);
    if (!dateMatch) return jsonResponse({ error: "Enter a valid student birthday." }, 400);
    const birthdayDate = new Date(`${birthday}T00:00:00.000Z`);
    if (
      Number.isNaN(birthdayDate.getTime()) ||
      birthdayDate.toISOString().slice(0, 10) !== birthday
    ) {
      return jsonResponse({ error: "Enter a valid student birthday." }, 400);
    }
    const minimumBirthday = new Date();
    minimumBirthday.setUTCFullYear(minimumBirthday.getUTCFullYear() - 10);
    if (birthdayDate > minimumBirthday) {
      return jsonResponse({ error: "Student must be at least 10 years old." }, 400);
    }

    const database = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
    const { data: teacher, error: teacherError } = await database
      .from("users")
      .select("role")
      .eq("id", caller.uid)
      .maybeSingle();
    if (teacherError) throw teacherError;
    if (!teacher || teacher.role !== "teacher") {
      return jsonResponse({ error: "Only a teacher can update student accounts." }, 403);
    }

    const { data: teacherStatus, error: statusError } = await database
      .from("teacher_info")
      .select("status")
      .eq("teacher_id", caller.uid)
      .maybeSingle();
    if (statusError) throw statusError;
    if (!teacherStatus || !["active", "Active"].includes(String(teacherStatus.status))) {
      return jsonResponse({ error: "Only active teachers can update student accounts." }, 403);
    }

    const { data: enrollment, error: enrollmentError } = await database
      .from("student_enrollments")
      .select("student_id, subjects!inner(teacher_id)")
      .eq("student_id", studentId)
      .eq("subject_id", subjectId)
      .eq("status", "Enrolled")
      .eq("subjects.teacher_id", caller.uid)
      .maybeSingle();
    if (enrollmentError) throw enrollmentError;
    if (!enrollment) {
      return jsonResponse({ error: "You can only update students enrolled in your own subject and section." }, 403);
    }

    const auth = firebaseAdminAuth();
    const originalAccount = await auth.getUser(studentId);
    const fullName = [firstName, middleName, lastName].filter(Boolean).join(" ");
    const emailChanged = originalAccount.email?.toLowerCase() !== email;
    await auth.updateUser(studentId, {
      email,
      displayName: fullName,
      ...(emailChanged ? { emailVerified: false } : {}),
    });

    try {
      const { error } = await database.rpc("update_student_profile", {
        p_student_id: studentId,
        p_lrn: lrn,
        p_email: email,
        p_first_name: firstName,
        p_middle_name: middleName || null,
        p_last_name: lastName,
        p_gender: gender,
        p_birthday: birthday,
      });
      if (error) throw error;
    } catch (error) {
      try {
        await auth.updateUser(studentId, {
          ...(originalAccount.email ? { email: originalAccount.email } : {}),
          ...(originalAccount.displayName ? { displayName: originalAccount.displayName } : {}),
          emailVerified: originalAccount.emailVerified,
        });
      } catch (rollbackError) {
        throw new Error(
          `Student database update failed and Firebase account rollback failed: ${String(rollbackError)}. Original error: ${String(error)}`,
        );
      }
      throw error;
    }

    return jsonResponse({ updated: true });
  } catch (error) {
    console.error("Student update failed:", error);
    return jsonResponse({ error: error instanceof Error ? error.message : "Student update failed." }, 400);
  }
});
