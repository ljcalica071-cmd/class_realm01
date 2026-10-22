-- =========================================================================
-- ClassRealm Database Performance Optimization Indexes
-- Migration: 006_performance_indexes.sql
-- =========================================================================

-- 1. Fast case-insensitive email lookup for authentication
CREATE INDEX IF NOT EXISTS idx_users_email_lower
  ON public.users (LOWER(email));

-- 2. User status & role filtering
CREATE INDEX IF NOT EXISTS idx_users_role_archived
  ON public.users (role, is_archived);

-- 3. High-throughput user session activity logs & heartbeat queries
CREATE INDEX IF NOT EXISTS idx_user_session_logs_user_date_active
  ON public.user_session_logs (user_id, session_date, is_active);

CREATE INDEX IF NOT EXISTS idx_user_session_logs_role_date
  ON public.user_session_logs (role, session_date);

-- 4. Academic curriculum, subject offerings & teacher scheduling queries
CREATE INDEX IF NOT EXISTS idx_subject_offerings_teacher_term
  ON public.subject_offerings (teacher_id, term_id, is_archived);

-- 5. Student enrollment queries & roster lookups
CREATE INDEX IF NOT EXISTS idx_student_enrollments_student_offering
  ON public.student_enrollments (student_id, subject_offering_id, status);

-- 6. Daily attendance recording & date range aggregates
CREATE INDEX IF NOT EXISTS idx_attendance_records_offering_date
  ON public.attendance_records (subject_offering_id, attendance_date);

-- 7. Notification center queries ordered by creation time
CREATE INDEX IF NOT EXISTS idx_notifications_archived_created
  ON public.notifications (is_archived, created_at DESC);
