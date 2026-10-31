import os
import shutil
import zipfile
import xml.etree.ElementTree as ET
from docx import Document
from docx.shared import Inches, Pt
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

# File paths
TARGET_DOCX = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED_SENIOR_HIGH_SCHOOL_ATTENDANCE_CH1_CH2_CH3.docx"
BACKUP_DOCX = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_m2_capstone\INTEGRATED_BACKUP.docx"
TEMP_DOCX = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_m2_capstone\temp_revised.docx"
FINAL_COMPILED_DOCX = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_m2_capstone\final_compiled.docx"
DIAGRAMS_DIR = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\docs\diagrams"

# Backup original
if not os.path.exists(BACKUP_DOCX):
    shutil.copy2(TARGET_DOCX, BACKUP_DOCX)
    print(f"Backed up original file to: {BACKUP_DOCX}")

import io
with open(BACKUP_DOCX, 'rb') as f:
    doc_bytes = io.BytesIO(f.read())
doc = Document(doc_bytes)

def format_para(p, text, is_bold=False, is_italic=False, align=WD_ALIGN_PARAGRAPH.JUSTIFY, first_line_indent=0.5, line_spacing=1.5, space_before=0, space_after=0):
    p.text = ""
    run = p.add_run(text)
    run.font.name = "Arial"
    run.font.size = Pt(12)
    run.bold = is_bold
    run.italic = is_italic
    p.alignment = align
    pf = p.paragraph_format
    pf.line_spacing = line_spacing
    pf.first_line_indent = Inches(first_line_indent)
    pf.space_before = Pt(space_before)
    pf.space_after = Pt(space_after)
    
    # XML enforcement
    pPr = p._p.get_or_add_pPr()
    spacing = pPr.find(qn('w:spacing'))
    if spacing is None:
        spacing = OxmlElement('w:spacing')
        pPr.append(spacing)
    spacing.set(qn('w:line'), str(int(line_spacing * 240)))
    spacing.set(qn('w:lineRule'), 'auto')
    spacing.set(qn('w:before'), str(int(space_before * 20)))
    spacing.set(qn('w:after'), str(int(space_after * 20)))
    
    ind = pPr.find(qn('w:ind'))
    if ind is None:
        ind = OxmlElement('w:ind')
        pPr.append(ind)
    ind.set(qn('w:firstLine'), str(int(first_line_indent * 1440)))
    if first_line_indent == 0:
        if qn('w:firstLine') in ind.attrib:
            del ind.attrib[qn('w:firstLine')]

    rPr = run._r.get_or_add_rPr()
    rFonts = rPr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = OxmlElement('w:rFonts')
        rPr.append(rFonts)
    rFonts.set(qn('w:ascii'), 'Arial')
    rFonts.set(qn('w:hAnsi'), 'Arial')
    rFonts.set(qn('w:cs'), 'Arial')

# ==============================================================================
# 1. CHAPTER 1 CONDENSATION
# ==============================================================================
print("Applying Chapter 1 revisions...")

# 1.1 Project Context (P31 to P34)
ch1_1_paras = [
    "In the Philippine basic education system, Senior High School (SHS) teachers balance classroom instruction with extensive administrative reporting. At Eduardo Barreto Sr. High School in Barangay Pansol, Calamba City, Laguna, teachers manage large classes across multiple sections, creating significant administrative demands during daily instruction.",
    "The client for this project is Ma’am Karen P. Gonzaga, a Senior High School Mathematics Teacher at Eduardo Barreto Sr. High School who teaches Grade 11 General Mathematics and Statistics and Probability. Daily attendance in her classes is recorded manually using paper sheets or index cards. For classes of 40 to 50 students, roll calls take 10 to 15 minutes of each 60-minute period. Paper records can be lost, damaged, or marked by proxy, and compiling attendance summaries at the end of each quarter requires laborious manual counting.",
    "Similar delays affect assignment tracking and grading. Student submissions for written works and performance tasks are recorded across separate paper notebooks and disconnected digital drives. Calculating quarterly grades under Department of Education (DepEd) Order No. 015, s. 2026 requires weighted calculations for Written Work, Performance Tasks, and Quarterly Assessments, followed by transmutation through an official 41-tier table. Doing this manually on paper or basic spreadsheets often leads to calculation errors and delays official DepEd Electronic Class Record submission.",
    "Teachers also spend substantial non-teaching hours preparing weekly lesson plans and sorting instructional files scattered across flash drives. Communication with parents occurs primarily during end-of-quarter meetings, leaving parents unaware of attendance issues or falling grades. An integrated management system resolves these connected operational challenges."
]
for idx, text in enumerate(ch1_1_paras):
    format_para(doc.paragraphs[31 + idx], text, first_line_indent=0.5)

# 1.2 Purpose and Description (P36 to P43)
format_para(doc.paragraphs[36], "The primary purpose of this capstone project is to develop and implement CLASSREALM (Comprehensive Learning and Academic Student Supervision Realm), an integrated educational management system for Eduardo Barreto Sr. High School. The system unifies attendance tracking, assignment submission, objective quiz grading, DepEd DO 15, s. 2026 grade calculation, lesson plan guide generation, and learning materials organization into a cohesive platform.", first_line_indent=0.5)
format_para(doc.paragraphs[37], "CLASSREALM provides four role-governed user portals tailored to school stakeholders:", first_line_indent=0.5)
format_para(doc.paragraphs[38], "1. Admin Portal (Web): A restricted web interface used by the client teacher solely for academic year transitions and teacher account creation, with zero access to student grades or instructional records.", first_line_indent=0.5)
format_para(doc.paragraphs[39], "2. Teacher Portal (Responsive Web App): A comprehensive workspace where teachers manage sections, plot schedules, record attendance via RFID tap or manual roster entry, administer quizzes, compute DepEd DO 15 grades, generate lesson plan guides, and share learning resources.", first_line_indent=0.5)
format_para(doc.paragraphs[40], "3. Student Portal (Mobile App): A secure mobile application giving students view-only access to personal attendance records, assignment marks, online quizzes, and learning materials.", first_line_indent=0.5)
format_para(doc.paragraphs[41], "4. Parent Portal (Mobile App): A mobile application allowing parents to view their child's daily attendance, receive alerts for three or more unexcused absences, track deadlines, and view quarterly grades.", first_line_indent=0.5)
format_para(doc.paragraphs[42], "To maintain continuous operation during network interruptions, CLASSREALM implements a dual-path attendance system. A standalone ESP32 hardware scanner with an RC522 RFID reader captures student card taps and buffers them in local non-volatile flash memory during offline periods, syncing automatically once connectivity returns. A manual digital roster is permanently maintained as a reliable operational fallback.", first_line_indent=0.5)
format_para(doc.paragraphs[43], "Beyond attendance, the system automates DepEd DO 15 grade calculations with 41-tier transmutation, exports official class records, generates Grade 11 Mathematics lesson plan guides, and manages digital files in a centralized repository.", first_line_indent=0.5)

# 1.3 Objectives of the Study (P46, P48 to P58)
format_para(doc.paragraphs[46], "The general objective of this study is to design, develop, implement, and evaluate CLASSREALM, an integrated educational management system for Eduardo Barreto Sr. High School, providing automated dual-path attendance tracking, objective assessment grading, DepEd DO 15, s. 2026 grade computation, teacher lesson planning support, and role-governed portals for enhanced classroom administration.", first_line_indent=0.5)
format_para(doc.paragraphs[48], "To achieve the general objective, the study aims to accomplish the following specific objectives during School Year 2026–2027:", first_line_indent=0.5)

sp_objs = [
    "1. Dual-Path Attendance Ingestion Pipeline: To build an attendance capture system combining a standalone ESP32 RFID scanner with a permanent manual teacher roster fallback, achieving a card tap detection latency under 2.0 seconds, an offline buffer capacity of at least 5,000 records, and cloud synchronization within 5.0 seconds upon reconnection.",
    "2. Schedule-Bound Auto-Status Engine: To develop an automated attendance engine bound to class schedules, enforcing teacher-set cutoff windows (Present, Late, Absent) and running a scheduled 23:59 serverless job (Supabase Edge Function) that marks unscanned enrolled students as Absent without overwriting existing marks or triggering on holidays.",
    "3. Activity and Requirement Tracking: To implement an assignment tracking module supporting file uploads with deadline verification within ±1.0 second, while delivering real-time mobile push notifications to students and parents within 3.0 seconds.",
    "4. Objective Assessment and Item Analysis: To create an online quiz engine supporting multiple choice, true/false, and identification formats, delivering automated scoring within 1.0 second and psychometric item analysis (difficulty and discrimination indices) within 2.0 seconds.",
    "5. DepEd DO 15, s. 2026 Grading Engine: To develop an automated grading engine adhering to DepEd Order No. 015, s. 2026 (Written Work 20%, Performance Tasks 50%, Quarterly Exam 30%), validating that weights equal 100%, rounding initial scores to two decimal places, and transmuting grades using the official 41-tier table with 100% mathematical accuracy.",
    "6. Teacher Lesson Plan Guide Generator: To design an interactive lesson plan generator that scaffolds DepEd-aligned lesson plans for Grade 11 Mathematics, reducing drafting time by at least 50% while preserving teacher editorial control.",
    "7. Centralized Learning Materials Organizer: To create a centralized repository for organizing and distributing instructional resources, ensuring role-governed student downloads with zero retrieval failures.",
    "8. Role-Governed Portals and Data Isolation: To develop dedicated Student and Parent mobile applications with Supabase Row-Level Security (RLS), ensuring users view only authorized personal records with 100% data isolation.",
    "9. Restricted Admin Portal: To build a restricted administrative web portal for the client teacher to manage academic year rollovers and teacher accounts, with zero access to student grades or instructional records.",
    "10. System Acceptability Evaluation: To evaluate the technical and operational quality of CLASSREALM using the ISO/IEC 25010:2023 product quality model across its nine characteristics among teachers, students, parents, and IT experts, targeting an overall weighted mean of at least 4.20 out of 5.00 (\"Highly Acceptable\")."
]
for idx, text in enumerate(sp_objs):
    format_para(doc.paragraphs[49 + idx], text, first_line_indent=0.5)

# 1.4.1 Scope of the Study (P61 to P67)
format_para(doc.paragraphs[61], "This study focuses on Eduardo Barreto Sr. High School in Barangay Pansol, Calamba City, Laguna, during School Year 2026–2027. The client is Ma’am Karen P. Gonzaga, a Senior High School Mathematics Teacher handling three Grade 11 sections in General Mathematics and Statistics and Probability, totaling 65 students. The primary beneficiaries are these Grade 11 students, their parents, and the client teacher. While initially deployed for a single teacher, the system architecture supports scaling to multiple teachers, subjects, and sections.", first_line_indent=0.5)
format_para(doc.paragraphs[62], "The software includes four role-governed portals:", first_line_indent=0.5)
format_para(doc.paragraphs[63], "• Admin Portal (Web): Manages academic year rollovers and teacher account creation.", first_line_indent=0.5)
format_para(doc.paragraphs[64], "• Teacher Portal (Responsive Web App): Manages rosters, schedules, RFID and manual attendance, assignments, quizzes, DepEd DO 15 grading, lesson plans, and instructional files.", first_line_indent=0.5)
format_para(doc.paragraphs[65], "• Student Portal (Mobile App): Displays personal attendance, grades, quizzes, and learning materials.", first_line_indent=0.5)
format_para(doc.paragraphs[66], "• Parent Portal (Mobile App): Displays child attendance logs, absence alerts (for three or more absences), deadlines, and quarterly grades.", first_line_indent=0.5)
format_para(doc.paragraphs[67], "The hardware includes a standalone ESP32 scanner with an RC522 RFID reader and offline flash buffering. The platform uses Flutter for client interfaces, Supabase PostgreSQL with Row-Level Security for persistent storage, and Firebase Authentication for access control. The system preserves historical records and exports grades to PDF, Excel, and CSV formats.", first_line_indent=0.5)

# 1.4.2 Boundaries and Limitations (P69 to P78)
format_para(doc.paragraphs[69], "To maintain institutional compliance and data security, the study defines the following operational boundaries:", first_line_indent=0.5)
boundaries = [
    "1. System Admin Boundaries: The Admin role is assigned to the client teacher solely for academic year rollovers and teacher provisioning. The Admin cannot access or modify sections, subjects, schedules, attendance, assignments, quizzes, grading, lesson plans, learning materials, or student academic records.",
    "2. Teacher Roster Self-Management: Teachers self-manage their class sections, subjects, and student enrollments after receiving official rosters from the school registrar.",
    "3. Excluded Institutional Roles: The system excludes Registrar and Principal user accounts, roles, and administrative dashboards.",
    "4. Excluded Student Workflows: Mid-year student transfers, section changes, and formal dropping procedures are excluded from the software, as DepEd requires official counseling and administrative documentation before a teacher updates the class roster manually.",
    "5. Permanent Manual Attendance Fallback: Manual attendance logging is a permanent operational feature alongside RFID scanning, ensuring uninterrupted tracking during forgotten card instances or hardware issues.",
    "6. Assessment Network Dependency: Online quizzes require active internet connectivity for real-time validation and security; offline test-taking is excluded.",
    "7. Automated Scoring Boundaries: Automated checking is restricted to objective items (multiple choice, true/false, identification). Subjective problem-solving and mathematical proofs require manual teacher grading.",
    "8. Anti-Cheat Monitoring Boundaries: The system logs tab-blur and window switching events to flag potential infractions, but cannot prevent students from consulting physical materials during remote assessments.",
    "9. Notification Delivery: Alerts are delivered via Firebase Cloud Messaging push notifications; cellular SMS delivery depends on third-party carrier coverage and credits."
]
for idx, text in enumerate(boundaries):
    format_para(doc.paragraphs[70 + idx], text, first_line_indent=0.5)

# 1.5 Quantifiable SMART Evaluation Criteria (P80 to P88)
format_para(doc.paragraphs[80], "To evaluate the technical performance and user acceptability of CLASSREALM during School Year 2026–2027, the system is measured against the following quantifiable criteria:", first_line_indent=0.5)
smart_criteria = [
    "• Attendance Tap Latency: RFID card detection and audiovisual feedback occur within less than 2.0 seconds on the standalone ESP32 scanner.",
    "• Offline Buffer Capacity: The scanner retains at least 5,000 attendance records in local non-volatile flash memory during network outages.",
    "• Duplicate Scan Suppression: 100% suppression of duplicate card taps within the same class session, preventing altered timestamps or downgraded statuses.",
    "• Cloud Synchronization Speed: Buffered offline logs synchronize with Supabase within less than 5.0 seconds upon network restoration.",
    "• Assessment Turnaround: Objective quiz scoring completes in less than 1.0 second, and item analysis (difficulty and discrimination indices) calculates within less than 2.0 seconds.",
    "• Grading Precision: 100% mathematical accuracy under DepEd Order No. 015, s. 2026, rounding initial scores to two decimal places and transmuting grades through the official 41-tier table with zero calculation error.",
    "• Notification Dispatch Speed: Absence alerts and requirement notifications deliver to mobile devices within less than 3.0 seconds.",
    "• ISO/IEC 25010:2023 Technical Quality: Attainment of an overall weighted mean score of at least 4.20 out of 5.00 (\"Highly Acceptable\") across all nine software quality characteristics."
]
for idx, text in enumerate(smart_criteria):
    format_para(doc.paragraphs[81 + idx], text, first_line_indent=0.5)

# 1.6 Definition of Terms (P90 to P99)
format_para(doc.paragraphs[90], "To provide operational clarity within CLASSREALM’s software and hardware architecture, the following terms are defined:", first_line_indent=0.5)
terms = [
    "1. ESP32: A 32-bit dual-core microcontroller with built-in Wi-Fi and Bluetooth, used in CLASSREALM as a standalone door scanner that captures RFID taps, buffers records in flash memory during outages, and synchronizes logs to the cloud.",
    "2. RFID (Radio Frequency Identification): A wireless technology operating at 13.56 MHz, used in CLASSREALM to read student card identification numbers mapped to 12-digit Learner Reference Numbers (LRNs) for rapid classroom attendance logging.",
    "3. Firebase Authentication: A cloud identity service integrated into CLASSREALM to handle secure user authentication, password encryption, JSON Web Token (JWT) management, and role-based credential verification.",
    "4. Supabase: An open-source backend platform built on PostgreSQL, serving as CLASSREALM’s primary database for persistent student records, scheduled Edge Functions, and database-level security.",
    "5. Row-Level Security (RLS): A PostgreSQL access-control feature in Supabase that restricts database row access based on user role and identity, ensuring teachers view only their classes and students and parents access only authorized personal records.",
    "6. Admin Portal: A restricted web interface used by the client teacher solely for academic year transitions and teacher provisioning, with no access to student grades or instructional records.",
    "7. Teacher Portal: A responsive web workspace allowing teachers to manage rosters, configure schedules, track attendance via RFID or manual roster, grade quizzes, compute DepEd DO 15 grades, generate lesson plans, and distribute materials.",
    "8. Student Portal: A mobile application providing enrolled learners with secure, view-only access to their attendance records, assignment grades, objective quizzes, and downloadable learning files.",
    "9. Parent Portal: A mobile application enabling verified parents to monitor child attendance, receive absence warning alerts for three or more unexcused absences, track deadlines, and view quarterly grades."
]
for idx, text in enumerate(terms):
    format_para(doc.paragraphs[91 + idx], text, first_line_indent=0.5)

# ==============================================================================
# 2. CHAPTER 2 CONDENSATION
# ==============================================================================
print("Applying Chapter 2 revisions...")

# 2.1.1 Automated and Dual-Path Attendance Tracking Systems (P106 to P110)
format_para(doc.paragraphs[106], "Automated attendance tracking reduces instructional time lost to roll calls and prevents recording errors. In a Philippine study, Holgado et al. (2026) evaluated an automated attendance system using Ultra High Frequency (UHF) RFID and a Raspberry Pi at Colegio de San Juan de Letran Manila. Their results demonstrated a 93.3% RFID detection accuracy during walk-through transit and a 100% success rate in backend database logging, with faculty rating software usability and hardware reliability as \"Strongly Agree.\" Contactless RFID identification effectively removes classroom queuing and administrative roll-call delays.", first_line_indent=0.5)
format_para(doc.paragraphs[107], "Similarly, Navarra and Antonio (2025) evaluated a student monitoring and data tracking system at Isulan National High School, Philippines. Developed using Agile Scrum across seven sprints and evaluated with N = 85 teachers, parents, and students, the platform achieved an overall grand mean of 4.72 ± 0.43 (\"Very Functional and Highly Effective\"). Moreover, 95% of respondents confirmed that digital attendance and academic records eliminated manual record reconciliation and improved school-home transparency.", first_line_indent=0.5)
format_para(doc.paragraphs[108], "Internationally, Irhamna, Kasmini, and Khairuman (2026) developed an IoT attendance system using an ESP32 microcontroller, RC522 RFID reader, and local MySQL logging at Universitas Bina Bangsa Getsempena, Indonesia. Evaluated by experts and N = 35 students, the system demonstrated an average scan latency of 0.10 seconds and an Aiken's V validity index of 0.982, confirming that low-cost ESP32 microcontrollers provide reliable offline-capable scanning.", first_line_indent=0.5)
format_para(doc.paragraphs[109], "In another study, Kurniawan, Fitriadi, Albaroky, and Astiani (2024) tested an RFID attendance system integrated with Telegram messaging. Testing showed 60 consecutive student cards were scanned in 213 seconds without interruption while immediately sending arrival notifications to parents, proving that RFID scanning paired with automated alerts eliminates entrance delays and keeps guardians informed.", first_line_indent=0.5)
# P110 can be emptied or formatted as clean paragraph transition
format_para(doc.paragraphs[110], "", first_line_indent=0)

# 2.1.2 Automated Grading, Assessment Computation, and Academic Analytics (P112 to P114)
format_para(doc.paragraphs[112], "Automated grading and assessment workflows eliminate calculation fatigue, enforce mathematical accuracy, and provide timely insights into student progress. In the Philippines, Bacongol and Durango (2025) evaluated the Automated Grading System (AutoGrade) at Sta. Margarita National High School across N = 165 teachers (n = 14) and students (n = 151) using ISO 9126 quality metrics. The system achieved a \"Very High\" rating across functionality, reliability, usability, and efficiency. It eliminated manual spreadsheet transcription errors and reduced grading turnaround time, validating the value of automated grade computation in Philippine secondary schools.", first_line_indent=0.5)
format_para(doc.paragraphs[113], "In an international study, Ramadhani, Sahiruddin, Kasri, and Alhamid (2025) developed a web-based grade management system for SMK Muhammadiyah Aimas using the Waterfall model. Black-box testing confirmed 100% operational compliance across all modules. Software evaluations rated the platform as \"Very Good\" (89.5%) by educational technology experts and \"Very High\" (93.0%) in teacher usability testing. The findings confirmed that automating score compilation and final grade calculation eliminates clerical errors, prevents duplicate entries, and accelerates report generation.", first_line_indent=0.5)
format_para(doc.paragraphs[114], "", first_line_indent=0)

# 2.1.4 Centralized Learning Materials Organization and Digital Repositories (P120 to P122)
format_para(doc.paragraphs[120], "Centralizing instructional materials within role-governed repositories ensures consistent student access and minimizes classroom delays. In the Philippines, Canlas and Ado (2024) developed and evaluated the Instructional Material Management System (IMMS) at the Polytechnic University of the Philippines. Evaluated by N = 120 faculty, administrators, and students using ISO/IEC 25010, the system achieved a \"Highly Acceptable\" grand mean of 4.56, with Security at 4.70, Functional Suitability at 4.53, and Usability at 4.45. A paired-samples t-test showed a statistically significant reduction in file retrieval time compared to scattered distribution methods (p < 0.001).", first_line_indent=0.5)
format_para(doc.paragraphs[121], "Internationally, Januhari, Setyanto, and Kusrini (2025) studied e-learning repository usability across N = 384 university students using ISO/IEC 25010 and PLS-SEM. Their analysis revealed that platform efficiency in file retrieval was the strongest predictor of user satisfaction (beta = 0.482, p < 0.001), explaining 64.2% of its variance (R^2 = 0.642). This confirms that organized, categorized file storage directly enhances user satisfaction in educational software.", first_line_indent=0.5)
format_para(doc.paragraphs[122], "", first_line_indent=0)

# Table 0 (Table 1 Quantitative Synthesis Matrix in doc.tables[0])
print("Condensing Table 1 cells while preserving all 10 studies and metrics...")
matrix_data = [
    # Row 0: Headers
    ["AUTHOR & YEAR", "TITLE & VENUE", "METHODOLOGY & DESIGN", "SAMPLE PROFILE & SIZE (N)", "KEY EMPIRICAL FINDINGS (QUANTITATIVE METRICS)", "ARCHITECTURAL CONTRIBUTION TO CLASSREALM"],
    # Row 1: Holgado
    ["Holgado et al. (2026) [Local]", "Automated Attendance Monitoring Using UHF RFID (The Horizon)", "Descriptive-developmental; hardware prototyping & faculty survey", "Senior High School Dept; trial batches and faculty evaluators", "93.3% RFID walk-through detection accuracy; 100% backend data logging accuracy; faculty rated 'Strongly Agree' for usability and reliability.", "Validates contactless RFID attendance in Philippine Senior High Schools, informing CLASSREALM's edge RFID capture."],
    # Row 2: Navarra
    ["Navarra & Antonio (2025) [Local]", "Student Monitoring and Data Tracking System (Psychology and Education)", "Agile SDLC (7 sprints) with descriptive-evaluative survey", "N = 85 (teachers, parents, secondary students) at Isulan NHS", "Grand mean of 4.72 ± 0.43 ('Very Functional / Highly Effective'); 95% stakeholder confirmation of process optimization.", "Demonstrates multi-stakeholder tracking across teachers, parents, and students, supporting CLASSREALM's multi-portal architecture."],
    # Row 3: Bacongol
    ["Bacongol & Durango (2025) [Local]", "Automated Grading System (AutoGrade) Based on ISO 9126 (iJOINED ETCOR)", "Descriptive-evaluative design using ISO 9126 quality metrics", "N = 165 (14 SHS teachers, 151 students) at Sta. Margarita NHS", "Achieved overall 'Very High' rating across functionality, reliability, usability, and efficiency; eradicated spreadsheet calculation errors.", "Validates centralized automated grading in Philippine Senior High Schools, informing CLASSREALM's DepEd DO 15 engine."],
    # Row 4: Contreras
    ["Contreras & Mercado (2024) [Local]", "Weekly Lesson Plan Monitoring Tool for Science Teachers (IJRISS)", "Pre-experimental repeated-measures design; paired t-test", "Secondary Science Teachers at Antonio A. Maceda Integrated School", "Competency rose from Q1 baseline M = 78.10 to Q3 M = 89.50; paired t = 4.45 > t_crit = 2.26 (p < 0.05); Q4 maintained M = 86.40.", "Confirms structured planning tools significantly improve teacher planning competence, supporting CLASSREALM's Lesson Plan Guide Generator."],
    # Row 5: Canlas
    ["Canlas & Ado (2024) [Local]", "Centralized Digital System for Instructional Material Management (Technologique)", "SDLC Waterfall with ISO/IEC 25010 evaluation; paired t-test", "N = 120 (faculty, administrators, students) at PUP Manila", "Grand mean of 4.56 ('Highly Acceptable'); Security at 4.70, Suitability at 4.53, Usability at 4.45; latency reduced (p < 0.001).", "Confirms centralized repositories eliminate resource loss and retrieval delays, informing CLASSREALM's Learning Materials module."],
    # Row 6: Irhamna
    ["Irhamna et al. (2026) [Foreign]", "RFID Attendance System with ESP32 and Local MySQL (Jurnal Inotera)", "R&D prototyping with Aiken's V validation & latency testing", "Technical experts and N = 35 students at Univ. Bina Bangsa Getsempena", "Average RFID read-to-log latency of 0.10s; Aiken's V validity index of 0.982; 100% data transmission reliability under local buffering.", "Validates ESP32 and RC522 hardware for sub-second, offline-buffered attendance capture in CLASSREALM."],
    # Row 7: Kurniawan
    ["Kurniawan et al. (2024) [Foreign]", "RFID and Telegram for Student Attendance (INJURATECH)", "Experimental benchmarking of scan throughput and messaging", "Secondary school cohort; 60 consecutive student card scans", "Scanned 60 consecutive cards in 213s without interruption; verified immediate mobile messaging alerts to parents and teachers.", "Substantiates pairing RFID hardware with instant parent and teacher alerts, eliminating entrance bottlenecks."],
    # Row 8: Ramadhani
    ["Ramadhani et al. (2025) [Foreign]", "Web-Based Student Grade Management System (JTP)", "R&D Waterfall method; black-box and usability testing", "Technology experts and secondary teachers at SMK Muhammadiyah Aimas", "100% functional test compliance; expert rating of 89.5% ('Very Good'); teacher usability of 93.0% ('Very High').", "Demonstrates high teacher usability and data accuracy for web-based grade calculation, justifying CLASSREALM's grading module."],
    # Row 9: Çevikbaş
    ["Çevikbaş et al. (2024) [Foreign]", "Teacher Competence in Mathematics Lesson Planning (ZDM)", "Systematic review and synthesis of N = 20 empirical studies", "N = 20 empirical studies of secondary mathematics teachers", "Structured planning guides significantly improve teachers' ability to align cognitive demand with curriculum standards and assessments.", "Justifies CLASSREALM's Lesson Plan Guide Generator for Grade 11 Mathematics, showing scaffolding improves plan quality."],
    # Row 10: Januhari
    ["Januhari et al. (2025) [Foreign]", "E-Learning Usability Based on ISO 25010 and PLS-SEM (AISM)", "Quantitative survey using ISO/IEC 25010 and PLS-SEM in SmartPLS", "N = 384 higher education students in Bali, Indonesia", "File retrieval efficiency directly predicted user satisfaction (beta = 0.482, p < 0.001), explaining 64.2% of variance (R^2 = 0.642).", "Confirms efficient digital material retrieval is a primary driver of system satisfaction, supporting CLASSREALM's repository design."]
]

tbl0 = doc.tables[0]
for r_idx, row in enumerate(matrix_data):
    for c_idx, val in enumerate(row):
        cell = tbl0.rows[r_idx].cells[c_idx]
        cell.text = ""
        p = cell.paragraphs[0]
        run = p.add_run(val)
        run.font.name = "Arial"
        run.font.size = Pt(10 if r_idx > 0 else 10)
        run.bold = (r_idx == 0)
        p.alignment = WD_ALIGN_PARAGRAPH.LEFT
        pf = p.paragraph_format
        pf.line_spacing = 1.15
        pf.space_before = Pt(2)
        pf.space_after = Pt(2)
        pf.first_line_indent = Inches(0)

# Enforce cantSplit and tblHeader on all tables
for t in doc.tables:
    for r_idx, row in enumerate(t.rows):
        trPr = row._tr.get_or_add_trPr()
        if trPr.find(qn('w:cantSplit')) is None:
            trPr.append(OxmlElement('w:cantSplit'))
        if r_idx == 0:
            if trPr.find(qn('w:tblHeader')) is None:
                trPr.append(OxmlElement('w:tblHeader'))

# 2.3 Theoretical Framework (P132 to P143)
format_para(doc.paragraphs[132], "The theoretical foundation of this study is grounded in General Systems Theory, operationalized through the Input-Process-Storage-Output (IPSO) framework and substantiated by the DeLone and McLean (2003) Information Systems Success Model. Educational data management requires a persistent system where student attendance, assessments, and grades remain secure, auditable, and accessible across multiple school years.", first_line_indent=0.5)
format_para(doc.paragraphs[133], "The DeLone and McLean (2003) model identifies six interrelated dimensions of system success: System Quality, Service Quality, Information Quality, System Use, User Satisfaction, and Net Benefits. In CLASSREALM, these dimensions map directly to the four sequential stages of the IPSO framework:", first_line_indent=0.5)

# P134 is Figure 1, P135 is caption, P137 is figure description
format_para(doc.paragraphs[137], "Figure 1 illustrates the flow of data through CLASSREALM: administrative and instructional data enter at the Input stage; are validated, calculated, and synchronized at the Process stage; persist in a secure database and non-volatile buffers at the Storage stage; and produce official attendance logs, transmutated grades, and dashboards at the Output stage.", first_line_indent=0.5)
format_para(doc.paragraphs[138], "The four interconnected stages of the IPSO theoretical architecture function as follows:", first_line_indent=0.5)
format_para(doc.paragraphs[139], "1. Input: Encompasses administrative and classroom data entered into the system, including official student rosters with 12-digit Learner Reference Numbers (LRNs), RFID card UIDs (captured via the ESP32 scanner or manual roster), class schedules with cutoff windows (Present, Late, Absent), raw assessment scores, DepEd DO 15 grading criteria, and curriculum competencies.", first_line_indent=0.5)
format_para(doc.paragraphs[140], "2. Process: Represents automated workflows executed by the system, including Firebase authentication, schedule-bound attendance filtering, duplicate scan suppression, ESP32 offline buffering, a nightly 23:59 Supabase Edge Function auto-marking unscanned students as Absent, DepEd DO 15 grade calculations with 41-tier transmutation, objective quiz scoring, and lesson plan guide generation.", first_line_indent=0.5)
format_para(doc.paragraphs[141], "3. Storage: Manages persistent, secure storage of academic records using a Supabase PostgreSQL relational database governed by Row-Level Security (RLS) policies, Supabase Storage buckets for instructional files and submissions, and immutable audit logs that preserve historical data across school years.", first_line_indent=0.5)
format_para(doc.paragraphs[142], "4. Output: Delivers actionable educational deliverables, including attendance logs tagged as \"RFID\" or \"Manual\", real-time absence warnings for three or more unexcused absences, official DepEd E-Class Records exportable to PDF, Excel, and CSV, structured Grade 11 Mathematics lesson plan guides, and view-only student and parent dashboards.", first_line_indent=0.5)
format_para(doc.paragraphs[143], "As illustrated in Figure 1, System Quality (rapid RFID scanning and offline buffering) and Service Quality (role-based security and reliable interfaces) govern the Process and Storage stages. These produce high Information Quality (accurate transmutated grades and audit-defensible attendance logs) at the Output stage, leading to high User Satisfaction and meaningful Net Benefits for Eduardo Barreto Sr. High School.", first_line_indent=0.5)

# 2.4 Conceptual Framework (P145 to P154)
format_para(doc.paragraphs[145], "The conceptual framework of CLASSREALM operationalizes the theoretical IPSO model for the classroom environment of Eduardo Barreto Sr. High School using an Input-Process-Output (IPO) model with an active feedback loop.", first_line_indent=0.5)
# P146 is Figure 2, P147 is caption
format_para(doc.paragraphs[149], "Figure 2 illustrates the Input-Process-Output flow of CLASSREALM. Teachers, students, and the administrator supply inputs; core system modules process and validate them; and verified deliverables return to stakeholders. The dashed feedback arrow represents corrections and updates submitted by users.", first_line_indent=0.5)
format_para(doc.paragraphs[150], "The three stages of the IPO framework function as follows:", first_line_indent=0.5)
format_para(doc.paragraphs[151], "INPUT: Captures raw instructional and administrative data. The teacher provides rosters, schedules, grading weights, lesson plan content, and learning materials. Students contribute RFID card taps, quiz answers, and assignment submissions. The Admin provisions user accounts and sets up the academic year.", first_line_indent=0.5)
format_para(doc.paragraphs[152], "PROCESS: Transforms raw inputs into structured academic outputs. Core operations include account authentication, attendance validation with schedule cutoffs and offline buffering, objective quiz scoring, DepEd DO 15 grade computation with 41-tier transmutation, lesson plan scaffolding, and automated notification dispatch.", first_line_indent=0.5)
format_para(doc.paragraphs[153], "OUTPUT: Delivers verified educational results, including attendance logs tagged as RFID or Manual, exportable DepEd E-Class Records, assessment analytics, structured lesson plan guides, learning materials access, mobile dashboards, and absence alert notifications.", first_line_indent=0.5)
format_para(doc.paragraphs[154], "The feedback loop depicted by the dashed arrow in Figure 2 reflects CLASSREALM’s self-correcting design: when teachers notice grading discrepancies, parents question attendance records, or students identify missing submissions, these observations return to the Input stage as corrective entries, ensuring data accuracy throughout the school year.", first_line_indent=0.5)

# ==============================================================================
# 3. CHAPTER 3 METHODOLOGY CLARIFICATIONS
# ==============================================================================
print("Applying Chapter 3 purposive sampling clarifications...")

# Section 3.1 Agile Scrum (P176)
format_para(doc.paragraphs[176], "To govern the software development lifecycle (SDLC), the study adopts the Agile Scrum Methodology. Agile Scrum is specifically chosen over rigid linear models because secondary school classroom operations require continuous alignment with changing administrative guidelines, localized grading templates, and end-user workflows. By organizing development into rapid, time-boxed two-week sprint iterations, the development team incrementally delivers working software modules, conducts hands-on sprint reviews directly with client teacher Ma’am Karen P. Gonzaga, and immediately incorporates stakeholder feedback. Purposive sampling is applied for teachers and parents during the initial deployment, focusing specifically on client teacher Ma’am Karen P. Gonzaga and parent monitors, while the underlying technical architecture (Supabase RLS, Flutter multi-portal architecture, and teacher section management) is designed and engineered to support multi-teacher, multi-subject, and multi-section scaling.", first_line_indent=0.5)

# Section 3.2 Population of Study (P191)
format_para(doc.paragraphs[191], "Purposive sampling is applied to select the single client teacher (Ma’am Karen P. Gonzaga, Senior High School Mathematics Teacher) to thoroughly validate classroom workflows within core Grade 11 Mathematics subjects during the initial pilot deployment, while the underlying software architecture is fully capable of scaling to multiple teachers, subjects, and sections. Complete enumeration is applied to the 65 Grade 11 students across her three handled sections (General Mathematics and Statistics and Probability) to capture authentic operational dynamics during daily instruction. For the parent cohort, purposive sampling is utilized, targeting 50 parents who possess active Android smartphones capable of running the Flutter parent mobile monitoring application. Finally, purposive expert sampling is used to recruit five (5) IT professionals with at least three years of industry experience to conduct independent technical quality auditing under ISO/IEC 25010:2023.", first_line_indent=0.5)

# Table 2 in doc.tables (Table 3 in text: PARTICIPANT CATEGORY)
# Row 1 is Client Teacher
tbl2 = doc.tables[2]
# Cell 3: Sampling Method
tbl2.rows[1].cells[3].text = ""
p_m = tbl2.rows[1].cells[3].paragraphs[0]
r_m = p_m.add_run("Purposive Sampling")
r_m.font.name = "Arial"
r_m.font.size = Pt(10)
p_m.alignment = WD_ALIGN_PARAGRAPH.LEFT
p_m.paragraph_format.line_spacing = 1.15
p_m.paragraph_format.first_line_indent = Inches(0)

# Cell 4: Justification
tbl2.rows[1].cells[4].text = ""
p_j = tbl2.rows[1].cells[4].paragraphs[0]
r_j = p_j.add_run("Senior High School Mathematics Teacher (Ma'am Karen P. Gonzaga) handling 3 Grade 11 sections; purposively selected for focused pilot workflow validation with multi-teacher scaling architecture.")
r_j.font.name = "Arial"
r_j.font.size = Pt(10)
p_j.alignment = WD_ALIGN_PARAGRAPH.LEFT
p_j.paragraph_format.line_spacing = 1.15
p_j.paragraph_format.first_line_indent = Inches(0)

# Save intermediate docx
doc.save(TEMP_DOCX)
print(f"Saved intermediate docx to {TEMP_DOCX}")

# ==============================================================================
# 4. EMBED ACCURATE HIGH-RESOLUTION DIAGRAMS & UPDATE DRAWING EXTENTS
# ==============================================================================
print("Replacing diagram images and updating drawing extents...")

# Replacement map: {zip_path: local_image_path}
replacements = {
    'word/media/image3.png': os.path.join(DIAGRAMS_DIR, 'figure1_ipso_diagram.png'),
    'word/media/image4.png': os.path.join(DIAGRAMS_DIR, 'figure2_ipo_diagram.png'),
    'word/media/image5.png': os.path.join(DIAGRAMS_DIR, 'figure3_agile_scrum_framework.png'),
    'word/media/image7.png': os.path.join(DIAGRAMS_DIR, 'figure5_context_diagram.png')
}

# Drawing extents map: target -> (cx, cy)
# 914400 EMUs = 1 inch
# Fig 1 (3400x2000, 1.700 ar): 5.50 in width -> cx=5029200, cy=2958353 (3.235 in)
# Fig 2 (3200x1900, 1.684 ar): 5.40 in width -> cx=4937760, cy=2931883 (3.206 in)
# Fig 3 (3400x2000, 1.700 ar): 5.40 in width -> cx=4937760, cy=2904565 (3.176 in)
# Fig 5 (3600x2400, 1.500 ar): 5.40 in width -> cx=4937760, cy=3291840 (3.600 in)
extent_map = {
    'media/image3.png': (5029200, 2958353),
    'media/image4.png': (4937760, 2931883),
    'media/image5.png': (4937760, 2904565),
    'media/image7.png': (4937760, 3291840)
}

# Unpack, update, and repack docx
with zipfile.ZipFile(TEMP_DOCX, 'r') as zin:
    doc_xml_bytes = zin.read('word/document.xml')
    rels_xml_bytes = zin.read('word/_rels/document.xml.rels')
    
    # Parse rels to map r:embed IDs
    rels_root = ET.fromstring(rels_xml_bytes)
    id_to_target = {r.get('Id'): r.get('Target') for r in rels_root}

    # Update extents in document.xml
    doc_root = ET.fromstring(doc_xml_bytes)
    ns = {
        'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
        'wp': 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing',
        'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
        'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
    }

    for drawing in doc_root.findall('.//w:drawing', ns):
        blip = drawing.find('.//a:blip', ns)
        extent = drawing.find('.//wp:extent', ns)
        if blip is not None and extent is not None:
            r_id = blip.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed')
            target = id_to_target.get(r_id, "")
            if target in extent_map:
                cx, cy = extent_map[target]
                extent.set('cx', str(cx))
                extent.set('cy', str(cy))
                # Also update a:xfrm/a:ext if present
                ext = drawing.find('.//a:xfrm/a:ext', ns)
                if ext is not None:
                    ext.set('cx', str(cx))
                    ext.set('cy', str(cy))
                print(f"Updated drawing extent for {target}: cx={cx}, cy={cy}")

    new_doc_xml_bytes = ET.tostring(doc_root, encoding='utf-8', xml_declaration=True)

    # Write final docx
    with zipfile.ZipFile(FINAL_COMPILED_DOCX, 'w', compression=zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            if item.filename == 'word/document.xml':
                zout.writestr(item, new_doc_xml_bytes)
            elif item.filename in replacements:
                local_path = replacements[item.filename]
                print(f"Replacing {item.filename} with {local_path} ({os.path.getsize(local_path)} bytes)")
                with open(local_path, 'rb') as img_in:
                    zout.writestr(item, img_in.read())
            else:
                zout.writestr(item, zin.read(item.filename))

shutil.copyfile(FINAL_COMPILED_DOCX, TARGET_DOCX)
print(f"\nSuccessfully compiled final document to {TARGET_DOCX}!")
