---
trigger: always_on
description: Strict guidelines for fast terminal test execution and verification, preventing long-running or hanging tasks.
---

## Fast Terminal Testing & Verification Guidelines

To prevent terminal commands from hanging indefinitely and to achieve rapid turnaround on user tasks:

1. **Targeted Testing Only (NEVER run unconstrained `flutter test`)**:
   - Strictly run ONLY the single, targeted test file relevant to the modified feature (e.g., `flutter test test/features/student/student_classwork_card_test.dart`).
   - NEVER execute bare `flutter test` across the whole repository, as it compiles and runs hundreds of tests that can take 10+ minutes or hang on timers.

2. **Prefer Instant Static Analysis**:
   - For syntax, typing, null-safety, and validation verification, prefer `flutter analyze <modified_file_path>`. It finishes in 3–5 seconds without background process overhead.

3. **Standalone Dart Scripts Must Terminate Explicitly**:
   - Whenever executing a standalone Dart script via `dart <path>`, the script MUST explicitly call `exit(0);` (or `exit(1);` on failure) at the end of `main()`.
   - Never leave unclosed HTTP client connection pools, Supabase client listeners, or active sockets that keep the Dart event loop alive indefinitely.

4. **Preventive Validation over Runtime Errors (Golden Rule)**:
   - When designing forms or uploads (e.g. file submissions), clearly present formats, size limits, and filename constraints in the UI before user interaction.
   - Validate early with clear, inline user-facing messages.
