# Activity 2 Data and Content Module for CLASSREALM
# Adheres to Laguna University College of Computing Studies BSIT Capstone Standards

TABLE_1_HEADERS = ["ENTITY", "TYPE", "SYSTEM ROLE", "OPERATIONAL SCOPE & DATA EXCHANGE"]
TABLE_1_DATA = [
    [
        "System Administrator",
        "Human User",
        "System Infrastructure & Governance",
        "Provisions and validates teacher accounts; initiates academic year transitions and semester rollovers; monitors system-wide audit logs and service operational health. Admin has zero access to academic records, attendance marks, grading, or lesson plans."
    ],
    [
        "Teacher (Ma'am Karen P. Gonzaga)",
        "Human User",
        "Primary Academic Manager",
        "Creates and manages sections, subjects, and student rosters; pairs physical RFID cards to students; records attendance via hardware taps or manual roster override; authors classwork and digital assessments; computes quarterly grades via DepEd Order 8 s. 2015 / DO 15 s. 2026; generates lesson plans and organizes instructional materials."
    ],
    [
        "Student (Grade 11 Senior High)",
        "Human User",
        "Primary Academic Consumer",
        "Taps RFID card at ESP32 scanner upon classroom entry; accesses mobile/web portal to view personal attendance history, submitted classwork grades, and quarterly performance; takes digital quizzes with anti-cheating monitoring; downloads learning resources."
    ],
    [
        "Parent / Guardian",
        "Human User",
        "Academic & Attendance Monitor",
        "Monitors linked student attendance records via mobile portal; receives automated real-time alerts for absences and attendance warning milestones (e.g., 3 cumulative absences); reviews official quarterly grade summaries."
    ],
    [
        "ESP32 RC522 RFID Scanner",
        "Edge Hardware Entity",
        "Autonomous Edge Capture Device",
        "Scans 13.56 MHz RFID cards via MFRC522 SPI module; validates against local offline flash buffer (/spool/attendance_queue.jsonl); provides instantaneous audio/visual feedback cues (buzzer/LED); transmits batched scan events over HTTPS POST to Supabase RPC when Wi-Fi is active."
    ],
    [
        "Firebase Authentication",
        "External Cloud Service",
        "Identity Provider & Auth Gateway",
        "Manages user credential verification (email/password); issues secure JSON Web Tokens (JWT) containing user claims and Firebase UID; enforces multi-tier progressive brute-force rate limiting; handles password reset challenges."
    ],
    [
        "Supabase Cloud Backend",
        "External Cloud Service",
        "Relational Storage & Processing Engine",
        "Executes PostgreSQL database transactions protected by Row-Level Security (RLS); hosts attendance RPC functions; runs automated 23:59 daily cron jobs for automated absence generation; provides real-time WebSocket state distribution to connected teacher dashboards."
    ]
]

TABLE_2_HEADERS = ["REQ ID", "MODULE", "FUNCTIONAL REQUIREMENT STATEMENT", "INPUT TRIGGER / DATA", "OUTPUT / STORED ENTITY"]
TABLE_2_DATA = [
    [
        "FR1",
        "Authentication",
        "The system shall authenticate Admin, Teacher, Student, and Parent users using Firebase Authentication and authorize operations via Supabase Row-Level Security (RLS) based on verified system roles.",
        "Email credentials, password string, role token claim",
        "Authenticated user session, role-scoped JWT, access token, audit log entry"
    ],
    [
        "FR2",
        "Classroom Mgmt",
        "The system shall enable teachers to independently configure sections, subjects, plotted class schedules, and enroll student rosters received from the school registrar.",
        "Section name, grade level, subject code, schedule days/times, student names, LRNs",
        "D2: sections, subjects, class_schedules, class_rosters"
    ],
    [
        "FR3",
        "RFID Setup",
        "The system shall enable teachers to assign physical 13.56 MHz RFID card UIDs to students using either a USB desktop scanner or mobile NFC tap, preventing duplicate card assignments across the school.",
        "Student ID, physical card UID (hexadecimal format), scanner device tag",
        "D2: rfid_cards, student_profiles (rfid_uid), audit_logs"
    ],
    [
        "FR4",
        "Dual-Path Attendance",
        "The system shall record attendance through autonomous ESP32 RFID hardware taps, mobile NFC taps, and permanent teacher manual overrides, validating scans strictly against plotted class schedule windows.",
        "Card UID, tap timestamp [ISO 8601], device ID, schedule ID, manual status override",
        "D2: attendance_records (Present, Late, Absent, Excused), audio/visual cue signal"
    ],
    [
        "FR5",
        "Auto-Absent Engine",
        "The system shall execute an automated backend evaluation job at 23:59 daily to mark unscanned students as Absent only if an active class schedule existed on that date, skipping non-scheduled days and official school holidays.",
        "System clock trigger (23:59), active schedule registry, holiday calendar",
        "D2: attendance_records (System Auto-Absent records), absence alerts"
    ],
    [
        "FR6",
        "Classwork Mgmt",
        "The system shall allow teachers to author classwork activities with rubrics and deadlines, and permit students to submit document files with automated submission timestamp tracking.",
        "Activity title, description, max score, deadline, student uploaded file payload",
        "D3: activities, submissions, file attachments"
    ],
    [
        "FR7",
        "Digital Assessments",
        "The system shall support teacher authoring of timed digital quizzes and exams with automatic objective scoring (multiple choice), immediate feedback, and browser tab-blur anti-cheating event logging.",
        "Assessment title, question items, answer keys, timer duration, student response inputs",
        "D3: assessments, questions, assessment_responses, anti_cheating_logs"
    ],
    [
        "FR8",
        "Grade Computation",
        "The system shall compute weighted quarterly grades according to DepEd Order 8 s. 2015 / DO 15 s. 2026 (WW 20%, PT 50%, EX 30% for Senior High Core Subjects) and automatically apply official transmutation tables.",
        "Raw scores from activities, quizzes, and quarterly exams; teacher weight profile",
        "D3: quarterly_grades (Initial Grade, Transmuted Grade, Remarks: Passed/Failed)"
    ],
    [
        "FR9",
        "Lesson Planning",
        "The system shall provide an AI-assisted ILAW-structured lesson plan guide generator and curriculum repository aligned with DepEd Most Essential Learning Competencies (MELCs).",
        "Curriculum subject, grade level, topic title, learning competency code",
        "D4: lesson_plans (Introduction, Learning Competency, Activities, Wrap-up / ILAW)"
    ],
    [
        "FR10",
        "Learning Materials",
        "The system shall organize and store instructional handouts, lecture slides, and review documents in structured folders, providing authorized student access and download capabilities.",
        "Teacher uploaded files (PDF, DOCX), topic tags, subject offering ID",
        "D4: learning_materials, folders, secure download links"
    ]
]

TABLE_3_HEADERS = ["STORY ID", "ROLE", "USER STORY NARRATIVE", "ACCEPTANCE CRITERIA", "MAPPED FR"]
TABLE_3_DATA = [
    [
        "US-01",
        "Admin",
        "As an Administrator, I want to approve teacher account registrations and execute academic year rollovers, so that the school's operational framework remains secure and structured.",
        "Teacher accounts require email challenge verification before activation; year rollover archives prior classes without deleting historical records.",
        "FR1, FR2"
    ],
    [
        "US-02",
        "Teacher",
        "As a Teacher, I want to scan physical RFID cards to bind them uniquely to my enrolled students, so that daily classroom entry can be automated without manual roll calls.",
        "Duplicate card UID triggers friendly modal error; successfully assigned UID binds instantly to student record and syncs across web and mobile.",
        "FR2, FR3"
    ],
    [
        "US-03",
        "Teacher",
        "As a Teacher, I want the system to record student attendance automatically via RFID taps while letting me manually override marks, so that classroom management is flexible and accurate.",
        "Hardware taps evaluate against schedule cutoffs (Present/Late); manual teacher edits are permanently authoritative and cannot be overwritten by delayed taps.",
        "FR4"
    ],
    [
        "US-04",
        "Teacher",
        "As a Teacher, I want the system to auto-check objective quiz items and compute quarterly grades based on DepEd weighting, so that I can eliminate tedious grading calculations.",
        "Multiple-choice items are scored immediately upon submission; quarterly grades transmute accurately according to official DepEd Order 8 s. 2015 tables.",
        "FR7, FR8"
    ],
    [
        "US-05",
        "Teacher",
        "As a Teacher, I want to generate structured ILAW lesson plans and upload reviewer handouts, so that my instructional preparations and student materials are centralized.",
        "Lesson plan generator populates standard DepEd components; uploaded PDFs are categorized by topic and available for student download.",
        "FR9, FR10"
    ],
    [
        "US-06",
        "Student",
        "As a Student, I want to tap my RFID card at the classroom scanner and check my daily attendance and quiz results on my mobile app, so that I stay informed of my academic status.",
        "Hardware scanner triggers green LED/buzzer upon valid tap; student mobile portal displays real-time attendance badges and itemized quiz scores.",
        "FR1, FR4, FR7"
    ],
    [
        "US-07",
        "Student",
        "As a Student, I want to submit digital activity files before the set deadline, so that my classwork requirements are securely logged and evaluated.",
        "System records exact upload timestamp; displays submission confirmation badge; prevents file uploads after hard deadline unless teacher grants extension.",
        "FR6"
    ],
    [
        "US-08",
        "Parent",
        "As a Parent, I want to view my child's attendance history and receive immediate alerts when they are marked absent, so that I can ensure their safety and regular school attendance.",
        "Parent app displays child's presence percentage; sends automated notification when 3 absences accumulate; displays quarterly report cards.",
        "FR1, FR4, FR5, FR8"
    ]
]

TABLE_4_HEADERS = ["PROCESS ID", "PROCESS NAME", "SUB-PROCESSES INCLUDED", "SUBSYSTEM RESPONSIBILITY", "EXTERNAL INTERFACES"]
TABLE_4_DATA = [
    [
        "1.0",
        "User Authentication & Role Verification",
        "1.1 Process Login Credentials\n1.2 Verify Role & Session with Firebase Auth\n1.3 Manage Teacher Account Requests\n1.4 Link Parent-Student Relationship",
        "Manages user identity verification, token validation, role-based session establishment, administrative teacher provisioning, and parent-student relationship verification.",
        "Admin, Teacher, Student, Parent, Firebase Auth, D1 User Accounts"
    ],
    [
        "2.0",
        "RFID & Manual Attendance Management",
        "2.1 Assign RFID Card to Student\n2.2 Validate Schedule & Cutoff Window\n2.3 Record RFID Scan Event\n2.4 Record Manual Roster Override\n2.5 Synchronize Offline Attendance Buffer\n2.6 Execute 23:59 Auto-Absent Job\n2.7 Dispatch Absence Warning Alerts",
        "Captures RFID hardware taps and mobile NFC events, evaluates class schedule cutoffs, maintains local LittleFS/Drift buffers, executes scheduled daily auto-absent jobs, and dispatches absence alerts.",
        "Teacher, Student, Parent, ESP32 RC522 Scanner, D2 Attendance & Rosters, Supabase Cloud"
    ],
    [
        "3.0",
        "Assessment, Classwork & Grade Computation",
        "3.1 Author Classwork & Requirements\n3.2 Author Quizzes/Exams & Answer Keys\n3.3 Receive Student Submissions\n3.4 Auto-Check Objective Responses\n3.5 Calculate DepEd Weighted Components\n3.6 Apply Transmutation Table & Export SF9",
        "Handles classwork creation, student file uploads, timed digital assessments, anti-cheating telemetry logging, objective item auto-scoring, DepEd weighted aggregation, and quarterly grade transmutation.",
        "Teacher, Student, D3 Classwork & Assessments"
    ],
    [
        "4.0",
        "Lesson Planning & Materials Repository",
        "4.1 Author ILAW Lesson Plan Guide\n4.2 Map DepEd Curriculum Competencies\n4.3 Upload & Organize Materials\n4.4 Distribute Handouts to Students",
        "Provides curriculum competency management, AI-guided lesson plan drafting (ILAW framework: Introduction, Learning Competency, Activities, Wrap-up), and categorized learning materials organization.",
        "Teacher, Student, D4 Lesson Plans & Materials"
    ],
    [
        "5.0",
        "System Administration & Academic Configuration",
        "5.1 Provision & Approve Teacher Accounts\n5.2 Configure School Year & Term Rollover\n5.3 Monitor System Audit Event Trail",
        "Manages institutional settings, maintenance mode toggling, teacher account onboarding challenges, school year activations, and immutable security audit log tracking.",
        "Admin, D1 User Accounts, D5 System Settings & Audit"
    ]
]

TABLE_5_HEADERS = ["STORE ID", "DATA STORE NAME", "CORRESPONDING RELATIONAL TABLES", "STORAGE SCOPE & RETENTION POLICY"]
TABLE_5_DATA = [
    [
        "D1",
        "User Accounts & Profiles",
        "users, admin_profiles, teacher_profiles, teacher_settings, student_profiles, parent_profiles, parent_student_links",
        "Persists user authentication identities, role associations, biometric/LRN identifiers, and parental linkages. Retained across academic years with soft-archive flags."
    ],
    [
        "D2",
        "Attendance, Rosters & Hardware",
        "sections, subjects, subject_offerings, class_schedules, class_rosters, rfid_cards, attendance_records, attendance_cutoffs, school_holidays",
        "Stores classroom structures, plotted weekly timetables, student enrollments, registered RFID card UIDs, and daily timestamped attendance logs with recording source indicators."
    ],
    [
        "D3",
        "Classwork, Assessments & Grades",
        "activities, submissions, assessments, questions, assessment_responses, anti_cheating_logs, grading_components, quarterly_grades",
        "Stores instructional tasks, student file uploads, digital quiz item banks, student response strings, anti-cheating telemetry, component score weights, and official transmuted grades."
    ],
    [
        "D4",
        "Lesson Plans & Learning Materials",
        "lesson_plans, learning_materials, folders",
        "Stores teacher pedagogical lesson plans (ILAW format), DepEd MELC curriculum alignments, uploaded instructional document metadata, and binary file storage paths."
    ],
    [
        "D5",
        "System Settings & Audit Logs",
        "school_years, terms, system_settings, audit_logs, notifications, notification_recipients",
        "Maintains global application parameters, active school year markers, immutable administrative audit trails, and multi-channel system notification queues."
    ]
]

TABLE_6_HEADERS = ["REQ ID", "FUNCTIONAL REQUIREMENT NAME", "PRIMARY DFD PROCESS", "SUB-PROCESSES INVOLVED", "DATA STORES USED", "VERIFICATION TEST CASE"]
TABLE_6_DATA = [
    [
        "FR1",
        "User Authentication & Access Control",
        "1.0 User Authentication",
        "1.1, 1.2, 1.3, 1.4",
        "D1 User Accounts, D5 System Settings",
        "TC-AUTH-01: Login with valid credentials grants role-scoped dashboard; invalid credentials trigger inline error."
    ],
    [
        "FR2",
        "Classroom & Section Management",
        "2.0 Attendance Management",
        "2.1, 2.2",
        "D2 Attendance & Rosters",
        "TC-CLS-01: Teacher successfully creates Grade 11 STEM section, attaches subjects, and plots weekly schedules."
    ],
    [
        "FR3",
        "Teacher RFID Card Assignment",
        "2.0 Attendance Management",
        "2.1",
        "D2 Attendance & Rosters, D1 User Accounts",
        "TC-RFID-01: Assign UID '04:5A:B2:1A' to student Juan Dela Cruz. Duplicate scan of same UID triggers modal conflict alert."
    ],
    [
        "FR4",
        "Schedule-Guarded Dual-Path Attendance",
        "2.0 Attendance Management",
        "2.2, 2.3, 2.4, 2.5",
        "D2 Attendance & Rosters",
        "TC-ATT-01: ESP32 hardware scan within class window logs 'Present'; scan after cutoff logs 'Late'; manual edit overrides mark."
    ],
    [
        "FR5",
        "Automated 23:59 Absent Evaluation Job",
        "2.0 Attendance Management",
        "2.6, 2.7",
        "D2 Attendance & Rosters, D5 System Settings",
        "TC-CRON-01: At 23:59, unscanned students in scheduled classes marked 'Absent'; non-scheduled classes/holidays skipped."
    ],
    [
        "FR6",
        "Classwork Requirement Publishing",
        "3.0 Assessment & Grades",
        "3.1, 3.3",
        "D3 Classwork & Assessments",
        "TC-CW-01: Teacher authors assignment; student uploads PDF before deadline; status displays 'Submitted On-Time'."
    ],
    [
        "FR7",
        "Digital Assessment & Auto-Scoring",
        "3.0 Assessment & Grades",
        "3.2, 3.4",
        "D3 Classwork & Assessments",
        "TC-ASM-01: Student completes 15-item quiz; multiple-choice auto-scores 15/15; tab-blur event logs warning entry."
    ],
    [
        "FR8",
        "DepEd Grade Computation & Transmutation",
        "3.0 Assessment & Grades",
        "3.5, 3.6",
        "D3 Classwork & Assessments",
        "TC-GRD-01: Raw score 91.2% in Senior High Core Subject transmutes accurately to 94 using DepEd DO 8 s. 2015 tables."
    ],
    [
        "FR9",
        "ILAW Lesson Plan Guide Generator",
        "4.0 Lesson Planning & Materials",
        "4.1, 4.2",
        "D4 Lesson Plans & Materials",
        "TC-LP-01: Teacher generates 4-part ILAW lesson plan for 'Rational Functions' with mapped MELC competency codes."
    ],
    [
        "FR10",
        "Learning Materials Repository",
        "4.0 Lesson Planning & Materials",
        "4.3, 4.4",
        "D4 Lesson Plans & Materials",
        "TC-MAT-01: Teacher uploads 'Module2_Functions.pdf'; student portal displays file under correct topic folder for download."
    ]
]

TABLE_7_HEADERS = ["RULE NO.", "GANE-SARSON DFD VALIDATION CRITERION", "RESULT", "VERIFICATION EVIDENCE IN CLASSREALM PROCESS MODEL"]
TABLE_7_DATA = [
    [
        "1",
        "Conservation of Data (Input vs. Output Sufficiency)",
        "PASS",
        "Every process receives all necessary input data flows required to produce its corresponding outputs. For example, Process 2.3 receives Card UID from ESP32 and Schedule Cutoffs from D2 to produce valid Attendance Records."
    ],
    [
        "2",
        "No Black Holes (Processes with Inputs but Zero Outputs)",
        "PASS",
        "All processes in Level 0 and Level 1 DFDs produce at least one output data flow directed to an external entity, another process, or a data store. No sinks exist."
    ],
    [
        "3",
        "No Miracles (Processes with Outputs but Zero Inputs)",
        "PASS",
        "No process spontaneously generates data without adequate source inputs. Even scheduled batch processes (e.g., 2.6 Auto-Absent) are triggered by system clock events and read schedule/roster data from D2."
    ],
    [
        "4",
        "No Direct Entity-to-Entity Data Flows",
        "PASS",
        "External entities never exchange data directly with each other without traversing a system process. All human and hardware communications are brokered by CLASSREALM processes."
    ],
    [
        "5",
        "No Direct Entity-to-Data-Store Connections",
        "PASS",
        "External entities never read or write directly to data stores. All read/write operations are mediated through authenticated and authorized process logic (e.g., Supabase RLS)."
    ],
    [
        "6",
        "No Direct Store-to-Store Data Flows",
        "PASS",
        "Data stores never transfer data directly to other data stores. Cross-store data aggregation is performed by intermediate processes (e.g., Process 3.5 reads D2 rosters and writes D3 grades)."
    ],
    [
        "7",
        "Parent-to-Child Flow Balancing (Level 0 vs. Level 1)",
        "PASS",
        "All input and output data flows connected to Process 2.0 at Level 0 correspond directly to the net external interfaces of sub-processes 2.1 through 2.7 in the decomposed Level 1 DFD."
    ],
    [
        "8",
        "Standardized Gane & Sarson Graphic Notation",
        "PASS",
        "All diagrams strictly use open-ended rectangles for data stores (D1–D5), rounded shapes/ellipses for processes, solid rectangles for external entities, and labeled directed vectors for data flows."
    ],
    [
        "9",
        "Absence of Generic Labels & Extraneous School Artifacts",
        "PASS",
        "Every data flow carries a domain-specific payload label (e.g., 'Card UID & Tap Timestamp [ISO 8601]'). No generic 'input/output' labels exist, and zero irrelevant external school artifacts (financial billing, payment accounting, optical mark sheets) appear."
    ]
]
