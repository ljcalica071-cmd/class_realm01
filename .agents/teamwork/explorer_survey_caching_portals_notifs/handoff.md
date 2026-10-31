# Architectural Exploration & Survey Report: Requirements R5 & R6

- **Working Directory**: `c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_survey_caching_portals_notifs`
- **Date**: 2026-10-30
- **Scope**:
  - **Requirement R5**: Performance Caching, Responsiveness, and Visual Hierarchy (Classroom Setup, Gradebook, Manage Students, Manage Parents, Learning Materials, My Schedule; Layout Viewport Adaptivity; 60-30-10 Color Rule).
  - **Requirement R6**: Student & Parent Portals and Multi-Tier Absence Push Notifications (Attendance History & Schedule in Student/Parent Portals; Push Notification Architecture & FCM; Automated 3/5/10-Absence Multi-Tier Alerts).

---

## 1. Observations

### 1.1 Slower Modules & Caching Architecture (R5)

#### 1. Classroom Setup
- **File**: `lib/features/teacher/sub_features/setup/widgets/teacher_classroom_setup_tab.dart`
- **Lines Observed**:
  - Line 138: `bool _isLoadingSubjects = false;`
  - Line 150: In `initState()`, `_loadSubjects();` is invoked immediately.
  - Line 2210: `setState(() => _isLoadingSubjects = true);`
  - Line 480–497: While `_isLoadingSubjects == true`, the entire tab displays a 4-item grid of `ShimmerTeacherSubjectCard`:
    ```dart
    _isLoadingSubjects
        ? LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 950 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 340,
                ),
                itemCount: 4,
                itemBuilder: (_, _) => const ShimmerTeacherSubjectCard(),
              );
            },
          )
        : _viewMode == _ClassroomViewMode.archivedSubjects
        ...
    ```
  - Lines 2213–2230: `_loadSubjects()` executes:
    ```dart
    final activeRows = await SubjectRepository.instance.getTeacherSubjects(teacherId, schoolYear: _currentSchoolYear);
    final archivedRows = await SubjectRepository.instance.getTeacherArchivedSubjects(teacherId, schoolYear: _currentSchoolYear);
    final archivedSectionRows = await SubjectRepository.instance.getTeacherArchivedSections(teacherId, schoolYear: _currentSchoolYear);
    final activeStudentCounts = await SubjectRepository.instance.getOfferingStudentCounts(activeIds);
    ```
- **Repository Observation** (`lib/data/repositories/subject_repository.dart`):
  - `getTeacherSubjects` (lines 221–231) has `AppDataCache` and Drift SQLite local cache integration.
  - However, `getTeacherArchivedSubjects` (lines 672–723), `getTeacherArchivedSections` (lines 726–760), and `getOfferingStudentCounts` perform un-cached direct Supabase network queries (`await _client.from('subject_offerings').select(...)`) on every mount!
  - Because `TeacherClassroomSetupTab` does not pre-seed `_subjects` from memory or `AppDataCache` synchronously, the user is subjected to flashing shimmer cards on every tab revisit.

#### 2. Gradebook
- **File**: `lib/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart`
- **Lines Observed**:
  - Line 32: `bool _isLoadingSubjects = true;`
  - Line 64: In `initState()`, `_fetchSubjects();` is called.
  - Lines 77–110: `_fetchSubjects()` awaits `SubjectRepository.instance.getTeacherSubjects(...)`, and only clears `_isLoadingSubjects = false;` asynchronously.
  - Line 712:
    ```dart
    child: (_isLoadingSubjects || (_isLoadingStudents && _students.isEmpty))
        ? _buildGradebookSkeleton(theme, isDark, borderColor)
        : Stack(...)
    ```
  - In `SubjectRepository` (lines 211–213), `getCachedTeacherSubjects(teacherId)` is available synchronously via `LocalStorageService.getTeacherSubjects(teacherId)`, but `_TeacherGradebookTabState` never invokes it to pre-populate `_teacherSubjects` on Frame 1.
  - Each time the teacher switches from Gradebook to another tab and returns, the state resets and renders `_buildGradebookSkeleton(...)`.

#### 3. Manage Students
- **File**: `lib/features/teacher/sub_features/class_management/widgets/teacher_student_management_tab.dart`
- **Lines Observed**:
  - Line 31: `bool _isLoading = true;`
  - Lines 77, 82–109: `_hydrateFromCache()` is implemented and checks `AppDataCache.instance.getCached<List<UserModel>>('teacher_students_${teacherId}_all_false', ...)`. If found, `_activeStudents = cachedActive;` and `_isLoading = false;` are set immediately.
  - Lines 170–178: `_loadData()` is invoked in `initState()`, and checks `if (_activeStudents.isEmpty && _archivedStudents.isEmpty)` before asserting `_isLoading = true;`.
  - While client-side caching works when the cache is populated, initial cache keys must strictly match `SupabaseStudentRepository.getStudentsForTeacher` (`'teacher_students_${teacherId}_all_false'`).

#### 4. Manage Parents
- **File**: `lib/features/teacher/sub_features/class_management/widgets/teacher_parent_management_tab.dart`
- **Lines Observed**:
  - Line 22: `final List<UserModel>? parents;` is received via constructor from `TeacherDashboardScreen` (line 765: `TeacherParentManagementTab(parents: parents)`).
  - Line 34: `bool _isLoading = true;`
  - Lines 86–118: `_hydrateFromCache()` checks:
    ```dart
    final cachedActive = AppDataCache.instance.get<List<UserModel>>('teacher_parents_${teacherId}_all_false');
    ```
    Notice that it uses `.get<List<UserModel>>()`. In `SupabaseParentRepository` (lines 43–48), caching is executed through `AppDataCache.instance.fetchWithSvr` which stores raw JSON maps via `setCache()`. Therefore, `.get<List<UserModel>>()` fails to cast and returns `null`!
  - Furthermore, `_hydrateFromCache()` completely ignores `widget.parents`! It only references `widget.parents` in `_loadData()` (lines 180 and 242) as a failure fallback after a network error!
  - Consequently, `_isLoading` remains `true` and the table shows `ShimmerManagementTable(rowCount: 8)` (lines 685–688) every time the teacher navigates to Manage Parents.

#### 5. Learning Materials
- **File**: `lib/features/teacher/sub_features/schedule_and_lessons/widgets/teacher_learning_materials_tab.dart`
- **Lines Observed**:
  - Line 31: `bool _isLoading = true;`
  - Line 70: `_loadTeacherClasses();` is called in `initState()`.
  - Lines 140–200: Sets `_isLoading = true;`, awaits `_subjectRepo.getTeacherSubjects(...)`, and calls `_loadFolderContents()`.
  - Lines 202–245: Sets `_isLoading = true;` again, calls:
    - `_materialRepo.ensureDefaultTermFolders(offeringId)`
    - `_materialRepo.getFolders(...)`
    - `_materialRepo.getArchivedFolders(offeringId)`
    - `_materialRepo.getArchivedMaterials(offeringId)`
- **Repository Observation** (`lib/data/repositories/supabase_learning_material_repository.dart`):
  - Lines 17–95: `ensureDefaultTermFolders`, `getFolders`, `getMaterials`, `getArchivedFolders`, and `getArchivedMaterials` contain ZERO caching (no `AppDataCache`, no `LocalStorageService`, no in-memory cache). Every single folder open and screen revisit runs 4–5 consecutive network queries against Supabase.

#### 6. My Schedule
- **File**: `lib/features/teacher/sub_features/schedule_and_lessons/widgets/teacher_schedule_tab.dart`
- **Lines Observed**:
  - Line 22: `bool _isLoading = true;`
  - Line 32: `_loadData();` is called in `initState()`.
  - Lines 35–56:
    ```dart
    final results = await Future.wait([
      _repo.getSchedules(teacherId: teacherId),
      SubjectRepository.instance.getTeacherSubjects(teacherId),
    ]);
    ```
- **Repository Observation** (`lib/data/repositories/supabase_schedule_repository.dart`):
  - Lines 150–225: `getSchedules({String? teacherId, String? section})` does not check Drift SQLite or `AppDataCache`. It performs an un-cached query:
    ```dart
    var query = _client.from('teacher_schedule').select('''...''');
    ```
  - Navigating to My Schedule blocks the screen behind `_isLoading = true;` every time.

#### 7. Dashboard Tab Lifecycle Architecture
- **File**: `lib/features/teacher/screens/teacher_dashboard_screen.dart`
- **Lines Observed**:
  - Lines 505–521, 710–775: The body widget is rendered inside `Expanded` with a plain `switch (_selectedIndex)`:
    ```dart
    Expanded(
      child: Container(
        color: Colors.transparent,
        child: StaggeredEntrance(
          key: ValueKey(_selectedIndex),
          index: 0,
          duration: const Duration(milliseconds: 280),
          child: _buildTeacherBodyContent(...),
        ),
      ),
    ),
    ```
  - Because `IndexedStack` or cached page views are not used, switching tabs disposes the previous tab completely and creates the new tab's `State` from scratch. Without synchronous cache pre-seeding, every tab flashes a loading indicator.

---

### 1.2 Layout Responsiveness & Visual Hierarchy (R5)

#### 1. Viewport Adaptivity & Overflow Risks
- **Classroom Setup (`TeacherClassroomSetupTab`)**:
  - Grid: Line 483 uses `final crossAxisCount = constraints.maxWidth >= 950 ? 2 : 1;` with fixed card height `mainAxisExtent: 340`.
  - Form Fields: Lines 1834, 1862, 1891 use `constraints.maxWidth < 650` to adaptively switch from `Row` with `Expanded` to `Column` stacking.
  - Dialogs: Lines 187–213 implement `_showConstrainedDialog` with `maxWidth: 460`, preventing horizontally stretched dialogs on desktop monitors.
- **Gradebook Table (`TeacherGradebookTab`)**:
  - Horizontal scroll setup: Lines 900–912 wrap the right columns in `Scrollbar` + `SingleChildScrollView(scrollDirection: Axis.horizontal)`.
  - **Severe Bug Discovered (Duplicate Keys & Filtering Crash)**:
    - Lines 835–859 render Male students under condition `_selectedGender == 'All' || _selectedGender == 'Male'`.
    - Immediately following at lines 860–877, `_buildGenderHeader('MALE', ...)` and `..._buildStudentRows(_visibleMaleStudents, ...)` are executed a SECOND time unconditionally outside any gender check!
    - Lines 878–895 then render `_buildGenderHeader('FEMALE', ...)`.
    - On the right scrollable side, lines 952–1005 render conditional male and female rows, followed immediately at lines 1006–1018 by redundant unconditional male rows!
    - **Exact Error**:
      `Duplicate keys found. Column(direction: vertical...) has multiple children with key [gradebook-row-zV0ZGShD46TGOcXrfsLIX1Jd45j2-true]`
    - This copy-paste duplication causes assertion errors and renders `# LEARNERS NAMES` and duplicate rows horizontally and vertically.
- **Manage Parents Table Header Overflow (`TeacherParentManagementTab`)**:
  - Lines 380–394 define column widths:
    `colCheckWidth = 44.0`, `colNumWidth = 48.0`, `colNameWidth = 240.0`, `colRelWidth = 130.0`, `colStudentWidth = 240.0`, `colSectionWidth = 140.0`, `colStatusWidth = 140.0`, `colActionsWidth = 180.0`.
  - Line 901: `SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: scrollableColsWidth, ...))` does not attach a synchronized horizontal scroll controller, causing visual misalignment and overflow stripes across web and desktop touch pads.
  - Column Configuration: Line 740 contains the Checkbox column adjacent to `#`, line 941 has `SECTION` instead of `BIRTHDAY`, and line 465 provides `'— All Subjects —'` in the subject filter dropdown.

#### 2. Visual Hierarchy & 60-30-10 Rule Compliance
- **Theme Definition** (`lib/core/theme/app_theme.dart`):
  - **60% Dominant Background**:
    - Light: `_lightBg = Color(0xFFF5F5F5)` (warm off-white)
    - Dark: `_darkBg = Color(0xFF111827)` (dark slate)
  - **30% Structural Surface**:
    - Light: `_lightSurface = Color(0xFFE8EBE2)` (warm sage) / `_lightCard = Color(0xFFFFFFFF)`
    - Dark: `_darkSurface = Color(0xFF1F2937)` / `_darkCard = Color(0xFF263040)`
  - **10% Intentional Accent**:
    - Light: `_lightAccent = Color(0xFF487898)` (steel blue)
    - Dark: `_darkAccent = Color(0xFF60A5FA)` (sky blue)
  - **Categorical Accent Indicators** (DepEd standard):
    - Written Works / Info: `catBlue` (`#2563EB`)
    - Performance Tasks / Present: `catGreen` (`#16A34A`)
    - Summative Tests: `catPurple` (`#7C3AED`)
    - Quarterly Exam / Late: `catOrange` (`#D97706`)
    - Absent / Critical Warnings: `catRed` (`#DC2626`)
    - RFID / Sync: `catTeal` (`#0D9488`)

---

### 1.3 Student & Parent Portals (R6)

#### 1. Student Portal Views
- **Home**: `lib/features/student/screens/student_home_screen.dart`
  - Lines 125–146: Bottom navigation bar hosts Home, Written Works, Exams, Alerts (`StudentNotificationsTab`), and Profile.
  - Lines 318–332: Navigation Drawer provides direct routes to:
    - `StudentAttendanceScreen` via `Icons.fact_check_outlined`
    - `StudentScheduleScreen` via `Icons.schedule_outlined`
- **Attendance History** (`lib/features/student/sub_features/schedule/screens/student_attendance_screen.dart`):
  - Lines 51–68: Calls `_repo.getMyAttendanceSummary()` and `_repo.getMyAttendancePage(offset: 0, pageSize: 20)`.
  - Lines 173–203: Displays 4 summary stat cards: Present, Late, Absent, Presence Rate %.
  - Lines 204–235: Displays an Early Warning Banner when cumulative absences reached:
    ```dart
    final showEarlyWarning = absentCount >= 3;
    ```
  - Lines 250–350: View-only paginated list displaying attendance date, status badge, recording method, and remarks.
- **My Schedule** (`lib/features/student/sub_features/schedule/screens/student_schedule_screen.dart`):
  - Lines 26–29: Queries `SupabaseScheduleRepository.instance.getSchedules(section: student.departmentOrSection)`.
  - Lines 20–25: Toggles between List view and Timetable Grid view.
  - Lines 41–120: Interactive class details modal showing subject, section, day, time, room, and teacher.

#### 2. Parent Portal Views
- **Home**: `lib/features/parent/screens/parent_home_screen.dart`
  - Lines 48–54: `SupabaseParentRepository.getLinkedStudentsForParent(parent.id)` loads linked children.
  - Lines 168–188: Child selector banner and tab content:
    - Tab 0: `ParentStudentOverviewTab`
    - Tab 1: `const ParentAttendanceTab(attendance: [])`
    - Tab 2: `ParentGradesTab`
    - Tab 3: `const ParentNotificationsTab()`
    - Tab 4: `ParentProfileTab`
- **CRITICAL DEFECT OBSERVED (Parent Attendance Blank)**:
  - Line 184 passes:
    ```dart
    const ParentAttendanceTab(attendance: []),
    ```
  - `ParentAttendanceTab` (`lib/features/parent/sub_features/child_details/widgets/parent_attendance_tab.dart`) is a `StatelessWidget` that accepts `final List<AttendanceRecord> attendance;`.
  - Because `attendance: []` is hardcoded with an empty list, and `ParentAttendanceTab` never queries the backend, the parent attendance screen is permanently empty!
  - `SupabaseAttendanceRepository.getAttendanceForStudent(studentId)` (line 2939) already exists in the codebase but was never connected to `ParentAttendanceTab`.
- **Child's Schedule** (`lib/features/parent/sub_features/child_details/widgets/parent_schedule_view.dart`):
  - Accessible via `ParentDrawer` (line 69: `ParentScheduleView(linkedStudent: linkedStudent)`).
  - Queries `SupabaseScheduleRepository.instance.getSchedules(section: linkedStudent.departmentOrSection)`.
  - Supports List and Timetable Grid view modes.

---

### 1.4 Push Notification Architecture & Multi-Tier Absence Triggers (R6)

#### 1. Push Notification Architecture (FCM & Supabase)
- **Firebase Configuration**:
  - `firebase.json` and `lib/firebase_options.dart` configure project `classrealm01`.
  - `firebase-service-account.json` exists in the project root (`firebase-adminsdk-fbsvc@classrealm01.iam.gserviceaccount.com`).
  - `.env` contains `FIREBASE_SERVICE_ACCOUNT_EMAIL`, `FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY`, and `FIREBASE_PROJECT_ID`.
- **OAuth2 Token Generator**:
  - `FirebaseAuthAdminService` in `lib/core/services/firebase_auth_admin_service.dart` (lines 300–394) implements pure-Dart RSA SHA-256 JWT minting to generate Google OAuth2 Access Tokens with scope `'https://www.googleapis.com/auth/cloud-platform'`.
  - This allows direct dispatching of FCM v1 push notifications via HTTP POST to:
    `https://fcm.googleapis.com/v1/projects/classrealm01/messages:send`
    without requiring third-party server-side daemons.
- **In-App Notification Database Tables** (`supabase/migrations/001_initial_schema.sql` lines 1585–1658 & `002_supabas.sql` lines 388–408):
  - `public.notifications`: `id`, `title`, `message`, `notification_type` (e.g. `'attendance'`), `target_audience`, `created_by`, `is_archived`, `created_at`.
  - `public.notification_recipients`: `notification_id`, `user_id`, `is_read`, `read_at`, `created_at`.
  - Realtime subscriptions already exist in `ParentNotificationsTab` (line 51: channel `'parent_notifications_realtime'`), `StudentNotificationsTab`, and `AdminBroadcastsTab`.

#### 2. Multi-Tier Absence Alert Triggers (3, 5, 10 Absences)
- **Attendance Save / Update Trigger Points**:
  - `SupabaseAttendanceRepository.saveAttendanceBatch` (`lib/data/repositories/supabase_attendance_repository.dart` line 735)
  - `SupabaseAttendanceRepository.correctAttendanceRecord` (line 2663)
  - `SupabaseAttendanceRepository.recordRfidScan` (line 1400)
- **Current State**:
  - `saveAttendanceBatch` saves records to `attendance_records` and Drift, but does NOT compute cumulative absences or dispatch push alerts.
  - `AttendanceAnalyticsCalculator.isAtRisk` (`lib/features/teacher/sub_features/attendance/utils/attendance_analytics_calculator.dart` line 14) checks `absentCount >= 3` for UI KPI badges, but no automated notification workflow is hooked to the database save.

---

## 2. Logic Chain

1. **Classroom Setup Shimmer Root Cause**:
   - `TeacherClassroomSetupTab` initiates `_isLoadingSubjects = true;` in `initState()` without checking `AppDataCache` or `LocalStorageService`.
   - While `SubjectRepository.getTeacherSubjects` uses cache, `getTeacherArchivedSubjects` and `getOfferingStudentCounts` do not.
   - Therefore, Classroom Setup always shows 4 shimmer placeholders when revisited. Pre-seeding data from `AppDataCache` on Frame 1 will enable 0ms instant display with silent background revalidation.

2. **Gradebook Blocking Skeleton Root Cause**:
   - `_TeacherGradebookTabState` initializes `_isLoadingSubjects = true;` and leaves `_teacherSubjects` empty.
   - Because line 712 renders `_buildGradebookSkeleton(...)` whenever `_isLoadingSubjects == true`, the table is blanked out on every tab switch.
   - Initializing `_teacherSubjects` from `SubjectRepository.instance.getCachedTeacherSubjects(teacherId)` eliminates this delay.

3. **Manage Parents Shimmer Root Cause**:
   - `TeacherParentManagementTab` receives `widget.parents` in its constructor, but its `initState()` and `_hydrateFromCache()` do not inspect `widget.parents`.
   - In addition, `_hydrateFromCache()` calls `AppDataCache.instance.get<List<UserModel>>` instead of `getCached` with `UserModel.fromJson`.
   - Checking `widget.parents` on Frame 1 allows immediate table rendering with 0ms delay.

4. **Learning Materials & Schedule Latency Root Cause**:
   - `SupabaseLearningMaterialRepository` and `SupabaseScheduleRepository.getSchedules` have no caching layer.
   - Adding `AppDataCache.instance.fetchWithSvr` caching to these repositories eliminates 4–5 sequential network calls on every tab visit.

5. **Gradebook Gender Filter Crash Root Cause**:
   - In `teacher_gradebook_tab.dart`, Male student rows and headers are duplicated at lines 860–877 and lines 1006–1018 outside the `_selectedGender` condition.
   - When filtering by 'Female', the code attempts to render female rows while simultaneously generating duplicate male rows with identical `ValueKey('gradebook-row-$studentId-true')`, throwing Flutter's duplicate key assertion crash. Removing the duplicated blocks resolves the crash.

6. **Parent Portal Attendance Disconnection**:
   - `ParentHomeScreen` passes `attendance: []` to `ParentAttendanceTab`.
   - `ParentAttendanceTab` is a `StatelessWidget` and does not fetch data itself.
   - Connecting `ParentAttendanceTab` to `SupabaseAttendanceRepository.instance.getAttendanceForStudent(linkedStudent.id)` solves the empty state.

7. **Push Notification Implementation Logic**:
   - In `saveAttendanceBatch` and `correctAttendanceRecord`, after upserting rows, identify students marked `absent`.
   - Query cumulative absence count for each student:
     `SELECT count(*) FROM attendance_records WHERE student_id = ? AND status = 'absent' AND subject_offering_id = ?`.
   - If cumulative count reaches exactly 3, 5, or 10:
     - Check dedup cache (to avoid duplicate triggers for the same milestone).
     - Query parent ID from `parent_student_links` and admin IDs from `users`.
     - Insert announcement into `public.notifications` and recipients into `public.notification_recipients`.
     - Generate OAuth2 access token via `FirebaseAuthAdminService._getAccessToken()` and post FCM push notification to topic `parent_${studentId}` and `admin_alerts`.

---

## 3. Caveats

1. **FCM Platform Specifics**:
   - On Android and iOS physical devices, receiving background push notifications when the application is terminated requires APNs certificates and Google Play Services configured on the target hardware. On Web, a service worker (`firebase-messaging-sw.js`) is needed.
   - In local debug/test mode without native push registration, in-app notifications dispatched through Supabase `notifications` and `notification_recipients` with Realtime subscriptions operate reliably across all platforms (web, mobile, desktop).
2. **Offline Absence Evaluation**:
   - When attendance is saved offline (Drift queue), absence counts can only be evaluated against locally synchronized records. Once network connectivity is restored and `syncOfflineAttendanceQueue()` runs, server-side absence threshold verification must re-check milestones before triggering notifications.
3. **Absence Scope Definition**:
   - In DepEd Senior High School, attendance is tracked per subject offering. The 3/5/10 thresholds are evaluated per subject offering. A cross-subject cumulative metric can be provided as a secondary summary.

---

## 4. Conclusions

1. **Performance Caching (R5)**:
   - Client-side caching is partially present in `AppDataCache`, but missing in `TeacherClassroomSetupTab`, `TeacherGradebookTab`, `TeacherParentManagementTab`, `SupabaseLearningMaterialRepository`, and `SupabaseScheduleRepository`.
   - Synchronous pre-seeding on Frame 1 in these 5 modules completely eliminates blocking spinners and shimmering cards when switching tabs.
2. **Layout & Crash Fixes (R5)**:
   - Gradebook duplicate key crash is caused by redundant lines 860–877 and lines 1006–1018 in `teacher_gradebook_tab.dart`.
   - Manage Parents table requires removing the Checkbox column, renaming `SECTION` to `BIRTHDAY`, removing `'— All Subjects —'`, and aligning scrollable column widths.
   - The 60-30-10 color rule is correctly structured in `AppTheme` and conforms to light and dark palettes.
3. **Portals (R6)**:
   - Student portal views (`StudentAttendanceScreen` and `StudentScheduleScreen`) are well-formed and functional.
   - Parent portal attendance is blank solely because `ParentHomeScreen` (line 184) passes an empty `attendance: []` list. Hooking it to `SupabaseAttendanceRepository.instance.getAttendanceForStudent(linkedStudent.id)` restores full functionality.
4. **Automated Multi-Tier Absence Notifications (R6)**:
   - Automated push notifications can be seamlessly integrated into `SupabaseAttendanceRepository.saveAttendanceBatch` and `correctAttendanceRecord`.
   - Triggers fire on exact cumulative counts (3 = Early Warning, 5 = Second Warning, 10 = Final Warning), saving in-app alerts to Supabase and dispatching push notifications via `FirebaseAuthAdminService` OAuth2 bearer tokens.

---

## 5. Verification Method

### 5.1 Verification Commands
To independently verify the affected targets and test suites:
```bash
# 1. Run theme & palette tests
flutter test test/core/theme/subject_palette_test.dart

# 2. Run Gradebook unit and widget tests
flutter test test/features/teacher/teacher_gradebook_tab_test.dart
flutter test test/features/teacher/gradebook_grid_cell_test.dart

# 3. Run Classroom Setup tests
flutter test test/features/teacher/teacher_classroom_setup_tab_test.dart

# 4. Run Learning Materials tests
flutter test test/features/teacher/learning_materials_test.dart

# 5. Run Attendance Repository & Analytics tests
flutter test test/data/repositories/supabase_attendance_repository_test.dart
flutter test test/features/teacher/attendance/attendance_analytics_calculator_test.dart
flutter test test/features/teacher/attendance/teacher_attendance_tab_test.dart

# 6. Run Student Portal Attendance tests
flutter test test/features/student/student_attendance_screen_test.dart
```

### 5.2 Files to Inspect
1. `lib/features/teacher/sub_features/setup/widgets/teacher_classroom_setup_tab.dart` (lines 138, 480–497, 2206–2310)
2. `lib/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart` (lines 32, 712, 835–895, 952–1020)
3. `lib/features/teacher/sub_features/class_management/widgets/teacher_parent_management_tab.dart` (lines 34, 86–118, 380–394, 740, 941)
4. `lib/features/teacher/sub_features/schedule_and_lessons/widgets/teacher_learning_materials_tab.dart` (lines 31, 202–245)
5. `lib/features/teacher/sub_features/schedule_and_lessons/widgets/teacher_schedule_tab.dart` (lines 22, 35–56)
6. `lib/features/parent/screens/parent_home_screen.dart` (line 184)
7. `lib/data/repositories/supabase_attendance_repository.dart` (lines 735–830, 2663–2696, 2939–2958)
8. `lib/core/services/firebase_auth_admin_service.dart` (lines 300–394)

### 5.3 Invalidation Conditions
- If `parent_student_links` has no matching parent record for a student, parent notifications must be skipped gracefully while still notifying admins.
- If attendance status is updated from `absent` to `present` via teacher correction, cumulative absences must decrement accordingly without triggering duplicate milestone alerts upon subsequent re-absence.
