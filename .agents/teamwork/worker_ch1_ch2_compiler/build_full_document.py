"""
build_full_document.py
Full compilation of Chapters 1 & 2 for CLASSREALM in INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx
"""

import os
import sys
import docx
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

BACKUP_PATH = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_ch1_ch2_compiler\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.backup.docx"
DOC_PATH = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx"
REVISED_PATH = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE_REVISED.docx"
IPSO_DOC_PATH = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE_v2_IPSO.docx"
FIG1_PATH = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_ch1_ch2_compiler\figures\image1.png"
FIG2_PATH = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_ch1_ch2_compiler\figures\image2.png"

def apply_p_format(p, first_line_indent=0.5, line_spacing=1.5, space_before=0, space_after=0, align=WD_ALIGN_PARAGRAPH.LEFT, keep_with_next=False):
    if first_line_indent is not None:
        p.paragraph_format.first_line_indent = Inches(first_line_indent)
    else:
        p.paragraph_format.first_line_indent = None
    p.paragraph_format.line_spacing = line_spacing
    p.paragraph_format.space_before = Pt(space_before)
    p.paragraph_format.space_after = Pt(space_after)
    p.alignment = align
    p.paragraph_format.keep_with_next = keep_with_next

def add_chapter_heading(doc, chapter_num, chapter_title):
    p1 = doc.add_paragraph()
    apply_p_format(p1, first_line_indent=0, line_spacing=1.15, space_before=14, space_after=0, align=WD_ALIGN_PARAGRAPH.CENTER, keep_with_next=True)
    r1 = p1.add_run(chapter_num)
    r1.font.name = "Arial"
    r1.font.size = Pt(12)
    r1.font.bold = True

    p2 = doc.add_paragraph()
    apply_p_format(p2, first_line_indent=0, line_spacing=1.15, space_before=0, space_after=18, align=WD_ALIGN_PARAGRAPH.CENTER, keep_with_next=True)
    r2 = p2.add_run(chapter_title)
    r2.font.name = "Arial"
    r2.font.size = Pt(12)
    r2.font.bold = True

def add_h1(doc, text):
    p = doc.add_paragraph()
    apply_p_format(p, first_line_indent=0, line_spacing=1.5, space_before=14, space_after=2, align=WD_ALIGN_PARAGRAPH.LEFT, keep_with_next=True)
    r = p.add_run(text)
    r.font.name = "Arial"
    r.font.size = Pt(12)
    r.font.bold = True
    return p

def add_h2(doc, text):
    p = doc.add_paragraph()
    apply_p_format(p, first_line_indent=0, line_spacing=1.5, space_before=10, space_after=2, align=WD_ALIGN_PARAGRAPH.LEFT, keep_with_next=True)
    r = p.add_run(text)
    r.font.name = "Arial"
    r.font.size = Pt(11)
    r.font.bold = True
    return p

def add_h3(doc, text):
    p = doc.add_paragraph()
    apply_p_format(p, first_line_indent=0, line_spacing=1.5, space_before=6, space_after=2, align=WD_ALIGN_PARAGRAPH.LEFT, keep_with_next=True)
    r = p.add_run(text)
    r.font.name = "Arial"
    r.font.size = Pt(11)
    r.font.bold = True
    r.font.italic = True
    return p

def add_body_p(doc, text, bold_prefix=None):
    p = doc.add_paragraph()
    apply_p_format(p, first_line_indent=0.5, line_spacing=1.5, space_before=0, space_after=0, align=WD_ALIGN_PARAGRAPH.JUSTIFY)
    if bold_prefix:
        r_pre = p.add_run(bold_prefix)
        r_pre.font.name = "Arial"
        r_pre.font.size = Pt(11)
        r_pre.font.bold = True
    r = p.add_run(text)
    r.font.name = "Arial"
    r.font.size = Pt(11)
    return p

def add_bullet_p(doc, bold_label, text):
    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Inches(0.5)
    p.paragraph_format.first_line_indent = Inches(-0.25)
    p.paragraph_format.line_spacing = 1.5
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(0)
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    
    r_lbl = p.add_run(bold_label + " ")
    r_lbl.font.name = "Arial"
    r_lbl.font.size = Pt(11)
    r_lbl.font.bold = True
    
    r = p.add_run(text)
    r.font.name = "Arial"
    r.font.size = Pt(11)
    return p

def add_hanging_ref(doc, text):
    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Inches(0.5)
    p.paragraph_format.first_line_indent = Inches(-0.5)
    p.paragraph_format.line_spacing = 1.5
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(4)
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    
    parts = text.split('*')
    for i, part in enumerate(parts):
        if not part:
            continue
        run = p.add_run(part)
        run.font.name = "Arial"
        run.font.size = Pt(11)
        if i % 2 == 1:
            run.font.italic = True
    return p

def set_cell_margins(cell, top=100, bottom=100, left=120, right=120):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = OxmlElement('w:tcMar')
    for m, val in [('top', top), ('bottom', bottom), ('left', left), ('right', right)]:
        node = OxmlElement(f'w:{m}')
        node.set(qn('w:w'), str(val))
        node.set(qn('w:type'), 'dxa')
        tcMar.append(node)
    tcPr.append(tcMar)

def set_table_borders(table, color="444444", sz="6"):
    tblPr = table._tbl.tblPr
    borders_xml = f'''
    <w:tblBorders {nsdecls("w")}>
        <w:top w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>
        <w:left w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>
        <w:bottom w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>
        <w:right w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>
        <w:insideH w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>
        <w:insideV w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>
    </w:tblBorders>
    '''
    tblPr.append(parse_xml(borders_xml))

def format_table(table, col_widths):
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(table)
    for idx, row in enumerate(table.rows):
        trPr = row._tr.get_or_add_trPr()
        trPr.append(parse_xml(f'<w:cantSplit {nsdecls("w")}/>'))
        if idx == 0:
            trPr.append(parse_xml(f'<w:tblHeader {nsdecls("w")}/>'))
        
        for c_idx, cell in enumerate(row.cells):
            cell.width = Inches(col_widths[c_idx])
            set_cell_margins(cell, top=100, bottom=100, left=100, right=100)
            cell.vertical_alignment = WD_ALIGN_VERTICAL.TOP
            if idx == 0:
                shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="F2F2F2"/>')
                cell._tc.get_or_add_tcPr().append(shd)
                for p in cell.paragraphs:
                    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                    p.paragraph_format.line_spacing = 1.15
                    p.paragraph_format.space_before = Pt(2)
                    p.paragraph_format.space_after = Pt(2)
                    for r in p.runs:
                        r.font.name = "Arial"
                        r.font.size = Pt(9.0)
                        r.font.bold = True
            else:
                for p in cell.paragraphs:
                    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
                    p.paragraph_format.line_spacing = 1.15
                    p.paragraph_format.space_before = Pt(1)
                    p.paragraph_format.space_after = Pt(1)
                    p.paragraph_format.first_line_indent = None
                    for r in p.runs:
                        r.font.name = "Arial"
                        r.font.size = Pt(8.5)

def main():
    print(f"Loading template from {BACKUP_PATH}...", flush=True)
    if os.path.exists(BACKUP_PATH):
        doc = Document(BACKUP_PATH)
    else:
        doc = Document(DOC_PATH)
        
    # Verify elements count
    body = doc._body._body
    print(f"Initial body child elements count: {len(body)}", flush=True)
    
    # Check elements 0 to 27
    print("Verifying Title Page elements (0 to 27)...", flush=True)
    p0_text = "".join(body[0].itertext()).strip()
    print(f"Element 0: {p0_text[:60]}...", flush=True)
    
    # Remove placeholder elements starting from index 28, but PRESERVE sectPr
    elems_to_remove = []
    for i in range(28, len(body)):
        elem = body[i]
        if not elem.tag.endswith('sectPr'):
            elems_to_remove.append(elem)
            
    for elem in elems_to_remove:
        body.remove(elem)
    print(f"Removed {len(elems_to_remove)} placeholder elements (preserving sectPr). Current body elements: {len(body)}", flush=True)
    
    # -------------------------------------------------------------
    # CHAPTER I: INTRODUCTION
    # -------------------------------------------------------------
    add_chapter_heading(doc, "CHAPTER I", "INTRODUCTION")
    
    add_h1(doc, "1.1 Project Context")
    add_body_p(doc, "In the contemporary Philippine basic education system, Senior High School (SHS) educators carry an increasingly complex dual mandate: delivering rigorous, competency-based classroom instruction while simultaneously fulfilling extensive administrative and clerical reporting responsibilities. At Eduardo Barreto Sr. High School, an established public secondary institution located in Barangay Pansol, Calamba City, Laguna, teachers encounter significant operational friction in managing day-to-day classroom logistics across multiple large-enrollment class sections.")
    
    add_body_p(doc, "The institutional client for this study, Ma’am Karen P. Gonzaga, is a Senior High School Mathematics Teacher at Eduardo Barreto Sr. High School tasked with instructional delivery across core and specialized mathematics offerings, including General Mathematics and Statistics and Probability for Grade 11 learners. Under current classroom workflows, daily student attendance is monitored predominantly through manual paper attendance sheets or physical index cards. In a typical class section of 40 to 50 students, conducting manual verbal roll calls or passing paper sheets expends approximately 10 to 15 minutes of the scheduled 60-minute instructional period. Beyond instructional time loss, paper-based records are highly vulnerable to physical deterioration, misplacement, and proxy signing, while compiling cumulative quarterly attendance tallies for institutional reporting requires labor-intensive manual counting across hundreds of individual paper entries.")
    
    add_body_p(doc, "Parallel administrative bottlenecks compromise assessment and instructional resource management. Student submissions for written works and performance tasks are recorded across disparate paper logs, personal notebooks, and disconnected cloud storage folders, resulting in tracking delays and lack of centralized visibility. Furthermore, computing quarterly student grades under Department of Education (DepEd) Order No. 015, s. 2026 mandates multi-step mathematical calculations involving percentage contributions for Written Work, Performance Tasks, and Quarterly Assessments, followed by transmutation using an official 41-tier table. Executing these calculations manually on paper ledgers or standalone spreadsheets introduces recurrent mathematical transcription errors and delays the encoding of official DepEd Electronic Class Records (E-Class Records).")
    
    add_body_p(doc, "These classroom operational delays are further exacerbated by pedagogical preparation burdens. Teachers expend substantial non-teaching hours drafting weekly lesson plans and organizing fragmented instructional materials—such as curriculum guides, lesson exemplars, slide decks, and video resources—scattered across personal flash drives and varied online repositories. Simultaneously, communication with parents remains largely episodic, occurring primarily during end-of-quarter parent-teacher conferences, which deprives families of timely visibility into chronic student absenteeism or slipping academic performance. Addressing these interconnected logistical challenges necessitates an integrated, multi-platform educational management system tailored specifically to the operational realities of Eduardo Barreto Sr. High School.")

    add_h1(doc, "1.2 Purpose and Description")
    add_body_p(doc, "The primary purpose of this capstone research is to design, develop, and implement CLASSREALM (Comprehensive Learning and Academic Student Supervision Realm), an integrated Senior High School management platform engineered to automate and unify attendance tracking, activity and requirement submissions, objective assessment grading, DepEd DO 15, s. 2026 grade computation, teacher lesson planning guide generation, and instructional materials management for Eduardo Barreto Sr. High School.")
    
    add_body_p(doc, "CLASSREALM is architected as an offline-resilient, multi-platform ecosystem comprising four specialized user portals designed to serve distinct institutional stakeholders:")
    
    add_bullet_p(doc, "1. Admin Portal (Web):", "A restricted web interface assigned exclusively to the client teacher for high-level administrative maintenance, specifically scoped to provisioning and activating teacher accounts and executing annual academic year rollovers, without access to classroom instructional data or student grades.")
    add_bullet_p(doc, "2. Teacher Portal (Responsive Web App):", "A comprehensive web-based workspace for teachers to self-manage class sections and subjects, plot class schedules, record attendance via RFID scanner tap or permanent manual roster entry, administer quizzes, execute automated DepEd DO 15 grade calculations, generate structured lesson plan guides, and manage digital learning resources.")
    add_bullet_p(doc, "3. Student Portal (Mobile App):", "A dedicated cross-platform mobile application providing authenticated learners with secure, view-only access to their personal attendance history, submitted requirement grades, objective online quizzes, and downloadable instructional files.")
    add_bullet_p(doc, "4. Parent Portal (Mobile App):", "A dedicated view-only mobile application enabling verified parents and legal guardians to monitor their linked child's real-time attendance status, unexcused absence warnings, pending requirement deadlines, and quarterly academic performance.")
    
    add_body_p(doc, "To ensure operational continuity in public school environments subject to fluctuating electrical power and intermittent classroom internet connectivity, CLASSREALM incorporates a dual-path attendance ingestion pipeline. The primary attendance mechanism consists of a standalone Internet of Things (IoT) hardware scanner powered by an ESP32 microcontroller and an RC522/PN532 Radio Frequency Identification (RFID) reader. The device operates independently with local non-volatile flash storage (SPIFFS/NVS), queuing student card scans during network blackouts and automatically synchronizing logs to the Supabase cloud backend upon reconnection. In addition, manual attendance logging via the digital class roster is permanently maintained as a non-negotiable operational fallback, ensuring that zero student logs are lost under any operational condition.")
    
    add_body_p(doc, "Beyond attendance, CLASSREALM unifies academic assessment and pedagogical support. The platform provides automated checking of objective quiz items, instant psychometric item analysis, mathematical validation of grading weights to an exact 100% total, automated 41-tier DepEd transmutation, and standardized grade sheet exports (PDF, CSV, Excel). For instructional preparation, the system integrates a Lesson Plan Guide Generator that structures DepEd-aligned lesson plans for Grade 11 Mathematics, alongside a centralized Learning Materials Organizer that provides role-governed file storage and retrieval, establishing a unified digital realm for classroom management.")

    add_h1(doc, "1.3 Objectives of the Study")
    add_h2(doc, "1.3.1 General Objective")
    add_body_p(doc, "The general objective of this capstone research is to design, develop, implement, and evaluate CLASSREALM, an integrated Senior High School attendance, activity and requirement tracking, teacher lesson planning, and learning materials management system for Eduardo Barreto Sr. High School, providing automated dual-path attendance capture, objective assessment checking, DepEd DO 15, s. 2026 grade computation, and role-based mobile portals for enhanced academic monitoring and operational efficiency.")

    add_h2(doc, "1.3.2 Specific Objectives")
    add_body_p(doc, "To achieve the general objective, the study specifically aims to accomplish the following measurable objectives for School Year 2026–2027:")
    
    add_bullet_p(doc, "1. Dual-Path Attendance Ingestion Pipeline:", "To engineer an IoT-enabled attendance capture pipeline integrating a standalone ESP32 RFID scanner alongside a permanent manual teacher roster fallback, achieving a card tap detection and feedback latency of less than 2.0 seconds, an offline non-volatile buffer capacity of at least 5,000 attendance records, and cloud synchronization latency under 5.0 seconds upon network restoration.")
    add_bullet_p(doc, "2. Schedule-Bound Auto-Status & Cutoff Engine:", "To implement an automated attendance evaluation engine bound strictly to plotted subject class schedules, enforcing teacher-configured chronological cutoffs (Present window, Late cutoff, Absent cutoff) and executing an automated serverless backend job (Supabase Edge Function) at 23:59 each school day that marks unscanned enrolled students as Absent without overwriting existing valid marks (Present, Late, Excused) or triggering on non-scheduled days or official holidays.")
    add_bullet_p(doc, "3. Activity and Requirement Tracking Module:", "To construct a requirement tracking module supporting teacher assignment creation with attachments and student electronic file submissions, enforcing submission deadline verification within ±1.0 second and delivering real-time push notification alerts to student and parent mobile applications within 3.0 seconds.")
    add_bullet_p(doc, "4. Objective Assessment & Item Analysis Engine:", "To implement an online quiz and examination engine supporting objective item formats (multiple choice, true/false, identification) with automated score evaluation completed within 1.0 second upon submission, and automated calculation of psychometric item analysis (difficulty index and discrimination index) within 2.0 seconds.")
    add_bullet_p(doc, "5. DepEd DO 15, s. 2026 Grading Engine:", "To engineer an automated grading computation engine adhering strictly to DepEd Order No. 015, s. 2026 for Senior High School subjects (e.g., General Mathematics: Written Work 20%, Performance Tasks 50%, Quarterly Assessment 30%), validating that teacher component percentages total exactly 100%, computing initial weighted scores rounded to 2 decimal places, and mapping final ratings to the official 41-tier transmutation scale with 100% mathematical accuracy.")
    add_bullet_p(doc, "6. Teacher Lesson Plan Guide Generator:", "To design an interactive lesson plan guide generator that scaffolds DepEd-aligned lesson plans (objectives, content standards, learning competencies, instructional procedures, and assessment alignment) specifically for Grade 11 Mathematics instruction, reducing manual lesson drafting time by at least 50% while preserving teacher editorial control.")
    add_bullet_p(doc, "7. Centralized Learning Materials Organizer:", "To develop a centralized, categorized learning materials repository allowing teachers to organize and distribute instructional resources (curriculum guides, slide presentations, supplementary worksheets, and video links) with role-governed file downloads and zero file retrieval failures.")
    add_bullet_p(doc, "8. Role-Governed Portals & Row-Level Security:", "To implement dedicated Student and Parent mobile portals enforcing Supabase Row-Level Security (RLS) policies, ensuring learners view only their personal academic history and parents access strictly their linked child's attendance, absence warnings (>=3 absences), and quarterly grades with 100% data isolation.")
    add_bullet_p(doc, "9. Restricted Admin Portal:", "To build a restricted administrative web portal assigned to the client teacher solely for provisioning teacher credentials and executing academic year transitions, with zero administrative access to classroom instructional data or student grades.")
    add_bullet_p(doc, "10. Technical and Operational Acceptability Evaluation:", "To evaluate the technical and operational acceptability of CLASSREALM using the ISO/IEC 25010:2023 product quality model across its nine characteristics (functional suitability, performance efficiency, compatibility, interaction capability, reliability, security, maintainability, flexibility, and safety) among teachers, students, parents, and IT experts, targeting an overall weighted mean score of at least 4.20 out of 5.00 ('Highly Acceptable').")

    add_h1(doc, "1.4 Scope and Limitations of the Study")
    add_h2(doc, "1.4.1 Scope of the Study")
    add_body_p(doc, "The scope of this research is bounded by the operational, technical, and pedagogical requirements of its pilot implementation at Eduardo Barreto Sr. High School in Barangay Pansol, Calamba City, Laguna, during School Year 2026–2027. The primary client is Ma’am Karen P. Gonzaga, Senior High School Mathematics Teacher, handling approximately 60 to 70 students across three class sections. The primary beneficiaries are Grade 11 students enrolled in core mathematics subjects (General Mathematics, Statistics and Probability), their parents or legal guardians, and the client teacher. While CLASSREALM is initially deployed for a single teacher, its role-based architecture is designed to support additional teachers should the institution expand its adoption in future school years.")
    
    add_body_p(doc, "The software scope encompasses four interconnected portals:")
    add_bullet_p(doc, "• Admin Portal (Web):", "Enables academic year setup, rollover transitions, and teacher credential provisioning.")
    add_bullet_p(doc, "• Teacher Portal (Responsive Web App):", "Empowers the teacher to self-manage class sections and student enrollments, configure plotted class schedules, capture attendance via RFID scanner or permanent manual roster logging, publish requirements, administer objective online quizzes, compute transmutated quarterly grades under DepEd DO 15, s. 2026, generate structured lesson plan guides, and manage instructional materials.")
    add_bullet_p(doc, "• Student Portal (Mobile App):", "Provides authenticated students with personal views of daily attendance logs, submitted assignment grades, quiz scores, and downloadable learning resources.")
    add_bullet_p(doc, "• Parent Portal (Mobile App):", "Provides authorized parents with linked view-only monitoring of daily attendance timestamps, immediate absence alert notifications for 3 or more absences, pending academic requirements, and official quarterly grades.")
    
    add_body_p(doc, "The technical hardware scope includes a standalone ESP32 DevKit microcontroller interfaced with an MFRC522/PN532 RFID reader, status LEDs, a piezo buzzer, and a rechargeable battery circuit, capable of non-volatile offline scan buffering. The software architecture utilizes Flutter for client applications, Supabase PostgreSQL with Row-Level Security for relational data persistence, and Firebase Authentication for secure identity governance. Furthermore, the system preserves academic and grade records across multiple school years and allows downloading and exporting consolidated class records into PDF, CSV, and Microsoft Excel formats.")

    add_h2(doc, "1.4.2 Boundaries and Limitations")
    add_body_p(doc, "To maintain structural integrity, data security, and institutional compliance, the study establishes the following explicit boundaries and functional limitations:")
    
    add_bullet_p(doc, "1. System Admin Boundaries & Separation of Duties:", "The System Admin account is assigned to the client teacher solely for academic year transitions and teacher provisioning. To preserve instructional autonomy and protect student confidentiality, the Admin CANNOT manage sections, subjects, schedules, attendance, activities, requirements, quizzes, examinations, grading percentages, lesson plans, learning materials, or student academic records.")
    add_bullet_p(doc, "2. Teacher Roster Self-Management:", "Teachers self-manage sections, subjects, and students after receiving class rosters from the registrar/school. The software empowers educators to maintain their own class sections without administrative intervention.")
    add_bullet_p(doc, "3. Excluded Institutional Roles:", "The system strictly excludes Registrar and Principal user accounts, roles, and administrative governance dashboards. School-wide enrollment reporting and principal administrative supervision remain outside the software scope.")
    add_bullet_p(doc, "4. Excluded Student Workflows:", "The system does not support or automate mid-year student transfers, cross-section switching, or formal student dropping procedures. Under DepEd regulations, student dropping requires formal home visitation, parent-teacher conferences, and guidance counseling documentation; consequently, dropping or transferring students must be resolved through official school administrative channels and reflected manually in the teacher's roster.")
    add_bullet_p(doc, "5. Permanent Manual Attendance Fallback:", "Manual attendance marking directly on the teacher's roster is a permanent, non-negotiable operational feature. It is not an emergency workaround but an essential operational mode enabling teachers to accommodate forgotten RFID cards, temporary hardware malfunctions, or school activities.")
    add_bullet_p(doc, "6. Assessment Network Dependency:", "Online quiz and examination administration requires an active internet connection. Offline test administration is excluded due to real-time answer verification and security requirements.")
    add_bullet_p(doc, "7. Automated Scoring Boundaries:", "Automated assessment scoring is strictly restricted to supported objective question types (multiple choice, true/false, and short identification). Subjective problem-solving, open essays, and multi-step mathematical proofs require manual teacher evaluation.")
    add_bullet_p(doc, "8. Anti-Cheat Monitoring Boundaries:", "The application incorporates client-side assessment session event logging (detecting app focus loss, screen switching, or browser tab blur) to generate infraction flags for teacher review. However, the software cannot prevent students from consulting external physical notes or secondary unmonitored devices during remote testing.")
    add_bullet_p(doc, "9. Telephony & Carrier Limitations:", "Push notifications and in-app alerts are delivered via Firebase Cloud Messaging. Automated cellular SMS notifications depend on external hardware GSM modems or third-party SMS API aggregators, which require active carrier signal coverage and account credits.")

    add_h1(doc, "1.5 Quantifiable SMART Evaluation Criteria")
    add_body_p(doc, "To verify the successful deployment and empirical acceptability of CLASSREALM during School Year 2026–2027, the system is governed by the following quantifiable performance benchmarks:")
    
    add_bullet_p(doc, "• Attendance Tap Latency:", "RFID card scan detection and audiovisual feedback (LED/buzzer) executed within < 2.0 seconds under the standalone ESP32 hardware scanner.")
    add_bullet_p(doc, "• Offline Data Buffer Capacity:", "The ESP32 standalone scanner retains at least 5,000 attendance records in local non-volatile flash memory without data loss during extended power or Wi-Fi outages.")
    add_bullet_p(doc, "• Duplicate Scan Suppression:", "100% idempotent suppression of duplicate card taps within the same class session, preventing timestamp overwrites or status downgrades.")
    add_bullet_p(doc, "• Cloud Synchronization Latency:", "Locally buffered offline attendance logs synchronize completely to Supabase within < 5.0 seconds upon network restoration.")
    add_bullet_p(doc, "• Assessment Turnaround:", "Objective quiz scoring completed in < 1.0 second per submission; psychometric item analysis (difficulty and discrimination indices) computed within < 2.0 seconds.")
    add_bullet_p(doc, "• Grading Mathematical Precision:", "100% adherence to DepEd Order No. 015, s. 2026 component weighting, with running initial grades rounded to 2 decimal places and final ratings transmutated via the official 41-tier table with zero computational error.")
    add_bullet_p(doc, "• Notification Dispatch Speed:", "Real-time push notifications for student absence warnings and requirement announcements delivered within < 3.0 seconds.")
    add_bullet_p(doc, "• ISO/IEC 25010:2023 Technical Quality:", "Attainment of an overall weighted mean score of >= 4.20 out of 5.00 ('Highly Acceptable') across all nine software quality characteristics during stakeholder evaluation.")

    add_h1(doc, "1.6 Definition of Terms")
    add_body_p(doc, "To establish operational clarity and precise technical understanding within the context of CLASSREALM's software and hardware architecture, the following terms are defined operationally:")
    
    add_bullet_p(doc, "1. ESP32:", "A low-cost, low-power 32-bit dual-core microcontroller equipped with integrated 2.4 GHz Wi-Fi and Bluetooth connectivity, utilized in CLASSREALM as a standalone edge scanner that interfaces with an RFID module to capture student card UIDs, validate timestamps, buffer scans in non-volatile flash memory during network outages, and synchronize attendance logs to the cloud backend.")
    add_bullet_p(doc, "2. RFID (Radio Frequency Identification):", "A contactless wireless communication technology operating via electromagnetic fields (specifically 13.56 MHz high frequency or 125 kHz low frequency) used in CLASSREALM to detect unique card identification codes (UIDs) mapped to student 12-digit Learner Reference Numbers (LRNs) for rapid classroom attendance logging.")
    add_bullet_p(doc, "3. Firebase Authentication:", "A cloud-based identity and access management service integrated into CLASSREALM to manage secure user credential validation, encrypted password storage, JSON Web Token (JWT) issuance, and first-time temporary password resets for administrators, teachers, students, and parents.")
    add_bullet_p(doc, "4. Supabase:", "An open-source Backend-as-a-Service (BaaS) built on PostgreSQL, serving as CLASSREALM’s primary relational database for persistent academic records, real-time data replication, automated scheduled cron jobs (Edge Functions), and backend security enforcement.")
    add_bullet_p(doc, "5. Row-Level Security (RLS):", "A PostgreSQL database access-control mechanism implemented in Supabase that programmatically restricts database rows returned by queries based on the authenticated user's role and unique ID, ensuring teachers only access their assigned classes and students/parents only access their authorized records.")
    add_bullet_p(doc, "6. Admin Portal:", "A restricted web management interface assigned exclusively to the client teacher, scoped strictly to provisioning and activating teacher accounts, managing user lifecycles, and executing annual academic year rollovers, without access to classroom instructional data or student grades.")
    add_bullet_p(doc, "7. Teacher Portal:", "A comprehensive web and responsive desktop/tablet workspace empowering teachers to self-manage subject sections, plot class schedules, record attendance via dual RFID or permanent manual entry, administer quizzes, execute DepEd DO 15 grade calculations, generate lesson plans, and organize instructional materials.")
    add_bullet_p(doc, "8. Student Portal:", "A dedicated mobile application interface allowing authenticated learners to verify daily attendance timestamps, track deadlines, submit electronic assignments, take objective online quizzes, and view transmutated quarterly grades under strict RLS isolation.")
    add_bullet_p(doc, "9. Parent Portal:", "A dedicated view-only mobile application interface enabling authorized parents and legal guardians to monitor their linked child's real-time attendance status, unexcused absence warnings, pending academic requirements, and quarterly performance summaries.")

    # -------------------------------------------------------------
    # PAGE BREAK TO CHAPTER II
    # -------------------------------------------------------------
    doc.add_page_break()

    # -------------------------------------------------------------
    # CHAPTER II: REVIEW OF RELATED LITERATURE AND THEORETICAL/CONCEPTUAL FRAMEWORK
    # -------------------------------------------------------------
    add_chapter_heading(doc, "CHAPTER II", "REVIEW OF RELATED LITERATURE AND THEORETICAL/CONCEPTUAL FRAMEWORK")
    
    add_h1(doc, "2.1 Thematic Review of Related Literature")
    add_body_p(doc, "The evolution of modern educational management systems represents a necessary convergence between administrative automation, classroom instructional supervision, and stakeholder transparency. Senior High School educators in the Philippines face severe administrative workloads encompassing manual roll calls, requirement tracking, grade computation, lesson plan drafting, and learning resource management. CLASSREALM addresses these challenges through four core integrated modules: (1) automated attendance tracking with manual fallback, (2) automated grading and assessment computation, (3) teacher lesson planning guide generation, and (4) centralized learning materials organization. The following literature review analyzes empirical studies published between 2024 and 2026 that substantiate these technical and operational domains.")

    add_h2(doc, "2.1.1 Automated and Dual-Path Attendance Tracking Systems")
    add_body_p(doc, "Automated attendance tracking significantly reduces the instructional time lost during traditional pen-and-paper roll calls while mitigating data falsification and recording errors.")
    
    add_body_p(doc, "In a local Philippine empirical study, Holgado et al. (2026) developed and evaluated an automated attendance monitoring system utilizing Ultra High Frequency (UHF) RFID and a Raspberry Pi microcomputer for the Senior High School department of Colegio de San Juan de Letran Manila. Utilizing a descriptive-developmental research design, the researchers executed physical walk-through detection trials and conducted faculty usability surveys. The empirical findings demonstrated a 93.3% RFID tag detection accuracy during walk-through transit and a 100% success rate in backend database logging. Faculty evaluators registered an overall mean score within the 'Strongly Agree' band for software usability and hardware reliability, affirming that contactless radio-frequency identification substantially eliminates classroom queuing and administrative roll-call delays.")
    
    add_body_p(doc, "Complementing automated hardware capture, Navarra and Antonio (2025) evaluated a multi-stakeholder student monitoring and data tracking system deployed at Isulan National High School, Philippines. Developed using an Agile software development lifecycle spanning seven sprints and evaluated through a descriptive-evaluative survey with N = 85 respondents (comprising teachers, parents, and secondary students), the system achieved an overall grand mean rating of 4.72 ± 0.43 (interpreted as 'Very Functional and Highly Effective'). Crucially, 95% of respondents confirmed that digitizing attendance logs and academic records eliminated manual record reconciliation while establishing cross-stakeholder transparency across parents and faculty.")
    
    add_body_p(doc, "In the international domain, Irhamna, Kasmini, and Khairuman (2026) developed an IoT-based student attendance system integrating an ESP32 microcontroller, RC522 RFID reader module, and local MySQL database recording at Universitas Bina Bangsa Getsempena, Indonesia. Utilizing a Research and Development (R&D) prototyping methodology evaluated by technical experts and N = 35 student participants, empirical benchmark tests demonstrated an average card-reading and logging latency of only 0.10 seconds per scan. Expert content validity evaluated via Aiken's V formula yielded an index of 0.982 (interpreted as highly valid), with 100% data transmission reliability under local buffering, confirming the viability of low-cost ESP32 edge microcontrollers for rapid, offline-capable attendance recording.")
    
    add_body_p(doc, "In an international investigation on automated student monitoring and real-time alerts, Kurniawan, Fitriadi, Albaroky, and Astiani (2024) developed an automated attendance tracking system integrating Radio Frequency Identification (RFID) hardware with Telegram instant messaging at the secondary school level. Published in the International Journal of Research and Applied Technology (INJURATECH) under DOI 10.34010/injuratech.v4i1.14124, the researchers conducted experimental throughput and reliability benchmarking across consecutive batch scans. The empirical results demonstrated that the automated RFID capture pipeline successfully identified and processed attendance records for 60 consecutive student cards without interruption in 3 minutes and 33 seconds (213 seconds), while instantaneously dispatching automated arrival notifications to parents and teachers. The authors proved that pairing contactless RFID hardware with automated mobile messaging eliminates queuing delays during morning entry and provides guardians with direct, verifiable visibility into student attendance.")

    add_h2(doc, "2.1.2 Automated Grading, Assessment Computation, and Academic Analytics")
    add_body_p(doc, "Automating classroom grading and objective assessment workflows eliminates teacher computation fatigue, enforces mathematical accuracy, and provides timely diagnostic insights into student mastery.")
    
    add_body_p(doc, "In the Philippine local context, Bacongol and Durango (2025) developed and empirically evaluated the Automated Grading System (AutoGrade) designed for Senior High School academic data management at Sta. Margarita National High School, Philippines. Published in the International Journal of Open-Access, Interdisciplinary & New Educational Discoveries (iJOINED ETCOR) under DOI 10.63498/etcor454, the study employed a descriptive-evaluative research design grounded in the ISO 9126 software quality characteristics across N = 165 respondents, comprising n = 14 Senior High School subject teachers and n = 151 students. The empirical findings demonstrated that the automated grading architecture achieved an overall 'Very High' software quality assessment across functionality, reliability, usability, and efficiency. The system successfully eradicated computation discrepancies caused by manual pen-and-paper encoding and fragmented spreadsheets, streamlined periodic DepEd quarterly grade consolidation, and cut teachers' grading turnaround time, validating the institutional necessity of centralized, automated grade computation in Philippine secondary schools.")
    
    add_body_p(doc, "In an international empirical study on secondary school grade automation, Ramadhani, Sahiruddin, Kasri, and Alhamid (2025) developed and evaluated a web-based student grade management information system at SMK Muhammadiyah Aimas, published in JTP – Jurnal Teknologi Pendidikan (DOI: 10.21009/jtp.v27i3.60886). Employing a Research and Development (R&D) methodology using the Waterfall development model, the system integrated master student registries, daily activity tracking, midterm and final examination scoring, attendance tracking, and automatic final grade computation. Black-box functional testing confirmed 100% operational compliance across all modules. Software quality evaluation by educational technology experts rated the platform as 'Very Good' (89.5%), while end-user usability testing administered to secondary school teachers yielded an outstanding usability score of 93.0% ('Very High'). The empirical results confirmed that automating score aggregation and grade calculations eliminates clerical errors, prevents duplicate entries, and expedites official academic report generation for teachers and school administrators.")

    add_h2(doc, "2.1.3 Teacher Lesson Plan Guide Generation and Instructional Design")
    add_body_p(doc, "Lesson planning represents a core pedagogical responsibility of Senior High School teachers, yet repetitive administrative documentation frequently detracts from instructional delivery. Integrating structured digital guides and generative pedagogical tools provides cognitive scaffolding while preserving teacher oversight.")
    
    add_body_p(doc, "In a landmark local Philippine empirical investigation, Contreras and Mercado (2024) evaluated the impact of a structured Weekly Lesson Plan Monitoring Tool (WLPMT) on enhancing the instructional planning competencies of secondary school science teachers at Antonio A. Maceda Integrated School (SDO-Manila). Employing a quantitative pre-experimental repeated-measures design, teachers' lesson planning quality was tracked across four academic quarters. Empirical statistical analysis revealed that baseline lesson planning competency rose from a 1st Quarter mean of 78.10 (SD = 9.30) to 81.00 (SD = 20.41) in the 2nd Quarter, reaching 89.50 (SD = 9.10) by the 3rd Quarter. A paired-samples t-test between the 1st and 3rd quarters yielded a computed t-value of 4.45, decisively exceeding the critical two-tailed value of 2.26 (p < 0.05). The 4th Quarter maintained an elevated mean of 86.40 (SD = 12.22). This provides direct empirical proof that structured, indicator-driven lesson planning platforms significantly enhance teachers' ability to align learning competencies with classroom objectives and assessment tasks.")
    
    add_body_p(doc, "In an international empirical synthesis on mathematics instructional preparation, Çevikbash, König, and Rothland (2024) conducted an empirical review published in ZDM – Mathematics Education (DOI: 10.1007/s11858-023-01487-2) analyzing empirical research across N = 20 studies examining secondary teacher competence in mathematics lesson planning. The authors synthesized empirical evidence regarding how teachers conceptualize learning objectives, select tasks, anticipate student misconceptions, and structure instructional phases. The empirical findings revealed that teachers exhibit substantial difficulty translating complex curriculum competencies into coherent daily lesson plans when relying solely on generic outlines or unassisted manual drafting. However, the systematic integration of structured planning guides, indicator rubrics, and pedagogical scaffolding significantly enhances teachers' competence in aligning cognitive demand with formative assessment tasks, provided that tools preserve teacher agency for classroom-specific adaptations. This empirical evidence directly justifies CLASSREALM's Lesson Plan Guide Generator for Senior High School Mathematics, which provides structured, competency-aligned scaffolds while maintaining teacher discretion for final instructional decisions.")

    add_h2(doc, "2.1.4 Centralized Learning Materials Organization and Digital Repositories")
    add_body_p(doc, "Fragmented instructional resources—spanning slide decks, PDFs, problem sets, and curriculum guides—create substantial administrative friction. Centralizing educational assets within role-governed repositories ensures equitable student access and minimizes instructional downtime.")
    
    add_body_p(doc, "In the Philippines, Canlas and Ado (2024) developed and evaluated the Instructional Material Management System (IMMS) for the Polytechnic University of the Philippines (PUP). Built upon the SDLC Waterfall methodology and evaluated across N = 120 institutional stakeholders (faculty members, academic administrators, program chairs, and students) using the ISO/IEC 25010 software quality evaluation model, the system attained an overall 'Highly Acceptable' grand mean of 4.56. In the specific sub-dimensions, Security achieved a mean of 4.70, Functional Suitability scored 4.53, and Usability scored 4.45. A paired-samples t-test comparing traditional fragmented distribution (email, individual drives) with the centralized repository revealed a statistically significant reduction in file retrieval latency and material loss (p < 0.001), empirically verifying that structured digital repositories dramatically improve academic resource workflows.")
    
    add_body_p(doc, "In a large-scale international empirical investigation, Januhari, Setyanto, and Kusrini (2025) evaluated e-learning platform usability and learning resource repository management across N = 384 higher education students using the ISO/IEC 25010 Quality-in-Use model and Partial Least Squares Structural Equation Modeling (PLS-SEM) in SmartPLS. The empirical findings demonstrated that platform efficiency (specifically, the speed and ease with which learners navigate and retrieve course materials) was the single strongest direct predictor of student satisfaction and continuous platform utilization (beta = 0.482, p < 0.001), accounting for 64.2% of the variance (R^2 = 0.642). The authors established that disorganized or decentralized digital file storage severely impairs student engagement, validating the necessity of categorized, role-based learning material repositories in educational software.")

    add_h1(doc, "2.2 Synthesis of Related Literature")
    add_body_p(doc, "The empirical scholarship from 2024 to 2026 synthesized above underscores a fundamental trajectory in educational informatics: isolated, single-purpose utilities are inadequate for the multifaceted demands of modern secondary school classrooms. In attendance tracking, the investigations of Holgado et al. (2026) and Irhamna et al. (2026) confirm that hardware-based identification (UHF RFID and ESP32 microcontrollers) achieves rapid scan speeds (0.10s latency) and exceptional data reliability (93.3% to 100%). Meanwhile, Navarra and Antonio (2025) and Kurniawan et al. (2024) demonstrate that attendance data delivers its greatest institutional value when integrated with multi-portal dashboards and automated instant alerts to teachers and parents. CLASSREALM builds directly upon these empirical findings by engineering a robust attendance capture pipeline: a primary standalone ESP32 RFID scanner fortified by offline non-volatile buffering to ensure uninterrupted operation during school connectivity blackouts, paired with a permanent manual teacher roster fallback.")
    
    add_body_p(doc, "In grading and academic performance tracking, Bacongol and Durango (2025) and Ramadhani et al. (2025) prove that automated calculation engines and centralized academic databases eliminate computational transcription errors, resolve fragmented spreadsheet inconsistencies, and achieve high teacher usability (93.0%). CLASSREALM integrates these principles through a validated 100% component-weighting grading engine, automated objective assessment scoring, and real-time attendance warning triggers for students accumulating three or more absences.")
    
    add_body_p(doc, "Crucially, the literature confirms the critical need for teacher-facing instructional tools. Contreras and Mercado (2024) and Çevikbash et al. (2024) provide robust empirical evidence that structured digital lesson-planning tools and pedagogical scaffolding significantly elevate instructional planning competency (t = 4.45, p < 0.05). Both studies demonstrate that while digital tools streamline competency alignment, human teacher agency remains essential for classroom contextualization. CLASSREALM implements this principle by providing an interactive Lesson Plan Guide Generator that outputs structured, DepEd-aligned lesson scaffolds designed for teacher editing and final pedagogical discretion.")
    
    add_body_p(doc, "Finally, in learning materials management, Canlas and Ado (2024) and Januhari et al. (2025) empirically validate that centralized, ISO/IEC 25010-compliant repositories eliminate file loss, optimize retrieval latency, and directly dictate user satisfaction (R^2 = 0.642). CLASSREALM operationalizes these findings by embedding a dedicated Learning Materials Management module featuring role-based access, categorized document storage, and direct student access.")

    # Table 1: Synthesis Matrix
    p_tbl_lbl = doc.add_paragraph()
    apply_p_format(p_tbl_lbl, first_line_indent=0, line_spacing=1.15, space_before=14, space_after=0, align=WD_ALIGN_PARAGRAPH.LEFT, keep_with_next=True)
    r_tl = p_tbl_lbl.add_run("Table 1")
    r_tl.font.name = "Arial"
    r_tl.font.size = Pt(11)
    r_tl.font.bold = True

    p_tbl_title = doc.add_paragraph()
    apply_p_format(p_tbl_title, first_line_indent=0, line_spacing=1.15, space_before=0, space_after=4, align=WD_ALIGN_PARAGRAPH.LEFT, keep_with_next=True)
    r_tt = p_tbl_title.add_run("Quantitative Synthesis Matrix of the Reviewed Empirical Literature")
    r_tt.font.name = "Arial"
    r_tt.font.size = Pt(11)
    r_tt.font.italic = True

    # 10 studies, 6 columns
    col_widths = [0.85, 1.05, 0.90, 0.75, 1.00, 0.95] # Total = 5.5 inches
    matrix_data = [
        [
            "AUTHOR & YEAR",
            "TITLE & PUBLICATION VENUE",
            "RESEARCH METHODOLOGY & DESIGN",
            "SAMPLE PROFILE & SIZE (N)",
            "KEY EMPIRICAL FINDINGS (QUANTITATIVE METRICS)",
            "METHODOLOGICAL & ARCHITECTURAL CONTRIBUTION TO CLASSREALM"
        ],
        [
            "Holgado et al. (2026)\n[Local]",
            "Development of an Automated Attendance Monitoring System Using Ultra High Frequency RFID for Colegio de San Juan de Letran Manila\n(The Horizon)",
            "Descriptive-developmental design; hardware prototyping with walk-through trial sessions and faculty evaluation.",
            "Senior High School Department; trial scan batches and faculty evaluators.",
            "93.3% RFID walk-through detection accuracy; 100% backend data logging accuracy; faculty evaluation rated 'Strongly Agree' across usability and reliability.",
            "Validates the feasibility and accuracy of RFID tracking in a Philippine Senior High School setting; directly informs CLASSREALM's automated RFID capture pipeline."
        ],
        [
            "Navarra & Antonio (2025)\n[Local]",
            "Efficient Student Monitoring and Data Tracking System\n(Psychology and Education: A Multidisciplinary Journal)",
            "Agile Software Development Lifecycle (7 sprints) combined with Descriptive-Evaluative Survey.",
            "N = 85 respondents (teachers, parents, and secondary school students) at Isulan National High School.",
            "Overall system evaluation grand mean of 4.72 +/- 0.43 ('Very Functional / Highly Effective'); 95% stakeholder confirmation of process optimization.",
            "Demonstrates the effectiveness of role-based data tracking across teachers, parents, and students; provides empirical support for CLASSREALM's multi-portal architecture."
        ],
        [
            "Bacongol & Durango (2025)\n[Local]",
            "Evaluating the Developed Automated Grading System (AutoGrade) for Academic Data Management Based on ISO 9126 Quality Characteristics: Insights from Sta. Margarita National High School, Philippines\n(iJOINED ETCOR)",
            "Descriptive-evaluative research design based on ISO 9126 software quality characteristics.",
            "N = 165 respondents (n = 14 Senior High School teachers and n = 151 students) at Sta. Margarita National High School.",
            "Achieved an overall 'Very High' software quality assessment across functionality, reliability, usability, and efficiency; successfully eradicated manual computation errors and spreadsheet discrepancies.",
            "Directly confirms the institutional necessity and validity of centralized automated grade computation in Philippine Senior High Schools; informs CLASSREALM's DepEd DO 15 grading engine."
        ],
        [
            "Contreras & Mercado (2024)\n[Local]",
            "Utilization of Weekly Lesson Plan Monitoring Tool for Enhancing Competencies of Science Teachers in Instructional Planning\n(IJRISS)",
            "Quantitative pre-experimental repeated-measures design; paired-samples t-test across 4 academic quarters.",
            "Secondary Science Teachers at Antonio A. Maceda Integrated School, Division of City Schools, Manila.",
            "Competency scores rose from Q1 baseline M = 78.10 (SD = 9.30) to Q3 M = 89.50 (SD = 9.10); paired t-test t = 4.45 > t_crit = 2.26 (p < 0.05); Q4 maintained M = 86.40.",
            "Directly provides empirical evidence that indicator-driven lesson planning tools significantly improve teacher planning competence; substantiates CLASSREALM's Lesson Plan Guide Generator."
        ],
        [
            "Canlas & Ado (2024)\n[Local]",
            "A Centralized Digital System for Instructional Material Management in Higher Education: Development and Evaluation of the IMMS at the Polytechnic University of the Philippines\n(Technologique)",
            "SDLC Waterfall methodology; ISO/IEC 25010 software quality evaluation; paired-samples t-test.",
            "N = 120 respondents (faculty, academic administrators, program chairs, students) at PUP Manila.",
            "Grand mean of 4.56 ('Highly Acceptable') on ISO/IEC 25010; Security at 4.70, Functional Suitability at 4.53, Usability at 4.45; statistically significant latency reduction (p < 0.001).",
            "Confirms that centralized instructional material repositories eliminate resource fragmentation and retrieval delays; informs CLASSREALM's Learning Materials Organization module."
        ],
        [
            "Irhamna, Kasmini, & Khairuman (2026)\n[Foreign]",
            "Design and Development of an RFID-Based Student Attendance System Using Student ID Cards as Identification Media and Local MySQL Recording\n(Jurnal Inotera)",
            "Research and Development (R&D) prototyping; Aiken's V expert content validation; empirical hardware latency testing.",
            "Technical expert evaluators and N = 35 university student participants at Universitas Bina Bangsa Getsempena, Indonesia.",
            "Average RFID read-to-log latency of 0.10 seconds; Aiken's V validity index of 0.982 ('Very Valid'); 100% data transmission reliability under local buffering.",
            "Validates the physical architecture of low-cost ESP32 microcontrollers paired with RC522 RFID readers; substantiates CLASSREALM's offline-buffered hardware scanner."
        ],
        [
            "Kurniawan, Fitriadi, Albaroky, & Astiani (2024)\n[Foreign]",
            "Radio Frequency Identification and Telegram for Student Attendance\n(INJURATECH)",
            "Experimental engineering methodology; sequential batch throughput and processing speed benchmarking.",
            "Secondary school student cohort; 60 consecutive student RFID card scan trials.",
            "Successfully scanned and processed 60 consecutive student cards without interruption in 213 seconds; verified instantaneous mobile messaging alerts to parents and teachers.",
            "Substantiates CLASSREALM's integration of RFID hardware with real-time push notifications to parents and teachers; proves queuing delay elimination."
        ],
        [
            "Ramadhani, Sahiruddin, Kasri, & Alhamid (2025)\n[Foreign]",
            "Web-Based Student Grade Management Information System\n(JTP – Jurnal Teknologi Pendidikan)",
            "Research and Development (R&D) Waterfall method; black-box testing, expert software evaluation, and end-user usability testing.",
            "Educational technology experts and secondary school teachers at SMK Muhammadiyah Aimas.",
            "100% functional test compliance; expert evaluation rated platform as 'Very Good' (89.5%); teacher usability testing achieved 93.0% ('Very High'); eliminated calculation errors and duplicate entries.",
            "Demonstrates high teacher usability and data integrity for web-based grade management; justifies CLASSREALM's centralized grade calculation and record management."
        ],
        [
            "Çevikbash, König, & Rothland (2024)\n[Foreign]",
            "Empirical Research on Teacher Competence in Mathematics Lesson Planning: Recent Developments\n(ZDM – Mathematics Education)",
            "Empirical review and synthesis of N = 20 empirical studies on mathematics lesson planning competence.",
            "N = 20 peer-reviewed empirical studies examining secondary mathematics teachers.",
            "Synthesized evidence that structured planning guides and pedagogical scaffolding significantly improve teachers' ability to align cognitive demand with curriculum standards and formative assessments.",
            "Provides international empirical justification for CLASSREALM's Lesson Plan Guide Generator for Grade 11 Mathematics, demonstrating that scaffolding enhances planning quality while preserving teacher agency."
        ],
        [
            "Januhari, Setyanto, & Kusrini (2025)\n[Foreign]",
            "Evaluation of E-Learning Usability Based on ISO 25010 with Hofstede's Cultural Dimensions as Moderation: A PLS-SEM Study in Higher Education\n(AISM)",
            "Quantitative empirical design; ISO/IEC 25010 Quality-in-Use model; Partial Least Squares Structural Equation Modeling (PLS-SEM).",
            "N = 384 higher education students across diverse academic disciplines in Bali, Indonesia.",
            "Platform efficiency directly predicted user satisfaction (beta = 0.482, p < 0.001), accounting for 64.2% of satisfaction variance (R^2 = 0.642).",
            "Empirically confirms that seamless, efficient access to categorized digital learning materials is a primary determinant of system satisfaction; justifies CLASSREALM's dedicated repository design."
        ]
    ]

    tbl = doc.add_table(rows=len(matrix_data), cols=6)
    for r_idx, r_data in enumerate(matrix_data):
        row = tbl.rows[r_idx]
        for c_idx, val in enumerate(r_data):
            cell = row.cells[c_idx]
            cell.text = val
    format_table(tbl, col_widths)

    p_tbl_post = doc.add_paragraph()
    apply_p_format(p_tbl_post, first_line_indent=0.5, line_spacing=1.5, space_before=6, space_after=0, align=WD_ALIGN_PARAGRAPH.LEFT)
    r_tpost = p_tbl_post.add_run("As detailed in Table 1, the ten reviewed empirical publications systematically substantiate every core functional module of CLASSREALM. Rather than viewing prior studies through unconstructive claims of missing features, Table 1 illustrates how each investigation contributed specific methodological rigor, hardware validation, or pedagogical insights. Specifically, the attendance investigations by Holgado et al. (2026) and Irhamna et al. (2026) validate sub-second hardware RFID capture, while Navarra and Antonio (2025) and Kurniawan et al. (2024) confirm high multi-stakeholder satisfaction with mobile tracking and real-time guardian alerts. In academic grading, Bacongol and Durango (2025) and Ramadhani et al. (2025) establish that automated grade computation eliminates calculation errors and expedites reporting turnaround. Direct empirical proof for teacher instructional tools is furnished by Contreras and Mercado (2024), who proved that structured lesson plan tools significantly elevate teacher planning competencies (t = 4.45, p < 0.05), and Çevikbash et al. (2024), who synthesized how planning guides support teachers in aligning cognitive tasks with curriculum standards. Finally, Canlas and Ado (2024) and Januhari et al. (2025) empirically substantiate that centralized, ISO/IEC 25010-compliant learning materials repositories eliminate resource retrieval delays and directly determine system satisfaction (R^2 = 0.642).")

    # -------------------------------------------------------------
    # SECTION 2.3: THEORETICAL FRAMEWORK (IPSO DIAGRAM)
    # -------------------------------------------------------------
    add_h1(doc, "2.3 Theoretical Framework")
    add_body_p(doc, "The theoretical foundation of this study is grounded in General Systems Theory and operationalized through the Input-Process-Storage-Output (IPSO) architectural paradigm, substantiated by the Information Systems Success Model formulated by DeLone and McLean (2003). In modern educational data management, an academic tracking and attendance platform cannot be structured as an ephemeral transactional utility that transforms and discards data within a single user session; rather, it represents a persistent cybernetic system in which data must persist, be retrieved, and be audited over time across multi-year academic cohorts.")
    
    add_body_p(doc, "While the updated DeLone and McLean (2003) model articulates the causal dimensions of information system success—comprising System Quality, Information Quality, Service Quality, System Use, User Satisfaction, and Net Benefits—the operational flow of academic records through CLASSREALM is structured around the sequential and interdependent stages of the IPSO paradigm. As conceptualized, raw administrative and instructional inputs are systematically captured, processed through specialized validation and computation algorithms, persisted within secure cloud storage and non-volatile hardware buffers, and rendered into verified academic deliverables.")

    # Figure 1: Theoretical Framework (IPSO Diagram)
    p_fig1_lbl = doc.add_paragraph()
    apply_p_format(p_fig1_lbl, first_line_indent=0, line_spacing=1.15, space_before=14, space_after=0, align=WD_ALIGN_PARAGRAPH.CENTER, keep_with_next=True)
    r_f1l = p_fig1_lbl.add_run("Figure 1")
    r_f1l.font.name = "Arial"
    r_f1l.font.size = Pt(11)
    r_f1l.font.bold = True

    p_fig1_title = doc.add_paragraph()
    apply_p_format(p_fig1_title, first_line_indent=0, line_spacing=1.15, space_before=0, space_after=6, align=WD_ALIGN_PARAGRAPH.CENTER, keep_with_next=True)
    r_f1t = p_fig1_title.add_run("Input-Process-Storage-Output Diagram (IPSO) of CLASSREALM")
    r_f1t.font.name = "Arial"
    r_f1t.font.size = Pt(11)
    r_f1t.font.italic = True

    if os.path.exists(FIG1_PATH):
        p_img1 = doc.add_paragraph()
        apply_p_format(p_img1, first_line_indent=0, line_spacing=1.0, space_before=0, space_after=6, align=WD_ALIGN_PARAGRAPH.CENTER)
        p_img1.add_run().add_picture(FIG1_PATH, width=Inches(5.5))
        print("Embedded Figure 1 (IPSO Diagram) successfully.", flush=True)
    else:
        print(f"Warning: Figure 1 image not found at {FIG1_PATH}", flush=True)

    p_fig1_post = doc.add_paragraph()
    apply_p_format(p_fig1_post, first_line_indent=0.5, line_spacing=1.5, space_before=6, space_after=0, align=WD_ALIGN_PARAGRAPH.LEFT)
    r_f1post = p_fig1_post.add_run("Figure 1 illustrates the flow of data through CLASSREALM: official student rosters, RFID card taps, plotted class schedules, assessment scores, grading criteria, and curriculum competencies are captured at the Input stage; validated, scored, computed, and synchronized at the Process stage; persisted in a role-protected Supabase database, secure file storage, and encrypted audit logs at the Storage stage; and rendered as audit-defensible attendance logs, DepEd E-Class Records, absence warning alerts, lesson plan guides, and multi-portal dashboards at the Output stage. A deficiency observed at the Output stage (for example, an inaccurate transmutated grade, duplicate attendance timestamp, or unreflected submission) can be traced backward through Storage and Process to its Input-stage origin.")

    add_body_p(doc, "The four interconnected stages of the IPSO theoretical architecture function as follows:")
    add_bullet_p(doc, "1. Input:", "Encompasses the foundational administrative, physical, and instructional data ingested into the system. This includes official registrar-provided class rosters with 12-digit Learner Reference Numbers (LRNs), physical RFID card UIDs (captured via the standalone ESP32 hardware scanner or permanent manual roster entry), plotted class timetables with teacher cutoff thresholds (Present, Late, Absent), assignment requirements, quiz item banks, raw assessment scores across Written Work, Performance Tasks, and Quarterly Exams, DepEd Order No. 015, s. 2026 grading percentages, and curriculum learning competencies.")
    add_bullet_p(doc, "2. Process:", "Represents the computational, algorithmic, and serverless workflows executed upon the ingested inputs. Core processes comprise role-based user authentication and session management via Firebase Authentication, schedule-bound attendance filtering that suppresses duplicate card taps and rejects scans outside class periods, ESP32 non-volatile offline scan buffering and cloud synchronization, a nightly 23:59 Supabase Edge Function auto-marking unscanned students as Absent, real-time objective quiz checking and psychometric item analysis, DepEd DO 15 weighted grade computation and 41-tier transmutation, structured lesson plan guide generation, and push notification dispatch.")
    add_bullet_p(doc, "3. Storage:", "Maintains the secure, relational persistence and multi-year archival of all educational data artifacts. This stage is hosted on an enterprise Supabase PostgreSQL relational database enforced by Row-Level Security (RLS) policies by user role, Supabase Storage buckets for digital learning materials and student electronic file submissions, and immutable audit logs that preserve historical records across successive academic school years.")
    add_bullet_p(doc, "4. Output:", "Delivers the actionable, verified educational deliverables to institutional stakeholders. Key outputs encompass audit-defensible attendance logs explicitly tagged with 'RFID' or 'Manual' capture indicators, real-time student absence alerts for 3 or more absences dispatched to parents and teachers, official DepEd E-Class Records exportable to PDF, Microsoft Excel, and CSV formats, structured Grade 11 Mathematics lesson plan guides, a searchable digital learning materials repository, and view-only personal dashboards for students and parents.")

    add_body_p(doc, "This IPSO theoretical architecture directly operationalizes the Information Systems Success dimensions articulated by DeLone and McLean (2003). High System Quality (sub-second edge RFID scanning, local buffering during power interruptions, and database reliability) and high Service Quality (Firebase role-based security, Row-Level Security data segregation, and inline form validation) jointly govern the Process and Storage stages. In turn, these drive high Information Quality (mathematically verified DepEd grade transmutation and tamper-resistant attendance records) at the Output stage, maximizing user satisfaction among teachers, students, and parents and generating institutional net benefits for Eduardo Barreto Sr. High School.")

    # -------------------------------------------------------------
    # SECTION 2.4: CONCEPTUAL FRAMEWORK (MULTI-TIER ARCHITECTURE)
    # -------------------------------------------------------------
    add_h1(doc, "2.4 Conceptual Framework")
    add_body_p(doc, "The conceptual framework of CLASSREALM operationalizes the theoretical IPSO stages within the concrete multi-platform environment of Eduardo Barreto Sr. High School. The framework follows an Input-Process-Output (IPO) model that maps the flow of classroom data—from raw teacher and student inputs through computational processing to verified institutional outputs—and includes a feedback loop through which stakeholders review outputs and feed corrections back as new inputs.")

    # Figure 2: Conceptual Framework (IPO Diagram)
    p_fig2_lbl = doc.add_paragraph()
    apply_p_format(p_fig2_lbl, first_line_indent=0, line_spacing=1.15, space_before=14, space_after=0, align=WD_ALIGN_PARAGRAPH.CENTER, keep_with_next=True)
    r_f2l = p_fig2_lbl.add_run("Figure 2")
    r_f2l.font.name = "Arial"
    r_f2l.font.size = Pt(11)
    r_f2l.font.bold = True

    p_fig2_title = doc.add_paragraph()
    apply_p_format(p_fig2_title, first_line_indent=0, line_spacing=1.15, space_before=0, space_after=6, align=WD_ALIGN_PARAGRAPH.CENTER, keep_with_next=True)
    r_f2t = p_fig2_title.add_run("Input-Process-Output Diagram (IPO) of CLASSREALM")
    r_f2t.font.name = "Arial"
    r_f2t.font.size = Pt(11)
    r_f2t.font.italic = True

    if os.path.exists(FIG2_PATH):
        p_img2 = doc.add_paragraph()
        apply_p_format(p_img2, first_line_indent=0, line_spacing=1.0, space_before=0, space_after=6, align=WD_ALIGN_PARAGRAPH.CENTER)
        p_img2.add_run().add_picture(FIG2_PATH, width=Inches(5.3))
        print("Embedded Figure 2 (IPO Diagram) successfully.", flush=True)
    else:
        print(f"Warning: Figure 2 image not found at {FIG2_PATH}", flush=True)

    p_fig2_post = doc.add_paragraph()
    apply_p_format(p_fig2_post, first_line_indent=0.5, line_spacing=1.5, space_before=6, space_after=0, align=WD_ALIGN_PARAGRAPH.JUSTIFY)
    r_f2post = p_fig2_post.add_run("Figure 2 illustrates the Input-Process-Output flow of CLASSREALM. The Teacher, Students, and the Admin supply the inputs; the system’s core modules transform them through processing; and the outputs are returned to the same stakeholders. The dashed feedback arrow shows how stakeholders review the outputs and, when necessary, submit corrections or updates as new inputs.")

    add_body_p(doc, "The three stages of the IPO Conceptual Framework function as follows:")

    add_bullet_p(doc, "INPUT –", "The input stage captures all raw data introduced into CLASSREALM. This includes: the Teacher’s class roster (with 12-digit Learner Reference Numbers), RFID attendance scans from the standalone ESP32 scanner, assessment scores, grading weight configurations, lesson plan content, and digital learning materials. Students supply quiz responses; and the Admin provides academic year setup and teacher account credentials.")

    add_bullet_p(doc, "PROCESS –", "The processing stage encompasses all computational, algorithmic, and serverless workflows that transform raw inputs into structured results. Core processes include: Account and Role Management, Classroom and Attendance Management (including schedule-bound auto-status and offline RFID buffering), Assessment and Grading, DepEd DO 15, s. 2026 Grade Computation (with 41-tier transmutation), Lesson Plan Guide Generation, Learning Materials Management, and Notifications and Reporting.")

    add_bullet_p(doc, "OUTPUT –", "The output stage delivers actionable, verified educational deliverables to institutional stakeholders. Key outputs include: audit-defensible Attendance Logs (tagged as RFID or Manual), official E-Class Records (exportable to PDF, Excel, and CSV), Assessment and Grade Results, structured Lesson Plan Guides, a centralized Learning Materials Repository, Student and Parent Dashboard Access, and Absence Warning Notifications for three or more unexcused absences.")

    add_body_p(doc, "The feedback loop depicted by the dashed arrow in Figure 2 reflects CLASSREALM’s self-correcting design: when teachers identify a discrepancy in a grade sheet, a parent disputes an attendance entry, or a student reports a missing submission, those observations return to the Input stage as corrective data, ensuring continuous accuracy and institutional accountability throughout the academic school year.")

    add_h1(doc, "2.5 References")
    
    add_h2(doc, "2.5.1 Local Literature and Studies")
    local_refs = [
        "Bacongol, D. M. A., & Durango, D. B. (2025). Evaluating the developed Automated Grading System (AutoGrade) for academic data management based on ISO 9126 quality characteristics: Insights from Sta. Margarita National High School, Philippines. *International Journal of Open-Access, Interdisciplinary & New Educational Discoveries*, 4(3), 905–918. https://doi.org/10.63498/etcor454",
        "Canlas, A. B., & Ado, R. G. (2024). A centralized digital system for instructional material management in higher education: Development and evaluation of the IMMS at the Polytechnic University of the Philippines. *Technologique: A Global Journal on Technological Developments and Scientific Innovations*, 9(1), 1–14. https://doi.org/10.62718/vmca.tech-gjtdsi.9.1.SC-0726-003",
        "Contreras, S. J., & Mercado, M. T. (2024). Utilization of weekly lesson plan monitoring tool for enhancing competencies of science teachers in instructional planning. *International Journal of Research and Innovation in Social Science*, 8(3S), 520–531. https://doi.org/10.47772/IJRISS.2024.803052S",
        "Holgado, J. L. P., Patulot, N. E. M., Bantola, J. J. J., Niño, C. S. G., Rico, C. E. V., Salama Mekawi, F. W. C., Pedrosa, J. J., & Arcaño, U. (2026). Development of an automated attendance monitoring system using ultra high frequency RFID for Colegio de San Juan de Letran Manila. *The Horizon*, 2(1), 12–25. https://research-manila.letran.edu.ph/article/279",
        "Navarra, J. M., & Antonio, E. O. (2025). Efficient student monitoring and data tracking system. *Psychology and Education: A Multidisciplinary Journal*, 35(8), 848–867. https://doi.org/10.70838/pemj.350801"
    ]
    for ref in local_refs:
        add_hanging_ref(doc, ref)

    add_h2(doc, "2.5.2 Foreign Literature and Studies")
    foreign_refs = [
        "Çevikbaş, M., König, J., & Rothland, M. (2024). Empirical research on teacher competence in mathematics lesson planning: Recent developments. *ZDM – Mathematics Education*, 56(1), 101–113. https://doi.org/10.1007/s11858-023-01487-2",
        "Irhamna, R., Kasmini, L., & Khairuman. (2026). Design and development of an RFID-based student attendance system using student ID cards as identification media and local MySQL recording. *Jurnal Inotera*, 11(1), 110–117. https://inotera.poltas.ac.id/index.php/inotera/article/view/620",
        "Januhari, N. N. U., Setyanto, A., & Kusrini. (2025). Evaluation of e-learning usability based on ISO 25010 with Hofstede's cultural dimensions as moderation: A PLS-SEM study in higher education. *Applied Information System and Management*, 8(1), 159–168. https://doi.org/10.15408/aism.v8i1.45738",
        "Kurniawan, B., Fitriadi, L. H., Albaroky, M. F., & Astiani, R. (2024). Radio frequency identification and Telegram for student attendance. *International Journal of Research and Applied Technology*, 4(1), 139–144. https://doi.org/10.34010/injuratech.v4i1.14124",
        "Ramadhani, I. A., Sahiruddin, Kasri, M. A., & Alhamid, S. (2025). Web-based student grade management information system. *JTP – Jurnal Teknologi Pendidikan*, 27(3), 864–877. https://doi.org/10.21009/jtp.v27i3.60886"
    ]
    for ref in foreign_refs:
        add_hanging_ref(doc, ref)

    add_h2(doc, "2.5.3 Institutional and Statutory Standards")
    standards_refs = [
        "Department of Education. (2026). *DepEd Order No. 015, s. 2026: Policy guidelines on the implementation of the Strengthened Senior High School (SSHS) curriculum and assessment*. Department of Education, Pasig City, Philippines. https://www.deped.gov.ph/orders/",
        "International Organization for Standardization. (2023). *Systems and software engineering — Systems and software Quality Requirements and Evaluation (SQuaRE) — Product quality model* (ISO/IEC 25010:2023). https://www.iso.org/standard/78176.html"
    ]
    for ref in standards_refs:
        add_hanging_ref(doc, ref)

    target_files = [
        IPSO_DOC_PATH,
        REVISED_PATH,
        DOC_PATH
    ]
    
    saved_any = False
    for target in target_files:
        try:
            doc.save(target)
            print(f"Successfully saved document to {target}! Final size: {os.path.getsize(target)} bytes.", flush=True)
            saved_any = True
        except PermissionError as pe:
            print(f"Notice: {os.path.basename(target)} is currently locked by Word/WPS ({pe}).", flush=True)
        except Exception as e:
            print(f"Error saving to {os.path.basename(target)}: {e}", flush=True)
            
    if not saved_any:
        print("Error: Could not save to any target document!", flush=True)
        sys.exit(1)

if __name__ == "__main__":
    main()
