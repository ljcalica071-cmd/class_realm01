## 2026-10-30T23:32:19Z
You are a Senior Flutter Implementation Worker.
Your working directory is: c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_m1_gradebook\

MANDATORY FIRST STEP:
Read the authoritative request file:
c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\ORIGINAL_REQUEST.md

Read the project specification:
c:\Users\Admin\AndroidStudioProjects\class_realm01\PROJECT.md (§10 Feature Inventory, §11 Milestones M1, §12 Interface Contracts).

Read the detailed survey report from Explorer 1:
c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_survey_gradebook_dir\handoff.md

YOUR EXCLUSIVE WRITE OWNERSHIP:
- `lib/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart`
- `lib/features/teacher/sub_features/grading/widgets/gradebook_grid_cell.dart`
- `test/features/teacher/teacher_gradebook_tab_test.dart`
You MUST NOT edit any files outside your assigned write ownership.

YOUR OBJECTIVE:
Implement production-ready fixes and optimizations for Milestone 1 (Requirement R1):
1. Resolve Duplicate Key Crash:
   - In `teacher_gradebook_tab.dart` Left Sticky Column (lines ~833–896), remove the duplicate unconditional blocks that append male and female rows a second time outside the gender condition.
   - Symmetrically implement conditional rendering for both `_selectedGender == 'All' || _selectedGender == 'Male'` and `_selectedGender == 'All' || _selectedGender == 'Female'`.
   - In the Right Scrollable Column (lines ~952–1037), remove the redundant unconditional rows (lines ~1006–1037).
   - Ensure student row keys `ValueKey('gradebook-row-${s.id}-$isLeft')` appear at most once per Column.
2. Fix Gender Filter Assertion Failure & Duplication:
   - Ensure clicking 'All', 'Male', and 'Female' renders exactly the matching rows without repeating '# LEARNERS NAMES' horizontally or vertically, and without throwing `assert(_elements.contains(element))`.
3. 5-to-10 Assessment Slot Optimization:
   - Convert `static const int wwColumns = 10` and `ptColumns = 10` into state variables `_wwColumns` and `_ptColumns` initialized to 5 (or max populated index in saved sheet if loaded).
   - In the subheader row for WW and PT, render the active columns (1..N). When column count < 10, render an inline '+' button cell of width 48px with tooltip and add icon.
   - When clicked, increment the slot count via `setState` up to 10. When 10 is reached, the '+' button disappears.
   - Ensure header width calculations, HPS rows, student score cells, and metric calculations dynamically align with `_wwColumns` and `_ptColumns`.
4. Verification:
   - Run the build and test suites:
     `flutter test test/features/teacher/teacher_gradebook_tab_test.dart`
     `flutter test test/features/teacher/gradebook_grid_cell_test.dart`
   - Add dedicated widget tests for gender filter toggling and dynamic '+' slot expansion.
   - Ensure all tests pass with exit code 0.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

OUTPUT REQUIREMENTS:
- Write your handoff report to `c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_m1_gradebook\handoff.md` with Observation, Logic Chain, Caveats, Conclusion, and Verification Command results.
- Update your `progress.md` with timestamps.
- When done, send a message back to the orchestrator summarizing your work and test results.

