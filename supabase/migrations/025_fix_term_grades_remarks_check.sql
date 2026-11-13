-- Migration 025: Fix term_grades remarks check constraint to be case-insensitive
-- Prevents PostgrestException 23514 when remarks are passed in UPPERCASE (e.g. 'PASSED', 'FAILED')
-- or Title Case (e.g. 'Passed', 'Failed', 'Incomplete', 'Dropped').

ALTER TABLE term_grades DROP CONSTRAINT IF EXISTS term_grades_remarks_check;

ALTER TABLE term_grades 
  ADD CONSTRAINT term_grades_remarks_check 
  CHECK (upper(remarks::text) = ANY (ARRAY['PASSED', 'FAILED', 'INCOMPLETE', 'DROPPED']));

