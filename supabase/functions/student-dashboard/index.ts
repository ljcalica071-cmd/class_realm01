import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
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

    const { data: user, error: userError } = await database
      .from("users")
      .select("id, email, role")
      .eq("id", caller.uid)
      .maybeSingle();
    if (userError) throw userError;
    if (!user || user.role !== "student") {
      return jsonResponse({ error: "A student account is required." }, 403);
    }

    const { data: info, error: infoError } = await database
      .from("student_info")
      .select("student_id, lrn, email, status, student_profile(firstname, middlename, lastname, birthday, gender)")
      .eq("student_id", caller.uid)
      .maybeSingle();
    if (infoError) throw infoError;
    if (!info) return jsonResponse({ error: "Student profile was not found." }, 404);

    const profileRaw = info.student_profile;
    const profile = Array.isArray(profileRaw) ? profileRaw[0] : profileRaw;

    const { data: enrollmentRows, error: enrollmentError } = await database
      .from("student_enrollments")
      .select("subject_id, subjects!inner(id, subject_name, section_name, grade_level)")
      .eq("student_id", caller.uid)
      .eq("status", "Enrolled");
    if (enrollmentError) throw enrollmentError;

    const enrollments = (enrollmentRows ?? []).map((row) => {
      const subjectRaw = row.subjects;
      const subject = Array.isArray(subjectRaw) ? subjectRaw[0] : subjectRaw;
      return {
        subject_id: row.subject_id,
        subject_name: subject?.subject_name ?? "",
        section_name: subject?.section_name ?? "",
        grade_level: subject?.grade_level ?? "",
      };
    });
    const subjectIds = [...new Set(enrollments.map((row) => String(row.subject_id)))];

    let classwork: Record<string, unknown>[] = [];
    if (subjectIds.length > 0) {
      const { data: items, error: classworkError } = await database
        .from("classwork_items")
        .select("id, classwork_type, title, description, instructions, assigned_at, deadline, max_score, subjects!inner(subject_name, section_name, grade_level)")
        .in("subject_id", subjectIds)
        .eq("is_published", true)
        .order("deadline", { ascending: true, nullsFirst: false });
      if (classworkError) throw classworkError;

      const itemIds = (items ?? []).map((item) => String(item.id));
      let submissionByItem = new Map<string, Record<string, unknown>>();
      if (itemIds.length > 0) {
        const { data: submissions, error: submissionsError } = await database
          .from("student_classwork_submissions")
          .select("classwork_id, status, score, feedback")
          .eq("student_id", caller.uid)
          .in("classwork_id", itemIds);
        if (submissionsError) throw submissionsError;
        submissionByItem = new Map(
          (submissions ?? []).map((submission) => [
            String(submission.classwork_id),
            submission as Record<string, unknown>,
          ]),
        );
      }

      classwork = (items ?? []).map((item) => {
        const subjectRaw = item.subjects;
        const subject = Array.isArray(subjectRaw) ? subjectRaw[0] : subjectRaw;
        return {
          id: item.id,
          classwork_type: item.classwork_type,
          title: item.title,
          description: item.description,
          instructions: item.instructions,
          assigned_at: item.assigned_at,
          deadline: item.deadline,
          max_score: item.max_score,
          subject: subject ?? {},
          submission: submissionByItem.get(String(item.id)),
        };
      });
    }

    return jsonResponse({
      student: {
        id: info.student_id,
        lrn: info.lrn,
        email: info.email ?? user.email,
        status: info.status,
        first_name: profile?.firstname ?? "",
        middle_name: profile?.middlename ?? "",
        last_name: profile?.lastname ?? "",
        birthday: profile?.birthday ?? null,
        gender: profile?.gender ?? null,
        enrollments,
      },
      classwork,
    });
  } catch (error) {
    console.error("Student dashboard request failed:", error);
    const message = error instanceof Error ? error.message : "Unable to load student dashboard.";
    const status = message.toLowerCase().includes("sign-in") ? 401 : 500;
    return jsonResponse({ error: message }, status);
  }
});
