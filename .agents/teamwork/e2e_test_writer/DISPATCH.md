## 2026-10-30T23:32:05Z
Sender: 66488352-1827-4000-888d-2b0cd950101f
Priority: MESSAGE_PRIORITY_HIGH

You are the E2E Testing Specialist for Class Realm.
Your working directory is: c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\e2e_test_writer\

MANDATORY FIRST STEP:
Read the authoritative request file:
c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\ORIGINAL_REQUEST.md

Read the project specification:
c:\Users\Admin\AndroidStudioProjects\class_realm01\PROJECT.md (especially §10 Feature Inventory, §11 Milestones, §12 Interface Contracts).

YOUR OBJECTIVE:
Architect and implement the comprehensive E2E test suite for the Class Realm fixes and enhancements (R1 through R6).
Follow the E2E Testing Track Principles:
- Requirement-driven, opaque-box: derive test cases from ORIGINAL_REQUEST.md and PROJECT.md §10 Feature Inventory, NOT internal implementation trivia.
- Test EVERY feature in the Feature Inventory (F1.1 to F6.3).
- 4-Tier Test Case Design Methodology:
  * Tier 1: Feature Coverage (>=5 test cases per feature area, happy-path isolation).
  * Tier 2: Boundary & Corner Cases (limits, empty inputs, max values, zero/negative, extremes).
  * Tier 3: Cross-Feature Combinations (pairwise interactions, state sharing, filter toggling during edits).
  * Tier 4: Real-World Application Scenarios (realistic end-to-end teacher/student/parent workflows).
- Deliverables:
  1. Create `TEST_INFRA.md` at project root `c:\Users\Admin\AndroidStudioProjects\class_realm01\TEST_INFRA.md` following the template in PROJECT.md / pattern guide.
  2. Implement executable Flutter test suites under `c:\Users\Admin\AndroidStudioProjects\class_realm01\test\e2e\` (e.g. `gradebook_e2e_test.dart`, `directory_management_e2e_test.dart`, `attendance_rfid_e2e_test.dart`, `audit_history_logs_e2e_test.dart`, `caching_responsiveness_e2e_test.dart`, `portals_notifications_e2e_test.dart`).
  3. Execute the tests or verify they compile and run cleanly with `flutter test test/e2e/`.
  4. Once all test suites are created and ready, publish `c:\Users\Admin\AndroidStudioProjects\class_realm01\TEST_READY.md` summarizing the test runner command and tier counts.
  5. Write your complete handoff report to `c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\e2e_test_writer\handoff.md`.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All tests must be genuine and execute authentic assertions. DO NOT hardcode trivial passing tests or create dummy verifications. A teamwork_auditor will independently verify your work.

When finished, send a message back to the orchestrator with your summary and links to TEST_INFRA.md, TEST_READY.md, and your handoff.md.
