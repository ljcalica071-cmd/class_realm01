# SSHS E-Class Record Gradebook & Multi-Term Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` along with `ui-ux-pro-max` and `.agents/rules/supabase_edge_functions.md` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all mathematical inaccuracies, input lag, cell UI styling, score validations, and term-isolation issues in the ClassRealm Gradebook so that it 100% matches the official **DepEd Order No. 015, s. 2026 Strengthened Senior High School (SSHS) Electronic Class Record (`TEMPLATE-SSHS-E-Class-Record-SY-2026-2027.xlsx`)**, including 1-Term, 2-Term, and 3-Term subject offerings and the Final Grades summary sheet.

**Architecture:**
1. **Centralized DO 15, s. 2026 Grading Engine (`lib/core/utils/deped_grading_engine.dart`):** Replace the legacy DO 8, s. 2015 transmutation table and simple exam averaging with the exact Excel formulas (`ROUND` to 2 decimal places at each step, `30% / 30% / 40%` ST1/ST2/TE internal sub-weights, and the 41-tier Adjusted Transmutation Table).
2. **Lag-Free Square Grid Cell Widget (`GradebookGridCell`):** Eliminate `TextEditingController` instantiation inside `build()` and whole-table `setState()` calls on every keystroke. Use a dedicated `StatefulWidget` per cell that owns its `TextEditingController` and `FocusNode`, renders as a pure borderless rectangular cell (no inner oval/pill box), enforces integer inputs `1–100` (for HPS) and `0–HPS` (capped at `100`, max 3 digits) via a custom `TextInputFormatter`, and locks student cells when column HPS is not set.
3. **Term-Scoped State, Multi-Term Block Rules & Final Grades View:** Partition all HPS and student scores by `offeringId` and `termNumber` (`1`, `2`, `3`). Support 1-Term (`1ST`, `2ND`, `3RD`), 2-Term (`1ST & 2ND`, `2ND & 3RD`), and 3-Term (`1ST, 2ND, 3RD`) configurations with the official Excel guard banner (`"INCORRECT SHEET. Do not use this sheet to input data."`) on non-applicable terms, and render a dedicated read-only **FINAL GRADES** summary table when the `FINAL GRADES` tab is selected.

**Tech Stack:** Flutter (Dart), Supabase PostgreSQL (`supabase_flutter`), Firebase Auth (`AuthRepository.instance.currentUser`), Drift SQLite (`AppDatabase`), and `SharedPreferences` (`LocalStorageService`).

**Spec:** `Gradebook_Architecture.md` & `TEMPLATE-SSHS-E-Class-Record-SY-2026-2027.xlsx`

---

## Root Cause Diagnosis (Why Current Code Fails)

1. **Inaccurate Examination (EX), Initial Grade (IG), and Term Grade (TG) Computation:**
    - **Excel Template Benchmark (`Term 3` Sheet):** When `WW1 HPS = 10, Score = 10` (`PS = 100.00, WS = 20.00`), `PT1 HPS = 10, Score = 10` (`PS = 100.00, WS = 50.00`), and `EX: ST1 HPS = 3 (Score = 2), ST2 HPS = 1 (Score = 1), TE HPS = 1 (Score = 1)`:
        - $\text{WS ST1} = \text{ROUND}((2 / 3) \times 30, 2) = 20.00$
        - $\text{WS ST2} = \text{ROUND}((1 / 1) \times 30, 2) = 30.00$
        - $\text{WS TE} = \text{ROUND}((1 / 1) \times 40, 2) = 40.00$
        - $\text{EX PS} = ((20.00 + 30.00 + 40.00) / 100) \times 100 = 90.00$
        - $\text{EX WS} = \text{ROUND}(90.00 \times 0.30, 2) = 27.00$
        - $\text{Initial Grade (IG)} = 20.00 + 50.00 + 27.00 = 97.00$
        - $\text{Term Grade (TG)} = 97$ (via DO 15, s. 2026 range `95.96 – 97.13 -> 97`).
    - **Current Code Bug (`teacher_gradebook_tab.dart`):** Calls `_percentageScore(s.id, 'ex', 3)` which sums raw scores `(2 + 1 + 1) / (3 + 1 + 1) = 4 / 5 = 80.0`, producing `EX WS = 24.0`, `IG = 94.0`, and `TG = 96` (using the outdated DO 8, s. 2015 transmutation table). Furthermore, the `WS ST1`, `WS ST2`, and `WS TE` cells in both the HPS row and student rows are hardcoded to empty strings `''`.
2. **Un-gated Student Cells & Inflated PS/WS Bug:**
    - In `teacher_gradebook_tab.dart`, students can type scores into columns where HPS is `0` or blank (e.g., `WW1 HPS = 40`, `WW2 HPS = blank`, student enters `WW1 = 40, WW2 = 30`, causing `TOTAL = 70 / 40 -> PS = 175%, WS = 35.0%`), or enter 5-digit numbers like `43422` against an HPS of `576`.
3. **Severe Input & Backspace Lag:**
    - `_buildHpsCell` and `_buildScoreCell` instantiate `TextEditingController(text: ...)` directly inside `build()` and invoke `setState()` on every `onChanged` keystroke, rebuilding hundreds of table cells on every character press or backspace.
4. **Shared Scores Across Terms 1, 2, 3 & Missing Final Grades View:**
    - `_scores` and `_hps` maps are not keyed by `_selectedTerm` or `subjectOfferingId`. Switching between `Term 1`, `Term 2`, `Term 3`, and `FINAL GRADES` displays the exact same in-memory numbers.
5. **Missing 1-Term / 2-Term Subject Block Logic:**
    - Electives in DO 15, s. 2026 are often taught for only **1 Term** (taken in Term 1, Term 2, or Term 3) or **2 Terms** (taken in `1ST & 2ND` or `2ND & 3RD`). The system lacks `terms_taught` and `term_block` metadata and does not lock non-applicable term tabs with the official Excel warning.

---

## File Map (Files to Create or Modify)

1. **`lib/core/utils/deped_grading_engine.dart`** *(Modify)*: Implement exact DO 15, s. 2026 math, 2-decimal rounding, ST1/ST2/TE sub-weights, 41-tier transmutation, descriptors, remarks, and multi-term Final Grade computation.
2. **`lib/models/subject_catalog_model.dart`** *(Modify)*: Add `unitsPerTerm`, `unitsPerYear`, `st1Weight`, `st2Weight`, `teWeight`, and `TermBlockConfig` helpers for 1-Term, 2-Term, and 3-Term subjects.
3. **`supabase/migrations/003_gradebook_term_support.sql`** *(Create)*: Non-destructive SQL migration adding `terms_taught`, `term_block`, `units_per_term`, `st1_weight`, `st2_weight`, `te_weight` to `public.subject_offerings`, plus `public.gradebook_term_sheets` for JSONB grid persistence per term (`1, 2, 3`).
4. **`lib/core/services/local_storage_service.dart` & `lib/data/repositories/subject_repository.dart`** *(Modify)*: Persist and load term metadata and per-term gradebook matrices (`hps` and `scores` per `offeringId` + `termNumber`) with offline-first cache + Supabase sync.
5. **`lib/features/teacher/sub_features/setup/widgets/teacher_classroom_setup_tab.dart`** *(Modify)*: Add `No. of Terms Taught` (`1 Term`, `2 Terms`, `3 Terms`) and `Term Block` selector (`FIRST TERM`, `SECOND TERM`, `THIRD TERM`, `1ST & 2ND`, `2ND & 3RD`) to the Add Subject form.
6. **`lib/features/teacher/sub_features/grading/widgets/gradebook_grid_cell.dart`** *(Create)*: Dedicated lag-free, pure-square `StatefulWidget` cell with custom `TextInputFormatter` (digits only, max 3 digits, max `100` for HPS, max `min(100, columnHps)` for student scores, disabled when HPS is unset).
7. **`lib/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart`** *(Modify)*: Integrate `GradebookGridCell`, term-isolated data maps, `DepEdGradingEngine`, inactive term sheet lock banner, and the **FINAL GRADES** summary table view.
8. **`test/core/utils/deped_grading_engine_test.dart`** *(Create)*: Unit tests verifying the exact Excel benchmark numbers and edge cases.

---

## Step-by-Step Implementation Checklist

### Phase 1: Exact DO 15, s. 2026 Grading Engine (`lib/core/utils/deped_grading_engine.dart`)

- [ ] **Step 1.1: Replace `DepEdGradingEngine` with the exact Excel formula pipeline.**
    - Update `lib/core/utils/deped_grading_engine.dart` to include:
        - **`round2(double value)`**: `double.parse(value.toStringAsFixed(2))` to match Excel `ROUND(val, 2)` and prevent floating-point drift.
        - **WW and PT Component Computation (`computeComponentMetrics`)**:
            - Safety Check: Only include column index `i` in a student's raw total if `hps[i] != null && hps[i]! > 0` AND the student has a non-null score in column `i`.
            - If a student has **no encoded scores** (`encodedCount == 0`) in that category, return `null` for `totalRaw`, `ps`, and `ws` (matches Excel `IF(COUNT(D17:M17)=0, "", SUM(D17:M17))`).
            - When scores exist and `totalHps > 0`:
                - `ps = round2((totalRaw / totalHps) * 100.0)`
                - `ws = round2(ps * (componentWeight / 100.0))`
        - **Examinations (EX) Sub-Weight Computation (`computeExamMetrics`)**:
            - Default sub-weights: `st1MaxWeight = 30.0`, `st2MaxWeight = 30.0`, `teMaxWeight = 40.0` (or `0, 0, 100` for TE-only Field Exposure/Apprenticeship subjects).
            - For each exam column (`0 -> ST1`, `1 -> ST2`, `2 -> TE`):
                - If `hps[col] > 0` and student `score[col] != null`:
                    - `wsSub[col] = round2((score[col]! / hps[col]!) * subMaxWeight[col])`
                - Else `wsSub[col] = null`.
            - Let `activeSubWeightSum` be the sum of `subMaxWeight[col]` for all exam columns where `hps[col] > 0` (in the standard Excel sheet, row 14 displays `30, 30, 40` so `SUM($AG$14:$AI$14) = 100`).
            - If at least one `wsSub` is non-null and `exWeight > 0`:
                - `exPs = round2(((wsSt1 + wsSt2 + wsTe) / activeSubWeightSum) * 100.0)`
                - `exWs = round2(exPs * (exWeight / 100.0))`
        - **Initial Grade (`computeInitialGrade`)**:
            - Matches Excel `AL17`:
                - If `exWeight == 0`: requires both `wwWs != null` and `ptWs != null`, then `ig = round2(wwWs + ptWs)`.
                - If `exWeight > 0`: requires `wwWs != null`, `ptWs != null`, and `exWs != null` (or if partial display is desired during encoding, sum available weighted scores while flagging incomplete components; to match Excel strictly, compute running sum when any component has a score, or provide a `strictCompleteOnly` flag). *Note: In Screenshot 4 of the Excel template, when WW, PT, and EX are encoded, `IG = 20.00 + 50.00 + 27.00 = 97.00`.*
- [ ] **Step 1.2: Implement the Official 41-Tier Adjusted Transmutation Table (DO 15, s. 2026).**
    - Replace `transmute(double initialGrade)` in `lib/core/utils/deped_grading_engine.dart` with the exact thresholds from `HELPER!B7:D47`:
      ```dart
      static int transmuteDO15(double ig) {
        final roundedIg = round2(ig);
        if (roundedIg >= 99.50) return 100;
        if (roundedIg >= 98.32) return 99;
        if (roundedIg >= 97.14) return 98;
        if (roundedIg >= 95.96) return 97;
        if (roundedIg >= 94.78) return 96;
        if (roundedIg >= 93.60) return 95;
        if (roundedIg >= 92.42) return 94;
        if (roundedIg >= 91.24) return 93;
        if (roundedIg >= 90.06) return 92;
        if (roundedIg >= 88.88) return 91;
        if (roundedIg >= 87.70) return 90;
        if (roundedIg >= 86.52) return 89;
        if (roundedIg >= 85.34) return 88;
        if (roundedIg >= 84.16) return 87;
        if (roundedIg >= 82.98) return 86;
        if (roundedIg >= 81.80) return 85;
        if (roundedIg >= 80.62) return 84;
        if (roundedIg >= 79.44) return 83;
        if (roundedIg >= 78.26) return 82;
        if (roundedIg >= 77.08) return 81;
        if (roundedIg >= 75.90) return 80;
        if (roundedIg >= 74.72) return 79;
        if (roundedIg >= 73.54) return 78;
        if (roundedIg >= 72.36) return 77;
        if (roundedIg >= 71.18) return 76;
        if (roundedIg >= 70.00) return 75;
        if (roundedIg >= 65.34) return 74;
        if (roundedIg >= 60.67) return 73;
        if (roundedIg >= 56.01) return 72;
        if (roundedIg >= 51.34) return 71;
        if (roundedIg >= 46.67) return 70;
        if (roundedIg >= 42.01) return 69;
        if (roundedIg >= 37.34) return 68;
        if (roundedIg >= 32.68) return 67;
        if (roundedIg >= 28.01) return 66;
        if (roundedIg >= 23.35) return 65;
        if (roundedIg >= 18.68) return 64;
        if (roundedIg >= 14.01) return 63;
        if (roundedIg >= 9.35) return 62;
        if (roundedIg >= 4.68) return 61;
        return 60;
      }
      ```
- [ ] **Step 1.3: Add Descriptors, Remarks, and Multi-Term Final Grade Formula.**
    - Add `getDescriptor(int finalOrTermGrade)`:
        - `90–100`: `'Advancing'`
        - `80–89`: `'Benchmarking'`
        - `75–79`: `'Connecting'`
        - `65–74`: `'Developing'`
        - `60–64`: `'Emerging'`
    - Add `getRemarks(int finalOrTermGrade)`:
        - `>= 75 ? 'PASSED' : 'FAILED'`
    - Add `computeFinalGrade({required int termsTaught, required List<int> activeTerms, required Map<int, int?> termGrades, double unitsPerTerm = 2.0, double? totalUnitsEarned})`:
        - Check that every term in `activeTerms` has a non-null `termGrades[t]`. If any required active term is missing (`COUNT(E17:G17) <> termsTaught`), return `null`.
        - Otherwise, compute `finalGrade = ((sumOfActiveTermGrades * unitsPerTerm) / (totalUnitsEarned ?? (unitsPerTerm * termsTaught))).round()` (which simplifies to `(sumOfActiveTermGrades / termsTaught).round()`).

---

### Phase 2: Multi-Term Subject Configuration (`1-Term`, `2-Term`, `3-Term`) & Database Persistence

- [ ] **Step 2.1: Expand `SubjectCatalogItem` in `lib/models/subject_catalog_model.dart`.**
    - Add fields:
        - `final int termsTaught;` (`1`, `2`, or `3` — Core & TechPro in G11 are `3`; Academic Electives are `1`; Work Immersion 540/640h can be `1` or `2`).
        - `final String defaultTermBlock;` (`'1ST, 2ND, 3RD'` when `termsTaught == 3`, `'FIRST TERM'` when `termsTaught == 1`, `'1ST & 2ND'` when `termsTaught == 2`).
        - `final double unitsPerTerm;` (e.g., `2.0` for Core, `3.0` for Academic Electives, `4.0` for G11 TechPro).
        - `final double st1Weight; final double st2Weight; final double teWeight;` (default `30, 30, 40`).
    - Add helper method `DepEdSubjectCatalog.getActiveTermsForBlock(int termsTaught, String termBlock)`:
        - If `termsTaught == 3` or `termBlock == '1ST, 2ND, 3RD'` -> returns `[1, 2, 3]`.
        - If `termsTaught == 1`:
            - `'FIRST TERM'` or `'1ST'` -> `[1]`
            - `'SECOND TERM'` or `'2ND'` -> `[2]`
            - `'THIRD TERM'` or `'3RD'` -> `[3]`
        - If `termsTaught == 2`:
            - `'FIRST TERM'` or `'1ST & 2ND'` -> `[1, 2]`
            - `'SECOND TERM'` or `'2ND & 3RD'` -> `[2, 3]`
            - Safety Check: 2-term electives **cannot** begin in Term 3 (`HELPER!G25`: *"2-term electives cannot begin in Term 3."*). Block `'THIRD TERM'` selection when `termsTaught == 2`.
- [ ] **Step 2.2: Create Supabase Migration `supabase/migrations/003_gradebook_term_support.sql`.**
    - Add columns to `public.subject_offerings` using `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`:
        - `terms_taught smallint NOT NULL DEFAULT 3 CHECK (terms_taught BETWEEN 1 AND 3)`
        - `term_block varchar(20) NOT NULL DEFAULT '1ST, 2ND, 3RD'`
        - `units_per_term numeric(4,1) NOT NULL DEFAULT 2.0`
        - `st1_weight numeric(5,2) NOT NULL DEFAULT 30.00`
        - `st2_weight numeric(5,2) NOT NULL DEFAULT 30.00`
        - `te_weight numeric(5,2) NOT NULL DEFAULT 40.00`
    - Create table `public.gradebook_term_sheets` to persist the teacher's per-term grid state (`hps_json` and `scores_json` per `subject_offering_id` and `term_number`):
      ```sql
      CREATE TABLE IF NOT EXISTS public.gradebook_term_sheets (
          id uuid NOT NULL DEFAULT gen_random_uuid(),
          subject_offering_id uuid NOT NULL REFERENCES public.subject_offerings(id) ON DELETE CASCADE,
          term_number smallint NOT NULL CHECK (term_number BETWEEN 1 AND 3),
          hps_json jsonb NOT NULL DEFAULT '{"ww":{},"pt":{},"ex":{}}'::jsonb,
          scores_json jsonb NOT NULL DEFAULT '{}'::jsonb,
          updated_at timestamptz NOT NULL DEFAULT now(),
          CONSTRAINT gradebook_term_sheets_pkey PRIMARY KEY (id),
          CONSTRAINT gradebook_term_sheets_unique_offering_term UNIQUE (subject_offering_id, term_number)
      );
      ```
- [ ] **Step 2.3: Update `LocalStorageService` and `SubjectRepository` for Offline-First Term Gradebook Storage.**
    - In `lib/core/services/local_storage_service.dart`, add:
        - `saveGradebookSheet(String offeringId, int termNumber, Map<String, dynamic> payload)`
        - `getGradebookSheet(String offeringId, int termNumber)`
    - In `lib/data/repositories/subject_repository.dart`:
        - Update `saveSubjects()` and `getTeacherSubjects()` to include `terms_taught`, `term_block`, `units_per_term`, `st1_weight`, `st2_weight`, and `te_weight` (with graceful fallback if the remote column is not yet migrated).
        - Add `saveGradebookTermSheet(...)` and `getGradebookTermSheet(...)` that save immediately to `LocalStorageService` (0ms latency) and asynchronously upsert to `public.gradebook_term_sheets` and `public.term_grades` in Supabase using the authenticated teacher's Firebase UID (`AuthRepository.instance.currentUser?.id`).
- [ ] **Step 2.4: Update `TeacherClassroomSetupTab` (`lib/features/teacher/sub_features/setup/widgets/teacher_classroom_setup_tab.dart`).**
    - In `_buildAddSubjectForm()`, add two dropdown fields under Subject & Grade Level:
        1. **`No. of Terms Taught`**: Dropdown with options `3 Terms (Full Year / Trimester)`, `1 Term Only`, `2 Terms`. Auto-populated when a template is chosen from `DepEdSubjectCatalog`.
        2. **`Term Block (Active Term)`**:
            - If `3 Terms`: Locked to `'1ST, 2ND, 3RD'` with helper note: *"Note: Accomplish all Term sheets."*
            - If `1 Term`: Dropdown with `'FIRST TERM'`, `'SECOND TERM'`, `'THIRD TERM'` with helper note: *"Note: Accomplish only ONE (1) term sheet. Select the applicable TERM BLOCK."*
            - If `2 Terms`: Dropdown with `'1ST & 2ND (Starts Term 1)'`, `'2ND & 3RD (Starts Term 2)'` with helper note: *"Notes: Accomplish TWO (2) term sheets. 2-term electives cannot begin in Term 3."*

---

### Phase 3: Pure Square, Lag-Free Gradebook Cell & Strict Input Validations

- [ ] **Step 3.1: Create `lib/features/teacher/sub_features/grading/widgets/gradebook_grid_cell.dart`.**
    - Build a dedicated `StatefulWidget` named `GradebookGridCell` with these exact specifications:
        - **Pure Square / Rectangular Spreadsheet Styling (No Inner Oval/Pill):**
            - Remove any rounded/oval `InputDecoration` or pill-shaped container inside the cell.
            - The cell must be a flat, sharp-edged `Container` (`width: width, height: 32`, `borderRadius: BorderRadius.zero`) with only a `0.5px` right border (`Border(right: BorderSide(color: borderColor, width: 0.5))`).
            - When focused, highlight the entire square cell border with a crisp `1.5px` accent outline (`theme.colorScheme.primary`) and subtle tint—just like Microsoft Excel / Google Sheets—so numbers look large, centered, and legible (`fontSize: 12, fontWeight: FontWeight.w600`).
        - **Zero-Lag Controller Lifecycle:**
            - Initialize `late final TextEditingController _controller` and `late final FocusNode _focusNode` in `initState()`.
            - In `didUpdateWidget(GradebookGridCell oldWidget)`, only update `_controller.text` if `!_focusNode.hasFocus` and the external `value` changed (e.g., when switching terms or subjects). This completely eliminates cursor jumping, typing lag, and backspace stutter.
            - Dispose both `_controller` and `_focusNode` in `dispose()`.
        - **HPS Prerequisite Lock (Disabled State):**
            - Pass `bool isEnabled` into `GradebookGridCell`.
            - For Student Score cells, `isEnabled` is `true` **ONLY IF** the column's Highest Possible Score is set (`columnHps != null && columnHps! > 0`) AND the current Term sheet is active for the subject.
            - When `isEnabled == false`:
                - Render the cell with a muted gray disabled background (`isDark ? Color(0xFF1E293B) : Color(0xFFE2E8F0)`), set `enabled: false` on the `TextField`, and show a subtle tooltip on tap/hover: *"Set Highest Possible Score (HPS) for this column first."*
        - **Strict Input Formatters & Validations (`_ScoreRangeTextInputFormatter`):**
            - Create a custom `TextInputFormatter` that enforces:
                1. **Digits Only:** `FilteringTextInputFormatter.digitsOnly` (no decimals, negative signs, spaces, or letters).
                2. **Max 3 Digits & Max Value 100:** `LengthLimitingTextInputFormatter(3)`. If the parsed integer is `> 100`, reject the keystroke immediately (`return oldValue`).
                3. **HPS Cell Rule (`isHpsCell: true`):** Only allow empty string `''` (to clear the column) or integers from **`1` to `100`**. Block leading zero `'0'` as a standalone HPS to prevent division-by-zero (`Score / 0`).
                4. **Student Score Cell Rule (`isHpsCell: false`):** Allow empty string `''` (blank = excused/not yet encoded, NOT zero), `'0'` (explicit zero score), or integers up to **`min(100, columnHps)`**.
                5. **Cannot Exceed HPS Guard:** If `parsed > columnHps`, reject the keystroke in the formatter AND trigger a brief visual shake/red border flash or `SnackBar` warning: *"Score cannot exceed Highest Possible Score (${columnHps.toInt()})."*
            - **Additional Safety Validation when Teacher Lowers HPS:**
                - If a teacher already encoded student scores in column `col` (e.g., `40`) and later lowers the column's HPS to `30` (or clears HPS to `null`):
                    - Any existing student score in that column where `score > newHps` (or where `newHps == null`) is highlighted with a light red cell background and green/red warning text (matching Excel's conditional formatting rule: *"Indicates an invalid entry; remove the entry or encode the corresponding highest possible score first"*), and is excluded from the student's `TOTAL / PS / WS` until corrected.

---

### Phase 4: Term Separation, 1-Term/2-Term Sheet Locking & Final Grades View (`teacher_gradebook_tab.dart`)

- [ ] **Step 4.1: Partition Gradebook State by Term (`1`, `2`, `3`).**
    - In `lib/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart`, replace the flat `_scores` and `_hps` maps with term-indexed structures:
      ```dart
      // term (1, 2, 3) -> category ('ww', 'pt', 'ex') -> colIndex -> hps (null if blank)
      final Map<int, Map<String, Map<int, double?>>> _termHps = {
        1: {'ww': {}, 'pt': {}, 'ex': {}},
        2: {'ww': {}, 'pt': {}, 'ex': {}},
        3: {'ww': {}, 'pt': {}, 'ex': {}},
      };
  
      // term (1, 2, 3) -> studentId -> category ('ww', 'pt', 'ex') -> colIndex -> score (null if blank)
      final Map<int, Map<String, Map<String, Map<int, double?>>>> _termScores = {
        1: {},
        2: {},
        3: {},
      };
      ```
    - **Distinguish `null` (blank cell) from `0.0` (explicit zero score):**
        - When a cell is cleared (backspaced to empty), store `null` in `_termScores` / `_termHps`—do **not** store `0.0`.
        - If a teacher explicitly types `0` for a student's score, store `0.0` and render `'0'` in red/bold text, which counts `0` toward the student's total while keeping the column's HPS in the denominator.
- [ ] **Step 4.2: Display `WS ST1`, `WS ST2`, and `WS TE` in Both HPS Row and Student Rows.**
    - In `_buildHpsRow()` for `category == 'ex'`:
        - Instead of rendering empty strings `''` for the 3 exam sub-weight columns (`WS ST1`, `WS ST2`, `WS TE`), display `'30'`, `'30'`, and `'40'` (or the subject's configured `st1_weight`, `st2_weight`, `te_weight` from `_currentSubjectData`).
    - In `_buildStudentRows()` for `category == 'ex'`:
        - Compute and display each student's `WS ST1`, `WS ST2`, and `WS TE` formatted to 2 decimal places (`wsSt1.toStringAsFixed(2)`), `PS` formatted to 2 decimal places (`exPs.toStringAsFixed(2)`), and `WS` formatted to 2 decimal places (`exWs.toStringAsFixed(2)`), matching the Excel sheet (`20.00`, `30.00`, `40.00`, `90.00`, `27.00`).
    - Format `WW` and `PT` `PS` and `WS`, as well as `INITIAL GRADE (IG)`, to **2 decimal places** (`toStringAsFixed(2)`), and `TERM GRADE (TG)` as a **whole integer** (`toString()`), matching the Excel template (`97.00` IG -> `97` TG).
- [ ] **Step 4.3: Implement 1-Term / 2-Term Inactive Sheet Lock Banner.**
    - Determine `activeTerms` for the currently selected subject offering using `DepEdSubjectCatalog.getActiveTermsForBlock(termsTaught, termBlock)`.
    - In `_buildSchoolInfoBar()`, add info chips showing:
        - `Terms: $termsTaught ($termBlock)`
        - `Units: $unitsPerTerm / Term · $unitsPerYear / Year`
    - If `_selectedTerm` (`1`, `2`, or `3`) is **NOT** in `activeTerms`:
        - Display a prominent amber/red banner directly above the grid matching Excel Cell `B8`:
            - **`"INCORRECT SHEET. Do not use this sheet to input data. This subject is configured for $termBlock only."`**
        - Disable all HPS and Student Score cells on that term tab (`isEnabled: false`), and include a quick action button on the banner: `"Switch to Active Term"` or `"Change Term Block"`.
- [ ] **Step 4.4: Build the Dedicated `FINAL GRADES` Summary View (`_selectedTerm == 0`).**
    - When the user clicks the **`FINAL GRADES`** tab at the bottom (`_selectedTerm == 0`), switch the body of the spreadsheet from the raw score matrix to the official DepEd **FINAL GRADES** summary table (`sheet6.xml`):
        - **Columns:**
            1. `#` (30px)
            2. `LRN` (120px — displays `student.lrn ?? '-'`)
            3. `LEARNERS' NAMES` (220px — grouped by `MALE` and `FEMALE`)
            4. `FIRST TERM` (110px — shows Term 1 `TG` if Term 1 is in `activeTerms`, or `'N/A'` in muted gray if Term 1 is not part of `activeTerms`)
            5. `SECOND TERM` (110px — shows Term 2 `TG` if Term 2 is in `activeTerms`, or `'N/A'`)
            6. `THIRD TERM` (110px — shows Term 3 `TG` if Term 3 is in `activeTerms`, or `'N/A'`)
            7. `FINAL GRADE` (110px — bold whole number computed via `DepEdGradingEngine.computeFinalGrade`; remains blank `''` until all active terms for that subject have a computed Term Grade)
            8. `DESCRIPTOR` (150px — `'Advancing'`, `'Benchmarking'`, `'Connecting'`, `'Developing'`, `'Emerging'`)
            9. `REMARK` (110px — status badge: green `'PASSED'` for `>= 75`, red `'FAILED'` for `< 75`)
        - **Header Metadata Strip in Final Grades View:**
            - Display `NO. OF TERMS: $termsTaught`, `TERM BLOCKS: $termBlock`, `UNITS PER TERM: $unitsPerTerm`, and `TOTAL UNITS EARNED: $unitsPerYear`.

---

### Phase 5: Verification & Unit Testing

- [ ] **Step 5.1: Create Unit Tests in `test/core/utils/deped_grading_engine_test.dart`.**
    - Write and run `flutter test test/core/utils/deped_grading_engine_test.dart` covering:
        1. **Exact Excel Benchmark Test (`input_file_3.png`):**
            - Input: `WW1: 10/10 (20%)`, `PT1: 10/10 (50%)`, `EX (30%): ST1=2/3, ST2=1/1, TE=1/1`.
            - Assert: `wsSt1 == 20.00`, `wsSt2 == 30.00`, `wsTe == 40.00`, `exPs == 90.00`, `exWs == 27.00`, `initialGrade == 97.00`, `termGrade == 97`, `descriptor == 'Advancing'`, `remarks == 'PASSED'`.
        2. **DO 15, s. 2026 Boundary Transmutation Tests:**
            - Assert `99.50 -> 100`, `99.49 -> 99`, `95.96 -> 97`, `94.00 -> 95` (note: in DO 15, `93.60–94.77` is `95`, whereas in old DO 8 it was `96`), `70.00 -> 75` (Passing Line), `69.99 -> 74` (`Developing / FAILED`), `0.00 -> 60` (`Emerging / FAILED`).
        3. **1-Term Subject Taken in Term 2 or Term 3 Final Grade Test:**
            - Input: `termsTaught = 1, activeTerms = [2], termGrades = {1: null, 2: 94, 3: null}, unitsPerTerm = 3, totalUnitsEarned = 3`.
            - Assert: `finalGrade == 94`, Term 1 and Term 3 are ignored.
        4. **3-Term Subject Incomplete vs Complete Final Grade Test:**
            - Input: `termsTaught = 3, activeTerms = [1, 2, 3], termGrades = {1: 90, 2: 93, 3: null}` -> Assert `finalGrade == null`.
            - Input: `termGrades = {1: 90, 2: 93, 3: 97}` -> Assert `finalGrade == 93` (`ROUND((90+93+97)*2/6, 0) = 93`).
- [ ] **Step 5.2: Run `flutter analyze` and Verify UI Behavior in Chrome.**
    - Confirm zero analyzer errors, zero typing/backspace lag in `GradebookGridCell`, disabled student score cells when column HPS is blank, strict `1–100` (3-digit max) validation, independent scores across `Term 1`, `Term 2`, and `Term 3`, and accurate `FINAL GRADES` computation.