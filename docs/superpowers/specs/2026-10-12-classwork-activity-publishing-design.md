# Classwork Activity Publishing Design

## Goal

Make teacher-created activities and assignments real Supabase classwork that appears in the enrolled student's dashboard, including an optional downloadable teacher attachment. Replace validation dialogs in the create flow with inline required-field errors.

## User-approved decisions

- The teacher assigns each activity to one subject offering (one subject, section, and term), selected explicitly in the form.
- The teacher may attach zero or one file. Accepted formats are PDF, DOC, and DOCX only.
- The maximum file size is 5 MiB (5 * 1024 * 1024 bytes).
- The attachment is stored privately. Only enrolled students receive a short-lived link, which opens through the device's available viewer/browser.
- Title, total points, and detailed instructions are required and display an asterisk. Validation errors appear under and around their input fields, not in modal dialogs.
- Preserve the existing total-points rule: whole numbers from 10 through 100.
- Do not add an arbitrary per-minute upload quota. Enforce teacher authentication/ownership, one file per classwork item, and the 5 MiB size cap. A request-frequency policy can be added later if operational evidence calls for one.

## Current state

- `CreateRequirementFlowDialog` uses modal validation and writes activities to `MockDatabase`.
- The teacher dashboard and unified assessments tab read activities from `MockDatabase`.
- The student dashboard already loads published `classwork_items` for a student's enrolled offerings through the `student-dashboard` Edge Function.
- The student classwork response/card does not include or display `classwork_attachments`.
- `classwork_items` and `classwork_attachments` already exist in the schema. Each classwork item belongs to a `subject_offering_id`.
- The project verifies Firebase identity in Supabase Edge Functions and uses the service role for database operations.
- The existing `learning_materials` bucket is public; classwork files must not be placed there because student-specific access is required.

## Proposed architecture

1. Add a private `classwork_attachments` Storage bucket configured for PDF, DOC, and DOCX MIME types with a 5 MiB per-object limit. Keep object access server-mediated; do not add public-read policies.
2. Add a teacher classwork Edge Function following the existing Firebase-token verification pattern. It must verify the caller is an active teacher and owns the selected subject offering before issuing a one-use upload authorization or publishing classwork.
3. Upload one selected file to a teacher-scoped, unpredictable Storage path using the signed upload authorization. Validate extension, MIME type, and size in the client and Edge Function; enforce MIME type and size again in Storage. On publish, verify the uploaded object and write the classwork item and attachment metadata. If persistence fails after upload, remove the unreferenced object and return an actionable error.
4. Store the private object path and attachment metadata in `classwork_attachments`, not a public URL. Publish without an attachment remains supported.
5. Extend teacher classwork repository/dashboard loading so created items are read from Supabase and appear in the teacher list after publish or refresh. Existing edit/delete actions on these persisted classwork items must also update/delete Supabase records and clean up replaced/deleted Storage objects; do not leave these actions pointed at `MockDatabase`. Keep unrelated mock-backed quiz/exam flows out of scope.
6. Add a `storage_path` column to `classwork_attachments` in a forward migration; retain the existing `storage_url` column for compatibility and do not put a public URL in it for new private attachments.
7. Extend `student-dashboard` to return attachment metadata and a short-lived signed download URL only for published classwork belonging to the student's enrolled offerings. Add the attachment to the student model and classwork card; tapping it opens the signed link through the platform viewer/browser. Never expose service-role credentials or a permanent public URL to Flutter.

## Form behavior

- Replace the current section-only multi-selection with a single subject-offering selector, showing enough context (subject and section) to disambiguate classes.
- Show a required `*` in the labels for Title, Total Points, and Detailed Instructions.
- After submit, show a red outline and field-specific message for each missing/invalid required field. Clear each field's error as the user corrects that field. Do not show validation errors in `AppModals`.
- Respect the existing database limits of 100 characters for the title and 1,000 characters for detailed instructions so overlong input is rejected or constrained before persistence.
- Keep the score input restricted to whole numbers and validate the existing 10-100 range.
- Allow the attachment field to be empty. When a file is selected, show its name and size and provide a way to replace/remove it. Reject unsupported extensions and files larger than 5 MiB before uploading.
- During upload/publish, prevent duplicate submissions and show progress. On failure, keep entered values and the selected file so the teacher can retry; show the error inline near the attachment/publish controls. Show success only after database and storage records are consistent.

## Failure handling and consistency

- A cancelled file picker is not an error and leaves the form unchanged.
- A selected file that cannot be read, has a disallowed extension/MIME type, or exceeds the limit is rejected with visible field-level feedback. The Storage bucket enforces MIME type and size; extension is validated by the client and Edge Function.
- A failed upload or database write must not leave a published classwork item with a broken attachment. Clean up an uploaded object if its database write fails; if cleanup also fails, report both the original failure and cleanup status for later recovery.
- When replacing or deleting an attachment, persist the database change first and then remove the old Storage object. If Storage cleanup fails, surface the failure and retain enough path information for a retry; never delete the object before the record update succeeds.
- Student dashboard attachment-link generation errors must be surfaced rather than silently fabricating a URL.
- Signed download links expire; refreshing the student dashboard obtains a fresh link.

## Scope boundaries

- Includes activity/assignment and performance-task items created through `CreateRequirementFlowDialog`, the matching teacher classwork list, and student classwork rendering.
- Does not migrate quizzes/exams, student submissions, learning materials, or unrelated teacher dashboard data from mocks.
- Does not deploy functions or apply a migration to a remote Supabase project as part of the design/specification stage.

## Verification plan

- Widget tests: required markers, inline missing/invalid errors, errors clearing on correction, and absence of modal validation.
- Repository/model tests: classwork type/score/deadline/attachment serialization and handling missing/invalid attachment response data.
- Edge Function tests: reject non-teachers, offerings not owned by caller, unsupported formats, oversized files, and non-enrolled student access; accept valid PDF/DOC/DOCX up to 5 MiB.
- Student widget tests: render attachment name and invoke the platform open action from its signed link.
- Run targeted Flutter tests and `flutter analyze` on changed code. Validate Edge Function tests with the repository's existing Deno test setup if available.
