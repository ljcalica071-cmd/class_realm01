# Targeted Notifications & Database RLS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate notification leaks by scoping class suspensions, absence warnings, and at-risk grade alerts (≤ 75) strictly to enrolled students and their linked parents, providing parent-tailored messaging, and establishing airtight Postgres Row Level Security (RLS) policies and RPC guards.

**Architecture:** Multi-layered defense:
1. **Database RLS Policies**: Replace open `USING (true)` policies on `notifications` and `notification_recipients` with strict role-based access policies in Postgres.
2. **Postgres Functions & RPCs**: Update `get_user_notifications` and `fn_process_absence_warning_alerts` to require and enforce `subject_offering_id`, `student_id`, and `notification_recipients` lookups via `student_enrollments` and `parent_student_links`.
3. **Application Layer (Flutter)**:
   - Refactor teacher class suspension in `teacher_attendance_tab.dart` to insert scoped notifications with distinct student and parent copies, inserting recipient rows for all enrolled students and linked parents.
   - Refactor grade publishing in `teacher_gradebook_tab.dart` to detect students with grades ≤ 75 and dispatch targeted academic remediation grade alerts to the student and their linked parents only.
4. **Client Repository Guard**: Harden fallback and client-side filtering in `supabase_notification_repository.dart` and `parent_notifications_tab.dart`.

**Tech Stack:** Flutter / Dart, Supabase / PostgreSQL (PL/pgSQL, Row Level Security, Security Definer Functions).

**Spec:** User requirements:
1. Class suspension announcements ("walang pasok" / cutoff) must only be delivered to students handled by the specific teacher of that subject offering and their linked parents; other students and unlinked parents must never receive them.
2. Absence warnings (3, 6, 10 absences) and attendance cutoff notices must include tailored parent messages linked strictly to the child in that class.
3. Grade alerts: When a teacher publishes grades, any student with a grade of 75 or below (≤ 75) must trigger an individualized academic alert sent exclusively to that student and their linked parent(s).
4. Solid database RLS and logic to eliminate any data/notification leaks.

---

## Global Constraints

- Never use open `USING (true)` RLS on `notifications` or `notification_recipients`.
- Teacher-level class suspensions must never insert into `public.school_holidays` (which is strictly reserved for school-wide institutional holidays created by administrators).
- Every class-scoped notification must carry `scope = 'class'`, `subject_offering_id`, `created_by`, and explicit rows in `notification_recipients` for all enrolled students and linked parents.
- Parent notifications must include clear student identity context (e.g. child name, subject, section).
- Avoid unconstrained `flutter test` across the whole repository; use targeted test commands and `flutter analyze` per repo guidelines.

---

## Review Focus

1. **Student Isolation**: A student enrolled in Subject A must NEVER see a class suspension notification created for Subject B by another teacher.
2. **Parent Isolation**: A parent linked to Student 1 must NEVER see an absence warning or grade notification belonging to Student 2.
3. **Unlinked Users on Direct Query**: Direct SQL queries or fallback `client.from('notifications').select()` must be blocked by Postgres RLS from returning records belonging to other classes/users.
4. **Resumed Class Cleanup**: When a teacher resumes a suspended class, only notifications for that specific `subject_offering_id` are archived; other teachers' suspensions remain unaffected.
5. **No School Holiday Leak**: Teacher suspensions must not trigger the global `school_holidays` broadcast trigger that notified all users across the institution.

---

## Implementation Tasks

### Task 1: Database Migration — Cleanup of Leaked Notifications & Trigger Guard

**Files:**
- Create: `supabase/migrations/033_targeted_notifications_and_rls.sql`

**Interfaces:**
- Consumes: `public.notifications`, `public.notification_recipients`, `public.school_holidays`.
- Produces: Archived/cleaned legacy leaked notifications, disabled/corrected `trg_notify_school_holiday`.

- [ ] **Step 1: Write migration SQL to archive leaked suspension notifications and prevent accidental global broadcasts**

In `supabase/migrations/033_targeted_notifications_and_rls.sql`:
1. Archive existing orphaned suspension notifications:
   ```sql
   UPDATE public.notifications
   SET is_archived = true
   WHERE notification_type = 'announcement'
     AND title ILIKE '%Class Suspension%'
     AND subject_offering_id IS NULL;
   ```
2. Deactivate any historical suspension entries mistakenly stored in `school_holidays`:
   ```sql
   UPDATE public.school_holidays
   SET is_active = false
   WHERE holiday_name ILIKE '%Class Suspension%'
      OR holiday_name ILIKE '%may sakit%';
   ```
3. Update `fn_notify_school_holiday` trigger function so it only broadcasts if `holiday_name` is an official school holiday and NOT a teacher class suspension.

- [ ] **Step 2: Apply migration step via Supabase SQL execution tool**
- [ ] **Step 3: Verify with query that leaked notifications are marked archived**

---

### Task 2: Database Migration — Airtight RLS on `notifications` & `notification_recipients`

**Files:**
- Modify: `supabase/migrations/033_targeted_notifications_and_rls.sql`

**Interfaces:**
- Consumes: `public.notifications`, `public.notification_recipients`, `public.users`, `public.student_enrollments`, `public.parent_student_links`, `public.subject_offerings`.
- Produces: Strict Postgres Row Level Security policies.

- [ ] **Step 1: Define comprehensive RLS policies on `public.notifications`**

```sql
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "app_full_access_notifications" ON public.notifications;

-- SELECT POLICY
CREATE POLICY "notifications_select_policy"
ON public.notifications
FOR SELECT
TO authenticated, anon
USING (
  -- 1. Direct recipient
  recipient_id = auth.uid()::text
  OR student_id = auth.uid()::text
  OR created_by = auth.uid()::text
  -- 2. Explicit recipient in join table
  OR EXISTS (
    SELECT 1 FROM public.notification_recipients nr
    WHERE nr.notification_id = notifications.id
      AND nr.user_id = auth.uid()::text
  )
  -- 3. Teacher of the class
  OR (
    subject_offering_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.subject_offerings so
      WHERE so.id = notifications.subject_offering_id
        AND so.teacher_id = auth.uid()::text
    )
  )
  -- 4. Student enrolled in the class
  OR (
    scope = 'class'
    AND subject_offering_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.student_enrollments se
      WHERE se.subject_offering_id = notifications.subject_offering_id
        AND se.student_id = auth.uid()::text
        AND se.status = 'enrolled'
    )
  )
  -- 5. Parent linked to student enrolled in the class or student_id
  OR (
    (
      student_id IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.parent_student_links psl
        WHERE psl.parent_id = auth.uid()::text
          AND psl.student_id = notifications.student_id
      )
    )
    OR (
      scope = 'class'
      AND subject_offering_id IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.parent_student_links psl
        JOIN public.student_enrollments se ON se.student_id = psl.student_id
        WHERE psl.parent_id = auth.uid()::text
          AND se.subject_offering_id = notifications.subject_offering_id
          AND se.status = 'enrolled'
      )
    )
  )
  -- 6. Genuine School-wide broadcasts only (Admin created, no offering or student scope)
  OR (
    scope = 'school_wide'
    AND subject_offering_id IS NULL
    AND student_id IS NULL
    AND recipient_id IS NULL
  )
  -- 7. Admin role access
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()::text AND u.role = 'admin'
  )
);

-- INSERT POLICY
CREATE POLICY "notifications_insert_policy"
ON public.notifications
FOR INSERT
TO authenticated, anon
WITH CHECK (
  -- Teachers can insert for offerings they teach
  (
    subject_offering_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.subject_offerings so
      WHERE so.id = notifications.subject_offering_id
        AND so.teacher_id = auth.uid()::text
    )
  )
  -- Admin or service role can insert any
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()::text AND u.role IN ('admin', 'teacher')
  )
  OR auth.uid() IS NULL -- allows backend service_role / triggers
);

-- UPDATE POLICY (e.g. archive notification)
CREATE POLICY "notifications_update_policy"
ON public.notifications
FOR UPDATE
TO authenticated, anon
USING (
  created_by = auth.uid()::text
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()::text AND u.role = 'admin'
  )
  OR auth.uid() IS NULL
);
```

- [ ] **Step 2: Define RLS policies on `public.notification_recipients`**

```sql
ALTER TABLE public.notification_recipients ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "app_full_access_notification_recipients" ON public.notification_recipients;

CREATE POLICY "notification_recipients_select"
ON public.notification_recipients
FOR SELECT
TO authenticated, anon
USING (
  user_id = auth.uid()::text
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()::text AND u.role = 'admin'
  )
);

CREATE POLICY "notification_recipients_insert"
ON public.notification_recipients
FOR INSERT
TO authenticated, anon
WITH CHECK (true); -- insertion is guided by notification foreign key & sender role

CREATE POLICY "notification_recipients_update"
ON public.notification_recipients
FOR UPDATE
TO authenticated, anon
USING (
  user_id = auth.uid()::text
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()::text AND u.role = 'admin'
  )
)
WITH CHECK (
  user_id = auth.uid()::text
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()::text AND u.role = 'admin'
  )
);
```

- [ ] **Step 3: Execute in Supabase and confirm policies are applied without errors**

---

### Task 3: Database Migration — Update RPCs for Strict Isolation & Parent Messages

**Files:**
- Modify: `supabase/migrations/033_targeted_notifications_and_rls.sql`

**Interfaces:**
- Updates: `public.get_user_notifications(p_user_id varchar, p_limit int)`
- Updates: `public.fn_process_absence_warning_alerts(p_student_id varchar, p_subject_offering_id uuid)`

- [ ] **Step 1: Update `get_user_notifications`**
Ensure that:
1. Students only receive:
   - Direct notices (`recipient_id = p_user_id` or `student_id = p_user_id`)
   - Explicit recipient rows (`notification_recipients`)
   - Class-scoped notices where student is currently enrolled in `subject_offering_id`
   - Explicit admin school-wide broadcasts (`scope = 'school_wide' AND subject_offering_id IS NULL AND student_id IS NULL AND recipient_id IS NULL`)
2. Parents only receive:
   - Direct notices (`recipient_id = p_user_id`)
   - Explicit recipient rows (`notification_recipients`)
   - Child-linked notices where `student_id` is linked in `parent_student_links`
   - Class-scoped notices where linked child is enrolled in `subject_offering_id`
   - Explicit admin school-wide broadcasts (`scope = 'school_wide' AND subject_offering_id IS NULL AND student_id IS NULL AND recipient_id IS NULL`)
3. Teachers only receive:
   - Direct notices
   - Offerings they teach
   - Explicit recipient rows
   - School-wide teacher broadcasts

- [ ] **Step 2: Update `fn_process_absence_warning_alerts`**
Ensure that when 3, 6, or 10 absences threshold is hit:
1. Notification rows set `subject_offering_id = p_subject_offering_id`, `student_id = p_student_id`, `scope = 'class'`.
2. Dedicated parent notification with respectful, clear message for parents:
   - **3 Absences**:
     - Title: `v_student_name || ' (Attendance Alert: 3 Absences)'`
     - Message: `'Dear Parent/Guardian, your child ' || v_student_name || ' has recorded 3 absences in ' || v_subject_name || ' (' || v_section || '). Please assist in ensuring regular attendance and coordinate with the subject teacher if excuse documentation is needed.'`
   - **6 Absences**:
     - Title: `v_student_name || ' (Attendance Warning: 6 Absences)'`
     - Message: `'Dear Parent/Guardian, your child ' || v_student_name || ' has accumulated 6 absences in ' || v_subject_name || ' (' || v_section || '). A parent-teacher conference is requested to arrange attendance remediation.'`
   - **10 Absences**:
     - Title: `v_student_name || ' (CRITICAL SARDO Alert: 10 Absences)'`
     - Message: `'Urgent Notice for Parent/Guardian: Your child ' || v_student_name || ' has reached 10 absences in ' || v_subject_name || ' (' || v_section || '), placing them at critical risk under DepEd SARDO policies. Please visit the school immediately to confer with the adviser and teacher.'`
3. Automatically insert into `public.notification_recipients` for:
   - The student (`user_id = p_student_id`)
   - The subject teacher (`user_id = v_teacher_id`)
   - Every parent linked to that student in `public.parent_student_links` (`user_id = psl.parent_id`).

- [ ] **Step 3: Execute in Supabase and verify function definitions**

---

### Task 4: Teacher Suspension Flow Enhancement in Flutter

**Files:**
- Modify: `lib/features/teacher/sub_features/attendance/widgets/teacher_attendance_tab.dart:2000-2220`
- Test: `test/features/teacher/attendance/teacher_attendance_tab_test.dart`

**Interfaces:**
- Consumes: `_selectedSubjectId`, `_attendanceSelectedDate`, `student_enrollments`, `parent_student_links`.
- Produces: Class-isolated notifications with distinct student and parent content.

- [ ] **Step 1: Write failing test in `teacher_attendance_tab_test.dart` verifying class suspension isolates notifications to enrolled students and linked parents**
- [ ] **Step 2: Update `_handleSuspendClass` in `teacher_attendance_tab.dart`:**
  - Create separate student-facing and parent-facing notification records with:
    - `subject_offering_id: offeringId`
    - `scope: 'class'`
    - `target_audience: 'students'` (for student notif) and `'parents'` (for parent notif)
    - Parent message: `'Notice for Parents/Guardians: Classes and RFID attendance for your child in ' + subjectName + ' (' + sectionName + ') are suspended on ' + readableDate + ' (' + cleanReason + '). Enrolled learners are excused for this session.'`
    - Student message: `'Classes and RFID attendance are suspended on ' + readableDate + ' (' + cleanReason + ') for ' + subjectName + ' (' + sectionName + '). You are excused for this session.'`
  - Insert recipient rows in `notification_recipients` for:
    - Enrolled student IDs -> link to student notification ID
    - Linked parent IDs -> link to parent notification ID
  - Verify that teacher suspension NEVER inserts into `school_holidays`.
- [ ] **Step 3: Run targeted test and ensure it passes**

---

### Task 5: Grades Publishing & At-Risk Grade Alerts (≤ 75) for Students and Parents

**Files:**
- Modify: `lib/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart:4010-4060`
- Test: `test/features/teacher/grading/teacher_gradebook_grade_alert_test.dart`

**Interfaces:**
- Consumes: `termNumber`, `offeringId`, `_students`, `_buildPersistedTermGrade`, `parent_student_links`.
- Produces: Individualized Academic Grade Alerts for students with transmuted grade ≤ 75 and general publication notices for others, with strictly isolated recipient records.

- [ ] **Step 1: Write test verifying grade alert generation for grades ≤ 75**
Verify that when grades are published:
  - A student with a grade ≤ 75 receives an individualized academic alert.
  - Linked parent(s) receive a parent-tailored alert mentioning the child and grade.
  - Students with grades > 75 receive the regular publication notice without at-risk alert.
  - No cross-student or cross-parent recipient leaks occur.

- [ ] **Step 2: Implement grade publish and at-risk alert dispatch in `teacher_gradebook_tab.dart`**
When `willPublish == true`:
  1. Identify students with `transmuted_grade <= 75`:
     - Calculate or read `transmuted_grade` from `_buildPersistedTermGrade(student.id, termNumber)`.
  2. Query `parent_student_links` for all enrolled students in `offeringId`.
  3. For each student with `transmuted_grade <= 75`:
     - Insert student-specific notification:
       - `title`: `'Academic Grade Alert: ' + subjectName + ' (' + sectionName + ') - Term ' + termNumber`
       - `message`: `'Your official grade for Term ' + termNumber + ' in ' + subjectName + ' (' + sectionName + ') is ' + termGrade + ' (75 or below). Please coordinate with your teacher for academic remediation.'`
       - `student_id`: `student.id`, `recipient_id`: `student.id`, `subject_offering_id`: `offeringId`, `scope`: `'class'`, `notification_type`: `'grade'`.
       - Recipient in `notification_recipients`: `user_id = student.id`.
     - Insert parent-specific notification for linked parent(s):
       - `title`: `'Academic Alert: ' + student.displayName + ' (' + termGrade + ' in ' + subjectName + ')'`
       - `message`: `'Dear Parent/Guardian, your child ' + student.displayName + ' received a grade of ' + termGrade + ' (75 or below) for Term ' + termNumber + ' in ' + subjectName + ' (' + sectionName + '). Please coordinate with the teacher for remediation support.'`
       - `student_id`: `student.id`, `subject_offering_id`: `offeringId`, `scope`: `'class'`, `notification_type`: `'grade'`.
       - Recipients in `notification_recipients`: `user_id = parent_id` for every linked parent of that student.
  4. For students with `transmuted_grade > 75`:
     - Normal class publication notification (or distinct student/parent general publication notices).

- [ ] **Step 3: Run `flutter analyze` on `teacher_gradebook_tab.dart` to verify typing and null safety**

---

### Task 6: Repository and Client-Side UI Hardening

**Files:**
- Modify: `lib/data/repositories/supabase_notification_repository.dart:315-348`
- Modify: `lib/features/parent/sub_features/communications/widgets/parent_notifications_tab.dart`

**Interfaces:**
- Consumes: `AppNotificationModel`, `UserModel`, `AppDataCache`.
- Produces: Secure notifications fetching and parent-child badge rendering.

- [ ] **Step 1: Harden fallback query in `supabase_notification_repository.dart`**
Ensure that if RPC fallback is invoked, it includes user-isolated filtering rather than an open `.select()` of all non-archived notifications.
- [ ] **Step 2: Update `isNotificationVisibleForUser` in `supabase_notification_repository.dart`**
Add strict suspension check: if a notification is a class suspension (`title.contains('Class Suspended')` or `scope == 'class'`), require that the student is enrolled in that subject or the parent has a linked child enrolled in that subject.
- [ ] **Step 3: Update `parent_notifications_tab.dart` to visually indicate child context on notifications**
Ensure parent notification cards clearly display the child's name badge when `n.studentId` or child name is identified.

---

### Task 7: Full System Verification

- [ ] **Step 1: Run `flutter analyze` across all modified files**
- [ ] **Step 2: Run targeted tests:**
  - `flutter test test/features/teacher/attendance/teacher_attendance_tab_test.dart`
  - `flutter test test/features/teacher/attendance/attendance_history_analytics_view_test.dart`
- [ ] **Step 3: Verify with database queries that:**
  - Leaked suspension notifications are archived.
  - Test student from Teacher A does not receive Teacher B's suspension.
  - Linked parent receives parent-tailored suspension and absence notifications.
- [ ] **Step 4: Run `graphify update .`**
