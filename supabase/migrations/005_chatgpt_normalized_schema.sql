-- ============================================================
-- SUPABASE DATABASE SCHEMA (V5 - Normalized)
-- Firebase = Authentication only
-- Supabase = Main Application Database
-- ============================================================

-- ============================================================
-- EXTENSIONS
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- ============================================================
-- 1. USERS
-- Firebase UID is stored in id
-- ============================================================

CREATE TABLE public.users (
    id text NOT NULL,
    email varchar NOT NULL UNIQUE,

    role varchar NOT NULL
        CHECK (
            role IN (
                'teacher',
                'admin',
                'student',
                'parent'
            )
        ),

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT users_pkey
        PRIMARY KEY (id)
);


-- ============================================================
-- 2. SCHOOL YEARS
-- ============================================================

CREATE TABLE public.school_years (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    school_year varchar NOT NULL UNIQUE,

    is_current boolean NOT NULL DEFAULT false,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT school_years_pkey
        PRIMARY KEY (id)
);


-- ============================================================
-- 3. TEACHER PROFILE
-- ============================================================

CREATE TABLE public.teacher_profiles (
    teacher_id text NOT NULL,

    first_name varchar NOT NULL,
    middle_name varchar,
    last_name varchar NOT NULL,

    birthday date,

    gender varchar
        CHECK (
            gender IN ('Male', 'Female')
        ),

    CONSTRAINT teacher_profiles_pkey
        PRIMARY KEY (teacher_id),

    CONSTRAINT teacher_profiles_teacher_id_fkey
        FOREIGN KEY (teacher_id)
        REFERENCES public.users(id)
        ON DELETE CASCADE
);


-- ============================================================
-- 4. TEACHER SETTINGS / CONTACT INFORMATION
-- ============================================================

CREATE TABLE public.teacher_settings (
    teacher_id text NOT NULL,

    contact_number varchar,

    status varchar NOT NULL DEFAULT 'pending',

    is_setup_complete boolean NOT NULL DEFAULT false,

    subject_specialization varchar,

    facebook_link text,

    is_facebook_public boolean NOT NULL DEFAULT false,

    is_phone_public boolean NOT NULL DEFAULT false,

    consultation_hours varchar,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT teacher_settings_pkey
        PRIMARY KEY (teacher_id),

    CONSTRAINT teacher_settings_teacher_id_fkey
        FOREIGN KEY (teacher_id)
        REFERENCES public.teacher_profiles(teacher_id)
        ON DELETE CASCADE
);


-- ============================================================
-- 5. STUDENT PROFILE
-- ============================================================

CREATE TABLE public.student_profiles (
    student_id text NOT NULL,

    lrn varchar NOT NULL UNIQUE,

    first_name varchar NOT NULL,
    middle_name varchar,
    last_name varchar NOT NULL,

    birthday date NOT NULL,

    gender varchar
        CHECK (
            gender IN ('Male', 'Female')
        ),

    CONSTRAINT student_profiles_pkey
        PRIMARY KEY (student_id),

    CONSTRAINT student_profiles_student_id_fkey
        FOREIGN KEY (student_id)
        REFERENCES public.users(id)
        ON DELETE CASCADE
);


-- ============================================================
-- 6. STUDENT SETTINGS
-- ============================================================

CREATE TABLE public.student_settings (
    student_id text NOT NULL,

    status varchar NOT NULL DEFAULT 'Pending First Login',

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT student_settings_pkey
        PRIMARY KEY (student_id),

    CONSTRAINT student_settings_student_id_fkey
        FOREIGN KEY (student_id)
        REFERENCES public.student_profiles(student_id)
        ON DELETE CASCADE
);


-- ============================================================
-- 7. PARENT PROFILE
-- ============================================================

CREATE TABLE public.parent_profiles (
    parent_id text NOT NULL,

    first_name varchar NOT NULL,
    middle_name varchar,
    last_name varchar NOT NULL,

    contact_number varchar NOT NULL,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT parent_profiles_pkey
        PRIMARY KEY (parent_id),

    CONSTRAINT parent_profiles_parent_id_fkey
        FOREIGN KEY (parent_id)
        REFERENCES public.users(id)
        ON DELETE CASCADE
);


-- ============================================================
-- 8. ADMIN PROFILE
-- ============================================================

CREATE TABLE public.admin_profiles (
    admin_id text NOT NULL,

    first_name varchar NOT NULL,
    last_name varchar NOT NULL,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT admin_profiles_pkey
        PRIMARY KEY (admin_id),

    CONSTRAINT admin_profiles_admin_id_fkey
        FOREIGN KEY (admin_id)
        REFERENCES public.users(id)
        ON DELETE CASCADE
);


-- ============================================================
-- 9. PARENT ↔ STUDENT RELATIONSHIP
-- Many-to-many
-- ============================================================

CREATE TABLE public.parent_student_links (
    parent_id text NOT NULL,

    student_id text NOT NULL,

    relationship varchar NOT NULL,

    CONSTRAINT parent_student_links_pkey
        PRIMARY KEY (parent_id, student_id),

    CONSTRAINT parent_student_links_parent_id_fkey
        FOREIGN KEY (parent_id)
        REFERENCES public.parent_profiles(parent_id)
        ON DELETE CASCADE,

    CONSTRAINT parent_student_links_student_id_fkey
        FOREIGN KEY (student_id)
        REFERENCES public.student_profiles(student_id)
        ON DELETE CASCADE
);


-- ============================================================
-- 10. SECTIONS
-- ============================================================

CREATE TABLE public.sections (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    section_name varchar NOT NULL,

    grade_level integer NOT NULL
        CHECK (grade_level BETWEEN 11 AND 12),

    school_year_id uuid NOT NULL,

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


-- ============================================================
-- 11. SUBJECTS
--
-- Subject itself contains only subject-level information.
-- Grading weights are NOT stored here because they may differ
-- depending on the actual class/offering.
-- ============================================================

CREATE TABLE public.subjects (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    subject_code varchar NOT NULL UNIQUE,

    subject_name varchar NOT NULL,

    grade_level integer NOT NULL
        CHECK (grade_level BETWEEN 11 AND 12),

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT subjects_pkey
        PRIMARY KEY (id)
);


-- ============================================================
-- 12. SUBJECT OFFERINGS
--
-- This represents:
--
-- Subject + Teacher + Section + School Year
--
-- Grading weights belong here because they are part of the
-- actual class/subject configuration.
-- ============================================================

CREATE TABLE public.subject_offerings (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    subject_id uuid NOT NULL,

    section_id uuid NOT NULL,

    teacher_id text NOT NULL,

    school_year_id uuid NOT NULL,

    ww_weight numeric(5,2) NOT NULL DEFAULT 20.00,

    pt_weight numeric(5,2) NOT NULL DEFAULT 50.00,

    exam_weight numeric(5,2) NOT NULL DEFAULT 30.00,

    created_at timestamptz NOT NULL DEFAULT now(),

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

    CONSTRAINT subject_offerings_school_year_id_fkey
        FOREIGN KEY (school_year_id)
        REFERENCES public.school_years(id)
        ON DELETE RESTRICT,

    CONSTRAINT subject_offerings_weights_valid
        CHECK (
            ww_weight >= 0
            AND pt_weight >= 0
            AND exam_weight >= 0
            AND (
                ww_weight
                + pt_weight
                + exam_weight
            ) = 100
        ),

    CONSTRAINT subject_offerings_unique_class
        UNIQUE (
            subject_id,
            section_id,
            teacher_id,
            school_year_id
        )
);


-- ============================================================
-- 13. STUDENT ENROLLMENTS
--
-- A student enrolls in a SUBJECT OFFERING,
-- not directly in a subject.
-- ============================================================

CREATE TABLE public.student_enrollments (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    student_id text NOT NULL,

    subject_offering_id uuid NOT NULL,

    status varchar NOT NULL DEFAULT 'Enrolled',

    is_irregular boolean NOT NULL DEFAULT false,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT student_enrollments_pkey
        PRIMARY KEY (id),

    CONSTRAINT student_enrollments_student_id_fkey
        FOREIGN KEY (student_id)
        REFERENCES public.student_profiles(student_id)
        ON DELETE CASCADE,

    CONSTRAINT student_enrollments_subject_offering_id_fkey
        FOREIGN KEY (subject_offering_id)
        REFERENCES public.subject_offerings(id)
        ON DELETE RESTRICT,

    CONSTRAINT student_enrollments_unique
        UNIQUE (
            student_id,
            subject_offering_id
        )
);


-- ============================================================
-- 14. TEACHER SCHEDULE
-- ============================================================

CREATE TABLE public.teacher_schedule (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    subject_offering_id uuid NOT NULL,

    day_of_week integer NOT NULL
        CHECK (day_of_week BETWEEN 1 AND 7),

    start_time time NOT NULL,

    end_time time NOT NULL,

    room varchar,

    is_active boolean NOT NULL DEFAULT true,

    CONSTRAINT teacher_schedule_pkey
        PRIMARY KEY (id),

    CONSTRAINT teacher_schedule_subject_offering_id_fkey
        FOREIGN KEY (subject_offering_id)
        REFERENCES public.subject_offerings(id)
        ON DELETE CASCADE,

    CONSTRAINT teacher_schedule_valid_time
        CHECK (end_time > start_time)
);


-- ============================================================
-- 15. CLASSWORK ITEMS
-- ============================================================

CREATE TABLE public.classwork_items (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    subject_offering_id uuid NOT NULL,

    classwork_type text NOT NULL
        CHECK (
            classwork_type IN (
                'activity',
                'assignment',
                'performance_task'
            )
        ),

    title text NOT NULL,

    description text NOT NULL DEFAULT '',

    instructions text NOT NULL DEFAULT '',

    assigned_at timestamptz NOT NULL DEFAULT now(),

    deadline timestamptz,

    max_score numeric NOT NULL DEFAULT 0
        CHECK (max_score >= 0),

    submission_type text NOT NULL DEFAULT 'file_and_text'
        CHECK (
            submission_type IN (
                'file',
                'text',
                'file_and_text',
                'none'
            )
        ),

    is_published boolean NOT NULL DEFAULT false,

    created_at timestamptz NOT NULL DEFAULT now(),

    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT classwork_items_pkey
        PRIMARY KEY (id),

    CONSTRAINT classwork_items_subject_offering_id_fkey
        FOREIGN KEY (subject_offering_id)
        REFERENCES public.subject_offerings(id)
        ON DELETE CASCADE
);


-- ============================================================
-- 16. CLASSWORK ATTACHMENTS
--
-- Allows multiple files per classwork.
-- ============================================================

CREATE TABLE public.classwork_attachments (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    classwork_id uuid NOT NULL,

    file_name text NOT NULL,

    file_url text NOT NULL,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT classwork_attachments_pkey
        PRIMARY KEY (id),

    CONSTRAINT classwork_attachments_classwork_id_fkey
        FOREIGN KEY (classwork_id)
        REFERENCES public.classwork_items(id)
        ON DELETE CASCADE
);


-- ============================================================
-- 17. STUDENT CLASSWORK SUBMISSIONS
-- ============================================================

CREATE TABLE public.student_classwork_submissions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    classwork_id uuid NOT NULL,

    student_id text NOT NULL,

    status text NOT NULL DEFAULT 'pending'
        CHECK (
            status IN (
                'pending',
                'submitted',
                'graded',
                'returned'
            )
        ),

    submitted_at timestamptz,

    text_submission text,

    score numeric
        CHECK (
            score IS NULL
            OR score >= 0
        ),

    feedback text,

    graded_at timestamptz,

    created_at timestamptz NOT NULL DEFAULT now(),

    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT student_classwork_submissions_pkey
        PRIMARY KEY (id),

    CONSTRAINT student_classwork_submissions_classwork_id_fkey
        FOREIGN KEY (classwork_id)
        REFERENCES public.classwork_items(id)
        ON DELETE CASCADE,

    CONSTRAINT student_classwork_submissions_student_id_fkey
        FOREIGN KEY (student_id)
        REFERENCES public.student_profiles(student_id)
        ON DELETE CASCADE,

    CONSTRAINT student_classwork_submissions_unique
        UNIQUE (
            classwork_id,
            student_id
        )
);


-- ============================================================
-- 18. SUBMISSION ATTACHMENTS
-- ============================================================

CREATE TABLE public.submission_attachments (
    id uuid NOT NULL DEFAULT gen_random_uuid(),

    submission_id uuid NOT NULL,

    file_name text NOT NULL,

    file_url text NOT NULL,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT submission_attachments_pkey
        PRIMARY KEY (id),

    CONSTRAINT submission_attachments_submission_id_fkey
        FOREIGN KEY (submission_id)
        REFERENCES public.student_classwork_submissions(id)
        ON DELETE CASCADE
);


-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_sections_school_year
    ON public.sections(school_year_id);

CREATE INDEX idx_subject_offerings_subject
    ON public.subject_offerings(subject_id);

CREATE INDEX idx_subject_offerings_section
    ON public.subject_offerings(section_id);

CREATE INDEX idx_subject_offerings_teacher
    ON public.subject_offerings(teacher_id);

CREATE INDEX idx_subject_offerings_school_year
    ON public.subject_offerings(school_year_id);

CREATE INDEX idx_student_enrollments_student
    ON public.student_enrollments(student_id);

CREATE INDEX idx_student_enrollments_offering
    ON public.student_enrollments(subject_offering_id);

CREATE INDEX idx_teacher_schedule_offering
    ON public.teacher_schedule(subject_offering_id);

CREATE INDEX idx_classwork_items_offering
    ON public.classwork_items(subject_offering_id);

CREATE INDEX idx_classwork_attachments_classwork
    ON public.classwork_attachments(classwork_id);

CREATE INDEX idx_submissions_classwork
    ON public.student_classwork_submissions(classwork_id);

CREATE INDEX idx_submissions_student
    ON public.student_classwork_submissions(student_id);

CREATE INDEX idx_submission_attachments_submission
    ON public.submission_attachments(submission_id);


-- ============================================================
-- DEFAULT SCHOOL YEAR
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
