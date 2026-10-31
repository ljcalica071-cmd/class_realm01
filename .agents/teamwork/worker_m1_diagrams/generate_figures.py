import os
from PIL import Image, ImageDraw, ImageFont
from diagram_engine import (
    PALETTE, FONTS, text_size, wrap_text,
    draw_header, draw_footer, draw_card, draw_bullet_item,
    draw_badge, draw_arrow, draw_elbow_arrow
)

OUTPUT_DIR = "c:/Users/Admin/AndroidStudioProjects/class_realm01/docs/diagrams"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# ==============================================================================
# FIGURE 1: IPSO DIAGRAM (Input - Process - Storage - Output)
# ==============================================================================
def generate_figure1():
    width = 3400
    height = 2000
    img = Image.new('RGB', (width, height), PALETTE['canvas_bg'])
    draw = ImageDraw.Draw(img)
    
    draw_header(
        draw, width,
        "Figure 1: Input - Process - Storage - Output (IPSO) Conceptual Framework",
        "System Architecture, Dual-Path Data Ingestion, Hybrid Persistence & DepEd Academic Deliverables",
        "CLASSREALM ARCHITECTURE • CONCEPTUAL FRAMEWORK"
    )
    
    col_w = 720
    col_gap = 50
    start_x = 180
    top_y = 190
    card_h = 1580
    
    cols_data = [
        {
            'title': '1. INPUT',
            'subtitle': 'Data Ingestion & Hardware Triggers',
            'header_bg': PALETTE['navy'],
            'accent': PALETTE['slate_blue'],
            'bg': PALETTE['white'],
            'items': [
                ("User Credentials:", "Role-based credentials (Admin, Teacher, Student, Parent) for identity verification."),
                ("Master Rosters:", "Student LRNs, personal profiles, section assignments from DepEd official records."),
                ("RFID Card Taps:", "13.56 MHz ISO 14443A card UIDs scanned via ESP32 RC522 door module."),
                ("Manual Overrides:", "Teacher mobile/web attendance entry (Present, Late, Absent, Excused fallback)."),
                ("Plotted Schedules:", "Class start/end times, room designations, and calendar holiday restrictions."),
                ("DepEd Criteria:", "DO 8 s. 2015 & DO 15 weights (Written Work 20%, PT 50%, Quarterly Exam 30%)."),
                ("Classwork & Items:", "Teacher learning tasks, quiz questions, objective answer keys, and file attachments."),
                ("ILAW Directives:", "Curriculum guide competencies and teacher instructional prompts.")
            ],
            'badges': ["13.56MHz RFID", "Mobile NFC", "Master Rosters", "DO 15 Criteria"]
        },
        {
            'title': '2. PROCESS',
            'subtitle': 'Core Computing & Validation Engines',
            'header_bg': PALETTE['purple'],
            'accent': PALETTE['purple_border'],
            'bg': PALETTE['white'],
            'items': [
                ("Authentication:", "Firebase Auth JWT verification, role validation, and Supabase RLS context binding."),
                ("Dual-Path Evaluation:", "Schedule-bound scan validation, grace cutoff checking (Present ≤15m, Late ≤45m)."),
                ("Auto-Absent Job:", "Automated 23:59 server cron marking unscanned students for scheduled classes."),
                ("Offline Sync Queue:", "SyncCoordinator 45s cycle draining Drift queue with monotonic timestamp rules."),
                ("Assessment Engine:", "Instant objective quiz auto-scoring and anti-cheating window-blur event logging."),
                ("DepEd Transmutation:", "Initial percentage computation and transmutation table mapping (70–100 scale)."),
                ("ILAW AI Generator:", "Google Gemini-powered generation of 4-part ILAW lesson plans and guides."),
                ("Resource Security:", "Row-Level Security isolation ensuring student/parent view-only authorization.")
            ],
            'badges': ["FreeRTOS Core 1", "SyncCoordinator", "DO 15 Engine", "Gemini ILAW"]
        },
        {
            'title': '3. STORAGE',
            'subtitle': 'Hybrid Cloud, Local & Edge Persistence',
            'header_bg': PALETTE['emerald'],
            'accent': PALETTE['emerald_border'],
            'bg': PALETTE['white'],
            'items': [
                ("Supabase PostgreSQL:", "42+ relational tables enforcing strict RLS policies, foreign keys, and indexes."),
                ("Drift + SQLite DB:", "14 local tables ('classrealm_local_db') providing full offline mobile persistence."),
                ("ESP32 LittleFS Buffer:", "Non-volatile SPI flash spool ('/spool/attendance_queue.jsonl', >6,800 offline scans)."),
                ("Offline Sync Queue:", "Drift write-ahead queue tracking pending mutations, payloads, and retry counts."),
                ("Cloud Storage:", "Supabase Storage buckets ('learning_materials' and 'classwork-materials')."),
                ("Realtime Subscriptions:", "9 WebSocket channels broadcasting live attendance, alerts, and settings updates."),
                ("Audit & System Logs:", "Tamper-evident logs of teacher provisioning, AY rollovers, and auth attempts."),
                ("Identity Store:", "Firebase Authentication directory managing identity provider credentials.")
            ],
            'badges': ["PostgreSQL RLS", "Drift SQLite", "LittleFS Flash", "Storage Buckets"]
        },
        {
            'title': '4. OUTPUT',
            'subtitle': 'Academic Deliverables & Analytics',
            'header_bg': PALETTE['sky'],
            'accent': PALETTE['sky'],
            'bg': PALETTE['white'],
            'items': [
                ("Live Attendance Logs:", "Roster data table with explicit recording method tags ('RFID' vs 'Manual')."),
                ("Early Warning Alerts:", "Push & SMS notifications triggered for students accumulating ≥3 absences."),
                ("DepEd E-Class Records:", "Official SF9 report cards and electronic class records exportable for school records."),
                ("Teacher Analytics:", "Section attendance rates, grade distributions, and at-risk student lists."),
                ("Student Portal App:", "View-only personal attendance history, submitted classwork scores, and grades."),
                ("Parent Portal App:", "Child-specific attendance monitoring, absence warnings, and term report cards."),
                ("ILAW Lesson Guides:", "Standardized lesson plans exportable in clean DOCX and PDF formats."),
                ("Materials Library:", "Organized instructional handouts, presentations, and reviewer repositories.")
            ],
            'badges': ["DepEd SF9 / ECR", "Push Alerts", "4 Actor Portals", "Export DOCX/PDF"]
        }
    ]
    
    # Draw Columns
    for i, col in enumerate(cols_data):
        cx = start_x + i * (col_w + col_gap)
        draw_card(
            draw, cx, top_y, col_w, card_h,
            col['title'], col['subtitle'],
            bg=col['bg'], border=col['accent'], border_w=3, radius=14,
            header_bg=col['header_bg'], header_h=70
        )
        
        # Badges row
        bx = cx + 24
        by = top_y + 86
        for b in col['badges']:
            bx = draw_badge(draw, bx, by, b, bg=PALETTE['card_alt_bg'], text_color=PALETTE['text_dark']) + 8
            
        # Divider line
        draw.line([(cx + 20, top_y + 128), (cx + col_w - 20, top_y + 128)], fill=PALETTE['border_light'], width=2)
        
        # Items
        cur_y = top_y + 144
        for prefix, desc in col['items']:
            cur_y = draw_bullet_item(draw, cx + 24, cur_y, col_w - 48, prefix, desc, bullet="▪", icon_color=col['accent'])
            cur_y += 18
            
    # Connectors between columns
    for i in range(3):
        x1 = start_x + (i + 1) * col_w + i * col_gap
        x2 = x1 + col_gap
        y_mid = top_y + card_h / 2
        draw_arrow(draw, (x1 + 4, y_mid), (x2 - 4, y_mid), color=PALETTE['navy'], width=5)
        draw_arrow(draw, (x1 + 4, y_mid - 280), (x2 - 4, y_mid - 280), color=PALETTE['slate_blue'], width=4)
        draw_arrow(draw, (x1 + 4, y_mid + 280), (x2 - 4, y_mid + 280), color=PALETTE['slate_blue'], width=4)
        
    # Bottom Feedback Loop
    feedback_y = top_y + card_h + 40
    p1 = (start_x + col_w * 3 + col_gap * 3 - 80, top_y + card_h)
    p2 = (p1[0], feedback_y)
    p3 = (start_x + 80, feedback_y)
    p4 = (p3[0], top_y + card_h)
    
    draw_elbow_arrow(
        draw, [p1, p2, p3, p4],
        label="REVERSE FEEDBACK & VERIFICATION LOOP",
        sublabel="Continuous Performance Analytics, Absence Interventions, Grade Adjustments & Offline Sync Reconciliation",
        color=PALETTE['amber'], width=4, dashed=True, arrow_at_end=True
    )
    
    draw_footer(draw, width, height)
    
    out_path = os.path.join(OUTPUT_DIR, "figure1_ipso_diagram.png")
    img.save(out_path, dpi=(300, 300))
    print(f"Generated: {out_path} ({width}x{height})")


# ==============================================================================
# FIGURE 2: IPO DIAGRAM (Input - Process - Output)
# ==============================================================================
def generate_figure2():
    width = 3200
    height = 1900
    img = Image.new('RGB', (width, height), PALETTE['canvas_bg'])
    draw = ImageDraw.Draw(img)
    
    draw_header(
        draw, width,
        "Figure 2: Input - Process - Output (IPO) Operational Model",
        "Operational Transformation Flow, Schedule-Bound Gateways & Automated Academic Reporting",
        "CLASSREALM ARCHITECTURE • OPERATIONAL MODEL"
    )
    
    col_w = 880
    col_gap = 90
    start_x = 180
    top_y = 190
    card_h = 1480
    
    columns = [
        {
            'title': 'INPUT',
            'subtitle': 'System Inputs & Triggering Payloads',
            'header_bg': PALETTE['navy'],
            'accent': PALETTE['slate_blue'],
            'sections': [
                ("User Credentials & Provisioning", [
                    ("Admin & Teacher Accounts:", "Email, password, role assignment, and administrative activation tokens."),
                    ("Student & Parent Identifiers:", "Learner Reference Numbers (LRN), verified parent authorization codes.")
                ]),
                ("Classroom & Academic Setup", [
                    ("Master Class Rosters:", "Student profiles, section assignments, and enrolled subject offerings."),
                    ("Plotted Class Schedules:", "Weekly timetables (day, start time, end time, room) and school holiday dates."),
                    ("DepEd Grading Scales:", "DepEd Order 8 s. 2015 / DO 15 component weight distributions (20-50-30).")
                ]),
                ("Live Operational & Hardware Signals", [
                    ("RFID Tap Events:", "13.56 MHz ISO 14443A card UIDs scanned via ESP32 RC522 door reader."),
                    ("Manual Roster Entries:", "Teacher web/mobile attendance marks with explicit override tags."),
                    ("Student Submissions:", "Uploaded classwork files (PDF/DOCX) and digital assessment responses."),
                    ("Curriculum Specifications:", "Teacher lesson prompts, competencies, and learning resource uploads.")
                ])
            ]
        },
        {
            'title': 'PROCESS',
            'subtitle': 'Business Logic & Automated Transformations',
            'header_bg': PALETTE['purple'],
            'accent': PALETTE['purple_border'],
            'sections': [
                ("Identity & Security Governance", [
                    ("Firebase Token Verification:", "JWT validation and role claim injection for authenticated sessions."),
                    ("Row-Level Security Scoping:", "PostgreSQL RLS policies isolating records per user role and student.")
                ]),
                ("Attendance Engine & Sync Pipeline", [
                    ("Schedule Guarding:", "Reject scans outside plotted class hours or on declared school holidays."),
                    ("Threshold Evaluation:", "Automatic status tagging: Present (≤15m), Late (≤45m), Absent (>60m)."),
                    ("23:59 Cron Auto-Absent:", "Scheduled backend job marking unscanned students for scheduled classes."),
                    ("Dual-Path Buffer Sync:", "SyncCoordinator background worker draining LittleFS & SQLite buffers.")
                ]),
                ("Academic & Instructional Computation", [
                    ("Quiz Auto-Scoring:", "Instant objective item scoring and anti-cheating tab-blur event logging."),
                    ("DepEd Grade Transmutation:", "Weighted component summation and transmutation to official 70–100 scale."),
                    ("ILAW AI Lesson Structuring:", "Google Gemini-assisted generation of 4-part ILAW lesson plan guides.")
                ])
            ]
        },
        {
            'title': 'OUTPUT',
            'subtitle': 'Generated Artifacts, Dashboards & Records',
            'header_bg': PALETTE['emerald'],
            'accent': PALETTE['emerald_border'],
            'sections': [
                ("Attendance & Safety Reporting", [
                    ("Live Attendance Rosters:", "Synchronized attendance sheets showing 'RFID' vs 'Manual' source indicators."),
                    ("Early Warning Alerts:", "Automated push & SMS notifications for students with ≥3 accumulated absences."),
                    ("Section Attendance KPIs:", "Aggregate attendance rates, tardiness trends, and excuse tracking.")
                ]),
                ("Official DepEd Academic Records", [
                    ("Electronic Class Records (ECR):", "DepEd Form 137 / SF9 grade sheets with transmuted quarterly ratings."),
                    ("Student Performance Analytics:", "Individual quarterly grade breakdowns, rank analysis, and remarks.")
                ]),
                ("Role-Specific Portals & Resources", [
                    ("Teacher Command Center:", "Classroom management, gradebook, and attendance administration."),
                    ("Student Mobile Portal:", "View-only attendance history, quiz results, and learning materials."),
                    ("Parent Mobile Portal:", "Linked child attendance monitoring and academic report cards."),
                    ("Standardized Lesson Files:", "Exportable ILAW lesson plans and categorized student handouts.")
                ])
            ]
        }
    ]
    
    for i, col in enumerate(columns):
        cx = start_x + i * (col_w + col_gap)
        draw_card(
            draw, cx, top_y, col_w, card_h,
            col['title'], col['subtitle'],
            bg=PALETTE['white'], border=col['accent'], border_w=3, radius=14,
            header_bg=col['header_bg'], header_h=70
        )
        
        cur_y = top_y + 90
        for sec_title, items in col['sections']:
            # Section mini-header
            draw.rectangle([cx + 20, cur_y, cx + col_w - 20, cur_y + 36], fill=PALETTE['card_alt_bg'])
            draw.text((cx + 28, cur_y + 6), sec_title.upper(), font=FONTS['body_sm_bold'], fill=col['header_bg'])
            cur_y += 48
            
            for prefix, desc in items:
                cur_y = draw_bullet_item(draw, cx + 24, cur_y, col_w - 48, prefix, desc, bullet="▸", icon_color=col['accent'])
                cur_y += 14
            cur_y += 10
            
    # Connectors between columns
    for i in range(2):
        x1 = start_x + (i + 1) * col_w + i * col_gap
        x2 = x1 + col_gap
        y_mid = top_y + card_h / 2
        draw_arrow(draw, (x1 + 4, y_mid), (x2 - 4, y_mid), color=PALETTE['navy'], width=5)
        draw_arrow(draw, (x1 + 4, y_mid - 250), (x2 - 4, y_mid - 250), color=PALETTE['slate_blue'], width=4)
        draw_arrow(draw, (x1 + 4, y_mid + 250), (x2 - 4, y_mid + 250), color=PALETTE['slate_blue'], width=4)
        
    # Dashed feedback loop
    feedback_y = top_y + card_h + 40
    p1 = (start_x + col_w * 2 + col_gap * 2 - 80, top_y + card_h)
    p2 = (p1[0], feedback_y)
    p3 = (start_x + 80, feedback_y)
    p4 = (p3[0], top_y + card_h)
    
    draw_elbow_arrow(
        draw, [p1, p2, p3, p4],
        label="OPERATIONAL FEEDBACK LOOP",
        sublabel="Continuous Analytics, Attendance Interventions, Offline Reconciliation & Teacher Manual Review",
        color=PALETTE['amber'], width=4, dashed=True, arrow_at_end=True
    )
    
    draw_footer(draw, width, height)
    
    out_path = os.path.join(OUTPUT_DIR, "figure2_ipo_diagram.png")
    img.save(out_path, dpi=(300, 300))
    print(f"Generated: {out_path} ({width}x{height})")


# ==============================================================================
# FIGURE 3: AGILE SCRUM FRAMEWORK
# ==============================================================================
def generate_figure3():
    width = 3400
    height = 2000
    img = Image.new('RGB', (width, height), PALETTE['canvas_bg'])
    draw = ImageDraw.Draw(img)
    
    draw_header(
        draw, width,
        "Figure 3: Agile Scrum Methodology Framework of CLASSREALM",
        "Iterative Sprint Cycles, Hardware/Software Co-Design & Purposive Client Teacher Validation",
        "CLASSREALM METHODOLOGY • AGILE SCRUM FRAMEWORK"
    )
    
    # Top Purposive Sampling Banner
    banner_y = 170
    draw.rounded_rectangle([180, banner_y, width - 180, banner_y + 80], radius=10, fill=PALETTE['amber_bg'], outline=PALETTE['amber_border'], width=2)
    draw.text((210, banner_y + 14), "PURPOSIVE SAMPLING HIGHLIGHT:", font=FONTS['body_bold'], fill=PALETTE['amber'])
    sample_text = "Initial pilot deployment focuses specifically on client teacher Ma'am Karen P. Gonzaga (Senior High School Mathematics) and linked parents at Eduardo Barretto Sr. High School; the underlying software and database architecture is fully engineered for multi-teacher, multi-subject, and multi-section horizontal scaling."
    lines = wrap_text(sample_text, FONTS['body'], width - 440)
    for idx, l in enumerate(lines):
        draw.text((210, banner_y + 40 + idx * 24), l, font=FONTS['body'], fill=PALETTE['text_dark'])
        
    # 4 Main Phase Cards
    phase_w = 720
    phase_gap = 50
    start_x = 180
    top_y = 280
    card_h = 1380
    
    phases = [
        {
            'num': 'PHASE 1',
            'title': 'Sprint 0: Architecture Baseline',
            'subtitle': 'Hardware Prototyping & DB Design',
            'color': PALETTE['navy'],
            'accent': PALETTE['slate_blue'],
            'sprints': [
                ("Requirements Gathering:", "Formal interviews with Ma'am Karen P. Gonzaga at Eduardo Barretto Sr. High School to define DepEd workflows."),
                ("Hardware Benchmarking:", "Prototyping ESP32 DevKit V1 with RC522 13.56 MHz SPI wiring, 3.3V logic level, active buzzer, and tri-color status LEDs."),
                ("Local Persistence:", "Architecting 14 Drift + SQLite tables ('classrealm_local_db') and write-ahead sync queue."),
                ("Cloud Migrations:", "Designing 42+ Supabase PostgreSQL tables with strict Row-Level Security (RLS) policies."),
                ("Product Backlog:", "Decomposing user stories into prioritized sprint backlog items across Web, App, and Hardware.")
            ],
            'deliverable': "Deliverable: Verified Architecture Specification, DB Schemas & Hardware Prototype"
        },
        {
            'num': 'PHASE 2',
            'title': 'Sprint Iterations (2-Week Cycles)',
            'subtitle': 'Modular Development & Integration',
            'color': PALETTE['purple'],
            'accent': PALETTE['purple_border'],
            'sprints': [
                ("Sprint 1 (Auth & Roles):", "Firebase Authentication integration, Admin teacher provisioning, parent-student linking."),
                ("Sprint 2 (Dual-Path Attendance):", "ESP32 FreeRTOS Core 1 scanning, LittleFS buffer spool, Flutter mobile NFC, 23:59 cron auto-absent."),
                ("Sprint 3 (Assessments & Grading):", "Classwork file submissions, digital quiz auto-scoring, DepEd DO 8 / DO 15 weighted transmutation engine."),
                ("Sprint 4 (Lessons & Repo):", "Google Gemini AI-assisted ILAW lesson plan wizard and centralized learning materials bucket."),
                ("Daily Standups (15 min):", "Progress checks, impediment removal, and code quality verification.")
            ],
            'deliverable': "Deliverable: Potentially Shippable Increments & Working Flutter / ESP32 Code"
        },
        {
            'num': 'PHASE 3',
            'title': 'Verification & Client Testing',
            'subtitle': 'Rigorous UAT & Edge-Case Validation',
            'color': PALETTE['emerald'],
            'accent': PALETTE['emerald_border'],
            'sprints': [
                ("Purposive Client UAT:", "Hands-on classroom testing with Ma'am Karen P. Gonzaga using live Grade 11 Mathematics classes."),
                ("Parent Portal Validation:", "Testing real-time absence alerts and mobile attendance transparency with linked parents."),
                ("Offline Sync Stress Test:", "Simulating 1,000+ offline scans buffered on ESP32 LittleFS and Drift SQLite, followed by reconnection drain."),
                ("Edge-Case Validation:", "Enforcing duplicate tap idempotency, cross-section scan rejection, and teacher manual authority."),
                ("DepEd ECR Accuracy:", "Verifying computed grades against official DepEd Excel E-Class Record templates.")
            ],
            'deliverable': "Deliverable: Signed UAT Evaluation, Defect Logs & Verified Accuracy Audit"
        },
        {
            'num': 'PHASE 4',
            'title': 'System Release & Deployment',
            'subtitle': 'Final Classroom Deployment & Handover',
            'color': PALETTE['sky'],
            'accent': PALETTE['sky'],
            'sprints': [
                ("Hardware Installation:", "Permanent deployment of standalone ESP32 RFID door scanner in Room 302 with Li-ion backup power."),
                ("App Distribution:", "Distribution of multi-platform Flutter app (Teacher Web, Student App, Parent App)."),
                ("Roster Onboarding:", "Importing official class rosters and assigning physical 13.56 MHz RFID tags to students."),
                ("User Training & Handover:", "Conducting comprehensive operational training for client teacher and participating parents."),
                ("Sprint Retrospective:", "Documentation of lessons learned, capstone thesis finalization, and maintenance plan.")
            ],
            'deliverable': "Deliverable: Live Production System, User Manuals & Capstone Final Defense"
        }
    ]
    
    for i, p in enumerate(phases):
        cx = start_x + i * (phase_w + phase_gap)
        draw_card(
            draw, cx, top_y, phase_w, card_h,
            p['title'], p['subtitle'],
            bg=PALETTE['white'], border=p['accent'], border_w=3, radius=14,
            header_bg=p['color'], header_h=70
        )
        
        # Phase Tag
        draw.rounded_rectangle([cx + 24, top_y + 86, cx + 180, top_y + 116], radius=6, fill=PALETTE['card_alt_bg'], outline=PALETTE['border'])
        draw.text((cx + 36, top_y + 92), p['num'], font=FONTS['badge'], fill=p['color'])
        
        cur_y = top_y + 138
        for prefix, desc in p['sprints']:
            cur_y = draw_bullet_item(draw, cx + 24, cur_y, phase_w - 48, prefix, desc, bullet="❖", icon_color=p['accent'])
            cur_y += 24
            
        # Bottom Deliverable Box
        deliv_y = top_y + card_h - 100
        draw.rounded_rectangle([cx + 16, deliv_y, cx + phase_w - 16, deliv_y + 80], radius=8, fill=PALETTE['soft_blue'], outline=PALETTE['border_light'])
        deliv_lines = wrap_text(p['deliverable'], FONTS['body_sm_bold'], phase_w - 50)
        for d_idx, dl in enumerate(deliv_lines):
            draw.text((cx + 26, deliv_y + 12 + d_idx * 22), dl, font=FONTS['body_sm_bold'], fill=PALETTE['navy'])
            
    # Forward Flow Connectors
    for i in range(3):
        x1 = start_x + (i + 1) * phase_w + i * phase_gap
        x2 = x1 + phase_gap
        y_mid = top_y + 500
        draw_arrow(draw, (x1 + 4, y_mid), (x2 - 4, y_mid), color=PALETTE['navy'], width=5)
        
    # Continuous Scrum Retrospective / Feedback Outer Loop
    loop_y = top_y + card_h + 30
    p1 = (start_x + phase_w * 3 + phase_gap * 3 - 60, top_y + card_h)
    p2 = (p1[0], loop_y)
    p3 = (start_x + 60, loop_y)
    p4 = (p3[0], top_y + card_h)
    
    draw_elbow_arrow(
        draw, [p1, p2, p3, p4],
        label="CONTINUOUS SPRINT RETROSPECTIVE & PRODUCT BACKLOG REFINEMENT",
        sublabel="Iterative Enhancements Based on Client Teacher Feedback, Stakeholder Reviews, and Bug Remediation",
        color=PALETTE['purple'], width=4, dashed=True, arrow_at_end=True
    )
    
    draw_footer(draw, width, height)
    
    out_path = os.path.join(OUTPUT_DIR, "figure3_agile_scrum_framework.png")
    img.save(out_path, dpi=(300, 300))
    print(f"Generated: {out_path} ({width}x{height})")


# ==============================================================================
# FIGURE 5: CONTEXT DIAGRAM (LEVEL 0 DFD)
# ==============================================================================
def generate_figure5():
    width = 3600
    height = 2400
    img = Image.new('RGB', (width, height), PALETTE['canvas_bg'])
    draw = ImageDraw.Draw(img)
    
    draw_header(
        draw, width,
        "Figure 5: Context Diagram (Level 0 DFD) of CLASSREALM",
        "System Boundaries, External User Entities, Edge Hardware & Cloud Services Data Flows",
        "CLASSREALM PROCESS MODELING • LEVEL 0 DFD"
    )
    
    # Center System Bubble
    center_w = 700
    center_h = 320
    center_x = (width - center_w) / 2
    center_y = (height - center_h) / 2 - 40
    
    # Outer glow / boundary
    draw.rounded_rectangle([center_x - 12, center_y - 12, center_x + center_w + 12, center_y + center_h + 12], radius=40, fill='#DBEAFE', outline='#BFDBFE', width=3)
    draw.rounded_rectangle([center_x, center_y, center_x + center_w, center_y + center_h], radius=32, fill=PALETTE['navy'], outline=PALETTE['slate_blue'], width=4)
    
    # Center text
    draw.text((center_x + 60, center_y + 40), "0.0", font=FONTS['super_title'], fill='#93C5FD')
    draw.text((center_x + 60, center_y + 110), "CLASSREALM SYSTEM", font=FONTS['title'], fill=PALETTE['white'])
    desc = "Integrated Senior High School Educational Management System\nDual-Path RFID Attendance, DepEd Grading & Lesson Repository"
    draw.text((center_x + 60, center_y + 175), desc, font=FONTS['card_sub'], fill='#E2E8F0')
    draw.text((center_x + 60, center_y + 245), "Client: Ma'am Karen P. Gonzaga • Eduardo Barretto Sr. High School", font=FONTS['badge'], fill='#FCD34D')
    
    # Entities Layout:
    # 1. Admin (Top Left)
    # 2. ESP32 RC522 RFID Scanner (Top Center)
    # 3. Parent / Guardian (Top Right)
    # 4. Teacher: Ma'am Karen P. Gonzaga (Bottom Left)
    # 5. Firebase Auth (Bottom Center-Left)
    # 6. Supabase Cloud (Bottom Center-Right)
    # 7. Student: Senior High School (Bottom Right)
    
    ent_w = 540
    ent_h = 240
    
    entities = {
        'admin': {
            'x': 140, 'y': 220,
            'title': 'ADMINISTRATOR',
            'subtitle': 'System Infrastructure Manager',
            'tag': 'User Entity',
            'color': PALETTE['rose']
        },
        'rfid': {
            'x': (width - 640) / 2, 'y': 200, 'w': 640,
            'title': 'ESP32 RC522 RFID SCANNER',
            'subtitle': 'Standalone Edge Hardware Module',
            'tag': 'External Hardware',
            'color': PALETTE['emerald']
        },
        'parent': {
            'x': width - 140 - ent_w, 'y': 220,
            'title': 'PARENT / GUARDIAN',
            'subtitle': 'Secondary Mobile App User',
            'tag': 'User Entity',
            'color': PALETTE['amber']
        },
        'teacher': {
            'x': 140, 'y': height - 420,
            'title': "TEACHER (CLIENT)",
            'subtitle': "Ma'am Karen P. Gonzaga (SHS)",
            'tag': 'Primary User Entity',
            'color': PALETTE['slate_blue']
        },
        'firebase': {
            'x': width / 2 - 620, 'y': height - 410, 'w': 580,
            'title': 'FIREBASE AUTHENTICATION',
            'subtitle': 'Identity Provider & Token Service',
            'tag': 'External Cloud Service',
            'color': PALETTE['amber']
        },
        'supabase': {
            'x': width / 2 + 40, 'y': height - 410, 'w': 580,
            'title': 'SUPABASE CLOUD BACKEND',
            'subtitle': 'PostgreSQL DB, Storage & 23:59 Cron',
            'tag': 'External Cloud Service',
            'color': PALETTE['emerald']
        },
        'student': {
            'x': width - 140 - ent_w, 'y': height - 420,
            'title': 'STUDENT (SENIOR HIGH)',
            'subtitle': 'Mobile App Portal User',
            'tag': 'Primary User Entity',
            'color': PALETTE['purple']
        }
    }
    
    # Draw Entities
    for key, ent in entities.items():
        ew = ent.get('w', ent_w)
        eh = ent.get('h', ent_h)
        draw_card(
            draw, ent['x'], ent['y'], ew, eh,
            ent['title'], ent['subtitle'],
            bg=PALETTE['white'], border=ent['color'], border_w=3, radius=12,
            header_bg=ent['color'], header_h=55
        )
        draw.rounded_rectangle([ent['x'] + ew - 180, ent['y'] + 12, ent['x'] + ew - 16, ent['y'] + 42], radius=6, fill=PALETTE['white'])
        draw.text((ent['x'] + ew - 170, ent['y'] + 18), ent['tag'], font=FONTS['badge'], fill=ent['color'])
        
    # Flow Lines & Labels
    # -------------------------------------------------------------
    # 1. Admin <-> Center
    admin_cx = entities['admin']['x'] + ent_w
    admin_cy = entities['admin']['y'] + ent_h / 2
    # Inflow to System:
    draw_arrow(
        draw, (admin_cx, admin_cy - 40), (center_x, center_y + 40),
        label="Admin Credentials, Teacher Approvals, AY Rollover, Maintenance Config",
        color=PALETTE['rose'], width=3
    )
    # Outflow to Admin:
    draw_arrow(
        draw, (center_x, center_y + 90), (admin_cx, admin_cy + 30),
        label="System Audit Logs, Teacher Account Requests, System Health Telemetry",
        color=PALETTE['rose'], width=3
    )
    
    # 2. ESP32 <-> Center
    rfid_cx = entities['rfid']['x'] + 320
    rfid_cy = entities['rfid']['y'] + ent_h
    # Inflow to System:
    draw_arrow(
        draw, (rfid_cx - 80, rfid_cy), (center_x + center_w / 2 - 80, center_y),
        label="13.56 MHz Card UID, Scan Timestamp, Device ID, LittleFS Spool Flushes",
        color=PALETTE['emerald'], width=3
    )
    # Outflow to ESP32:
    draw_arrow(
        draw, (center_x + center_w / 2 + 80, center_y), (rfid_cx + 80, rfid_cy),
        label="Audio/Visual Cues (Buzzer Frequency Pulses & Green/Red/Blue LEDs)",
        color=PALETTE['emerald'], width=3
    )
    
    # 3. Parent <-> Center
    parent_cx = entities['parent']['x']
    parent_cy = entities['parent']['y'] + ent_h / 2
    # Inflow to System:
    draw_arrow(
        draw, (parent_cx, parent_cy + 30), (center_x + center_w, center_y + 40),
        label="Parent Credentials, Parent-Student Linking Authorization Request",
        color=PALETTE['amber'], width=3
    )
    # Outflow to Parent:
    draw_arrow(
        draw, (center_x + center_w, center_y + 90), (parent_cx, parent_cy - 40),
        label="Child Attendance History, Push Absence Warnings (≥3), Term Grade Cards",
        color=PALETTE['amber'], width=3
    )
    
    # 4. Teacher <-> Center
    teacher_cx = entities['teacher']['x'] + ent_w
    teacher_cy = entities['teacher']['y'] + ent_h / 2
    # Inflow to System:
    draw_arrow(
        draw, (teacher_cx, teacher_cy - 40), (center_x, center_y + center_h - 90),
        label="Credentials, Sections, Rosters, Schedules, Cutoffs, Manual Attendance, Quizzes, Weights, Lessons",
        color=PALETTE['slate_blue'], width=3
    )
    # Outflow to Teacher:
    draw_arrow(
        draw, (center_x, center_y + center_h - 40), (teacher_cx, teacher_cy + 30),
        label="Active Session, Live Attendance Rosters, Student Submissions, Auto-Computed ECRs, Class Analytics",
        color=PALETTE['slate_blue'], width=3
    )
    
    # 5. Firebase Auth <-> Center
    fb_cx = entities['firebase']['x'] + 290
    fb_cy = entities['firebase']['y']
    draw_arrow(
        draw, (fb_cx - 40, fb_cy), (center_x + 140, center_y + center_h),
        label="User Provisioning API Requests, Session Tokens",
        color=PALETTE['amber'], width=3
    )
    draw_arrow(
        draw, (center_x + 180, center_y + center_h), (fb_cx, fb_cy),
        label="Verified JWT Tokens, Firebase UIDs, Auth States",
        color=PALETTE['amber'], width=3
    )
    
    # 6. Supabase Cloud <-> Center
    sb_cx = entities['supabase']['x'] + 290
    sb_cy = entities['supabase']['y']
    draw_arrow(
        draw, (center_x + center_w - 180, center_y + center_h), (sb_cx - 40, sb_cy),
        label="RLS Queries/Upserts, Storage Uploads, Batch RPC Flushes",
        color=PALETTE['emerald'], width=3
    )
    draw_arrow(
        draw, (sb_cx, sb_cy), (center_x + center_w - 140, center_y + center_h),
        label="Realtime WebSocket Streams, Relational Data, 23:59 Cron Auto-Absent",
        color=PALETTE['emerald'], width=3
    )
    
    # 7. Student <-> Center
    student_cx = entities['student']['x']
    student_cy = entities['student']['y'] + ent_h / 2
    # Inflow to System:
    draw_arrow(
        draw, (student_cx, student_cy - 40), (center_x + center_w, center_y + center_h - 90),
        label="Student Credentials, Quiz Responses, Classwork Submissions, Profile Details",
        color=PALETTE['purple'], width=3
    )
    # Outflow to Student:
    draw_arrow(
        draw, (center_x + center_w, center_y + center_h - 40), (student_cx, student_cy + 30),
        label="Scoped Attendance History, Graded Submission Feedback, Transmuted Grades, Handouts",
        color=PALETTE['purple'], width=3
    )
    
    draw_footer(draw, width, height)
    
    out_path = os.path.join(OUTPUT_DIR, "figure5_context_diagram.png")
    img.save(out_path, dpi=(300, 300))
    print(f"Generated: {out_path} ({width}x{height})")


if __name__ == '__main__':
    generate_figure1()
    generate_figure2()
    generate_figure3()
    generate_figure5()
