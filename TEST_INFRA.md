# ClassRealm E2E Test Infrastructure & Test Suite Specification

## 1. Overview & Architectural Philosophy

The ClassRealm End-to-End (E2E) Test Suite provides requirement-driven, opaque-box verification across the six core functional areas (R1 through R6) defined in `ORIGINAL_REQUEST.md` and `PROJECT.md` §10 (Feature Inventory F1.1 through F6.3).

### Testing Principles
1. **Requirement-Driven & Opaque-Box**: Tests are derived strictly from user requirements, DepEd grading/attendance rules, and cross-module interface contracts, never internal implementation trivia or ephemeral UI flags.
2. **4-Tier Test Case Design**:
   - **Tier 1: Feature Coverage**: Comprehensive happy-path validation isolating each feature (minimum 5 tests per feature area).
   - **Tier 2: Boundary & Corner Cases**: Edge cases, empty rosters, zero/negative scores, maximum slot thresholds (10 columns), 11:59 PM cutoffs, and format extremes.
   - **Tier 3: Cross-Feature Combinations**: Pairwise and multi-state interactions (e.g. filter switching while cells are edited, pagination combined with searches, caching hydration across tab transitions).
   - **Tier 4: Real-World Scenarios**: Complete end-to-end user workflows representing realistic teacher grading, roster management, attendance scanning, audit inspections, and parent/student portal monitoring.
3. **Progressive Testability & Deterministic Isolation**: Each test is fully self-contained with mock/in-memory adapters and clean teardowns, preventing test order dependencies or side-effects.

---

## 2. Directory & File Organization

All E2E test suites reside in `test/e2e/` adhering to the project's Flutter test conventions:

```
test/e2e/
├── gradebook_e2e_test.dart            # R1: F1.1 to F1.4 (Columns, Expansion, Crashes, Filter Symmetry)
├── directory_management_e2e_test.dart # R2: F2.1 to F2.6 (Font Standard, Table Cleanliness, Birthday, Subjects)
├── attendance_rfid_e2e_test.dart      # R3: F3.1 to F3.6 (Typography, Lazy Load, Inline RFID, Action Buttons)
├── audit_history_logs_e2e_test.dart   # R4: F4.1 to F4.3 (20-Item Pagination, Full Names, Separate Columns)
├── caching_responsiveness_e2e_test.dart # R5: F5.1 to F5.3 (SWR Frame-1 Caching, Responsiveness, 60-30-10)
└── portals_notifications_e2e_test.dart  # R6: F6.1 to F6.3 (Student/Parent Portals, 3/5/10 Absence Alerts)
```

---

## 3. Feature Inventory Coverage Matrix

| Feature ID | Feature Description | Milestone | Target Test Suite | Tiers Covered |
|---|---|---|---|---|
| **F1.1** | 5-Slot Score Columns per Category | M1 | `gradebook_e2e_test.dart` | Tier 1, Tier 2, Tier 3, Tier 4 |
| **F1.2** | Inline '+' Score Column Expansion (up to 10) | M1 | `gradebook_e2e_test.dart` | Tier 1, Tier 2, Tier 3, Tier 4 |
| **F1.3** | Fix Duplicate Key Row Crash | M1 | `gradebook_e2e_test.dart` | Tier 1, Tier 2, Tier 3 |
| **F1.4** | Symmetrical Gender Filter & Column Fix | M1 | `gradebook_e2e_test.dart` | Tier 1, Tier 2, Tier 3, Tier 4 |
| **F2.1** | Manage Students Name Font Standard (13.5–14pt) | M2 | `directory_management_e2e_test.dart` | Tier 1, Tier 2, Tier 4 |
| **F2.2** | Manage Parents Name Font Standard (13.5–14pt) | M2 | `directory_management_e2e_test.dart` | Tier 1, Tier 2, Tier 4 |
| **F2.3** | Remove Checkbox Column in Manage Parents | M2 | `directory_management_e2e_test.dart` | Tier 1, Tier 2, Tier 3 |
| **F2.4** | Replace 'SECTION' with 'BIRTHDAY' Column | M2 | `directory_management_e2e_test.dart` | Tier 1, Tier 2, Tier 3, Tier 4 |
| **F2.5** | Remove 'All Subjects' Option from Subject Filter | M2 | `directory_management_e2e_test.dart` | Tier 1, Tier 2, Tier 3 |
| **F2.6** | Fix Manage Parents Header Overflow Artifacts | M2 | `directory_management_e2e_test.dart` | Tier 1, Tier 2, Tier 3 |
| **F3.1** | Attendance Typography & LRN Removal | M3 | `attendance_rfid_e2e_test.dart` | Tier 1, Tier 2, Tier 4 |
| **F3.2** | Attendance Roster Lazy Loading (20/batch) | M3 | `attendance_rfid_e2e_test.dart` | Tier 1, Tier 2, Tier 3, Tier 4 |
| **F3.3** | Inline RFID Tap-to-Link (No Modal Popup) | M3 | `attendance_rfid_e2e_test.dart` | Tier 1, Tier 2, Tier 3, Tier 4 |
| **F3.4** | Action Buttons Layout & Cutoff Rules Placement | M3 | `attendance_rfid_e2e_test.dart` | Tier 1, Tier 3, Tier 4 |
| **F3.5** | 'Analytics & History' Header & Filter Container | M3 | `attendance_rfid_e2e_test.dart` | Tier 1, Tier 2, Tier 3 |
| **F3.6** | Active Schedule Filtering in Attendance Dropdowns | M3 | `attendance_rfid_e2e_test.dart` | Tier 1, Tier 2, Tier 3, Tier 4 |
| **F4.1** | Audit Log 20-Item Structured Pagination | M4 | `audit_history_logs_e2e_test.dart` | Tier 1, Tier 2, Tier 3, Tier 4 |
| **F4.2** | Full Student Names (Lastname, Firstname M.) | M4 | `audit_history_logs_e2e_test.dart` | Tier 1, Tier 2, Tier 4 |
| **F4.3** | Dedicated Time In & Method Table Columns | M4 | `audit_history_logs_e2e_test.dart` | Tier 1, Tier 2, Tier 3, Tier 4 |
| **F5.1** | Client-Side Frame-1 Caching (AppDataCache SWR) | M5 | `caching_responsiveness_e2e_test.dart` | Tier 1, Tier 2, Tier 3, Tier 4 |
| **F5.2** | Cross-Viewport Responsiveness & Layout Safety | M5 | `caching_responsiveness_e2e_test.dart` | Tier 1, Tier 2, Tier 3, Tier 4 |
| **F5.3** | Strict 60-30-10 Color Rule Token Compliance | M5 | `caching_responsiveness_e2e_test.dart` | Tier 1, Tier 2, Tier 4 |
| **F6.1** | Student Portal Schedule & Attendance Views | M6 | `portals_notifications_e2e_test.dart` | Tier 1, Tier 2, Tier 3, Tier 4 |
| **F6.2** | Parent Portal Child Attendance & Schedule Views | M6 | `portals_notifications_e2e_test.dart` | Tier 1, Tier 2, Tier 3, Tier 4 |
| **F6.3** | Automated 3/5/10-Absence Multi-Tier Push Alerts | M6 | `portals_notifications_e2e_test.dart` | Tier 1, Tier 2, Tier 3, Tier 4 |

---

## 4. Test Execution & Verification

### Running the Complete E2E Test Suite
```powershell
flutter test test/e2e/
```

### Running Individual Test Suites
```powershell
flutter test test/e2e/gradebook_e2e_test.dart
flutter test test/e2e/directory_management_e2e_test.dart
flutter test test/e2e/attendance_rfid_e2e_test.dart
flutter test test/e2e/audit_history_logs_e2e_test.dart
flutter test test/e2e/caching_responsiveness_e2e_test.dart
flutter test test/e2e/portals_notifications_e2e_test.dart
```

### Running by Tier Tag / Filter
```powershell
flutter test test/e2e/ --name "Tier 1"
flutter test test/e2e/ --name "Tier 2"
flutter test test/e2e/ --name "Tier 3"
flutter test test/e2e/ --name "Tier 4"
```

---

## 5. Mocking Strategy & Dependency Inversion

1. **LocalStorage & Preferences**: Mocked using `SharedPreferences.setMockInitialValues({})` and `LocalStorageService.init()`.
2. **Cloud Repositories**: Replaced with isolated in-memory test doubles implementing the respective repository abstract interfaces (`AttendanceRepository`, `StudentRepository`, `ParentRepository`, `ScheduleRepository`).
3. **Viewport Adaptation**: Simulated via `tester.view.physicalSize = const Size(width, height)` and `tester.view.devicePixelRatio = 1.0`, with automatic teardown resetting physical size.
4. **Hardware Scanner & Key Events**: Simulated via `tester.sendKeyEvent(LogicalKeyboardKey.keyA)` or direct text/character stream injection simulating 8-to-14 character RFID UID scanners.
