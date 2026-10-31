import os
from PIL import Image, ImageDraw, ImageFont
from diagram_engine import (
    PALETTE, FONTS, text_size, wrap_text,
    draw_header, draw_footer, draw_card, draw_badge,
    draw_arrow, draw_elbow_arrow
)

OUTPUT_DIR = "c:/Users/Admin/AndroidStudioProjects/class_realm01/docs/diagrams"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def draw_dfd_process(draw, x, y, w, h, proc_num, title, subtitle=None, bg=PALETTE['white'], border=PALETTE['navy']):
    # Rounded process bubble
    draw.rounded_rectangle([x, y, x + w, y + h], radius=14, fill=bg, outline=border, width=3)
    # Header strip for process ID
    draw.rounded_rectangle([x, y, x + w, y + 42], radius=14, fill=border)
    draw.rectangle([x, y + 14, x + w, y + 42], fill=border)
    draw.text((x + 16, y + 8), f"PROCESS {proc_num}", font=FONTS['badge'], fill=PALETTE['white'])
    # Title & Subtitle
    draw.text((x + 16, y + 52), title, font=FONTS['card_header'], fill=PALETTE['navy'])
    if subtitle:
        lines = wrap_text(subtitle, FONTS['body_sm'], w - 32)
        for idx, l in enumerate(lines):
            draw.text((x + 16, y + 84 + idx * 22), l, font=FONTS['body_sm'], fill=PALETTE['text_muted'])

def draw_dfd_store(draw, x, y, w, h, store_id, name, desc=None):
    # Open-ended rectangle (parallel top/bottom lines, closed left, open right)
    draw.rectangle([x, y, x + w, y + h], fill=PALETTE['white'])
    draw.line([(x, y), (x + w, y)], fill=PALETTE['slate_blue'], width=3)
    draw.line([(x, y + h), (x + w, y + h)], fill=PALETTE['slate_blue'], width=3)
    draw.line([(x, y), (x, y + h)], fill=PALETTE['slate_blue'], width=3)
    # Store ID box
    id_w = 60
    draw.rectangle([x, y, x + id_w, y + h], fill=PALETTE['soft_blue'])
    draw.line([(x + id_w, y), (x + id_w, y + h)], fill=PALETTE['slate_blue'], width=2)
    draw.text((x + 12, y + h/2 - 12), store_id, font=FONTS['card_header'], fill=PALETTE['navy'])
    # Store Name & Desc
    draw.text((x + id_w + 16, y + 10), name, font=FONTS['card_header'], fill=PALETTE['text_dark'])
    if desc:
        draw.text((x + id_w + 16, y + 38), desc, font=FONTS['body_sm'], fill=PALETTE['text_muted'])

def draw_dfd_entity(draw, x, y, w, h, name, role_desc=None, color=PALETTE['navy']):
    # Double-border external entity
    draw.rectangle([x, y, x + w, y + h], fill=PALETTE['white'], outline=color, width=3)
    draw.rectangle([x + 4, y + 4, x + w - 4, y + h - 4], outline=PALETTE['border_light'], width=1)
    # Header bar
    draw.rectangle([x, y, x + w, y + 36], fill=color)
    draw.text((x + 12, y + 8), "EXTERNAL ENTITY", font=FONTS['badge'], fill=PALETTE['white'])
    # Entity Title
    draw.text((x + 14, y + 46), name, font=FONTS['card_header'], fill=PALETTE['text_dark'])
    if role_desc:
        draw.text((x + 14, y + 74), role_desc, font=FONTS['body_sm'], fill=PALETTE['text_muted'])


# ==============================================================================
# ACTIVITY 2 - FIGURE 1: CONTEXT DIAGRAM (MATCHES FIG 5)
# ==============================================================================
def generate_activity2_dfd_level0():
    width = 3600
    height = 2400
    img = Image.new('RGB', (width, height), PALETTE['canvas_bg'])
    draw = ImageDraw.Draw(img)
    
    draw_header(
        draw, width,
        "Activity #2 — Figure 1: Context Diagram (Level 0 DFD) of CLASSREALM",
        "Process Modeling Baseline: System Boundaries, External User Roles & Cloud/Hardware Interfaces",
        "ACTIVITY #2: REQUIREMENTS TO PROCESS MODELING • LEVEL 0 DFD"
    )
    
    center_w = 700
    center_h = 320
    center_x = (width - center_w) / 2
    center_y = (height - center_h) / 2 - 40
    
    draw.rounded_rectangle([center_x - 12, center_y - 12, center_x + center_w + 12, center_y + center_h + 12], radius=40, fill='#DBEAFE', outline='#BFDBFE', width=3)
    draw.rounded_rectangle([center_x, center_y, center_x + center_w, center_y + center_h], radius=32, fill=PALETTE['navy'], outline=PALETTE['slate_blue'], width=4)
    
    draw.text((center_x + 60, center_y + 40), "0.0", font=FONTS['super_title'], fill='#93C5FD')
    draw.text((center_x + 60, center_y + 110), "CLASSREALM SYSTEM", font=FONTS['title'], fill=PALETTE['white'])
    desc = "Integrated Senior High School Educational Management System\nDual-Path RFID Attendance, DepEd Grading & Lesson Repository"
    draw.text((center_x + 60, center_y + 175), desc, font=FONTS['card_sub'], fill='#E2E8F0')
    draw.text((center_x + 60, center_y + 245), "Client: Ma'am Karen P. Gonzaga • Eduardo Barretto Sr. High School", font=FONTS['badge'], fill='#FCD34D')
    
    ent_w = 540
    ent_h = 240
    
    entities = {
        'admin': {'x': 140, 'y': 220, 'title': 'ADMINISTRATOR', 'subtitle': 'System Infrastructure Manager', 'tag': 'User Entity', 'color': PALETTE['rose']},
        'rfid': {'x': (width - 640) / 2, 'y': 200, 'w': 640, 'title': 'ESP32 RC522 RFID SCANNER', 'subtitle': 'Standalone Edge Hardware Module', 'tag': 'External Hardware', 'color': PALETTE['emerald']},
        'parent': {'x': width - 140 - ent_w, 'y': 220, 'title': 'PARENT / GUARDIAN', 'subtitle': 'Secondary Mobile App User', 'tag': 'User Entity', 'color': PALETTE['amber']},
        'teacher': {'x': 140, 'y': height - 420, 'title': "TEACHER (CLIENT)", 'subtitle': "Ma'am Karen P. Gonzaga (SHS)", 'tag': 'Primary User Entity', 'color': PALETTE['slate_blue']},
        'firebase': {'x': width / 2 - 620, 'y': height - 410, 'w': 580, 'title': 'FIREBASE AUTHENTICATION', 'subtitle': 'Identity Provider & Token Service', 'tag': 'External Cloud Service', 'color': PALETTE['amber']},
        'supabase': {'x': width / 2 + 40, 'y': height - 410, 'w': 580, 'title': 'SUPABASE CLOUD BACKEND', 'subtitle': 'PostgreSQL DB, Storage & 23:59 Cron', 'tag': 'External Cloud Service', 'color': PALETTE['emerald']},
        'student': {'x': width - 140 - ent_w, 'y': height - 420, 'title': 'STUDENT (SENIOR HIGH)', 'subtitle': 'Mobile App Portal User', 'tag': 'Primary User Entity', 'color': PALETTE['purple']}
    }
    
    for key, ent in entities.items():
        ew = ent.get('w', ent_w)
        eh = ent.get('h', ent_h)
        draw_card(draw, ent['x'], ent['y'], ew, eh, ent['title'], ent['subtitle'], bg=PALETTE['white'], border=ent['color'], border_w=3, radius=12, header_bg=ent['color'], header_h=55)
        draw.rounded_rectangle([ent['x'] + ew - 180, ent['y'] + 12, ent['x'] + ew - 16, ent['y'] + 42], radius=6, fill=PALETTE['white'])
        draw.text((ent['x'] + ew - 170, ent['y'] + 18), ent['tag'], font=FONTS['badge'], fill=ent['color'])
        
    admin_cx = entities['admin']['x'] + ent_w
    admin_cy = entities['admin']['y'] + ent_h / 2
    draw_arrow(draw, (admin_cx, admin_cy - 40), (center_x, center_y + 40), label="Admin Credentials, Teacher Approvals, AY Rollover, Maintenance Config", color=PALETTE['rose'], width=3)
    draw_arrow(draw, (center_x, center_y + 90), (admin_cx, admin_cy + 30), label="System Audit Logs, Teacher Account Requests, System Health Telemetry", color=PALETTE['rose'], width=3)
    
    rfid_cx = entities['rfid']['x'] + 320
    rfid_cy = entities['rfid']['y'] + ent_h
    draw_arrow(draw, (rfid_cx - 80, rfid_cy), (center_x + center_w / 2 - 80, center_y), label="13.56 MHz Card UID, Scan Timestamp, Device ID, LittleFS Spool Flushes", color=PALETTE['emerald'], width=3)
    draw_arrow(draw, (center_x + center_w / 2 + 80, center_y), (rfid_cx + 80, rfid_cy), label="Audio/Visual Cues (Buzzer Frequency Pulses & Green/Red/Blue LEDs)", color=PALETTE['emerald'], width=3)
    
    parent_cx = entities['parent']['x']
    parent_cy = entities['parent']['y'] + ent_h / 2
    draw_arrow(draw, (parent_cx, parent_cy + 30), (center_x + center_w, center_y + 40), label="Parent Credentials, Parent-Student Linking Authorization Request", color=PALETTE['amber'], width=3)
    draw_arrow(draw, (center_x + center_w, center_y + 90), (parent_cx, parent_cy - 40), label="Child Attendance History, Push Absence Warnings (≥3), Term Grade Cards", color=PALETTE['amber'], width=3)
    
    teacher_cx = entities['teacher']['x'] + ent_w
    teacher_cy = entities['teacher']['y'] + ent_h / 2
    draw_arrow(draw, (teacher_cx, teacher_cy - 40), (center_x, center_y + center_h - 90), label="Credentials, Sections, Rosters, Schedules, Cutoffs, Manual Attendance, Quizzes, Weights, Lessons", color=PALETTE['slate_blue'], width=3)
    draw_arrow(draw, (center_x, center_y + center_h - 40), (teacher_cx, teacher_cy + 30), label="Active Session, Live Attendance Rosters, Student Submissions, Auto-Computed ECRs, Class Analytics", color=PALETTE['slate_blue'], width=3)
    
    fb_cx = entities['firebase']['x'] + 290
    fb_cy = entities['firebase']['y']
    draw_arrow(draw, (fb_cx - 40, fb_cy), (center_x + 140, center_y + center_h), label="User Provisioning API Requests, Session Tokens", color=PALETTE['amber'], width=3)
    draw_arrow(draw, (center_x + 180, center_y + center_h), (fb_cx, fb_cy), label="Verified JWT Tokens, Firebase UIDs, Auth States", color=PALETTE['amber'], width=3)
    
    sb_cx = entities['supabase']['x'] + 290
    sb_cy = entities['supabase']['y']
    draw_arrow(draw, (center_x + center_w - 180, center_y + center_h), (sb_cx - 40, sb_cy), label="RLS Queries/Upserts, Storage Uploads, Batch RPC Flushes", color=PALETTE['emerald'], width=3)
    draw_arrow(draw, (sb_cx, sb_cy), (center_x + center_w - 140, center_y + center_h), label="Realtime WebSocket Streams, Relational Data, 23:59 Cron Auto-Absent", color=PALETTE['emerald'], width=3)
    
    student_cx = entities['student']['x']
    student_cy = entities['student']['y'] + ent_h / 2
    draw_arrow(draw, (student_cx, student_cy - 40), (center_x + center_w, center_y + center_h - 90), label="Student Credentials, Quiz Responses, Classwork Submissions, Profile Details", color=PALETTE['purple'], width=3)
    draw_arrow(draw, (center_x + center_w, center_y + center_h - 40), (student_cx, student_cy + 30), label="Scoped Attendance History, Graded Submission Feedback, Transmuted Grades, Handouts", color=PALETTE['purple'], width=3)
    
    draw_footer(draw, width, height)
    out_path = os.path.join(OUTPUT_DIR, "activity2_dfd_level0.png")
    img.save(out_path, dpi=(300, 300))
    print(f"Generated: {out_path} ({width}x{height})")


# ==============================================================================
# ACTIVITY 2 - FIGURE 2: LEVEL 1 DFD OVERVIEW (PROCESSES 1.0 TO 5.0)
# ==============================================================================
def generate_activity2_dfd_level1_overview():
    width = 3600
    height = 2400
    img = Image.new('RGB', (width, height), PALETTE['canvas_bg'])
    draw = ImageDraw.Draw(img)
    
    draw_header(
        draw, width,
        "Activity #2 — Figure 2: Level 1 DFD Overview (Major Subsystem Decomposition)",
        "System Decomposition into 5 Primary Operational Subsystems and 5 Central Data Stores (D1–D5)",
        "ACTIVITY #2: REQUIREMENTS TO PROCESS MODELING • LEVEL 1 OVERVIEW DFD"
    )
    
    # 5 Major Processes layout in a clean circular / staggered flow
    proc_w = 540
    proc_h = 160
    
    # Process Coordinates
    procs = {
        'p1': {'num': '1.0', 'x': 800, 'y': 240, 'title': 'User Authentication & Role Verification', 'sub': 'Firebase Auth token check & RLS binding'},
        'p2': {'num': '2.0', 'x': 2260, 'y': 240, 'title': 'Dual-Path Hardware & Manual Attendance', 'sub': 'ESP32 RFID tap, NFC fallback & cutoff engine'},
        'p3': {'num': '3.0', 'x': 2260, 'y': 1050, 'title': 'Assessment & Automated Grade Computation', 'sub': 'Classwork, quiz auto-check & DepEd transmutation'},
        'p4': {'num': '4.0', 'x': 1530, 'y': 1750, 'title': 'Lesson Planning & Learning Repository', 'sub': 'ILAW lesson generator & materials repository'},
        'p5': {'num': '5.0', 'x': 800, 'y': 1050, 'title': 'System Administration & Academic Rollover', 'sub': 'Teacher provisioning & academic year setup'}
    }
    
    # Draw Processes
    for k, p in procs.items():
        draw_dfd_process(draw, p['x'], p['y'], proc_w, proc_h, p['num'], p['title'], p['sub'], border=PALETTE['navy'])
        
    # 5 Data Stores centered inside the ring
    store_w = 460
    store_h = 90
    
    stores = {
        'd1': {'id': 'D1', 'x': 1570, 'y': 360, 'name': 'User Accounts & Profiles', 'desc': 'users, teacher/student/parent profiles'},
        'd2': {'id': 'D2', 'x': 2200, 'y': 660, 'name': 'Attendance & Rosters', 'desc': 'sections, schedules, rfid_cards, logs'},
        'd3': {'id': 'D3', 'x': 2200, 'y': 1480, 'name': 'Classwork & Assessments', 'desc': 'activities, quizzes, responses, grades'},
        'd4': {'id': 'D4', 'x': 940, 'y': 1480, 'name': 'Lesson Plans & Materials', 'desc': 'lesson_plans, learning_materials'},
        'd5': {'id': 'D5', 'x': 940, 'y': 660, 'name': 'System Settings & Audit', 'desc': 'school_years, audit_logs, settings'}
    }
    
    for k, s in stores.items():
        draw_dfd_store(draw, s['x'], s['y'], store_w, store_h, s['id'], s['name'], s['desc'])
        
    # External Entities on borders
    ent_w = 420
    ent_h = 130
    entities = {
        'admin': {'x': 100, 'y': 650, 'name': 'Administrator', 'sub': 'System Manager', 'color': PALETTE['rose']},
        'teacher': {'x': 100, 'y': 1400, 'name': "Teacher (Ma'am Karen)", 'sub': 'Academic Client User', 'color': PALETTE['slate_blue']},
        'rfid': {'x': 2950, 'y': 240, 'name': 'ESP32 RC522 Scanner', 'sub': 'Standalone Hardware', 'color': PALETTE['emerald']},
        'student': {'x': 2950, 'y': 1050, 'name': 'Student (SHS)', 'sub': 'Mobile App Portal', 'color': PALETTE['purple']},
        'parent': {'x': 2950, 'y': 1750, 'name': 'Parent / Guardian', 'sub': 'Mobile App Portal', 'color': PALETTE['amber']}
    }
    
    for k, e in entities.items():
        draw_dfd_entity(draw, e['x'], e['y'], ent_w, ent_h, e['name'], e['sub'], color=e['color'])
        
    # Interconnecting Data Flows
    # Admin -> P1.0
    draw_arrow(draw, (entities['admin']['x'] + ent_w, entities['admin']['y'] + 30), (procs['p1']['x'], procs['p1']['y'] + 80), label="Admin Login", color=PALETTE['rose'], width=3)
    # Admin <-> P5.0
    draw_arrow(draw, (entities['admin']['x'] + ent_w, entities['admin']['y'] + 80), (procs['p5']['x'], procs['p5']['y'] + 40), label="Teacher Approval & AY Setup", color=PALETTE['rose'], width=3)
    draw_arrow(draw, (procs['p5']['x'], procs['p5']['y'] + 90), (entities['admin']['x'] + ent_w, entities['admin']['y'] + 100), label="Audit Logs & Health Telemetry", color=PALETTE['rose'], width=3)
    
    # Teacher -> P1.0
    draw_arrow(draw, (entities['teacher']['x'] + ent_w, entities['teacher']['y'] - 40), (procs['p1']['x'] + 100, procs['p1']['y'] + proc_h), label="Teacher Credentials", color=PALETTE['slate_blue'], width=3)
    # Teacher <-> P2.0
    draw_elbow_arrow(draw, [(entities['teacher']['x'] + ent_w, entities['teacher']['y']), (1450, 1400), (1450, 290), (procs['p2']['x'], 290)], label="Manual Attendance & Settings", color=PALETTE['slate_blue'], width=3)
    # Teacher <-> P3.0
    draw_arrow(draw, (entities['teacher']['x'] + ent_w, entities['teacher']['y'] + 40), (procs['p3']['x'] - 80, procs['p3']['y'] + 40), label="Quizzes, Weights & Grades", color=PALETTE['slate_blue'], width=3)
    # Teacher <-> P4.0
    draw_arrow(draw, (entities['teacher']['x'] + ent_w, entities['teacher']['y'] + 90), (procs['p4']['x'], procs['p4']['y'] + 40), label="Lesson Prompts & Handouts", color=PALETTE['slate_blue'], width=3)
    
    # ESP32 <-> P2.0
    draw_arrow(draw, (entities['rfid']['x'], entities['rfid']['y'] + 50), (procs['p2']['x'] + proc_w, procs['p2']['y'] + 50), label="13.56 MHz Card UID & Timestamp", color=PALETTE['emerald'], width=3)
    draw_arrow(draw, (procs['p2']['x'] + proc_w, procs['p2']['y'] + 100), (entities['rfid']['x'], entities['rfid']['y'] + 100), label="Audio/Visual Feedback Cue", color=PALETTE['emerald'], width=3)
    
    # Student <-> P3.0
    draw_arrow(draw, (entities['student']['x'], entities['student']['y'] + 50), (procs['p3']['x'] + proc_w, procs['p3']['y'] + 50), label="Submissions & Quiz Responses", color=PALETTE['purple'], width=3)
    draw_arrow(draw, (procs['p3']['x'] + proc_w, procs['p3']['y'] + 100), (entities['student']['x'], entities['student']['y'] + 100), label="Scores & Transmuted Grades", color=PALETTE['purple'], width=3)
    
    # Parent <-> P2.0 & P3.0
    draw_elbow_arrow(draw, [(entities['parent']['x'], entities['parent']['y'] + 30), (2880, entities['parent']['y'] + 30), (2880, procs['p2']['y'] + 120), (procs['p2']['x'] + proc_w, procs['p2']['y'] + 120)], label="Absence Warning Alerts (≥3)", color=PALETTE['amber'], width=3)
    draw_arrow(draw, (procs['p3']['x'] + proc_w - 60, procs['p3']['y'] + proc_h), (entities['parent']['x'] + 60, entities['parent']['y']), label="Quarterly SF9 Report Card", color=PALETTE['amber'], width=3)
    
    # Internal Process <-> Data Store Flows
    # P1.0 <-> D1
    draw_arrow(draw, (procs['p1']['x'] + proc_w, procs['p1']['y'] + 60), (stores['d1']['x'], stores['d1']['y'] + 30), label="User Record Verification", color=PALETTE['slate_blue'], width=3)
    # P2.0 <-> D2
    draw_arrow(draw, (procs['p2']['x'] + 140, procs['p2']['y'] + proc_h), (stores['d2']['x'] + 140, stores['d2']['y']), label="Write Attendance Logs", color=PALETTE['emerald'], width=3)
    # P3.0 <-> D3
    draw_arrow(draw, (procs['p3']['x'] + 140, procs['p3']['y'] + proc_h), (stores['d3']['x'] + 140, stores['d3']['y']), label="Store Scores & Transmuted Grades", color=PALETTE['purple'], width=3)
    # P4.0 <-> D4
    draw_arrow(draw, (procs['p4']['x'], procs['p4']['y'] + 80), (stores['d4']['x'] + store_w, stores['d4']['y'] + 50), label="Store Lessons & File URLs", color=PALETTE['sky'], width=3)
    # P5.0 <-> D5
    draw_arrow(draw, (procs['p5']['x'] + 140, procs['p5']['y']), (stores['d5']['x'] + 140, stores['d5']['y'] + store_h), label="Write Audit Logs & Settings", color=PALETTE['rose'], width=3)
    
    draw_footer(draw, width, height)
    out_path = os.path.join(OUTPUT_DIR, "activity2_dfd_level1_overview.png")
    img.save(out_path, dpi=(300, 300))
    print(f"Generated: {out_path} ({width}x{height})")


# ==============================================================================
# ACTIVITY 2 - FIGURE 3: LEVEL 1 DFD FOR 1.0 (USER AUTHENTICATION)
# ==============================================================================
def generate_activity2_dfd_level1_proc1():
    width = 3200
    height = 2000
    img = Image.new('RGB', (width, height), PALETTE['canvas_bg'])
    draw = ImageDraw.Draw(img)
    
    draw_header(
        draw, width,
        "Activity #2 — Figure 3: Level 1 DFD for Process 1.0 (User Authentication & Role Verification)",
        "Credential Validation, Firebase Identity Integration, Token Claims & Parent-Student Authorization",
        "ACTIVITY #2: REQUIREMENTS TO PROCESS MODELING • PROCESS 1.0 DFD"
    )
    
    # 4 Sub-processes
    sub_w = 640
    sub_h = 160
    
    subs = {
        '1.1': {'x': 880, 'y': 280, 'title': '1.1 Validate User Credentials', 'sub': 'Email/password authentication check with Firebase Auth'},
        '1.2': {'x': 1880, 'y': 280, 'title': '1.2 Verify Role & Session Token', 'sub': 'Extract JWT claims & inject Supabase RLS context'},
        '1.3': {'x': 880, 'y': 920, 'title': '1.3 Provision & Approve Teacher Accounts', 'sub': 'Admin verification of teacher requests & activation'},
        '1.4': {'x': 1880, 'y': 920, 'title': '1.4 Link Parent-Student Relationship', 'sub': 'Verify parent authorization code & bind to student LRN'}
    }
    
    for k, s in subs.items():
        draw_dfd_process(draw, s['x'], s['y'], sub_w, sub_h, k, s['title'], s['sub'], border=PALETTE['navy'])
        
    # Data Stores
    draw_dfd_store(draw, 1380, 600, 640, 100, "D1", "User Accounts & Profiles", "users, admin/teacher/student/parent profiles, links")
    draw_dfd_store(draw, 1380, 1400, 640, 100, "D5", "System Settings & Audit Logs", "auth_rate_limits, session_logs, audit_logs")
    
    # Entities
    draw_dfd_entity(draw, 120, 280, 480, 130, "User (All Roles)", "Admin, Teacher, Student, Parent", color=PALETTE['navy'])
    draw_dfd_entity(draw, 120, 920, 480, 130, "Administrator", "System Infrastructure Manager", color=PALETTE['rose'])
    draw_dfd_entity(draw, 2600, 280, 500, 130, "Firebase Authentication", "External Identity Provider", color=PALETTE['amber'])
    draw_dfd_entity(draw, 2600, 920, 500, 130, "Parent User", "Secondary Mobile App User", color=PALETTE['purple'])
    
    # Flows
    # User -> 1.1
    draw_arrow(draw, (600, 330), (880, 330), label="Email & Password Credentials", color=PALETTE['navy'], width=3)
    # 1.1 <-> Firebase
    draw_arrow(draw, (1520, 330), (1880, 330), label="Validated Auth Request", color=PALETTE['navy'], width=3)
    draw_arrow(draw, (2520, 330), (2600, 330), label="Auth Query", color=PALETTE['amber'], width=3)
    draw_arrow(draw, (2600, 380), (2520, 380), label="Firebase UID & ID Token", color=PALETTE['amber'], width=3)
    
    # 1.2 -> D1
    draw_arrow(draw, (1980, 440), (1800, 600), label="Query User Role & Profile", color=PALETTE['slate_blue'], width=3)
    draw_arrow(draw, (1750, 600), (1920, 440), label="Return Role Claim", color=PALETTE['slate_blue'], width=3)
    
    # 1.2 -> User (Session Token)
    draw_elbow_arrow(draw, [(1980, 280), (1980, 220), (360, 220), (360, 280)], label="Authenticated JWT Session Token (RLS Scoped)", color=PALETTE['emerald'], width=3)
    
    # Admin <-> 1.3
    draw_arrow(draw, (600, 960), (880, 960), label="Teacher Provisioning & Approval", color=PALETTE['rose'], width=3)
    draw_arrow(draw, (880, 1010), (600, 1010), label="Teacher Request Summary", color=PALETTE['rose'], width=3)
    # 1.3 -> D1
    draw_arrow(draw, (1200, 920), (1450, 700), label="Update Teacher Profile Status", color=PALETTE['slate_blue'], width=3)
    # 1.3 -> D5
    draw_arrow(draw, (1200, 1080), (1450, 1400), label="Record Audit Log Entry", color=PALETTE['rose'], width=3)
    
    # Parent <-> 1.4
    draw_arrow(draw, (2600, 960), (2520, 960), label="Student LRN & Auth Link Code", color=PALETTE['purple'], width=3)
    draw_arrow(draw, (2520, 1010), (2600, 1010), label="Parent-Student Verification Status", color=PALETTE['purple'], width=3)
    # 1.4 <-> D1
    draw_arrow(draw, (1880, 960), (1750, 700), label="Validate LRN & Insert Link", color=PALETTE['slate_blue'], width=3)
    
    draw_footer(draw, width, height)
    out_path = os.path.join(OUTPUT_DIR, "activity2_dfd_level1_proc1.png")
    img.save(out_path, dpi=(300, 300))
    print(f"Generated: {out_path} ({width}x{height})")


# ==============================================================================
# ACTIVITY 2 - FIGURE 4: LEVEL 1 DFD FOR 2.0 (DUAL-PATH ATTENDANCE)
# ==============================================================================
def generate_activity2_dfd_level1_proc2():
    width = 3400
    height = 2200
    img = Image.new('RGB', (width, height), PALETTE['canvas_bg'])
    draw = ImageDraw.Draw(img)
    
    draw_header(
        draw, width,
        "Activity #2 — Figure 4: Level 1 DFD for Process 2.0 (Dual-Path Attendance Tracking)",
        "ESP32 Door Hardware, Teacher Mobile NFC, Schedule Guarding, Cutoff Engine & 23:59 Auto-Absent",
        "ACTIVITY #2: REQUIREMENTS TO PROCESS MODELING • PROCESS 2.0 DFD"
    )
    
    # 6 Sub-processes
    sub_w = 640
    sub_h = 160
    
    subs = {
        '2.1': {'x': 780, 'y': 260, 'title': '2.1 Assign RFID Card to Student', 'sub': 'Bind 13.56MHz UID to student LRN with duplicate conflict shield'},
        '2.2': {'x': 1800, 'y': 260, 'title': '2.2 Validate Schedule & Cutoffs', 'sub': 'Enforce class time windows & evaluate Present/Late cutoffs'},
        '2.3': {'x': 780, 'y': 780, 'title': '2.3 Capture Hardware RFID Tap', 'sub': 'ESP32 RC522 scanning, buzzer/LED feedback & LittleFS spool'},
        '2.4': {'x': 1800, 'y': 780, 'title': '2.4 Record Manual Override', 'sub': 'Teacher web/app attendance entry with source indicator'},
        '2.5': {'x': 780, 'y': 1300, 'title': '2.5 Drain Offline Attendance Queue', 'sub': 'SyncCoordinator 45s timer, Drift SQLite -> Supabase batch RPC'},
        '2.6': {'x': 1800, 'y': 1300, 'title': '2.6 Execute 23:59 Auto-Absent', 'sub': 'Cron trigger marking unscanned students for scheduled classes'}
    }
    
    for k, s in subs.items():
        draw_dfd_process(draw, s['x'], s['y'], sub_w, sub_h, k, s['title'], s['sub'], border=PALETTE['emerald_border'])
        
    # Data Stores
    draw_dfd_store(draw, 1340, 520, 620, 90, "D1", "User Accounts & Profiles", "student_profiles, rfid_cards")
    draw_dfd_store(draw, 1340, 1040, 620, 90, "D2", "Attendance & Rosters", "schedules, attendance_records, cutoffs")
    draw_dfd_store(draw, 1340, 1560, 620, 90, "D5", "System Settings & Audit", "school_holidays, sync_queue, audit_logs")
    
    # Entities
    draw_dfd_entity(draw, 100, 260, 480, 130, "Teacher (Client)", "Classroom Administrator", color=PALETTE['slate_blue'])
    draw_dfd_entity(draw, 100, 780, 480, 130, "ESP32 RC522 Scanner", "Edge Door Hardware", color=PALETTE['emerald'])
    draw_dfd_entity(draw, 2760, 260, 520, 130, "Student / Card Tap", "Physical 13.56 MHz Card", color=PALETTE['purple'])
    draw_dfd_entity(draw, 2760, 780, 520, 130, "Parent User", "Absence Alert Recipient", color=PALETTE['amber'])
    draw_dfd_entity(draw, 2760, 1300, 520, 130, "Supabase Cron Engine", "Automated Daily Trigger", color=PALETTE['emerald'])
    
    # Flows
    # Teacher -> 2.1
    draw_arrow(draw, (580, 310), (780, 310), label="Student LRN & Card UID Assignment", color=PALETTE['slate_blue'], width=3)
    # 2.1 <-> D1
    draw_arrow(draw, (1420, 340), (1500, 520), label="Check UID Conflict & Save Mapping", color=PALETTE['emerald'], width=3)
    
    # Student -> 2.3
    draw_arrow(draw, (2760, 330), (2440, 330), label="Card UID Tap Event", color=PALETTE['purple'], width=3)
    
    # ESP32 <-> 2.3
    draw_arrow(draw, (580, 830), (780, 830), label="Card UID, Timestamp & Device ID", color=PALETTE['emerald'], width=3)
    draw_arrow(draw, (780, 880), (580, 880), label="Buzzer/LED Visual Acknowledgment", color=PALETTE['emerald'], width=3)
    
    # 2.3 -> 2.2
    draw_arrow(draw, (1100, 780), (1800, 390), label="Raw Scan Event Payload", color=PALETTE['emerald'], width=3)
    
    # 2.2 <-> D2
    draw_arrow(draw, (1980, 420), (1800, 1040), label="Query Schedule & Grace Cutoffs", color=PALETTE['slate_blue'], width=3)
    draw_arrow(draw, (1820, 1040), (2000, 420), label="Return Schedule Active Window", color=PALETTE['slate_blue'], width=3)
    
    # 2.2 -> D2 (Write Log)
    draw_elbow_arrow(draw, [(2120, 420), (2120, 680), (1700, 680), (1700, 1040)], label="Insert Attendance Record (Present/Late)", color=PALETTE['emerald'], width=3)
    
    # Teacher -> 2.4
    draw_elbow_arrow(draw, [(480, 390), (480, 740), (1800, 740), (1800, 780)], label="Manual Override (source='Manual')", color=PALETTE['slate_blue'], width=3)
    # 2.4 -> D2
    draw_arrow(draw, (1950, 940), (1850, 1040), label="Teacher Authoritative Override", color=PALETTE['slate_blue'], width=3)
    
    # 2.5 <-> D2 & D5
    draw_arrow(draw, (1100, 1300), (1450, 1130), label="Drain SQLite Buffer Records", color=PALETTE['emerald'], width=3)
    draw_arrow(draw, (1100, 1380), (1450, 1560), label="Update Sync Status to 'Synced'", color=PALETTE['emerald'], width=3)
    
    # 2.6 <-> Supabase Cron
    draw_arrow(draw, (2760, 1350), (2440, 1350), label="Trigger 23:59 Cron Event", color=PALETTE['emerald'], width=3)
    draw_arrow(draw, (1980, 1300), (1850, 1130), label="Mark Unscanned Students 'Absent'", color=PALETTE['rose'], width=3)
    
    # D2 -> Parent (Absence Warnings)
    draw_elbow_arrow(draw, [(1960, 1080), (2500, 1080), (2500, 840), (2760, 840)], label="Push Warning Alert (≥3 Absences)", color=PALETTE['amber'], width=3)
    
    draw_footer(draw, width, height)
    out_path = os.path.join(OUTPUT_DIR, "activity2_dfd_level1_proc2.png")
    img.save(out_path, dpi=(300, 300))
    print(f"Generated: {out_path} ({width}x{height})")


# ==============================================================================
# ACTIVITY 2 - FIGURE 5: LEVEL 1 DFD FOR 3.0 (ASSESSMENTS & GRADES)
# ==============================================================================
def generate_activity2_dfd_level1_proc3():
    width = 3400
    height = 2000
    img = Image.new('RGB', (width, height), PALETTE['canvas_bg'])
    draw = ImageDraw.Draw(img)
    
    draw_header(
        draw, width,
        "Activity #2 — Figure 5: Level 1 DFD for Process 3.0 (Assessments & Grade Computation)",
        "Classwork Requirements, Digital Quiz Auto-Scoring, DepEd Weighted Aggregation & Transmutation",
        "ACTIVITY #2: REQUIREMENTS TO PROCESS MODELING • PROCESS 3.0 DFD"
    )
    
    sub_w = 640
    sub_h = 160
    
    subs = {
        '3.1': {'x': 780, 'y': 280, 'title': '3.1 Publish Classwork Tasks', 'sub': 'Teacher defines title, max score, due date & attachments'},
        '3.2': {'x': 1800, 'y': 280, 'title': '3.2 Author Quizzes & Question Banks', 'sub': 'Multiple-choice items, options & answer key configuration'},
        '3.3': {'x': 780, 'y': 880, 'title': '3.3 Receive Student Submissions', 'sub': 'File uploads (PDF/DOCX) & quiz answers with anti-cheating log'},
        '3.4': {'x': 1800, 'y': 880, 'title': '3.4 Auto-Check Objective Items', 'sub': 'Instant scoring, response logging & item analysis'},
        '3.5': {'x': 780, 'y': 1480, 'title': '3.5 Compute DepEd Weighted Components', 'sub': 'Written Work (20%), Performance Tasks (50%), Exam (30%)'},
        '3.6': {'x': 1800, 'y': 1480, 'title': '3.6 Apply Transmutation & Generate ECR', 'sub': 'Map initial grade to 70–100 scale & export DepEd SF9'}
    }
    
    for k, s in subs.items():
        draw_dfd_process(draw, s['x'], s['y'], sub_w, sub_h, k, s['title'], s['sub'], border=PALETTE['purple_border'])
        
    draw_dfd_store(draw, 1340, 580, 620, 90, "D3", "Classwork & Assessments", "activities, submissions, quizzes, responses")
    draw_dfd_store(draw, 1340, 1180, 620, 90, "D2", "Attendance & Rosters", "enrolled students, subject offerings")
    
    draw_dfd_entity(draw, 100, 280, 480, 130, "Teacher (Client)", "Ma'am Karen P. Gonzaga", color=PALETTE['slate_blue'])
    draw_dfd_entity(draw, 2760, 280, 520, 130, "Student (SHS)", "Classwork & Quiz Participant", color=PALETTE['purple'])
    draw_dfd_entity(draw, 2760, 1480, 520, 130, "Parent User", "Grade Card Viewer", color=PALETTE['amber'])
    
    # Flows
    draw_arrow(draw, (580, 330), (780, 330), label="Classwork Title, Due Date & File", color=PALETTE['slate_blue'], width=3)
    draw_arrow(draw, (580, 380), (1800, 330), label="Quiz Items, Options & Answer Key", color=PALETTE['slate_blue'], width=3)
    
    draw_arrow(draw, (1100, 440), (1450, 580), label="Save Classwork Task Record", color=PALETTE['purple'], width=3)
    draw_arrow(draw, (1980, 440), (1850, 580), label="Save Quiz & Questions Schema", color=PALETTE['purple'], width=3)
    
    draw_arrow(draw, (2760, 380), (1420, 880), label="Submit Activity File & Quiz Answers", color=PALETTE['purple'], width=3)
    draw_arrow(draw, (1420, 940), (1800, 940), label="Extract Answers for Auto-Scoring", color=PALETTE['purple'], width=3)
    draw_arrow(draw, (1980, 1040), (1850, 670), label="Save Question Response & Score", color=PALETTE['purple'], width=3)
    
    draw_arrow(draw, (1450, 670), (1100, 1480), label="Fetch Aggregated Component Scores", color=PALETTE['purple'], width=3)
    draw_arrow(draw, (1420, 1540), (1800, 1540), label="Summed Initial Percentage Grade", color=PALETTE['purple'], width=3)
    draw_arrow(draw, (1980, 1640), (1850, 670), label="Store Transmuted Grade Record", color=PALETTE['purple'], width=3)
    
    draw_arrow(draw, (2440, 1540), (2760, 1540), label="Official SF9 Electronic Class Record", color=PALETTE['amber'], width=3)
    draw_elbow_arrow(draw, [(2440, 1500), (2580, 1500), (2580, 410), (2760, 410)], label="Personal Transmuted Grade Summary", color=PALETTE['purple'], width=3)
    
    draw_footer(draw, width, height)
    out_path = os.path.join(OUTPUT_DIR, "activity2_dfd_level1_proc3.png")
    img.save(out_path, dpi=(300, 300))
    print(f"Generated: {out_path} ({width}x{height})")


# ==============================================================================
# ACTIVITY 2 - FIGURE 6: LEVEL 1 DFD FOR 4.0 (LESSON PLANNING & MATERIALS)
# ==============================================================================
def generate_activity2_dfd_level1_proc4():
    width = 3200
    height = 1900
    img = Image.new('RGB', (width, height), PALETTE['canvas_bg'])
    draw = ImageDraw.Draw(img)
    
    draw_header(
        draw, width,
        "Activity #2 — Figure 6: Level 1 DFD for Process 4.0 (Lesson Planning & Materials)",
        "ILAW Framework Structuring, Gemini AI Assistance, Storage Buckets & Student Distribution",
        "ACTIVITY #2: REQUIREMENTS TO PROCESS MODELING • PROCESS 4.0 DFD"
    )
    
    sub_w = 640
    sub_h = 160
    
    subs = {
        '4.1': {'x': 780, 'y': 280, 'title': '4.1 Structure ILAW Lesson Plan', 'sub': 'Define topic, competencies & 4-stage ILAW instructional sequence'},
        '4.2': {'x': 1800, 'y': 280, 'title': '4.2 AI-Assisted Lesson Refinement', 'sub': 'Curriculum prompt expansion via Google Gemini API'},
        '4.3': {'x': 780, 'y': 980, 'title': '4.3 Upload & Categorize Materials', 'sub': 'Store PDFs, DOCX, slides in Supabase Storage buckets'},
        '4.4': {'x': 1800, 'y': 980, 'title': '4.4 Distribute Learning Resources', 'sub': 'RLS-enforced resource listing in student mobile portal'}
    }
    
    for k, s in subs.items():
        draw_dfd_process(draw, s['x'], s['y'], sub_w, sub_h, k, s['title'], s['sub'], border=PALETTE['sky'])
        
    draw_dfd_store(draw, 1340, 620, 620, 100, "D4", "Lesson Plans & Learning Materials", "lesson_plans, folders, learning_materials, URLs")
    
    draw_dfd_entity(draw, 100, 280, 480, 130, "Teacher (Client)", "Instructional Author", color=PALETTE['slate_blue'])
    draw_dfd_entity(draw, 2600, 280, 500, 130, "Google Gemini AI API", "Instructional Assistant", color=PALETTE['purple'])
    draw_dfd_entity(draw, 2600, 980, 500, 130, "Student (SHS)", "Handout Download Recipient", color=PALETTE['purple'])
    
    # Flows
    draw_arrow(draw, (580, 330), (780, 330), label="Curriculum Topic & Competency Prompts", color=PALETTE['slate_blue'], width=3)
    draw_arrow(draw, (1420, 330), (1800, 330), label="Draft ILAW Lesson Structure", color=PALETTE['sky'], width=3)
    draw_arrow(draw, (2440, 330), (2600, 330), label="Gemini API Prompt Query", color=PALETTE['purple'], width=3)
    draw_arrow(draw, (2600, 380), (2440, 380), label="AI-Generated ILAW Expansion", color=PALETTE['purple'], width=3)
    
    draw_arrow(draw, (1980, 440), (1750, 620), label="Save Completed ILAW Lesson Plan", color=PALETTE['sky'], width=3)
    
    draw_arrow(draw, (580, 1030), (780, 1030), label="Handout PDF Files & Metadata", color=PALETTE['slate_blue'], width=3)
    draw_arrow(draw, (1420, 1030), (1500, 720), label="Store File URL & Category Folder", color=PALETTE['sky'], width=3)
    
    draw_arrow(draw, (1750, 720), (1980, 980), label="Fetch Authorized Material Links", color=PALETTE['sky'], width=3)
    draw_arrow(draw, (2440, 1030), (2600, 1030), label="Download Handouts & Study Guides", color=PALETTE['purple'], width=3)
    
    draw_footer(draw, width, height)
    out_path = os.path.join(OUTPUT_DIR, "activity2_dfd_level1_proc4.png")
    img.save(out_path, dpi=(300, 300))
    print(f"Generated: {out_path} ({width}x{height})")


if __name__ == '__main__':
    generate_activity2_dfd_level0()
    generate_activity2_dfd_level1_overview()
    generate_activity2_dfd_level1_proc1()
    generate_activity2_dfd_level1_proc2()
    generate_activity2_dfd_level1_proc3()
    generate_activity2_dfd_level1_proc4()
