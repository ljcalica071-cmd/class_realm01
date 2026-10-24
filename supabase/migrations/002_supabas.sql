-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.users (
  id character varying NOT NULL,
  email character varying NOT NULL,
  role character varying NOT NULL CHECK (role::text = ANY (ARRAY['admin'::character varying, 'teacher'::character varying, 'student'::character varying, 'parent'::character varying]::text[])),
  is_archived boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT users_pkey PRIMARY KEY (id)
);
CREATE TABLE public.admin_profiles (
  admin_id character varying NOT NULL,
  first_name character varying NOT NULL,
  last_name character varying NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT admin_profiles_pkey PRIMARY KEY (admin_id),
  CONSTRAINT admin_profiles_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.users(id)
);
CREATE TABLE public.teacher_profiles (
  teacher_id character varying NOT NULL,
  first_name character varying NOT NULL,
  middle_name character varying,
  last_name character varying NOT NULL,
  birthday date,
  gender character varying CHECK (gender::text = ANY (ARRAY['Male'::character varying, 'Female'::character varying]::text[])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT teacher_profiles_pkey PRIMARY KEY (teacher_id),
  CONSTRAINT teacher_profiles_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.users(id)
);
CREATE TABLE public.teacher_settings (
  teacher_id character varying NOT NULL,
  contact_number character varying,
  status character varying NOT NULL DEFAULT 'pending_first_login'::character varying CHECK (status::text = ANY (ARRAY['pending_first_login'::text, 'active'::text, 'archived'::text])),
  is_setup_complete boolean NOT NULL DEFAULT false,
  subject_specialization character varying,
  facebook_link text,
  is_facebook_public boolean NOT NULL DEFAULT false,
  is_phone_public boolean NOT NULL DEFAULT false,
  consultation_hours character varying,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  previous_status character varying,
  CONSTRAINT teacher_settings_pkey PRIMARY KEY (teacher_id),
  CONSTRAINT teacher_settings_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teacher_profiles(teacher_id)
);
CREATE TABLE public.student_profiles (
  student_id character varying NOT NULL,
  lrn character varying NOT NULL UNIQUE,
  first_name character varying NOT NULL,
  middle_name character varying,
  last_name character varying NOT NULL,
  birthday date NOT NULL,
  gender character varying CHECK (gender::text = ANY (ARRAY['Male'::character varying, 'Female'::character varying]::text[])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT student_profiles_pkey PRIMARY KEY (student_id),
  CONSTRAINT student_profiles_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.users(id)
);
CREATE TABLE public.student_settings (
  student_id character varying NOT NULL,
  status character varying NOT NULL DEFAULT 'pending_first_login'::character varying CHECK (status::text = ANY (ARRAY['pending_first_login'::text, 'active'::text, 'archived'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  previous_status character varying,
  CONSTRAINT student_settings_pkey PRIMARY KEY (student_id),
  CONSTRAINT student_settings_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.student_profiles(student_id)
);
CREATE TABLE public.parent_profiles (
  parent_id character varying NOT NULL,
  first_name character varying NOT NULL,
  middle_name character varying,
  last_name character varying NOT NULL,
  contact_number character varying NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  birthday date,
  status character varying DEFAULT 'pending_first_login'::character varying CHECK (status::text = ANY (ARRAY['pending_first_login'::text, 'active'::text, 'archived'::text])),
  previous_status character varying,
  CONSTRAINT parent_profiles_pkey PRIMARY KEY (parent_id),
  CONSTRAINT parent_profiles_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.users(id)
);
CREATE TABLE public.parent_student_links (
  parent_id character varying NOT NULL,
  student_id character varying NOT NULL,
  relationship character varying NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT parent_student_links_pkey PRIMARY KEY (parent_id, student_id),
  CONSTRAINT parent_student_links_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.parent_profiles(parent_id),
  CONSTRAINT parent_student_links_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.student_profiles(student_id)
);
CREATE TABLE public.school_years (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  school_year character varying NOT NULL UNIQUE CHECK (school_year::text ~ '^[0-9]{4}-[0-9]{4}$'::text),
  is_current boolean NOT NULL DEFAULT false,
  is_archived boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT school_years_pkey PRIMARY KEY (id)
);
CREATE TABLE public.terms (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  school_year_id uuid NOT NULL,
  term_number smallint NOT NULL CHECK (term_number >= 1 AND term_number <= 3),
  term_name character varying NOT NULL CHECK (term_name::text = ANY (ARRAY['Term 1'::character varying, 'Term 2'::character varying, 'Term 3'::character varying]::text[])),
  is_archived boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT terms_pkey PRIMARY KEY (id),
  CONSTRAINT terms_school_year_id_fkey FOREIGN KEY (school_year_id) REFERENCES public.school_years(id)
);
CREATE TABLE public.sections (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  section_name character varying NOT NULL,
  grade_level smallint NOT NULL CHECK (grade_level >= 11 AND grade_level <= 12),
  school_year_id uuid NOT NULL,
  is_archived boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT sections_pkey PRIMARY KEY (id),
  CONSTRAINT sections_school_year_id_fkey FOREIGN KEY (school_year_id) REFERENCES public.school_years(id)
);
CREATE TABLE public.subjects (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  subject_code character varying NOT NULL UNIQUE,
  subject_name character varying NOT NULL,
  grade_level smallint NOT NULL CHECK (grade_level >= 11 AND grade_level <= 12),
  is_archived boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT subjects_pkey PRIMARY KEY (id)
);
CREATE TABLE public.subject_offerings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  subject_id uuid NOT NULL,
  section_id uuid NOT NULL,
  teacher_id character varying NOT NULL,
  term_id uuid NOT NULL,
  ww_weight numeric NOT NULL DEFAULT 20.00,
  pt_weight numeric NOT NULL DEFAULT 50.00,
  ex_weight numeric NOT NULL DEFAULT 30.00,
  is_archived boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  terms_taught smallint NOT NULL DEFAULT 3 CHECK (terms_taught >= 1 AND terms_taught <= 3),
  term_block character varying NOT NULL DEFAULT '1ST, 2ND, 3RD'::character varying,
  units_per_term numeric NOT NULL DEFAULT 2.0,
  st1_weight numeric NOT NULL DEFAULT 30.00,
  st2_weight numeric NOT NULL DEFAULT 30.00,
  te_weight numeric NOT NULL DEFAULT 40.00,
  CONSTRAINT subject_offerings_pkey PRIMARY KEY (id),
  CONSTRAINT subject_offerings_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id),
  CONSTRAINT subject_offerings_section_id_fkey FOREIGN KEY (section_id) REFERENCES public.sections(id),
  CONSTRAINT subject_offerings_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teacher_profiles(teacher_id),
  CONSTRAINT subject_offerings_term_id_fkey FOREIGN KEY (term_id) REFERENCES public.terms(id)
);
CREATE TABLE public.student_enrollments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  student_id character varying NOT NULL,
  subject_offering_id uuid NOT NULL,
  status character varying NOT NULL DEFAULT 'enrolled'::character varying CHECK (status::text = ANY (ARRAY['enrolled'::character varying, 'dropped'::character varying, 'transferred'::character varying]::text[])),
  is_irregular boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT student_enrollments_pkey PRIMARY KEY (id),
  CONSTRAINT student_enrollments_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.student_profiles(student_id),
  CONSTRAINT student_enrollments_subject_offering_id_fkey FOREIGN KEY (subject_offering_id) REFERENCES public.subject_offerings(id)
);
CREATE TABLE public.teacher_schedule (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  subject_offering_id uuid NOT NULL,
  day_of_week smallint NOT NULL CHECK (day_of_week >= 1 AND day_of_week <= 7),
  start_time time without time zone NOT NULL,
  end_time time without time zone NOT NULL,
  room character varying,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT teacher_schedule_pkey PRIMARY KEY (id),
  CONSTRAINT teacher_schedule_subject_offering_id_fkey FOREIGN KEY (subject_offering_id) REFERENCES public.subject_offerings(id)
);
CREATE TABLE public.attendance_records (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  student_id character varying NOT NULL,
  subject_offering_id uuid NOT NULL,
  attendance_date date NOT NULL,
  status character varying NOT NULL CHECK (status::text = ANY (ARRAY['present'::character varying, 'absent'::character varying, 'late'::character varying, 'excused'::character varying]::text[])),
  remarks character varying,
  recorded_by character varying,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT attendance_records_pkey PRIMARY KEY (id),
  CONSTRAINT attendance_records_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.student_profiles(student_id),
  CONSTRAINT attendance_records_subject_offering_id_fkey FOREIGN KEY (subject_offering_id) REFERENCES public.subject_offerings(id),
  CONSTRAINT attendance_records_student_offering_fkey FOREIGN KEY (student_id) REFERENCES public.student_enrollments(student_id),
  CONSTRAINT attendance_records_student_offering_fkey FOREIGN KEY (subject_offering_id) REFERENCES public.student_enrollments(subject_offering_id),
  CONSTRAINT attendance_records_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES public.users(id)
);
CREATE TABLE public.classwork_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  subject_offering_id uuid NOT NULL,
  classwork_type character varying NOT NULL CHECK (classwork_type::text = ANY (ARRAY['activity'::character varying, 'assignment'::character varying, 'performance_task'::character varying]::text[])),
  grading_category character varying NOT NULL CHECK (grading_category::text = ANY (ARRAY['ww'::character varying, 'pt'::character varying]::text[])),
  title character varying NOT NULL,
  description character varying,
  instructions character varying,
  assigned_at timestamp with time zone NOT NULL DEFAULT now(),
  deadline timestamp with time zone,
  max_score numeric NOT NULL DEFAULT 0 CHECK (max_score >= 0::numeric),
  is_published boolean NOT NULL DEFAULT false,
  is_archived boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  term_number smallint NOT NULL DEFAULT 1 CHECK (term_number >= 1 AND term_number <= 3),
  gradebook_column_index smallint CHECK (gradebook_column_index IS NULL OR gradebook_column_index >= 1 AND gradebook_column_index <= 10),
  batch_group_id uuid,
  target_student_ids ARRAY,
  allow_late_submission boolean NOT NULL DEFAULT true,
  updated_instructions_at timestamp with time zone,
  CONSTRAINT classwork_items_pkey PRIMARY KEY (id),
  CONSTRAINT classwork_items_subject_offering_id_fkey FOREIGN KEY (subject_offering_id) REFERENCES public.subject_offerings(id)
);
CREATE TABLE public.classwork_extensions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  classwork_id uuid NOT NULL,
  student_id character varying NOT NULL,
  new_deadline timestamp with time zone NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT classwork_extensions_pkey PRIMARY KEY (id),
  CONSTRAINT classwork_extensions_classwork_id_fkey FOREIGN KEY (classwork_id) REFERENCES public.classwork_items(id),
  CONSTRAINT classwork_extensions_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.student_profiles(student_id)
);
CREATE TABLE public.classwork_attachments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  classwork_id uuid NOT NULL,
  file_name character varying NOT NULL,
  storage_url character varying NOT NULL,
  mime_type character varying CHECK (mime_type::text = ANY (ARRAY['application/pdf'::character varying, 'application/msword'::character varying, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'::character varying]::text[])),
  file_size_bytes bigint CHECK (file_size_bytes > 0 AND file_size_bytes <= 3145728),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT classwork_attachments_pkey PRIMARY KEY (id),
  CONSTRAINT classwork_attachments_classwork_id_fkey FOREIGN KEY (classwork_id) REFERENCES public.classwork_items(id)
);
CREATE TABLE public.student_classwork_submissions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  classwork_id uuid NOT NULL,
  student_id character varying NOT NULL,
  status character varying NOT NULL DEFAULT 'pending'::character varying CHECK (status::text = ANY (ARRAY['pending'::text, 'submitted'::text, 'late_submitted'::text, 'graded'::text, 'returned_corrupted'::text, 'reopened'::text])),
  submitted_at timestamp with time zone,
  score numeric CHECK (score IS NULL OR score >= 0::numeric),
  feedback character varying,
  graded_at timestamp with time zone,
  graded_by character varying,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  submission_count integer NOT NULL DEFAULT 0 CHECK (submission_count >= 0 AND submission_count <= 5),
  last_uploaded_at timestamp with time zone,
  is_file_corrupted boolean NOT NULL DEFAULT false,
  dispute_note text,
  dispute_status character varying CHECK (dispute_status IS NULL OR (dispute_status::text = ANY (ARRAY['open'::character varying, 'resolved'::character varying, 'dismissed'::character varying]::text[]))),
  CONSTRAINT student_classwork_submissions_pkey PRIMARY KEY (id),
  CONSTRAINT student_classwork_submissions_classwork_id_fkey FOREIGN KEY (classwork_id) REFERENCES public.classwork_items(id),
  CONSTRAINT student_classwork_submissions_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.student_profiles(student_id),
  CONSTRAINT student_classwork_submissions_graded_by_fkey FOREIGN KEY (graded_by) REFERENCES public.users(id)
);
CREATE TABLE public.submission_attachments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  submission_id uuid NOT NULL,
  file_name character varying NOT NULL,
  storage_url character varying NOT NULL,
  mime_type character varying NOT NULL CHECK (mime_type::text = ANY (ARRAY['application/pdf'::character varying, 'application/msword'::character varying, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'::character varying]::text[])),
  file_size_bytes bigint CHECK (file_size_bytes > 0 AND file_size_bytes <= 3145728),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT submission_attachments_pkey PRIMARY KEY (id),
  CONSTRAINT submission_attachments_submission_id_fkey FOREIGN KEY (submission_id) REFERENCES public.student_classwork_submissions(id)
);
CREATE TABLE public.digital_assessments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  subject_offering_id uuid NOT NULL,
  assessment_type character varying NOT NULL CHECK (assessment_type::text = ANY (ARRAY['quiz'::character varying, 'st1'::character varying, 'st2'::character varying, 'term_exam'::character varying]::text[])),
  grading_category character varying NOT NULL CHECK (grading_category::text = ANY (ARRAY['ww'::character varying, 'pt'::character varying, 'ex'::character varying]::text[])),
  title character varying NOT NULL,
  description character varying,
  instructions character varying,
  time_limit_minutes integer CHECK (time_limit_minutes IS NULL OR time_limit_minutes > 0),
  available_from timestamp with time zone,
  deadline timestamp with time zone,
  attempts_allowed integer NOT NULL DEFAULT 1 CHECK (attempts_allowed >= 1),
  is_published boolean NOT NULL DEFAULT false,
  is_archived boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT digital_assessments_pkey PRIMARY KEY (id),
  CONSTRAINT digital_assessments_subject_offering_id_fkey FOREIGN KEY (subject_offering_id) REFERENCES public.subject_offerings(id)
);
CREATE TABLE public.digital_assessment_extensions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  assessment_id uuid NOT NULL,
  student_id character varying NOT NULL,
  new_deadline timestamp with time zone NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT digital_assessment_extensions_pkey PRIMARY KEY (id),
  CONSTRAINT digital_assessment_extensions_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES public.digital_assessments(id),
  CONSTRAINT digital_assessment_extensions_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.student_profiles(student_id)
);
CREATE TABLE public.assessment_questions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  assessment_id uuid NOT NULL,
  position integer NOT NULL CHECK ("position" >= 1),
  question_type character varying NOT NULL CHECK (question_type::text = ANY (ARRAY['multiple_choice'::character varying, 'true_false'::character varying, 'matching_type'::character varying, 'identification'::character varying]::text[])),
  question_text character varying NOT NULL,
  points numeric NOT NULL DEFAULT 1.00 CHECK (points >= 0::numeric),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT assessment_questions_pkey PRIMARY KEY (id),
  CONSTRAINT assessment_questions_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES public.digital_assessments(id)
);
CREATE TABLE public.assessment_question_options (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  question_id uuid NOT NULL,
  position smallint NOT NULL CHECK ("position" >= 1),
  option_text character varying NOT NULL,
  is_correct boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT assessment_question_options_pkey PRIMARY KEY (id),
  CONSTRAINT assessment_question_options_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.assessment_questions(id)
);
CREATE TABLE public.assessment_attempts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  assessment_id uuid NOT NULL,
  student_id character varying NOT NULL,
  attempt_number integer NOT NULL CHECK (attempt_number >= 1),
  status character varying NOT NULL DEFAULT 'in_progress'::character varying CHECK (status::text = ANY (ARRAY['in_progress'::character varying, 'submitted'::character varying, 'auto_submitted'::character varying, 'abandoned'::character varying]::text[])),
  started_at timestamp with time zone NOT NULL DEFAULT now(),
  submitted_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT assessment_attempts_pkey PRIMARY KEY (id),
  CONSTRAINT assessment_attempts_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES public.digital_assessments(id),
  CONSTRAINT assessment_attempts_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.student_profiles(student_id)
);
CREATE TABLE public.assessment_responses (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  attempt_id uuid NOT NULL,
  question_id uuid NOT NULL,
  selected_option_id uuid,
  is_correct boolean,
  points_earned numeric NOT NULL DEFAULT 0 CHECK (points_earned >= 0::numeric),
  answered_at timestamp with time zone,
  CONSTRAINT assessment_responses_pkey PRIMARY KEY (id),
  CONSTRAINT assessment_responses_attempt_id_fkey FOREIGN KEY (attempt_id) REFERENCES public.assessment_attempts(id),
  CONSTRAINT assessment_responses_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.assessment_questions(id),
  CONSTRAINT assessment_responses_selected_option_fkey FOREIGN KEY (selected_option_id) REFERENCES public.assessment_question_options(id),
  CONSTRAINT assessment_responses_selected_option_fkey FOREIGN KEY (question_id) REFERENCES public.assessment_question_options(question_id)
);
CREATE TABLE public.anti_cheating_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  assessment_attempt_id uuid NOT NULL,
  event_type character varying NOT NULL,
  event_at timestamp with time zone NOT NULL DEFAULT now(),
  event_details jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT anti_cheating_logs_pkey PRIMARY KEY (id),
  CONSTRAINT anti_cheating_logs_attempt_id_fkey FOREIGN KEY (assessment_attempt_id) REFERENCES public.assessment_attempts(id)
);
CREATE TABLE public.folders (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  subject_offering_id uuid NOT NULL,
  parent_folder_id uuid,
  folder_name character varying NOT NULL,
  is_archived boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  is_visible_to_students boolean NOT NULL DEFAULT true,
  CONSTRAINT folders_pkey PRIMARY KEY (id),
  CONSTRAINT folders_subject_offering_id_fkey FOREIGN KEY (subject_offering_id) REFERENCES public.subject_offerings(id),
  CONSTRAINT folders_parent_folder_id_fkey FOREIGN KEY (parent_folder_id) REFERENCES public.folders(id)
);
CREATE TABLE public.learning_materials (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  folder_id uuid NOT NULL,
  file_name character varying NOT NULL,
  storage_path_url character varying NOT NULL,
  mime_type character varying CHECK (mime_type IS NULL OR (mime_type::text = ANY (ARRAY['application/pdf'::character varying, 'application/msword'::character varying, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'::character varying, 'application/vnd.ms-powerpoint'::character varying, 'application/vnd.openxmlformats-officedocument.presentationml.presentation'::character varying, 'text/markdown'::character varying, 'text/uri-list'::character varying]::text[]))),
  file_size_bytes bigint CHECK (file_size_bytes IS NULL OR file_size_bytes >= 0 AND file_size_bytes <= 3145728),
  is_archived boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  is_visible_to_students boolean NOT NULL DEFAULT true,
  title character varying,
  description text,
  available_from timestamp with time zone,
  CONSTRAINT learning_materials_pkey PRIMARY KEY (id),
  CONSTRAINT learning_materials_folder_id_fkey FOREIGN KEY (folder_id) REFERENCES public.folders(id)
);
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title character varying NOT NULL,
  message character varying NOT NULL,
  notification_type character varying NOT NULL DEFAULT 'general'::character varying,
  created_by character varying,
  is_archived boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  target_audience character varying NOT NULL DEFAULT 'all'::character varying,
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id)
);
CREATE TABLE public.notification_recipients (
  notification_id uuid NOT NULL,
  user_id character varying NOT NULL,
  read_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT notification_recipients_pkey PRIMARY KEY (notification_id, user_id),
  CONSTRAINT notification_recipients_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT notification_recipients_notification_id_fkey FOREIGN KEY (notification_id) REFERENCES public.notifications(id)
);
CREATE TABLE public.audit_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id character varying NOT NULL,
  action_type character varying NOT NULL,
  description character varying NOT NULL,
  logged_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT audit_logs_pkey PRIMARY KEY (id),
  CONSTRAINT audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.term_grades (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  student_id character varying NOT NULL,
  subject_offering_id uuid NOT NULL,
  initial_grade numeric NOT NULL DEFAULT 0,
  transmuted_grade numeric NOT NULL DEFAULT 0,
  remarks character varying CHECK (remarks::text = ANY (ARRAY['Passed'::character varying, 'Failed'::character varying, 'Incomplete'::character varying, 'Dropped'::character varying]::text[])),
  is_finalized boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  term_number smallint NOT NULL DEFAULT 1 CHECK (term_number >= 1 AND term_number <= 3),
  CONSTRAINT term_grades_pkey PRIMARY KEY (id),
  CONSTRAINT term_grades_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.student_profiles(student_id),
  CONSTRAINT term_grades_subject_offering_id_fkey FOREIGN KEY (subject_offering_id) REFERENCES public.subject_offerings(id)
);
CREATE TABLE public.admin_teacher_email_challenges (
  email character varying NOT NULL,
  code_hash text NOT NULL,
  first_name character varying NOT NULL,
  middle_name character varying,
  last_name character varying NOT NULL,
  gender character varying NOT NULL,
  birthday date NOT NULL,
  created_by character varying NOT NULL,
  expires_at timestamp with time zone NOT NULL,
  last_sent_at timestamp with time zone NOT NULL,
  failed_attempts integer NOT NULL DEFAULT 0,
  locked_until timestamp with time zone,
  resend_count integer NOT NULL DEFAULT 0,
  window_started_at timestamp with time zone NOT NULL DEFAULT now(),
  lockout_tier smallint NOT NULL DEFAULT 0,
  tier_escalated_at timestamp with time zone,
  CONSTRAINT admin_teacher_email_challenges_pkey PRIMARY KEY (email)
);
CREATE TABLE public.first_login_otp_verifications (
  user_id character varying NOT NULL,
  code_hash character varying NOT NULL,
  expires_at timestamp with time zone NOT NULL,
  last_sent_at timestamp with time zone NOT NULL DEFAULT now(),
  resend_count integer NOT NULL DEFAULT 0,
  failed_attempts integer NOT NULL DEFAULT 0,
  is_verified boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  email character varying,
  window_started_at timestamp with time zone NOT NULL DEFAULT now(),
  lockout_tier smallint NOT NULL DEFAULT 0,
  tier_escalated_at timestamp with time zone,
  locked_until timestamp with time zone,
  CONSTRAINT first_login_otp_verifications_pkey PRIMARY KEY (user_id)
);
CREATE TABLE public.gradebook_term_sheets (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  subject_offering_id uuid NOT NULL,
  term_number smallint NOT NULL CHECK (term_number >= 1 AND term_number <= 3),
  hps_json jsonb NOT NULL DEFAULT '{"ex": {}, "pt": {}, "ww": {}}'::jsonb,
  scores_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT gradebook_term_sheets_pkey PRIMARY KEY (id),
  CONSTRAINT gradebook_term_sheets_subject_offering_id_fkey FOREIGN KEY (subject_offering_id) REFERENCES public.subject_offerings(id)
);
CREATE TABLE public.system_settings (
  id boolean NOT NULL DEFAULT true CHECK (id = true),
  is_maintenance_mode boolean NOT NULL DEFAULT false,
  maintenance_updated_at timestamp with time zone NOT NULL DEFAULT now(),
  maintenance_updated_by character varying,
  school_year_updated_at timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT system_settings_pkey PRIMARY KEY (id),
  CONSTRAINT system_settings_maintenance_updated_by_fkey FOREIGN KEY (maintenance_updated_by) REFERENCES public.users(id)
);
CREATE TABLE public.user_session_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id character varying NOT NULL,
  role character varying NOT NULL,
  session_date date NOT NULL DEFAULT CURRENT_DATE,
  login_at timestamp with time zone NOT NULL DEFAULT now(),
  last_active_at timestamp with time zone NOT NULL DEFAULT now(),
  logout_at timestamp with time zone,
  logout_reason character varying CHECK (logout_reason IS NULL OR (logout_reason::text = ANY (ARRAY['manual'::character varying, 'inactivity'::character varying, 'inactivity_timeout'::character varying, 'terminated'::character varying, 'app_closed'::character varying, 'session_expired'::character varying, 'session_superseded'::character varying]::text[]))),
  is_active boolean NOT NULL DEFAULT true,
  duration_seconds integer NOT NULL DEFAULT 0 CHECK (duration_seconds >= 0),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_session_logs_pkey PRIMARY KEY (id),
  CONSTRAINT user_session_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.auth_rate_limits (
  scope_key character varying NOT NULL,
  feature character varying NOT NULL CHECK (feature::text = ANY (ARRAY['login_account'::character varying::text, 'login_device'::character varying::text, 'forgot_password'::character varying::text, 'first_login_otp'::character varying::text, 'admin_add_teacher_otp'::character varying::text, 'admin_broadcast'::character varying::text, 'admin_sy_switch'::character varying::text, 'admin_maintenance_toggle'::character varying::text])),
  device_id character varying NOT NULL,
  target_identifier character varying NOT NULL,
  failed_attempts integer NOT NULL DEFAULT 0 CHECK (failed_attempts >= 0),
  resend_count integer NOT NULL DEFAULT 0 CHECK (resend_count >= 0),
  window_started_at timestamp with time zone NOT NULL DEFAULT now(),
  lockout_tier smallint NOT NULL DEFAULT 0 CHECK (lockout_tier >= 0 AND lockout_tier <= 4),
  tier_escalated_at timestamp with time zone,
  locked_until timestamp with time zone,
  cooldown_until timestamp with time zone,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT auth_rate_limits_pkey PRIMARY KEY (scope_key)
);
CREATE TABLE public.password_reset_otps (
  email character varying NOT NULL,
  code_hash text NOT NULL,
  expires_at timestamp with time zone NOT NULL,
  last_sent_at timestamp with time zone NOT NULL DEFAULT now(),
  resend_count integer NOT NULL DEFAULT 0,
  failed_attempts integer NOT NULL DEFAULT 0,
  window_started_at timestamp with time zone NOT NULL DEFAULT now(),
  lockout_tier smallint NOT NULL DEFAULT 0,
  tier_escalated_at timestamp with time zone,
  locked_until timestamp with time zone,
  is_verified boolean NOT NULL DEFAULT false,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT password_reset_otps_pkey PRIMARY KEY (email)
);