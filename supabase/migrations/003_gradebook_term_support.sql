ALTER TABLE public.subject_offerings
    ADD COLUMN IF NOT EXISTS terms_taught smallint NOT NULL DEFAULT 3
        CHECK (terms_taught BETWEEN 1 AND 3),
    ADD COLUMN IF NOT EXISTS term_block varchar(20) NOT NULL DEFAULT '1ST, 2ND, 3RD',
    ADD COLUMN IF NOT EXISTS units_per_term numeric(4,1) NOT NULL DEFAULT 2.0,
    ADD COLUMN IF NOT EXISTS st1_weight numeric(5,2) NOT NULL DEFAULT 30.00,
    ADD COLUMN IF NOT EXISTS st2_weight numeric(5,2) NOT NULL DEFAULT 30.00,
    ADD COLUMN IF NOT EXISTS te_weight numeric(5,2) NOT NULL DEFAULT 40.00;

CREATE TABLE IF NOT EXISTS public.gradebook_term_sheets (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    subject_offering_id uuid NOT NULL
        REFERENCES public.subject_offerings(id) ON DELETE CASCADE,
    term_number smallint NOT NULL CHECK (term_number BETWEEN 1 AND 3),
    hps_json jsonb NOT NULL DEFAULT '{"ww":{},"pt":{},"ex":{}}'::jsonb,
    scores_json jsonb NOT NULL DEFAULT '{}'::jsonb,
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT gradebook_term_sheets_pkey PRIMARY KEY (id),
    CONSTRAINT gradebook_term_sheets_unique_offering_term
        UNIQUE (subject_offering_id, term_number)
);

-- One offering now owns multiple term records, so term number must join the key.
ALTER TABLE public.term_grades
    ADD COLUMN IF NOT EXISTS term_number smallint NOT NULL DEFAULT 1
        CHECK (term_number BETWEEN 1 AND 3);

ALTER TABLE public.term_grades
    DROP CONSTRAINT IF EXISTS term_grades_unique_student_offering;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.term_grades'::regclass
          AND conname = 'term_grades_unique_student_offering_term'
    ) THEN
        ALTER TABLE public.term_grades
            ADD CONSTRAINT term_grades_unique_student_offering_term
            UNIQUE (student_id, subject_offering_id, term_number);
    END IF;
END
$$;
