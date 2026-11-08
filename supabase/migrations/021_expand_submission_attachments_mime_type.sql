-- Migration 021: Expand submission_attachments mime_type column length
-- Reason: docx MIME type 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
-- is 71 characters, which previously exceeded varchar(50) causing code 22001.

ALTER TABLE public.submission_attachments 
  ALTER COLUMN mime_type TYPE varchar(150);
