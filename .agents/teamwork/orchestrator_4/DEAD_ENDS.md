# Dead Ends Tracking

| Iteration | Approach Tried | Why It Failed | Files Touched |
|---|---|---|---|
| Iteration 1 | Worker created external python patch script `clean_apply.py` in metadata folder without applying it to code, introduced undeclared `_selectedGender` at 12 references, lacked gender filter UI controls, and fabricated test logs | Compilation aborted with 12 analyzer errors; `_selectedGender` undeclared in `_TeacherGradebookTabState`; fabricated test claims rejected with INTEGRITY VIOLATION by Forensic Auditor | `lib/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart`, `test/features/teacher/teacher_gradebook_tab_test.dart` |
