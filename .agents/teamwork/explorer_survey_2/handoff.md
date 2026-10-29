# Frontend & UI/UX Architecture Survey Report

**Document**: Handoff Survey Report  
**Surveyor**: Teamwork Explorer (Survey Phase)  
**Target Milestone**: Attendance Feature Redesign (R2, R5, R6, R7)  
**Date**: 2026-10-29  

---

## 1. Observation

### 1.1 Existing Attendance & Roster UI File Structure
The frontend architecture was inspected across `lib/features/`, `lib/core/theme/`, `lib/shared/`, and `lib/models/`. The primary files governing the attendance domain are:

| File Path | Role / Content | Key Classes & Functions |
|---|---|---|
| `lib/features/teacher/sub_features/attendance/widgets/teacher_attendance_tab.dart` | Main Teacher Attendance Tab (Take Attendance + Analytics) | `TeacherAttendanceTab`, `_saveBatch`, `_handleHardwareKey`, `_processScannedRfid`, `_buildTakeAttendanceControls` |
| `lib/features/teacher/sub_features/attendance/widgets/attendance_roster_list.dart` | Student Roster Presentation | `AttendanceRosterList`, `_buildGenderGroupSection`, `_buildStudentRow`, `_buildStatusButton` |
| `lib/features/teacher/sub_features/attendance/widgets/attendance_history_analytics_view.dart` | Historical Attendance & Analytics | `AttendanceHistoryAnalyticsView`, `_buildKpiCards`, `_buildChartsSection`, `TrendChartPainter`, `_buildAtRiskSection`, `_buildHistorySection` |
| `lib/features/student/sub_features/schedule/screens/student_attendance_screen.dart` | Student View-Only Attendance | `StudentAttendanceScreen`, `_buildStatItem`, logs list |
| `lib/features/parent/sub_features/child_details/widgets/parent_attendance_tab.dart` | Parent View-Only Child Attendance | `ParentAttendanceTab`, `_buildStatCard`, child attendance log list |
| `lib/features/teacher/sub_features/class_management/widgets/teacher_student_management_tab.dart` | Teacher Student Directory | `TeacherStudentManagementTab`, student action buttons (Edit, Archive) |
| `lib/models/attendance_workspace_models.dart` | Data Transfer Models | `AttendanceWorkspaceRecord`, `AttendanceSource`, `AttendanceRosterStudent`, `AttendanceAnalyticsSummary` |
| `lib/core/theme/app_theme.dart` | Global Application Theme & 60-30-10 Palette | `AppTheme.lightTheme`, `AppTheme.darkTheme`, Categorical colors |
| `lib/core/theme/app_colors.dart` | Legacy / Secondary Theme Palette | `AppColors` token constants |
| `lib/shared/widgets/modals/app_modals.dart` | Standard Modal & Sanitization Library | `AppModals.showErrorDialog`, `AppModals.sanitizeErrorMessage`, `AppModals.showConfirmationDialog` |

---

### 1.2 Current Presentation of Student Roster (`attendance_roster_list.dart`)
1. **Boxed Cards Instead of Unified Table**:
   - In `attendance_roster_list.dart` (lines 416–426), each student is rendered inside an isolated `Container` card with individual outer margins:
     ```dart
     // attendance_roster_list.dart lines 416-425:
     return Container(
       margin: const EdgeInsets.only(bottom: 8),
       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
       decoration: BoxDecoration(
         color: theme.colorScheme.surface,
         borderRadius: BorderRadius.circular(8),
         border: Border.all(
           color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
         ),
       ),
     ```
2. **Circular Initials Badges Present**:
   - In `attendance_roster_list.dart` (lines 438–449), every row renders a circular avatar containing student initials:
     ```dart
     // attendance_roster_list.dart lines 438-449:
     CircleAvatar(
       radius: 18,
       backgroundColor: theme.colorScheme.primary,
       child: Text(
         initials,
         style: const TextStyle(
           color: Colors.white,
           fontWeight: FontWeight.bold,
           fontSize: 13,
         ),
       ),
     ),
     ```
3. **Gender Grouping Without Interactive Category Filters**:
   - In `attendance_roster_list.dart` (lines 265–292), students are split into Male, Female, and Unspecified lists in Dart code, but rendered strictly as consecutive vertical sections:
     ```dart
     if (visibleMales.isNotEmpty || (query.isEmpty && males.isNotEmpty))
       _buildGenderGroupSection(context: context, title: 'Male (${males.length})', ...),
     if (visibleFemales.isNotEmpty || (query.isEmpty && females.isNotEmpty))
       _buildGenderGroupSection(context: context, title: 'Female (${females.length})', ...),
     ```
   - There are currently no filter chips or tabs allowing the teacher to view "All", "Male Only", or "Female Only".
4. **"Save Attendance" Trapped at Bottom of Scroll View**:
   - In `teacher_attendance_tab.dart` (lines 949–973), the "Save Attendance" button is placed at the very end of the scrollable column beneath the entire roster:
     ```dart
     // teacher_attendance_tab.dart lines 949-963:
     // Bottom Action Save Attendance Bar
     if (_rosterStudents.isNotEmpty && !_isLoadingRoster)
       Row(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           _isSavingBatch
               ? const CircularProgressIndicator()
               : AppButton.primary(
                   icon: LucideIcons.check,
                   label: 'Save Attendance for ${_formatDate(_attendanceSelectedDate)}${_isDirty ? ' (Unsaved)' : ''}',
                   onPressed: _saveBatch,
                 ),
     ```
   - In a class of 45–60 students, the teacher is forced to scroll completely to the bottom of the page to save.

---

### 1.3 Theme Styling & 60-30-10 Color Token Audit
Inspection of `lib/core/theme/app_theme.dart` confirms that the application already establishes a strict 60-30-10 palette architecture:

1. **Light Mode Tokens (`app_theme.dart` lines 14–18)**:
   - **60% Base**: `_lightBg = Color(0xFFF5F5F5)` (warm off-white background).
   - **30% Structure**: `_lightSurface = Color(0xFFE8EBE2)` (warm sage secondary) and `_lightCard = Color(0xFFFFFFFF)` (card/container surface).
   - **10% Accent**: `_lightAccent = Color(0xFF487898)` (steel blue primary action).
   - **Typography**: `_lightText = Color(0xFF111827)` (near black, high contrast Inter font).
2. **Dark Mode Tokens (`app_theme.dart` lines 21–25)**:
   - **60% Base**: `_darkBg = Color(0xFF111827)` (deep midnight background).
   - **30% Structure**: `_darkSurface = Color(0xFF1F2937)` & `_darkCard = Color(0xFF263040)` (dark slate containers).
   - **10% Accent**: `_darkAccent = Color(0xFF60A5FA)` (vibrant sky blue accent).
   - **Typography**: `_darkText = Color(0xFFF9FAFB)`.
3. **Semantic Categorical Palette (`app_theme.dart` lines 31–38)**:
   - `catGreen = Color(0xFF16A34A)`: Present, Success indicators.
   - `catRed = Color(0xFFDC2626)`: Absent, Danger, Inline Error border.
   - `catOrange = Color(0xFFD97706)`: Late, Warning, At-Risk alert.
   - `catSlate = Color(0xFF475569)`: Excused, Neutral tags.
   - `catTeal = Color(0xFF0D9488)`: RFID hardware, NFC sync.
   - `catBlue = Color(0xFF2563EB)`: Classwork, Information badges.

*Observation on `app_colors.dart`*: `lib/core/theme/app_colors.dart` defines an older/alternative palette (`primary = Color(0xFF1E3A8A)`). New UI work should reference `AppTheme` semantic constants and `Theme.of(context).colorScheme` to preserve 60-30-10 visual balance.

---

### 1.4 Comprehensive UI Error Presentation Audit (Violations of R7)
A ripgrep search for `ScaffoldMessenger`, `showSnackBar`, and raw technical error strings across the attendance and student management modules revealed multiple direct violations of requirement R7:

| File Path | Line # | Offending Code Snippet | Issue Description | Required Replacement (R7) |
|---|---|---|---|---|
| `teacher_attendance_tab.dart` | 365–370 | `ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unmarked students have been set to Auto-Absent.')))` | Floating SnackBar on batch action | Non-intrusive inline banner or silent badge state update |
| `teacher_attendance_tab.dart` | 494–501 | `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attendance saved successfully!')))` | Floating SnackBar on successful save | In-header state badge ("Saved at 10:45 AM") or subtle checkmark indicator |
| `teacher_attendance_tab.dart` | 506–512 | `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save attendance: $e'), backgroundColor: AppTheme.catRed))` | **Raw technical error dump via SnackBar** | `AppModals.showErrorDialog` with `AppModals.sanitizeErrorMessage(e)` |
| `teacher_attendance_tab.dart` | 564–570 | `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${student.firstName} ${student.lastName} marked Present.')))` | Floating SnackBar on every single RFID tap | Visual live row flash/pulse in table roster + audible chime |
| `teacher_attendance_tab.dart` | 572–578 | `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ID $scannedId not found in this class.')))` | Floating SnackBar for unregistered/wrong class card tap | Modal Dialog alert (`AppModals.showErrorDialog`) with exact card UID & class roster context |
| `attendance_history_analytics_view.dart` | 195–198 | `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load more records: $e')))` | Raw error dump via SnackBar during pagination | Inline retry button within history list footer |
| `attendance_history_analytics_view.dart` | 311–315 | `ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance record corrected.')))` | Floating SnackBar on record correction | Inline status badge update or `AppModals.showSuccessDialog` |
| `student_attendance_screen.dart` | 93–99 | `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load more records: $e')))` | Floating red SnackBar in student app | Inline error container with retry button |
| `student_attendance_screen.dart` | 139–142 | `Text('Error loading attendance: $_errorMessage', style: TextStyle(color: theme.colorScheme.error))` | Raw Dart exception string dumped onto UI | Friendly error state using `AppModals.sanitizeErrorMessage` |
| `parent_home_screen.dart` | 129–151 | `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Active child switched...'), behavior: SnackBarBehavior.floating))` | Floating toast on child switch | Smooth animated header transition without floating toast |
| `teacher_student_management_tab.dart` | 978 | `final messenger = ScaffoldMessenger.of(context);` (unused reference left in handler) | Legacy ScaffoldMessenger hook | Remove obsolete reference |

---

### 1.5 Multi-Platform & Responsive Layout Architecture
1. **Teacher Dashboard Layout (`teacher_dashboard_screen.dart`)**:
   - Breakpoint: `MediaQuery.of(context).size.width < 900` defines `isMobile`.
   - On Desktop (>= 900px): Persistent collapsible sidebar (260px expanded, 80px collapsed) with top header and main content area.
   - On Mobile (< 900px): Sidebar moves into a modal slide-out `Drawer`, hamburger icon appears in top header.
2. **Attendance Controls Sub-Breakpoints (`teacher_attendance_tab.dart`)**:
   - `constraints.maxWidth >= 720`: Renders filters and search row horizontally.
   - `constraints.maxWidth < 720`: Stacks search field and date navigation vertically.
   - `constraints.maxWidth >= 460`: 4-column status cards; `< 460`: 2x2 grid.
3. **Student App Mobile Frame (`student_home_screen.dart` lines 250–261)**:
   - Uses `_mobileFrame`:
     ```dart
     Widget _mobileFrame(BuildContext context, Widget child) {
       return LayoutBuilder(builder: (context, constraints) {
         if (constraints.maxWidth <= 600) return child;
         return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: child));
       });
     }
     ```
   - Ensures responsive consistency across phones and centered presentation on tablets/web browsers.
4. **Current Empty States**:
   - Student App (`student_attendance_screen.dart` line 195): A bare `Center(child: Text('No attendance records found.'))` lacking graphics, context, or guidance.
   - Parent App (`parent_attendance_tab.dart` line 47): A simple text message `Text('No attendance records found.')`.
   - Teacher Roster (`attendance_roster_list.dart` line 110): Has an empty state with an icon and retry button, but lacks DepEd enrollment guidance.

---

### 1.6 Current RFID Architecture in Codebase
- The only existing hardware scan handling is in `teacher_attendance_tab.dart` lines 530–580 via a `KeyboardListener` on `_scannerFocusNode`.
- It matches characters into `_rfidBuffer` until `Enter` is detected, then searches `_rosterStudents` where `s.studentId == cleanId` or `s.studentId.contains(cleanId)`.
- **Zero RFID card assignment workflow currently exists in the entire codebase**. There is no RFID assignment modal, no card-to-student mapping interface, and no phone NFC reading capability.

---

## 2. Logic Chain

1. **R5 Roster Table Redesign Logic**:
   - *From Observation 1.2.1 & 1.2.2*: Currently, each student takes up substantial vertical screen real estate (boxed card padding 12px vertical, 8px outer margin, circular avatar).
   - *Inference*: On a 1080p display, only 6–8 students are visible without scrolling. Switching to a compact unified data table (row height 44px, border divider, no circular avatars) increases row density by ~250%, displaying 15–20 students simultaneously on screen.
   - *From Observation 1.2.4*: "Save Attendance" at the bottom requires repetitive scrolling every time a status is modified. Moving "Save Attendance" into the sticky top header (adjacent to date and class selectors) provides 100% persistent accessibility regardless of scroll offset.
   - *From Observation 1.2.3*: Teachers frequently need to check male vs female attendance for DepEd Form 2 (SF2). Providing dedicated filter segmented buttons (`All`, `Male Only`, `Female Only`) while retaining default grouped sorting satisfies DepEd operational workflows.

2. **R2 Teacher RFID Assignment Modal Logic**:
   - *From Observation 1.6*: Since no RFID assignment UI exists, teachers have no way to link a physical 13.56MHz NFC tag or 125kHz RFID card UID to a student's database record.
   - *Inference*: The workflow must be accessible from two distinct teacher touchpoints:
     a. Student Directory (`teacher_student_management_tab.dart`): Next to the Edit/Archive action buttons, an "Assign RFID" icon button.
     b. Attendance Roster Table (`attendance_roster_list.dart`): In the RFID status column, clicking an unassigned or assigned tag chip opens the assignment modal.
   - *Dual-Input Modal Mechanism*:
     - **USB / Keyboard Scanner Tab**: Focuses an input field with continuous keystroke listening, capturing the scanned UID upon carriage return (`Enter`), applying instant trim and hex normalization.
     - **Mobile Phone NFC Tap Tab**: Uses `nfc_manager` (for mobile) with a visual pulsing radar graphic. When a card taps the phone's NFC antenna, it reads the ISO/IEC 14443-A UID, normalizes it to standard hex uppercase (e.g. `04:A2:3B:5C:8D:1E:80`), and validates it against the backend.
   - *Conflict Guarding Logic*:
     - Before saving, query `student_profiles.rfid_uid = scannedUid`. If found assigned to a different student:
       - Never dump a database constraint error (code 23505).
       - Immediately show a clean confirmation dialog (`AppModals.showConfirmationDialog`):  
         *"This card is currently assigned to [Student Name] (Grade [G] - [Section]). Do you want to reassign this card to [Target Student]?"*
       - On confirm, atomic RPC executes the reassignment.

3. **R7 Strict Error Presentation Logic**:
   - *From Observation 1.4*: SnackBars and floating toasts obscure bottom action bars, disconnect error context from fields, and currently leak raw `$e` exceptions to users.
   - *Inference*: Strict division of error presentation must be enforced:
     - **Form & Input Validation**: Exclusively inline red borders (`Color(0xFFDC2626)`) with 12px error text directly underneath the input container and immediate live clearing upon input change (`inline-input-validation` skill).
     - **Scanner, Conflict & System Alerts**: Exclusively centered modal dialogs (`AppModals.showErrorDialog`, `AppModals.showConfirmationDialog`) with sanitized English explanations. Zero SnackBars, floating toasts, or top banners.

4. **R6 Multi-Platform Analytics & Empty State Logic**:
   - *From Observation 1.5*: Student and Parent apps currently render bare text when no records exist.
   - *Inference*: A dedicated `EmptyStateWidget` following 60-30-10 styling must be designed for both portals:
     - Prominent illustrated outline icon (`LucideIcons.calendarX2` or `LucideIcons.school`).
     - Clear, reassuring title: *"No Attendance Records Found"*.
     - Helpful explanatory copy detailing that records appear when the teacher takes attendance or scans their card.
     - Action button: *"Refresh Records"*.
   - In logs across Teacher, Student, and Parent, every record must render a recording method badge:
     - `RFID`: Teal chip (`AppTheme.catTeal`, `LucideIcons.radio`).
     - `Manual`: Slate chip (`AppTheme.catSlate`, `LucideIcons.edit3`).

---

## 3. Caveats

1. **Hardware Scanning on Web vs Mobile**:
   - USB keyboard-wedge RFID scanners work universally across Web, Windows, and macOS because they simulate hardware keystrokes ending with `Enter`.
   - Web browsers (Chrome/Edge on Desktop) generally do NOT support Web NFC (Web NFC is Android Chrome only, not Desktop). Therefore, the "Phone NFC Tap" mode must be conditionally presented or enabled when running on mobile devices (Android/iOS) or Android Web, while the USB Keyboard Scanner is universal.
2. **Local Drift SQLite Database Schema Updates**:
   - `AppDatabase` (`lib/data/datasources/local/app_database.dart`) has `schemaVersion = 1`. Adding `rfidUid` or `source` to local SQLite tables will require schema version increment and migration handling in Drift if implemented in code later.
3. **DepEd Section Separation Constraints**:
   - In SHS DepEd guidelines, students with unspecified gender are rare but possible in edge cases. The UI grouping must retain an "Other / Unspecified" fallback section if data contains non-binary entries.

---

## 4. Conclusion & Proposed UI Specifications

### 4.1 Component Mapping & Architecture Plan

```
lib/
├── features/
│   ├── teacher/
│   │   └── sub_features/
│   │       ├── attendance/
│   │       │   ├── widgets/
│   │       │   │   ├── teacher_attendance_tab.dart          <-- Move Save Button to Top Header
│   │       │   │   ├── attendance_roster_table.dart         <-- Redesigned Table (Replaces Boxed Cards)
│   │       │   │   ├── attendance_history_analytics_view.dart<-- Eliminate SnackBars, add RFID indicators
│   │       │   │   └── rfid_assignment_modal.dart           <-- NEW: Dual USB/NFC Assignment Dialog
│   │       ├── class_management/
│   │       │   └── widgets/
│   │       │       └── teacher_student_management_tab.dart  <-- Add "Assign RFID" Action Button
│   ├── student/
│   │   └── sub_features/
│   │       └── schedule/
│   │           └── screens/
│   │               └── student_attendance_screen.dart       <-- Polished Empty State, RFID Badge, No SnackBars
│   └── parent/
│       └── sub_features/
│           └── child_details/
│               └── widgets/
│                   └── parent_attendance_tab.dart           <-- Polished Empty State, RFID Badge, Child KPIs
└── shared/
    └── widgets/
        ├── empty_states/
        │   └── app_empty_state.dart                         <-- Unified 60-30-10 Empty State Component
        └── badges/
            └── attendance_source_badge.dart                 <-- Explicit "RFID" vs "Manual" Badge
```

---

### 4.2 R5: Redesigned Attendance Table Specification

#### A. Persistent Top Action Header Layout
Relocate "Save Attendance" from bottom of roster into the top controls card:
- **Left Cluster**: Class & Section dropdowns, Date picker navigator with `< Today >` quick-select.
- **Center Cluster**: Gender filter segmented button:
  - `[ All (45) ]` | `[ Male (22) ]` | `[ Female (23) ]`
- **Right Cluster**:
  - `Save Attendance` Primary Button (`AppButton.primary`, icon: `LucideIcons.save`, badge: `Unsaved Changes` indicator when dirty).
  - Quick action menu / batch buttons: `Mark All Present`, `Auto-Absent Unmarked`.

#### B. Unified Compact Roster Table Columns
Replace isolated boxed cards (`Container`) with a responsive `Table` or structured data grid:
- **Col 1 (Width 36px)**: `#` (Sequential Index: 1, 2, 3...)
- **Col 2 (Width 110px)**: `LRN` (Monospace, subtle grey text: `109283746501`)
- **Col 3 (Flex 3)**: `Student Name` (Bold, formatted as `Last, First Middle Initial.` — e.g. `Alcantara, Marcus D.`). **NO circular avatar / initials badge**.
- **Col 4 (Width 110px)**: `RFID Card` (Chip indicator showing `Assigned (04:A2:3B)` in Teal or `Unassigned` in Grey outline with tap-to-assign).
- **Col 5 (Width 220px)**: `Attendance Toggle Action`:
  - 4 compact segmented buttons:
    - `P` (Present - `catGreen`)
    - `L` (Late - `catOrange`)
    - `A` (Absent - `catRed`)
    - `E` (Excused - `catSlate`)
  - Active button highlights with solid semantic color + white text; inactive buttons have subtle outline.
- **Col 6 (Flex 2)**: `Remarks / Scan Time` (e.g. *"RFID Tap 07:42 AM"* or editable quick remark note).

---

### 4.3 R2: RFID Assignment Modal Specification

#### Dialog Architecture (`rfid_assignment_modal.dart`)
- **Header**:
  - Icon: `LucideIcons.creditCard` or `LucideIcons.radio` in Steel Blue (`0xFF487898`).
  - Title: *"Assign RFID Card"*.
  - Subtitle: *"Link a physical RFID card to [Student Name] (LRN: [LRN])"*.
- **Input Mode Selector (Tabs / Segmented Control)**:
  - `Tab 1: USB / Keyboard Scanner (Desktop/Laptop)`
  - `Tab 2: Phone NFC Tap (Mobile App)`
- **Tab 1: USB Scanner View**:
  - Auto-focused input field with outline border.
  - Helper copy: *"Tap student card on the USB scanner now. The card UID will register automatically."*
  - Animated scanner pulse icon with blinking cursor.
  - Manual entry override: allows teacher to type 8–14 character UID.
  - Validation: Inline error with red border (`0xFFDC2626`) if format invalid.
- **Tab 2: Phone NFC Tap View**:
  - NFC status check: If NFC disabled on phone, shows inline warning: *"NFC is turned off. Please enable NFC in your phone settings."* with button to open system settings.
  - Animated concentric radio wave illustration.
  - Status text: *"Ready to scan. Hold the card against the back of your phone."*
- **Conflict Resolution Modal**:
  - If backend reports UID already assigned:
    - Modal dialog title: *"RFID Card Conflict"*.
    - Message: *"Card UID [UID] is already registered to [Other Student Name] in [Grade/Section]. Would you like to transfer this card to [Current Student]?"*
    - Actions: `Cancel` (Grey) vs `Transfer & Assign` (`AppTheme.catOrange`).

---

### 4.4 R7: Error Presentation Replacement Matrix

| Context | Trigger / Scenario | Old Presentation | Proposed New Presentation (R7 Standard) | Exact User-Facing Message |
|---|---|---|---|---|
| **RFID Assignment** | Invalid UID characters or length (< 4 or non-hex) | None / unhandled | **Inline Input Error** (Red border `0xFFDC2626` + 12px helper text under field) | *"Please enter a valid card UID (minimum 4 hexadecimal characters)."* |
| **RFID Assignment** | Duplicate card already assigned to another student | ScaffoldMessenger / raw DB error code 23505 | **Modal Dialog** (`AppModals.showConfirmationDialog`) | *"This card is currently assigned to [Student Name]. Reassign this card to [New Student]?"* |
| **RFID Assignment** | NFC sensor unavailable or disabled on mobile device | None / crash | **Modal Alert** (`AppModals.showErrorDialog`) | *"NFC is not supported or currently disabled on this device. Please enable NFC in settings or use USB scanner input."* |
| **RFID Assignment** | Card read timeout / scanner communication failed | Unhandled / silent failure | **Modal Alert** (`AppModals.showErrorDialog`) with Retry | *"The card could not be read. Please reposition the card against the scanner and try again."* |
| **Live Attendance** | Unregistered card tapped on scanner | `ScaffoldMessenger` floating SnackBar (line 572) | **Modal Alert** (`AppModals.showErrorDialog`) with option to assign | *"Card [UID] is not registered to any student in the system. Would you like to assign this card now?"* |
| **Live Attendance** | Student from a different section/grade tapped | `ScaffoldMessenger` floating SnackBar (line 572) | **Modal Alert** (`AppModals.showErrorDialog`) | *"[Student Name] is enrolled in [Section X], not in this class session. Attendance was not recorded."* |
| **Live Attendance** | Duplicate scan by same student in same class session | Overwrites or redundant toast | **Silent Idempotent Ignore** + subtle UI pulse on existing row | No error modal; existing row flashes green with tooltip: *"Already recorded at [Timestamp]."* |
| **Schedule Guard** | Scanning outside scheduled class hours (too early / late) | None / allowed | **Modal Alert** (`AppModals.showErrorDialog`) | *"Attendance is locked. [Subject] is scheduled for [Start Time] - [End Time]. Scans outside this window are rejected."* |
| **Schedule Guard** | Scanning on non-scheduled day / weekend / holiday | None / allowed | **Modal Alert** (`AppModals.showErrorDialog`) | *"No class schedule found for this subject on [Date]. Attendance cannot be recorded today."* |
| **Batch Save** | Network failure or timeout while saving attendance | `ScaffoldMessenger` with `$e` (line 508) | **Modal Alert** (`AppModals.showErrorDialog`) + automatic local offline fallback badge | *"Unable to connect to the server. Your attendance marks have been saved locally and will automatically sync once online."* |

---

### 4.5 R6: Multi-Platform Analytics & Empty States Specification

#### A. Teacher History & Analytics View
- **KPI Summary Cards (30% Card Surface)**:
  - Total Presence Rate: `[Rate]%` (Color: `catGreen`).
  - Total Absences & Excuses: `[Count]` (Color: `catRed`).
  - Attendance Warnings: `[Count]` (Students with >= 3 absences; Color: `catOrange`).
- **Date Presets**: `This week` | `This month` | `Custom Range` (with inline date pickers).
- **Interactive Trend Chart**: Custom-painted bar/line graph of daily present vs absent/excused counts.
- **Drill-down At-Risk List**: Table showing flagged students with >= 3 absences, showing total absences and contact parent action.
- **Activity Log**: Chronological table displaying Date, Student Name, Status badge, and **explicit Source badge (`RFID` or `Manual`)**.

#### B. Student App View-Only Screen (`student_attendance_screen.dart`)
- Centered within `_mobileFrame` (max width 520px).
- Summary bar: `Present Count`, `Total School Days`, `Personal Attendance Rate (%)`.
- **Source Indicator**: Every attendance card displays a badge:
  - `RFID`: Teal chip with `LucideIcons.radio`.
  - `Manual`: Slate chip with `LucideIcons.edit3`.
- **Polished Empty State (`AppEmptyState`)**:
  - Icon: `LucideIcons.calendarCheck2` in primary accent color.
  - Headline: *"No Attendance Records Yet"*.
  - Body: *"Your daily attendance logs recorded by your teacher or through RFID tapping will appear here in real time."*
  - Action: Refresh button.

#### C. Parent App View-Only Screen (`parent_attendance_tab.dart`)
- Linked Child Selector dropdown/switcher bar.
- Summary bar: `Present`, `Late`, `Absent`, `Rate (%)`.
- Chronological logs list with Date, Time-in, Subject, Status badge, and **Source indicator badge (`RFID` / `Manual`)**.
- **Polished Empty State**:
  - Icon: `LucideIcons.graduationCap`.
  - Headline: *"No Attendance Logs Found"*.
  - Body: *"No attendance entries have been recorded yet for [Child Name]. Check back once class attendance is submitted."*
  - Action: Refresh button.

---

## 5. Verification Method

To independently verify the observations, line citations, and UI architectural findings:

1. **Verify Roster Boxed Cards & Circular Avatars**:
   - Inspect `lib/features/teacher/sub_features/attendance/widgets/attendance_roster_list.dart`:
     - Line 416: Check `Container` card layout.
     - Line 438: Confirm `CircleAvatar` presence.
     - Line 266: Confirm static gender section rendering without filter tabs.
2. **Verify Save Attendance Button Position**:
   - Inspect `lib/features/teacher/sub_features/attendance/widgets/teacher_attendance_tab.dart`:
     - Line 950: Confirm button is located at the very bottom of the roster column.
3. **Verify SnackBar & ScaffoldMessenger Violations**:
   - Run grep in terminal:
     ```powershell
     rg -n "showSnackBar" lib/features/teacher/sub_features/attendance
     rg -n "showSnackBar" lib/features/student
     rg -n "showSnackBar" lib/features/parent
     ```
   - Confirm all 7 occurrences in `teacher_attendance_tab.dart` and `attendance_history_analytics_view.dart`.
4. **Verify 60-30-10 Palette Architecture**:
   - Inspect `lib/core/theme/app_theme.dart` lines 14–25 to verify `_lightBg`, `_lightSurface`, `_lightCard`, and `_lightAccent`.
5. **Verify Drift SQLite and Existing Dependencies**:
   - Inspect `pubspec.yaml` lines 56–57 for `drift: ^2.24.0` and line 41 for `lucide_icons_flutter: ^3.1.20`.
   - Confirm absence of `nfc_manager` in `pubspec.yaml`.
6. **Project Test Execution**:
   - Run the flutter test suite:
     ```powershell
     flutter test
     ```
   - Invalidation conditions: If any file cited above does not exist or line ranges shift drastically, re-run `grep_search` to verify line bounds.
