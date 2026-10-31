# Explorer M0-2 Handoff Report: Investigation of Activities & System Diagrams for CLASSREALM

## 1. Observation

### 1.1 Inspected Files & Environmental Evidence
1. **Previous Activities Draft**: `c:\Users\Admin\AndroidStudioProjects\class_realm01\Group#20_Calica_Sanjuan_Activities.docx (1).pdf`
   - *Pages 1–4*: Title (Laguna University, BSIT Capstone, Calica & San Juan), Part A Requirements Review (Table 1: 4 Stakeholders [Admin, Teacher, Student, Parent], Table 2: FR1–FR8 Functional Requirements, Table 3: User Stories).
   - *Pages 5–8*: Part B Process Modeling (Figure 1: Context Diagram, Figure 2: Level 0 DFD with 5 major processes [1.0 Accounts, 2.0 Classroom & Attendance, 3.0 Classwork & Assessments, 4.0 Grades & Reports, 5.0 Learning Resources], Figure 3: Level 1 DFD for 3.0), Part C Requirement $\leftrightarrow$ DFD Mapping (Table 4), Part D DFD Validation Checklist.
   - *Pages 9–16*: Part A UML ERD, Part B UML Use Case Diagram, Part C UML Class Diagram, Part D Object Diagram (Grade 11 Mathematics runtime snapshot featuring Ma'am Karen P. Gonzaga, Juan Dela Cruz, RFID scan att001, etc.), Section III Diagram Integration, Section IV Diagram-to-Diagram Consistency, Section V Traceability Table, Section VI Design Review.

2. **Classmate Activity Reference #2**: `c:\Users\Admin\Downloads\Activity#2_DFD (3).docx`
   - *Authors*: Calantina, Jhon Vincent S. & Jacob, Xedric Jhover E.
   - *Structure*:
     * Title Page: Activity #2: Requirements to Process Modeling, Institutional Heading.
     * Part A — Requirements Review: 1. Stakeholders / External Users (Table 1), 2. Functional Requirements (Table 2), 3. User Stories (Table 3).
     * Part B — Process Modeling: 4. DFD Design Overview (Table 4 Process Decomposition, Table 5 Data Stores to Database Tables), Figure 1 Context Diagram (Level 0 DFD), Figure 2 Level 0 DFD (System decomposition), Figures 3–9 Level 1 DFDs with detailed narrative for each sub-process.
     * Part C — Validation: 5. Requirement-to-DFD Mapping (Table 6), 6. DFD Validation Checklist (Table 7), 7. Notes on the Revised Model.

3. **Classmate Activity Reference #4**: `c:\Users\Admin\Downloads\Activity#4_UML_Object.docx`
   - *Structure*:
     * Title Page: Activity #4: Integrated UML and Data Modeling.
     * Part A — Design Basis: 1. The System Being Modeled, 2. How the Four Models Fit Together (Table 1 Summary Matrix).
     * Part B — Data Modeling: 3. Entities and Relationships (Figures 1–4 Modular ERDs, Tables 2–10 Data Dictionary, Tables 11–12 Cardinalities & Relationships).
     * Part C — Use Case Modeling: 4. Actors and Use Cases (Figures 5–8 Modular Use Case Diagrams), 5. Use Case Descriptions (Tables 13–18 Summaries, Tables 19–23 Detailed Step-by-Step Specifications).
     * Part D — Class Modeling: 6. Classes and Associations (Figures 9–12 Modular Class Diagrams, Tables 24–26 Class-to-Entity Mapping).
     * Part E — Object Modeling: 7. Scenarios (Figures 13–16 Concrete Object Diagrams with slot values).
     * Part F — Integration and Validation: 8. Traceability Table (Table 27), 9. Consistency of Names Across the Models (Table 28), 10. Design Review Checklist (Table 29), 11. Design Decisions and Limits.

4. **Capstone 1 Master Manuscript**: `c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED_SENIOR_HIGH_SCHOOL_ATTENDANCE_CH1_CH2_CH3.docx`
   - *Figure 1 (IPSO Diagram)*: Flow from Input (rosters, RFID card taps, schedules, criteria) $\rightarrow$ Process (auth, dual-path attendance, auto-grading, grade computation) $\rightarrow$ Storage (Supabase RLS DB, Drift+SQLite local DB, SPIFFS flash, secure file storage) $\rightarrow$ Output (attendance logs, E-Class Records, absence warnings, lesson guides, dashboards) + Reverse feedback tracing.
   - *Figure 2 (IPO Diagram)*: Three side-column aligned boxes (Input $\rightarrow$ Process $\rightarrow$ Output) + dashed bottom feedback loop.
   - *Figure 3 (Agile Scrum Framework)*: 4 sequential phases (Sprint 0 $\rightarrow$ Sprint Iterations $\rightarrow$ Verification & Review $\rightarrow$ System Release) + continuous retrospective feedback loop. Purposive sampling for client teacher and parent.
   - *Figure 4 (Three-Tier Architecture)*: Edge Hardware Layer $\leftrightarrow$ Client Application Layer $\leftrightarrow$ Cloud Backend Layer.
   - *Figure 5 (Context Diagram Level 0 DFD)*: Central Process 0 CLASSREALM interacting with 4 User Entities (Admin, Teacher, Student, Parent) and 3 External Entities (ESP32 RC522 RFID Scanner, Firebase Auth, Supabase Cloud).

5. **Codebase Schema Verification**: `c:\Users\Admin\AndroidStudioProjects\class_realm01\supabase\migrations\001_initial_schema.sql`
   - Verified relational tables: `users` (id=Firebase UID, role enum 'admin','teacher','student','parent'), `admin_profiles`, `teacher_profiles`, `teacher_settings`, `student_profiles`, `parent_profiles`, `parent_student_links`, `sections`, `subjects`, `class_schedules`, `class_rosters`, `rfid_cards`, `attendance_logs` (recording_method 'RFID'/'Manual', status 'Present'/'Late'/'Absent'/'Excused'), `activities`, `submissions`, `assessments`, `questions`, `assessment_sessions`, `assessment_responses`, `grading_components`, `quarterly_grades`, `lesson_plans`, `learning_materials`, `notifications`, `audit_logs`.
   - Local client stack: Drift + SQLite on mobile for offline operation.

6. **System Tooling Environment Audit**:
   - Python 3.13 at `C:\Users\Admin\AppData\Local\Programs\Python\Python313\python.exe`.
   - Installed packages: `PIL` (Pillow) **INSTALLED**, `docx` (python-docx) **INSTALLED**.
   - Not installed: `matplotlib`, `graphviz`. Graphviz native `dot.exe` is not installed in the Windows PATH.
   - Browser engine: Microsoft Edge verified present at `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe` (supports `--headless --screenshot`).
   - Windows TrueType fonts verified present: `C:\Windows\Fonts\segoeui.ttf`, `segoeuib.ttf` (Segoe UI Bold), `arial.ttf`, `calibri.ttf`.

---

## 2. Logic Chain

1. **Classmate Document Blueprint vs. CLASSREALM Reality**:
   - The classmate reference files (`Activity#2_DFD (3).docx` and `Activity#4_UML_Object.docx`) provide the exact academic structure expected by the Laguna University IT faculty, including numbered parts, table schemas, validation checklists, and traceability matrices.
   - However, the classmate files model an entirely different system (MOJ Catholic School with cashier, GCash, registrar, and OMR paper sheets).
   - *Logic Step*: We must adopt the exact structural template and academic rigor of Calantina & Jacob, but replace 100% of the content with CLASSREALM's validated architecture (DepEd Senior High School, Ma'am Karen P. Gonzaga, ESP32 RC522 RFID, Firebase Auth, Supabase Cloud, Drift+SQLite local storage, DepEd Order 8 s. 2015 grading).

2. **Process Modeling Decomposition for Activity #2**:
   - *Context Diagram (Level 0)*: Needs 1 central process (`0 CLASSREALM`) connected to 4 human user roles (Admin, Teacher, Student, Parent) and 3 external automated entities (ESP32 RC522 RFID Module, Firebase Authentication, Supabase Cloud Backend). Every data flow must be labeled specifically with domain payloads (e.g., "Card UID & Tap Timestamp [ISO 8601]" from ESP32, "Audio/Visual Acknowledgment Signal" to ESP32). Generic labels like "input" or "output" must be omitted.
   - *Level 1 Decomposition*: Must break down into 5 distinct subsystem processes:
     * `1.0 User Authentication & Role Verification` (Firebase Auth + Supabase profile linking $\rightarrow$ D1 User Accounts).
     * `2.0 RFID & Manual Attendance Management` (Dual-path capture, schedule verification, cutoff evaluation, 23:59 auto-absent cron $\rightarrow$ D2 Attendance & Rosters).
     * `3.0 Assessment, Classwork & Automated Grade Computation` (Activities, online quizzes with auto-checking, item analysis, DepEd 60-20-20 or subject weighting, quarterly transmutation $\rightarrow$ D3 Classwork & Assessments).
     * `4.0 Lesson Planning & Learning Materials Repository` (Curriculum competency alignment, lesson plan generator, file uploads $\rightarrow$ D4 Lesson Plans & Learning Materials).
     * `5.0 System Configuration & Academic Year Rollover` (Admin teacher provisioning, school year activation, system audit trail $\rightarrow$ D5 System Settings & Audit).

3. **Integrated UML Modeling for Activity #4**:
   - *ERD*: Must reflect the verified relational schema in `001_initial_schema.sql`, featuring primary/foreign key relationships, explicit cardinalities (1:1, 1:N, M:N resolved via bridge entities such as `parent_student_links`, `class_rosters`, `assessment_responses`), and typed columns.
   - *Use Case Diagram*: Covers actors (Admin, Teacher, Student, Parent, RFID Scanner). Features strict `<<include>>` (e.g., `Record Attendance` $\rightarrow$ `Scan RFID Tag`) and `<<extend>>` (e.g., `Record Attendance` $\rightarrow$ `Synchronize Offline Attendance`, `Take Assessment` $\rightarrow$ `Log Suspicious Activity Event`).
   - *Class Diagram*: Defines OOP model with abstract base class `User`, concrete role classes, typed attributes, visibility indicators (`+`, `-`, `#`), domain methods (`recordAttendance()`, `computeQuarterlyGrade()`, `syncOfflineLogs()`), and clear composition relationships (e.g. `Assessment` owns `Question`, `Activity` owns `Submission`).
   - *Object Diagram*: Depicts concrete runtime instances representing a live Friday morning session in Ma'am Karen P. Gonzaga's Grade 11 General Mathematics class at Eduardo Barretto Senior High School.

4. **Chapter 1–3 Diagram Alignment**:
   - *Figure 1 (IPSO)*: Explicit 4-stage pipeline (Input, Process, Storage, Output) with balanced spacing and reverse audit feedback arrows.
   - *Figure 2 (IPO)*: 3 aligned side columns with clear horizontal mapping and bottom dashed feedback loop.
   - *Figure 3 (Agile Scrum Framework)*: 4 proportional phases (Sprint 0 $\rightarrow$ Sprints $\rightarrow$ Review $\rightarrow$ Release) with sprint backlog refinement loop and purposive sampling note.
   - *Figure 5 (Context Diagram)*: Clean, professional Level 0 DFD matching Figure 1 of Activity #2.

5. **Diagram Generation Tooling Strategy**:
   - Because `matplotlib` and `graphviz` are absent from the local Python installation and native `dot.exe` is missing, relying on external Graphviz CLI would cause build failures.
   - However, `PIL` (Pillow) is already installed in Python 3.13!
   - Pillow provides programmatic canvas drawing (`ImageDraw.Draw`), anti-aliasing, rounded rectangles, font metric calculations via `font.getbbox(text)` (guaranteeing zero text clipping and dynamic bounding box expansion), high DPI export (300 DPI, 2400 to 3600 px wide), and full offline stability.
   - Alternatively, standalone SVG generation rendered via headless Microsoft Edge (`msedge.exe --headless --screenshot`) can be utilized as a secondary rendering engine.

---

## 3. Caveats

1. **Classmate Document Discrepancy**: The classmate files reference enrollment fees, cashiers, GCash, and OMR scanners. Under no circumstances should those entities be included in CLASSREALM deliverables.
2. **Admin Scope Enforcement**: As mandated by Capstone 1 constraints, the System Admin has zero access to manage sections, schedules, attendance, quizzes, or grades. The Admin only handles teacher account approval/provisioning and academic year rollover.
3. **Attendance Dual-Path Nature**: Attendance is offline-first via ESP32 RC522 hardware and Flutter mobile NFC fallback, whereas quiz/examination taking requires active internet connectivity.
4. **Tool Availability**: Graphviz is not installed. All diagram generation scripts must use either Python Pillow (`PIL`) directly or headless Microsoft Edge rendering of SVG/HTML to avoid missing dependency errors.

---

## 4. Conclusion & Complete System Models Specification

### 4.1 Activity #2: Requirements to Process Modeling Specification

#### Part A: Requirements Review
- **Table 1: Stakeholders and External Entities**:
  * `Admin`: System manager; teacher account creation/approval, status deactivation, school year rollover, system audit log monitoring.
  * `Teacher (Ma'am Karen P. Gonzaga)`: Primary academic user; section management, student roster enrollment, RFID card assignment, attendance capture, activity/assessment authoring, auto-grading, quarterly grade computation, lesson plan guide generation, learning materials repository.
  * `Student (Grade 11 Senior High)`: Primary system user; mobile app access to view personal attendance history, submit activity files, take digital quizzes/exams, view assessment scores and item feedback, view quarterly grades, access learning materials.
  * `Parent / Guardian`: Secondary system user; mobile app access to view linked child's attendance history, absence warning alerts, quarterly grades, and school announcements.
  * `ESP32 RC522 RFID Module`: External edge hardware entity; captures 13.56 MHz RFID card UID, transmits scan event over Wi-Fi/buffer, receives buzzer/LED status indicator.
  * `Firebase Authentication`: External identity provider; processes email/password auth, generates secure tokens, returns Firebase UID.
  * `Supabase Cloud Backend`: Cloud database & compute engine; enforces Row Level Security (RLS), stores synchronized records, executes 23:59 scheduled auto-absent cron job.

- **Table 2: Functional Requirements (FR1–FR10)**:
  * `FR1`: User Authentication & Role-Based Access Control (Admin, Teacher, Student, Parent).
  * `FR2`: Teacher Classroom & Section Management (sections, subjects, schedules, student rosters).
  * `FR3`: RFID Card Assignment & Management (mapping card UID to student with duplicate conflict prevention).
  * `FR4`: Dual-Path & Schedule-Guarded Attendance Recording (ESP32 RFID tap, mobile NFC tap, and permanent manual fallback; schedule window guarding; recording method indicator).
  * `FR5`: Automated 23:59 Absent Evaluation Job (marking unscanned students on scheduled class days).
  * `FR6`: Classwork & Requirement Management (activity authoring, student file upload submission, deadline status).
  * `FR7`: Digital Assessment & Automated Objective Item Scoring (quizzes/exams, multiple choice auto-checking, item analysis, suspicious activity event logging).
  * `FR8`: DepEd Grade Computation & Transmutation (teacher-configured weights, DepEd Order 8 s. 2015 transmutation tables, SF9/E-Class Record export).
  * `FR9`: Lesson Plan Guide Generator & Curriculum Repository (lesson plan template creation, competency tracking).
  * `FR10`: Centralized Learning Materials Repository (instructional file upload, categorizing, student download).

- **Table 3: User Stories (8 User Stories covering all 4 roles)**.

#### Part B: Process Modeling & DFD Hierarchy
- **Figure 1: Context Diagram (Level 0 DFD)**:
  * Central entity: `0 CLASSREALM`.
  * Connected to Admin, Teacher, Student, Parent, ESP32 RC522 Module, Firebase Auth, and Supabase Backend.
  * Directed arrows with complete payload labels (no generic "input/output" text).

- **Figure 2: Level 0 DFD (System Subsystem Decomposition)**:
  * Process 1.0: User Authentication & Role Verification (Linked to D1 User Accounts).
  * Process 2.0: RFID & Manual Attendance Management (Linked to D2 Attendance & Rosters, ESP32, Teacher, Student, Parent).
  * Process 3.0: Assessment, Classwork & Grade Computation (Linked to D3 Classwork & Assessments).
  * Process 4.0: Lesson Planning & Learning Materials Repository (Linked to D4 Lesson Plans & Materials).
  * Process 5.0: System Administration & Academic Configuration (Linked to D5 System Settings & Audit).

- **Level 1 Sub-Process Decompositions (Figures 3–7)**:
  * *1.0 User Authentication*:
    - 1.1 Process Login Credentials
    - 1.2 Verify Role & Session with Firebase Auth
    - 1.3 Manage Teacher Account Requests (Admin)
    - 1.4 Link Parent-Student Relationship
  * *2.0 Attendance Management*:
    - 2.1 Assign RFID Card to Student (Teacher/NFC/USB)
    - 2.2 Validate Class Schedule & Cutoff Window
    - 2.3 Record RFID Tap Event (ESP32 / NFC)
    - 2.4 Record Manual Attendance Override (Teacher)
    - 2.5 Synchronize Offline Attendance Buffer
    - 2.6 Execute 23:59 Auto-Absent Evaluation Job
    - 2.7 Generate Attendance Summaries & Absence Warning Alerts
  * *3.0 Assessment & Grade Computation*:
    - 3.1 Create Classwork & Activity Tasks
    - 3.2 Author Quizzes/Exams & Answer Keys
    - 3.3 Receive Student Submissions & Responses
    - 3.4 Auto-Check Objective Responses & Log Suspicious Events
    - 3.5 Calculate Weighted Components (Written Work, Performance Tasks, Quarterly Exam)
    - 3.6 Apply DepEd Transmutation Table & Generate E-Class Records
  * *4.0 Lesson Planning & Learning Materials*:
    - 4.1 Author Lesson Plan Guide & Map Curriculum Competencies
    - 4.2 Upload & Organize Learning Material Files
    - 4.3 Distribute Learning Resources to Student Portal
  * *5.0 Administration & Audit*:
    - 5.1 Provision & Approve Teacher Accounts
    - 5.2 Configure School Year & Semester Rollover
    - 5.3 Monitor System Health & Audit Event Trails

- **Table 4: DFD Sub-Process Hierarchy & Table 5: Data Stores to Database Tables**:
  * D1: `users`, `admin_profiles`, `teacher_profiles`, `teacher_settings`, `student_profiles`, `parent_profiles`, `parent_student_links`
  * D2: `sections`, `subjects`, `class_schedules`, `class_rosters`, `rfid_cards`, `attendance_logs`, `attendance_cutoffs`
  * D3: `activities`, `submissions`, `assessments`, `questions`, `assessment_sessions`, `assessment_responses`, `grading_components`, `quarterly_grades`
  * D4: `lesson_plans`, `learning_materials`
  * D5: `academic_years`, `audit_logs`, `notifications`

- **Part C: Validation (Tables 6 & 7)**: Complete Requirement-to-DFD Matrix and 9-point DFD Validation Checklist.

---

### 4.2 Activity #4: Integrated UML & Data Modeling Specification

#### Part A: Design Basis & Model Interconnection Matrix
- Table 1 defines the four views:
  * ERD: Data persistence, keys, and relational schema.
  * Use Case: Functional interactions and system boundaries.
  * Class Diagram: Object-oriented architecture, types, visibility, and methods.
  * Object Diagram: Runtime scenario instance snapshots with real data values.

#### Part B: Entity-Relationship Diagram (ERD) & Data Dictionary
- 16 Relational Entities with PK, FK, data types, nullability, and descriptions:
  * `USER` (id [PK], email, role, is_archived, created_at)
  * `ADMIN_PROFILE` (admin_id [PK, FK $\rightarrow$ USER.id], first_name, last_name)
  * `TEACHER_PROFILE` (teacher_id [PK, FK $\rightarrow$ USER.id], first_name, middle_name, last_name, gender)
  * `STUDENT_PROFILE` (student_id [PK, FK $\rightarrow$ USER.id], lrn, first_name, middle_name, last_name, grade_level)
  * `PARENT_PROFILE` (parent_id [PK, FK $\rightarrow$ USER.id], first_name, last_name, contact_number)
  * `PARENT_STUDENT_LINK` (id [PK], parent_id [FK], student_id [FK], relationship, is_verified)
  * `SECTION` (id [PK], name, grade_level, academic_year_id)
  * `CLASS_SCHEDULE` (id [PK], section_id [FK], subject_id [FK], day_of_week, start_time, end_time, room)
  * `RFID_CARD` (id [PK], card_uid [UNIQUE], student_id [FK], status, assigned_at)
  * `ATTENDANCE_LOG` (id [PK], student_id [FK], schedule_id [FK], date, scan_time, status, recording_method, sync_status)
  * `ACTIVITY` (id [PK], teacher_id [FK], section_id [FK], title, max_score, due_date)
  * `SUBMISSION` (id [PK], activity_id [FK], student_id [FK], submitted_at, file_url, score, status)
  * `ASSESSMENT` (id [PK], teacher_id [FK], section_id [FK], title, type, total_items, passing_score)
  * `QUESTION` (id [PK], assessment_id [FK], item_number, question_text, correct_answer, points)
  * `ASSESSMENT_RESPONSE` (id [PK], assessment_id [FK], student_id [FK], item_number, student_answer, is_correct, points_earned)
  * `QUARTERLY_GRADE` (id [PK], student_id [FK], subject_id [FK], quarter, written_score, pt_score, exam_score, initial_grade, transmuted_grade)
  * `LESSON_PLAN` (id [PK], teacher_id [FK], subject_id [FK], topic, week_number, learning_competencies, content)
  * `LEARNING_MATERIAL` (id [PK], teacher_id [FK], subject_id [FK], title, file_url, file_type, upload_date)
- Tables 11 & 12: Cardinalities and resolution of M:N relationships via associative entities.

#### Part C: Use Case Modeling
- Actors: `Admin`, `Teacher`, `Student`, `Parent`, and `ESP32 RFID Scanner`.
- Use Case Modules:
  * Authentication & User Provisioning (UC01–UC04)
  * Classroom, Section & RFID Setup (UC05–UC08)
  * Attendance Tracking & Auto-Status (UC09–UC14)
    - `Record Attendance` $\rightarrow$ `<<include>> Scan RFID Tag`
    - `Record Attendance` $\rightarrow$ `<<extend>> Synchronize Offline Attendance`
    - `Record Attendance` $\rightarrow$ `<<extend>> Override Manual Status`
  * Classwork & Assessment Operations (UC15–UC22)
    - `Take Assessment` $\rightarrow$ `<<extend>> Log Suspicious Activity Event`
    - `Take Assessment` $\rightarrow$ `<<include>> Auto-Check Objective Responses`
  * Grade Computation & DepEd Reporting (UC23–UC26)
    - `Compute Grades` $\rightarrow$ `<<include>> Configure Grading Components`
    - `Compute Grades` $\rightarrow$ `<<include>> Apply DepEd Transmutation Table`
  * Lesson Planning & Materials Organization (UC27–UC30)
- Tables 19–23: Detailed step-by-step specifications for core use cases.

#### Part D: Class Modeling
- Domain Class Diagram:
  * Abstract base class `User` with subclasses `Admin`, `Teacher`, `Student`, `Parent`.
  * Domain classes: `Section`, `Subject`, `Schedule`, `RfidCard`, `AttendanceLog`, `Activity`, `Submission`, `Assessment`, `Question`, `AssessmentResponse`, `GradingComponent`, `QuarterlyGrade`, `LessonPlan`, `LearningMaterial`, `Notification`.
  * Visibility modifiers (`+` public, `-` private, `#` protected).
  * Typed methods: e.g. `AttendanceLog.evaluateStatus(scanTime, schedule): Status`, `QuarterlyGrade.transmute(initialGrade): Int`, `Submission.submitFile(url): Void`.
  * Compositions: `Assessment` $\blacklozenge\text{---}$ `Question`, `Activity` $\blacklozenge\text{---}$ `Submission`.
- Tables 24–26: Class-to-Entity mapping matrix.

#### Part E: Concrete Runtime Object Diagram
- Concrete scenario representing Ma'am Karen P. Gonzaga's Grade 11 General Mathematics class at Eduardo Barretto Senior High School:
  * `t001:Teacher` $\rightarrow$ `fullName = "Karen P. Gonzaga"`, `department = "Mathematics"`, `approvalStatus = "Approved"`
  * `s001:Student` $\rightarrow$ `lrn = "123456789012"`, `fullName = "Juan Dela Cruz"`, `gradeLevel = "Grade 11"`
  * `p001:Parent` $\rightarrow$ `fullName = "Maria Dela Cruz"`, `contactNumber = "09171234567"`
  * `psl001:ParentStudentLink` $\rightarrow$ `relationship = "Mother"`, `isVerified = true`
  * `sec001:Section` $\rightarrow$ `name = "STEM 11-A"`, `gradeLevel = "Grade 11"`
  * `sch001:ClassSchedule` $\rightarrow$ `dayOfWeek = "Monday"`, `startTime = "07:30"`, `endTime = "08:30"`, `room = "Room 302"`
  * `rfid001:RFIDCard` $\rightarrow$ `cardUID = "E28011052000"`, `status = "Assigned"`
  * `att001:AttendanceLog` $\rightarrow$ `date = "2026-04-20"`, `scanTime = "07:22:15"`, `status = "Present"`, `recordingMethod = "RFID"`, `syncStatus = "Synced"`
  * `act001:Activity` $\rightarrow$ `title = "Problem Set 1: Rational Functions"`, `maxScore = 50`
  * `sub001:Submission` $\rightarrow$ `score = 48`, `status = "Graded"`, `submittedAt = "2026-04-24 16:30"`
  * `asm001:Assessment` $\rightarrow$ `title = "Quarter 1 Quiz 1"`, `type = "Quiz"`, `totalItems = 15`
  * `q001:Question` $\rightarrow$ `itemNumber = 1`, `points = 1`
  * `resp001:AssessmentResponse` $\rightarrow$ `studentAnswer = "B"`, `isCorrect = true`, `pointsEarned = 1`
  * `grd001:QuarterlyGrade` $\rightarrow$ `quarter = "Q1"`, `initialGrade = 91.2`, `transmutedGrade = 94`
  * `lp001:LessonPlan` $\rightarrow$ `topic = "Rational Functions and Equations"`, `weekNumber = 2`
  * `mat001:LearningMaterial` $\rightarrow$ `fileName = "Module2_Rational_Functions.pdf"`, `fileType = "PDF"`

#### Part F: Traceability, Checklist & Limits
- Table 27: Requirement-to-Model Traceability matrix.
- Table 28: Schema and Class Naming Consistency dictionary.
- Table 29: 10-point Design Review Checklist.
- Design Decisions and Boundaries:
  1. Offline attendance capture supported via ESP32 EEPROM/SPIFFS and Flutter Drift cache.
  2. Online connectivity required for assessment taking and instant auto-grading.
  3. Official DepEd E-Class Record and SF9 preserved and supported via CSV/PDF export.

---

### 4.3 Chapter 1–3 Diagrams Specification

| Diagram | Title | Key Elements & Structural Rules | Recommended Dimensions / Styling |
|---|---|---|---|
| **Figure 1** | Input-Process-Storage-Output (IPSO) Framework of CLASSREALM | 4 horizontal sequential stages: **Input** (Rosters, RFID taps, schedules, criteria) $\rightarrow$ **Process** (Auth, attendance guard, auto-grading, grade computation) $\rightarrow$ **Storage** (Supabase RLS DB, Drift+SQLite local DB, SPIFFS flash) $\rightarrow$ **Output** (Live logs, E-Class records, absence alerts, dashboards). Reverse dashed arrow: *Traceability & Error Auditing Feedback*. | 3200 $\times$ 1400 px, 300 DPI, Segoe UI font, Navy (#1E3A8A) / Emerald (#10B981) palette, rounded bounding boxes with 20px padding. |
| **Figure 2** | Input-Process-Output (IPO) Conceptual Framework | 3 aligned vertical side-columns: **Input** (Left: Teacher, Students, Parent, Admin, ESP32, Firebase), **Process** (Center: Auth Engine, Attendance Engine, Assessment Engine, Grade Engine, Lesson Repo), **Output** (Right: Live Rosters, Quiz Scores, Transmuted Grades, Lesson Guides, Dashboards). Bottom curved dashed arrow: *Corrective Data & Stakeholder Review Loop*. | 2800 $\times$ 1800 px, 300 DPI, side-column grid layout, consistent box heights, high-contrast text. |
| **Figure 3** | Agile Scrum Methodology Framework of CLASSREALM | 4 proportional horizontal phases: **Sprint 0** (Requirements & Backlog), **Sprint Iterations** (Bi-weekly Sprints 1–5), **Verification & Review** (Sprint Review, Retrospective, Purposive Client Sampling with Ma'am Karen Gonzaga), **System Release** (Acceptability & ISO 25010 Evaluation). Dashed feedback loop: *Continuous Backlog Refinement*. | 3200 $\times$ 1200 px, 300 DPI, clean chevron or phase-box flow, zero text cut-off, spacious margins. |
| **Figure 5** | Level 0 Context Diagram of CLASSREALM | Central circular or rounded-box process: `0 CLASSREALM`. 4 User Entities (Admin, Teacher, Student, Parent) + 3 External Automated Entities (ESP32 RC522 RFID Module, Firebase Auth, Supabase Cloud). All directed arrows labeled with explicit payload data (no redundant generic "input/output" text). | 3200 $\times$ 2200 px, 300 DPI, balanced radial or distributed layout, clear arrow heads, high readability. |

---

### 4.4 Diagram Generation Strategy & Recommendations

1. **Primary Tool Choice: Python Pillow (`PIL`) with Native Windows Typography**
   - **Availability**: Pillow is **already installed** in the system Python environment (`PIL installed`).
   - **Zero Dependency Risk**: Requires no external binaries, C-compilers, or package downloads.
   - **Pixel-Perfect Typography**: Uses Windows system TrueType fonts (`C:\Windows\Fonts\segoeui.ttf`, `segoeuib.ttf`, `calibri.ttf`).
   - **Dynamic Bounding Boxes**: Uses `font.getbbox(text)` to dynamically compute text bounding boxes and dynamically expand shapes, guaranteeing **zero text clipping** and perfectly centered text.
   - **Export Specs**: Renders high-resolution 300 DPI images (e.g. 3200 $\times$ 1800 px) with anti-aliasing (`ImageDraw`), professional modern styling (subtle drop-shadows, rounded rectangles with radius=16, border stroke=3, clean hex color themes).

2. **Secondary / Hybrid Tool Choice: Headless Microsoft Edge SVG Rendering**
   - **Availability**: Microsoft Edge is verified installed at `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`.
   - **Method**: Python script emits clean vector `.svg` or `.html` file with CSS Flexbox/Grid, and executes `msedge --headless --screenshot=output.png --window-size=3200,1800 input.html`.
   - **Advantage**: Native vector anti-aliasing and web-standards typography.

3. **Tool to Avoid**: Native Graphviz CLI (`dot.exe`) and `matplotlib` (both are missing and would trigger execution errors).

---

## 5. Verification Method

To independently verify the facts and models in this report:

1. **Verify Python Environment & Pillow Installation**:
   ```powershell
   $null | & 'C:\Users\Admin\AppData\Local\Programs\Python\Python313\python.exe' -c "import PIL; from PIL import Image, ImageDraw, ImageFont; print('Pillow OK:', PIL.__version__)"
   ```
   *Expected Result*: `Pillow OK: <version>` exits with code 0.

2. **Verify Database Entities Alignment**:
   Open and inspect `c:\Users\Admin\AndroidStudioProjects\class_realm01\supabase\migrations\001_initial_schema.sql` lines 36–150 and 500–800 to confirm all tables, columns, and foreign keys cited in Section 4.2 match the live database.

3. **Verify Reference Activities Structure**:
   Extract and inspect the XML headings of `c:\Users\Admin\Downloads\Activity#2_DFD (3).docx` and `c:\Users\Admin\Downloads\Activity#4_UML_Object.docx` to confirm the Part A–F structural alignment.

4. **Invalidation Conditions**:
   - If the instructor requires registrar or financial modules (which were proven to belong to the classmate's MOJ Catholic School project and not CLASSREALM).
   - If external Graphviz binaries are mandated without administrative installation.
