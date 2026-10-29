The user requested: "Gusto ko maraming agents yung gagalaw para sa system natin para mabilis matapos yung sa attendance feature." Create a comprehensive end-to-end design and implementation plan document for the Attendance Feature redesign, teacher RFID assignment, dual-path offline scanning (ESP32 hardware scanner and NFC mobile app fallback with ESP32 build guide), schedule-bound automated attendance status recording, table-based roster redesign, multi-platform responsive views (Teacher Web/App, Student App, Parent App), and an exhaustive edge-case validation matrix.

Working directory: c:\Users\Admin\AndroidStudioProjects\class_realm01
Integrity mode: development

## Requirements

### R1. Comprehensive Architecture & Implementation Plan Deliverable
Produce a complete architectural, functional, and UI/UX implementation plan document saved in `docs/` (without modifying application source code). The document must detail data models, validation logic, offline sync protocols, hardware build guides, responsive screen specifications, and phased rollout tasks.

### R2. Teacher RFID Assignment & Recording Method Indicator
Design the workflow for teachers to assign physical RFID cards directly to students across Teacher Web and Mobile:
- Enforce unique RFID assignments with conflict detection (prevent duplicate card assignment across students).
- Provide an assignment modal supporting both keyboard/USB scanner input and phone NFC taps.
- In attendance logs, display an explicit indicator for each record showing whether it was recorded via "RFID" or "Manual".

### R3. Schedule-Connected Auto-Status, Cutoff Validation & 11:59 PM Auto-Absent
Specify the automated attendance evaluation engine strictly bound to plotted class schedules:
- Scans outside the plotted class schedule window or on non-scheduled days are blocked.
- Teacher-configurable cutoff thresholds for Present, Late, and Absent with strict chronological validation (Present window starts at/before class start; Late cutoff is strictly after Present cutoff; Absent cutoff is strictly after Late cutoff and within class hours; no inverted or overlapping thresholds).
- Daily automated backend job (Supabase Edge Function / cron trigger at 23:59) that marks unscanned students as Absent only if their subject/section had an active scheduled class on that day; never generate absences on non-scheduled days or holidays, and never overwrite existing Present, Late, or Excused marks.

### R4. Dual-Path Offline Attendance Capture & ESP32 Hardware Guide
Architect an offline-first attendance collection pipeline:
- Primary hardware device: Standalone ESP32 RFID scanner that operates independently with local non-volatile storage when offline or when the teacher's laptop is closed, queuing scans and synchronizing to Supabase when connectivity returns.
- Mobile phone fallback: Teacher mobile app with NFC capability allowing any compatible NFC-enabled smartphone to scan student RFID cards and record attendance offline with local caching and auto-sync on reconnect.
- Hardware build tutorial: Step-by-step guide detailing ESP32 hardware assembly, components (ESP32 DevKit, RC522 / PN532 RFID reader, buzzer, status LEDs, battery/power circuit), wiring pinouts, firmware architecture, and offline buffering/retry logic.

### R5. Roster Table UI/UX Redesign & 60-30-10 Theming
Redesign the student roster interface into a clean, unified, and compact table layout following the 60-30-10 color rule and responsive design across Web and Mobile:
- Alphabetical student ordering by default.
- Remove the circular avatar/initials badge beside student names.
- Category filters for gender (default grouped view of Male and Female sections, with filter options for All, Male Only, and Female Only).
- Relocate "Save Attendance" action to the persistent top header action bar, eliminating excessive scrolling.

### R6. Multi-Platform Attendance History & Analytics (Teacher, Student, Parent)
Specify responsive history and analytics views:
- Teacher view (Web & Mobile): Section-level KPIs (Attendance Rate, Total Absences & Excuses, Attendance Warnings for students with >= 3 absences, Attendance Trend, Status Breakdown bars), date range filtering (This week, This month, Custom), and per-student drill-downs.
- Student App: Dedicated view-only personal history and analytics dashboard strictly scoped via Row Level Security (RLS) to the logged-in student's own records, featuring a polished, user-friendly empty state when no attendance records exist yet.
- Parent App: Dedicated view-only child history and analytics dashboard strictly scoped via RLS to their linked child's records, featuring a polished empty state.

### R7. Strict UI Error Presentation & Comprehensive Validation Matrix
Enforce user-friendly error handling and an exhaustive validation and edge-case matrix:
- UI Error Presentation Rule: Zero raw, technical, or database error messages shown to users. Use strictly Inline Input Errors (red border + helper text directly under the input field) or Modal Dialogs (for scanner, conflict, and hardware alerts). Strictly prohibit SnackBars, floating toasts, and top/bottom banners.
- Explicit edge-case specifications covering:
  1. RFID Assignment: Duplicate card already assigned, corrupted/invalid UID format, card replacement/reassignment confirmation, scanner timeout/read failure, NFC unavailable/disabled.
  2. Schedule Guarding: Scanning on non-scheduled days, scanning before class window opens, scanning after class ends.
  3. Live Attendance: Unregistered card tapped, student card from a different section/grade tapped, duplicate scans by the same student in the same class session (idempotent; do not overwrite timestamp or downgrade status), offline scan vs manual teacher override conflict resolution (deterministic rules).
  4. 11:59 PM Auto-Absent: Skipping non-scheduled days/holidays, preserving existing marks.

## Acceptance Criteria

### Plan Deliverables & File Isolation
- [ ] A dedicated implementation plan document is created under `docs/` detailing data schemas, API contracts, hardware diagrams, UI specifications, and phased rollout tasks.
- [ ] No application code files are modified during this planning run.

### RFID Setup & Attendance Tracking
- [ ] Specification details teacher RFID assignment modal supporting both USB/keyboard scanner and phone NFC scanning.
- [ ] Duplicate RFID assignment is detected and prevented with clear, friendly inline or modal feedback.
- [ ] Attendance data model and logs include an explicit recording method attribute distinguishing "RFID" from "Manual".
- [ ] Roster table replaces individual boxed cards with a unified data table, removes circular avatars, provides gender category filters (All, Male Only, Female Only), and positions "Save Attendance" in the top header.

### Schedule Guarding & Auto-Status Rules
- [ ] Attendance recording is locked and scans are rejected on dates and times without an active matching class schedule.
- [ ] Teacher cutoff configuration enforces strict validation: Present window starts at/before class start, Late cutoff is after Present cutoff, and Absent threshold is after Late cutoff within class duration.
- [ ] Server-side 23:59 scheduled cron job logic is specified to mark unscanned students as Absent only for classes scheduled on that date, preserving existing marks and skipping non-scheduled days.

### Dual-Path Hardware & Mobile Offline Architecture
- [ ] ESP32 hardware architecture specification includes circuit wiring/pinout diagrams, bill of materials, and firmware operational flow.
- [ ] Offline queuing and conflict-free synchronization mechanism is defined for both ESP32 hardware and mobile phone NFC fallback.
- [ ] Complete step-by-step tutorial document covers building, wiring, flashing, and testing the ESP32 RFID scanner.

### Cross-Platform Responsive Views & Access Control
- [ ] Teacher attendance management and analytics are specified with responsive layouts for both Web and Mobile.
- [ ] Student App attendance history & analytics is specified as view-only, strictly restricted via Supabase RLS to the authenticated student's own records, and includes a polished empty state.
- [ ] Parent App attendance history & analytics is specified as view-only, strictly restricted via Supabase RLS to the linked child's records, and includes a polished empty state.

### Error Presentation & Validation Matrix
- [ ] Plan enforces zero technical error messages, using exclusively inline errors (under form inputs) or modal dialogs (for scanner/action alerts), strictly prohibiting SnackBars, toasts, and banners.
- [ ] Plan includes an exhaustive scenario matrix covering unregistered cards, cross-section card taps, duplicate scans (idempotent), offline sync conflicts with manual teacher edits, schedule cutoff validations, and scanner timeouts with exact user-facing friendly messages.
- [ ] UI designs follow the 60-30-10 color rule.

## Verification Resources
- [ ] Existing project test suites and Supabase schema fixtures (`class_realm01`).
