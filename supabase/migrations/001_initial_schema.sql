-- ============================================================
-- CLASSREALM
-- SCHOOL MANAGEMENT + LMS DATABASE
-- PostgreSQL / Supabase
--
-- Firebase  = Authentication
-- Supabase  = Main Application Database
--
-- Design goals:
-- - Normalized relational structure
-- - UUID primary keys for application entities
-- - Firebase UID stored as text
-- - Proper FK relationships
-- - ON DELETE CASCADE / RESTRICT
-- - Soft deletion where appropriate
-- - 3-Term New Curriculum
-- - Classwork + Digital Assessments
-- - Learning Materials
-- - Notifications
-- - Audit Logs
-- ============================================================


-- ============================================================
-- 0. EXTENSIONS
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- ============================================================
-- 1. USERS
-- Firebase UID is stored directly in id
-- ============================================================

CREATE TABLE public.users (
    id varchar(30) NOT NULL,
    email varchar(100) NOT NULL,

    role varchar(10) NOT NULL
        CHECK (
            role IN (
                'admin',
                'teacher',
                'student',
                'parent'
            )
        ),

    is_archived boolean NOT NULL DEFAULT false,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT users_pkey
        PRIMARY KEY (id)
);


-- Case-insensitive email uniqueness
CREATE UNIQUE INDEX uq_users_email_lower
    ON public.users (lower(email));

CREATE INDEX idx_users_role
    ON public.users (role);

CREATE INDEX idx_users_is_archived
    ON public.users (is_archived);


-- ============================================================
-- 2. ADMIN PROFILES
-- ============================================================

CREATE TABLE public.admin_profiles (
    admin_id varchar(30) NOT NULL,

    first_name varchar(30) NOT NULL,
    last_name varchar(30) NOT NULL,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT admin_profiles_pkey
        PRIMARY KEY (admin_id),

    CONSTRAINT admin_profiles_admin_id_fkey
        FOREIGN KEY (admin_id)
        REFERENCES public.users(id)
        ON DELETE CASCADE
);


-- ============================================================
-- 3. TEACHER PROFILES
-- ============================================================

CREATE TABLE public.teacher_profiles (
    teacher_id varchar(30) NOT NULL,

    first_name varchar(30) NOT NULL,
    middle_name varchar(30),
    last_name varchar(30) NOT NULL,

    birthday date,

    gender varchar(10)
        CHECK (
            gender IN (
                'Male',
                'Female'
            )
        ),

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT teacher_profiles_pkey
        PRIMARY KEY (teacher_id),

    CONSTRAINT teacher_profiles_teacher_id_fkey
        FOREIGN KEY (teacher_id)
        REFERENCES public.users(id)
        ON DELETE CASCADE
);


-- ============================================================
-- 4. TEACHER SETTINGS
-- ============================================================

CREATE TABLE public.teacher_settings (
    teacher_id varchar(30) NOT NULL,

    contact_number varchar(11),

    status varchar(30) NOT NULL DEFAULT 'pending_first_login'
        CHECK (
            status IN (
                'pending',
                'pending_first_login',
                'active',
                'inactive'
            )
        ),

    is_setup_complete boolean NOT NULL DEFAULT false,

    subject_specialization varchar(50),

    facebook_link text,

    is_facebook_public boolean NOT NULL DEFAULT false,

    is_phone_public boolean NOT NULL DEFAULT false,

    consultation_hours varchar(50),

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT teacher_settings_pkey
        PRIMARY KEY (teacher_id),

    CONSTRAINT teacher_settings_teacher_id_fkey
        FOREIGN KEY (teacher_id)
        REFERENCES public.teacher_profiles(teacher_id)
        ON DELETE CASCADE
);


-- ============================================================
-- 5. STUDENT PROFILES
-- ============================================================

CREATE TABLE public.student_profiles (
    student_id varchar(30) NOT NULL,

    lrn varchar(12) NOT NULL,

    first_name varchar(30) NOT NULL,
    middle_name varchar(30),
    last_name varchar(30) NOT NULL,

    birthday date NOT NULL,

    gender varchar(6)
        CHECK (
            gender IN (
                'Male',
                'Female'
            )
        ),

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT student_profiles_pkey
        PRIMARY KEY (student_id),

    CONSTRAINT student_profiles_lrn_key
        UNIQUE (lrn),

    CONSTRAINT student_profiles_student_id_fkey
        FOREIGN KEY (student_id)
        REFERENCES public.users(id)
        ON DELETE CASCADE
);


-- ============================================================
-- 6. STUDENT SETTINGS
-- ============================================================

CREATE TABLE public.student_settings (
    student_id varchar(30) NOT NULL,

    status varchar(30) NOT NULL DEFAULT 'pending_first_login'
        CHECK (
            status IN (
                'pending_first_login',
                'active',
                'inactive'
            )
        ),

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT student_settings_pkey
        PRIMARY KEY (student_id),

    CONSTRAINT student_settings_student_id_fkey
        FOREIGN KEY (student_id)
        REFERENCES public.student_profiles(student_id)
        ON DELETE CASCADE
);


-- ============================================================
-- 7. PARENT PROFILES
-- ============================================================

CREATE TABLE public.parent_profiles (
    parent_id varchar(30) NOT NULL,

    first_name varchar(30) NOT NULL,
    middle_name varchar(30),
    last_name varchar(30) NOT NULL,

    contact_number varchar(11) NOT NULL,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT parent_profiles_pkey
        PRIMARY KEY (parent_id),

    CONSTRAINT parent_profiles_parent_id_fkey
        FOREIGN KEY (parent_id)
        REFERENCES public.users(id)
        ON DELETE CASCADE
);


-- ============================================================
-- 8. PARENT <-> STUDENT
-- Many-to-many relationship
-- ============================================================

CREATE TABLE public.parent_student_links (
    parent_id varchar(30) NOT NULL,
    student_id varchar(30) NOT NULL,

    relationship varchar(30) NOT NULL,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT parent_student_links_pkey
        PRIMARY KEY (
            parent_id,
            student_id
        ),

    CONSTRAINT parent_student_links_parent_id_fkey
        FOREIGN KEY (parent_id)
        REFERENCES public.parent_profiles(parent_id)
        ON DELETE CASCADE,

    CONSTRAINT parent_student_links_student_id_fkey
        FOREIGN KEY (student_id)
        REFERENCES public.student_profiles(student_id)
        ON DELETE CASCADE
);

CREATE INDEX idx_parent_student_links_student
    ON public.parent_student_links(student_id);


-- ============================================================
-- 9. SCHOOL YEARS
-- ============================================================

CREATE TABLE public.school_years (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    school_year varchar(9) NOT NULL,

    is_current boolean NOT NULL DEFAULT false,
    is_archived boolean NOT NULL DEFAULT false,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT school_years_pkey
        PRIMARY KEY (id),

    CONSTRAINT school_years_school_year_key
        UNIQUE (school_year),

    CONSTRAINT school_years_format_check
        CHECK (
            school_year ~ '^[0-9]{4}-[0-9]{4}$'
        ),

    CONSTRAINT school_years_current_archive_check
        CHECK (
            NOT (
                is_current = true
                AND is_archived = true
            )
        )
);


-- Only one school year can be current
CREATE UNIQUE INDEX uq_school_years_one_current
    ON public.school_years(is_current)
    WHERE is_current = true;


CREATE INDEX idx_school_years_is_archived
    ON public.school_years(is_archived);


-- ============================================================
-- 10. TERMS
-- New Curriculum = 3 Terms
-- ============================================================

CREATE TABLE public.terms (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    school_year_id uuid NOT NULL,

    term_number smallint NOT NULL
        CHECK (term_number BETWEEN 1 AND 3),

    term_name varchar(20) NOT NULL
        CHECK (
            term_name IN (
                'Term 1',
                'Term 2',
                'Term 3'
            )
        ),

    is_archived boolean NOT NULL DEFAULT false,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT terms_pkey
        PRIMARY KEY (id),

    CONSTRAINT terms_school_year_id_fkey
        FOREIGN KEY (school_year_id)
        REFERENCES public.school_years(id)
        ON DELETE RESTRICT,

    CONSTRAINT terms_unique_number_per_school_year
        UNIQUE (
            school_year_id,
            term_number
        ),

    CONSTRAINT terms_unique_name_per_school_year
        UNIQUE (
            school_year_id,
            term_name
        )
);

CREATE INDEX idx_terms_school_year
    ON public.terms(school_year_id);

CREATE INDEX idx_terms_is_archived
    ON public.terms(is_archived);


-- ============================================================
-- 11. SECTIONS
-- ============================================================

CREATE TABLE public.sections (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    section_name varchar(50) NOT NULL,

    grade_level smallint NOT NULL
        CHECK (
            grade_level BETWEEN 11 AND 12
        ),

    school_year_id uuid NOT NULL,

    is_archived boolean NOT NULL DEFAULT false,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT sections_pkey
        PRIMARY KEY (id),

    CONSTRAINT sections_school_year_id_fkey
        FOREIGN KEY (school_year_id)
        REFERENCES public.school_years(id)
        ON DELETE RESTRICT,

    CONSTRAINT sections_unique_per_school_year
        UNIQUE (
            section_name,
            grade_level,
            school_year_id
        )
);

CREATE INDEX idx_sections_school_year
    ON public.sections(school_year_id);

CREATE INDEX idx_sections_is_archived
    ON public.sections(is_archived);


-- ============================================================
-- 12. SUBJECT CATALOG
-- ============================================================

CREATE TABLE public.subjects (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    subject_code varchar(20) NOT NULL,

    subject_name varchar(100) NOT NULL,

    grade_level smallint NOT NULL
        CHECK (
            grade_level BETWEEN 11 AND 12
        ),

    is_archived boolean NOT NULL DEFAULT false,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT subjects_pkey
        PRIMARY KEY (id),

    CONSTRAINT subjects_subject_code_key
        UNIQUE (subject_code),

    CONSTRAINT subjects_name_grade_key
        UNIQUE (
            subject_name,
            grade_level
        )
);

CREATE INDEX idx_subjects_grade_level
    ON public.subjects(grade_level);

CREATE INDEX idx_subjects_is_archived
    ON public.subjects(is_archived);


-- ============================================================
-- 13. SUBJECT OFFERINGS
--
-- Represents:
-- Subject + Section + Teacher + Term
--
-- school_year_id is intentionally NOT stored here.
-- It is derived through:
--     term_id    -> school_year
--     section_id -> school_year
--
-- Grading weights belong to the actual term/class offering.
-- ============================================================

CREATE TABLE public.subject_offerings (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    subject_id uuid NOT NULL,
    section_id uuid NOT NULL,
    teacher_id varchar(30) NOT NULL,
    term_id uuid NOT NULL,

    ww_weight numeric(5,2) NOT NULL DEFAULT 20.00,
    pt_weight numeric(5,2) NOT NULL DEFAULT 50.00,
    ex_weight numeric(5,2) NOT NULL DEFAULT 30.00,

    is_archived boolean NOT NULL DEFAULT false,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT subject_offerings_pkey
        PRIMARY KEY (id),

    CONSTRAINT subject_offerings_subject_id_fkey
        FOREIGN KEY (subject_id)
        REFERENCES public.subjects(id)
        ON DELETE RESTRICT,

    CONSTRAINT subject_offerings_section_id_fkey
        FOREIGN KEY (section_id)
        REFERENCES public.sections(id)
        ON DELETE RESTRICT,

    CONSTRAINT subject_offerings_teacher_id_fkey
        FOREIGN KEY (teacher_id)
        REFERENCES public.teacher_profiles(teacher_id)
        ON DELETE RESTRICT,

    CONSTRAINT subject_offerings_term_id_fkey
        FOREIGN KEY (term_id)
        REFERENCES public.terms(id)
        ON DELETE RESTRICT,

    CONSTRAINT subject_offerings_weights_valid
        CHECK (
            ww_weight >= 0
            AND pt_weight >= 0
            AND ex_weight >= 0
            AND (
                ww_weight
                + pt_weight
                + ex_weight
            ) = 100
        ),

    CONSTRAINT subject_offerings_unique_class
        UNIQUE (
            subject_id,
            section_id,
            term_id
        )
);

CREATE INDEX idx_subject_offerings_subject
    ON public.subject_offerings(subject_id);

CREATE INDEX idx_subject_offerings_section
    ON public.subject_offerings(section_id);

CREATE INDEX idx_subject_offerings_teacher
    ON public.subject_offerings(teacher_id);

CREATE INDEX idx_subject_offerings_term
    ON public.subject_offerings(term_id);

CREATE INDEX idx_subject_offerings_is_archived
    ON public.subject_offerings(is_archived);


-- ============================================================
-- 14. STUDENT ENROLLMENTS
-- ============================================================

CREATE TABLE public.student_enrollments (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    student_id varchar(30) NOT NULL,

    subject_offering_id uuid NOT NULL,

    status varchar(30) NOT NULL DEFAULT 'enrolled'
        CHECK (
            status IN (
                'enrolled',
                'dropped',
                'transferred'
            )
        ),

    is_irregular boolean NOT NULL DEFAULT false,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT student_enrollments_pkey
        PRIMARY KEY (id),

    CONSTRAINT student_enrollments_student_id_fkey
        FOREIGN KEY (student_id)
        REFERENCES public.student_profiles(student_id)
        ON DELETE RESTRICT,

    CONSTRAINT student_enrollments_subject_offering_id_fkey
        FOREIGN KEY (subject_offering_id)
        REFERENCES public.subject_offerings(id)
        ON DELETE RESTRICT,

    CONSTRAINT student_enrollments_unique
        UNIQUE (
            student_id,
            subject_offering_id
        ),

    -- Composite key used by attendance FK
    CONSTRAINT student_enrollments_student_offering_unique
        UNIQUE (
            student_id,
            subject_offering_id
        )
);

CREATE INDEX idx_student_enrollments_student
    ON public.student_enrollments(student_id);

CREATE INDEX idx_student_enrollments_offering
    ON public.student_enrollments(subject_offering_id);

CREATE INDEX idx_student_enrollments_status
    ON public.student_enrollments(status);


-- ============================================================
-- 15. TEACHER SCHEDULE
-- ============================================================

CREATE TABLE public.teacher_schedule (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    subject_offering_id uuid NOT NULL,

    day_of_week smallint NOT NULL
        CHECK (
            day_of_week BETWEEN 1 AND 7
        ),

    start_time time NOT NULL,

    end_time time NOT NULL,

    room varchar(50),

    is_active boolean NOT NULL DEFAULT true,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT teacher_schedule_pkey
        PRIMARY KEY (id),

    CONSTRAINT teacher_schedule_subject_offering_id_fkey
        FOREIGN KEY (subject_offering_id)
        REFERENCES public.subject_offerings(id)
        ON DELETE CASCADE,

    CONSTRAINT teacher_schedule_valid_time
        CHECK (
            end_time > start_time
        )
);

CREATE INDEX idx_teacher_schedule_offering
    ON public.teacher_schedule(subject_offering_id);

CREATE INDEX idx_teacher_schedule_day
    ON public.teacher_schedule(day_of_week);


-- ============================================================
-- 16. ATTENDANCE RECORDS
-- Historical transaction table.
--
-- No is_archived:
-- attendance should be preserved for reporting/history.
-- ============================================================

CREATE TABLE public.attendance_records (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    student_id varchar(30) NOT NULL,

    subject_offering_id uuid NOT NULL,

    attendance_date date NOT NULL,

    status varchar(10) NOT NULL
        CHECK (
            status IN (
                'present',
                'absent',
                'late',
                'excused'
            )
        ),

    remarks varchar(100),

    recorded_by varchar(30),

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT attendance_records_pkey
        PRIMARY KEY (id),

    CONSTRAINT attendance_records_student_id_fkey
        FOREIGN KEY (student_id)
        REFERENCES public.student_profiles(student_id)
        ON DELETE RESTRICT,

    CONSTRAINT attendance_records_subject_offering_id_fkey
        FOREIGN KEY (subject_offering_id)
        REFERENCES public.subject_offerings(id)
        ON DELETE RESTRICT,

    CONSTRAINT attendance_records_student_offering_fkey
        FOREIGN KEY (
            student_id,
            subject_offering_id
        )
        REFERENCES public.student_enrollments(
            student_id,
            subject_offering_id
        )
        ON DELETE RESTRICT,

    CONSTRAINT attendance_records_recorded_by_fkey
        FOREIGN KEY (recorded_by)
        REFERENCES public.users(id)
        ON DELETE RESTRICT,

    CONSTRAINT attendance_records_unique_daily
        UNIQUE (
            student_id,
            subject_offering_id,
            attendance_date
        )
);

CREATE INDEX idx_attendance_records_student
    ON public.attendance_records(student_id);

CREATE INDEX idx_attendance_records_offering
    ON public.attendance_records(subject_offering_id);

CREATE INDEX idx_attendance_records_date
    ON public.attendance_records(attendance_date);

CREATE INDEX idx_attendance_records_status
    ON public.attendance_records(status);


-- ============================================================
-- 17. CLASSWORK ITEMS
--
-- WW / PT work:
-- activity
-- assignment
-- performance_task
-- ============================================================

CREATE TABLE public.classwork_items (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    subject_offering_id uuid NOT NULL,

    classwork_type varchar(30) NOT NULL
        CHECK (
            classwork_type IN (
                'activity',
                'assignment',
                'performance_task'
            )
        ),

    grading_category varchar(10) NOT NULL
        CHECK (
            grading_category IN (
                'ww',
                'pt'
            )
        ),

    title varchar(100) NOT NULL,

    description varchar(500),

    instructions varchar(1000),

    assigned_at timestamptz NOT NULL DEFAULT now(),

    deadline timestamptz,

    max_score numeric(8,2) NOT NULL DEFAULT 0
        CHECK (
            max_score >= 0
        ),

    is_published boolean NOT NULL DEFAULT false,

    is_archived boolean NOT NULL DEFAULT false,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT classwork_items_pkey
        PRIMARY KEY (id),

    CONSTRAINT classwork_items_subject_offering_id_fkey
        FOREIGN KEY (subject_offering_id)
        REFERENCES public.subject_offerings(id)
        ON DELETE RESTRICT,

    CONSTRAINT classwork_items_deadline_check
        CHECK (
            deadline IS NULL
            OR deadline > assigned_at
        )
);

CREATE INDEX idx_classwork_items_offering
    ON public.classwork_items(subject_offering_id);

CREATE INDEX idx_classwork_items_type
    ON public.classwork_items(classwork_type);

CREATE INDEX idx_classwork_items_deadline
    ON public.classwork_items(deadline);

CREATE INDEX idx_classwork_items_is_archived
    ON public.classwork_items(is_archived);


-- ============================================================
-- 18. CLASSWORK EXTENSIONS
-- Student-specific deadline extension
-- ============================================================

CREATE TABLE public.classwork_extensions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    classwork_id uuid NOT NULL,

    student_id varchar(30) NOT NULL,

    new_deadline timestamptz NOT NULL,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT classwork_extensions_pkey
        PRIMARY KEY (id),

    CONSTRAINT classwork_extensions_classwork_id_fkey
        FOREIGN KEY (classwork_id)
        REFERENCES public.classwork_items(id)
        ON DELETE CASCADE,

    CONSTRAINT classwork_extensions_student_id_fkey
        FOREIGN KEY (student_id)
        REFERENCES public.student_profiles(student_id)
        ON DELETE RESTRICT,

    CONSTRAINT classwork_extensions_unique_student
        UNIQUE (
            classwork_id,
            student_id
        )
);

CREATE INDEX idx_classwork_extensions_classwork
    ON public.classwork_extensions(classwork_id);

CREATE INDEX idx_classwork_extensions_student
    ON public.classwork_extensions(student_id);


-- ============================================================
-- 19. CLASSWORK ATTACHMENTS
-- Multiple teacher files per classwork
-- ============================================================

CREATE TABLE public.classwork_attachments (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    classwork_id uuid NOT NULL,

    file_name varchar(255) NOT NULL,

    storage_url varchar(500) NOT NULL,

    mime_type varchar(50),

    file_size_bytes bigint
        CHECK (
            file_size_bytes IS NULL
            OR file_size_bytes >= 0
        ),

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT classwork_attachments_pkey
        PRIMARY KEY (id),

    CONSTRAINT classwork_attachments_classwork_id_fkey
        FOREIGN KEY (classwork_id)
        REFERENCES public.classwork_items(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_classwork_attachments_classwork
    ON public.classwork_attachments(classwork_id);


-- ============================================================
-- 20. STUDENT CLASSWORK SUBMISSIONS
--
-- Historical record:
-- DO NOT soft-delete.
--
-- Student uploads are stored in submission_attachments.
-- Submission file types are restricted to PDF / DOC / DOCX.
-- ============================================================

CREATE TABLE public.student_classwork_submissions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    classwork_id uuid NOT NULL,

    student_id varchar(30) NOT NULL,

    status varchar(30) NOT NULL DEFAULT 'pending'
        CHECK (
            status IN (
                'pending',
                'submitted',
                'graded'
            )
        ),

    submitted_at timestamptz,

    score numeric(8,2)
        CHECK (
            score IS NULL
            OR score >= 0
        ),

    feedback varchar(1000),

    graded_at timestamptz,

    graded_by varchar(30),

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT student_classwork_submissions_pkey
        PRIMARY KEY (id),

    CONSTRAINT student_classwork_submissions_classwork_id_fkey
        FOREIGN KEY (classwork_id)
        REFERENCES public.classwork_items(id)
        ON DELETE RESTRICT,

    CONSTRAINT student_classwork_submissions_student_id_fkey
        FOREIGN KEY (student_id)
        REFERENCES public.student_profiles(student_id)
        ON DELETE RESTRICT,

    CONSTRAINT student_classwork_submissions_graded_by_fkey
        FOREIGN KEY (graded_by)
        REFERENCES public.users(id)
        ON DELETE RESTRICT,

    CONSTRAINT student_classwork_submissions_unique
        UNIQUE (
            classwork_id,
            student_id
        )
);

CREATE INDEX idx_submissions_classwork
    ON public.student_classwork_submissions(classwork_id);

CREATE INDEX idx_submissions_student
    ON public.student_classwork_submissions(student_id);

CREATE INDEX idx_submissions_status
    ON public.student_classwork_submissions(status);


-- ============================================================
-- 21. SUBMISSION ATTACHMENTS
-- Student file uploads
-- ============================================================

CREATE TABLE public.submission_attachments (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    submission_id uuid NOT NULL,

    file_name varchar(255) NOT NULL,

    storage_url varchar(500) NOT NULL,

    mime_type varchar(50) NOT NULL
        CHECK (
            mime_type IN (
                'application/pdf',
                'application/msword',
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
            )
        ),

    file_size_bytes bigint
        CHECK (
            file_size_bytes >= 0
        ),

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT submission_attachments_pkey
        PRIMARY KEY (id),

    CONSTRAINT submission_attachments_submission_id_fkey
        FOREIGN KEY (submission_id)
        REFERENCES public.student_classwork_submissions(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_submission_attachments_submission
    ON public.submission_attachments(submission_id);


-- ============================================================
-- 22. DIGITAL ASSESSMENTS
--
-- One structure for:
-- quiz
-- st1
-- st2
-- term_exam
-- ============================================================

CREATE TABLE public.digital_assessments (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    subject_offering_id uuid NOT NULL,

    assessment_type varchar(30) NOT NULL
        CHECK (
            assessment_type IN (
                'quiz',
                'st1',
                'st2',
                'term_exam'
            )
        ),

    grading_category varchar(10) NOT NULL
        CHECK (
            grading_category IN (
                'ww',
                'pt',
                'ex'
            )
        ),

    title varchar(100) NOT NULL,

    description varchar(500),

    instructions varchar(1000),

    time_limit_minutes integer
        CHECK (
            time_limit_minutes IS NULL
            OR time_limit_minutes > 0
        ),

    available_from timestamptz,

    deadline timestamptz,

    attempts_allowed integer NOT NULL DEFAULT 1
        CHECK (
            attempts_allowed >= 1
        ),

    is_published boolean NOT NULL DEFAULT false,

    is_archived boolean NOT NULL DEFAULT false,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT digital_assessments_pkey
        PRIMARY KEY (id),

    CONSTRAINT digital_assessments_subject_offering_id_fkey
        FOREIGN KEY (subject_offering_id)
        REFERENCES public.subject_offerings(id)
        ON DELETE RESTRICT,

    CONSTRAINT digital_assessments_deadline_check
        CHECK (
            deadline IS NULL
            OR available_from IS NULL
            OR deadline > available_from
        )
);

CREATE INDEX idx_digital_assessments_offering
    ON public.digital_assessments(subject_offering_id);

CREATE INDEX idx_digital_assessments_type
    ON public.digital_assessments(assessment_type);

CREATE INDEX idx_digital_assessments_deadline
    ON public.digital_assessments(deadline);

CREATE INDEX idx_digital_assessments_is_archived
    ON public.digital_assessments(is_archived);


-- ============================================================
-- 23. DIGITAL ASSESSMENT EXTENSIONS
-- Student-specific assessment deadline
-- ============================================================

CREATE TABLE public.digital_assessment_extensions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    assessment_id uuid NOT NULL,

    student_id varchar(30) NOT NULL,

    new_deadline timestamptz NOT NULL,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT digital_assessment_extensions_pkey
        PRIMARY KEY (id),

    CONSTRAINT digital_assessment_extensions_assessment_id_fkey
        FOREIGN KEY (assessment_id)
        REFERENCES public.digital_assessments(id)
        ON DELETE CASCADE,

    CONSTRAINT digital_assessment_extensions_student_id_fkey
        FOREIGN KEY (student_id)
        REFERENCES public.student_profiles(student_id)
        ON DELETE RESTRICT,

    CONSTRAINT digital_assessment_extensions_unique_student
        UNIQUE (
            assessment_id,
            student_id
        )
);

CREATE INDEX idx_digital_assessment_extensions_assessment
    ON public.digital_assessment_extensions(assessment_id);

CREATE INDEX idx_digital_assessment_extensions_student
    ON public.digital_assessment_extensions(student_id);


-- ============================================================
-- 24. ASSESSMENT QUESTIONS
-- ============================================================

CREATE TABLE public.assessment_questions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    assessment_id uuid NOT NULL,

    position integer NOT NULL
        CHECK (
            position >= 1
        ),

    question_type varchar(30) NOT NULL
        CHECK (
            question_type IN (
                'multiple_choice',
                'true_false',
                'matching_type',
                'identification'
            )
        ),

    question_text varchar(1000) NOT NULL,

    points numeric(8,2) NOT NULL DEFAULT 1.00
        CHECK (
            points >= 0
        ),

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT assessment_questions_pkey
        PRIMARY KEY (id),

    CONSTRAINT assessment_questions_assessment_id_fkey
        FOREIGN KEY (assessment_id)
        REFERENCES public.digital_assessments(id)
        ON DELETE RESTRICT,

    CONSTRAINT assessment_questions_unique_position
        UNIQUE (
            assessment_id,
            position
        )
);

CREATE INDEX idx_assessment_questions_assessment
    ON public.assessment_questions(assessment_id);


-- ============================================================
-- 25. ASSESSMENT QUESTION OPTIONS
--
-- For:
-- multiple_choice
-- true_false
--
-- is_correct stores the answer key.
-- One correct option per question is enforced.
-- ============================================================

CREATE TABLE public.assessment_question_options (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    question_id uuid NOT NULL,

    position smallint NOT NULL
        CHECK (
            position >= 1
        ),

    option_text varchar(500) NOT NULL,

    is_correct boolean NOT NULL DEFAULT false,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT assessment_question_options_pkey
        PRIMARY KEY (id),

    CONSTRAINT assessment_question_options_question_id_fkey
        FOREIGN KEY (question_id)
        REFERENCES public.assessment_questions(id)
        ON DELETE CASCADE,

    CONSTRAINT assessment_question_options_unique_position
        UNIQUE (
            question_id,
            position
        ),

    -- Used for composite FK from responses
    CONSTRAINT assessment_question_options_id_question_unique
        UNIQUE (
            id,
            question_id
        )
);

CREATE INDEX idx_assessment_question_options_question
    ON public.assessment_question_options(question_id);


-- Exactly one correct answer per question
CREATE UNIQUE INDEX uq_assessment_one_correct_option
    ON public.assessment_question_options(question_id)
    WHERE is_correct = true;


-- ============================================================
-- 26. ASSESSMENT ATTEMPTS
--
-- A student may have multiple attempts if allowed.
-- ============================================================

CREATE TABLE public.assessment_attempts (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    assessment_id uuid NOT NULL,

    student_id varchar(30) NOT NULL,

    attempt_number integer NOT NULL
        CHECK (
            attempt_number >= 1
        ),

    status varchar(30) NOT NULL DEFAULT 'in_progress'
        CHECK (
            status IN (
                'in_progress',
                'submitted',
                'auto_submitted',
                'abandoned'
            )
        ),

    started_at timestamptz NOT NULL DEFAULT now(),

    submitted_at timestamptz,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT assessment_attempts_pkey
        PRIMARY KEY (id),

    CONSTRAINT assessment_attempts_assessment_id_fkey
        FOREIGN KEY (assessment_id)
        REFERENCES public.digital_assessments(id)
        ON DELETE RESTRICT,

    CONSTRAINT assessment_attempts_student_id_fkey
        FOREIGN KEY (student_id)
        REFERENCES public.student_profiles(student_id)
        ON DELETE RESTRICT,

    CONSTRAINT assessment_attempts_unique_number
        UNIQUE (
            assessment_id,
            student_id,
            attempt_number
        ),

    CONSTRAINT assessment_attempts_submitted_time_check
        CHECK (
            submitted_at IS NULL
            OR submitted_at >= started_at
        )
);

CREATE INDEX idx_assessment_attempts_assessment
    ON public.assessment_attempts(assessment_id);

CREATE INDEX idx_assessment_attempts_student
    ON public.assessment_attempts(student_id);

CREATE INDEX idx_assessment_attempts_status
    ON public.assessment_attempts(status);


-- Only one active attempt at a time
CREATE UNIQUE INDEX uq_assessment_one_active_attempt
    ON public.assessment_attempts(
        assessment_id,
        student_id
    )
    WHERE status = 'in_progress';


-- ============================================================
-- 27. ASSESSMENT RESPONSES
--
-- Stores exact answer per question.
-- Used for:
-- - Auto grading
-- - Item analysis
-- - Correct/wrong percentages
-- ============================================================

CREATE TABLE public.assessment_responses (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    attempt_id uuid NOT NULL,

    question_id uuid NOT NULL,

    selected_option_id uuid,

    is_correct boolean,

    points_earned numeric(8,2) NOT NULL DEFAULT 0
        CHECK (
            points_earned >= 0
        ),

    answered_at timestamptz,

    CONSTRAINT assessment_responses_pkey
        PRIMARY KEY (id),

    CONSTRAINT assessment_responses_attempt_id_fkey
        FOREIGN KEY (attempt_id)
        REFERENCES public.assessment_attempts(id)
        ON DELETE CASCADE,

    CONSTRAINT assessment_responses_question_id_fkey
        FOREIGN KEY (question_id)
        REFERENCES public.assessment_questions(id)
        ON DELETE RESTRICT,

    CONSTRAINT assessment_responses_selected_option_fkey
        FOREIGN KEY (
            selected_option_id,
            question_id
        )
        REFERENCES public.assessment_question_options(
            id,
            question_id
        )
        ON DELETE RESTRICT,

    CONSTRAINT assessment_responses_unique_question
        UNIQUE (
            attempt_id,
            question_id
        )
);

CREATE INDEX idx_assessment_responses_attempt
    ON public.assessment_responses(attempt_id);

CREATE INDEX idx_assessment_responses_question
    ON public.assessment_responses(question_id);

CREATE INDEX idx_assessment_responses_selected_option
    ON public.assessment_responses(selected_option_id);


-- ============================================================
-- 28. ANTI-CHEATING MONITORING LOGS
--
-- References assessment_attempt_id instead of duplicating:
-- student_id + assessment_id
--
-- Example event_type:
-- tab_switched
-- fullscreen_exit
-- window_blur
-- copy_attempt
-- paste_attempt
-- right_click
-- multiple_tabs
-- etc.
-- ============================================================

CREATE TABLE public.anti_cheating_logs (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    assessment_attempt_id uuid NOT NULL,

    event_type varchar(50) NOT NULL,

    event_at timestamptz NOT NULL DEFAULT now(),

    event_details jsonb,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT anti_cheating_logs_pkey
        PRIMARY KEY (id),

    CONSTRAINT anti_cheating_logs_attempt_id_fkey
        FOREIGN KEY (assessment_attempt_id)
        REFERENCES public.assessment_attempts(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_anti_cheating_logs_attempt
    ON public.anti_cheating_logs(assessment_attempt_id);

CREATE INDEX idx_anti_cheating_logs_event_type
    ON public.anti_cheating_logs(event_type);

CREATE INDEX idx_anti_cheating_logs_event_at
    ON public.anti_cheating_logs(event_at);


-- ============================================================
-- 29. FOLDERS
--
-- Learning materials organized by specific offering.
--
-- parent_folder_id enables sub-folders.
-- ============================================================

CREATE TABLE public.folders (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    subject_offering_id uuid NOT NULL,

    parent_folder_id uuid,

    folder_name varchar(100) NOT NULL,

    is_archived boolean NOT NULL DEFAULT false,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT folders_pkey
        PRIMARY KEY (id),

    CONSTRAINT folders_subject_offering_id_fkey
        FOREIGN KEY (subject_offering_id)
        REFERENCES public.subject_offerings(id)
        ON DELETE RESTRICT,

    CONSTRAINT folders_parent_folder_id_fkey
        FOREIGN KEY (parent_folder_id)
        REFERENCES public.folders(id)
        ON DELETE CASCADE,

    CONSTRAINT folders_not_self_parent
        CHECK (
            parent_folder_id IS NULL
            OR parent_folder_id <> id
        )
);

CREATE INDEX idx_folders_subject_offering
    ON public.folders(subject_offering_id);

CREATE INDEX idx_folders_parent
    ON public.folders(parent_folder_id);

CREATE INDEX idx_folders_is_archived
    ON public.folders(is_archived);


-- ============================================================
-- 30. LEARNING MATERIALS
-- ============================================================

CREATE TABLE public.learning_materials (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    folder_id uuid NOT NULL,

    file_name varchar(100) NOT NULL,

    storage_path_url varchar(500) NOT NULL,

    mime_type varchar(50),

    file_size_bytes bigint
        CHECK (
            file_size_bytes IS NULL
            OR file_size_bytes >= 0
        ),

    is_archived boolean NOT NULL DEFAULT false,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT learning_materials_pkey
        PRIMARY KEY (id),

    CONSTRAINT learning_materials_folder_id_fkey
        FOREIGN KEY (folder_id)
        REFERENCES public.folders(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_learning_materials_folder
    ON public.learning_materials(folder_id);

CREATE INDEX idx_learning_materials_is_archived
    ON public.learning_materials(is_archived);


-- ============================================================
-- 31. NOTIFICATIONS
--
-- Notification content is stored once.
-- Recipients are stored in notification_recipients.
-- ============================================================

CREATE TABLE public.notifications (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    title varchar(100) NOT NULL,

    message varchar(500) NOT NULL,

    notification_type varchar(30) NOT NULL DEFAULT 'general',

    created_by varchar(30),

    is_archived boolean NOT NULL DEFAULT false,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT notifications_pkey
        PRIMARY KEY (id),

    CONSTRAINT notifications_created_by_fkey
        FOREIGN KEY (created_by)
        REFERENCES public.users(id)
        ON DELETE SET NULL
);

CREATE INDEX idx_notifications_type
    ON public.notifications(notification_type);

CREATE INDEX idx_notifications_created_at
    ON public.notifications(created_at);

CREATE INDEX idx_notifications_is_archived
    ON public.notifications(is_archived);


-- ============================================================
-- 32. NOTIFICATION RECIPIENTS
--
-- Many-to-many:
-- notification <-> users
--
-- read_at = NULL means unread
-- ============================================================

CREATE TABLE public.notification_recipients (
    notification_id uuid NOT NULL,

    user_id varchar(30) NOT NULL,

    read_at timestamptz,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT notification_recipients_pkey
        PRIMARY KEY (
            notification_id,
            user_id
        ),

    CONSTRAINT notification_recipients_notification_id_fkey
        FOREIGN KEY (notification_id)
        REFERENCES public.notifications(id)
        ON DELETE CASCADE,

    CONSTRAINT notification_recipients_user_id_fkey
        FOREIGN KEY (user_id)
        REFERENCES public.users(id)
        ON DELETE RESTRICT
);

CREATE INDEX idx_notification_recipients_user
    ON public.notification_recipients(user_id);

CREATE INDEX idx_notification_recipients_unread
    ON public.notification_recipients(user_id)
    WHERE read_at IS NULL;


-- ============================================================
-- 33. AUDIT LOGS
--
-- Historical system monitoring.
-- No is_archived.
-- ============================================================

CREATE TABLE public.audit_logs (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    user_id varchar(30) NOT NULL,

    action_type varchar(50) NOT NULL,

    description varchar(500) NOT NULL,

    logged_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT audit_logs_pkey
        PRIMARY KEY (id),

    CONSTRAINT audit_logs_user_id_fkey
        FOREIGN KEY (user_id)
        REFERENCES public.users(id)
        ON DELETE RESTRICT
);

CREATE INDEX idx_audit_logs_user
    ON public.audit_logs(user_id);

CREATE INDEX idx_audit_logs_action_type
    ON public.audit_logs(action_type);

CREATE INDEX idx_audit_logs_logged_at
    ON public.audit_logs(logged_at);


-- ============================================================
-- 34. UPDATED_AT TRIGGER FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


-- ============================================================
-- 35. APPLY UPDATED_AT TRIGGERS
-- ============================================================

CREATE TRIGGER trg_teacher_settings_updated_at
BEFORE UPDATE ON public.teacher_settings
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_student_settings_updated_at
BEFORE UPDATE ON public.student_settings
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_subject_offerings_updated_at
BEFORE UPDATE ON public.subject_offerings
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_classwork_items_updated_at
BEFORE UPDATE ON public.classwork_items
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_classwork_extensions_updated_at
BEFORE UPDATE ON public.classwork_extensions
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_student_classwork_submissions_updated_at
BEFORE UPDATE ON public.student_classwork_submissions
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_digital_assessments_updated_at
BEFORE UPDATE ON public.digital_assessments
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_digital_assessment_extensions_updated_at
BEFORE UPDATE ON public.digital_assessment_extensions
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_assessment_questions_updated_at
BEFORE UPDATE ON public.assessment_questions
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_folders_updated_at
BEFORE UPDATE ON public.folders
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_learning_materials_updated_at
BEFORE UPDATE ON public.learning_materials
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- ============================================================
-- 36. VALIDATE SUBJECT OFFERING CONTEXT
--
-- Ensures:
-- 1. Subject grade = Section grade
-- 2. Section school year = Term school year
-- ============================================================

CREATE OR REPLACE FUNCTION public.validate_subject_offering_context()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_subject_grade smallint;
    v_section_grade smallint;
    v_section_school_year uuid;
    v_term_school_year uuid;
BEGIN

    SELECT grade_level
    INTO v_subject_grade
    FROM public.subjects
    WHERE id = NEW.subject_id;

    SELECT grade_level, school_year_id
    INTO v_section_grade, v_section_school_year
    FROM public.sections
    WHERE id = NEW.section_id;

    SELECT school_year_id
    INTO v_term_school_year
    FROM public.terms
    WHERE id = NEW.term_id;

    IF v_subject_grade IS DISTINCT FROM v_section_grade THEN
        RAISE EXCEPTION
            'Subject grade level (%) does not match section grade level (%).',
            v_subject_grade,
            v_section_grade;
    END IF;

    IF v_section_school_year IS DISTINCT FROM v_term_school_year THEN
        RAISE EXCEPTION
            'Section and term must belong to the same school year.';
    END IF;

    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_validate_subject_offering_context
BEFORE INSERT OR UPDATE OF subject_id, section_id, term_id
ON public.subject_offerings
FOR EACH ROW
EXECUTE FUNCTION public.validate_subject_offering_context();


-- ============================================================
-- 37. VALIDATE CLASSWORK STUDENT ENROLLMENT
--
-- Used for:
-- - classwork submissions
-- - classwork extensions
-- ============================================================

CREATE OR REPLACE FUNCTION public.validate_classwork_student_enrollment()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_subject_offering_id uuid;
BEGIN

    SELECT subject_offering_id
    INTO v_subject_offering_id
    FROM public.classwork_items
    WHERE id = NEW.classwork_id;

    IF NOT EXISTS (
        SELECT 1
        FROM public.student_enrollments se
        WHERE se.student_id = NEW.student_id
          AND se.subject_offering_id = v_subject_offering_id
    ) THEN
        RAISE EXCEPTION
            'Student is not enrolled in the classwork subject offering.';
    END IF;

    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_validate_classwork_submission_enrollment
BEFORE INSERT OR UPDATE OF classwork_id, student_id
ON public.student_classwork_submissions
FOR EACH ROW
EXECUTE FUNCTION public.validate_classwork_student_enrollment();


CREATE TRIGGER trg_validate_classwork_extension_enrollment
BEFORE INSERT OR UPDATE OF classwork_id, student_id
ON public.classwork_extensions
FOR EACH ROW
EXECUTE FUNCTION public.validate_classwork_student_enrollment();


-- ============================================================
-- 38. VALIDATE ASSESSMENT STUDENT ENROLLMENT
--
-- Used for:
-- - assessment attempts
-- - assessment deadline extensions
-- ============================================================

CREATE OR REPLACE FUNCTION public.validate_assessment_student_enrollment()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_subject_offering_id uuid;
BEGIN

    SELECT subject_offering_id
    INTO v_subject_offering_id
    FROM public.digital_assessments
    WHERE id = NEW.assessment_id;

    IF NOT EXISTS (
        SELECT 1
        FROM public.student_enrollments se
        WHERE se.student_id = NEW.student_id
          AND se.subject_offering_id = v_subject_offering_id
    ) THEN
        RAISE EXCEPTION
            'Student is not enrolled in the assessment subject offering.';
    END IF;

    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_validate_assessment_attempt_enrollment
BEFORE INSERT OR UPDATE OF assessment_id, student_id
ON public.assessment_attempts
FOR EACH ROW
EXECUTE FUNCTION public.validate_assessment_student_enrollment();


CREATE TRIGGER trg_validate_assessment_extension_enrollment
BEFORE INSERT OR UPDATE OF assessment_id, student_id
ON public.digital_assessment_extensions
FOR EACH ROW
EXECUTE FUNCTION public.validate_assessment_student_enrollment();


-- ============================================================
-- 39. VALIDATE ASSESSMENT RESPONSE CONTEXT
--
-- Prevents:
-- question from another assessment
-- from being answered in an unrelated attempt.
-- ============================================================

CREATE OR REPLACE FUNCTION public.validate_assessment_response_context()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_attempt_assessment_id uuid;
    v_question_assessment_id uuid;
BEGIN

    SELECT assessment_id
    INTO v_attempt_assessment_id
    FROM public.assessment_attempts
    WHERE id = NEW.attempt_id;

    SELECT assessment_id
    INTO v_question_assessment_id
    FROM public.assessment_questions
    WHERE id = NEW.question_id;

    IF v_attempt_assessment_id IS DISTINCT FROM v_question_assessment_id THEN
        RAISE EXCEPTION
            'Assessment response question does not belong to the assessment attempt.';
    END IF;

    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_validate_assessment_response_context
BEFORE INSERT OR UPDATE OF attempt_id, question_id
ON public.assessment_responses
FOR EACH ROW
EXECUTE FUNCTION public.validate_assessment_response_context();


-- ============================================================
-- 40. VALIDATE FOLDER PARENT
--
-- Parent folder must belong to the same subject offering.
-- ============================================================

CREATE OR REPLACE FUNCTION public.validate_folder_parent()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_parent_subject_offering_id uuid;
BEGIN

    IF NEW.parent_folder_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT subject_offering_id
    INTO v_parent_subject_offering_id
    FROM public.folders
    WHERE id = NEW.parent_folder_id;

    IF v_parent_subject_offering_id IS DISTINCT FROM NEW.subject_offering_id THEN
        RAISE EXCEPTION
            'Parent folder must belong to the same subject offering.';
    END IF;

    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_validate_folder_parent
BEFORE INSERT OR UPDATE OF parent_folder_id, subject_offering_id
ON public.folders
FOR EACH ROW
EXECUTE FUNCTION public.validate_folder_parent();


-- ============================================================
-- 41. ASSESSMENT ATTEMPT SCORE VIEW
--
-- Computes:
-- - score
-- - maximum score
-- - percentage
--
-- Score is based on points_earned snapshots in responses.
-- ============================================================

CREATE OR REPLACE VIEW public.assessment_attempt_scores AS
SELECT
    aa.id AS attempt_id,
    aa.assessment_id,
    aa.student_id,
    aa.attempt_number,
    aa.status,

    COALESCE(
        SUM(ar.points_earned),
        0
    ) AS score,

    COALESCE(
        SUM(aq.points),
        0
    ) AS max_score,

    CASE
        WHEN COALESCE(SUM(aq.points), 0) = 0
            THEN 0
        ELSE ROUND(
            (
                COALESCE(SUM(ar.points_earned), 0)
                / SUM(aq.points)
            ) * 100,
            2
        )
    END AS percentage

FROM public.assessment_attempts aa

LEFT JOIN public.assessment_questions aq
    ON aq.assessment_id = aa.assessment_id

LEFT JOIN public.assessment_responses ar
    ON ar.attempt_id = aa.id
   AND ar.question_id = aq.id

GROUP BY
    aa.id,
    aa.assessment_id,
    aa.student_id,
    aa.attempt_number,
    aa.status;


-- ============================================================
-- 42. ASSESSMENT ITEM ANALYSIS VIEW
--
-- Provides raw statistics needed for:
-- - correct percentage
-- - wrong percentage
-- - unanswered count
-- - difficulty calculation
--
-- Hard / Medium / Easy is intentionally NOT hard-coded here.
-- ============================================================

CREATE OR REPLACE VIEW public.assessment_item_analysis AS
SELECT
    aq.id AS question_id,
    aq.assessment_id,
    aq.position,
    aq.question_type,
    aq.question_text,
    aq.points,

    COUNT(DISTINCT aa.id)
        AS attempt_count,

    COUNT(ar.id)
        AS response_count,

    COUNT(ar.id)
        FILTER (
            WHERE ar.is_correct = true
        )
        AS correct_count,

    COUNT(ar.id)
        FILTER (
            WHERE ar.is_correct = false
        )
        AS wrong_count,

    (
        COUNT(DISTINCT aa.id)
        - COUNT(ar.id)
    )
        AS unanswered_count,

    CASE
        WHEN COUNT(DISTINCT aa.id) = 0
            THEN 0
        ELSE ROUND(
            (
                COUNT(ar.id)
                FILTER (
                    WHERE ar.is_correct = true
                )::numeric
                / COUNT(DISTINCT aa.id)
            ) * 100,
            2
        )
    END AS correct_percentage_of_attempts,

    CASE
        WHEN COUNT(ar.id) = 0
            THEN 0
        ELSE ROUND(
            (
                COUNT(ar.id)
                FILTER (
                    WHERE ar.is_correct = true
                )::numeric
                / COUNT(ar.id)
            ) * 100,
            2
        )
    END AS correct_percentage_of_responses,

    CASE
        WHEN COUNT(ar.id) = 0
            THEN 0
        ELSE ROUND(
            (
                COUNT(ar.id)
                FILTER (
                    WHERE ar.is_correct = false
                )::numeric
                / COUNT(ar.id)
            ) * 100,
            2
        )
    END AS wrong_percentage_of_responses

FROM public.assessment_questions aq

LEFT JOIN public.assessment_attempts aa
    ON aa.assessment_id = aq.assessment_id
   AND aa.status IN (
        'submitted',
        'auto_submitted'
   )

LEFT JOIN public.assessment_responses ar
    ON ar.attempt_id = aa.id
   AND ar.question_id = aq.id

GROUP BY
    aq.id,
    aq.assessment_id,
    aq.position,
    aq.question_type,
    aq.question_text,
    aq.points;


-- ============================================================
-- 43. DEFAULT SCHOOL YEAR
-- Optional initial seed
-- ============================================================

INSERT INTO public.school_years (
    school_year,
    is_current
)
VALUES (
    '2026-2027',
    true
)
ON CONFLICT (school_year)
DO NOTHING;


-- ============================================================
-- 44. DEFAULT 3 TERMS FOR 2026-2027
-- ============================================================

INSERT INTO public.terms (
    school_year_id,
    term_number,
    term_name
)
SELECT
    sy.id,
    t.term_number,
    t.term_name
FROM public.school_years sy
CROSS JOIN (
    VALUES
        (1, 'Term 1'),
        (2, 'Term 2'),
        (3, 'Term 3')
) AS t(term_number, term_name)
WHERE sy.school_year = '2026-2027'
ON CONFLICT (
    school_year_id,
    term_number
)
DO NOTHING; 

-- ============================================================
-- 45. TERM GRADES (Final Computed Grades)
-- ============================================================

CREATE TABLE public.term_grades (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    student_id varchar(30) NOT NULL,
    subject_offering_id uuid NOT NULL,

    initial_grade numeric(5,2) NOT NULL DEFAULT 0,
    transmuted_grade numeric(5,2) NOT NULL DEFAULT 0,
    
    remarks varchar(255) 
        CHECK (remarks IN ('Passed', 'Failed', 'Incomplete', 'Dropped')),

    is_finalized boolean NOT NULL DEFAULT false,
    
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT term_grades_pkey PRIMARY KEY (id),
    
    CONSTRAINT term_grades_student_id_fkey 
        FOREIGN KEY (student_id) REFERENCES public.student_profiles(student_id) ON DELETE CASCADE,
        
    CONSTRAINT term_grades_subject_offering_id_fkey 
        FOREIGN KEY (subject_offering_id) REFERENCES public.subject_offerings(id) ON DELETE CASCADE,
        
    -- Only one grade record per student per subject offering (Term)
    CONSTRAINT term_grades_unique_student_offering 
        UNIQUE (student_id, subject_offering_id)
);

CREATE TRIGGER trg_term_grades_updated_at
BEFORE UPDATE ON public.term_grades
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
