# Teacher Performance Analytics & Grades Computation Specification

**Status:** Draft for review  
**Scope:** Teacher Portal (`TeacherGradesTab` at tab index 9, replacing the static "Grades" tab with a unified **Performance Analytics & Grades Computation** workspace directly linked to the Gradebook).  
**Implementation gate:** Do not implement until this spec and a subsequent implementation plan are approved.

---

## 1. Goal

Replace the disconnected **Grades** tab (`TeacherGradesTab`) in the Teacher Portal with a unified **Performance Analytics** workspace that combines:
1. **Visual Performance Analytics** — tracking whether class and individual learner performance is rising (`📈 Improving`), steady (`➖ Stable`), or dropping (`📉 Declining`), alongside component mastery (`Written Works` vs `Performance Tasks` vs `Examinations`) and DO 15, s. 2026 descriptor distribution.
2. **Quarterly / Term Grades Computation & Student Ranking Table** — the complete student grades computation and ranking roster, embedded in the same workspace and automatically computed from the teacher's **Gradebook** (`gradebook_term_sheets`) using `DepEdGradingEngine`.

---

## 2. Existing Project Context

- **Teacher Dashboard Navigation (`TeacherDashboardScreen`)**:
  - Tab index `18` under `MY CLASSROOM` is **Gradebook** (`TeacherGradebookTab`), where teachers encode Highest Possible Scores (HPS) and raw learner scores (`WW`, `PT`, `EX`) per active term (`1`, `2`, `3`) and view `FINAL GRADES` (`term == 0`).
  - Tab index `9` under `MONITORING & EVALUATION` is currently labeled **Grades** (`TeacherGradesTab`), which renders a static table with `_quarterlyGradeFor(studentId)` returning `null` and has no connection to `SubjectRepository` or `DepEdGradingEngine`.
- **Gradebook Storage & Sync (`SubjectRepository` & `LocalStorageService`)**:
  - `SubjectRepository.instance.getTeacherSubjects(teacherId, onlyWithEnrolledStudents: true)` returns the teacher's active subject offerings with weights (`ww_weight`, `pt_weight`, `ex_weight`, `st1_weight`, `st2_weight`, `te_weight`) and term metadata (`terms_taught`, `term_block`, `units_per_term`).
  - `SubjectRepository.instance.getGradebookTermSheet(offeringId, term)` returns the persisted `{ 'hps': ..., 'scores': ... }` map for each term (`1`, `2`, `3`) with Drift/LocalStorage cache-first hydration and Supabase persistence.
  - `TeacherGradebookTab.gradebookRefreshNotifier`, `TeacherGradebookTab.classworkSyncNotifier`, and `SubjectRepository.classworkSyncedNotifier` broadcast live updates whenever scores or HPS values change in Gradebook or Classwork.
- **DepEd DO 15, s. 2026 Curriculum & Grading Rules (`DepEdGradingEngine` & `DepEdSubjectCatalog`)**:
  - Subjects can be taught across **1 Term** (`termsTaught == 1`), **2 Terms** (`termsTaught == 2`), or **3 Terms** (`termsTaught == 3`).
  - `DepEdSubjectCatalog.getActiveTermsForBlock(termsTaught, termBlock)` returns the exact list of active term numbers (e.g., `[1, 2, 3]`, `[1, 2]`, `[2, 3]`, or `[3]`).
  - `DepEdGradingEngine` provides canonical calculations for `computeComponentMetrics`, `computeExamMetrics`, `computeInitialGrade`, `transmuteDO15`, `getDescriptor` (`Advancing`, `Benchmarking`, `Connecting`, `Developing`, `Emerging`), `getRemarks` (`PASSED`, `FAILED`), and `computeFinalGrade`.

---

## 3. Architecture & Component Structure

### 3.1 Pure Analytics & Computation Engine (`GradebookAnalyticsCalculator`)

Create `lib/features/teacher/sub_features/grading/utils/gradebook_analytics_calculator.dart` as a pure, deterministic calculator (mirroring the pattern of `AttendanceAnalyticsCalculator`) with zero UI dependencies so it can be unit-tested thoroughly.

#### Input Data
- Subject offering metadata (`id`, `subject_name`, `section_name`, `ww_weight`, `pt_weight`, `ex_weight`, `st1_weight`, `st2_weight`, `te_weight`, `terms_taught`, `term_block`, `units_per_term`).
- Enrolled active learners (`List<UserModel>`).
- Decoded Gradebook term sheets (`Map<int, Map<String, dynamic>>` for active terms `1..3`).
- Selected view mode:
  - Specific active term (`term = 1`, `2`, or `3`)
  - Final & Term Comparison (`term = 0`)
  - Section scope: Single Section (`offeringId`) or Compare All Sections (`allOfferingsForSubject`)

#### Output Models
1. **`GradeTrend` enum**: `improving`, `declining`, `stable`, `insufficientData`.
2. **`AssessmentProgressionPoint`**:
   - `slotKey` (`WW1`, `WW2`, ..., `PT1`, ..., `ST1`, `ST2`, `TE`)
   - `label` (display label)
   - `category` (`ww`, `pt`, `ex`)
   - `hps` (double)
   - `classAveragePercent` (`0..100` percentage score across encoded learners)
   - `encodedCount` (number of learners with a recorded score for this slot)
   - `deltaFromPrevious` (double? difference vs previous active assessment slot)
3. **`TermProgressionPoint`**:
   - `termNumber` (`1`, `2`, `3`, or `0` for Final)
   - `label` (`Term 1`, `Term 2`, `Term 3`, `Final Grade`)
   - `classAverageGrade` (double? average transmuted grade)
   - `passingRate` (double? `0..100`)
   - `encodedCount` (int)
4. **`SectionComparisonPoint`**:
   - `offeringId`, `sectionName`
   - `classAverage` (double?)
   - `passingRate` (double?)
   - `wwPsAvg`, `ptPsAvg`, `exPsAvg` (double?)
   - `perTermAverages` (`Map<int, double?>`)
5. **`StudentGradeAnalyticsRow`**:
   - `student` (`UserModel`), `displayName` (`LASTNAME, Firstname M.`), `lrn`, `sectionName`
   - Per-term metrics for the selected term: `wwMetrics` (`ComponentMetrics`), `ptMetrics` (`ComponentMetrics`), `exMetrics` (`ExamMetrics`), `initialGrade` (`double?`), `transmutedGrade` (`int?`)
   - Multi-term summary: `termGrades` (`Map<int, int?>` for active terms), `finalGrade` (`int?`)
   - Trend metrics:
     - `withinTermDelta` (`double?` percentage-point change between earliest encoded assessment(s) and latest encoded assessment(s) within the selected term)
     - `crossTermDelta` (`int?` transmuted grade point change from earliest encoded active term to latest encoded active term)
     - `effectiveDelta` (`double?` — uses `withinTermDelta` when viewing a single term or 1-term subject; uses `crossTermDelta` when viewing `Final & Term Comparison` on a multi-term subject, with fallback to `withinTermDelta` if only one term has grades encoded so far)
     - `trend` (`GradeTrend`)
   - `descriptor` (`String` via `DepEdGradingEngine.getDescriptor`, or `'Pending'` if ungraded)
   - `remarks` (`String` via `DepEdGradingEngine.getRemarks`, or `'—'` if ungraded)
6. **`GradebookAnalyticsSummary`**:
   - KPI metrics: `classAverage` (`double?`), `passingRate` (`double?`), `passingCount` (`int`), `encodedStudentCount` (`int`), `totalStudentCount` (`int`), `improvingCount` (`int`), `needsAttentionCount` (`int` — learners with `grade < 75` or `trend == GradeTrend.declining`)
   - Component Mastery averages (`wwPsAvg`, `ptPsAvg`, `exPsAvg`)
   - Descriptor counts (`advancingCount`, `benchmarkingCount`, `connectingCount`, `developingCount`, `emergingCount`, `pendingCount`)
   - `withinTermPoints` (`List<AssessmentProgressionPoint>`)
   - `crossTermPoints` (`List<TermProgressionPoint>`)
   - `sectionComparisonPoints` (`List<SectionComparisonPoint>`)
   - `studentRows` (`List<StudentGradeAnalyticsRow>`)

---

## 4. Adaptive Handling of 1-Term, 2-Term, and 3-Term Subjects

To eliminate confusion across subjects with different term durations (`terms_taught` = 1, 2, or 3):

1. **Dynamic Term Selector Bar**:
   - Uses `DepEdSubjectCatalog.getActiveTermsForBlock(termsTaught, termBlock)` to display only the subject's active term tabs plus a `FINAL & TERM COMPARISON` (`term == 0`) tab:
     - **3-Term Subject** (e.g., *General Mathematics*): `[Term 1] [Term 2] [Term 3] [Final & Term Comparison]`
     - **2-Term Subject** (e.g., *Research & Design*): `[Term 1] [Term 2] [Final & Term Comparison]` (if `1ST & 2ND`) or `[Term 2] [Term 3] [Final & Term Comparison]` (if `2ND & 3RD`)
     - **1-Term Subject** (e.g., *Work Immersion* in Term 3): `[Term 3 (Active)] [Final Summary]`
   - Inactive terms are never rendered as empty chart bars or blank table columns.

2. **Dual-Level Trend Calculation ("Tumataas o Bumababa")**:
   - **Within-Term Assessment Trend (Active when viewing `Term 1`, `Term 2`, `Term 3`, OR when the subject is a `1-Term Subject`)**:
     - Evaluates all assessment columns in the selected term that have `HPS > 0` in canonical order (`WW1..WW10`, `PT1..PT10`, `ST1`, `ST2`, `TE`).
     - Plots the class average percentage score `(score / hps) * 100` across each encoded assessment so the teacher sees whether the section's performance is rising or dropping from quiz to quiz and exam to exam.
     - Computes each learner's `withinTermDelta`: when a learner has at least 2 scored assessments in that term, splits their scored assessments chronologically into an earlier half and a later half and computes `laterAvgPercent - earlierAvgPercent`.
       - `>= +2.0%` → `GradeTrend.improving` (`📈`)
       - `<= -2.0%` → `GradeTrend.declining` (`📉`)
       - Between `-2.0%` and `+2.0%` → `GradeTrend.stable` (`➖`)
   - **Cross-Term Progression Trend (Active when viewing `Final & Term Comparison` on a `2-Term` or `3-Term` subject)**:
     - Plots the section's average transmuted grade across each active term (`Term 1 → Term 2 → Term 3 → Final Grade`).
     - Computes each learner's `crossTermDelta = latestEncodedTermGrade - earliestEncodedTermGrade`:
       - `>= +1` transmuted point → `GradeTrend.improving` (`📈 +N pts`)
       - `<= -1` transmuted point → `GradeTrend.declining` (`📉 -N pts`)
       - `0` change → `GradeTrend.stable` (`➖ Stable`)
       - If only 1 active term has encoded grades so far (e.g., Term 1 is still ongoing), automatically falls back to that term's `withinTermDelta` so the teacher still gets meaningful trend indicators before Term 2 begins.

3. **Section-vs-Section Comparison Mode**:
   - When the teacher teaches the selected subject to multiple sections, the Section dropdown includes `"Compare All Sections"`.
   - Selecting `"Compare All Sections"` switches the primary chart to a side-by-side comparison of each section's Class Average, Passing Rate, and Component Mastery (`WW`, `PT`, `EX`), and adds a `SECTION` badge to each row in the student ranking table.

---

## 5. UI/UX Layout (Unified Single-Page Workspace)

### 5.1 Navigation Updates (`TeacherDashboardScreen`)
- In `lib/features/teacher/screens/teacher_dashboard_screen.dart`:
  - Under `MONITORING & EVALUATION`, update nav item `9` from `'Grades'` (`LucideIcons.award`) to `'Performance Analytics'` (`LucideIcons.trendingUp`).
  - Update `_getTeacherTitle(9)` to `'Performance Analytics & Grades'`.
  - Pass an optional `onNavigateToGradebook: () => _onSelectTab(18)` callback into `TeacherGradesTab` so teachers can jump to the Gradebook with one click.

### 5.2 Top Filter & Context Bar
- **Header Row**:
  - Title: `Performance Analytics & Grades Computation`
  - Subtitle showing active subject name, DO 15 component weights (`WW % • PT % • EX %`), and active terms badge.
  - Action button: `Open Gradebook` (navigates to tab `18` if unlocked).
- **Controls Row**:
  - `Subject` dropdown
  - `Section / Scope` dropdown (individual sections + `Compare All Sections` when `> 1` section exists for that subject)
  - `Sort / Filter` dropdown:
    - `Ranking: Highest to Lowest`
    - `Ranking: Lowest to Highest`
    - `Trend: Needs Attention (Declining / <75)`
    - `Trend: Most Improved (Rising)`
    - `Name: A to Z (DepEd Order)`
- **Adaptive Term Tabs Bar**:
  - Interactive pill buttons for each active term (`Term 1`, `Term 2`, `Term 3`) + `Final & Term Comparison`.

### 5.3 KPI Summary Row (4 Cards)
1. **Class Average**: Mean transmuted grade across encoded learners (or `—` if no grades encoded yet), with net trajectory indicator.
2. **Passing Rate (`>= 75`)**: Percentage and count (`X of Y Learners Passed`).
3. **Improving Learners (`📈`)**: Count of learners with positive trend (`GradeTrend.improving`).
4. **Needs Attention (`📉 / <75`)**: Count of learners who are currently failing (`< 75`) or have a declining score trend (`GradeTrend.declining`).

### 5.4 Visual Analytics Row (2 Panels)
- **Left Panel (7/12 width on desktop): Performance Trajectory & Comparison Chart**
  - Renders clean, theme-aware progress/bar/line visualizations:
    - **Within-Term Mode**: Horizontal/vertical progression bars for each encoded assessment (`WW1`, `WW2`, `PT1`, `ST1`, `TE`) with class average `%` and delta badges (`▲ +3%` / `▼ -4%`).
    - **Cross-Term Mode**: Term-by-term comparison bars (`Term 1`, `Term 2`, `Term 3`, `Final Grade Average`).
    - **Section Comparison Mode**: Grouped comparison bars per section (`Section A` vs `Section B`).
  - Includes a bottom insight takeaway banner summarizing the trajectory.
- **Right Panel (5/12 width on desktop): Component Mastery & DO 15 Descriptor Distribution**
  - **Component Mastery**: 3 progress bars showing the class average Percentage Score (`PS%`) in `Written Works (WW)`, `Performance Tasks (PT)`, and `Examinations (EX)` so teachers immediately see which assessment type is pulling grades up or down.
  - **DO 15, s. 2026 Descriptor Breakdown**: Compact count cards for `Advancing (90–100)`, `Benchmarking (80–89)`, `Connecting (75–79)`, `Developing (65–74)`, and `Emerging (60–64)`.

### 5.5 Integrated Grades Computation & Student Ranking Table
- Directly below the analytics panels inside the same scrollable view.
- **Columns in Single-Term View (or 1-Term Subject)**:
  - `RANK` (`#1`, `#2`, ...)
  - `STUDENT NAME` (`LASTNAME, Firstname M.`)
  - `LRN`
  - `WW (WS)` (Weighted Score)
  - `PT (WS)` (Weighted Score)
  - `EX (WS)` (Weighted Score)
  - `INITIAL GRADE`
  - `TERM GRADE` (Transmuted DO 15 grade)
  - `TREND` (`📈 +N%`, `📉 -N%`, `➖ Stable`)
  - `DESCRIPTOR` (`Advancing`, `Benchmarking`, `Connecting`, `Developing`, `Emerging`, or `Pending`)
  - `REMARKS` (`PASSED`, `FAILED`, or `—`)
- **Columns in `Final & Term Comparison` View (2-Term & 3-Term Subjects)**:
  - `RANK`
  - `STUDENT NAME`
  - `LRN`
  - Dynamic `TERM 1`, `TERM 2`, `TERM 3` columns (only for `activeTerms`)
  - `FINAL GRADE` (computed via `DepEdGradingEngine.computeFinalGrade`)
  - `TERM TREND` (`📈 +N pts`, `📉 -N pts`, `➖ Stable`)
  - `DESCRIPTOR`
  - `REMARKS`

---

## 6. Data Flow, Caching, Error Handling & Empty States

- **Zero Mock Data**: All numbers are strictly derived from real teacher subject offerings, real enrolled students (`SupabaseStudentRepository`), and real saved gradebook term sheets (`SubjectRepository.instance.getGradebookTermSheet`).
- **Cache-First & Live Sync**:
  - Hydrates immediately from `SubjectRepository` / `AppDataCache` / `LocalStorageService` when available, then refreshes in the background.
  - Listens to `TeacherGradebookTab.gradebookRefreshNotifier`, `TeacherGradebookTab.classworkSyncNotifier`, and `SubjectRepository.classworkSyncedNotifier` so any grade change in Gradebook or Classwork immediately recomputes the analytics and table.
- **Empty & Partial States**:
  - **No Subject Offerings / No Enrolled Students**: Displays a clean empty state card explaining that subjects and students must be configured in **Classroom Setup** first.
  - **No Scores Encoded Yet in Selected Term**: Renders KPI cards with `—` / `0 Encoded`, displays a clear empty-chart prompt (`"No scores encoded for Term X yet. Encode HPS and learner scores in the Gradebook to generate performance trends."`) with an **Open Gradebook** button, and still lists the enrolled learners in the table with `Pending` descriptors so the roster is always visible.
- **No Database Migration Required**:
  - All required raw and computed data is already persisted in `subject_offerings`, `student_enrollments`, `gradebook_term_sheets`, and `term_grades`.

---

## 7. Verification & Testing Strategy

1. **Unit Tests (`test/features/teacher/gradebook_analytics_calculator_test.dart`)**:
   - Verify **3-Term Subject** computation (`activeTerms = [1, 2, 3]`): within-term progression, cross-term progression (`Term 1 → Term 2 → Term 3 → Final`), and student `crossTermDelta` / `GradeTrend`.
   - Verify **2-Term Subject** computation (`activeTerms = [1, 2]` and `[2, 3]`): inactive terms are excluded from progression points and final grade averages.
   - Verify **1-Term Subject** computation (`activeTerms = [3]`): final grade equals Term 3 transmuted grade, and trend uses `withinTermDelta` across encoded assessments (`WW1..TE`).
   - Verify **Section-vs-Section Comparison**: aggregates multiple offerings of the same subject accurately.
   - Verify **Ranking & Trend Filters**: `Highest to Lowest`, `Lowest to Highest`, `Needs Attention`, and `Most Improved` sort and filter learners deterministically.
2. **Widget Tests (`test/features/teacher/teacher_grades_analytics_tab_test.dart`)**:
   - Verify adaptive term tabs render `[Term 3] [Final Summary]` for a 1-term subject and `[Term 1] [Term 2] [Term 3] [Final & Term Comparison]` for a 3-term subject.
   - Verify switching between Term view and Final view updates both the trajectory chart and the Grades Computation table columns.
   - Verify empty state when no scores are encoded yet.
