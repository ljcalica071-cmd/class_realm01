# ClassRealm — Student Side Implementation Plan (Frontend Prototype Only)

**Scope:** Flutter frontend prototype (no backend, no API, no real auth). All data lives in
`lib/data/mock_database.dart` (`MockDatabase.instance`). Do NOT add HTTP calls, Firebase,
or any backend integration in this pass — everything must keep working purely off the mock
in-memory data, the same way the Teacher side already does.

**Why this document exists:** The Student side currently *looks* mostly done, but several
core features are either disconnected, faked with hardcoded strings, or missing entirely,
even though the underlying data models and Teacher-side code already support them. This
plan lists every gap, in priority order, with the exact files to touch and a definition of
done for each item.

**Ground rules for whoever implements this:**
1. Follow the existing code style/widgets already used in this project: `AppColors`,
   `AppPrimaryButton` / `AppSecondaryButton` (`widgets/common/app_buttons.dart`),
   `AppModals` (`widgets/common/app_modals.dart`), `StatusBadge`
   (`widgets/common/status_badge.dart`), `SyncStatusBadge`. Do not invent a new design
   system — reuse what Teacher/Parent screens already use.
2. Student UI stays **mobile-first**: bottom navigation for primary tabs (Home, Activities,
   Quiz/Exam, Notifications, Profile), side drawer for secondary features (Attendance,
   Schedule, Learning Materials, Grades, Requirements, Settings, Logout). Do not turn the
   Student side into a desktop sidebar layout like Teacher's.
3. Every new screen must read from `MockDatabase.instance` — add helper getters/methods to
   `MockDatabase` where needed (listed per item below) instead of filtering lists inline in
   the widget. Keep the single-source-of-truth pattern already used elsewhere.
4. Do not remove or break any Teacher, Parent, or Admin functionality while doing this.
   See "Cross-side safety rules" below — this is not just a reminder, there are specific
   steps to follow.
5. After each phase, run `flutter analyze` and fix warnings/errors before moving to the
   next phase. Do not batch all phases into one giant uncompilable diff.
6. Work phase by phase, in order. Do not skip ahead to Phase 4 while Phase 1 is unfinished.
7. **`lib/CLASSREALM_SSTruth_Mock_Data.txt` is the canonical mock-data specification for
   this whole project.** Every mock record you add or touch in Phase 0 (and anywhere else)
   must match it exactly — same 10 students, same 2 sections, same teacher (Karen P.
   Gonzaga / T001), same 7 assessments, same attendance dates/statuses, same scores. Do not
   invent new students, sections, or assessments. If that file and the current code
   conflict, the `.txt` file wins — fix the code, not the doc.

---

## Cross-side safety rules (read before touching any shared file)

Most of this plan only touches files under `lib/features/student/`, which no other role's
code imports or reads — those are safe by construction. But three phases touch **shared**
files that Teacher/Parent/Admin also depend on:

| Shared file | Touched by | Also read by |
|---|---|---|
| `lib/data/mock_database.dart` | Phase 0.1, 0.2, 2.1, 3.1, 4.1 (adding fields/data/helpers) | Teacher, Parent, Admin dashboards |
| `lib/models/academic_models.dart` | Phase 0.1 (`LearningMaterialModel`), Phase 1.6 (`AssessmentResultModel`) | Teacher, Parent screens |
| `lib/features/teacher/screens/teacher_dashboard_screen.dart` | Phase 1.7 only | Teacher only (but this file alone is 7,000+ lines — easy to break something unrelated by accident) |

Rules when touching these:

1. **Only ADD, never remove or rename**, existing fields, methods, or list contents in
   `mock_database.dart` and `academic_models.dart`. If a new field is needed on an existing
   model (`LearningMaterialModel.section`, `AssessmentResultModel.violationLog`), give it a
   sensible default (e.g. `this.section = 'Section A'` or `this.violationLog = const []`)
   so every *existing* place that constructs that model — even ones you're not touching —
   keeps compiling without being edited. Before adding the field, grep the whole `lib/`
   folder for every place that constructs the model (e.g. `grep -rn "LearningMaterialModel("
   lib/`) and confirm you've accounted for all of them.
2. **Never change the meaning of an existing filter.** E.g. don't change what
   `MockDatabase.instance.activities` returns in a way that shifts what Teacher's
   `_buildActivitiesTab` shows — add new getters/helpers (`activitiesOnly`, `requirements`,
   `submissionFor(...)`, etc.) alongside the existing ones instead of repurposing them.
3. **Phase 1.7 (Teacher "Assessment Monitoring" tab) must be additive.** Add a new tab/method
   to `teacher_dashboard_screen.dart`; do not edit the body of any existing
   `_build...Tab()` method while doing this.
4. **After finishing any phase that touched a shared file** (Phase 0, Phase 1.6/1.7, Phase
   2.1, Phase 3.1, Phase 4.1), manually run the app and click through, at minimum: Teacher
   login → Dashboard → Attendance tab, Activities tab, Quizzes tab, Learning Materials tab,
   Schedule tab, Gradebook tab; and Parent login → Parent home. Confirm they still show the
   same data as before your change, with nothing missing or duplicated. Note in your commit
   message / summary which tabs you manually re-checked.
5. If a change genuinely requires editing existing logic in a shared file (not just adding),
   stop and call it out explicitly instead of doing it silently — e.g. "Phase 0.3 found that
   attendance record X doesn't match the SSOT file and I corrected it" should be a visible,
   deliberate note, not a silent diff buried in a larger change.

---

## PHASE 0 — Mock Data Consistency (do this FIRST, before Phase 1)

**Problem:** The Student-side screens planned below (Attendance, Schedule, Learning
Materials, Grades in Phases 2–5) are supposed to show data that's *consistent with what the
Teacher already sees* — same records, same source, per
`lib/CLASSREALM_SSTruth_Mock_Data.txt`. Right now:
- `MockDatabase.schedules` is **completely empty** (`schedules = [];`) — there is no
  schedule mock data at all yet, for any role.
- `LearningMaterialModel` has **no `section` field**, so the 3 existing materials records
  can't actually be scoped to Section A vs Section B — they're effectively global with no
  way to filter "materials for my section."
- Attendance and assessment/grade mock data already exist and already match the SSOT
  file — do **not** regenerate these, only reuse them via the helper methods in Phases 2–5.

This phase must be done first because Phases 2, 4, and 5 all assume real, section-scoped
data exists to read from. Skipping this phase means those later screens will just show empty
lists.

### 0.1 Add `section` to `LearningMaterialModel`
In `lib/models/academic_models.dart`, add a `final String section;` field (values: `'A'`/
`'B'` or `'Section A'`/`'Section B'` — match whatever format `ActivityModel.section` already
uses elsewhere in the codebase, for consistency) to `LearningMaterialModel`, with a
constructor param. Update the 3 existing seed records in `mock_database.dart` to each
declare a section (split them across Section A and Section B — do not leave any as
"global"/sectionless, and do not invent new material records beyond these 3 unless the SSOT
file is updated first).

### 0.2 Populate `MockDatabase.schedules` for Section A and Section B
Using `ScheduleModel` (`subject`, `section`, `room`, `dayOfWeek`, `startTime`, `endTime`),
add a realistic weekly recurring schedule for **General Mathematics, taught by Karen P.
Gonzaga (T001), for Section A and Section B only** — matching the SSOT file's "Teacher
handles only Grade 11 General Mathematics, only Section A and Section B" rule. Two or three
class meetings per week per section is enough (e.g. Mon/Wed for Section A, Tue/Thu for
Section B, same room or different — your call, just keep it internally consistent). Do not
add other subjects or other teachers.

### 0.3 Cross-check attendance & grades against the SSOT file (no changes expected, verify only)
Confirm `MockDatabase`'s existing attendance records and assessment scores already match
`CLASSREALM_SSTruth_Mock_Data.txt` exactly (10 students, same IDs, same 5 dates
09-14-2026 → 09-18-2026, same "1 Late + 1 Absent per section" rule, same 7 assessment
records and scores). If any existing record disagrees with the `.txt` file, fix the record
to match the file — do not edit the `.txt` file to match the code.

### 0.4 Wire student screens to the shared data, not new copies
When building the Attendance, Schedule, Learning Materials, and Grades screens in Phases
2–5, every student-side query (`attendanceForStudent`, `scheduleForSection`,
`materialsForSection`, grade lookups) must read from these same centralized
`MockDatabase` lists — the exact same objects the Teacher dashboard reads from. Do not
create a second parallel data source for the Student side. This is what makes Student data
automatically "connected" to Teacher data: they're the same records, just filtered
differently per viewer.

**Done when:** `flutter analyze` passes, `schedules` is non-empty and scoped to Section
A/Section B under Karen Gonzaga only, every `LearningMaterialModel` has a section, and a
manual check confirms Teacher-side and (once Phases 2–5 are built) Student-side show
identical underlying attendance/grade/schedule/materials records for the same student —
just different views of the same data.

---

## PHASE 1 — Critical: Quiz/Exam flow is currently fake (do this first)

### 1.1 Wire up the real assessment screen
**Problem:** `lib/features/student/screens/student_assessment_screen.dart` is a fully built
screen (rules acknowledgment → answering → auto-checked result) but it is never navigated
to. The "Start Quiz/Exam" button in `student_home_screen.dart`
(`_buildQuizExamTab`) just shows a fake `AppModals.showSuccessDialog`.

**Fix:**
- In `student_home_screen.dart` → `_buildQuizExamTab`, replace the fake dialog call with
  `StudentAssessmentScreen.start(context, q)`.
- After returning from the assessment screen, refresh the quiz/exam tab (`setState`) so the
  list reflects the new submission state (see 1.4).

**Done when:** Tapping "Start Quiz/Exam" on any published quiz/exam actually opens the
rules screen, then the real question-answering flow, then a result screen — not a dialog.

### 1.2 Fix the "Offline Safe" contradiction
**Problem:** The button label says `"Start Quiz (Offline Safe)"` and the dialog text says
*"Answers will be saved locally in real time even if offline."* This directly contradicts
the product spec (`lib/system_plan.txt`, "QUIZ MUST REQUIRE INTERNET" / "EXAM MUST REQUIRE
INTERNET" sections), which explicitly forbids offline quiz/exam taking.

**Fix:**
- Remove "(Offline Safe)" from the button label.
- Add a simple simulated connectivity flag (e.g. a `bool _isOnline` in
  `MockDatabase`, default `true`, toggleable via a debug/demo switch — see 1.5).
- Before entering the assessment and while inside it, check this flag. If offline:
  block entry / show a blocking banner: *"Internet connection lost. Quiz access is
  temporarily unavailable."* (for quizzes) or *"Internet connection lost. Your examination
  session requires an active internet connection."* (for exams), per the spec text.
- Do NOT implement any "saved locally while offline" messaging or behavior for quizzes/exams.
  (Note: this offline-safe behavior IS correct and should stay for the Activities/Requirements
  submission flow — the spec only forbids it for Quiz/Exam.)

**Done when:** No quiz/exam UI text claims offline capability, and simulating "offline"
blocks quiz/exam entry with the warning text above.

### 1.3 Implement real anti-cheating detection in `student_assessment_screen.dart`
**Problem:** `_violations` is declared but never incremented anywhere. There is no timer
countdown, no focus/lifecycle detection, no way to trigger a violation at all.

**Fix — build this inside `_StudentAssessmentScreenState`:**
- Add `with WidgetsBindingObserver` and override `didChangeAppLifecycleState`. When the
  state changes to `paused`/`inactive` while `_currentStep == 1` (answering), count it as a
  violation event ("Tab/window focus lost" / "Returned to assessment" on resume).
- Add a real countdown `Timer.periodic` based on `widget.assessment.durationMinutes` that
  ticks the displayed "`XX:XX remaining`" text down every second. When it hits zero,
  auto-submit (call `_submitAssessment()`).
- Detect copy/paste/cut where technically feasible (e.g. wrap the question text in a
  `SelectableText` with a listener, or intercept via `Focus`/`RawKeyboard` for Ctrl+C/V/X);
  where Flutter genuinely cannot detect it in this prototype, add a labeled **demo-only
  button** ("Simulate: Copy attempt detected") so the flow can be demonstrated — but label
  it clearly as a demo control, not real detection, per `system_plan.txt`'s "IMPORTANT
  ANTI-CHEATING LIMITATION" section.
- Every detected/simulated event should:
  1. Increment `_violations`.
  2. Append a `{time, eventLabel}` entry to a local `List<Map<String,dynamic>> _violationLog`
     (new field on the state).
  3. Show a warning modal/banner: `"Warning: <event>."` + `"Violation X of 3"`.
  4. Apply the configurable policy from `system_plan.txt`: violation 1 = warning, violation
     2 = final warning, violation 3 = auto-submit and lock (call `_submitAssessment()` and
     disable further input).
- On submit, persist `_violations` **and** `_violationLog` into `AssessmentResultModel`
  (already has a `violationCount` field — add a new `violationLog` field, see 1.6, so
  Teacher-side monitoring in Phase 1.7 has something to show).

**Done when:** Switching apps/losing focus during a quiz/exam visibly increments the
violation counter, shows a warning, and 3 violations auto-submits the assessment. The timer
counts down for real.

### 1.4 Reflect assessment results back on the Student Home "Quiz/Exam" tab
**Problem:** Once a student submits a quiz/exam, `_buildQuizExamTab` still shows the same
"Start Quiz/Exam" button with no memory that it was already taken.

**Fix:**
- Add `MockDatabase.instance.resultFor(String assessmentId, String studentId)` → returns the
  matching `AssessmentResultModel?` from `assessmentResults`.
- In `_buildQuizExamTab`, for each quiz/exam, look up the current student's result:
  - No result yet → show "Start Quiz/Exam" as today.
  - Result exists, `isReleased == false` → show a `StatusBadge` "Submitted — awaiting
    release" (no score).
  - Result exists, `isReleased == true` → show score (`scoreEarned / totalPoints`) and a
    "View Result" button that reopens the result view (step 2 of the assessment screen) in
    read-only mode.

**Done when:** A student cannot "start" the same quiz/exam twice, and can see their score
once released, all without leaving the Home/Quiz tab.

### 1.5 Add a demo connectivity toggle
Add a small debug affordance (e.g. a toggle in the Student Profile tab, or reuse/extend
`SyncStatusBadge`) that flips the simulated online/offline flag from 1.2, so this behavior
can actually be demoed to whoever is reviewing the prototype.

### 1.6 Model changes needed
In `lib/models/academic_models.dart`, extend `AssessmentResultModel` with:
```dart
final List<Map<String, dynamic>> violationLog; // [{ 'time': DateTime, 'event': String }]
```
(with a sensible default `const []` and updated `copyWith`/constructor).

### 1.7 Teacher-side violation monitoring (required so Phase 1 data is actually visible)
**Problem:** `system_plan.txt` requires teachers to see submission monitoring — student
name, start/submit time, duration, status, score, violation count, violation history — but
no such UI exists anywhere in `teacher_dashboard_screen.dart` today.

**Fix:**
- Add a new tab/section to the Teacher dashboard (near `_buildExamCheckerTab` /
  `_buildItemAnalysisTab`) called "Assessment Monitoring".
- List all `AssessmentResultModel` entries for the selected quiz/exam with columns: Student,
  Start time (approximate — submittedAt minus durationTakenMinutes is fine for this
  prototype), Submission time, Duration, Status (`Normal` / `Warning` if 1 violation /
  `Suspicious Activity` if 2 / `Auto Submitted` if 3+), Score, Violation count.
- Tapping a row opens a detail view showing the violation timeline from `violationLog`
  (time + event, in order), matching the example format in `system_plan.txt`.

**Done when:** A teacher can open any submitted quiz/exam and see the violation history the
student generated in Phase 1.3.

---

## PHASE 2 — High priority: Submission status & scores are invisible to students

**Problem:** `StudentSubmission` already has `score`, `status` (`ActivityStatus`), and
`feedback` fields — the Teacher side (`activity_submissions_screen.dart`) already writes to
these when grading. But `student_home_screen.dart` (`_buildHomeTab` and
`_buildActivitiesTab`) never reads them. The "Upload & Submit" button always shows,
regardless of whether the student already submitted, was graded, or submitted late.

### 2.1 Add MockDatabase helpers
```dart
StudentSubmission? submissionFor(String activityId, String studentId);
List<StudentSubmission> submissionsForStudent(String studentId);
```

### 2.2 Update `_buildHomeTab` and `_buildActivitiesTab` in `student_home_screen.dart`
For each activity, look up the current student's submission and branch the card UI:
- No submission, before deadline → current "Upload & Submit" button.
- No submission, past deadline → `StatusBadge` "Missing" (red) instead of the button, or a
  "Submit Late" button if late submission should still be allowed (match whatever
  `ActivityStatus.lateSubmission` implies elsewhere in the app).
- Submitted, `status == ActivityStatus.submitted` → `StatusBadge` "Submitted — awaiting
  check" + disable/hide the submit button (or turn it into "Resubmit" only if that's
  intentionally allowed).
- Submitted, `status == ActivityStatus.graded` or `.returned` → show the score
  (`"${submission.score}/${activity.maxScore}"`) and, if `submission.feedback` is non-null,
  show the teacher's feedback text.

**Done when:** A student can tell, at a glance, which activities are pending, submitted, or
graded — and see their score/feedback for graded ones — without any teacher-side changes.

---

## PHASE 3 — High priority: Requirements need their own space

**Problem:** `ActivityModel.isRequirement` already exists and the mock data already creates
requirement-type entries, but the Student side has no dedicated Requirements view — they're
silently mixed into the general Activities list, and per `system_plan.txt` (REQUIREMENTS
section) students should be able to view assigned requirements and status specifically.

### 3.1 Add MockDatabase helpers
```dart
List<ActivityModel> get requirements => activities.where((a) => a.isRequirement).toList();
List<ActivityModel> get activitiesOnly => activities.where((a) => !a.isRequirement).toList();
```

### 3.2 New screen: `lib/features/student/screens/student_requirements_screen.dart`
Reuse the same card layout/status logic built in Phase 2 (submission status, score,
feedback), scoped to `requirements` instead of all activities.

### 3.3 Wire it up
- Add a "Requirements" `ListTile` to the Student drawer in `student_home_screen.dart`
  (`_buildStudentDrawer`), navigating to the new screen.
- Update the "Activities" tab/list to use `activitiesOnly` instead of the full `activities`
  list, so requirements aren't duplicated in two places.

**Done when:** Requirements and Activities are clearly separated, each with their own
submission-status UI from Phase 2.

---

## PHASE 4 — Medium priority: Replace fake static drawer dialogs with real screens

**Problem:** The Attendance, Schedule, and Learning Materials drawer items currently just
call `AppModals.showSuccessDialog` with hardcoded strings (e.g. *"100% attendance rate"*,
*"Mon/Wed 07:30 AM (Room 304)"*, *"3 downloadable PDF modules"*) instead of showing real
data — even though `AttendanceRecord`, `ScheduleModel`, and `LearningMaterialModel` already
exist and are populated in `MockDatabase` for the Teacher side.

### 4.1 Add MockDatabase helpers
```dart
List<AttendanceRecord> attendanceForStudent(String studentId);
List<ScheduleModel> scheduleForSection(String section);
List<LearningMaterialModel> materialsForSection(String section); // or however materials are scoped today — check existing field, adjust filter accordingly
```

### 4.2 New screen: `student_attendance_screen.dart`
List view of the student's own `AttendanceRecord`s (date, time in, status badge, method —
RFID vs Manual), newest first. Show a simple summary header (e.g. "X present / Y total days
this quarter").

### 4.3 New screen: `student_schedule_screen.dart`
Weekly view (group `ScheduleModel` entries by `dayOfWeek`) showing subject, room, start/end
time for the student's section. A simple list grouped under day headers is enough — no need
to build a full calendar widget.

### 4.4 New screen: `student_learning_materials_screen.dart`
List of `LearningMaterialModel` for the student's section/subjects, showing title, category
icon (PDF/Document/Presentation/Image/Link), file size, uploaded date. Tapping an item can
open a simple detail/mock-download dialog (reuse `AppModals`) — real file download is out of
scope for this frontend-only prototype.

### 4.5 Wire up the drawer
Replace the three `AppModals.showSuccessDialog(...)` calls in `_buildStudentDrawer` with
`Navigator.push` to the three new screens.

**Done when:** Attendance, Schedule, and Learning Materials each open a real screen backed
by `MockDatabase` data instead of a static dialog.

---

## PHASE 5 — Medium priority: Real Grades screen

**Problem:** The only grade visibility today is one hardcoded quarterly number shown in a
dialog (`quarterlyGradeFor`). There's no per-subject or per-activity breakdown, even though
graded `StudentSubmission`s and `AssessmentResultModel`s already carry real scores once
Phase 2 is done.

### 5.1 New screen: `student_grades_screen.dart`
- Group by subject (use `activity.subject` / `assessment.subject`).
- Per subject, list graded activities/requirements/quizzes/exams with their scores.
- Show the existing `quarterlyGradeFor(studentId)` as a summary at the top (keep it — it's
  fine as a computed overall number), but back it with the real per-item breakdown below it.

### 5.2 Wire up
Replace the "Published Grades" drawer dialog with navigation to this screen.

**Done when:** A student can see not just one overall number, but which subject/item scores
make it up.

---

## PHASE 6 — Lower priority: Polish

### 6.1 Settings screen
`system_plan.txt` lists "Settings" as a drawer item; it's currently missing entirely. Add a
minimal `student_settings_screen.dart` (e.g. notification preferences toggle, theme
placeholder, "Change Password" that reuses whatever the Auth side already has for password
change — check `first_login_screen.dart` for a reusable password field pattern). Keep this
simple; it's not core to the academic workflow.

### 6.2 Notification tap-through
Notifications in `_buildNotificationsTab` are static and don't navigate anywhere. Where
`AppNotificationModel.type` matches a known category (`'activity'`, `'grade'`,
`'attendance'`), tapping the notification should navigate to the relevant screen from the
phases above. Not blocking, but cheap to add once those screens exist.

### 6.3 De-duplicate Home vs Activities tab
`_buildHomeTab`'s "Pending Activities & Tasks" section and `_buildActivitiesTab` currently
duplicate almost identical card-building code. Once Phase 2/3 status logic exists, factor it
into one shared private widget/method to avoid maintaining two copies of the same logic.

---

## Suggested order of work (summary)

0. Phase 0 — mock data consistency (schedule data + learning-materials section field),
   grounded in `lib/CLASSREALM_SSTruth_Mock_Data.txt`. Do this before anything else, or
   later phases will have nothing real to display.
1. Phase 1 (1.1 → 1.7) — quiz/exam is the most visible and most "broken-looking" gap.
2. Phase 2 — submission status/score visibility (affects Home + Activities + the new
   Requirements screen from Phase 3, so do this before Phase 3).
3. Phase 3 — Requirements screen.
4. Phase 4 — Attendance / Schedule / Learning Materials real screens.
5. Phase 5 — Grades screen.
6. Phase 6 — Settings + polish, whenever time allows.

## Out of scope for this pass (explicitly do not attempt)
- Any real backend/API/auth integration.
- Real file upload/download (mock it the same way the existing code already mocks it).
- Push notifications.
- Offline data sync for anything other than what's already simulated via `SyncStatusBadge`.
