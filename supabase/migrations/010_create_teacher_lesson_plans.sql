-- Migration 010: Normalized Database Schema for Teacher Lesson Plans (SHS iLAW Generator)
-- 3NF Normalized Relational Architecture with Strict Teacher Isolation RLS

-- 1. Main Table: Lesson Plan Headers & Metadata
CREATE TABLE IF NOT EXISTS public.teacher_lesson_plans (
    id varchar(100) NOT NULL,
    teacher_id varchar(30) NOT NULL,
    grade_level varchar(30) NOT NULL DEFAULT 'Grade 11',
    term varchar(30) NOT NULL DEFAULT 'Term 1',
    subject varchar(150) NOT NULL DEFAULT '',
    topic varchar(255) NOT NULL DEFAULT '',
    duration_minutes integer NOT NULL DEFAULT 60,
    status varchar(30) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'approved')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT teacher_lesson_plans_pkey PRIMARY KEY (id),
    CONSTRAINT teacher_lesson_plans_teacher_id_fkey 
        FOREIGN KEY (teacher_id) 
        REFERENCES public.users(id) 
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_teacher_lesson_plans_teacher 
    ON public.teacher_lesson_plans(teacher_id);

CREATE INDEX IF NOT EXISTS idx_teacher_lesson_plans_updated_at 
    ON public.teacher_lesson_plans(updated_at DESC);

-- Drop legacy unnormalized columns from teacher_lesson_plans if table existed previously
ALTER TABLE public.teacher_lesson_plans
    DROP COLUMN IF EXISTS teacher_name,
    DROP COLUMN IF EXISTS quarter,
    DROP COLUMN IF EXISTS teaching_strategy,
    DROP COLUMN IF EXISTS learning_competency,
    DROP COLUMN IF EXISTS intended_outcomes,
    DROP COLUMN IF EXISTS learning_content,
    DROP COLUMN IF EXISTS assessment,
    DROP COLUMN IF EXISTS work_experiences,
    DROP COLUMN IF EXISTS template_type,
    DROP COLUMN IF EXISTS content_source,
    DROP COLUMN IF EXISTS target_proficiency,
    DROP COLUMN IF EXISTS number_of_sessions,
    DROP COLUMN IF EXISTS language,
    DROP COLUMN IF EXISTS deped_order_citation,
    DROP COLUMN IF EXISTS sessions,
    DROP COLUMN IF EXISTS rubric_items;

-- 2. Normalized Sections & Content Table (1-to-1)
CREATE TABLE IF NOT EXISTS public.lesson_plan_sections (
    lesson_plan_id varchar(100) NOT NULL,
    learning_competency text DEFAULT '',
    intended_outcomes text DEFAULT '',
    learning_content text DEFAULT '',
    work_experiences text DEFAULT '',
    assessment text DEFAULT '',
    teaching_strategy text DEFAULT '',
    template_type varchar(50) DEFAULT 'ilawModified',
    content_source varchar(50) DEFAULT 'curriculumBased',
    target_proficiency varchar(50) DEFAULT 'developing',
    number_of_sessions integer DEFAULT 4,
    language varchar(50) DEFAULT 'English',
    deped_order_citation text DEFAULT 'DepEd Order No. 003, s. 2026 (Guidelines on the Responsible Use of AI in Basic Education)',

    CONSTRAINT lesson_plan_sections_pkey PRIMARY KEY (lesson_plan_id),
    CONSTRAINT lesson_plan_sections_plan_fkey 
        FOREIGN KEY (lesson_plan_id) 
        REFERENCES public.teacher_lesson_plans(id) 
        ON DELETE CASCADE
);

-- 3. Normalized Sessions Table (1-to-Many relational sessions)
CREATE TABLE IF NOT EXISTS public.lesson_plan_sessions (
    id varchar(120) NOT NULL,
    lesson_plan_id varchar(100) NOT NULL,
    session_number integer NOT NULL DEFAULT 1,
    session_title varchar(255) NOT NULL DEFAULT '',
    objectives text DEFAULT '',
    learning_experiences text DEFAULT '',
    formative_assessment text DEFAULT '',
    parent_guide text DEFAULT '',
    community_experience text DEFAULT '',
    teacher_reflections text DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT lesson_plan_sessions_pkey PRIMARY KEY (id),
    CONSTRAINT lesson_plan_sessions_plan_fkey 
        FOREIGN KEY (lesson_plan_id) 
        REFERENCES public.teacher_lesson_plans(id) 
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_lesson_plan_sessions_plan 
    ON public.lesson_plan_sessions(lesson_plan_id, session_number);

-- 4. Normalized Rubrics Table (1-to-Many relational rubrics)
CREATE TABLE IF NOT EXISTS public.lesson_plan_rubrics (
    id varchar(120) NOT NULL,
    lesson_plan_id varchar(100) NOT NULL,
    criterion text NOT NULL DEFAULT '',
    is_met boolean NOT NULL DEFAULT true,
    notes text DEFAULT '',

    CONSTRAINT lesson_plan_rubrics_pkey PRIMARY KEY (id),
    CONSTRAINT lesson_plan_rubrics_plan_fkey 
        FOREIGN KEY (lesson_plan_id) 
        REFERENCES public.teacher_lesson_plans(id) 
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_lesson_plan_rubrics_plan 
    ON public.lesson_plan_rubrics(lesson_plan_id);

-- 5. Role Grants
GRANT ALL ON TABLE public.teacher_lesson_plans TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.lesson_plan_sections TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.lesson_plan_sessions TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.lesson_plan_rubrics TO anon, authenticated, service_role;

-- 6. Strict Teacher Isolation Row Level Security (RLS)
ALTER TABLE public.teacher_lesson_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_plan_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_plan_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_plan_rubrics ENABLE ROW LEVEL SECURITY;

-- Helper check function for current auth teacher uid
CREATE OR REPLACE FUNCTION public.current_auth_teacher_id()
RETURNS varchar(30)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid text;
BEGIN
    v_uid := COALESCE(
        NULLIF(current_setting('request.jwt.claim.sub', true), ''),
        (NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'),
        (NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'user_id'),
        auth.uid()::text
    );
    IF v_uid IS NULL OR TRIM(v_uid) = '' THEN
        RETURN NULL;
    END IF;
    RETURN LEFT(TRIM(v_uid), 30)::varchar(30);
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$;

-- RLS: Main Table Policies
DROP POLICY IF EXISTS "teacher_lesson_plans_select" ON public.teacher_lesson_plans;
CREATE POLICY "teacher_lesson_plans_select" 
    ON public.teacher_lesson_plans
    FOR SELECT 
    TO anon, authenticated
    USING (
        teacher_id = (auth.uid())::text
        OR teacher_id = public.current_auth_teacher_id()
        OR auth.role() = 'service_role'
    );

DROP POLICY IF EXISTS "teacher_lesson_plans_insert" ON public.teacher_lesson_plans;
CREATE POLICY "teacher_lesson_plans_insert" 
    ON public.teacher_lesson_plans
    FOR INSERT 
    TO anon, authenticated
    WITH CHECK (
        teacher_id = (auth.uid())::text
        OR teacher_id = public.current_auth_teacher_id()
        OR auth.role() = 'service_role'
    );

DROP POLICY IF EXISTS "teacher_lesson_plans_update" ON public.teacher_lesson_plans;
CREATE POLICY "teacher_lesson_plans_update" 
    ON public.teacher_lesson_plans
    FOR UPDATE 
    TO anon, authenticated
    USING (
        teacher_id = (auth.uid())::text
        OR teacher_id = public.current_auth_teacher_id()
        OR auth.role() = 'service_role'
    )
    WITH CHECK (
        teacher_id = (auth.uid())::text
        OR teacher_id = public.current_auth_teacher_id()
        OR auth.role() = 'service_role'
    );

DROP POLICY IF EXISTS "teacher_lesson_plans_delete" ON public.teacher_lesson_plans;
CREATE POLICY "teacher_lesson_plans_delete" 
    ON public.teacher_lesson_plans
    FOR DELETE 
    TO anon, authenticated
    USING (
        teacher_id = (auth.uid())::text
        OR teacher_id = public.current_auth_teacher_id()
        OR auth.role() = 'service_role'
    );

-- RLS: Sections Child Table Policies
DROP POLICY IF EXISTS "lesson_plan_sections_select" ON public.lesson_plan_sections;
CREATE POLICY "lesson_plan_sections_select" 
    ON public.lesson_plan_sections
    FOR SELECT 
    TO anon, authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.teacher_lesson_plans p
            WHERE p.id = lesson_plan_sections.lesson_plan_id
              AND (
                  p.teacher_id = (auth.uid())::text
                  OR p.teacher_id = public.current_auth_teacher_id()
                  OR auth.role() = 'service_role'
              )
        )
    );

DROP POLICY IF EXISTS "lesson_plan_sections_modify" ON public.lesson_plan_sections;
CREATE POLICY "lesson_plan_sections_modify" 
    ON public.lesson_plan_sections
    FOR ALL 
    TO anon, authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.teacher_lesson_plans p
            WHERE p.id = lesson_plan_sections.lesson_plan_id
              AND (
                  p.teacher_id = (auth.uid())::text
                  OR p.teacher_id = public.current_auth_teacher_id()
                  OR auth.role() = 'service_role'
              )
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.teacher_lesson_plans p
            WHERE p.id = lesson_plan_sections.lesson_plan_id
              AND (
                  p.teacher_id = (auth.uid())::text
                  OR p.teacher_id = public.current_auth_teacher_id()
                  OR auth.role() = 'service_role'
              )
        )
    );

-- RLS: Sessions Child Table Policies
DROP POLICY IF EXISTS "lesson_plan_sessions_select" ON public.lesson_plan_sessions;
CREATE POLICY "lesson_plan_sessions_select" 
    ON public.lesson_plan_sessions
    FOR SELECT 
    TO anon, authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.teacher_lesson_plans p
            WHERE p.id = lesson_plan_sessions.lesson_plan_id
              AND (
                  p.teacher_id = (auth.uid())::text
                  OR p.teacher_id = public.current_auth_teacher_id()
                  OR auth.role() = 'service_role'
              )
        )
    );

DROP POLICY IF EXISTS "lesson_plan_sessions_modify" ON public.lesson_plan_sessions;
CREATE POLICY "lesson_plan_sessions_modify" 
    ON public.lesson_plan_sessions
    FOR ALL 
    TO anon, authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.teacher_lesson_plans p
            WHERE p.id = lesson_plan_sessions.lesson_plan_id
              AND (
                  p.teacher_id = (auth.uid())::text
                  OR p.teacher_id = public.current_auth_teacher_id()
                  OR auth.role() = 'service_role'
              )
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.teacher_lesson_plans p
            WHERE p.id = lesson_plan_sessions.lesson_plan_id
              AND (
                  p.teacher_id = (auth.uid())::text
                  OR p.teacher_id = public.current_auth_teacher_id()
                  OR auth.role() = 'service_role'
              )
        )
    );

-- RLS: Rubrics Child Table Policies
DROP POLICY IF EXISTS "lesson_plan_rubrics_select" ON public.lesson_plan_rubrics;
CREATE POLICY "lesson_plan_rubrics_select" 
    ON public.lesson_plan_rubrics
    FOR SELECT 
    TO anon, authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.teacher_lesson_plans p
            WHERE p.id = lesson_plan_rubrics.lesson_plan_id
              AND (
                  p.teacher_id = (auth.uid())::text
                  OR p.teacher_id = public.current_auth_teacher_id()
                  OR auth.role() = 'service_role'
              )
        )
    );

DROP POLICY IF EXISTS "lesson_plan_rubrics_modify" ON public.lesson_plan_rubrics;
CREATE POLICY "lesson_plan_rubrics_modify" 
    ON public.lesson_plan_rubrics
    FOR ALL 
    TO anon, authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.teacher_lesson_plans p
            WHERE p.id = lesson_plan_rubrics.lesson_plan_id
              AND (
                  p.teacher_id = (auth.uid())::text
                  OR p.teacher_id = public.current_auth_teacher_id()
                  OR auth.role() = 'service_role'
              )
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.teacher_lesson_plans p
            WHERE p.id = lesson_plan_rubrics.lesson_plan_id
              AND (
                  p.teacher_id = (auth.uid())::text
                  OR p.teacher_id = public.current_auth_teacher_id()
                  OR auth.role() = 'service_role'
              )
        )
    );
