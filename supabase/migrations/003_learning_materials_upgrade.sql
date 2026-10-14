-- Migration 003: Learning Materials Google Drive-style & Privacy Upgrade
-- Adds visibility and metadata, creates storage bucket and policies

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'learning_materials',
  'learning_materials',
  true,
  5242880,
  ARRAY[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation'
  ]
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

ALTER TABLE public.folders 
ADD COLUMN IF NOT EXISTS is_visible_to_students boolean NOT NULL DEFAULT true;

ALTER TABLE public.learning_materials 
ADD COLUMN IF NOT EXISTS is_visible_to_students boolean NOT NULL DEFAULT true;

ALTER TABLE public.learning_materials 
ADD COLUMN IF NOT EXISTS title character varying;

ALTER TABLE public.learning_materials 
ADD COLUMN IF NOT EXISTS description text;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' 
        AND schemaname = 'storage' 
        AND policyname = 'Public Access Learning Materials'
    ) THEN
        CREATE POLICY "Public Access Learning Materials" 
        ON storage.objects FOR ALL 
        USING (bucket_id = 'learning_materials')
        WITH CHECK (bucket_id = 'learning_materials');
    END IF;
END $$;
