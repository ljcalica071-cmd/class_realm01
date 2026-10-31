# Exploration & Architecture Survey: Gradebook Optimization (R1) & Directory Management Polish (R2)

**Author**: Explorer Subagent  
**Date**: 2026-10-30T23:26:00Z  
**Scope**: Requirements R1 (Gradebook Optimization & Crash/Duplication Fixes) and R2 (Manage Students & Manage Parents UI Polish)  
**Target Directory**: `c:\Users\Admin\AndroidStudioProjects\class_realm01`  

---

## 1. Observation

### 1.1 Gradebook Architecture & Rendering Locations
- **Main Widget File**: `lib/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart` (2,953 lines).
- **Cell Widget File**: `lib/features/teacher/sub_features/grading/widgets/gradebook_grid_cell.dart`.
- **Spreadsheet Structure**:
  - The spreadsheet viewport is constructed inside `_TeacherGradebookTabState.build()` at lines 774–1045 as a horizontal `Row` containing two distinct vertical hierarchies:
    1. **Left Sticky Column** (width: `230.0` px, lines 781–898):
       - Category headers (`_buildCategoryHeaders(..., isLeft: true)`, line 797): Renders `#` (`30.0` px) and `LEARNERS' NAMES` (`200.0` px).
       - Sub-headers (`_buildColumnSubHeaders(..., isLeft: true)`, line 806).
       - HPS row (`_buildHpsRow(..., isLeft: true)`, line 818).
       - Student rows (`_buildStudentRows(..., isLeft: true)`, line 839 & line 865).
    2. **Right Scrollable Section** (`Expanded` -> `Scrollbar` -> horizontal `SingleChildScrollView`, lines 900–1042):
       - Category headers (`_buildCategoryHeaders(..., isLeft: false)`, line 915): Renders `WW (Written Works)`, `PT (Performance Tasks)`, `EX (Examinations)`, `INITIAL GRADE`, and `TERM GRADE`.
       - Sub-headers (`_buildColumnSubHeaders(..., isLeft: false)`, line 924): Numeric indices `1..10`, `TOTAL`, `PS`, `WS`.
       - HPS row (`_buildHpsRow(..., isLeft: false)`, line 937).
       - Student rows (`_buildStudentRows(..., isLeft: false)`, line 958 & line 1006).

### 1.2 Exact Crash Sites for Duplicate Keys & Assertion Failure
1. **Duplicate Key Crash**:
   - Verbatim crash:
     `Duplicate keys found. Column(direction: vertical...) has multiple children with key [gradebook-row-zV0ZGShD46TGOcXrfsLIX1Jd45j2-true]`
   - Observed in `teacher_gradebook_tab.dart` lines 833–896 (Left Sticky Column):
     ```dart
     833: if (_selectedGender == 'All' || _selectedGender == 'Male') ...[
     834:   _buildGenderHeader(
     835:     'MALE (${_maleStudents.length})',
     836:     genderHeaderBg,
     837:     isLeft: true,
     838:   ),
     839:   ..._buildStudentRows(
     840:     _visibleMaleStudents,
     ...
     850:     isLeft: true,
     851:   ),
     ...
     859: ],
     860: _buildGenderHeader(
     861:   'MALE',
     862:   genderHeaderBg,
     863:   isLeft: true,
     864: ),
     865: ..._buildStudentRows(
     866:   _visibleMaleStudents,
     ...
     876:   isLeft: true,
     877: ),
     878: _buildGenderHeader(
     879:   'FEMALE',
     880:   genderHeaderBg,
     881:   isLeft: true,
     882: ),
     883: ..._buildStudentRows(
     884:   _visibleFemaleStudents,
     ...
     894:   isLeft: true,
     895: ),
     ```
   - Observed in `_buildStudentRows` (line 2591):
     ```dart
     2588: return List.generate(students.length, (idx) {
     2589:   final s = students[idx];
     2590:   return AnimatedBuilder(
     2591:     key: ValueKey('gradebook-row-${s.id}-$isLeft'),
     ...
     ```
   - When `_selectedGender == 'All'` or `_selectedGender == 'Male'`, `_visibleMaleStudents` is passed to `_buildStudentRows` at line 839, generating key `ValueKey('gradebook-row-${s.id}-true')`. Then immediately at line 865, `_visibleMaleStudents` is passed to `_buildStudentRows` **again unconditionally**, producing the exact duplicate key `ValueKey('gradebook-row-${s.id}-true')` inside the same vertical `Column`!
2. **Assertion Failure `_elements.contains(element) is not true` & Filter Duplication**:
   - In the left column (lines 833–896), there is NO `if (_selectedGender == 'All' || _selectedGender == 'Female')` branch at all. Female students were only rendered by the unconditional fallback at lines 878–895.
   - In the right column (lines 952–1037), conditional rendering existed for both Male and Female, BUT lines 1006–1037 also appended unconditional male and female student rows!
   - When toggling between `'All'`, `'Male'`, and `'Female'`, the left and right columns have completely mismatched child element counts and orders (e.g., selecting `'Female'` renders Male rows at the top of the left column, but Female rows at the top of the right column).
   - During `setState`, Flutter's `RenderObjectElement.updateChildren` / `Element.deactivateChild` encounters duplicate keys and mismatched element identities in the active slot list, triggering the framework assertion: `assert(_elements.contains(element))`.

### 1.3 Score Column Slots Definition & Render Burden
- Observed in `teacher_gradebook_tab.dart` lines 171–173:
  ```dart
  static const int wwColumns = 10;
  static const int ptColumns = 10;
  static const int exColumns = 3; // ST1, ST2, TE
  ```
- Observed widget count:
  - Each student row renders 10 WW score cells + 3 computed cells + 10 PT score cells + 3 computed cells + 3 EX cells + 5 exam computed cells + 2 grade cells = **36 cells per row**, of which 23 are editable, focusable `GradebookGridCell` widgets.
  - For a typical class of 40 students, this creates **920 interactive cells** in memory simultaneously, plus HPS inputs.
  - This excessive widget load causes perceptible render lag and frame drops during horizontal scrolling.

### 1.4 Directory Management Tables (Manage Students & Manage Parents)
- **Manage Students File**: `lib/features/teacher/sub_features/class_management/widgets/teacher_student_management_tab.dart` (1,751 lines).
- **Manage Parents File**: `lib/features/teacher/sub_features/class_management/widgets/teacher_parent_management_tab.dart` (1,715 lines).
- **Student Name Text Sizes**:
  - `teacher_student_management_tab.dart` lines 998–1013:
    ```dart
    TextSpan(text: lastName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
    TextSpan(text: ', $restOfName', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface)),
    ```
    Column width is `colNameWidth = 260.0`.
  - `teacher_parent_management_tab.dart` lines 868–883:
    Parent name uses `fontSize: 13, fontWeight: FontWeight.bold` and `fontSize: 13, fontWeight: FontWeight.w500`, but its column width is compressed to `colNameWidth = 240.0` due to an unnecessary checkbox column (`colCheckWidth = 48.0`).
- **Manage Parents Directory Issues**:
  1. **Checkbox Column**: `colCheckWidth = 48.0` is placed adjacent to `#` at lines 742–768 (header) and lines 836–850 (rows). `_selectedParentIds` has no bulk actions or batch operations attached to it.
  2. **SECTION vs BIRTHDAY Column**:
     - `teacher_parent_management_tab.dart` lines 938–948 (header) and lines 1034–1042 (row) display `SECTION` with width `colSectionWidth = 140.0`.
     - In data model `UserModel` (`lib/models/user_model.dart` line 27 & 64), `final DateTime? birthday;` is available.
     - In `SupabaseParentRepository` (`lib/data/repositories/supabase_parent_repository.dart` line 127 & line 229), `birthday` is already queried from `parent_profiles` and populated into `UserModel.birthday`.
     - Linked student profile `linkedStudent?.birthday` is also available via `_enrolledStudents`.
  3. **Subject Filter Dropdown**:
     - `teacher_parent_management_tab.dart` line 33 and line 465 initializes with `String _selectedSubjectFilter = '— All Subjects —';` and includes `'— All Subjects —'` in the dropdown items list.
  4. **Table Header Horizontal Overflow**:
     - In `teacher_parent_management_tab.dart` line 383, `colRelWidth = 130.0` with `horizontal: 10` padding leaves an inner width of 110 px.
     - In `_buildClickableHeaderTitle` (line 1272):
       ```dart
       Widget _buildClickableHeaderTitle(String title, String columnKey) {
         final isCurrent = _sortColumn == columnKey;
         final icon = !isCurrent ? ' ↕' : (_sortAscending ? ' ▴' : ' ▾');
         return InkWell(
           onTap: () => _onSort(columnKey),
           child: Text(
             '$title$icon',
             style: TextStyle(
               color: theme.colorScheme.onSurface,
               fontWeight: isCurrent ? FontWeight.w800 : FontWeight.bold,
               fontSize: 12.5,
             ),
           ),
         );
       }
       ```
     - Notice: `Text('$title$icon')` lacks `maxLines: 1` and `overflow: TextOverflow.ellipsis`!
     - When sorted by relationship, `'RELATIONSHIP ▴'` at `FontWeight.w800` exceeds 110 px, throwing a `RenderFlex overflowed by X pixels` yellow/black zebra stripe error.

---

## 2. Logic Chain

### 2.1 Gradebook Crash and Duplication Resolution
1. **Deduplication**:
   - In `teacher_gradebook_tab.dart`, the left column contains lines 833–859 (conditional Male) followed immediately by unconditional lines 860–895 (Male + Female).
   - Removing lines 860–895 and providing explicit, symmetrical conditional branches for both `_selectedGender == 'All' || _selectedGender == 'Male'` and `_selectedGender == 'All' || _selectedGender == 'Female'` ensures each student row is instantiated exactly once per render pass.
   - Similarly, in the right column, removing unconditional lines 1006–1037 eliminates duplicate right-column cells.
   - Because each student row key `ValueKey('gradebook-row-${s.id}-$isLeft')` is now guaranteed to appear at most once within its parent `Column`, Flutter's duplicate key exception is completely resolved.
   - Furthermore, because left and right columns have identical row counts, identical sorting, and identical gender headers, element reconciliation during filter toggling succeeds without triggering `_elements.contains(element) is not true`.

### 2.2 Dynamic 5-to-10 Column Slot Expansion Architecture
1. **State Conversion**:
   - Convert `static const int wwColumns = 10` and `ptColumns = 10` to state variables:
     ```dart
     int _wwColumns = 5;
     int _ptColumns = 5;
     static const int maxCategoryColumns = 10;
     static const int defaultCategoryColumns = 5;
     ```
2. **Preserving Loaded Data**:
   - In `_decodeSheet()`, inspect the loaded sheets:
     ```dart
     final maxWwKey = _termHps[term]!['ww']!.keys.followedBy(
       _termScores[term]!.values.expand((m) => m['ww']?.keys ?? <int>[]),
     ).fold<int>(-1, (max, k) => k > max ? k : max);
     _wwColumns = math.max(defaultCategoryColumns, maxWwKey + 1).clamp(defaultCategoryColumns, maxCategoryColumns);
     ```
   - This ensures that if a teacher opens a sheet that already has 7 or 8 columns recorded, all entered scores are displayed automatically.
3. **Inline '+' Button in Sub-Headers**:
   - In `_buildColumnSubHeaders()`, when rendering category columns for `ww` or `pt`:
     - Render columns `0` to `_wwColumns - 1` (titled `1.._wwColumns`).
     - If `_wwColumns < maxCategoryColumns`, append an inline button cell of width `colW = 48.0` with an icon `Icon(Icons.add_circle_outline, size: 16)` and tooltip `'Add Written Work slot'`.
     - Clicking the button increments `_wwColumns` via `setState(() => _wwColumns++)`. Once `_wwColumns == 10`, the button disappears.
   - In `_buildCategoryHeaders()`, calculate width dynamically:
     `_wwColumns * colW + 3 * computedW + (_wwColumns < maxCategoryColumns ? colW : 0)`.
   - In `_buildHpsRow()` and `_buildStudentRows()`, append an empty cell `_emptyGridCell(colW, ...)` when `_wwColumns < maxCategoryColumns` to maintain strict column alignment with the subheader.
   - In `_initialGrade()` and `_calculateTotalWidth()`, use `_wwColumns` and `_ptColumns`.

### 2.3 Directory Management Polish (Manage Students & Manage Parents)
1. **Typography Standardization**:
   - Standardize student names in Manage Students and parent names in Manage Parents:
     - Set column width to `260.0` px in both tables.
     - Uniform typography: `fontSize: 13`, `fontWeight: FontWeight.bold` for `lastName`, `fontWeight: FontWeight.w500` for `', $restOfName'`, `overflow: TextOverflow.ellipsis`, `maxLines: 1`.
2. **Checkbox Column Removal**:
   - In `teacher_parent_management_tab.dart`, remove `colCheckWidth = 48.0`.
   - Update `pinnedWidth = colNumWidth + colNameWidth` (`56.0 + 260.0 = 316.0`).
   - Remove checkbox cells from header and rows.
3. **Replace 'SECTION' with 'BIRTHDAY'**:
   - Define `colBirthdayWidth = 140.0`.
   - Retrieve parent's birthday from `p.birthday` (fallback to `linkedStudent?.birthday`).
   - Format date consistently with Manage Students: `'${bday.year}-${bday.month.toString().padLeft(2, '0')}-${bday.day.toString().padLeft(2, '0')}'` (or `'—'` if null).
   - Add clickable sort header for `'birthday'`.
4. **Subject Filter Refinement**:
   - Remove `'— All Subjects —'`. Default `_selectedSubjectFilter` to the teacher's first assigned subject.
   - Restrict filter dropdown items to `_teacherSubjects` only.
   - Filter query strictly compares `studentSubject == _selectedSubjectFilter`.
5. **Horizontal Overflow Artifact Fix**:
   - In `_buildClickableHeaderTitle()` and static header cells:
     - Add `overflow: TextOverflow.ellipsis` and `maxLines: 1`.
     - Increase `colRelWidth` from `130.0` to `140.0` px.
     - Ensure `scrollableColsWidth` exactly matches the sum of child columns (`140 + 240 + 140 + 140 + 180 = 840.0` px).

---

## 3. Caveats

1. **Gradebook Save Payload**:
   - `_persistSheet()` saves the entire `_termHps` and `_termScores` maps as JSON to Supabase. Reducing visible score column slots from 10 to 5 does NOT erase scores in slots 6–10 in the database if they were previously saved; however, computing metrics (`_componentMetrics`) must pass `_wwColumns` so that only currently enabled slots are evaluated.
2. **Exam Columns (EX)**:
   - The requirement specifically targets assessment score columns (WW and PT). Exam columns (`exColumns = 3` for ST1, ST2, TE) must remain fixed at 3 as mandated by the Senior High School grading system.
3. **Parent Birthday Data Availability**:
   - Older parent accounts created before `birthday` was required may have `p.birthday == null`. The fallback to `linkedStudent?.birthday` (or displaying `'—'`) prevents null crashes.

---

## 4. Conclusion & Actionable Implementation Plan

### 4.1 Implementation Tasks for Requirement R1 (`teacher_gradebook_tab.dart`)
1. **Eliminate Duplicate Key Crash & Filter Desync**:
   - In the Left Sticky Column (lines 833–896), replace the block with:
     ```dart
     if (_selectedGender == 'All' || _selectedGender == 'Male') ...[
       _buildGenderHeader('MALE (${_maleStudents.length})', genderHeaderBg, isLeft: true),
       ..._buildStudentRows(_visibleMaleStudents, theme, isDark, cellText, borderColor, altRowBg, cellBg, wwWeight, ptWeight, exWeight, isLeft: true),
       if (_maleStudents.length > _maleVisibleCount)
         _buildLoadMoreRow(isMale: true, isLeft: true, theme: theme, borderColor: borderColor),
     ],
     if (_selectedGender == 'All' || _selectedGender == 'Female') ...[
       _buildGenderHeader('FEMALE (${_femaleStudents.length})', genderHeaderBg, isLeft: true),
       ..._buildStudentRows(_visibleFemaleStudents, theme, isDark, cellText, borderColor, altRowBg, cellBg, wwWeight, ptWeight, exWeight, isLeft: true),
       if (_femaleStudents.length > _femaleVisibleCount)
         _buildLoadMoreRow(isMale: false, isLeft: true, theme: theme, borderColor: borderColor),
     ],
     ```
   - In the Right Scrollable Column (lines 952–1037), remove unconditional lines 1006–1037.
2. **Dynamic 5-to-10 Column Slots with Inline '+' Button**:
   - Change `wwColumns` and `ptColumns` from static constants to state variables initialized to 5.
   - Add `math.max(5, highestIndex + 1)` detection in `_decodeSheet()`.
   - Update `buildCategoryCols()` in `_buildColumnSubHeaders()` to render an inline '+' button when count < 10.
   - Update `_categoryBlock()`, `_buildHpsRow()`, `_buildStudentRows()`, `_initialGrade()`, and `_calculateTotalWidth()`.

### 4.2 Implementation Tasks for Requirement R2 (`teacher_parent_management_tab.dart`)
1. **Remove Checkbox Column**:
   - Delete `colCheckWidth = 48.0`.
   - Set `pinnedWidth = colNumWidth + colNameWidth` (`56.0 + 260.0 = 316.0`).
   - Remove checkbox header (lines 742–768) and data cells (lines 836–850).
   - Clean up `_selectedParentIds`.
2. **Replace 'SECTION' with 'BIRTHDAY'**:
   - Set `colBirthdayWidth = 140.0`.
   - Header: `_buildClickableHeaderTitle('BIRTHDAY', 'birthday')`.
   - Row: Format `p.birthday ?? linkedStudent?.birthday` as `YYYY-MM-DD` or `'—'`.
   - Add birthday case to `displayList.sort()`.
3. **Remove 'All Subjects' Option**:
   - Default `_selectedSubjectFilter` to `_teacherSubjects.firstOrNull`.
   - Dropdown items strictly list `..._teacherSubjects.map(...)`.
4. **Header Typography & Horizontal Overflow Artifacts**:
   - Standardize `colNameWidth` to `260.0` in Parent Directory to match Student Directory.
   - Add `maxLines: 1` and `overflow: TextOverflow.ellipsis` to `_buildClickableHeaderTitle()` and static header cells.
   - Increase `colRelWidth` to `140.0`.

---

## 5. Verification Method

### 5.1 Automated Unit & Widget Tests
Execute the existing Flutter test suites:
```bash
flutter test test/features/teacher/teacher_gradebook_tab_test.dart
```

Add dedicated regression tests verifying:
1. **Gender Filter Toggle Without Crashes**:
   - Pump `TeacherGradebookTab`.
   - Tap 'Female' toggle while on Term 1 tab. Verify no duplicate key exceptions or assertion failures are thrown.
   - Tap 'Male', then 'All'. Verify matching rows are rendered with strictly unique keys.
2. **5-to-10 Slot Expansion**:
   - Verify initial WW and PT column headers show columns 1..5 and a '+' button.
   - Tap '+' button. Verify slot 6 appears and column width recalculates.
   - Increment up to 10. Verify '+' button disappears upon reaching 10 slots.
3. **Manage Parents Polish**:
   - Verify checkbox column is absent and `#` is the leftmost column.
   - Verify `'BIRTHDAY'` column is present and `'SECTION'` is absent.
   - Verify subject filter contains no `'— All Subjects —'` option.

### 5.2 Visual Inspection
- Inspect the table headers across window resize (800px to 1920px) to verify zero RenderFlex overflow stripes.
- Verify typography parity across Student and Parent Directory tables.
