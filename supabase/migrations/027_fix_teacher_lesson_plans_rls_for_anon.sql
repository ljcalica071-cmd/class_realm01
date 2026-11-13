-- Migration 027: Update RLS Policies for Teacher Lesson Plans (Firebase Auth Anon Client Compatibility)
-- Enables full SELECT, INSERT, UPDATE, DELETE for anon and authenticated clients
-- so that the web app (Vercel) and local app can view and manage teacher lesson plans seamlessly.

-- 1. Main Table: teacher_lesson_plans
ALTER TABLE public.teacher_lesson_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "teacher_lesson_plans_select" ON public.teacher_lesson_plans;
DROP POLICY IF EXISTS "teacher_lesson_plans_insert" ON public.teacher_lesson_plans;
DROP POLICY IF EXISTS "teacher_lesson_plans_update" ON public.teacher_lesson_plans;
DROP POLICY IF EXISTS "teacher_lesson_plans_delete" ON public.teacher_lesson_plans;
DROP POLICY IF EXISTS "teacher_lesson_plans_anon_all" ON public.teacher_lesson_plans;

CREATE POLICY "teacher_lesson_plans_select" 
    ON public.teacher_lesson_plans
    FOR SELECT 
    TO anon, authenticated
    USING (true);

CREATE POLICY "teacher_lesson_plans_insert" 
    ON public.teacher_lesson_plans
    FOR INSERT 
    TO anon, authenticated
    WITH CHECK (true);

CREATE POLICY "teacher_lesson_plans_update" 
    ON public.teacher_lesson_plans
    FOR UPDATE 
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "teacher_lesson_plans_delete" 
    ON public.teacher_lesson_plans
    FOR DELETE 
    TO anon, authenticated
    USING (true);

-- 2. Sections: lesson_plan_sections
ALTER TABLE public.lesson_plan_sections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "lesson_plan_sections_select" ON public.lesson_plan_sections;
DROP POLICY IF EXISTS "lesson_plan_sections_modify" ON public.lesson_plan_sections;
DROP POLICY IF EXISTS "lesson_plan_sections_all" ON public.lesson_plan_sections;

CREATE POLICY "lesson_plan_sections_select" 
    ON public.lesson_plan_sections
    FOR SELECT 
    TO anon, authenticated
    USING (true);

CREATE POLICY "lesson_plan_sections_modify" 
    ON public.lesson_plan_sections
    FOR ALL 
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

-- 3. Sessions: lesson_plan_sessions
ALTER TABLE public.lesson_plan_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "lesson_plan_sessions_select" ON public.lesson_plan_sessions;
DROP POLICY IF EXISTS "lesson_plan_sessions_modify" ON public.lesson_plan_sessions;
DROP POLICY IF EXISTS "lesson_plan_sessions_all" ON public.lesson_plan_sessions;

CREATE POLICY "lesson_plan_sessions_select" 
    ON public.lesson_plan_sessions
    FOR SELECT 
    TO anon, authenticated
    USING (true);

CREATE POLICY "lesson_plan_sessions_modify" 
    ON public.lesson_plan_sessions
    FOR ALL 
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

-- 4. Rubrics: lesson_plan_rubrics
ALTER TABLE public.lesson_plan_rubrics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "lesson_plan_rubrics_select" ON public.lesson_plan_rubrics;
DROP POLICY IF EXISTS "lesson_plan_rubrics_modify" ON public.lesson_plan_rubrics;
DROP POLICY IF EXISTS "lesson_plan_rubrics_all" ON public.lesson_plan_rubrics;

CREATE POLICY "lesson_plan_rubrics_select" 
    ON public.lesson_plan_rubrics
    FOR SELECT 
    TO anon, authenticated
    USING (true);

CREATE POLICY "lesson_plan_rubrics_modify" 
    ON public.lesson_plan_rubrics
    FOR ALL 
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

-- Grants
GRANT ALL ON TABLE public.teacher_lesson_plans TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.lesson_plan_sections TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.lesson_plan_sessions TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.lesson_plan_rubrics TO anon, authenticated, service_role;

