-- Require canonical middle initials for new and updated records.
-- Existing rows are not validated here so legacy full middle names remain
-- untouched until they can be reviewed and cleaned up separately.

DO $$
DECLARE
  target_table text;
  constraint_name text;
BEGIN
  FOREACH target_table IN ARRAY ARRAY[
    'student_profiles',
    'teacher_profiles',
    'parent_profiles',
    'admin_teacher_email_challenges'
  ]
  LOOP
    constraint_name := target_table || '_middle_initial_format_check';

    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conname = constraint_name
        AND conrelid = format('public.%I', target_table)::regclass
    ) THEN
      EXECUTE format(
        'ALTER TABLE public.%I ADD CONSTRAINT %I CHECK (middle_name IS NULL OR middle_name ~ %L) NOT VALID',
        target_table,
        constraint_name,
        '^[A-ZÑ]\.$'
      );
    END IF;
  END LOOP;
END $$;
