-- Migration 010: Create Teacher Lesson Plans Table for SHS iLAW Generator
-- Safe, non-destructive migration strictly isolated to teacher lesson planning.
-- Preserves all existing tables, student records, gradebook, and attendance.

CREATE TABLE IF NOT EXISTS public.teacher_lesson_plans (
    id varchar(100) NOT NULL,
    teacher_id varchar(30) NOT NULL,
    teacher_name varchar(100) NOT NULL DEFAULT '',
    grade_level varchar(30) NOT NULL DEFAULT 'Grade 11',
    term varchar(30) NOT NULL DEFAULT 'Term 1',
    quarter varchar(30) NOT NULL DEFAULT 'Term 1',
    subject varchar(150) NOT NULL DEFAULT '',
    topic varchar(255) NOT NULL DEFAULT '',
    duration_minutes integer NOT NULL DEFAULT 60,
    teaching_strategy text DEFAULT '',
    learning_competency text DEFAULT '',
    intended_outcomes text DEFAULT '',
    learning_content text DEFAULT '',
    assessment text DEFAULT '',
    work_experiences text DEFAULT '',
    template_type varchar(50) DEFAULT 'ilawModified',
    content_source varchar(50) DEFAULT 'curriculumBased',
    target_proficiency varchar(50) DEFAULT 'developing',
    number_of_sessions integer DEFAULT 4,
    language varchar(50) DEFAULT 'English',
    deped_order_citation text DEFAULT 'DepEd Order No. 003, s. 2026 (Guidelines on the Responsible Use of AI in Basic Education)',
    sessions jsonb DEFAULT '[]'::jsonb,
    rubric_items jsonb DEFAULT '[]'::jsonb,
    status varchar(30) DEFAULT 'draft',
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

-- Row Level Security (RLS)
ALTER TABLE public.teacher_lesson_plans ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'teacher_lesson_plans' 
          AND policyname = 'Teachers can manage their own lesson plans'
    ) THEN
        CREATE POLICY "Teachers can manage their own lesson plans" 
            ON public.teacher_lesson_plans
            FOR ALL 
            TO authenticated 
            USING (teacher_id = auth.uid()::text OR auth.role() = 'service_role')
            WITH CHECK (teacher_id = auth.uid()::text OR auth.role() = 'service_role');
    END IF;
END $$;
