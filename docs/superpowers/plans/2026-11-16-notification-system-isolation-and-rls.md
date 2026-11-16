# Complete Multi-Tenant Notification Isolation & Row-Level Security (RLS) Master Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permanently resolve cross-user notification leakage across all user roles (Teacher, Student, Parent) by replacing insecure client-side string/regex filtering with strict Supabase Postgres Row-Level Security (RLS) policies and relational foreign-key scoping (`recipient_id`, `subject_offering_id`, `student_id`).

**Architecture:**
- **Database Level (Zero-Trust Enforcement):** Foreign keys `recipient_id`, `subject_offering_id`, `student_id`, and `scope` on `public.notifications`. Native Postgres RLS policies evaluate `auth.uid()` against user IDs, subject offerings, and `parent_student_links`.
- **Backend / Repository Dispatchers:** Every notification event (attendance warning, assessment assigned, exam scheduled, grade published) explicitly resolves and sets `recipient_id`, `subject_offering_id`, and `student_id`.
- **Client Queries & Realtime:** Clients query only scoped rows. Delete all fragile client-side text parsing (`isNotificationVisibleForUser`). Realtime channels listen with server-side filters.

---

## 1. Concrete Proof & Personas (How the Leak Happened vs. How It Will Be Prevented)

### Concrete Scenario:
- **Teacher 1:** Sir Naruto Uzumaki (Teaches *Art Criticism and Creative Markets, Section 1*)
- **Teacher 2:** Teacher Naki Naga (Teaches *Mabisang Komunikasyon, Section 1*)
- **Student A:** Ian Villanueva (Enrolled in Sir Naruto's class, linked to **Parent A: Mrs. Villanueva**)
- **Student B:** Juana Dela Cruz (Enrolled in Teacher Naki's class, linked to **Parent B: Mr. Dela Cruz**)

| Event | Current System (The Bug) | Target System (The Fix) |
|---|---|---|
| **Ian Villanueva gets 3 absences** | Notification inserted with `target_audience: 'teachers'`. **NO `recipient_id`**. | Notification inserted with `recipient_id: naruto_id`, `subject_offering_id: art_offering_id`, `student_id: ian_id`. |
| **Teacher Naki opens app** | App downloads **ALL** teacher notifications via `.inFilter('target_audience', ['teachers'])`. Client regex leaks Ian's alert to Teacher Naki during initial loading. | Postgres RLS checks: Is Teacher Naki the recipient? **NO**. Is Teacher Naki the teacher of Art Criticism? **NO**. **Postgres returns 0 rows.** |
| **Student B (Juana) opens app** | App queries all student notifications. If message doesn't match specific keyword or regex fails, Student B sees Student A's alert. | Postgres RLS checks: Is `recipient_id == juana_id`? **NO**. **Postgres returns 0 rows. Juana cannot see Ian's alert.** |
| **Parent B (Mr. Dela Cruz) opens app** | App queries all parent alerts. Client regex checks if child's name is in string. If loading or multiple kids, Parent B sees Ian's warning. | Postgres RLS checks: Is Ian Villanueva in `parent_student_links` for Mr. Dela Cruz? **NO.** **Postgres returns 0 rows. Parent B sees only Juana's alerts.** |

---

## 2. Supabase Database Schema Migration

```sql
-- 1. Add Relational Foreign Keys to notifications table
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS recipient_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS subject_offering_id UUID REFERENCES public.subject_offerings(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS scope VARCHAR(20) DEFAULT 'individual' CHECK (scope IN ('individual', 'class', 'role', 'school_wide'));

-- 2. Performance Indexes (Essential for instant query speeds)
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_id 
  ON public.notifications(recipient_id);

CREATE INDEX IF NOT EXISTS idx_notifications_offering_id 
  ON public.notifications(subject_offering_id);

CREATE INDEX IF NOT EXISTS idx_notifications_student_id 
  ON public.notifications(student_id);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient_created 
  ON public.notifications(recipient_id, created_at DESC);
```

---

## 3. Postgres Row-Level Security (RLS) Policies

All security checks happen on the PostgreSQL database engine. Client code cannot bypass this.

```sql
-- Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Drop legacy leaky policies if any
DROP POLICY IF EXISTS "Allow all authenticated users" ON public.notifications;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.notifications;

-- =========================================================================
-- 1. STUDENT POLICY: Only their own notifications or enrolled classes
-- =========================================================================
CREATE POLICY "student_notifications_isolation_policy"
ON public.notifications
FOR SELECT
TO authenticated
USING (
  -- Must be signed in as this student
  recipient_id = (SELECT auth.uid())
  OR
  -- Or class notification where student is actively enrolled
  (
    scope = 'class' AND
    subject_offering_id IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.student_enrollments se
      WHERE se.subject_offering_id = notifications.subject_offering_id
      AND se.student_id = (SELECT auth.uid())
      AND se.status = 'enrolled'
    )
  )
  OR
  -- Or school-wide announcements
  (
    scope = 'school_wide' AND
    target_audience IN ('students', 'all')
  )
);

-- =========================================================================
-- 2. PARENT POLICY: Only their own notifications or verified linked children
-- =========================================================================
CREATE POLICY "parent_notifications_isolation_policy"
ON public.notifications
FOR SELECT
TO authenticated
USING (
  -- Directly addressed to parent
  recipient_id = (SELECT auth.uid())
  OR
  -- Or concerning their verified linked student in parent_student_links
  (
    student_id IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.parent_student_links psl
      WHERE psl.parent_id = (SELECT auth.uid())
      AND psl.student_id = notifications.student_id
    )
  )
  OR
  -- Or school-wide announcements
  (
    scope = 'school_wide' AND
    target_audience IN ('parents', 'all')
  )
);

-- =========================================================================
-- 3. TEACHER POLICY: Only their own notifications or their own classes
-- =========================================================================
CREATE POLICY "teacher_notifications_isolation_policy"
ON public.notifications
FOR SELECT
TO authenticated
USING (
  -- Directly addressed to teacher
  recipient_id = (SELECT auth.uid())
  OR
  -- Or class notification for a subject taught by this teacher
  (
    subject_offering_id IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.subject_offerings so
      WHERE so.id = notifications.subject_offering_id
      AND so.teacher_id = (SELECT auth.uid())
    )
  )
  OR
  -- Or school-wide announcements
  (
    scope IN ('role', 'school_wide') AND
    target_audience IN ('teachers', 'all')
  )
);

-- =========================================================================
-- 4. UPDATE POLICY: Users can only mark their own notifications as read
-- =========================================================================
CREATE POLICY "users_mark_read_own_notifications"
ON public.notifications
FOR UPDATE
TO authenticated
USING (
  recipient_id = (SELECT auth.uid())
  OR
  EXISTS (
    SELECT 1 FROM public.notification_recipients nr
    WHERE nr.notification_id = notifications.id
    AND nr.user_id = (SELECT auth.uid())
  )
)
WITH CHECK (
  recipient_id = (SELECT auth.uid())
  OR
  EXISTS (
    SELECT 1 FROM public.notification_recipients nr
    WHERE nr.notification_id = notifications.id
    AND nr.user_id = (SELECT auth.uid())
  )
);
```

---

## 4. Repositories Code Refactoring (Event Dispatchers)

### A. Attendance Consecutive Absence Alert:
File: `lib/data/repositories/supabase_attendance_repository.dart`
```dart
// 1. Resolve Teacher ID from subject_offerings
final offeringRow = await _supabase
    .from('subject_offerings')
    .select('teacher_id, subjects(subject_name), sections(section_name)')
    .eq('id', subjectOfferingId)
    .maybeSingle();

final teacherId = offeringRow?['teacher_id']?.toString();

// 2. Insert alert targeted ONLY to this specific Teacher
if (teacherId != null) {
  await _supabase.from('notifications').insert({
    'recipient_id': teacherId,
    'subject_offering_id': subjectOfferingId,
    'student_id': studentId,
    'title': 'Attendance Warning',
    'message': '$studentName has $absenceCount consecutive absences in $subjectName ($sectionName).',
    'notification_type': 'attendance_alert',
    'target_audience': 'teachers',
    'scope': 'individual',
    'created_at': DateTime.now().toUtc().toIso8601String(),
  });
}

// 3. Insert alert targeted ONLY to this Student
await _supabase.from('notifications').insert({
  'recipient_id': studentId,
  'subject_offering_id': subjectOfferingId,
  'student_id': studentId,
  'title': 'Attendance Notice',
  'message': 'You have accumulated $absenceCount consecutive absences in $subjectName ($sectionName). Please coordinate with your teacher.',
  'notification_type': 'attendance_alert',
  'target_audience': 'students',
  'scope': 'individual',
  'created_at': DateTime.now().toUtc().toIso8601String(),
});

// 4. Insert alert targeted ONLY to Parent(s) linked to this student
final parents = await _supabase
    .from('parent_student_links')
    .select('parent_id')
    .eq('student_id', studentId);

for (final p in parents) {
  final parentId = p['parent_id']?.toString();
  if (parentId != null) {
    await _supabase.from('notifications').insert({
      'recipient_id': parentId,
      'subject_offering_id': subjectOfferingId,
      'student_id': studentId,
      'title': 'Student Attendance Warning',
      'message': 'Your child $studentName has $absenceCount consecutive absences in $subjectName ($sectionName).',
      'notification_type': 'attendance_alert',
      'target_audience': 'parents',
      'scope': 'individual',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
```

---

## 5. Client Tabs Query Simplification

All three tabs (`StudentNotificationsTab`, `ParentNotificationsTab`, `TeacherNotificationsTab`) will no longer run broad queries and will stop using regex matching:

```dart
// Clean, secure query for Student:
final currentUserId = AuthRepository.instance.currentUser?.id;
final res = await Supabase.instance.client
    .from('notifications')
    .select()
    .eq('is_archived', false)
    .order('created_at', ascending: false)
    .limit(100);
// (Postgres RLS automatically filters rows before sending to client!)
```

And in `supabase_notification_repository.dart`:
- Completely delete `isNotificationVisibleForUser()` regex logic.
- Unread badge counter calculates count using exact rows returned by RLS.

---

## 6. Step-by-Step Execution Plan

- [ ] **Task 1: Run Supabase SQL Migration & Apply RLS Policies**
  - Execute SQL migration to add foreign keys (`recipient_id`, `subject_offering_id`, `student_id`, `scope`).
  - Create B-tree indexes for fast queries.
  - Apply the three RLS policies (Student, Parent, Teacher) and update policy.

- [ ] **Task 2: Update Notification Event Dispatchers in Repositories**
  - Update `supabase_attendance_repository.dart` to insert `recipient_id`, `subject_offering_id`, and `student_id` for teacher, student, and parent.
  - Update `create_assessment_flow.dart` and `create_requirement_flow.dart` to link new assignments to `subject_offering_id`.
  - Update `teacher_gradebook_tab.dart` grade publication to target enrolled students and their parents.

- [ ] **Task 3: Refactor Student, Parent, and Teacher Notification Tabs**
  - Remove all client-side regex string parsing in `student_notifications_tab.dart`, `parent_notifications_tab.dart`, and `teacher_notifications_tab.dart`.
  - Simplify queries to rely on database-level RLS.
  - Update Realtime subscriptions to listen with `recipient_id=eq.$userId`.

- [ ] **Task 4: Verification Testing**
  - Test 1: Log in as Student A -> Verify Student A sees only their notices; Student B's notices return 0 rows.
  - Test 2: Log in as Parent A -> Verify Parent A sees notices only for Student A; zero notices for Student B.
  - Test 3: Log in as Teacher Naki -> Verify zero attendance notices for Sir Naruto's students.
