# Original User Request

## Approved Task Prompt — 2026-10-29T08:54:45Z

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



## Approved Task Prompt — 2026-10-29T22:58:33Z

Revise and align Chapters 1 and 2 for CLASSREALM, an integrated Senior High School educational management system (RFID attendance with manual fallback, assessments, automated grade computation, lesson plan guide generator, and learning materials organizer) for client Ma'am Karen P. Gonzaga at Eduardo Barreto Sr. High School.

Working directory: c:\Users\Admin\AndroidStudioProjects\class_realm01
Integrity mode: development

## Reference Material
- Target Word Document: `c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx`
- Adviser Evaluation Notes & Rubrics: `c:\Users\Admin\AndroidStudioProjects\class_realm01\SAD_FR_Thesis_Finals-Activity1_Chapter3.pdf`
- Previous Chapters 1 & 2 Draft: `c:\Users\Admin\AndroidStudioProjects\class_realm01\Group#20_Calica_Sanjuan_chapter1and2.docx (2) (1).pdf`
- Previous Activities Draft: `c:\Users\Admin\AndroidStudioProjects\class_realm01\Group#20_Calica_Sanjuan_Activities.docx (1).pdf`
- System Overview Presentation: `c:\Users\Admin\Downloads\CLASSREALM_Presentation_Overview.pptx`
- Reference Samples (Structure only): `c:\Users\Admin\Downloads\Activity#1_Chapter1.docx`, `c:\Users\Admin\Downloads\Acitivity#3_Chapter2.docx`

## Requirements

### R1. Chapter 1 Revision, Scope Formalization, and Technical Definitions
Revise Chapter 1 (Introduction, Problem Statement, General and Specific Objectives, Scope and Limitations, Definition of Terms) according to the adviser's evaluation and project specifications:
- Writing tone: Formal capstone prose that is concise, direct to the point, and easy to understand, avoiding flowery or unnecessarily verbose phrasing.
- Explicitly name the pilot institution as Eduardo Barreto Sr. High School and the client as Ma’am Karen P. Gonzaga, Senior High School Mathematics Teacher.
- Detail the supported roles: Admin, Teacher (web and responsive app), Student (app), and Parent (app).
- Formally establish system boundaries and limitations in the narrative:
  - System Admin account is assigned to the client teacher solely for academic year transitions and teacher provisioning. Admin has no access to manage sections, subjects, schedules, attendance, activities, requirements, quizzes, examinations, grading percentages, lesson plans, learning materials, or student academic records.
  - Teachers self-manage sections, subjects, and students after receiving class rosters from the registrar/school.
  - The system excludes registrar and principal roles.
  - Transfer student, transfer section, and dropping student workflows are excluded from system management.
  - System must preserve academic records and allow downloading/exporting student grade records.
- Establish measurable, dated SMART evaluation targets for attendance tracking, submission handling, and assessment evaluation.
- Preserve manual attendance recording as a permanent operational fallback alongside RFID scanning.
- Define parent authorization, offline synchronization / duplicate attendance policies, and test thresholds.
- Definition of Terms: Construct operational, IT-oriented technical definitions directly tailored to ClassRealm's architecture rather than generic dictionary definitions. Specifically include and define: ESP32, RFID, Firebase Authentication, Supabase, Row-Level Security (RLS), Admin Portal, Teacher Portal, Student Portal, and Parent Portal (without copying any prompt example verbatim).

### R2. Chapter 2 Review of Related Literature (RRL) and Theoretical/Conceptual Framework
Revise Chapter 2 to fulfill all adviser recommendations:
- Identify and develop literature themes, concepts, and variables directly aligned with the research title and statement of the problem across attendance tracking, assessment and grading, lesson planning, and learning materials management.
- Sourced literature requirement: Include exactly 10 empirical studies published between 2021 and 2026 (5 Philippine local studies in English, 5 foreign/international studies in English) with valid, authentic sources, working URLs or DOIs, explicit methodologies, participant/sample groups, and actual empirical findings.
- Expand the synthesis matrix to encompass all 10 domain sources; eliminate unsupported blanket statements claiming prior works simply "lack" features.
- Provide direct literature and empirical evidence supporting the teacher lesson-planning and learning-materials workflow components.
- Present an explicit 4-part IPSO (Input - Process - System - Output) diagram and narrative for the Conceptual Framework.
- Incorporate DeLone & McLean (2003) Information Systems Success Model as foundational supporting theory, including its complete citation and publication year (2003).

### R3. Word Document Compilation and Formatting
Directly populate, update, and format the revised Chapters 1 and 2 within the provided Word template: `c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx`.
- Maintain a direct, formal capstone writing style free of filler content.
- Replace outdated or contradictory sections with the corrected text, maintaining uniform typography, heading hierarchy, margins, and caption standards conforming to `SAD_FR_Thesis_Finals-Activity1_Chapter3.pdf`.
- Ensure consistency between Chapter 1 objectives, scope limitations, and Chapter 2 conceptual framework variables.

## Acceptance Criteria

### Chapter 1 Compliance & Definitions
- [ ] Eduardo Barreto Sr. High School is explicitly identified as the pilot school, and Ma'am Karen P. Gonzaga is explicitly identified as the client.
- [ ] Scope and Limitations section explicitly limits Admin to academic year transitions and teacher provisioning, while designating student roster entry to teachers.
- [ ] Exclusions of registrar and principal user accounts and transfer/drop workflows are documented, and student grade record preservation and downloading capabilities are specified.
- [ ] Attendance specifications include both RFID and manual teacher fallback.
- [ ] Quantifiable, dated SMART criteria are documented for attendance, assessment, and submission workflows.
- [ ] Parent authorization policies, offline synchronization, duplicate attendance detection, and test thresholds are defined.
- [ ] Definition of Terms contains operational, system-specific IT definitions for ESP32, RFID, Firebase Authentication, Supabase, Row-Level Security (RLS), Admin Portal, Teacher Portal, Student Portal, and Parent Portal.
- [ ] Phrasing across Chapter 1 is concise, formal, and free of overly flowery filler text.

### Chapter 2 & Literature Synthesis
- [ ] Literature review includes exactly 10 empirical studies (5 Philippine local, 5 international) published between 2021 and 2026 with verifiable citations and DOIs/URLs.
- [ ] Literature review matrix contains all 10 studies with distinct columns for author/year, methodology, sample size/profile, and specific empirical findings, without unsupported blanket "lacks" statements.
- [ ] Specific literature evidence directly addresses teacher lesson planning and learning materials management workflows.
- [ ] DeLone & McLean (2003) is cited with complete year and established as foundational theory.
- [ ] Conceptual framework diagram and narrative explicitly follow the 4-part IPSO stages.

### Document Quality & Verification
- [ ] The deliverable is compiled directly into `c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx`.
- [ ] All itemized deficiencies cited in the adviser evaluation record (Mpbomilc review) for Chapter 1 and Chapter 2 are resolved and verified against `SAD_FR_Thesis_Finals-Activity1_Chapter3.pdf`.


## Approved Task Prompt — 2026-10-30T11:21:14Z

Work using subagents. Revise and streamline the CLASSREALM IT Capstone 1 documentation (Chapters 1-3) and produce a consolidated Activity document (Activities #2 and #4) adhering to IT Capstone guidelines, using direct and natural language without overly fancy words, and generating clean, accurate architecture diagrams.

Working directory: c:\Users\Admin\AndroidStudioProjects\class_realm01
Integrity mode: development

## Reference Materials
- Existing Activities: `c:\Users\Admin\AndroidStudioProjects\class_realm01\Group#20_Calica_Sanjuan_Activities.docx (1).pdf`
- Classmate Activity References: `c:\Users\Admin\Downloads\Activity#2_DFD (3).docx`, `c:\Users\Admin\Downloads\Activity#4_UML_Object.docx`
- Formatting Guidelines (IT Capstone rules: spacing, font sizes, unsevered tables across page boundaries): `c:\Users\Admin\AndroidStudioProjects\class_realm01\Capstone-1-and-Thesis-1-Document-FORMATS-1785742696-1.docx`
- Master Template for Capstone & Activities: `c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED_SENIOR_HIGH_SCHOOL_ATTENDANCE_CH1_CH2_CH3.docx`
- Existing Codebase for Tech Stack verification: `c:\Users\Admin\AndroidStudioProjects\class_realm01`

## Requirements

### R1. Revise Chapters 1 to 3 in a Single Document
Revise the complete Capstone 1 document (Chapters 1-3) into a single DOCX file based on `INTEGRATED_SENIOR_HIGH_SCHOOL_ATTENDANCE_CH1_CH2_CH3.docx` and compliant with IT format specifications:
- Language & Tone: Remove flowery, convoluted vocabulary ("fancy words"); rewrite all revised sections in clear, direct, and natural academic English.
- Chapter 1 Page Constraint: Sections 1.1 (Project Context), 1.2 (Purpose and Description), 1.4.1 (Scope of the Study), and 1.4.2 (Boundaries and Limitations) must be condensed such that the entire Chapter 1 spans strictly between 9 to 11 pages (counting from the Title page through the end of Chapter 1).
- Chapter 2 Condensation: Substantially shorten sections 2.1.1 (Automated and Dual-Path Attendance Tracking Systems), 2.1.2 (Automated Grading, Assessment Computation, and Academic Analytics), 2.1.4 (Centralized Learning Materials Organization and Digital Repositories), Table 1 (Quantitative Synthesis Matrix of the Reviewed Empirical Literature), 2.3 (Theoretical Framework), and 2.4 (Conceptual Framework) to be concise and focused on essentials.
- Chapter 3 Methodology Clarification: In the Agile Scrum Methodology section, specify that purposive sampling is applied for teachers and parents (initial deployment focuses specifically on the client teacher and parent, while the underlying architecture supports multi-teacher, multi-subject, and multi-section scaling).

### R2. Redesign and Embed Accurate System Diagrams
Generate high-resolution, accurately spaced diagrams for the CLASSREALM system and embed them within the documentation:
- Figure 1: Input-Process-Storage-Output (IPSO) Diagram of CLASSREALM with balanced spacing and structure.
- Figure 2: Input-Process-Output (IPO) Diagram of CLASSREALM with side-column aligned boxes properly mapped to system components.
- Figure 3: Agile Scrum Methodology Framework of CLASSREALM with clean typography, no text overflowing bounding boxes, and properly proportioned sprint phases.
- Figure 5: Context Diagram (Level 0 DFD) showing CLASSREALM at the center, interacting with all user entities (Admin, Teacher, Student, Parent) and external entities/services (RFID Scanner Module RC522, Firebase Auth, Supabase), with directed arrows detailing input and output data flows (omitting redundant generic "input/output" text labels on the diagram canvas).
- Architecture & Database Alignment: Represent the actual system tech stack: Drift + SQLite for local database persistence on mobile, ESP32 + RC522 RFID scanner module hardware for attendance tracking, and cloud backend integration (Supabase / Firebase Auth), verified against the `class_realm01` codebase.

### R3. Produce a Single Consolidated Activities Document (Activities #2 and #4)
Create a single DOCX file containing both activities tailored specifically for CLASSREALM, formatted according to the IT capstone template:
- Activity #2: Requirements to Process Modeling (Context DFD, Level 1 DFDs, and process specifications for CLASSREALM).
- Activity #4: Integrated UML and Data Modeling (ERD, Use Case Diagram, Class Diagram, and Object Diagram for CLASSREALM).
- Use classmate activity documents solely as structural references; all models, diagrams, and descriptions must strictly represent CLASSREALM.

## Acceptance Criteria

### Formatting & Presentation
- [ ] Output documents strictly follow IT formatting rules in `Capstone-1-and-Thesis-1-Document-FORMATS-1785742696-1.docx` (font type/sizes, line spacing, margins, table rows not split across page breaks).
- [ ] Chapter 1 spans strictly between 9 and 11 pages from the Title page to the end of Chapter 1.
- [ ] Text uses natural, straightforward language without unnecessary jargon or filler phrasing.

### Diagram Completeness & Quality
- [ ] All diagram graphics (Figures 1, 2, 3, 5, and Activity diagrams) are sharp, legible, and contain no truncated or overflowing text.
- [ ] Figure 5 (Level 0 DFD) contains Admin, Teacher, Student, Parent, RC522 RFID, Firebase Auth, and Supabase with labeled directed data flows.
- [ ] Database and hardware representations reflect Drift + SQLite and ESP32 RC522 RFID.

### Deliverables
- [ ] Exactly one consolidated DOCX file for Chapters 1-3.
- [ ] Exactly one consolidated DOCX file containing both Activity #2 and Activity #4.

## Approved Task Prompt — 2026-10-30T23:09:39Z

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
