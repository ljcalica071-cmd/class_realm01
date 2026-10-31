# Comprehensive Codebase Survey Report: Requirements R3 & R4
**Attendance Tab Improvements, Inline RFID Tap-to-Link, and Attendance Audit & History Logs Refactoring**

- **Explorer Agent**: Explorer (Attendance & RFID Subsystem)
- **Working Directory**: `c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_survey_attendance_rfid\`
- **Target Subsystems**: Attendance Workspace, RFID Linking, Analytics & History Logs, Scheduling Guards
- **Date**: 2026-10-31

---

## 1. Observation

Direct observations from source code inspection across `lib/` and `test/`:

### 1.1 Requirement R3: Attendance Tab Improvements & Inline RFID Tap-to-Link

#### R3.1 Student Name Text Size & LRN Removal
- **File**: `lib/features/teacher/sub_features/attendance/widgets/attendance_roster_table.dart`
- **Lines**: 1076–1134 (`_buildStudentNameRichText`)
- **Direct Code Quote**:
  ```dart
  Widget _buildStudentNameRichText(
    ThemeData theme,
    AttendanceRosterStudent student,
  ) {
    final ln = student.lastName.trim();
    final fn = student.firstName.trim();
    final mi = student.middleInitial;
    final restParts = [
      if (fn.isNotEmpty) fn,
      ?mi,
    ].join(' ');
    final hasLrn = student.lrn != null && student.lrn!.trim().isNotEmpty;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: [
              TextSpan(
                text: ln.isNotEmpty ? ln : student.displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (ln.isNotEmpty && restParts.isNotEmpty)
                TextSpan(
                  text: ', $restParts',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.88),
                  ),
                ),
            ],
          ),
        ),
        if (hasLrn)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              'LRN ${student.lrn!.trim()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
      ],
    );
  }
  ```
- **Finding**:
  - The student's last name is rendered at `13` font size and first/middle names at `12.5`. In Manage Students (`teacher_student_management_tab.dart`, lines 994–1019), standard readable names use `fontSize: 13.5`–`14`.
  - The LRN is rendered directly underneath in a stacked `Column` (`Text('LRN ${student.lrn!.trim()}')` at `10.5` pt).
  - Row height is constrained to `52.0` (`_rowHeight = 52.0`, line 72), causing vertical crampedness.

#### R3.2 Lazy Loading in Attendance Student List (20 students per batch)
- **Files**:
  - Table implementation: `lib/features/teacher/sub_features/attendance/widgets/attendance_roster_table.dart`, lines 135–174, 785, 883.
  - List reference: `lib/features/teacher/sub_features/attendance/widgets/attendance_roster_list.dart`, lines 38–44, 284–304, 351–365.
  - Tab coordinator: `lib/features/teacher/sub_features/attendance/widgets/teacher_attendance_tab.dart`, lines 500–623 (`_loadRosterAndRecords`).
- **Direct Code Quote from `attendance_roster_table.dart`**:
  ```dart
  List<AttendanceRosterStudent> _buildFilteredSortedRoster() {
    ...
    return filtered; // Returns ALL students in the class session
  }
  ...
  ListView.builder(
    controller: _pinnedScrollController,
    itemCount: students.length, // Renders all 30–60+ students at once
  )
  ```
- **Direct Code Quote from legacy `attendance_roster_list.dart`**:
  ```dart
  late int _visibleCount;
  @override
  void initState() {
    super.initState();
    _visibleCount = widget.pageSize; // 20
  }
  ...
  final visibleSlice = filtered.take(effectiveVisibleCount).toList();
  ...
  if (hasMore) ...[
    AppButton.outline(
      label: 'Load More (Scroll to show ${filtered.length - effectiveVisibleCount} remaining)',
      onPressed: () => setState(() => _visibleCount += widget.pageSize),
    )
  ]
  ```
- **Finding**:
  - `AttendanceRosterTable` receives `_rosterStudents` (all students enrolled in the offering) and builds all rows simultaneously in dual synchronized `ListView.builder`s (`_pinnedScrollController` and `_scrollableScrollController`).
  - There is currently NO lazy batching (chunking by 20) in `AttendanceRosterTable`.

#### R3.3 RFID Linking Workflow & Current Popup Modal
- **Files**:
  - Modal: `lib/shared/widgets/modals/rfid_assignment_modal.dart`, lines 35–60, 70–150.
  - Invocation: `lib/features/teacher/sub_features/attendance/widgets/teacher_attendance_tab.dart`, lines 799–839 (`_openLinkRfidForStudent`).
  - Roster Table trigger: `lib/features/teacher/sub_features/attendance/widgets/attendance_roster_table.dart`, lines 1144, 1168.
  - Hardware listener: `lib/features/teacher/sub_features/attendance/widgets/teacher_attendance_tab.dart`, lines 637–673 (`_handleGlobalHardwareKey`).
  - Backend update: `lib/data/repositories/supabase_attendance_repository.dart`, lines 1278–1340 (`assignStudentRfid`).
- **Direct Code Quote from `teacher_attendance_tab.dart`**:
  ```dart
  Future<void> _openLinkRfidForStudent(
    AttendanceRosterStudent student, {
    String? prefillUid,
  }) async {
    final result = await RfidAssignmentModal.show(
      context,
      studentId: student.studentId,
      studentName: student.displayName,
      lrn: student.lrn,
      currentRfidUid: student.rfidUid,
      prefillRfidUid: prefillUid,
      repository: _repository,
    );
    ...
  ```
- **Finding**:
  - Clicking "Link RFID" on a student opens `RfidAssignmentModal`, requiring a dialog popup that has a manual text field (`_uidController`) and an explicit "Link Card" button.
  - `teacher_attendance_tab.dart` already has a working hardware keystroke listener (`HardwareKeyboard.instance.addHandler(_handleGlobalHardwareKey)`) which buffers raw USB keyboard-wedge RFID reader inputs (8–14 hex characters ending in Enter).
  - `SupabaseAttendanceRepository.instance.assignStudentRfid` already handles unique constraint conflict detection, reassigning from former holders, updating `student_profiles.rfid_uid`, and offline queue fallback.

#### R3.4 Action Button Organization
- **Files**:
  - Persistent Header: `lib/features/teacher/sub_features/attendance/widgets/teacher_attendance_tab.dart`, lines 1444–1516 (`_buildPersistentTopHeader`).
  - Table Action Bar: `lib/features/teacher/sub_features/attendance/widgets/attendance_roster_table.dart`, lines 507–532.
- **Direct Code Quote (`teacher_attendance_tab.dart`)**:
  ```dart
  // Mode Toggle
  Container(
    child: Row(
      children: [
        AppButton.primary/ghost(label: 'Take Attendance'),
        AppButton.primary/ghost(label: 'History & Analytics'),
      ],
    ),
  ),
  if (_selectedAttendanceView == 'Take Attendance' && _selectedSubjectId != null) ...[
    AppSecondaryButton(label: 'Cutoff Rules', ...),
    AppPrimaryButton(label: 'Save Attendance ($dirtyCount)', ...),
  ],
  ```
- **Direct Code Quote (`attendance_roster_table.dart`)**:
  ```dart
  if (!widget.isLocked)
    Wrap(
      children: [
        if (widget.onMarkAllPresent != null)
          AppButton.success(label: 'Mark All Present', ...),
        if (widget.onAutoAbsentUnmarked != null)
          AppButton.outline(label: 'Auto-Absent Unmarked', ...),
      ],
    ),
  ```
- **Finding**:
  - "Save Attendance" is currently separated from "Auto-Absent Unmarked" — "Save Attendance" is up in the top header, while "Auto-Absent" is in the table action strip.
  - "Cutoff Rules" is currently positioned after the view toggles ("Take Attendance" / "History & Analytics"), rather than before "Take Attendance".

#### R3.5 "History & Analytics" Rename, Filter Box Integration & Active Schedules
- **Files**:
  - View switcher: `lib/features/teacher/sub_features/attendance/widgets/teacher_attendance_tab.dart`, lines 80, 1048–1055, 1479–1493.
  - Filter box: `lib/features/teacher/sub_features/attendance/widgets/teacher_attendance_tab.dart`, lines 1522–1650 (`_buildClassAndDateControls`).
  - Analytics date bar: `lib/features/teacher/sub_features/attendance/widgets/attendance_history_analytics_view.dart`, lines 363–410 (`_buildDateFilterBar`).
  - Schedule source table: `teacher_schedule` in Supabase, `localSchedules` in Drift SQLite (`lib/data/datasources/local/tables.dart`, lines 10–25).
- **Direct Code Quote (`teacher_attendance_tab.dart`)**:
  ```dart
  List<String> get _gradeLevels { ... }
  List<String> get _availableSubjects { ... }
  List<Map<String, dynamic>> get _availableSections { ... }
  ```
- **Finding**:
  - The tab view is named `'History & Analytics'` instead of `'Analytics & History'`.
  - The filter box (`_buildClassAndDateControls`) leaves the right-hand area blank in history mode; `AttendanceHistoryAnalyticsView` duplicates a whole container for "This week", "This month", "Custom", and "Export SF2 CSV".
  - `_teacherSubjects` in `teacher_attendance_tab.dart` currently loads all offerings for the teacher, regardless of whether a schedule is plotted in `teacher_schedule` with `is_active = true`.

---

### 1.2 Requirement R4: Attendance Audit & History Logs Refactoring

#### R4.1 Lazy Loading vs Pagination
- **File**: `lib/features/teacher/sub_features/attendance/widgets/attendance_history_analytics_view.dart`
- **Lines**: 50–54, 153–220, 1476–1510.
- **Direct Code Quote**:
  ```dart
  bool _isLoadingHistory = true;
  List<AttendanceWorkspaceRecord> _historyRows = [];
  int _historyOffset = 0;
  bool _historyHasMore = false;
  bool _isLoadingMoreHistory = false;
  ...
  Future<void> _loadMoreHistory() async {
    ...
    final page = await _repository.getAttendanceHistory(
      AttendanceHistoryFilter(offset: _historyOffset, pageSize: 20, ...),
    );
    _historyRows.addAll(page.rows);
    _historyOffset = page.nextOffset;
    _historyHasMore = page.hasMore;
  }
  ...
  if (_historyHasMore)
    AppButton.outline(
      label: 'Load More Records',
      onPressed: _loadMoreHistory,
    )
  ```
- **Manage Students Pagination Pattern Reference**:
  `lib/features/teacher/sub_features/class_management/widgets/teacher_student_management_tab.dart`, lines 46–47, 513–520, 1353–1412, 1710–1749:
  ```dart
  int totalPages = (displayList.length / _itemsPerPage).ceil();
  if (totalPages == 0) totalPages = 1;
  if (_currentPage > totalPages) _currentPage = totalPages;
  final startIndex = (_currentPage - 1) * _itemsPerPage;
  final endIndex = (startIndex + _itemsPerPage).clamp(0, displayList.length);
  final paginatedList = displayList.sublist(startIndex, endIndex);
  ...
  // Full width footer:
  Text('Showing ${startIndex + 1} to $endIndex of ${displayList.length} entries')
  Row(
    children: [
      _buildPageButton('First', ...),
      _buildPageButton('<', ...),
      for (int p = 1; p <= totalPages; p++)
        _buildPageButton(p.toString(), ...),
      _buildPageButton('>', ...),
      _buildPageButton('Last', ...),
    ],
  )
  ```
- **Finding**:
  - The audit log section currently uses incremental loading ("Load More Records" button appending to `_historyRows`) instead of structured pagination with 20 records per page.

#### R4.2 Raw/Random Student IDs Displayed Instead of Full Names
- **Files**:
  - Presentation: `lib/features/teacher/sub_features/attendance/widgets/attendance_history_analytics_view.dart`, line 1362.
  - Repository Query: `lib/data/repositories/supabase_attendance_repository.dart`, lines 2434–2469 (`getAttendanceHistory`).
  - Model: `lib/models/attendance_workspace_models.dart`, lines 56–150 (`AttendanceWorkspaceRecord`).
- **Direct Code Quote from `attendance_history_analytics_view.dart`**:
  ```dart
  Text(
    'Student: ${row.studentId}', // Raw alphanumeric UID like "JrZ71239-14a..."
    style: TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    ),
  ),
  ```
- **Direct Code Quote from `supabase_attendance_repository.dart`**:
  ```dart
  rows = await _client
      .from('attendance_records')
      .select(
        'id, student_id, subject_offering_id, attendance_date, status, recording_method, time_in, device_id, remarks, recorded_by, created_at',
      )
      ...
  ```
- **Finding**:
  - `attendance_records` has foreign key `CONSTRAINT attendance_records_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.student_profiles(student_id)` (`002_supabas.sql`, line 184).
  - However, `getAttendanceHistory` in `supabase_attendance_repository.dart` does NOT join `student_profiles`.
  - `AttendanceWorkspaceRecord` lacks `firstName`, `lastName`, and `middleName` fields, forcing the view to display the raw `student_id`.

#### R4.3 Table Columns & Layout for Time In and Method
- **File**: `lib/features/teacher/sub_features/attendance/widgets/attendance_history_analytics_view.dart`, lines 1298–1435 (`_buildHistorySection`).
- **Direct Code Quote**:
  ```dart
  ListView.separated(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: _historyRows.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (ctx, i) {
      final row = _historyRows[i];
      ...
      return Container(
        ...
        child: Wrap(
          children: [
            ...
            Text('Student: ${row.studentId}'),
            Wrap(
              children: [
                Text('Time In: $timeInDisplay'), // Under student name!
                _buildProvenancePill(theme, row.source), // Under student name!
              ],
            ),
          ],
        ),
      );
    },
  )
  ```
- **Finding**:
  - The audit log is not an actual data table; it is a list of card tiles.
  - "Time In" and "Method" (`_buildProvenancePill`) are placed together in a subtitle wrap directly underneath the student ID, rather than in separate dedicated table columns.

---

## 2. Logic Chain

### 2.1 Logic for R3 Improvements
1. **Student Name Typography**: In `AttendanceRosterTable`, `ln` (fontSize 13) and `restParts` (fontSize 12.5) sit above `LRN` (fontSize 10.5). Removing the LRN subtitle cleans vertical space in the 52px row and allows increasing the name typography to 14.0 pt (bold for last name, semibold for first/middle names), achieving visual parity with the standard Manage Students table.
2. **Attendance Lazy Loading**: `ListView.builder` inside `AttendanceRosterTable` renders all students in the class. Slicing the sorted/filtered roster to `_visibleBatchCount` (initialized to 20) and listening to `_scrollableScrollController.position.pixels >= _scrollableScrollController.position.maxScrollExtent - 80` allows loading the next 20 students as the teacher scrolls, preventing UI freeze when handling large classes.
3. **Inline Tap-to-Link (No Modal)**:
   - When the user taps "Link RFID" on row `i`, set `_inlineLinkingStudentId = student.studentId`.
   - The cell replaces the button with a pulsing/waiting badge: "Waiting for RFID..." with a cancel button.
   - The global hardware listener in `teacher_attendance_tab.dart` intercepts scanner keystrokes. When `_inlineLinkingStudentId != null`, incoming characters are collected into an inline buffer.
   - When Enter or 8–14 hex characters are received, `_repository.assignStudentRfid` is called directly with `forceReassign: true`.
   - The UI updates student's `rfidUid` immediately, shows a temporary green checkmark "Linked: <UID>" in the row, updates the header notice, and clears `_inlineLinkingStudentId`. No popup modal is opened.
4. **Action Button Placement**:
   - In `AttendanceRosterTable`, "Auto-Absent Unmarked" marks all non-scanned students absent. Placing "Save Attendance" right beside it in the table toolbar (`onSaveAttendance: canSave ? _saveBatch : null`) allows instant 1-click committing of auto-absent marks.
   - Moving "Cutoff Rules" before the view switcher ("Take Attendance") preserves a logical left-to-right hierarchy: Configuration ("Cutoff Rules") -> View Mode ("Take Attendance" / "Analytics & History").
5. **Analytics & History Toolbar Integration**:
   - Merging "This Week", "This Month", "Custom", and "Export SF2 CSV" into the persistent filter container box on the right of Grade, Subject, and Section eliminates redundant bars and provides consistent placement.
   - Filtering `_teacherSubjects` by querying `teacher_schedule` for `is_active = true` ensures teachers cannot select classes that have no active class schedules plotted.

### 2.2 Logic for R4 Refactoring
1. **Pagination**:
   - Following `teacher_student_management_tab.dart`: `int _currentPage = 1; final int _pageSize = 20;`.
   - Slicing `historyRows` or querying Supabase with `.range((_currentPage - 1) * 20, _currentPage * 20 - 1)` with `count: CountOption.exact`.
   - Rendering the pagination bar: "Showing X to Y of Z entries" with `First`, `<`, page numbers, `>`, `Last` buttons.
2. **Student Full Name Resolution**:
   - `attendance_records` has an established foreign key to `student_profiles(student_id)`.
   - Changing `getAttendanceHistory` select query to include `student_profiles ( student_id, first_name, middle_name, last_name, lrn )` retrieves the learner's name attributes.
   - Adding `firstName`, `middleName`, `lastName` (or `studentName`) to `AttendanceWorkspaceRecord` allows formatting as `"$lastName, $firstName${middleName != null && middleName.isNotEmpty ? ' $middleName' : ''}"`.
   - If offline, query `LocalStudents` from Drift SQLite by `student_id` to populate names.
3. **Audit Data Table Layout**:
   - Replacing the card list with a table containing separate columns:
     - `DATE` (110px)
     - `LEARNER NAME` (240px, bold standard font)
     - `TIME IN` (130px, e.g. "07:45 AM")
     - `METHOD` (120px, provenance pill: RFID / Manual / System)
     - `STATUS` (130px, status badge: Present / Late / Absent / Excused)
     - `REMARKS` (180px, remark text)
     - `ACTIONS` (110px, "Correct" audit button)
   - Guarantees Time In and Method are in their own dedicated columns.

---

## 3. Caveats

1. **Hardware Keyboard Wedging on Web vs Desktop**: On Flutter Web, `HardwareKeyboard` events require the browser window/canvas to have focus. The existing `_hasEditableFocus()` guard must remain active to avoid swallowing keystrokes when the teacher is typing into a TextField (such as search or remarks).
2. **Card Conflict Confirmation**: If an RFID card is already assigned to another student, `assignStudentRfid` can force reassign or clear the previous student's card. In an inline workflow without modal, if a conflict occurs, an inline conflict alert or quick confirmation notice must be shown to ensure a card is not reassigned accidentally without teacher awareness.
3. **Active Schedules Filtering Fallback**: If a teacher has not yet configured any schedule in the Schedule tab, strictly filtering out offerings with no active schedules would result in an empty dropdown. A fallback banner ("No active schedules found for this academic term. Set up class schedules in My Schedule to record attendance.") should guide the teacher.
4. **History Data Join Schema Compatibility**: If an older backend environment lacks the foreign key or has orphan records where `student_profiles` row is missing, the code must gracefully fallback to `row.studentId`.

---

## 4. Conclusion & Proposed Implementation Steps

### Summary Assessment
Both R3 and R4 can be implemented cleanly using existing architectural patterns in the codebase without introducing new external packages. The database foreign keys, repositories, Drift local tables, and styling tokens already support all required behaviors.

### Proposed Implementation Plan

#### Step 1: Update Models & Repositories (`attendance_workspace_models.dart`, `supabase_attendance_repository.dart`)
1. In `AttendanceWorkspaceRecord`:
   - Add fields: `final String? firstName;`, `final String? middleName;`, `final String? lastName;`, `final String? studentName;`.
   - Add getter `formattedStudentName`:
     ```dart
     String get formattedStudentName {
       final ln = (lastName ?? '').trim();
       final fn = (firstName ?? '').trim();
       final mn = (middleName ?? '').trim();
       if (ln.isNotEmpty && fn.isNotEmpty) {
         return mn.isNotEmpty ? '$ln, $fn $mn' : '$ln, $fn';
       }
       if (studentName != null && studentName!.trim().isNotEmpty) {
         return studentName!.trim();
       }
       return studentId;
     }
     ```
   - Update `fromJson` and `toJson` to deserialize `student_profiles` joins.
2. In `supabase_attendance_repository.dart`:
   - In `getAttendanceHistory`, join `student_profiles ( student_id, first_name, middle_name, last_name, lrn )`.
   - In offline fallback, query Drift `LocalStudents` to populate names.
   - Add method or query to fetch offerings with active schedules:
     ```dart
     Future<Set<String>> getActiveScheduleOfferingIds(String teacherId);
     ```

#### Step 2: Implement Inline Tap-to-Link & Roster Polish (`attendance_roster_table.dart`, `teacher_attendance_tab.dart`)
1. In `attendance_roster_table.dart`:
   - In `_buildStudentNameRichText`:
     - Increase `fontSize` to `14.0` for last name and `13.5` for first/middle names.
     - Remove the `if (hasLrn)` block containing `'LRN ${student.lrn!.trim()}'`.
   - Add lazy loading:
     - `int _visibleBatchCount = 20;`
     - Slicing `filtered.take(_visibleBatchCount).toList()`.
     - Sync scroll listener to increment `_visibleBatchCount += 20` when scrolling near bottom.
   - Add inline RFID linking state:
     - Parameter `String? inlineLinkingStudentId`, `ValueChanged<AttendanceRosterStudent>? onStartInlineLinkRfid`, `VoidCallback? onCancelInlineLinkRfid`.
     - When `student.studentId == inlineLinkingStudentId`:
       Render pulsing/active chip: "Waiting for RFID..." with circular progress indicator and cancel button.
   - Place "Save Attendance" button next to "Auto-Absent Unmarked" button in the table toolbar:
     - Add `VoidCallback? onSaveAttendance;` and `bool isSavingBatch;` to `AttendanceRosterTable`.
     - Render `AppPrimaryButton(label: 'Save Attendance', icon: LucideIcons.check, isSmall: true, onPressed: onSaveAttendance)` immediately beside `Auto-Absent Unmarked`.

#### Step 3: Action Buttons Reorganization & Filter Box Integration (`teacher_attendance_tab.dart`)
1. Action buttons:
   - Move "Cutoff Rules" button before "Take Attendance" button in the top action bar.
2. View renaming:
   - Rename `'History & Analytics'` to `'Analytics & History'` in all state variables, tab buttons, and handlers.
3. Active schedules filtering:
   - In `_loadSubjects()`, filter `_teacherSubjects` against active schedule offering IDs from `teacher_schedule`.
4. Filter container box:
   - In `_buildClassAndDateControls`, when `_selectedAttendanceView == 'Analytics & History'`:
     - Render "This Week", "This Month", "Custom", and "Export SF2 CSV" inside the filter box on the right-hand side.
     - Pass the active preset, date range, and export handler to `AttendanceHistoryAnalyticsView`.

#### Step 4: Audit & History Logs Refactoring into Data Table with Pagination (`attendance_history_analytics_view.dart`)
1. Remove redundant date filter bar from `AttendanceHistoryAnalyticsView`.
2. Convert `_buildHistorySection` from `ListView.separated` of cards into a full Data Table:
   - Header: `# / DATE`, `LEARNER NAME`, `TIME IN`, `METHOD`, `STATUS`, `REMARKS`, `ACTIONS`.
   - Data rows:
     - Dedicated `TIME IN` column with formatted clock string or `—`.
     - Dedicated `METHOD` column with `_buildProvenancePill(theme, row.source)`.
     - `LEARNER NAME` column showing `row.formattedStudentName` (format: "Lastname, Firstname Middlename").
3. Implement 20-item pagination:
   - `int _currentPage = 1; final int _itemsPerPage = 20;`
   - Calculate `totalPages = (totalRecords / _itemsPerPage).ceil()`.
   - Add Manage Students pagination footer:
     `Showing startIndex + 1 to endIndex of totalRecords entries`
     `[First] [<] [1] [2] ... [>] [Last]`.

---

## 5. Verification Method

### Test Commands to Run
1. Run teacher attendance tab widget tests:
   ```powershell
   flutter test test/features/teacher/attendance/teacher_attendance_tab_test.dart
   ```
2. Run history analytics view widget tests:
   ```powershell
   flutter test test/features/teacher/attendance/attendance_history_analytics_view_test.dart
   ```
3. Run roster list and calculator tests:
   ```powershell
   flutter test test/features/teacher/attendance/attendance_roster_list_test.dart
   flutter test test/features/teacher/attendance/attendance_analytics_calculator_test.dart
   ```
4. Run full attendance test suite:
   ```powershell
   flutter test test/attendance_redesign_test.dart
   ```

### Files to Inspect
- `lib/features/teacher/sub_features/attendance/widgets/attendance_roster_table.dart`
- `lib/features/teacher/sub_features/attendance/widgets/teacher_attendance_tab.dart`
- `lib/features/teacher/sub_features/attendance/widgets/attendance_history_analytics_view.dart`
- `lib/models/attendance_workspace_models.dart`
- `lib/data/repositories/supabase_attendance_repository.dart`

### Invalidation Conditions
- Student names in roster table appear with LRN underneath or smaller than 13.5 pt.
- Roster table displays more than 20 rows on initial load for a 40+ student class without user scrolling.
- Clicking "Link RFID" opens a modal dialog popup instead of activating inline row listening.
- USB RFID scan does not link directly to the student row or does not save to repository.
- "Save Attendance" button is not directly beside "Auto-Absent" in the table toolbar.
- "Cutoff Rules" appears after "Take Attendance" rather than before it.
- "Analytics & History" tab displays duplicate filter boxes or lists subjects without active schedules.
- Audit logs display alphanumeric student IDs (e.g. `JrZ...`) instead of `Lastname, Firstname Middlename`.
- Time In and Method share a column or are placed underneath student names instead of dedicated table columns.
- Audit logs load via infinite scroll button rather than 20-item page navigation with First/Prev/Page/Next/Last controls.
