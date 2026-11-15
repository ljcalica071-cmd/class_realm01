-- Migration 031: Fix mime_type column length and file size check constraints
-- Resolves 'value too long for type character varying(50)' on .docx, .pptx, and .xlsx uploads
-- (which have MIME types up to 72 characters long, e.g. application/vnd.openxmlformats-officedocument.wordprocessingml.document)
-- Also updates legacy 3 MB limit check on learning_materials to match the 15 MB system limit.

ALTER TABLE public.learning_materials
  ALTER COLUMN mime_type TYPE character varying(100);

ALTER TABLE public.classwork_attachments
  ALTER COLUMN mime_type TYPE character varying(100);

ALTER TABLE public.submission_attachments
  ALTER COLUMN mime_type TYPE character varying(100);

ALTER TABLE public.learning_materials
  DROP CONSTRAINT IF EXISTS learning_materials_file_size_bytes_check;

ALTER TABLE public.learning_materials
  ADD CONSTRAINT learning_materials_file_size_bytes_check
  CHECK (file_size_bytes IS NULL OR (file_size_bytes >= 0 AND file_size_bytes <= 15728640));
