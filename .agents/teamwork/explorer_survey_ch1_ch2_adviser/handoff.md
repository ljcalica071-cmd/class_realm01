# Handoff Report: Technical & Pedagogical Survey of Adviser Notes, Rubrics, and Requirements for Chapters 1 & 2

- **Author**: Explorer 1 (`teamwork_explorer`)
- **Working Directory**: `c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_survey_ch1_ch2_adviser`
- **Target Deliverable**: Revision and Alignment of Chapters 1 & 2 for CLASSREALM in `c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx`
- **Date**: 2026-10-29T23:25:00Z

---

## 1. Observation

Direct examination of the authoritative project documents was conducted:
1. `SAD_FR_Thesis_Finals-Activity1_Chapter3.pdf` (Course Assessment Guide, Rubrics, Formatting Standards, Alignment Criteria by Subject Adviser / Course Coordinator).
2. `Group#20_Calica_Sanjuan_chapter1and2.docx (2) (1).pdf` (Previous Draft of Chapters 1 and 2, 18 pages).
3. `Group#20_Calica_Sanjuan_Activities.docx (1).pdf` (Previous Activities 1–4 Submissions: Requirements, DFDs, ERD, Use Case, Class, and Object Diagrams).
4. `c:\Users\Admin\Downloads\comment sheet.pdf` (Institutional Title Defense Panel Comment Sheet for Group No. 20).
5. `Master_Plan.md` and `Plan.md` (System Architecture, Client Fieldwork Intelligence, DepEd DO 15 s. 2026 E-Class Record alignment).

### Verbatim & Structural Findings from Primary Sources

#### A. Institutional & Formatting Baseline (`SAD_FR_Thesis_Finals-Activity1_Chapter3.pdf`, pp. 1–20)
- **Course & Institution**: SD-3102 System Analysis and Design, College of Computing Studies, Laguna University.
- **Strict Formatting Mandates (p. 15)**:
  - Margins: **Top: 1.6 in, Left: 1.6 in, Bottom: 1.2 in, Right: 1.4 in**.
  - Headings: **Arial 12 pt, Bold**. Narrative text: **Arial 11 pt, Regular**.
  - Chapter Title: `CHAPTER I` (or `CHAPTER II`) and the chapter title appear on separate lines on a new page.
  - Spacing: Body paragraphs use **0.5-inch first-line indent** and **0 pt spacing before and after**; strictly **no extra blank lines between body paragraphs**. One blank line precedes new headings.
  - Visual Elements: Table/Figure number is bold on its own line, followed by an *italic title* on the next line immediately above the visual. Table column headers are **UPPERCASE and bold**. Visuals must be centered.
  - Explanatory Text: Every table and figure must have a paragraph directly below it that explicitly cites and discusses its number and content.
  - Reference Citation: Strict **APA 7th edition** format, alphabetical ordering, and **0.5-inch hanging indent**.
- **Alignment Directive (pp. 8, 15)**:
  - Title and scope $\rightarrow$ Specific Objectives $\rightarrow$ Functional Requirements (FRs) $\rightarrow$ DFD processes and data stores $\rightarrow$ ERD/UML $\rightarrow$ Architecture/Screens $\rightarrow$ Testing and Evaluation.
  - Literature about an optional feature does **not** authorize scope expansion.

#### B. Deficiencies Identified in Previous Draft (`Group#20_Calica_Sanjuan_chapter1and2.docx (2) (1).pdf`)
1. **School & Client Misidentification**:
   - Previous draft (pp. 2, 5) designated the institution as *"Eduardo Barretto Senior Integrated School"* (misspelled with double 't') and client as *"Ms. Karen P. Gonzaga, a Senior High School Mathematics teacher handling Grade 11 students"*.
   - Authoritative Requirement: Pilot school is **Eduardo Barreto Sr. High School** (single 't', Sr. High School), and client is **Ma’am Karen P. Gonzaga, Senior High School Mathematics Teacher**.
2. **Ambiguous Role Boundaries & Admin Scope Creep**:
   - Previous draft (pp. 3, 5) defined the Admin interface vaguely without explaining *who* holds the Admin role.
   - Authoritative Requirement: The System Admin account is assigned strictly to the **client teacher** solely for **academic year transitions and teacher provisioning**. Admin has **no access** to manage sections, subjects, schedules, attendance, activities, requirements, quizzes, examinations, grading percentages, lesson plans, learning materials, or student academic records.
3. **Missing System Exclusions**:
   - The previous draft omitted formal boundaries regarding administrative roles and complex DepEd school workflows.
   - Authoritative Requirement: Explicitly exclude **Registrar** and **Principal** roles. Exclude **Transfer student**, **Transfer section**, and **Dropping student** workflows.
4. **Lack of SMART Criteria in Objectives**:
   - Specific Objectives in previous draft (pp. 4–5, Objectives 1–10) were purely qualitative statements (e.g., *"To develop an attendance module..."*, *"To provide quiz and examination functions..."*). None contained quantifiable targets, timing thresholds, or empirical performance indicators.
5. **Casual Treatment of Manual Attendance**:
   - In the previous draft, manual attendance was treated as an afterthought rather than a **permanent, mission-critical operational fallback** alongside RFID scanning.
6. **Generic, Dictionary-Style Definition of Terms**:
   - Definitions in previous draft (pp. 7–9) were superficial and non-technical (e.g., defining ESP32 merely as *"a microcontroller used in the proposed attendance setup to collect attendance data through an RFID reader"*).
   - Missing terms: **Row-Level Security (RLS)** was entirely absent; **Admin Portal**, **Teacher Portal**, **Student Portal**, and **Parent Portal** were absent as defined IT entities.
7. **Flawed Literature Review & Synthesis Matrix (Chapter 2)**:
   - Synthesis Matrix in previous draft (pp. 13–14) listed only 6 studies instead of the full set.
   - The "Research Gap Addressed" column relied on unsupported, negative blanket statements (e.g., *"Lacks integration with lesson planning and grades"*, *"Lacks robust teacher lesson planning tools"*, *"Lacks parent portal and performance insights"*).
   - Missing empirical evidence for core teacher workflows: No empirical studies supported the Teacher Lesson Planning guide generator or Learning Materials organizer.
   - Conceptual Framework inconsistency: Section 6.3 claimed an *"Input-Process-Storage-Output (IPSO)"* theoretical framework, while Section 6.4 switched to a 3-part *"Input-Process-Output (IPO)"* model without the required 4-part IPSO structure.

---

## 2. Logic Chain

From the observed evidence, the required revisions for Chapters 1 and 2 follow an interconnected logical chain:

### Step 1: Institutional & Client Grounding (Chapter 1)
- *Premise*: A capstone project must accurately reflect the client's actual organizational context and institutional environment.
- *Inference*: Updating the institutional name to **Eduardo Barreto Sr. High School** and the client to **Ma’am Karen P. Gonzaga, Senior High School Mathematics Teacher** eliminates factual contradictions with client interview data recorded in `Master_Plan.md` (§1.14).

### Step 2: Formalizing System Boundaries & Role Segregation
- *Premise*: Public high schools have rigid separation between departmental classroom instruction and institutional school governance. Furthermore, this software is commissioned specifically for classroom teachers, not the school division office.
- *Inference*: 
  1. The Admin account must be assigned to the client teacher solely for administrative infrastructure (academic year rollover and teacher provisioning). 
  2. To protect teacher instructional autonomy and prevent data corruption, Admin is hard-locked out of instructional data (sections, subjects, schedules, attendance, assignments, quizzes, grades, lesson plans, materials).
  3. Teachers self-manage sections, subjects, and students only *after* receiving official rosters from the registrar/school.
  4. Institutional governance roles (**Registrar**, **Principal**) are excluded.
  5. Mid-year section transfers (disallowed by school policy), student transfers, and formal dropping (which mandates DepEd home visitation and legal counseling) are strictly excluded from automated software execution.
  6. The system guarantees academic record preservation across school years and provides exportable/downloadable grade sheets.

### Step 3: Upgrading Objectives to Quantifiable SMART Targets
- *Premise*: Capstone defense rubrics (`SAD_FR_Thesis_Finals-Activity1_Chapter3.pdf`, Table 3, C1 & C4) penalize vague, unmeasurable objectives.
- *Inference*: Specific Objectives must incorporate dated, quantifiable performance thresholds for SY 2026–2027:
  - *Attendance*: RFID scan detection < 2.0 s, offline buffer $\ge$ 5,000 logs, 100% duplicate tap suppression, sync latency < 5.0 s.
  - *Assessment*: Instant auto-checking of objective items within < 1.0 s, automated item analysis within < 2.0 s, 100% mathematical conformity with DepEd DO 15, s. 2026 41-tier transmutation.
  - *Submissions*: Task caching with zero data loss, timestamp validation within $\pm$1.0 s, push alert delivery < 3.0 s.

### Step 4: Robust Offline-First Attendance & Fallback Architecture
- *Premise*: Pilot school classrooms experience frequent Wi-Fi drops and power interruptions.
- *Inference*:
  1. Standalone ESP32 hardware scanner and teacher mobile NFC scanning must buffer attendance records in local non-volatile storage (SPIFFS/NVS or Drift SQLite).
  2. Manual roster attendance is a permanent operational fallback: teachers can mark Present, Late, or Absent manually at any time.
  3. Conflict Resolution: A confirmed manual teacher override deterministically supersedes an automated RFID log.
  4. Duplicate scans are idempotent: subsequent taps in the same class session do not alter the initial arrival timestamp.
  5. Schedule Guarding: Scans outside active plotted class windows are blocked; an automated 23:59 cron job marks unscanned enrolled students as Absent without overwriting existing marks or triggering on holidays/weekends.

### Step 5: IT-Tailored Operational Definitions
- *Premise*: Software capstones require operational technical definitions rather than elementary dictionary entries.
- *Inference*: Definitions must be constructed directly around ClassRealm's technical architecture:
  - **ESP32**: Standalone dual-core Wi-Fi/BLE microcontroller interfacing with MFRC522 RFID reader, executing local non-volatile offline scan queuing.
  - **RFID**: Contactless 13.56 MHz / 125 kHz identification cards holding unique UIDs mapped to 12-digit DepEd Learner Reference Numbers (LRNs).
  - **Firebase Authentication**: Cloud identity provider handling encrypted password hashing, JWT token generation, and secure session management.
  - **Supabase**: Open-source PostgreSQL backend providing relational schema management, real-time replication, and server-side Edge Functions.
  - **Row-Level Security (RLS)**: PostgreSQL engine policies executing granular query filtering to isolate student records per teacher assignment and restrict parent views strictly to linked children.
  - **Admin Portal**: Restricted administrative web module for academic year creation and teacher credential provisioning.
  - **Teacher Portal**: Responsive web and tablet workspace for class roster self-management, schedule plotting, dual RFID/manual attendance, DepEd DO 15 grading, and lesson plan management.
  - **Student Portal**: Dedicated mobile app interface for students to monitor attendance logs, submit requirements, and view assessment scores.
  - **Parent Portal**: Dedicated read-only mobile app interface for parents to track attendance, missing tasks, and quarterly grades.

### Step 6: Empirical Literature Synthesis & Theoretical Alignment (Chapter 2)
- *Premise*: Capstone guidelines demand verifiable scholarship (2021–2026), full 10-study synthesis, elimination of unscientific "lacks" statements, and clear theoretical underpinning.
- *Inference*:
  1. Ground theoretical foundation in **DeLone & McLean (2003) Information Systems Success Model** (System Quality, Information Quality, Service Quality, Use, User Satisfaction, Net Benefits).
  2. Implement an explicit 4-part **IPSO (Input - Process - System - Output)** Conceptual Framework.
  3. Expand synthesis matrix to include all 10 studies (5 Philippine local, 5 international; 2021–2026) with objective columns: Author/Year, Title & Venue, Methodology, Sample Size/Profile, Key Findings, Alignment to ClassRealm.
  4. Ensure explicit empirical literature supports teacher lesson-planning and learning materials management workflows.

---

## 3. Caveats

1. **Academic Year & Curricular Nuance**: DepEd Order No. 015, s. 2026 mandates the Strengthened Senior High School (SSHS) curriculum with a trimester/term-based grading structure (Core 20/50/30, 41-tier transmutation). Chapter 1 and 2 narratives reflect these standards while acknowledging that official DepEd grading templates may receive further regional administrative issuances.
2. **Third-Party Telephony**: While push notifications and app alerts are integrated via Firebase Cloud Messaging, SMS notification delivery depends on hardware cellular gateways or third-party SMS API aggregators, which require active carrier credits.
3. **Anti-Cheat Monitoring Limitations**: The system monitors detectable in-app assessment session events (focus loss, screen switching). As formalized in the limitations, software monitoring cannot physically prevent students from consulting secondary external devices or collaborating in person.

---

## 4. Conclusion & Actionable Specifications

### 4.1 Chapter 1 Structural Blueprint

```markdown
# CHAPTER I
# INTRODUCTION

1.1 Project Context
- Pilot Institution: Eduardo Barreto Sr. High School (Brgy. Pansol, Calamba City, Laguna).
- Client: Ma’am Karen P. Gonzaga, Senior High School Mathematics Teacher.
- Operational Setting: Grade 11 Mathematics instruction (General Mathematics, Statistics and Probability).
- Existing Challenges: Manual paper index cards, fragmented spreadsheets, manual absence tallying, scattered Google Drive resources, manual DepEd E-Class Record encoding, limited classroom internet.

1.2 Purpose and Description
- Comprehensive multi-platform educational management system:
  * Teacher Portal (Web & Responsive Tablet/App)
  * Student Portal (Dedicated Mobile App)
  * Parent Portal (Dedicated Mobile App)
  * Admin Portal (Restricted Web Module)
  * Standalone ESP32 Hardware Attendance Scanner with NFC Mobile Fallback
- Integration of attendance, requirements, objective assessments, DepEd DO 15 s. 2026 grading, lesson planning guides, and learning resources.

1.3 Objectives of the Study
- General Objective: To design, develop, and evaluate CLASSREALM, an integrated educational management system with dual-path attendance, assessment checking, automated grading, lesson planning, and materials management for Eduardo Barreto Sr. High School.
- Specific Objectives (SMART Formulated):
  1. To construct an ESP32 RFID and mobile NFC attendance logging pipeline with permanent manual teacher fallback, achieving < 2.0 s tap latency, $\ge$ 5,000 offline buffer, and < 5.0 s cloud synchronization.
  2. To implement schedule-connected auto-status logic with teacher-defined cutoffs and a 23:59 server cron marking unscanned students as Absent without modifying existing marks.
  3. To develop an activity and requirement tracking module supporting student file submissions, deadline verification within $\pm$ 1.0 s, and push notification delivery within < 3.0 s.
  4. To implement an objective quiz/examination engine with automated checking within < 1.0 s and real-time item analysis calculation within < 2.0 s.
  5. To engineer a DepEd DO 15, s. 2026 grading engine that computes weighted scores rounded to 2 decimal places and transmates final grades using the 41-tier table with 100% accuracy.
  6. To construct a lesson plan guide generator and centralized learning material organizer for Grade 11 Mathematics teachers.
  7. To develop role-based Student and Parent mobile portals enforcing Supabase Row-Level Security (RLS) for confidential academic monitoring.
  8. To provide an Admin web portal restricted strictly to teacher provisioning and academic year transitions.
  9. To incorporate client-side assessment session event monitoring to log detectable window defocusing or app switching for teacher review.
  10. To evaluate the technical and operational acceptability of CLASSREALM using the ISO/IEC 25010:2023 product quality model among teachers, students, parents, and IT experts.

1.4 Scope and Limitations of the Study
- Scope:
  * Eduardo Barreto Sr. High School, client Ma’am Karen P. Gonzaga (Grade 11 Mathematics).
  * 4 user portals: Admin, Teacher, Student, Parent.
  * Hardware: ESP32 + RC522/PN532 RFID reader + buzzer/LEDs.
  * Dual-path offline attendance capture (ESP32 hardware + teacher phone NFC).
  * DepEd DO 15, s. 2026 grading engine (1-term, 2-term, 3-term offerings).
  * Grade record preservation and export (PDF, CSV, Excel).
- Strict Role Boundaries & Limitations:
  * Admin Account: Assigned to client teacher solely for academic year transitions and teacher provisioning.
  * Negative Admin Constraints: Admin CANNOT view or edit sections, subjects, schedules, attendance, assignments, quizzes, exams, grading weights, lesson plans, learning materials, or student academic records.
  * Teacher Roster Management: Teachers self-manage sections, subjects, and students after receiving official class rosters from the registrar/school.
  * Role Exclusions: The system strictly excludes Registrar and Principal user accounts.
  * Workflow Exclusions: Transfer student tracking, mid-year section switching, and formal dropping procedures are excluded from software automation.
  * Permanent Fallback: Manual attendance recording is permanently maintained in the teacher interface.
  * Quiz Connectivity: Online quizzes/exams require active internet connectivity.
  * Assessment Monitoring: Anti-cheat session tracking is limited to detectable software events and does not replace teacher proctoring.
  * Automated Grading Scope: Automatic scoring applies strictly to supported objective items; subjective/complex mathematical solutions require manual teacher grading.

1.5 Definition of Terms (IT-Tailored Operational Definitions)
- ESP32
- RFID (Radio Frequency Identification)
- Firebase Authentication
- Supabase
- Row-Level Security (RLS)
- Admin Portal
- Teacher Portal
- Student Portal
- Parent Portal
- DepEd DO 15, s. 2026 Electronic Class Record
- Offline-First Architecture
```

### 4.2 Operational Definitions Table

| Term | Operational IT-Tailored Definition |
|---|---|
| **ESP32** | A 32-bit dual-core microcontroller equipped with integrated 2.4 GHz Wi-Fi and Bluetooth connectivity, utilized in ClassRealm as a dedicated hardware scanner that interfaces with an RFID module to capture student card UIDs, validate timestamps, buffer scans in non-volatile flash memory during network outages, and synchronize attendance logs to the cloud. |
| **RFID (Radio Frequency Identification)** | A contactless wireless identification technology operating via electromagnetic fields (typically 13.56 MHz high frequency or 125 kHz low frequency) used in ClassRealm to instantly detect unique card identification codes (UIDs) linked to student Learner Reference Numbers (LRNs) for high-speed, contactless classroom attendance recording. |
| **Firebase Authentication** | A secure cloud identity service integrated into ClassRealm to manage user credential validation, encrypted password storage, JSON Web Token (JWT) issuance, and first-time temporary password resets for administrators, teachers, students, and parents. |
| **Supabase** | An open-source Backend-as-a-Service built on PostgreSQL, serving as ClassRealm’s primary relational database for persistent academic records, real-time data replication, automated scheduled cron jobs (Edge Functions), and backend security enforcement. |
| **Row-Level Security (RLS)** | A PostgreSQL database access-control mechanism implemented in Supabase that programmatically restricts database rows returned by queries based on the authenticated user's role and unique ID, ensuring teachers only access their assigned classes and students/parents only access their authorized records. |
| **Admin Portal** | A restricted web management interface assigned exclusively to the client teacher, scoped strictly to provisioning and activating teacher accounts, managing user lifecycles, and executing annual academic year rollovers, without access to classroom instructional data. |
| **Teacher Portal** | A comprehensive web and responsive desktop/tablet workspace empowering teachers to self-manage subject sections, plot class schedules, record attendance via dual RFID or permanent manual entry, administer quizzes, execute DepEd DO 15 grade calculations, generate lesson plans, and organize instructional materials. |
| **Student Portal** | A dedicated mobile application interface allowing authenticated learners to verify daily attendance timestamps, track deadlines, submit electronic assignments, take objective online quizzes, and view transmutated quarterly grades under strict RLS isolation. |
| **Parent Portal** | A dedicated view-only mobile application interface enabling authorized parents and legal guardians to monitor their linked child's real-time attendance status, unexcused absence warnings, pending academic requirements, and quarterly performance summaries. |

---

### 4.3 Chapter 2 Theoretical & Conceptual Framework Blueprint

#### Theoretical Framework: DeLone & McLean (2003) Information Systems Success Model
ClassRealm is theoretically anchored on the updated **DeLone and McLean Information Systems Success Model (2003)**, evaluating six interdependent constructs:
1. **System Quality**: Evaluates usability, response time, offline data persistence, hardware reliability (ESP32/RFID), and mobile responsiveness across Android devices.
2. **Information Quality**: Assesses accuracy, completeness, and timeliness of attendance logs, auto-checked quiz results, DepEd DO 15 transmutated grades, and lesson plan guides.
3. **Service Quality**: Evaluates role-appropriate interface reliability, Firebase authentication security, and deterministic offline-to-online data synchronization.
4. **System Use**: Measures active utilization of the Teacher Portal (daily attendance, grade entry), Student Portal (task submissions, quiz taking), and Parent Portal (progress monitoring).
5. **User Satisfaction**: Captures user perceptions of interface simplicity, reduction in clerical burden, and ease of academic tracking.
6. **Net Benefits**: Delivers tangible institutional improvements, including eliminated manual attendance tallying, error-free DepEd grade computation, centralized instructional assets, and increased parental engagement.

#### Conceptual Framework: 4-Part IPSO Model
```
┌────────────────────────────────┐       ┌────────────────────────────────┐
│             INPUT              │       │            PROCESS             │
│ • Client Requirements (G11)    │       │ • Academic Year & Role Setup   │
│ • Class Rosters & 12-digit LRN │       │ • Schedule-Gated RFID Scanning │
│ • Plotted Subject Schedules    │       │ • Offline Buffering & Sync     │
│ • RFID Card Unique IDs (UIDs)  │──────▶│ • Manual Attendance Fallback   │
│ • Quiz Items & Answer Keys     │       │ • Automated Assessment Checking│
│ • DepEd DO 15 Grading Criteria │       │ • Item Analysis Computation    │
│ • Lesson Exemplars & Resources │       │ • DepEd 41-Tier Transmutation  │
│ • Parental Authorization Links │       │ • Lesson Plan Guide Assembly   │
└────────────────────────────────┘       └────────────────────────────────┘
                                                           │
                                                           ▼
┌────────────────────────────────┐       ┌────────────────────────────────┐
│             OUTPUT             │       │             SYSTEM             │
│ • Validated Attendance Logs    │       │           CLASSREALM           │
│ • Real-time Attendance Alerts  │       │ • Admin Web Portal             │
│ • Missing Requirement Reports  │       │ • Teacher Web/Responsive App   │
│ • Item Difficulty Summaries    │◀──────│ • Student Mobile App (Flutter) │
│ • Computed E-Class Record (SF9)│       │ • Parent Mobile App (Flutter)  │
│ • Exported Grade Sheets (Excel)│       │ • ESP32 Hardware RFID Scanner  │
│ • Formatted Lesson Plan Guides │       │ • Supabase PostgreSQL & RLS    │
│ • Organized Materials Library  │       │ • Firebase Cloud Auth & FCM    │
└────────────────────────────────┘       └────────────────────────────────┘
```

#### Narrative Explanation of IPSO Framework:
1. **Input**: Encompasses raw instructional data and configuration parameters provided by stakeholders (official student rosters from registrar, plotted class timetables, student RFID UIDs, quiz items, DepEd DO 15, s. 2026 percentage distributions, and curriculum guides).
2. **Process**: Defines the operational logic, algorithms, and workflows executed by users and automated services (schedule-connected cutoff validation, ESP32 SPIFFS offline queuing, manual teacher override resolution, real-time quiz scoring, item discrimination calculation, running weighted score computation, and lesson plan drafting).
3. **System**: Represents the integrated hardware and software ecosystem—comprising the standalone ESP32 scanner, Flutter multi-platform application, Supabase PostgreSQL database protected by RLS, and Firebase identity management—that binds inputs and processes into a secure platform.
4. **Output**: Represents the tangible artifacts, metrics, and records generated for institutional use (official DepEd electronic class records, downloadable Excel/PDF grade sheets, daily attendance histories, absence alerts, item analysis reports, and structured lesson plan guides).

---

## 5. Verification Method

To verify full alignment of the revised Chapters 1 and 2:

1. **Document Inspection**:
   - Verify that `c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx` contains all revised sections conforming to the Arial 12/11 typography and 1.6"/1.6"/1.2"/1.4" margins specified in `SAD_FR_Thesis_Finals-Activity1_Chapter3.pdf`.
2. **Deficiency Resolution Audit**:
   - Check off each of the 7 itemized deficiency categories against the updated manuscript text.
   - Confirm Eduardo Barreto Sr. High School and Ma'am Karen P. Gonzaga are consistently identified.
   - Confirm Admin negative boundaries and exclusion of Registrar, Principal, Transfer, and Drop workflows are explicitly articulated in the Scope and Limitations.
3. **Definition Precision Check**:
   - Confirm that ESP32, RFID, Firebase Authentication, Supabase, Row-Level Security (RLS), Admin Portal, Teacher Portal, Student Portal, and Parent Portal have complete, operational, system-tailored definitions.
4. **Theoretical & Conceptual Framework Validation**:
   - Confirm DeLone & McLean (2003) is cited with complete publication year and mapped across its 6 dimensions.
   - Confirm the Conceptual Framework follows the 4-part IPSO diagram and narrative.
5. **Literature Synthesis Verification**:
   - Confirm the literature review and synthesis matrix contain exactly 10 authentic empirical studies (5 local, 5 international; 2021–2026) with working DOIs/URLs, documented sample sizes, and empirical metrics, free of unsupported "lacks" assertions.
