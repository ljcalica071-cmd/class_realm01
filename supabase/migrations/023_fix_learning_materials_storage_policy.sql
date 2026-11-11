-- Fix storage policy for learning_materials bucket
-- Ensures public role has both USING and WITH CHECK permissions on learning_materials bucket
-- allowing uploadBinary (which uses ON CONFLICT DO UPDATE / upsert) and file removals.

ALTER POLICY "Public Access Learning Materials" ON storage.objects
USING (bucket_id = 'learning_materials')
WITH CHECK (bucket_id = 'learning_materials');
