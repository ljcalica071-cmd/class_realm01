import os
import sys
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import parse_xml, OxmlElement
from docx.oxml.ns import nsdecls, qn

# Import Activity Data Modules
import activity2_data as a2
import activity4_data as a4

TARGET_DOCX = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\CLASSREALM_Activities_2_and_4.docx"
DIAG_DIR = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\docs\diagrams"

def create_document():
    doc = Document()
    
    # Configure Page Margins: Top 1.6", Left 1.6", Bottom 1.2", Right 1.4" on Letter paper
    for section in doc.sections:
        section.top_margin = Inches(1.6)
        section.left_margin = Inches(1.6)
        section.bottom_margin = Inches(1.2)
        section.right_margin = Inches(1.4)
        section.page_width = Inches(8.5)
        section.page_height = Inches(11.0)
        
    # Configure Normal Style: Arial 12pt Regular, Black
    normal_style = doc.styles['Normal']
    normal_style.font.name = 'Arial'
    normal_style.font.size = Pt(12)
    normal_style.font.color.rgb = RGBColor(0, 0, 0)
    
    return doc

# --- HELPER FUNCTIONS FOR FORMATTING ---

def add_cover_title(doc, text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.line_spacing = 1.15
    p.paragraph_format.first_line_indent = Inches(0)
    run = p.add_run(text)
    run.font.name = 'Arial'
    run.font.size = Pt(14)
    run.bold = True
    return p

def add_cover_subtitle(doc, text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.line_spacing = 1.15
    p.paragraph_format.first_line_indent = Inches(0)
    run = p.add_run(text)
    run.font.name = 'Arial'
    run.font.size = Pt(12)
    run.bold = True
    return p

def add_cover_text(doc, text, italic=False, bold=False, space_before=2, space_after=2):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(space_before)
    p.paragraph_format.space_after = Pt(space_after)
    p.paragraph_format.line_spacing = 1.15
    p.paragraph_format.first_line_indent = Inches(0)
    run = p.add_run(text)
    run.font.name = 'Arial'
    run.font.size = Pt(12)
    run.italic = italic
    run.bold = bold
    return p

def add_h1(doc, text, center=True):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER if center else WD_ALIGN_PARAGRAPH.LEFT
    p.paragraph_format.space_before = Pt(18)
    p.paragraph_format.space_after = Pt(6)
    p.paragraph_format.line_spacing = 1.15
    p.paragraph_format.first_line_indent = Inches(0)
    p.paragraph_format.keep_with_next = True
    run = p.add_run(text)
    run.font.name = 'Arial'
    run.font.size = Pt(12)
    run.bold = True
    return p

def add_h2(doc, text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    p.paragraph_format.space_before = Pt(14)
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.line_spacing = 1.15
    p.paragraph_format.first_line_indent = Inches(0)
    p.paragraph_format.keep_with_next = True
    run = p.add_run(text)
    run.font.name = 'Arial'
    run.font.size = Pt(12)
    run.bold = True
    return p

def add_h3(doc, text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    p.paragraph_format.space_before = Pt(10)
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.line_spacing = 1.15
    p.paragraph_format.first_line_indent = Inches(0)
    p.paragraph_format.keep_with_next = True
    run = p.add_run(text)
    run.font.name = 'Arial'
    run.font.size = Pt(12)
    run.bold = True
    run.italic = True
    return p

def add_p(doc, text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(0)
    p.paragraph_format.line_spacing = 1.5
    p.paragraph_format.first_line_indent = Inches(0.5)
    run = p.add_run(text)
    run.font.name = 'Arial'
    run.font.size = Pt(12)
    return p

def add_table_caption(doc, number_str, title_str):
    p1 = doc.add_paragraph()
    p1.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p1.paragraph_format.space_before = Pt(14)
    p1.paragraph_format.space_after = Pt(1)
    p1.paragraph_format.line_spacing = 1.15
    p1.paragraph_format.first_line_indent = Inches(0)
    p1.paragraph_format.keep_with_next = True
    r1 = p1.add_run(number_str)
    r1.font.name = 'Arial'
    r1.font.size = Pt(12)
    r1.bold = True

    p2 = doc.add_paragraph()
    p2.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p2.paragraph_format.space_before = Pt(0)
    p2.paragraph_format.space_after = Pt(6)
    p2.paragraph_format.line_spacing = 1.15
    p2.paragraph_format.first_line_indent = Inches(0)
    p2.paragraph_format.keep_with_next = True
    r2 = p2.add_run(title_str)
    r2.font.name = 'Arial'
    r2.font.size = Pt(12)
    r2.italic = True

def add_figure_image_and_caption(doc, img_filename, number_str, title_str):
    img_path = os.path.join(DIAG_DIR, img_filename)
    if not os.path.exists(img_path):
        print(f"WARNING: Image not found: {img_path}")
    
    p1 = doc.add_paragraph()
    p1.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p1.paragraph_format.space_before = Pt(12)
    p1.paragraph_format.space_after = Pt(2)
    p1.paragraph_format.line_spacing = 1.0
    p1.paragraph_format.first_line_indent = Inches(0)
    p1.paragraph_format.keep_with_next = True
    r1 = p1.add_run(number_str)
    r1.font.name = 'Arial'
    r1.font.size = Pt(12)
    r1.bold = True

    p2 = doc.add_paragraph()
    p2.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p2.paragraph_format.space_before = Pt(0)
    p2.paragraph_format.space_after = Pt(6)
    p2.paragraph_format.line_spacing = 1.0
    p2.paragraph_format.first_line_indent = Inches(0)
    p2.paragraph_format.keep_with_next = True
    r2 = p2.add_run(title_str)
    r2.font.name = 'Arial'
    r2.font.size = Pt(12)
    r2.italic = True

    p_img = doc.add_paragraph()
    p_img.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_img.paragraph_format.space_before = Pt(2)
    p_img.paragraph_format.space_after = Pt(10)
    p_img.paragraph_format.line_spacing = 1.0
    p_img.paragraph_format.first_line_indent = Inches(0)
    p_img.paragraph_format.keep_with_next = True
    
    if os.path.exists(img_path):
        run_img = p_img.add_run()
        run_img.add_picture(img_path, width=Inches(5.4))
    else:
        run_img = p_img.add_run(f"[Diagram Image Missing: {img_filename}]")
        run_img.bold = True
        run_img.font.color.rgb = RGBColor(200, 0, 0)

def create_styled_table(doc, headers, data, col_widths=None, center_cols=None):
    if center_cols is None:
        center_cols = [0]
    
    table = doc.add_table(rows=len(data) + 1, cols=len(headers))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    
    # Table borders at tblPr level
    tblPr = table._element.xpath('w:tblPr')
    if tblPr:
        borders = parse_xml('''
            <w:tblBorders xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                <w:top w:val="single" w:sz="6" w:space="0" w:color="555555"/>
                <w:left w:val="single" w:sz="6" w:space="0" w:color="555555"/>
                <w:bottom w:val="single" w:sz="6" w:space="0" w:color="555555"/>
                <w:right w:val="single" w:sz="6" w:space="0" w:color="555555"/>
                <w:insideH w:val="single" w:sz="6" w:space="0" w:color="555555"/>
                <w:insideV w:val="single" w:sz="6" w:space="0" w:color="555555"/>
            </w:tblBorders>
        ''')
        tblPr[0].append(borders)
        
    # Format Header Row
    header_row = table.rows[0]
    trPr = header_row._element.get_or_add_trPr()
    trPr.append(parse_xml('<w:tblHeader xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"/>'))
    trPr.append(parse_xml('<w:cantSplit xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"/>'))
    
    for i, h_text in enumerate(headers):
        cell = header_row.cells[i]
        tcPr = cell._element.get_or_add_tcPr()
        tcPr.append(parse_xml('<w:shd xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" w:fill="F2F4F8"/>'))
        tcPr.append(parse_xml('''
            <w:tcMar xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                <w:top w:w="120" w:type="dxa"/>
                <w:bottom w:w="120" w:type="dxa"/>
                <w:left w:w="150" w:type="dxa"/>
                <w:right w:w="150" w:type="dxa"/>
            </w:tcMar>
        '''))
        cell.text = h_text
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(0)
        p.paragraph_format.line_spacing = 1.15
        p.paragraph_format.first_line_indent = Inches(0)
        for r in p.runs:
            r.font.name = 'Arial'
            r.font.size = Pt(10)
            r.bold = True
            
    # Format Data Rows
    for row_idx, row_data in enumerate(data):
        row = table.rows[row_idx + 1]
        trPr = row._element.get_or_add_trPr()
        trPr.append(parse_xml('<w:cantSplit xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"/>'))
        
        # Check if this is an entity header row in data dictionary (starts with -- Entity:)
        is_entity_header = str(row_data[0]).startswith("-- Entity:")
        
        for col_idx, val in enumerate(row_data):
            cell = row.cells[col_idx]
            tcPr = cell._element.get_or_add_tcPr()
            if is_entity_header:
                tcPr.append(parse_xml('<w:shd xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" w:fill="EAEEF3"/>'))
            tcPr.append(parse_xml('''
                <w:tcMar xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                    <w:top w:w="100" w:type="dxa"/>
                    <w:bottom w:w="100" w:type="dxa"/>
                    <w:left w:w="150" w:type="dxa"/>
                    <w:right w:w="150" w:type="dxa"/>
                </w:tcMar>
            '''))
            cell.text = str(val)
            p = cell.paragraphs[0]
            if is_entity_header:
                p.alignment = WD_ALIGN_PARAGRAPH.LEFT
            elif col_idx in center_cols:
                p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            else:
                p.alignment = WD_ALIGN_PARAGRAPH.LEFT
                
            p.paragraph_format.space_before = Pt(0)
            p.paragraph_format.space_after = Pt(0)
            p.paragraph_format.line_spacing = 1.15
            p.paragraph_format.first_line_indent = Inches(0)
            for r in p.runs:
                r.font.name = 'Arial'
                r.font.size = Pt(9.5) if len(headers) >= 5 else Pt(10)
                if is_entity_header:
                    r.bold = True
                    r.font.color.rgb = RGBColor(20, 50, 100)
                    
    # Apply column widths if provided
    if col_widths:
        for row in table.rows:
            for i, w in enumerate(col_widths):
                if i < len(row.cells):
                    row.cells[i].width = Inches(w)
                    
    # Space after table
    p_after = doc.add_paragraph()
    p_after.paragraph_format.space_before = Pt(0)
    p_after.paragraph_format.space_after = Pt(8)
    p_after.paragraph_format.first_line_indent = Inches(0)

# ==============================================================================
# DOCUMENT BUILD PIPELINE
# ==============================================================================

def build_activities_document():
    print("Initializing document...")
    doc = create_document()
    
    # --------------------------------------------------------------------------
    # COVER / TITLE BLOCK
    # --------------------------------------------------------------------------
    add_cover_text(doc, "LAGUNA UNIVERSITY", bold=True, space_before=10, space_after=2)
    add_cover_text(doc, "COLLEGE OF COMPUTING STUDIES", bold=True, space_before=2, space_after=2)
    add_cover_text(doc, "BACHELOR OF SCIENCE IN INFORMATION TECHNOLOGY", bold=True, space_before=2, space_after=18)
    
    add_cover_title(doc, "CLASSREALM: AN INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE, ASSESSMENT, AND LEARNING MANAGEMENT SYSTEM WITH RFID SCANNING AND OFFLINE SYNCHRONIZATION")
    add_cover_subtitle(doc, "CONSOLIDATED CAPSTONE SYSTEM ARCHITECTURE DOCUMENT")
    add_cover_subtitle(doc, "ACTIVITY #2: REQUIREMENTS TO PROCESS MODELING\n&\nACTIVITY #4: INTEGRATED UML AND DATA MODELING")
    
    add_cover_text(doc, "A Capstone Project Documentation Submitted to the Faculty of the College of Computing Studies", italic=True, space_before=16, space_after=4)
    add_cover_text(doc, "In Partial Fulfillment of the Requirements for the Degree of Bachelor of Science in Information Technology", italic=True, space_before=2, space_after=16)
    
    add_cover_text(doc, "Prepared by:", bold=True, space_before=10, space_after=2)
    add_cover_text(doc, "CALICA, MARK ANGELO C.", space_before=2, space_after=2)
    add_cover_text(doc, "SAN JUAN, JOHN CARL B.", space_before=2, space_after=14)
    
    add_cover_text(doc, "Client / Stakeholder Partner:", bold=True, space_before=6, space_after=2)
    add_cover_text(doc, "MA'AM KAREN P. GONZAGA", space_before=2, space_after=2)
    add_cover_text(doc, "Senior High School Mathematics Teacher", space_before=2, space_after=2)
    add_cover_text(doc, "Eduardo Barretto Sr. High School — Calamba City, Laguna", space_before=2, space_after=14)
    
    add_cover_text(doc, "Academic Year 2025 – 2026", bold=True, space_before=10, space_after=20)
    
    doc.add_page_break()
    
    # ==========================================================================
    # ACTIVITY #2: REQUIREMENTS TO PROCESS MODELING
    # ==========================================================================
    print("Generating Activity #2...")
    add_h1(doc, "ACTIVITY #2")
    add_h1(doc, "REQUIREMENTS TO PROCESS MODELING")
    
    add_p(doc, "Activity #2 establishes the formal transition from system requirements discovery into a rigorous, decomposed process model for the CLASSREALM educational management system. Using the standardized Gane and Sarson process modeling notation, this document provides an exhaustive structural and behavioral specification of all human stakeholders, edge hardware scanners, cloud backend infrastructure, functional requirements, user stories, and multi-level data flow diagrams (DFDs). The process model guarantees rigorous system boundaries, deterministic data transformation paths, and verifiable conservation of data across all operational subsystems.")
    
    # PART A — REQUIREMENTS REVIEW
    add_h1(doc, "PART A — REQUIREMENTS REVIEW", center=False)
    add_h2(doc, "1. Stakeholders / External Users")
    add_p(doc, "The stakeholder ecosystem of CLASSREALM encompasses both direct human actors and external automated services. Direct human actors comprise the System Administrator, Teacher, Student, and Parent. External automated entities include the ESP32 RC522 RFID door scanner, Firebase Authentication gateway, and Supabase Cloud backend. In strict alignment with the institutional boundaries established with our client partner, Ma'am Karen P. Gonzaga at Eduardo Barretto Sr. High School, system operations strictly exclude school registrar, financial billing, accounting collection, and academic dropping workflows, focusing exclusively on instructional management, dual-path attendance tracking, digital assessments, automated grading, and curriculum resource organization.")
    
    add_table_caption(doc, "Table 1", "Stakeholders and External Entities in CLASSREALM")
    create_styled_table(doc, a2.TABLE_1_HEADERS, a2.TABLE_1_DATA, col_widths=[1.2, 1.0, 1.3, 2.0], center_cols=[0, 1])
    add_p(doc, "Table 1 describes the operational roles and system boundaries of the seven stakeholders and external entities comprising CLASSREALM. The table highlights the role segregation between administrative infrastructure governance and teacher academic self-management, confirming that the client teacher retains complete autonomy over sections, subjects, rosters, and grade computation.")
    
    add_h2(doc, "2. Functional Requirements")
    add_p(doc, "The functional requirements of CLASSREALM were systematically formulated through iterative stakeholder consultation sessions with Ma'am Karen P. Gonzaga, combined with empirical analysis of Senior High School grading mandates under DepEd Order No. 8, s. 2015 and DepEd Order No. 15, s. 2026. Each requirement encapsulates a distinct functional capability, specifying its input trigger, processing transformation, output payload, and persistent data store destination.")
    
    add_table_caption(doc, "Table 2", "Functional Requirements of CLASSREALM")
    create_styled_table(doc, a2.TABLE_2_HEADERS, a2.TABLE_2_DATA, col_widths=[0.6, 1.0, 1.7, 1.1, 1.1], center_cols=[0, 1])
    add_p(doc, "Table 2 defines the ten core functional requirements (FR1 through FR10) that drive the system architecture. These functional requirements span authentication, classroom configuration, teacher RFID card assignment, dual-path attendance tracking, 23:59 automated absence evaluation, classwork submission, digital quiz administration, DepEd grade transmutation, ILAW lesson plan generation, and instructional materials distribution.")
    
    add_h2(doc, "3. User Stories")
    add_p(doc, "To ensure user-centered architectural fidelity, the functional requirements are complemented by agile user stories. Each user story expresses a vital operational capability from the perspective of a specific stakeholder persona, defining the operational motivation, functional goal, and empirical acceptance criteria required for verification.")
    
    add_table_caption(doc, "Table 3", "User Stories for CLASSREALM")
    create_styled_table(doc, a2.TABLE_3_HEADERS, a2.TABLE_3_DATA, col_widths=[0.6, 0.7, 1.8, 1.8, 0.6], center_cols=[0, 1, 4])
    add_p(doc, "Table 3 details eight prioritized user stories (US-01 to US-08) representing the four primary human user roles. The user stories trace directly to the underlying functional requirements and establish measurable acceptance thresholds for hardware scanning latency, duplicate card prevention, manual override immutability, and parent absence warning delivery.")
    
    # PART B — PROCESS MODELING
    add_h1(doc, "PART B — PROCESS MODELING", center=False)
    add_h2(doc, "4. DFD Design Overview & Architecture")
    add_p(doc, "The process modeling architecture of CLASSREALM utilizes the standardized Gane and Sarson graphical notation. Under this convention, solid rounded shapes or ellipses represent operational processes that transform data; solid rectangles represent external entities acting as data sources or sinks; open-ended parallel horizontal bars represent persistent data stores; and solid directed vectors represent discrete, labeled data flows. In strict accordance with institutional capstone standards, all data flows carry explicit domain payload descriptions (e.g., 'Card UID & Tap Timestamp [ISO 8601]'), and all generic 'input/output' labels are strictly omitted.")
    
    add_table_caption(doc, "Table 4", "Process Decomposition Matrix of CLASSREALM")
    create_styled_table(doc, a2.TABLE_4_HEADERS, a2.TABLE_4_DATA, col_widths=[0.7, 1.4, 1.4, 1.2, 0.8], center_cols=[0])
    add_p(doc, "Table 4 outlines the functional decomposition of CLASSREALM into five major Level 0 processes (1.0 to 5.0) and their constituent sub-processes. This hierarchical structure ensures that every operational capability is modularly isolated, completely traceable, and systematically verified.")
    
    add_table_caption(doc, "Table 5", "Data Stores and Corresponding Relational Database Tables")
    create_styled_table(doc, a2.TABLE_5_HEADERS, a2.TABLE_5_DATA, col_widths=[0.6, 1.3, 1.8, 1.8], center_cols=[0])
    add_p(doc, "Table 5 specifies the five persistent data stores (D1 to D5) utilized across the DFD model and maps each store directly to the underlying PostgreSQL relational tables hosted on Supabase and mirrored locally via Drift SQLite on client mobile devices. This explicit mapping establishes complete structural harmony between the process model and the relational data schema.")
    
    # Context Diagram (Level 0 DFD)
    add_figure_image_and_caption(doc, "activity2_dfd_level0.png", "Figure 1", "Context Diagram (Level 0 DFD) of CLASSREALM")
    add_p(doc, "Figure 1 illustrates the Context Diagram (Level 0 DFD) of CLASSREALM, depicting the entire system as a single central process (0 CLASSREALM) interfacing with four human stakeholder entities (System Administrator, Teacher, Student, Parent) and three external automated services (ESP32 RC522 RFID Scanner, Firebase Authentication, and Supabase Cloud Backend). As detailed in the diagram, the Administrator issues teacher account provisioning directives and receives system audit summaries; the Teacher inputs classroom setup, student rosters, RFID card pairing commands, manual attendance overrides, and assessment authoring data, while receiving real-time attendance rosters, item analysis reports, and computed quarterly grade sheets; the Student taps physical RFID cards at the scanner antenna and accesses personal attendance histories, digital quizzes, and learning materials; and the Parent receives real-time attendance alerts and official quarterly grade summaries. The ESP32 RFID Scanner autonomously captures 13.56 MHz card taps and transmits scan timestamps over Wi-Fi while receiving buzzer and LED status cues; Firebase Authentication processes credential verification requests and returns role-scoped JWT tokens; and Supabase executes backend database transactions under Row-Level Security (RLS) enforcement and triggers daily 23:59 automated absent jobs.")
    
    # Level 1 DFD Overview
    add_figure_image_and_caption(doc, "activity2_dfd_level1_overview.png", "Figure 2", "Level 1 DFD Overview of CLASSREALM")
    add_p(doc, "Figure 2 presents the Level 1 DFD Overview of CLASSREALM, decomposing the central system into five major sub-processes: Process 1.0 (User Authentication & Role Verification), Process 2.0 (RFID & Manual Attendance Management), Process 3.0 (Assessment, Classwork & Automated Grade Computation), Process 4.0 (Lesson Planning & Learning Materials Repository), and Process 5.0 (System Administration & Academic Configuration). The diagram delineates the exact inter-process data communication pathways and data store linkages. Process 1.0 verifies user identities against Firebase Auth and populates D1 (User Accounts); Process 2.0 receives card scans from the ESP32 scanner and teacher overrides, reads schedule cutoffs from D2, and writes verified logs to D2 (Attendance & Rosters); Process 3.0 retrieves enrolled rosters from D2, ingests student submissions and quiz responses, and persists evaluated marks in D3 (Classwork & Assessments); Process 4.0 enables teachers to author lesson guides and upload instructional files into D4 (Lesson Plans & Materials); and Process 5.0 allows the Administrator to manage academic year rollovers and monitor audit trails in D5 (System Settings & Audit).")
    
    # Sub-process 1.0
    add_h2(doc, "Sub-process 1.0: User Authentication & Role Verification")
    add_figure_image_and_caption(doc, "activity2_dfd_level1_proc1.png", "Figure 3", "Sub-process 1.0 DFD — User Authentication & Role Verification")
    add_p(doc, "Figure 3 illustrates the sub-process decomposition of Process 1.0 into four constituent operations: 1.1 Process Login Credentials, 1.2 Verify Role & Session with Firebase Auth, 1.3 Manage Teacher Account Requests, and 1.4 Link Parent-Student Relationship. Sub-process 1.1 accepts user credentials from Admin, Teacher, Student, and Parent portals; sub-process 1.2 transmits credentials to Firebase Authentication, receives the verified JWT containing user UID claims, cross-references D1 to verify active profile status, and establishes role-scoped dashboard permissions; sub-process 1.3 processes administrative teacher provisioning and verification challenges; and sub-process 1.4 validates parental relationship links to enforce Row-Level Security data boundaries.")
    
    # Sub-process 2.0
    add_h2(doc, "Sub-process 2.0: RFID & Manual Attendance Management")
    add_figure_image_and_caption(doc, "activity2_dfd_level1_proc2.png", "Figure 4", "Sub-process 2.0 DFD — RFID & Manual Attendance Management")
    add_p(doc, "Figure 4 details the operational flow of Process 2.0 across seven specialized sub-processes: 2.1 Assign RFID Card to Student, 2.2 Validate Class Schedule & Cutoff Window, 2.3 Record RFID Scan Event, 2.4 Record Manual Roster Override, 2.5 Synchronize Offline Attendance Buffer, 2.6 Execute 23:59 Auto-Absent Job, and 2.7 Dispatch Absence Warning Alerts. Sub-process 2.1 captures card UIDs from USB or NFC readers, enforces school-wide duplicate conflict detection, and writes mappings to D2; sub-process 2.2 verifies active class hours; sub-process 2.3 ingests hardware scans, evaluates Present (<=15 min) or Late (<=45 min) status, and emits hardware audio/visual cues; sub-process 2.4 allows authoritative teacher manual edits; sub-process 2.5 drains offline flash buffers upon network reconnection; sub-process 2.6 automatically flags unscanned students as Absent at 23:59 on scheduled class days; and sub-process 2.7 alerts parents upon accumulated absences.")
    
    # Sub-process 3.0
    add_h2(doc, "Sub-process 3.0: Assessment, Classwork & Grade Computation")
    add_figure_image_and_caption(doc, "activity2_dfd_level1_proc3.png", "Figure 5", "Sub-process 3.0 DFD — Assessment, Classwork & Grade Computation")
    add_p(doc, "Figure 5 delineates the architectural flow of Process 3.0 across six sub-processes: 3.1 Create Classwork & Activities, 3.2 Author Quizzes/Exams & Answer Keys, 3.3 Receive Student Submissions, 3.4 Auto-Check Objective Responses & Log Suspicious Events, 3.5 Calculate DepEd Weighted Components, and 3.6 Apply Transmutation Table & Export SF9. Sub-process 3.1 and 3.2 store learning tasks and test questions into D3; sub-process 3.3 receives student file uploads and enforces deadline cutoffs; sub-process 3.4 automatically compares multiple-choice responses against answer keys and logs browser tab-blur security events; sub-process 3.5 computes percentage scores according to DepEd Senior High School Core weights (WW 20%, PT 50%, EX 30%); and sub-process 3.6 applies official DepEd Order 8 s. 2015 transmutation tables to produce official electronic class records.")
    
    # Sub-process 4.0
    add_h2(doc, "Sub-process 4.0: Lesson Planning & Learning Materials Repository")
    add_figure_image_and_caption(doc, "activity2_dfd_level1_proc4.png", "Figure 6", "Sub-process 4.0 DFD — Lesson Planning & Materials Repository")
    add_p(doc, "Figure 6 exhibits the operational structure of Process 4.0 across three sub-processes: 4.1 Author ILAW Lesson Plan Guide, 4.2 Map DepEd Curriculum Competencies, and 4.3 Upload & Organize Instructional Materials. Sub-process 4.1 utilizes an AI-guided wizard to formulate four-part lesson plans adhering to the ILAW structure (Introduction, Learning Competency, Activities, Wrap-up); sub-process 4.2 binds lesson plans to official DepEd Most Essential Learning Competencies (MELCs) in D4; and sub-process 4.3 manages cloud storage uploads for reviewer handouts, lecture slides, and PDF modules accessible by enrolled learners.")
    
    # PART C — VALIDATION
    add_h1(doc, "PART C — VALIDATION", center=False)
    add_h2(doc, "5. Requirement-to-DFD Mapping")
    add_p(doc, "To ensure exhaustive traceability between user needs and technical specifications, Table 6 provides a comprehensive bidirectional mapping matrix linking each functional requirement to its corresponding DFD process, sub-processes, persistent data stores, and verification test case.")
    
    add_table_caption(doc, "Table 6", "Requirement-to-DFD Mapping Matrix")
    create_styled_table(doc, a2.TABLE_6_HEADERS, a2.TABLE_6_DATA, col_widths=[0.6, 1.4, 1.1, 0.7, 0.9, 0.8], center_cols=[0, 2, 3])
    add_p(doc, "Table 6 demonstrates that 100% of the functional requirements are represented in the process model without omission. Each requirement corresponds to a verifiable execution pathway supported by persistent database tables and explicit test cases.")
    
    add_h2(doc, "6. DFD Validation Checklist")
    add_p(doc, "The process model was rigorously audited against the foundational Gane and Sarson validation criteria to ensure structural consistency, syntactic validity, and complete absence of modeling anti-patterns.")
    
    add_table_caption(doc, "Table 7", "DFD Validation Checklist")
    create_styled_table(doc, a2.TABLE_7_HEADERS, a2.TABLE_7_DATA, col_widths=[0.5, 1.8, 0.7, 2.5], center_cols=[0, 2])
    add_p(doc, "Table 7 confirms that the CLASSREALM process model satisfies all nine formal Gane-Sarson validation rules. The model exhibits strict conservation of data, contains zero black holes or miracles, prevents illegal entity-to-entity and store-to-store data flows, maintains parent-to-child flow balancing between Level 0 and Level 1, and completely eliminates extraneous non-academic entities.")
    
    add_h2(doc, "7. Notes on the Revised Model")
    add_p(doc, "The revised process model reflects critical architectural refinements established in collaboration with our client partner, Ma'am Karen P. Gonzaga. First, the dual-path attendance pipeline incorporates autonomous ESP32 hardware scanning with local LittleFS flash buffering alongside mobile NFC scanning, guaranteeing uninterrupted attendance tracking during network outages. Second, schedule window guarding and deterministic cutoff thresholds (Present <= 15 min, Late <= 45 min, Absent > 60 min) eliminate arbitrary marking while preserving permanent teacher manual override authority. Third, the automated 23:59 backend evaluation job accurately flags absences without misidentifying non-scheduled days or official holidays. Finally, all irrelevant non-academic entities (such as financial billing, payment collection, and optical mark sheet scanners) have been permanently excised, ensuring that CLASSREALM models an authentic, highly focused educational management solution tailored exclusively for Eduardo Barretto Sr. High School.")
    
    doc.add_page_break()
    
    # ==========================================================================
    # ACTIVITY #4: INTEGRATED UML AND DATA MODELING
    # ==========================================================================
    print("Generating Activity #4...")
    add_h1(doc, "ACTIVITY #4")
    add_h1(doc, "INTEGRATED UML AND DATA MODELING")
    
    add_p(doc, "Activity #4 presents the integrated object-oriented and relational data modeling specifications for CLASSREALM. By integrating four standard UML and data modeling perspectives—Entity-Relationship Modeling, Use Case Modeling, Class Modeling, and Concrete Runtime Object Modeling—this document provides an end-to-end blueprint of the system's static architecture, behavioral dynamics, and physical data structures. All specifications strictly correspond to the production Flutter and Supabase codebase verified in our architectural baseline.")
    
    # PART A — DESIGN BASIS
    add_h1(doc, "PART A — DESIGN BASIS", center=False)
    add_h2(doc, "1. The System Being Modeled")
    add_p(doc, "CLASSREALM is an integrated Senior High School educational management platform developed for client partner Ma'am Karen P. Gonzaga, Senior High School Mathematics Teacher at Eduardo Barretto Sr. High School in Calamba City, Laguna. The platform provides edge-buffered RFID and mobile NFC attendance capture, classroom section and roster management, digital activity and timed assessment administration, automated DepEd Order 8 s. 2015 grade computation, AI-assisted ILAW lesson planning, and centralized instructional materials organization. The system is engineered as an offline-first mobile and web application utilizing Flutter, Drift SQLite local storage, ESP32 DevKit V1 hardware with MFRC522 RFID readers, Firebase Authentication, and Supabase PostgreSQL cloud backend with Row-Level Security.")
    
    add_h2(doc, "2. How the Four Models Fit Together")
    add_p(doc, "To provide a complete architectural specification, CLASSREALM is modeled across four interconnected views: the Data Persistence View (ERD), the Functional & Behavioral View (Use Case Diagram), the Static Structural Object-Oriented View (Class Diagram), and the Concrete Dynamic Runtime Snapshot View (Object Diagram). Each model addresses a distinct engineering question while maintaining 100% semantic and structural harmony with the other views.")
    
    add_table_caption(doc, "Table 1", "Summary Matrix of the Four UML Models")
    create_styled_table(doc, a4.TABLE_1_HEADERS, a4.TABLE_1_DATA, col_widths=[1.1, 1.0, 1.2, 0.9, 1.3], center_cols=[0])
    add_p(doc, "Table 1 summarizes the scope, perspective, and core deliverables of the four modeling views. The matrix confirms that entity names, class definitions, and use case boundaries remain fully synchronized across all design artifacts.")
    
    # PART B — DATA MODELING
    add_h1(doc, "PART B — DATA MODELING", center=False)
    add_h2(doc, "3. Entities and Relationships")
    add_p(doc, "The relational data model of CLASSREALM is engineered in Third Normal Form (3NF) to guarantee transactional integrity, eliminate data redundancy, and support high-performance indexing across mobile and cloud platforms. The schema comprises 24 relational tables organized into nine cohesive architectural modules: User Identity & Profiles, Academic & Section Management, RFID Hardware & Attendance, Classwork & Submissions, Digital Assessments, Grading Components, Curriculum & Materials, System Configuration & Security, and Notifications.")
    
    # ERD Figure
    add_figure_image_and_caption(doc, "activity4_erd.png", "Figure 7", "Entity-Relationship Diagram (ERD) of CLASSREALM")
    add_p(doc, "Figure 7 illustrates the complete Entity-Relationship Diagram (ERD) of CLASSREALM, depicting all 24 relational database entities, primary keys (PK), foreign keys (FK), and explicit cardinalities using Crow's Foot notation. The central spine of the database connects users to role-specific profile extensions (admin_profiles, teacher_profiles, student_profiles, parent_profiles) via 1:1 specialization relationships. The academic hierarchy links school_years to sections (1:N) and subjects to subject_offerings (1:N), which are bound to students through class_rosters. Attendance operations link student_profiles and subject_offerings to attendance_records, configured by attendance_cutoffs and captured via rfid_cards. The assessment engine branches into activities/submissions and assessments/questions/assessment_responses, feeding directly into grading_components and quarterly_grades. Finally, teacher pedagogical workflows are supported by lesson_plans and learning_materials, while operational stability is monitored through audit_logs and notifications.")
    
    # Data Dictionaries
    add_h3(doc, "Data Dictionary: User Identity & Profile Entities")
    add_table_caption(doc, "Table 2", "Data Dictionary — User Identity and Profile Entities")
    create_styled_table(doc, a4.TABLE_2_HEADERS, a4.TABLE_2_DATA, col_widths=[1.2, 1.1, 1.1, 0.6, 1.5], center_cols=[1, 3])
    add_p(doc, "Table 2 details the attributes, data types, key constraints, and descriptions for the core identity and profile entities (users, admin_profiles, teacher_profiles, student_profiles, parent_profiles, parent_student_links). Foreign keys enforce cascade deletions while preserving unique 12-digit DepEd LRNs and physical RFID UIDs.")
    
    add_h3(doc, "Data Dictionary: Academic & Section Management Entities")
    add_table_caption(doc, "Table 3", "Data Dictionary — Academic and Section Management Entities")
    create_styled_table(doc, a4.TABLE_3_HEADERS, a4.TABLE_3_DATA, col_widths=[1.2, 1.1, 1.1, 0.6, 1.5], center_cols=[1, 3])
    add_p(doc, "Table 3 specifies the academic structure entities (school_years, sections, subjects, subject_offerings, class_schedules, class_rosters). The subject_offerings bridge entity encapsulates teacher assignment, section enrollment, and DepEd component percentage weights.")
    
    add_h3(doc, "Data Dictionary: RFID Hardware & Attendance Entities")
    add_table_caption(doc, "Table 4", "Data Dictionary — RFID Hardware and Attendance Entities")
    create_styled_table(doc, a4.TABLE_4_HEADERS, a4.TABLE_4_DATA, col_widths=[1.2, 1.1, 1.1, 0.6, 1.5], center_cols=[1, 3])
    add_p(doc, "Table 4 defines physical card inventory and daily attendance tracking entities (rfid_cards, attendance_cutoffs, attendance_records). Attributes capture scan timestamps, evaluated operational status (Present, Late, Absent, Excused), recording source ('RFID' vs 'Manual'), and sync status.")
    
    add_h3(doc, "Data Dictionary: Classwork & Student Submission Entities")
    add_table_caption(doc, "Table 5", "Data Dictionary — Classwork and Student Submission Entities")
    create_styled_table(doc, a4.TABLE_5_HEADERS, a4.TABLE_5_DATA, col_widths=[1.2, 1.1, 1.1, 0.6, 1.5], center_cols=[1, 3])
    add_p(doc, "Table 5 specifies instructional classwork activities and student submission deliverables (activities, submissions). Submissions capture document URLs, automated upload timestamps, raw scores, and evaluation lifecycle states.")
    
    add_h3(doc, "Data Dictionary: Digital Assessment & Scoring Entities")
    add_table_caption(doc, "Table 6", "Data Dictionary — Digital Assessment and Scoring Entities")
    create_styled_table(doc, a4.TABLE_6_HEADERS, a4.TABLE_6_DATA, col_widths=[1.2, 1.1, 1.1, 0.6, 1.5], center_cols=[1, 3])
    add_p(doc, "Table 6 outlines online quiz and examination structures (assessments, questions, assessment_responses). Multiple-choice options are stored as structured JSONB arrays, and responses record individual item correctness and earned points.")
    
    add_h3(doc, "Data Dictionary: Grading Components & Transmutation Entities")
    add_table_caption(doc, "Table 7", "Data Dictionary — Grading Components and Transmutation Entities")
    create_styled_table(doc, a4.TABLE_7_HEADERS, a4.TABLE_7_DATA, col_widths=[1.2, 1.1, 1.1, 0.6, 1.5], center_cols=[1, 3])
    add_p(doc, "Table 7 defines DepEd component weight profiles and quarterly report card marks (grading_components, quarterly_grades). The quarterly_grades entity stores component weighted percentages, initial grades, and official DepEd transmuted grades.")
    
    add_h3(doc, "Data Dictionary: Lesson Planning & Learning Materials Entities")
    add_table_caption(doc, "Table 8", "Data Dictionary — Lesson Planning and Learning Materials Entities")
    create_styled_table(doc, a4.TABLE_8_HEADERS, a4.TABLE_8_DATA, col_widths=[1.2, 1.1, 1.1, 0.6, 1.5], center_cols=[1, 3])
    add_p(doc, "Table 8 specifies pedagogical planning and instructional repository entities (lesson_plans, learning_materials). Structured ILAW content is stored as JSONB alongside DepEd curriculum competency codes and cloud storage download links.")
    
    add_h3(doc, "Data Dictionary: System Configuration & Security Audit Entities")
    add_table_caption(doc, "Table 9", "Data Dictionary — System Configuration and Security Audit Entities")
    create_styled_table(doc, a4.TABLE_9_HEADERS, a4.TABLE_9_DATA, col_widths=[1.2, 1.1, 1.1, 0.6, 1.5], center_cols=[1, 3])
    add_p(doc, "Table 9 defines application parameters and immutable audit trails (system_settings, audit_logs). The audit_logs entity records user actions, target tables, old/new state JSON payloads, and timestamps for institutional security audits.")
    
    add_h3(doc, "Data Dictionary: Notification & Communication Entities")
    add_table_caption(doc, "Table 10", "Data Dictionary — Notification and Communication Entities")
    create_styled_table(doc, a4.TABLE_10_HEADERS, a4.TABLE_10_DATA, col_widths=[1.2, 1.1, 1.1, 0.6, 1.5], center_cols=[1, 3])
    add_p(doc, "Table 10 details multi-channel messaging entities (notifications, notification_recipients), supporting in-app push alerts and absence warnings sent to parents.")
    
    # Cardinalities Tables
    add_h3(doc, "Relational Cardinalities and Integrity Constraints")
    add_table_caption(doc, "Table 11", "Core Academic and Identity Relationships")
    create_styled_table(doc, a4.TABLE_11_HEADERS, a4.TABLE_11_DATA, col_widths=[1.1, 1.1, 0.8, 1.2, 0.7, 0.6], center_cols=[2, 4])
    add_p(doc, "Table 11 describes the structural cardinalities, relationship names, foreign keys, and referential integrity actions for the core academic and user identity modules.")
    
    add_table_caption(doc, "Table 12", "Assessment, Grading, and Operational Relationships")
    create_styled_table(doc, a4.TABLE_12_HEADERS, a4.TABLE_12_DATA, col_widths=[1.1, 1.1, 0.8, 1.2, 0.7, 0.6], center_cols=[2, 4])
    add_p(doc, "Table 12 outlines the cardinalities and cascading integrity actions governing attendance, assessments, quarterly grades, lesson plans, materials, and system notifications.")
    
    # PART C — USE CASE MODELING
    add_h1(doc, "PART C — USE CASE MODELING", center=False)
    add_h2(doc, "4. Actors and Use Cases")
    add_p(doc, "The functional capabilities of CLASSREALM are formally organized into 28 discrete use cases distributed across six functional subsystems. The system interacts with five distinct actors: four human user roles (System Administrator, Teacher, Student, Parent) and one edge hardware actor (ESP32 RFID Scanner). The use case architecture strictly enforces standard UML stereotyping, incorporating <<include>> relationships for mandatory sub-tasks and <<extend>> relationships for conditional or exceptional branches.")
    
    # Use Case Figure
    add_figure_image_and_caption(doc, "activity4_use_case.png", "Figure 8", "Use Case Diagram of CLASSREALM")
    add_p(doc, "Figure 8 exhibits the complete Use Case Diagram of CLASSREALM, depicting all five actors and their operational associations across the six subsystems: Identity & User Account Management, Classroom & Section Management, Dual-Path Attendance Tracking, Classwork & Digital Assessments, Grade Computation & DepEd Reports, and Lesson Planning & Learning Repository. Notice that Record Attendance <<includes>> Scan RFID Tag and <<extends>> Trigger Hardware Audio/Visual Indicator and Override Attendance Status Manually; Take Digital Assessment <<includes>> Auto-Check Objective Responses and <<extends>> Log Tab-Blur Anti-Cheating Event; and Compute DepEd Quarterly Grades <<includes>> Configure Grading Weights and Apply DepEd Transmutation Table.")
    
    # Use Case Summaries
    add_h3(doc, "Subsystem 1: Identity & User Account Management")
    add_table_caption(doc, "Table 13", "Use Case Summary — Identity and User Account Management")
    create_styled_table(doc, a4.TABLE_13_HEADERS, a4.TABLE_13_DATA, col_widths=[0.8, 1.3, 1.0, 0.8, 0.5, 1.1], center_cols=[0, 4])
    
    add_h3(doc, "Subsystem 2: Classroom & Section Management")
    add_table_caption(doc, "Table 14", "Use Case Summary — Classroom and Section Management")
    create_styled_table(doc, a4.TABLE_14_HEADERS, a4.TABLE_14_DATA, col_widths=[0.8, 1.3, 0.9, 0.8, 0.5, 1.2], center_cols=[0, 4])
    
    add_h3(doc, "Subsystem 3: Dual-Path Attendance Tracking")
    add_table_caption(doc, "Table 15", "Use Case Summary — Dual-Path Attendance Tracking")
    create_styled_table(doc, a4.TABLE_15_HEADERS, a4.TABLE_15_DATA, col_widths=[0.8, 1.3, 1.0, 0.8, 0.5, 1.1], center_cols=[0, 4])
    
    add_h3(doc, "Subsystem 4: Classwork & Digital Assessments")
    add_table_caption(doc, "Table 16", "Use Case Summary — Classwork and Digital Assessments")
    create_styled_table(doc, a4.TABLE_16_HEADERS, a4.TABLE_16_DATA, col_widths=[0.8, 1.3, 0.9, 0.8, 0.5, 1.2], center_cols=[0, 4])
    
    add_h3(doc, "Subsystem 5: Grade Computation & DepEd Reports")
    add_table_caption(doc, "Table 17", "Use Case Summary — Grade Computation and DepEd Reports")
    create_styled_table(doc, a4.TABLE_17_HEADERS, a4.TABLE_17_DATA, col_widths=[0.8, 1.3, 0.9, 0.8, 0.5, 1.2], center_cols=[0, 4])
    
    add_h3(doc, "Subsystem 6: Lesson Planning & Learning Repository")
    add_table_caption(doc, "Table 18", "Use Case Summary — Lesson Planning and Learning Repository")
    create_styled_table(doc, a4.TABLE_18_HEADERS, a4.TABLE_18_DATA, col_widths=[0.8, 1.3, 0.9, 0.8, 0.5, 1.2], center_cols=[0, 4])
    add_p(doc, "Tables 13 through 18 establish the functional scope of all 28 use cases across the six subsystems, specifying primary actors, secondary actors, mapped functional requirements, and core operational responsibilities.")
    
    # Detailed Use Case Specs
    add_h2(doc, "5. Detailed Step-by-Step Use Case Specifications")
    add_p(doc, "To provide unambiguous implementation guidance for critical system features, Tables 19 through 23 present exhaustive step-by-step specifications for five core operational use cases, detailing triggers, pre-conditions, post-conditions, normal success flows, alternative flows, and UML associations.")
    
    add_table_caption(doc, "Table 19", "Detailed Specification — UC-ATT-01: Record Attendance via RFID Tap")
    create_styled_table(doc, a4.TABLE_19_HEADERS, a4.TABLE_19_DATA, col_widths=[1.5, 4.0], center_cols=[0])
    
    add_table_caption(doc, "Table 20", "Detailed Specification — UC-ATT-02: Synchronize Offline Attendance Records")
    create_styled_table(doc, a4.TABLE_20_HEADERS, a4.TABLE_20_DATA, col_widths=[1.5, 4.0], center_cols=[0])
    
    add_table_caption(doc, "Table 21", "Detailed Specification — UC-ATT-03: Execute 23:59 Automated Absent Job")
    create_styled_table(doc, a4.TABLE_21_HEADERS, a4.TABLE_21_DATA, col_widths=[1.5, 4.0], center_cols=[0])
    
    add_table_caption(doc, "Table 22", "Detailed Specification — UC-ASM-01: Take Digital Assessment")
    create_styled_table(doc, a4.TABLE_22_HEADERS, a4.TABLE_22_DATA, col_widths=[1.5, 4.0], center_cols=[0])
    
    add_table_caption(doc, "Table 23", "Detailed Specification — UC-GRD-01: Compute DepEd Quarterly Grades")
    create_styled_table(doc, a4.TABLE_23_HEADERS, a4.TABLE_23_DATA, col_widths=[1.5, 4.0], center_cols=[0])
    add_p(doc, "Tables 19 through 23 confirm that all mission-critical workflows—hardware RFID sensing, offline flash synchronization, scheduled absence evaluation, timed quiz administration with anti-cheating telemetry, and DepEd Order 8 s. 2015 grade transmutation—are formally specified with deterministic logic and robust exception handling.")
    
    # PART D — CLASS MODELING
    add_h1(doc, "PART D — CLASS MODELING", center=False)
    add_h2(doc, "6. Classes and Associations")
    add_p(doc, "The static software architecture of CLASSREALM is structured around object-oriented principles of encapsulation, inheritance, polymorphism, and composition. The class model defines an abstract base User class specialized into concrete user roles (AdminUser, TeacherUser, StudentUser, ParentUser); domain entity classes corresponding to database tables; and stateless service engines (such as DepEdGradingEngine and SyncCoordinator) that encapsulate core business logic. Visibility modifiers strictly follow UML standards: public (+), protected (#), and private (-).")
    
    # Class Diagram Figure
    add_figure_image_and_caption(doc, "activity4_class_diagram.png", "Figure 9", "Domain Class Diagram of CLASSREALM")
    add_p(doc, "Figure 9 presents the Domain Class Diagram of CLASSREALM, detailing all major application classes, typed attributes, visibility modifiers, and domain methods. The model depicts the generalization hierarchy from the abstract base class User to AdminUser, TeacherUser, StudentUser, and ParentUser. It highlights composite ownership relationships, such as Assessment owning Question (composite aggregation) and Activity owning Submission. In addition, it illustrates associations between Section, Subject, and SubjectOffering, which binds to ClassSchedule and ClassRoster. The attendance module integrates RfidCard, AttendanceCutoff, AttendanceRecord, and OfflineAttendanceQueue; the grading engine encapsulates DepEdGradingEngine and QuarterlyGrade; and curriculum workflows connect TeacherUser to LessonPlan and LearningMaterial.")
    
    # Class Mapping Tables
    add_h3(doc, "Class-to-Entity Mapping Matrices")
    add_table_caption(doc, "Table 24", "Class-to-Entity Mapping — Identity and Classroom Management")
    create_styled_table(doc, a4.TABLE_24_HEADERS, a4.TABLE_24_DATA, col_widths=[1.0, 1.1, 1.0, 1.2, 1.2], center_cols=[0])
    
    add_table_caption(doc, "Table 25", "Class-to-Entity Mapping — Attendance and Assessment Subsystems")
    create_styled_table(doc, a4.TABLE_25_HEADERS, a4.TABLE_25_DATA, col_widths=[1.1, 1.0, 1.1, 1.1, 1.2], center_cols=[0])
    
    add_table_caption(doc, "Table 26", "Class-to-Entity Mapping — Grading, Lesson Planning, and System")
    create_styled_table(doc, a4.TABLE_26_HEADERS, a4.TABLE_26_DATA, col_widths=[1.1, 1.1, 1.1, 1.1, 1.1], center_cols=[0])
    add_p(doc, "Tables 24 through 26 map all software classes to their corresponding database tables, package paths, core responsibilities, and primary domain methods, establishing full architectural alignment between object-oriented code and database persistence.")
    
    # PART E — OBJECT MODELING
    add_h1(doc, "PART E — OBJECT MODELING", center=False)
    add_h2(doc, "7. Concrete Runtime Object Scenarios")
    add_p(doc, "To validate that the class and data models accurately capture operational behavior during live instruction, Figure 10 presents a concrete runtime object diagram capturing a live classroom session at Eduardo Barretto Sr. High School. The scenario models a Friday morning General Mathematics class held in Room 302 from 07:30 to 08:30 AM, conducted by our client partner, Ma'am Karen P. Gonzaga, with enrolled Grade 11 student Juan Dela Cruz.")
    
    # Object Diagram Figure
    add_figure_image_and_caption(doc, "activity4_object_diagram.png", "Figure 10", "Concrete Runtime Object Diagram of CLASSREALM")
    add_p(doc, "Figure 10 illustrates the Concrete Runtime Object Diagram, capturing 17 interrelated runtime object instances and their exact slot values during an active instructional session on Friday, October 24, 2026. The snapshot depicts teacher t001:TeacherUser (fullName='Karen P. Gonzaga', department='Mathematics', approvalStatus='Approved') managing section sec001:Section (name='STEM 11-A', gradeLevel='Grade 11') enrolled in subject offering so001:SubjectOffering (subjectName='General Mathematics', wwWeight=20.00, ptWeight=50.00, exWeight=30.00) scheduled on sch001:ClassSchedule (dayOfWeek='Friday', startTime='07:30', endTime='08:30', room='Room 302'). Enrolled learner s001:StudentUser (lrn='123456789012', fullName='Juan Dela Cruz') is bound to mother p001:ParentUser (fullName='Maria Dela Cruz', contactNumber='09171234567') via psl001:ParentStudentLink (relationship='Mother', isVerified=true). At 07:22:15 AM (eight minutes prior to class start), Juan taps his assigned physical RFID card rfid001:RfidCard (cardUID='E28011052000', status='Assigned'), creating attendance log att001:AttendanceRecord (date='2026-10-24', scanTime='07:22:15', status='Present', recordingMethod='RFID', syncStatus='Synced'). In academic classwork, Juan completed act001:Activity (title='Problem Set 1: Rational Functions', maxScore=50) with submission sub001:Submission (score=48, status='Graded') and took quiz asm001:Assessment (title='Quarter 1 Quiz 1', totalItems=15) answering q001:Question with response resp001:AssessmentResponse (studentAnswer='B', isCorrect=true, pointsEarned=1.0). His cumulative performance is computed in grd001:QuarterlyGrade (quarter='Q1', initialGrade=91.20, transmutedGrade=94, remarks='Passed'). Ma'am Karen guides instruction using lesson plan lp001:LessonPlan (topic='Rational Functions and Equations', weekNumber=2, curriculumCode='M11GM-Ib-1') and uploaded material mat001:LearningMaterial (title='Module 2: Rational Functions Reviewer.pdf').")
    
    # PART F — INTEGRATION AND VALIDATION
    add_h1(doc, "PART F — INTEGRATION AND VALIDATION", center=False)
    add_h2(doc, "8. Traceability Table")
    add_p(doc, "To ensure end-to-end architectural integrity, Table 27 provides an integrated cross-model traceability matrix tracing every functional requirement across the DFD process model, Use Case model, Domain Class model, and ERD relational schema.")
    
    add_table_caption(doc, "Table 27", "Cross-Model Traceability Table")
    create_styled_table(doc, a4.TABLE_27_HEADERS, a4.TABLE_27_DATA, col_widths=[0.6, 1.2, 1.2, 1.2, 1.3], center_cols=[0, 2])
    add_p(doc, "Table 27 proves complete continuity across all architectural models: every functional requirement is realized by dedicated DFD processes, use case interactions, software domain classes, and relational database tables.")
    
    add_h2(doc, "9. Consistency of Names Across the Models")
    add_p(doc, "To prevent architectural ambiguity and ensure consistent engineering terminology, Table 28 presents a consistency dictionary mapping conceptual subsystems across DFD data stores, ERD entities, class names, and use case identifiers.")
    
    add_table_caption(doc, "Table 28", "Consistency of Names Across the Models")
    create_styled_table(doc, a4.TABLE_28_HEADERS, a4.TABLE_28_DATA, col_widths=[1.2, 1.1, 1.1, 1.1, 1.0], center_cols=[4])
    add_p(doc, "Table 28 confirms that naming conventions remain 100% consistent across all models, eliminating semantic discrepancies between process modeling, database schemas, and object-oriented implementations.")
    
    add_h2(doc, "10. Design Review Checklist")
    add_p(doc, "The integrated UML and data models were thoroughly evaluated against the formal IT Capstone design review checklist to confirm syntactic correctness, relational normalization, and client alignment.")
    
    add_table_caption(doc, "Table 29", "Integrated Design Review Checklist")
    create_styled_table(doc, a4.TABLE_29_HEADERS, a4.TABLE_29_DATA, col_widths=[0.5, 1.8, 0.7, 2.5], center_cols=[0, 2])
    add_p(doc, "Table 29 confirms that CLASSREALM satisfies all ten design review criteria, demonstrating complete compliance with UML 2.5 standards, Third Normal Form normalization, dual-path attendance edge buffering, and DepEd Order 8 s. 2015 grading regulations.")
    
    add_h2(doc, "11. Design Decisions and System Boundaries")
    add_p(doc, "The architectural design of CLASSREALM embodies five foundational engineering decisions established to address the specific realities of Eduardo Barretto Sr. High School. First, the dual-path attendance capture architecture employs standalone ESP32 DevKit V1 microcontrollers with MFRC522 RFID readers as the primary door scanner, supported by teacher mobile phone NFC scanning as an operational fallback. Both paths utilize local non-volatile spooling (LittleFS JSONL on ESP32 and Drift SQLite on mobile), ensuring zero data loss during network disruptions. Second, deterministic conflict resolution prioritizes teacher manual edits over automated hardware scans and enforces monotonicity, guaranteeing that attendance marks are never downgraded by delayed offline sync packets. Third, system boundaries strictly isolate administrative infrastructure provisioning from teacher academic self-management, granting the client teacher total autonomy over rosters, subjects, and grading while excluding external school administrative roles (such as registrar, financial bursar, and collection staff). Fourth, the grading engine directly encapsulates the percentage weighting (WW 20%, PT 50%, EX 30%) and transmutation tables mandated by DepEd Order 8, s. 2015, automating the generation of official School Form 9 (SF9) report cards. Finally, all vestigial entities from external classmate templates (such as tuition billing, financial payment accounts, and optical mark paper scanners) have been permanently excluded, delivering an authentic, unified, and production-ready Capstone deliverable.")
    
    # Save the document
    print(f"Saving compiled document to: {TARGET_DOCX}")
    doc.save(TARGET_DOCX)
    print("Document successfully compiled and saved!")

if __name__ == '__main__':
    build_activities_document()
