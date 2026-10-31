Implement production-ready fixes and enhancements across the teacher, student, and parent modules in Class Realm: resolve Gradebook column rendering lag and filter duplication crashes, polish Manage Students and Manage Parents tables, streamline attendance with inline RFID tap-to-link, paginated audit logs, caching, responsive layouts following the 60-30-10 color rule, and build student/parent portal views with automated 3/5/10-absence push notifications.

Working directory: c:\Users\Admin\AndroidStudioProjects\class_realm01
Integrity mode: development

## Requirements

### R1. Gradebook Optimization and Crash/Duplication Fixes
- Reduce default score column slots from 10 to 5 per assessment category, providing an inline "+" button on subsequent columns to add slots up to a maximum of 10 (the "+" button disappears once 10 slots are reached) to eliminate UI lag.
- Resolve the Flutter crash caused by duplicate keys (`Duplicate keys found. Column(direction: vertical...) has multiple children with key [gradebook-row-zV0ZGShD46TGOcXrfsLIX1Jd45j2-true]`) in `teacher_gradebook_tab.dart`.
- Fix the assertion failure and column duplication bug when toggling gender filters ('All', 'Male', 'Female'): filtering must strictly display the corresponding learners without duplicating sticky/header columns or repeating '# LEARNERS NAMES' horizontally across the table.

### R2. Manage Students and Manage Parents UI Polish
- Standardize learner name text sizes in Manage Students and parent name text sizes in Manage Parents to an equal, legible, and consistent size.
- In the Manage Parents directory table:
  - Remove the checkbox column adjacent to '#'.
  - Replace the 'SECTION' column with a 'BIRTHDAY' column.
  - Remove the 'All Subjects' option from the subject filter dropdown so teachers select only specific assigned subjects.
  - Fix table header horizontal overflow rendering artifacts.

### R3. Attendance Tab Improvements & Inline RFID Tap-to-Link
- Increase student name text size in the attendance list to match the readable standard size, and remove the LRN label displayed underneath student names.
- Implement lazy loading in the attendance student list (loading 20 students per batch).
- Implement an inline tap-to-link workflow for RFID cards without opening a popup modal: clicking "Link RFID" displays an inline "Waiting for RFID..." indicator on the student row that listens for card reader input (8-character UID keystrokes), automatically links the card to the student, and confirms completion.
- Reorganize action buttons: place the "Save Attendance" button directly beside the "Auto Absent" button, and move the "Cut off rules" button before the "Take Attendance" button.
- Rename "History & Analytics" to "Analytics & History", and integrate "This Week", "This Month", "Custom", and "Export" buttons inside the filter container box next to Grade, Subject, and Section on the right-hand side. Filter dropdowns must only list grades, subjects, and sections with active schedules.

### R4. Attendance Audit & History Logs Refactoring
- Replace lazy loading with pagination displaying 20 records per page, matching the pagination pattern in Manage Students.
- Display student full names in format "Lastname, Firstname Middlename" instead of raw/random IDs (e.g. "JrZ...").
- Display Time In and Attendance Method (e.g., Manual vs RFID) in dedicated, separate table columns rather than placed under the student name.

### R5. Performance Caching, Responsiveness, and Visual Hierarchy
- Implement client-side caching for slower modules (Classroom Setup, Gradebook, Manage Students, Manage Parents, Learning Materials, and My Schedule) so navigation and data retrieval are fast without redundant reload states.
- Ensure all teacher-side screens adapt responsively across supported viewports without overflow stripes or broken layouts.
- Strictly adhere to the 60-30-10 color rule across updated layouts.

### R6. Student & Parent Portals and Multi-Tier Absence Push Notifications
- Implement student portal views for Attendance history and My Schedule.
- Implement parent portal views allowing parents/guardians to inspect their linked child's schedule and attendance records.
- Implement automated push notification alerts to admin and parents upon student reaching 3 absences (early warning), 5 absences (second warning), and 10 absences (final warning), integrated via the existing FCM architecture.

## Acceptance Criteria

### Gradebook
- [ ] Initial assessment score columns render 5 slots with a "+" button that increments columns up to 10 and hides thereafter.
- [ ] Switching between All, Male, and Female filters displays only matching rows without throwing duplicate key errors or duplicating sticky columns and header titles.
- [ ] Gradebook scrolling and interactions operate smoothly without perceptible lag or redundant re-renders.

### Directory Management (Manage Students & Manage Parents)
- [ ] Student names in Manage Students and parent names in Manage Parents render with equal, readable font sizes.
- [ ] Manage Parents table has no checkbox column next to '#', displays 'BIRTHDAY' instead of 'SECTION', and contains no 'All Subjects' option in the subject dropdown.
- [ ] Table headers render cleanly without horizontal overflow stripes.

### Attendance & RFID
- [ ] Attendance list loads students lazily in batches of 20, student names are clearly readable, and LRN labels are removed from underneath names.
- [ ] Clicking "Link RFID" displays an inline "Waiting for RFID..." indicator on the student item without a modal popup, automatically capturing the scanned 8-character UID and saving the link.
- [ ] "Save Attendance" is positioned next to "Auto Absent", and "Cut off rules" is positioned before "Take Attendance".
- [ ] Filter box in Analytics & History contains "This Week", "This Month", "Custom", and "Export" on the right side, and only lists grades, subjects, and sections with existing schedules.

### Audit & History Logs
- [ ] Audit logs display paginated at 20 items per page with functional page navigation controls.
- [ ] Student records display full names (Lastname, Firstname Middlename) rather than alphanumeric IDs.
- [ ] Time In and Method are displayed in dedicated, separate columns.

### Caching, Responsiveness, & Styling
- [ ] Classroom Setup, Gradebook, Manage Students, Manage Parents, Learning Materials, and My Schedule utilize caching for quick revisitation without blocking loading states.
- [ ] Teacher interface layouts adapt responsively without overflow errors across window resizes.
- [ ] Color usage conforms to the 60-30-10 palette distribution.

### Student & Parent Portals & Notifications
- [ ] Student portal displays student schedule and personal attendance history.
- [ ] Parent portal displays linked children's schedules and attendance records.
- [ ] Push notifications are automatically dispatched to admin and parent devices upon a student reaching exactly 3, 5, and 10 cumulative absences.
