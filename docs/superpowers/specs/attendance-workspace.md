# Attendance Workspace Specification

**Status:** Draft for review  
**Scope:** Teacher Attendance Workspace, plus the minimal secure/paginated data-access update required to keep the existing student attendance log working after direct client table access is blocked. No student attendance redesign.
**Implementation gate:** Do not implement until this spec and a subsequent implementation plan are approved.

## Goal

Replace the current in-memory attendance marking flow with a compact, data-backed teacher workspace for recording attendance, reviewing paginated history, and understanding attendance trends. Manual entry is supported now. RFID remains explicitly unavailable until hardware and its integration protocol exist.

## Existing project context

- Teacher subject offerings and student enrollments are already queried from Supabase. Student records include first, middle, and last names and gender.
- The schema includes `teacher_schedule` and `attendance_records`. The attendance table already has `recorded_by`, a unique daily key per student and subject offering, and a date index.
- Attendance persistence is currently stubbed in `SupabaseAttendanceRepository`; the current UI marks statuses only in memory and has no functional history or analytics.
- `AttendanceRecord` has a `method` string, but it does not currently represent a reliable persisted capture source.
- The app authenticates users with Firebase. Existing Supabase Edge Functions use `requireFirebaseUser` and a server-side service-role client, but attendance-specific authorization and deployed attendance policies have not been verified.
- `fl_chart` is not currently a project dependency.
- `Master_Plan.md` defines a separate 12-absence per-subject/term warning and a school-year-wide absence review. This workspace's requested 3-absence range warning must not trigger enrollment changes or account deactivation.
- The checked-in schema definitions are not fully consistent. In particular, `002_supabas.sql` models the attendance-to-enrollment relationship with separate single-column foreign keys, while `001_initial_schema.sql` uses a composite relationship. Confirm the deployed schema before writing an additive migration.
- No attendance RLS policies are present in the checked-in migrations. Attendance client operations must therefore go through a Firebase-authenticated Edge Function; do not add direct client-side table access that trusts a submitted teacher ID.

## Workspace structure

One teacher attendance workspace contains two primary views:

1. **Take Attendance**
2. **History & Analytics**

The selected teacher subject offering is shared when possible between views. Changing the offering or date must clearly reload the relevant data and must not silently discard unsaved attendance changes.

## Take Attendance

### Selection and roster

- Select a subject offering/section from the signed-in teacher's actual active offerings; do not use sample data.
- Select an attendance date with a date picker.
- Display names in DepEd order as `Last name, First name, Middle initial` (for example, `Dela Cruz, Juan H.`); sort case-insensitively by last name, then first name, then middle name.
- Group the roster into Male and Female lists. Students whose gender is missing or does not match either supported value must remain visible in a clearly labeled **Unspecified** group rather than disappearing.
- The limit of 50 male and 50 female students is a roster capacity, not a page size. Paginate the combined roster in pages of 30 students, keeping the Male group before the Female group and sorting each group by the name order above. A page boundary can fall within a gender group or between groups; the page count is across all students, not reset for each gender. Since a section is capped at 100 total students, load its roster once and reveal subsequent 30-student pages locally; do not re-read the database just to reveal the next page.
- Keep the current text search behavior if it can be preserved without causing extra roster fetches.

### Status entry and save

- Allow each student to be marked `Present`, `Late`, `Absent`, or `Excused`.
- Show live counts for all four statuses and the number not yet marked. Counts describe the selected offering and date, not merely the currently visible search results.
- Provide a clear save action and confirmation/result feedback. Failed loads and failed saves must be shown as errors, never as an empty class or a successful save.
- Batch upsert the selected offering/date roster in one repository operation using the existing uniqueness key `(student_id, subject_offering_id, attendance_date)`.
- Route app attendance operations through a Supabase Edge Function. Verify the Firebase ID token with the existing shared Firebase verifier, resolve the teacher from the verified UID and `public.users`, and verify that the selected offering belongs to that teacher before any read or write. Never trust a caller-supplied teacher ID as authorization.
- Preserve the existing student **My Attendance Logs** screen through a self-only Edge Function action: derive the student ID from the verified Firebase UID, never accept another student ID, provide a server-side summary and 20-row paginated history, and replace the screen's `A01` placeholder with the signed-in student identity. Keep the existing screen layout and summary semantics.
- Do not silently mark unselected students absent. Require explicit status selection for each student, or obtain approval for a separate bulk-marking behavior.
- On retry, the same batch must be idempotent. A stale or duplicate request must not create duplicate daily records.

### Capture source and RFID

- The manual mode is the only enabled capture mode until real hardware integration is delivered.
- Show **RFID Hardware Not Connected** and keep RFID actions disabled. Do not simulate scans, card reads, or RFID attendance.
- Persist a normalized source value (`manual` or future `rfid`) for each saved attendance record. Do not overload source with the subject name or a display label.
- The saved record's source is distinct from its last editor: editing a record must not rewrite how it was originally captured.

## History & Analytics

### Filters and summary

- Select a subject offering and a date range using **This week**, **This month**, or **Custom range**.
- Custom range requires a start and end date; reject a start date later than the end date.
- Display KPI cards for **Total Presence Rate**, **Absences & Excuses**, and **Attendance Warnings**.
- Provide a Present-versus-Absent/Excused trend line and a presence breakdown visualization using `fl_chart`, with readable labels, date markers, and a useful empty state when no records exist.
- Provide an at-risk list of students with at least three `Absent` records in the selected range. Show the count and enough student/section identity to distinguish students. This is a review warning only; it does not drop or deactivate a student.
- Show a detailed activity log with student, section, status, attendance date, recorded time when available, and capture source. Existing schema does not store a time-of-day; add a timestamp field only if the product requires actual recorded time in the log. Never display a fabricated time.
- Keep the existing student **My Attendance Logs** screen visually unchanged except for replacing the placeholder student ID with the authenticated user and adding server-paged 20-row history. Return its existing Present/Total Days/Rate summary as server aggregates so pagination does not change the summary denominator or fetch all rows.

### Pagination and query bounds

- The activity log and any record history list must use server-side pagination, with a stable ordering and page size (proposed default: 20).
- Date and offering filters must be applied server-side before pagination.
- Analytics must not fetch an unbounded attendance history into the client. Use bounded date-range queries and/or a database aggregation endpoint for counts and trend buckets.
- The roster may be loaded once per selected offering; changing only a local display filter must not trigger a database read.

## Corrections and audit

- Teachers can select a date and correct an existing attendance record.
- A correction requires a non-empty edit reason and displays the current value before confirmation.
- Keep `recorded_by` as the original recorder and `source` as the original capture method; record the correcting user separately as `modified_by`.
- Preserve each correction in an append-only audit history (proposed `attendance_record_edits` table with record ID, previous/new status, reason, editor, and timestamp). Updating only `modified_by` and `edit_reason` on the attendance row is insufficient for a durable audit trail.
- Save the record update and audit entry atomically. The Edge Function must verify the Firebase teacher and offering ownership before invoking the privileged database operation.
- Define whether corrections can change source or attendance date only if a separately approved workflow needs it; the default correction flow changes status/remarks, not identity, offering, date, or original source.

## Additive data changes (proposal)

After confirming the deployed schema and existing RLS policies, add a new migration rather than rewriting an existing migration:

- Add `source` with a safe default of `manual` and a constraint for supported source values.
- Keep the existing `recorded_by`; add `modified_by` and a timestamp for the most recent modification if needed.
- Add an append-only `attendance_record_edits` table for correction history and its indexes.
- Add indexes supporting offering/date pagination and any aggregation queries. Avoid duplicate indexes if equivalent indexes already exist.
- Add a student/date index for the secure self-history page if no equivalent index exists; compute the student's existing summary in a bounded SQL aggregate.
- Route all client operations through the authenticated Edge Function. Keep the service-role key server-side only; the function must verify Firebase identity, teacher role, offering ownership, and (for edits) record/offering scope on every request.
- Implement correction and analytics aggregation as PostgreSQL operations callable only by the server-side function where atomicity/bounded aggregation is required. Keep attendance rows inaccessible to direct client queries; confirm existing grants/RLS before applying any RLS change.
- Migration must be compatible with existing rows and must not assume that the two checked-in schema snapshots match production.
- Treat any `recorded_at` time-of-day column as a separate decision; existing records only carry `attendance_date` and `created_at`.

The migration is contingent on confirming which schema snapshot is deployed and correcting any invalid or mismatched attendance foreign-key assumptions without destructive table recreation.

## Loading, empty, error, and offline behavior

- Show distinct loading, no offerings, no enrolled students, no records for the selected date/range, and error states.
- Surface Supabase/network failures with a retry action. Do not catch and convert repository failures into a successful empty result.
- This scope does not add an offline attendance queue or claim that unsaved attendance synchronizes later. If offline writes are required, design and approve a durable local store, conflict policy, and retry queue separately.
- Unsaved manual selections remain visibly unsaved and are protected from accidental loss when changing offering/date.

## Accessibility and responsive behavior

- Use existing ClassRealm theme tokens and components; do not copy the reference image literally.
- Keep controls usable on phone, tablet, and desktop widths. Use responsive layout constraints and scrollable content without hiding the save action or list entries.
- Provide text labels and semantics for status controls, filters, chart summaries, selected state, and disabled RFID controls. Do not communicate status by color alone.
- Use accessible touch targets, visible focus/pressed states, and readable contrast in light and dark themes.

## Proposed calculation rules for approval

These rules are explicit proposals because the current product rules do not define all KPI denominators:

- **Status totals:** count persisted records for the selected offering and range, separated into the four statuses.
- **Presence rate:** `(Present + Late) / (Present + Late + Absent)`. Exclude Excused from the denominator and display excused counts separately.
- **At-risk tracker:** count only explicit `Absent` records; list at three or more in the selected range. Excused records remain visible in KPIs but do not count toward this new range-based warning.
- **Unmarked students and non-class days:** do not infer an absence from a missing record. Schedule/holiday-aware denominator logic requires complete and authoritative schedule/calendar data and a separately approved rule.
- **Trend buckets:** aggregate by day for ranges up to 31 days, by week up to 180 days, and by month for longer ranges. Use local calendar dates consistently.
- These range-based KPIs are separate from the existing 12-absence per-term and 20% school-year policies in `Master_Plan.md`.

## Prerequisites and out of scope

Before implementation can be considered fully usable, the teacher needs an active subject offering with enrolled students. The project has a `teacher_schedule` schema and schedule repository, but this review cannot confirm that each teacher has completed schedule setup or that production data is present. Set up and verify the teacher's class/section, enrollment roster, and (if class-day-aware analytics are desired) schedule data first.

Out of scope for this phase:

- RFID hardware, student card registration, device identity, event protocol, and real RFID capture.
- Offline attendance persistence and background synchronization.
- School calendar, holidays, special sessions, and automatic absence generation.
- Automatic student drop/deactivation or notifications based on the new 3-absence warning.
- Parent attendance screens and exports; redesigning the student attendance screen.

The minimal student log data-access/pagination compatibility work above is in scope; redesigning student attendance visuals or adding parent attendance access remains out of scope.

## Acceptance criteria

1. A teacher can load only their real offerings and enrolled roster, grouped Male then Female, displayed surname-first with a middle initial, and paginated in combined 30-student pages.
2. The date-specific roster supports all four statuses, live counts, visible unsaved state, and one reliable batch save.
3. Saved rows retain an accurate `manual` source; RFID is visibly disconnected and cannot generate records.
4. History filters by offering and week/month/custom range; logs load in bounded server-side pages and show only persisted values.
5. KPI, trend, breakdown, and at-risk views use the approved calculation rules and show loading, empty, and error states.
6. An authenticated, offering-authorized teacher can correct a record only with a reason, and every correction is auditable without replacing the original recorder/source.
7. Database reads are bounded, errors are surfaced, and no missing record is silently treated as an absence.
8. Tests cover sorting/grouping, status counts, save/upsert, source mapping, pagination/filtering, analytics rules, edit-reason enforcement, error states, and the honest disconnected RFID state.
9. The existing student log uses only the verified student's own records, shows its existing Present/Total Days/Rate summary from a server aggregate, and loads records in bounded 20-row pages without changing its existing visual layout.

## Review decisions requested

Approved policy choices:

1. `Late` counts as present in **Total Presence Rate**.
2. `Excused` is excluded from the presence-rate denominator and the new three-absence warning, but remains separately visible.
3. Attendance date is teacher-selectable; do not infer attendance from schedule gaps.
4. Use the real persisted creation timestamp for new records and show date-only for legacy rows when no reliable capture time exists.
5. Attendance operations use an authenticated Supabase Edge Function that verifies Firebase identity and offering ownership; do not expose service-role credentials to the Flutter client.
