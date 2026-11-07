-- Migration 017: Assessment results released, score tracking, and text responses
ALTER TABLE public.digital_assessments 
ADD COLUMN IF NOT EXISTS results_released boolean NOT NULL DEFAULT false;

ALTER TABLE public.assessment_attempts 
ADD COLUMN IF NOT EXISTS score_earned numeric NOT NULL DEFAULT 0 CHECK (score_earned >= 0);

ALTER TABLE public.assessment_responses 
ADD COLUMN IF NOT EXISTS text_response text;
