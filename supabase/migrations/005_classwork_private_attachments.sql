-- Migration 005: Secure Classwork Private Attachments Storage & Metadata
-- Creates a private storage bucket for classwork attachments (PDF, DOC, DOCX up to 5 MiB)
-- Adds storage_path column to classwork_attachments and allows private server-mediated access.

-- 1. Create private storage bucket 'classwork_attachments'
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'classwork_attachments',
  'classwork_attachments',
  false,
  5242880,
  ARRAY[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]
)
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = 5242880,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 2. Add nullable storage_path column to public.classwork_attachments
ALTER TABLE public.classwork_attachments
ADD COLUMN IF NOT EXISTS storage_path varchar(500);

-- 3. Make storage_url nullable for compatibility with private attachments
ALTER TABLE public.classwork_attachments
ALTER COLUMN storage_url DROP NOT NULL;

-- 4. Index on storage_path for fast path queries and cleanups
CREATE INDEX IF NOT EXISTS idx_classwork_attachments_storage_path
ON public.classwork_attachments(storage_path);

-- Notice: No public read policy is granted for 'classwork_attachments'.
-- Enrolled students receive time-limited signed download URLs generated server-side.
