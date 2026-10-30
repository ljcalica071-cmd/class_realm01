# System-Wide Caching & Real-Data Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide an instant (0ms blocking latency), cross-platform (Web + App) caching architecture with Stale-While-Revalidate (SWR), TTL cooldown, and mutation invalidation across all features, eliminate all mock/hardcoded grades, and standardize skeleton/staggered loading.

**Architecture:** 
1. Upgrade `AppDataCache` to be the single source of truth for both in-memory and `LocalStorageService` disk cache with TTL freshness tracking, in-flight deduplication, and payload diffing.
2. Integrate `AppDataCache` into repository queries (`SubjectRepository`, `SupabaseStudentRepository`, `SupabaseParentRepository`, `SupabaseTeacherClassworkRepository`, `StudentDashboardRepository`, `AdminRepository`).
3. Connect write mutations and Supabase Realtime to prefix-based cache invalidation (`invalidatePrefix`).
4. Replace hardcoded mock grades in `TeacherGradesTab` with real DepEd gradebook values or empty/pending state ("—") when no grades are recorded.
5. Standardize skeleton shimmer loading (`ShimmerLoading`, `ShimmerManagementTable`) and staggered animations (`StaggeredEntrance`) on empty states.

**Tech Stack:** Flutter, Dart, Supabase Flutter, SharedPreferences (`LocalStorageService`), AppLifecycleCoordinator.

---

## Global Constraints
- Must function identically on Flutter Web and Native platforms (Mobile / Desktop).
- Zero mock or fake data: if no records exist in the database, screens must show empty/pending states, never placeholder numbers like `85.0`.
- Do not use blocking loading spinners for tab transitions; use `StaggeredEntrance` and skeleton shimmer loading when initial data is absent.
- Preserves offline resilience and privacy: caches must be purged on logout via `AppDataCache.instance.clearAll()`.

## Review Focus
1. Switching tabs back and forth (e.g. Dashboard -> Students -> Dashboard) within TTL must NOT fire network requests to Supabase.
2. In-flight request deduplication prevents concurrent identical calls when switching rapidly.
3. Mutations (adding, editing, deleting, or grading) must immediately invalidate the relevant cache prefix so fresh data appears.
4. If a student has no grades recorded in `gradebook_term_sheets`, `TeacherGradesTab` must show "—" / "Pending", not "85.0".
5. Flutter Web must use `LocalStorageService` + Memory via `AppDataCache` instead of failing on SQLite Drift workers.

---

### Task 1: Purge Hardcoded Mock Grades in `TeacherGradesTab`

**Files:**
- Modify: `lib/features/teacher/sub_features/grading/widgets/teacher_grades_tab.dart`
- Test: `test/features/teacher/grading/teacher_grades_tab_test.dart`

**Interfaces:**
- Consumes: `UserModel` student list, real DepEd computed grades or null.
- Produces: Clean grade rendering showing real computed quarterly grade or "—" (No Grade Recorded).

- [ ] **Step 1: Write widget test verifying empty/pending grade state**
  Verify that when students have no recorded grades in the gradebook, the grade cell displays "—" and remarks display "Pending" / "No Grade" rather than hardcoded "85.0" or "Passed".

- [ ] **Step 2: Run test to verify it fails**
  Run: `flutter test test/features/teacher/grading/teacher_grades_tab_test.dart`
  Expected: FAIL (currently hardcodes `85.0`).

- [ ] **Step 3: Refactor `teacher_grades_tab.dart` to eliminate mock `85.0`**
  Remove `double _quarterlyGradeFor(String studentId) => 85.0;`. Replace with nullable computation `double? _quarterlyGradeFor(String studentId)` that inspects actual recorded scores or returns `null`. Render `"Pending"` / `"—"` with muted styling when `null`.

- [ ] **Step 4: Run test to verify it passes**
  Run: `flutter test test/features/teacher/grading/teacher_grades_tab_test.dart`
  Expected: PASS.

---

### Task 2: Upgrade `AppDataCache` with TTL Cooldown, SWR, In-Flight Deduplication, and Lifecycle Hooks

**Files:**
- Modify: `lib/core/services/app_data_cache.dart`
- Test: `test/core/services/app_data_cache_test.dart`

**Interfaces:**
- Produces:
  ```dart
  Future<T> fetchWithSvr<T>({
    required String cacheKey,
    required Future<T> Function() fetcher,
    required void Function(T data) onUpdate,
    T Function(dynamic json)? fromJson,
    dynamic Function(T data)? toJson,
    Duration ttl = const Duration(minutes: 5),
    bool forceRefresh = false,
  });
  void invalidatePrefix(String prefix);
  bool isFresh(String key);
  ```

- [ ] **Step 1: Write unit tests for `AppDataCache` TTL, deduplication, and prefix invalidation**
  Test cases:
  1. Instant return of cached memory data.
  2. Within TTL, second call skips network fetcher.
  3. When `forceRefresh: true` or `invalidatePrefix()` called, fetcher is executed.
  4. Deduplication: 2 concurrent calls only trigger 1 network future.

- [ ] **Step 2: Run test to verify it fails**
  Run: `flutter test test/core/services/app_data_cache_test.dart`
  Expected: FAIL.

- [ ] **Step 3: Implement TTL tracking, deduplication, and prefix invalidation in `AppDataCache`**
  - Add `_cacheTimestamps = <String, DateTime>{}` and `_inFlightFutures = <String, Future<dynamic>>{}`.
  - Implement `invalidatePrefix(String prefix)` to remove matching keys from both memory and timestamps.
  - In `fetchWithSvr`, if data exists and `DateTime.now().difference(timestamp) < ttl` and `!forceRefresh`, return cached data immediately and skip network call.
  - Compare payload hashes/JSON strings before triggering `onUpdate` to avoid unnecessary widget rebuilds.

- [ ] **Step 4: Run test to verify it passes**
  Run: `flutter test test/core/services/app_data_cache_test.dart`
  Expected: PASS.

---

### Task 3: Integrate Caching in Teacher Repositories (`SubjectRepository`, `SupabaseStudentRepository`, `SupabaseTeacherClassworkRepository`)

**Files:**
- Modify: `lib/data/repositories/subject_repository.dart`
- Modify: `lib/data/repositories/supabase_student_repository.dart`
- Modify: `lib/data/repositories/supabase_teacher_classwork_repository.dart`
- Test: `test/data/repositories/cached_repositories_test.dart`

**Interfaces:**
- Consumes: `AppDataCache.instance.fetchWithSvr`, Supabase Client.
- Produces: Cached `getTeacherSubjects`, `getStudentsForTeacher`, and `getActivities` with automatic write-through cache invalidation.

- [ ] **Step 1: Write tests for repository caching and invalidation**
  Verify `getTeacherSubjects` returns cached list on second invocation without querying Supabase, and invalidates when a new subject offering is saved.

- [ ] **Step 2: Run test to verify it fails**
  Run: `flutter test test/data/repositories/cached_repositories_test.dart`
  Expected: FAIL.

- [ ] **Step 3: Apply caching and invalidation in repositories**
  - In `SubjectRepository.getTeacherSubjects()`: wrap with `AppDataCache.instance.fetchWithSvr` (key: `'teacher_subjects_${teacherId}'`, TTL: 5 min).
  - In `SupabaseStudentRepository.getStudentsForTeacher()`: wrap with `AppDataCache` (key: `'teacher_students_${teacherId}_${includeArchived}'`, TTL: 5 min). Invalidate on `enrollStudent()`, `updateStudent()`, `archiveStudent()`.
  - In `SupabaseTeacherClassworkRepository.getActivities()`: wrap with `AppDataCache` (key: `'teacher_activities_${teacherId}'`, TTL: 5 min). Invalidate on `createActivity()`, `updateActivity()`, `deleteActivity()`.

- [ ] **Step 4: Run test to verify it passes**
  Run: `flutter test test/data/repositories/cached_repositories_test.dart`
  Expected: PASS.

---

### Task 4: Integrate Caching & Skeleton Shimmer in Teacher Tabs (`TeacherStudentManagementTab`, `TeacherDashboardOverviewTab`)

**Files:**
- Modify: `lib/features/teacher/sub_features/class_management/widgets/teacher_student_management_tab.dart`
- Modify: `lib/features/teacher/screens/teacher_dashboard_screen.dart`
- Modify: `lib/features/teacher/sub_features/overview/widgets/teacher_dashboard_overview_tab.dart`

**Interfaces:**
- Consumes: Cached repositories from Task 3.
- Produces: Seamless tab switching with 0ms blank screens; initial load displays `ShimmerManagementTable` only if local cache is completely empty.

- [ ] **Step 1: Wire synchronous cache hydration in `TeacherStudentManagementTab.initState`**
  Before `_loadData()` triggers, synchronously check if cached students and subjects exist in `AppDataCache` and populate `_activeStudents`, `_teacherSubjects`, and `_teacherSections` immediately on Frame 1.

- [ ] **Step 2: Wire synchronous cache in `TeacherDashboardScreen` for students and parents**
  In `_loadData()`, read from `AppDataCache` synchronously so overview widgets have student counts and classwork ready instantly without waiting for network response.

- [ ] **Step 3: Verify tab switching latency**
  Switching between Dashboard -> Manage Students -> Classwork -> Dashboard renders immediately with zero loading spinners and preserves scroll/filter positions.

---

### Task 5: Cross-Platform Student & Admin Caching (Web + Native Parity)

**Files:**
- Modify: `lib/data/repositories/student_dashboard_repository.dart`
- Modify: `lib/data/repositories/admin_repository.dart`
- Modify: `lib/core/services/app_lifecycle_coordinator.dart`

**Interfaces:**
- Consumes: `AppDataCache` across platforms.
- Produces: Fast Web dashboard loading for Students and fast Admin tab switches without relying on native-only Drift SQLite.

- [ ] **Step 1: Update `StudentDashboardRepository` with Web-safe `AppDataCache` fallback**
  Replace the failing `AppDatabase.instance.getSetting` on Web with `AppDataCache.instance.fetchWithSvr`, delivering instant dashboard rendering on both Web and Mobile.

- [ ] **Step 2: Update `AdminRepository` to cache Teacher Management & Broadcasts**
  Wrap `getTeachers` and `getTeacherWorkloadSummaries` in `AppDataCache` with 5-minute TTL.

- [ ] **Step 3: Connect `AppLifecycleCoordinator.onResume()` for silent delta revalidation**
  When returning from background or browser tab switch, mark dirty caches for background delta refresh without blocking UI interaction.

---

### Task 6: Final Verification & Test Suite Execution

- [ ] **Step 1: Run all Flutter unit and widget tests**
  Command: `flutter test`
  Expected: All tests pass.

- [ ] **Step 2: Manual Smoke Test Verification**
  - Verify Teacher portal navigation between all tabs: 0 network wait on repeated clicks.
  - Verify Grade tab: No fake 85.0 grades displayed; displays real/pending state.
  - Verify Student portal on Web: instant dashboard hydration from local cache.

