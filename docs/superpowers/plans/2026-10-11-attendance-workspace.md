# Attendance Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the approved teacher Attendance Workspace with reliable manual batch entry, honest RFID-unavailable state, paginated history, bounded analytics, audited corrections, and a minimal secure/paginated compatibility update for the existing student attendance log.

**Architecture:** Keep the two-view workspace in the teacher attendance feature, route attendance access through a Firebase-authenticated Supabase Edge Function, and isolate analytics calculations for testability. The function verifies the Firebase user, teacher role, and offering ownership before using a server-only service-role client; the student-log action derives and restricts the student ID to the verified student. Use additive Supabase migrations for source metadata, bounded analytics/student-summary operations, and an atomic correction/audit trail. Keep roster pagination local after one bounded roster read (30 students per combined page) and use server-side 20-row pages for growing activity logs.

**Tech Stack:** Flutter/Dart, Supabase/PostgreSQL, Flutter widget/unit tests, `fl_chart`.

**Spec:** `docs/superpowers/specs/attendance-workspace.md`

## Global Constraints

- The roster page size is 30 across Male then Female groups; do not reset pagination per gender.
- Activity history uses server-side pagination with a stable ordering and page size of 20.
- Never infer absence from a missing attendance row or silently convert a failed read into an empty successful result.
- Manual is the only enabled capture source; display **RFID Hardware Not Connected** and do not simulate reads.
- Corrections require a reason, preserve original `recorded_by` and `source`, and append an audit entry atomically.
- Analytics queries must be bounded or aggregated on the server; never fetch unbounded attendance history to calculate charts or warnings.
- Use the approved KPI rules: Late counts as present; Excused is excluded from the presence-rate denominator and the new three-absence warning.
- Keep unrelated pre-existing worktree changes intact; do not rewrite deployed schema or edit existing migrations.
- Do not expose the service-role key to Flutter. Verify Firebase identity and offering ownership in the Edge Function for every operation.
- Stop before applying migrations if the deployed schema and existing grants/RLS cannot be confirmed. Use only server-side, additive code/migration changes until deployment schema is verified.

## Review Focus

- **Roster changes while a page is partially revealed:** reset visible-page state only after confirming or preserving unsaved marks; test changing offering/date with dirty marks.
- **Unmarked students and non-class dates:** never convert missing rows into absences; test that an empty date loads unmarked statuses.
- **Duplicate/retried batch saves:** upsert by student/offering/date and prove retry does not create duplicates.
- **Teacher identity and offering authorization:** test a teacher cannot read, save, or edit another teacher's offering; enforce Firebase verification and offering ownership in the Edge Function.
- **Legacy rows without a trustworthy capture time or source:** map safely and do not display fabricated time or RFID provenance.
- **Student identity on the legacy attendance screen:** derive the requested user from the verified Firebase UID; test that a caller cannot request another student's records and that summary totals are not limited to the current page.

---

### Task 1: Confirm Edge Function security and database boundaries

**Files:**
- Inspect: `supabase/migrations/001_initial_schema.sql`
- Inspect: `supabase/migrations/002_supabas.sql`
- Inspect: deployed attendance schema and access controls if authorized read-only database tooling is available
- Inspect: `supabase/functions/_shared/firebase_admin.ts`
- Inspect: `supabase/functions/student-dashboard/index.ts`
- Inspect: `lib/data/repositories/auth_repository.dart`

**Interfaces:**
- Produces: confirmed local Firebase verification/service-role conventions and a clear record of production schema facts that remain unverified.

- [ ] **Step 1: Compare deployed attendance schema with the checked-in snapshots**

  Compare the two checked-in schema snapshots and document their conflicts. If read-only production inspection is unavailable, mark deployed columns, constraints, grants/RLS, and `recorded_by` identity as unknown; do not present either snapshot as confirmed production truth.

- [ ] **Step 2: Define Edge Function authorization checks**

  Use the shared Firebase verifier; resolve the verified UID's `public.users` row and require role `teacher`; verify every requested subject offering belongs to that UID and every edited attendance record belongs to that offering. Ignore/reject caller-supplied teacher IDs.

- [ ] **Step 3: Record the verified schema decisions in the plan/task notes**

  The current implementation path is the Firebase-authenticated Edge Function, not direct Flutter table access. If no read-only database tool is available, record deployed schema/RLS as unknown and do not apply migrations until an authorized schema review.

### Task 2: Define attendance data contracts and calculation tests

**Files:**
- Create: `lib/models/attendance_workspace_models.dart`
- Create: `lib/features/teacher/sub_features/attendance/utils/attendance_analytics_calculator.dart`
- Test: `test/features/teacher/attendance/attendance_analytics_calculator_test.dart`
- Test: `test/models/attendance_workspace_models_test.dart`

**Interfaces:**
- Produces: typed attendance page/filter/summary/trend/at-risk values used by repository and UI tasks.
- Produces: `AttendanceAnalyticsCalculator.calculatePresenceMetrics({required int present, required int late, required int absent, required int excused}) -> AttendancePresenceMetrics`, a pure function with no database or widget dependency.
- Produces: `AttendanceAnalyticsCalculator.isAtRisk({required int absentCount}) -> bool`, returning true for at least three explicit absences and false below three.
- `AttendanceWorkspaceRecord` stores nullable record ID, student/offering IDs, date, `AttendanceStatus`, normalized source, remarks, original recorder, real creation time, and last editor.
- `AttendanceHistoryFilter` stores offering ID, inclusive `AttendanceDateRange`, offset, and page size (default 20); `AttendancePage<T>` stores rows, next offset, and `hasMore`.
- `AttendanceStatusCounts` stores the four marked counts and unmarked count; `AttendanceAnalyticsSummary` stores nullable presence rate, absence-plus-excuse total, warning count, four status totals, trend points, and at-risk students.

- [ ] **Step 1: Write failing calculation tests**

  Cover Late counted as present; Excused excluded from the presence denominator but included in absences-plus-excuses; zero denominator returns a null presence rate rather than `NaN`; exactly three explicit absences is at-risk and fewer than three is not; source parsing maps missing legacy source to `manual` and rejects unsupported values.

- [ ] **Step 2: Run the focused tests and confirm they fail for missing behavior**

  Run: `flutter test test/features/teacher/attendance/attendance_analytics_calculator_test.dart test/models/attendance_workspace_models_test.dart`

- [ ] **Step 3: Define typed filter, page, KPI, trend, and warning models**

  Define the typed data contracts with the exact fields above. Do not encode display labels as source values; do not substitute a fabricated timestamp when creation time is unavailable.

- [ ] **Step 4: Implement the pure calculator and model serialization/parsing**

  Keep the pure presence calculation matching the approved spec and handle empty/legacy data explicitly. The SQL aggregate (Task 3), not a client-side raw-history scan, calculates at-risk counts and trend buckets.

- [ ] **Step 5: Re-run focused tests**

  Run: `flutter test test/features/teacher/attendance/attendance_analytics_calculator_test.dart test/models/attendance_workspace_models_test.dart`

### Task 3: Add safe persistence and audit migration

**Files:**
- Create: `supabase/migrations/<next_timestamp>_attendance_workspace.sql`
- Test/verify: repository's existing Supabase migration validation workflow, if present

**Interfaces:**
- Produces: `attendance_records.source`, correction audit storage, indexes for stable offering/date and student/date paging, an atomic correction operation, bounded teacher analytics aggregation, and a student self-history summary operation called through the attendance Edge Function.
- Produces: `attendance_workspace_student_summary(p_student_id text) -> jsonb`, restricted to `service_role`, validating `users.role = 'student'` and returning `present_count`, `total_days`, and the existing `present_count / total_days` rate (0 when there are no records).
- Produces: the ascending-index equivalent of `(student_id, attendance_date DESC, id DESC)` for stable student history pages.

- [ ] **Step 1: Define migration assertions against confirmed production schema**

  The migration must be additive and idempotent where the project's migration convention permits.   Add `source` with existing rows defaulted to `manual`; preserve `recorded_by`. Add `modified_by` only for latest-change metadata if needed, and create append-only `attendance_record_edits` rows with record ID, old/new status, required reason, editor, and timestamp. Add an equivalent student/date index only when one is not already present.

- [ ] **Step 2: Add failing SQL-level checks or repository-supported migration checks**

  Verify legacy rows remain readable, source defaults to `manual`, uniqueness remains intact, invalid source values are rejected, and the new indexes support `(subject_offering_id, attendance_date, id)` ordering.

- [ ] **Step 3: Implement atomic, authorized correction and bounded analytics operations**

  Correction must update the attendance row and append the edit record in one transaction. The Edge Function must verify the Firebase teacher/offering before calling it. Teacher aggregation must accept offering/date bounds and return status totals, trend buckets, and students with at least three explicit absences without returning all raw records. Student summary must verify the student UID/role and return the existing Present/Total Days/Rate totals without returning raw attendance rows.

- [ ] **Step 4: Review migration SQL and authorization predicates**

  Confirm no existing migration is edited and no destructive table recreation occurs. Keep direct client attendance access blocked; the function uses a service-role client only after its Firebase/teacher checks. Do not apply the migration to a shared/production database as part of local code implementation.

### Task 4: Implement repository reads, batch writes, and history pagination

**Files:**
- Modify: `lib/data/repositories/attendance_repository.dart`
- Modify: `lib/data/repositories/supabase_attendance_repository.dart`
- Create: `supabase/functions/teacher-attendance/index.ts`
- Modify: `lib/models/attendance_workspace_models.dart`
- Modify: `lib/features/student/sub_features/schedule/screens/student_attendance_screen.dart`
- Test: `test/data/repositories/supabase_attendance_repository_test.dart`
- Test: `test/features/student/student_attendance_screen_test.dart`

**Interfaces:**
- Consumes: typed attendance workspace models from Task 2 and confirmed database operations from Tasks 1 and 3.
- Produces: repository methods that invoke an authenticated Edge Function for teacher offering/date roster reads, idempotent batch upsert, filtered server-paginated activity logs, bounded analytics results, audited correction, and self-only student summary/history.
- Produces: `getMyAttendanceSummary() -> AttendanceStudentSummary` and `getMyAttendancePage({required int offset}) -> AttendancePage<AttendanceRecord>`; student identity is derived in the Edge Function, not passed from the client.

- [ ] **Step 1: Write repository tests for query contracts**

  Cover offering/date filtering, status/source mapping, stable 20-row paging, next-page behavior, date range validation, batch upsert conflict keys, propagation of function/read/write errors, rejection for non-teacher/foreign offerings, self-only student access, student summary independent from current page, and correction rejection when the reason is blank.

- [ ] **Step 2: Run focused repository tests and confirm expected failures**

  Run: `flutter test test/data/repositories/supabase_attendance_repository_test.dart`

- [ ] **Step 3: Extend the repository interface with typed operations**

  Use explicit offering IDs, date/range values, page cursor/offset, and typed return models. Remove empty-list and success-shaped stub implementations for attendance methods.

- [ ] **Step 4: Implement authenticated function operations and RPC mapping**

  Invoke the function with the existing Firebase ID token and API key headers. Inside the function, verify caller identity/role/ownership before service-role queries; apply filters before `.range(from, to)` and use stable ordering. Student history must derive the student UID from the verified user and apply `.range(from, to)` with no client-supplied student ID. Keep all service-role credentials server-side and propagate function errors to the UI.

- [ ] **Step 5: Preserve the existing student attendance log on secure paging**

  Replace the `A01` placeholder with the signed-in student's repository calls. Fetch the independent server aggregate for the existing Present/Total Days/Rate header, load 20 log rows per page, and provide a clear Load more action without changing the rest of the layout.

- [ ] **Step 6: Re-run repository and student screen tests**

  Run: `flutter test test/data/repositories/supabase_attendance_repository_test.dart test/features/student/student_attendance_screen_test.dart`

### Task 5: Build the paginated Take Attendance view

**Files:**
- Modify: `lib/features/teacher/sub_features/attendance/widgets/teacher_attendance_tab.dart`
- Create: `lib/features/teacher/sub_features/attendance/widgets/attendance_roster_list.dart`
- Test: `test/features/teacher/attendance/attendance_roster_list_test.dart`
- Test: `test/features/teacher/attendance/teacher_attendance_tab_test.dart`

**Interfaces:**
- Consumes: real teacher offering/roster data and attendance repository operations from Task 4.
- Produces: Take Attendance view with 30-student combined pages, status counts, dirty-state handling, and batch save.

- [ ] **Step 1: Write failing roster and workspace widget tests**

  Assert surname-first display with middle initial (e.g. `Dela Cruz, Juan H.`), case-insensitive name ordering within groups, Male group before Female, unspecified gender remains visible, page 1 contains 30 combined roster students, page 2 continues across gender boundaries without resetting its count, and load failures remain distinguishable from an empty roster.

- [ ] **Step 2: Run the focused widget tests and confirm they fail**

  Run: `flutter test test/features/teacher/attendance/attendance_roster_list_test.dart test/features/teacher/attendance/teacher_attendance_tab_test.dart test/data/repositories/supabase_attendance_repository_test.dart test/features/student/student_attendance_screen_test.dart`

- [ ] **Step 3: Implement one-time roster loading and local 30-row paging**

  Fetch the selected offering roster once, keep per-student status state keyed by student ID, and append/reveal the next combined page locally. Do not issue a roster query when only search, gender display, or page visibility changes.

- [ ] **Step 4: Implement date/subject selectors and status controls**

  Load saved statuses for the chosen offering/date; default missing rows to unmarked; update four live status counts and unmarked count across the entire roster, not only currently shown/search-matched students.

- [ ] **Step 5: Implement source state, dirty protection, and reliable batch save**

  Manual is enabled; show disabled **RFID Hardware Not Connected** state. Prompt before discarding dirty marks on date/offering changes. Save explicit marks in one batch and show success only after repository success; show retryable errors otherwise.

- [ ] **Step 6: Re-run focused widget tests**

  Run: `flutter test test/features/teacher/attendance/attendance_roster_list_test.dart test/features/teacher/attendance/teacher_attendance_tab_test.dart`

### Task 6: Add History & Analytics view

**Files:**
- Modify: `lib/features/teacher/sub_features/attendance/widgets/teacher_attendance_tab.dart`
- Create: `lib/features/teacher/sub_features/attendance/widgets/attendance_history_analytics_view.dart`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Test: `test/features/teacher/attendance/attendance_history_analytics_view_test.dart`

**Interfaces:**
- Consumes: repository history pages, bounded analytics aggregates, and calculator/models from Tasks 2 and 4.
- Produces: week/month/custom date filters, three KPI cards, trend chart, presence breakdown, at-risk list, and paged detailed activity log.

- [ ] **Step 1: Add failing history widget tests**

  Cover date presets, custom range validation, empty/loading/error states, KPI rendering, 20-row page continuation, source and persisted time display, the three-absence warning, responsive layouts, accessible labels, and chart summaries.

- [ ] **Step 2: Run focused widget tests and confirm they fail**

  Run: `flutter test test/features/teacher/attendance/attendance_history_analytics_view_test.dart`

- [ ] **Step 3: Add `fl_chart` using the project's Flutter package workflow**

  Update only the dependency and lockfile entries required for the approved chart library.

- [ ] **Step 4: Implement bounded filters, KPI cards, and charts**

  Request aggregates for selected offering/date bounds; group trends by day for ranges up to 31 days, week up to 180 days, and month for longer ranges. Show both chart visualizations with labels and textual summaries, and show no-data states without fabricated values.

- [ ] **Step 5: Implement server-paginated activity log and at-risk tracker**

  Fetch log rows in 20-row pages with offering/date filters applied server-side. Load more using the next page cursor/offset; render actual date/status/source and recorded time only where a persisted timestamp exists.

- [ ] **Step 6: Re-run focused history tests**

  Run: `flutter test test/features/teacher/attendance/attendance_history_analytics_view_test.dart`

### Task 7: Implement audited manual corrections

**Files:**
- Modify: `lib/features/teacher/sub_features/attendance/widgets/attendance_history_analytics_view.dart`
- Modify: `lib/data/repositories/attendance_repository.dart`
- Modify: `lib/data/repositories/supabase_attendance_repository.dart`
- Test: `test/features/teacher/attendance/attendance_correction_test.dart`
- Test: `test/data/repositories/supabase_attendance_repository_test.dart`

**Interfaces:**
- Consumes: authorized atomic correction operation from Task 3 and typed activity records from Task 4.
- Produces: date-specific correction flow that requires a reason and preserves original source/recorder.

- [ ] **Step 1: Write failing correction tests**

  Assert blank reasons cannot submit, confirmation shows the existing status, successful corrections append audit metadata, source and original recorder remain unchanged, and database errors are shown without success feedback.

- [ ] **Step 2: Run focused correction tests and confirm expected failures**

  Run: `flutter test test/features/teacher/attendance/attendance_correction_test.dart test/data/repositories/supabase_attendance_repository_test.dart`

- [ ] **Step 3: Implement correction dialog and repository call**

  Require a trimmed non-empty reason; call the atomic database operation; refresh the affected log/summary page only after success.

- [ ] **Step 4: Re-run focused correction tests**

  Run: `flutter test test/features/teacher/attendance/attendance_correction_test.dart test/data/repositories/supabase_attendance_repository_test.dart`

### Task 8: Verify integration and document operational prerequisites

**Files:**
- Modify: `docs/superpowers/specs/attendance-workspace.md` only if implementation details reveal a necessary approved clarification
- Test: attendance-related tests and Flutter analyzer

**Interfaces:**
- Consumes: all completed attendance workspace views, repository methods, and migration.
- Produces: verified integration with accurate remaining setup requirements.

- [ ] **Step 1: Run all attendance-focused tests**

  Run: `flutter test test/features/teacher/attendance test/data/repositories/supabase_attendance_repository_test.dart`

- [ ] **Step 2: Run Flutter analyzer**

  Run: `flutter analyze`

- [ ] **Step 3: Review the full attendance diff**

  Verify the teacher portal still routes to the workspace; no mock data, fake RFID behavior, unbounded history reads, silent repository fallbacks, inaccessible/color-only controls, unrelated assessment changes, or destructive schema edits were introduced. Check small phone, tablet, and light/dark themes.

- [ ] **Step 4: Report deployment/setup prerequisites**

  State that the additive migration must be applied to the confirmed database, teachers need active offerings/enrollments (and schedule data if later adopted), and RFID remains unavailable until physical hardware, card mapping, and an authenticated event protocol exist. The existing student log now uses its own authenticated, self-only paginated API.
