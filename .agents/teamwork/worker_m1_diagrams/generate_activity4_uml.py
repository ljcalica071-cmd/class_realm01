import os
from PIL import Image, ImageDraw, ImageFont
from diagram_engine import (
    PALETTE, FONTS, text_size, wrap_text,
    draw_header, draw_footer, draw_card, draw_bullet_item, draw_badge,
    draw_arrow, draw_elbow_arrow
)

OUTPUT_DIR = "c:/Users/Admin/AndroidStudioProjects/class_realm01/docs/diagrams"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# UML Drawing Helpers
def draw_uml_actor(draw, x, y, name, color=PALETTE['navy']):
    # Stick figure actor
    head_r = 16
    draw.ellipse([x - head_r, y - head_r*2, x + head_r, y], fill=PALETTE['white'], outline=color, width=3)
    # Body
    body_y_end = y + 42
    draw.line([(x, y), (x, body_y_end)], fill=color, width=3)
    # Arms
    draw.line([(x - 28, y + 14), (x + 28, y + 14)], fill=color, width=3)
    # Legs
    draw.line([(x, body_y_end), (x - 22, body_y_end + 38)], fill=color, width=3)
    draw.line([(x, body_y_end), (x + 22, body_y_end + 38)], fill=color, width=3)
    # Label
    nw, _ = text_size(draw, name, FONTS['body_bold'])
    draw.text((x - nw / 2, body_y_end + 46), name, font=FONTS['body_bold'], fill=PALETTE['text_dark'])

def draw_uml_use_case(draw, x, y, rx, ry, text, color=PALETTE['navy'], fill=PALETTE['white']):
    draw.ellipse([x - rx, y - ry, x + rx, y + ry], fill=fill, outline=color, width=2)
    lines = wrap_text(text, FONTS['body_sm_bold'], rx * 1.8)
    total_h = len(lines) * 20
    start_y = y - total_h / 2
    for idx, l in enumerate(lines):
        lw, _ = text_size(draw, l, FONTS['body_sm_bold'])
        draw.text((x - lw / 2, start_y + idx * 20), l, font=FONTS['body_sm_bold'], fill=PALETTE['text_dark'])

def draw_uml_class(draw, x, y, w, h, class_name, stereotype=None, attrs=None, methods=None, is_abstract=False, color=PALETTE['navy']):
    draw.rectangle([x, y, x + w, y + h], fill=PALETTE['white'], outline=color, width=2)
    # Header compartment
    hdr_h = 50 if stereotype else 40
    draw.rectangle([x, y, x + w, y + hdr_h], fill=PALETTE['soft_blue'])
    draw.line([(x, y + hdr_h), (x + w, y + hdr_h)], fill=color, width=2)
    
    if stereotype:
        sw, _ = text_size(draw, f"<<{stereotype}>>", FONTS['badge'])
        draw.text((x + (w - sw) / 2, y + 6), f"<<{stereotype}>>", font=FONTS['badge'], fill=PALETTE['text_muted'])
        cw, _ = text_size(draw, class_name, FONTS['body_bold'])
        draw.text((x + (w - cw) / 2, y + 24), class_name, font=FONTS['body_bold'], fill=PALETTE['navy'])
    else:
        cw, _ = text_size(draw, class_name, FONTS['body_bold'])
        draw.text((x + (w - cw) / 2, y + 10), class_name, font=FONTS['body_bold'], fill=PALETTE['navy'])
        
    cur_y = y + hdr_h + 8
    # Attributes compartment
    if attrs:
        for a in attrs:
            draw.text((x + 10, cur_y), a, font=FONTS['body_sm'], fill=PALETTE['text_dark'])
            cur_y += 20
    # Separator
    draw.line([(x, cur_y + 4), (x + w, cur_y + 4)], fill=PALETTE['border_light'], width=1)
    cur_y += 10
    # Methods compartment
    if methods:
        for m in methods:
            draw.text((x + 10, cur_y), m, font=FONTS['body_sm'], fill=PALETTE['text_dark'])
            cur_y += 20

def draw_uml_object(draw, x, y, w, h, obj_name, class_name, slots, color=PALETTE['slate_blue']):
    draw.rounded_rectangle([x, y, x + w, y + h], radius=8, fill=PALETTE['white'], outline=color, width=2)
    hdr_h = 42
    draw.rounded_rectangle([x, y, x + w, y + hdr_h], radius=8, fill=PALETTE['card_alt_bg'])
    draw.rectangle([x, y + 10, x + w, y + hdr_h], fill=PALETTE['card_alt_bg'])
    draw.line([(x, y + hdr_h), (x + w, y + hdr_h)], fill=color, width=2)
    
    header_text = f"{obj_name} : {class_name}"
    hw, _ = text_size(draw, header_text, FONTS['body_bold'])
    hx = x + (w - hw) / 2
    draw.text((hx, y + 10), header_text, font=FONTS['body_bold'], fill=PALETTE['navy'])
    draw.line([(hx, y + 32), (hx + hw, y + 32)], fill=PALETTE['navy'], width=1) # Underline for object
    
    cur_y = y + hdr_h + 10
    for slot in slots:
        draw.text((x + 12, cur_y), slot, font=FONTS['body_sm'], fill=PALETTE['text_dark'])
        cur_y += 20

def draw_erd_entity(draw, x, y, w, h, table_name, pk_cols, fk_cols, normal_cols, color=PALETTE['navy']):
    draw.rectangle([x, y, x + w, y + h], fill=PALETTE['white'], outline=color, width=2)
    # Header bar
    hdr_h = 36
    draw.rectangle([x, y, x + w, y + hdr_h], fill=color)
    draw.text((x + 12, y + 8), table_name.upper(), font=FONTS['body_bold'], fill=PALETTE['white'])
    
    cur_y = y + hdr_h + 6
    for pk, col_type in pk_cols:
        draw.text((x + 10, cur_y), "PK", font=FONTS['badge'], fill=PALETTE['amber'])
        draw.text((x + 36, cur_y), pk, font=FONTS['body_sm_bold'], fill=PALETTE['navy'])
        tw, _ = text_size(draw, col_type, FONTS['code'])
        draw.text((x + w - tw - 10, cur_y + 1), col_type, font=FONTS['code'], fill=PALETTE['text_muted'])
        cur_y += 20
        
    for fk, col_type in fk_cols:
        draw.text((x + 10, cur_y), "FK", font=FONTS['badge'], fill=PALETTE['slate_blue'])
        draw.text((x + 36, cur_y), fk, font=FONTS['body_sm'], fill=PALETTE['text_dark'])
        tw, _ = text_size(draw, col_type, FONTS['code'])
        draw.text((x + w - tw - 10, cur_y + 1), col_type, font=FONTS['code'], fill=PALETTE['text_muted'])
        cur_y += 20
        
    if normal_cols:
        draw.line([(x, cur_y + 2), (x + w, cur_y + 2)], fill=PALETTE['border_light'], width=1)
        cur_y += 6
        for col, col_type in normal_cols:
            draw.text((x + 36, cur_y), col, font=FONTS['body_sm'], fill=PALETTE['text_muted'])
            tw, _ = text_size(draw, col_type, FONTS['code'])
            draw.text((x + w - tw - 10, cur_y + 1), col_type, font=FONTS['code'], fill=PALETTE['text_light'])
            cur_y += 20


# ==============================================================================
# ACTIVITY 4 - FIGURE 1: ENTITY-RELATIONSHIP DIAGRAM (ERD)
# ==============================================================================
def generate_activity4_erd():
    width = 3800
    height = 2500
    img = Image.new('RGB', (width, height), PALETTE['canvas_bg'])
    draw = ImageDraw.Draw(img)
    
    draw_header(
        draw, width,
        "Activity #4 — Entity-Relationship Diagram (ERD) of CLASSREALM",
        "Relational Database Schema (Supabase PostgreSQL & Drift SQLite), Primary/Foreign Keys & Cardinalities",
        "ACTIVITY #4: INTEGRATED UML & DATA MODELING • RELATIONAL ERD"
    )
    
    # 16 Relational Tables grouped into 4 functional columns
    # Col 1: Users & Profiles
    # Col 2: Academic Setup & Scheduling
    # Col 3: Attendance & Hardware Logs
    # Col 4: Assessments, Grading & Materials
    
    ew = 440
    
    # Tables definition
    # 1. users
    draw_erd_entity(draw, 80, 200, ew, 180, "users", 
                    [("id", "UUID")], [], 
                    [("email", "VARCHAR(255)"), ("role", "user_role_enum"), ("is_archived", "BOOLEAN"), ("created_at", "TIMESTAMP")],
                    color=PALETTE['navy'])
    # 2. teacher_profiles
    draw_erd_entity(draw, 80, 430, ew, 170, "teacher_profiles",
                    [("teacher_id", "UUID")], [("teacher_id", "UUID -> users")],
                    [("first_name", "VARCHAR(100)"), ("last_name", "VARCHAR(100)"), ("department", "VARCHAR(100)")],
                    color=PALETTE['slate_blue'])
    # 3. student_profiles
    draw_erd_entity(draw, 80, 650, ew, 210, "student_profiles",
                    [("student_id", "UUID")], [("student_id", "UUID -> users")],
                    [("lrn", "VARCHAR(12)"), ("first_name", "VARCHAR(100)"), ("last_name", "VARCHAR(100)"), ("grade_level", "VARCHAR(20)"), ("rfid_uid", "VARCHAR(32)")],
                    color=PALETTE['purple'])
    # 4. parent_profiles
    draw_erd_entity(draw, 80, 910, ew, 170, "parent_profiles",
                    [("parent_id", "UUID")], [("parent_id", "UUID -> users")],
                    [("first_name", "VARCHAR(100)"), ("last_name", "VARCHAR(100)"), ("contact_number", "VARCHAR(20)")],
                    color=PALETTE['amber'])
    # 5. parent_student_links
    draw_erd_entity(draw, 80, 1130, ew, 170, "parent_student_links",
                    [("id", "UUID")], [("parent_id", "UUID"), ("student_id", "UUID")],
                    [("relationship", "VARCHAR(50)"), ("is_verified", "BOOLEAN"), ("created_at", "TIMESTAMP")],
                    color=PALETTE['amber'])
    # 6. admin_profiles
    draw_erd_entity(draw, 80, 1350, ew, 150, "admin_profiles",
                    [("admin_id", "UUID")], [("admin_id", "UUID -> users")],
                    [("first_name", "VARCHAR(100)"), ("last_name", "VARCHAR(100)")],
                    color=PALETTE['rose'])
                    
    # Col 2: Academic Setup
    # 7. sections
    draw_erd_entity(draw, 620, 200, ew, 170, "sections",
                    [("id", "UUID")], [],
                    [("name", "VARCHAR(100)"), ("grade_level", "VARCHAR(20)"), ("school_year", "VARCHAR(20)"), ("is_archived", "BOOLEAN")],
                    color=PALETTE['navy'])
    # 8. subjects
    draw_erd_entity(draw, 620, 420, ew, 170, "subjects",
                    [("id", "UUID")], [],
                    [("subject_code", "VARCHAR(50)"), ("subject_name", "VARCHAR(150)"), ("grade_level", "VARCHAR(20)")],
                    color=PALETTE['navy'])
    # 9. subject_offerings
    draw_erd_entity(draw, 620, 640, ew, 230, "subject_offerings",
                    [("id", "UUID")], [("teacher_id", "UUID"), ("subject_id", "UUID"), ("section_id", "UUID")],
                    [("ww_weight", "NUMERIC(4,2)"), ("pt_weight", "NUMERIC(4,2)"), ("ex_weight", "NUMERIC(4,2)"), ("school_year", "VARCHAR(20)")],
                    color=PALETTE['slate_blue'])
    # 10. class_schedules
    draw_erd_entity(draw, 620, 920, ew, 190, "class_schedules",
                    [("id", "UUID")], [("subject_offering_id", "UUID")],
                    [("day_of_week", "VARCHAR(20)"), ("start_time", "TIME"), ("end_time", "TIME"), ("room", "VARCHAR(50)")],
                    color=PALETTE['slate_blue'])
    # 11. student_enrollments
    draw_erd_entity(draw, 620, 1160, ew, 170, "student_enrollments",
                    [("id", "UUID")], [("student_id", "UUID"), ("subject_offering_id", "UUID")],
                    [("status", "enroll_status_enum"), ("created_at", "TIMESTAMP")],
                    color=PALETTE['purple'])
                    
    # Col 3: Attendance & Hardware
    # 12. rfid_cards
    draw_erd_entity(draw, 1160, 200, ew, 190, "rfid_cards",
                    [("id", "UUID")], [("student_id", "UUID")],
                    [("card_uid", "VARCHAR(32) UNIQUE"), ("status", "VARCHAR(20)"), ("assigned_at", "TIMESTAMP")],
                    color=PALETTE['emerald'])
    # 13. attendance_records
    draw_erd_entity(draw, 1160, 440, ew, 250, "attendance_records",
                    [("id", "UUID")], [("student_id", "UUID"), ("subject_offering_id", "UUID")],
                    [("attendance_date", "DATE"), ("time_in", "TIME"), ("status", "att_status_enum"), ("recording_method", "VARCHAR(20)"), ("sync_status", "VARCHAR(20)"), ("device_id", "VARCHAR(50)")],
                    color=PALETTE['emerald'])
    # 14. attendance_cutoffs
    draw_erd_entity(draw, 1160, 740, ew, 190, "attendance_cutoffs",
                    [("id", "UUID")], [("subject_offering_id", "UUID")],
                    [("present_cutoff_minutes", "INTEGER"), ("late_cutoff_minutes", "INTEGER"), ("absent_cutoff_minutes", "INTEGER")],
                    color=PALETTE['emerald'])
    # 15. offline_sync_queue (Drift local)
    draw_erd_entity(draw, 1160, 980, ew, 210, "offline_sync_queue",
                    [("id", "UUID")], [],
                    [("action", "VARCHAR(50)"), ("target_table", "VARCHAR(50)"), ("payload_json", "TEXT"), ("retry_count", "INTEGER"), ("status", "VARCHAR(20)")],
                    color=PALETTE['emerald'])
                    
    # Col 4: Assessments, Grading & Materials
    # 16. classwork_items
    draw_erd_entity(draw, 1700, 200, ew, 210, "classwork_items",
                    [("id", "UUID")], [("subject_offering_id", "UUID")],
                    [("title", "VARCHAR(150)"), ("component", "VARCHAR(10)"), ("max_score", "NUMERIC(5,2)"), ("due_date", "TIMESTAMP"), ("file_url", "TEXT")],
                    color=PALETTE['purple'])
    # 17. student_classwork_submissions
    draw_erd_entity(draw, 1700, 460, ew, 210, "student_classwork_submissions",
                    [("id", "UUID")], [("classwork_id", "UUID"), ("student_id", "UUID")],
                    [("submitted_at", "TIMESTAMP"), ("file_url", "TEXT"), ("score", "NUMERIC(5,2)"), ("status", "VARCHAR(20)")],
                    color=PALETTE['purple'])
    # 18. digital_assessments
    draw_erd_entity(draw, 1700, 720, ew, 190, "digital_assessments",
                    [("id", "UUID")], [("subject_offering_id", "UUID")],
                    [("title", "VARCHAR(150)"), ("type", "VARCHAR(20)"), ("total_items", "INTEGER"), ("passing_score", "NUMERIC(5,2)")],
                    color=PALETTE['purple'])
    # 19. assessment_questions
    draw_erd_entity(draw, 1700, 960, ew, 190, "assessment_questions",
                    [("id", "UUID")], [("assessment_id", "UUID")],
                    [("item_number", "INTEGER"), ("question_text", "TEXT"), ("correct_answer", "VARCHAR(50)"), ("points", "NUMERIC(4,2)")],
                    color=PALETTE['purple'])
    # 20. assessment_responses
    draw_erd_entity(draw, 1700, 1200, ew, 210, "assessment_responses",
                    [("id", "UUID")], [("question_id", "UUID"), ("student_id", "UUID")],
                    [("student_answer", "TEXT"), ("is_correct", "BOOLEAN"), ("points_earned", "NUMERIC(4,2)")],
                    color=PALETTE['purple'])
                    
    # Col 5: Grading & Lessons (Far Right)
    col5_x = 2240
    # 21. term_grades
    draw_erd_entity(draw, col5_x, 200, ew, 230, "term_grades",
                    [("id", "UUID")], [("student_id", "UUID"), ("subject_offering_id", "UUID")],
                    [("term", "VARCHAR(10)"), ("initial_grade", "NUMERIC(5,2)"), ("transmuted_grade", "INTEGER"), ("remarks", "VARCHAR(50)")],
                    color=PALETTE['amber'])
    # 22. lesson_plans
    draw_erd_entity(draw, col5_x, 480, ew, 210, "lesson_plans",
                    [("id", "UUID")], [("teacher_id", "UUID"), ("subject_offering_id", "UUID")],
                    [("topic", "VARCHAR(200)"), ("week_number", "INTEGER"), ("ilaw_phase", "VARCHAR(50)"), ("content_json", "JSONB")],
                    color=PALETTE['sky'])
    # 23. learning_materials
    draw_erd_entity(draw, col5_x, 740, ew, 210, "learning_materials",
                    [("id", "UUID")], [("teacher_id", "UUID"), ("subject_offering_id", "UUID")],
                    [("title", "VARCHAR(200)"), ("file_url", "TEXT"), ("file_type", "VARCHAR(20)"), ("size_bytes", "BIGINT")],
                    color=PALETTE['sky'])
    # 24. audit_logs
    draw_erd_entity(draw, col5_x, 1000, ew, 190, "audit_logs",
                    [("id", "UUID")], [("user_id", "UUID")],
                    [("action", "VARCHAR(100)"), ("entity_type", "VARCHAR(50)"), ("details_json", "JSONB"), ("created_at", "TIMESTAMP")],
                    color=PALETTE['rose'])
                    
    # Summary Schema Legend Box on Bottom
    draw.rounded_rectangle([col5_x + 500, 200, width - 80, 1400], radius=14, fill=PALETTE['white'], outline=PALETTE['border'], width=2)
    draw.text((col5_x + 530, 230), "RELATIONAL SCHEMA ARCHITECTURE", font=FONTS['section_header'], fill=PALETTE['navy'])
    
    notes = [
        ("Database Engine:", "Supabase PostgreSQL (Cloud) & Drift SQLite (Local Mobile)"),
        ("Security Policy:", "PostgreSQL Row-Level Security (RLS) active on all tables"),
        ("Identity Key:", "users.id maps directly to Firebase Authentication UID"),
        ("Attendance Rule:", "recording_method explicitly stores 'RFID' or 'Manual' source"),
        ("Schedule Guard:", "attendance_records rejected outside class_schedules"),
        ("Cutoff Policy:", "Present ≤15m, Late ≤45m, Absent >60m via attendance_cutoffs"),
        ("Grading Weights:", "DepEd DO 15: WW 20%, PT 50%, EX 30% stored in offerings"),
        ("Transmutation:", "term_grades stores both raw initial_grade & transmuted SF9"),
        ("Offline Buffer:", "offline_sync_queue guarantees monotonic event synchronization"),
        ("Storage Buckets:", "Files hosted on Supabase Storage ('learning_materials', 'classwork')")
    ]
    
    ly = 280
    for prefix, desc in notes:
        ly = draw_bullet_item(draw, col5_x + 530, ly, width - col5_x - 620, prefix, desc, bullet="✔", icon_color=PALETTE['emerald'])
        ly += 22
        
    # Relational Connectors between key tables
    draw_arrow(draw, (80 + ew, 290), (620, 290), label="1:N Profile", color=PALETTE['slate_blue'], width=2)
    draw_arrow(draw, (620 + ew, 740), (1160, 540), label="1:N Offering to Attendance", color=PALETTE['emerald'], width=2)
    draw_arrow(draw, (1160 + ew, 300), (1700, 300), label="1:N Offering to Classwork", color=PALETTE['purple'], width=2)
    draw_arrow(draw, (1700 + ew, 300), (col5_x, 300), label="1:N Offering to Grades", color=PALETTE['amber'], width=2)
    
    draw_footer(draw, width, height)
    out_path = os.path.join(OUTPUT_DIR, "activity4_erd.png")
    img.save(out_path, dpi=(300, 300))
    print(f"Generated: {out_path} ({width}x{height})")


# ==============================================================================
# ACTIVITY 4 - FIGURE 2: UML USE CASE DIAGRAM
# ==============================================================================
def generate_activity4_use_case():
    width = 3600
    height = 2400
    img = Image.new('RGB', (width, height), PALETTE['canvas_bg'])
    draw = ImageDraw.Draw(img)
    
    draw_header(
        draw, width,
        "Activity #4 — UML Use Case Diagram of CLASSREALM",
        "Actor Boundaries, System Packages, Core Educational Workflows with <<include>> and <<extend>> Relations",
        "ACTIVITY #4: INTEGRATED UML & DATA MODELING • UML USE CASE"
    )
    
    # System boundary rectangle
    sys_x = 580
    sys_y = 190
    sys_w = 2440
    sys_h = 2110
    draw.rounded_rectangle([sys_x, sys_y, sys_x + sys_w, sys_y + sys_h], radius=16, fill='#FAFBFD', outline=PALETTE['navy'], width=3)
    draw.text((sys_x + 30, sys_y + 20), "CLASSREALM SYSTEM BOUNDARY", font=FONTS['card_header'], fill=PALETTE['navy'])
    
    # Actors:
    # Admin (Left Top)
    # Teacher (Left Bottom)
    # ESP32 RFID Scanner (Top Center)
    # Student (Right Bottom)
    # Parent (Right Top)
    
    draw_uml_actor(draw, 260, 420, "Administrator", color=PALETTE['rose'])
    draw_uml_actor(draw, 260, 1350, "Teacher\n(Ma'am Karen P. Gonzaga)", color=PALETTE['slate_blue'])
    draw_uml_actor(draw, 1800, 100, "ESP32 RC522 RFID Scanner\n(Edge Hardware)", color=PALETTE['emerald'])
    draw_uml_actor(draw, 3340, 1350, "Student\n(Senior High School)", color=PALETTE['purple'])
    draw_uml_actor(draw, 3340, 420, "Parent / Guardian\n(Mobile App)", color=PALETTE['amber'])
    
    # Use Case Ovals inside system boundary
    rx = 180
    ry = 46
    
    # Package 1: Identity & Provisioning (Top Left)
    uc_auth = (900, 320)
    uc_prov = (900, 450)
    uc_ay = (900, 580)
    uc_audit = (900, 710)
    
    draw_uml_use_case(draw, uc_auth[0], uc_auth[1], rx, ry, "Login & Authenticate")
    draw_uml_use_case(draw, uc_prov[0], uc_prov[1], rx, ry, "Provision Teacher Accounts")
    draw_uml_use_case(draw, uc_ay[0], uc_ay[1], rx, ry, "Rollover Academic Year")
    draw_uml_use_case(draw, uc_audit[0], uc_audit[1], rx, ry, "View System Audit Logs")
    
    # Package 2: Classroom & Attendance (Center Left & Center)
    uc_sec = (900, 1050)
    uc_rfid = (900, 1220)
    uc_dupl = (1380, 1220)
    uc_att = (1500, 750)
    uc_scan = (1500, 500)
    uc_man = (1500, 950)
    uc_sync = (1500, 1150)
    
    draw_uml_use_case(draw, uc_sec[0], uc_sec[1], rx, ry, "Manage Sections & Rosters")
    draw_uml_use_case(draw, uc_rfid[0], uc_rfid[1], rx, ry, "Assign Student RFID Card")
    draw_uml_use_case(draw, uc_dupl[0], uc_dupl[1], rx, ry, "Resolve Duplicate UID Conflict", color=PALETTE['amber'])
    draw_uml_use_case(draw, uc_att[0], uc_att[1], 200, 54, "Record Class Attendance", color=PALETTE['emerald'])
    draw_uml_use_case(draw, uc_scan[0], uc_scan[1], rx, ry, "Scan 13.56MHz RFID Tag", color=PALETTE['emerald'])
    draw_uml_use_case(draw, uc_man[0], uc_man[1], rx, ry, "Record Manual Attendance", color=PALETTE['slate_blue'])
    draw_uml_use_case(draw, uc_sync[0], uc_sync[1], rx, ry, "Drain Offline Buffer Queue", color=PALETTE['emerald'])
    
    # Package 3: Assessments & Grades (Center Right)
    uc_cw = (2100, 1050)
    uc_sub = (2650, 1050)
    uc_quiz = (2100, 1250)
    uc_take = (2650, 1250)
    uc_auto = (2650, 1450)
    uc_cheat = (2650, 1650)
    uc_grade = (2100, 1550)
    uc_trans = (2100, 1750)
    
    draw_uml_use_case(draw, uc_cw[0], uc_cw[1], rx, ry, "Publish Classwork Tasks")
    draw_uml_use_case(draw, uc_sub[0], uc_sub[1], rx, ry, "Submit Classwork File")
    draw_uml_use_case(draw, uc_quiz[0], uc_quiz[1], rx, ry, "Author Digital Quiz & Key")
    draw_uml_use_case(draw, uc_take[0], uc_take[1], rx, ry, "Take Digital Quiz / Exam")
    draw_uml_use_case(draw, uc_auto[0], uc_auto[1], rx, ry, "Auto-Check Objective Items", color=PALETTE['purple'])
    draw_uml_use_case(draw, uc_cheat[0], uc_cheat[1], rx, ry, "Log Tab-Switch Anomaly", color=PALETTE['rose'])
    draw_uml_use_case(draw, uc_grade[0], uc_grade[1], rx, ry, "Compute Quarterly Grades")
    draw_uml_use_case(draw, uc_trans[0], uc_trans[1], rx, ry, "Apply DepEd Transmutation")
    
    # Package 4: Lessons & Materials (Bottom)
    uc_lp = (900, 1850)
    uc_gemini = (1450, 1850)
    uc_mat = (900, 2050)
    uc_down = (2650, 2050)
    
    draw_uml_use_case(draw, uc_lp[0], uc_lp[1], rx, ry, "Generate ILAW Lesson Plan")
    draw_uml_use_case(draw, uc_gemini[0], uc_gemini[1], rx, ry, "Gemini AI Lesson Prompt Expansion", color=PALETTE['purple'])
    draw_uml_use_case(draw, uc_mat[0], uc_mat[1], rx, ry, "Upload Learning Materials")
    draw_uml_use_case(draw, uc_down[0], uc_down[1], rx, ry, "Download Learning Resources")
    
    # Package 5: Student & Parent Monitoring (Top Right)
    uc_att_stu = (2650, 420)
    uc_att_par = (2650, 580)
    uc_warn = (2100, 580)
    
    draw_uml_use_case(draw, uc_att_stu[0], uc_att_stu[1], rx, ry, "View Personal Attendance")
    draw_uml_use_case(draw, uc_att_par[0], uc_att_par[1], rx, ry, "Monitor Child Attendance")
    draw_uml_use_case(draw, uc_warn[0], uc_warn[1], rx, ry, "Receive Absence Warning (≥3)", color=PALETTE['amber'])
    
    # Actor Association Lines
    # Admin links
    draw.line([(310, 420), (uc_auth[0] - rx, uc_auth[1])], fill=PALETTE['rose'], width=2)
    draw.line([(310, 420), (uc_prov[0] - rx, uc_prov[1])], fill=PALETTE['rose'], width=2)
    draw.line([(310, 420), (uc_ay[0] - rx, uc_ay[1])], fill=PALETTE['rose'], width=2)
    draw.line([(310, 420), (uc_audit[0] - rx, uc_audit[1])], fill=PALETTE['rose'], width=2)
    
    # Teacher links
    draw.line([(310, 1350), (uc_auth[0] - rx, uc_auth[1])], fill=PALETTE['slate_blue'], width=2)
    draw.line([(310, 1350), (uc_sec[0] - rx, uc_sec[1])], fill=PALETTE['slate_blue'], width=2)
    draw.line([(310, 1350), (uc_rfid[0] - rx, uc_rfid[1])], fill=PALETTE['slate_blue'], width=2)
    draw.line([(310, 1350), (uc_att[0] - 200, uc_att[1])], fill=PALETTE['slate_blue'], width=2)
    draw.line([(310, 1350), (uc_cw[0] - rx, uc_cw[1])], fill=PALETTE['slate_blue'], width=2)
    draw.line([(310, 1350), (uc_quiz[0] - rx, uc_quiz[1])], fill=PALETTE['slate_blue'], width=2)
    draw.line([(310, 1350), (uc_grade[0] - rx, uc_grade[1])], fill=PALETTE['slate_blue'], width=2)
    draw.line([(310, 1350), (uc_lp[0] - rx, uc_lp[1])], fill=PALETTE['slate_blue'], width=2)
    draw.line([(310, 1350), (uc_mat[0] - rx, uc_mat[1])], fill=PALETTE['slate_blue'], width=2)
    
    # ESP32 links
    draw.line([(1800, 170), (uc_scan[0], uc_scan[1] - ry)], fill=PALETTE['emerald'], width=2)
    draw.line([(1800, 170), (uc_att[0] + 100, uc_att[1] - 54)], fill=PALETTE['emerald'], width=2)
    
    # Student links
    draw.line([(3280, 1350), (uc_auth[0] + rx, uc_auth[1])], fill=PALETTE['purple'], width=2)
    draw.line([(3280, 1350), (uc_sub[0] + rx, uc_sub[1])], fill=PALETTE['purple'], width=2)
    draw.line([(3280, 1350), (uc_take[0] + rx, uc_take[1])], fill=PALETTE['purple'], width=2)
    draw.line([(3280, 1350), (uc_att_stu[0] + rx, uc_att_stu[1])], fill=PALETTE['purple'], width=2)
    draw.line([(3280, 1350), (uc_down[0] + rx, uc_down[1])], fill=PALETTE['purple'], width=2)
    
    # Parent links
    draw.line([(3280, 420), (uc_auth[0] + rx, uc_auth[1])], fill=PALETTE['amber'], width=2)
    draw.line([(3280, 420), (uc_att_par[0] + rx, uc_att_par[1])], fill=PALETTE['amber'], width=2)
    
    # <<include>> and <<extend>> stereotypes (Dashed arrows)
    draw_arrow(draw, (uc_att[0], uc_att[1] - 54), (uc_scan[0], uc_scan[1] + ry), label="<<include>>", color=PALETTE['emerald'], width=2, dashed=True)
    draw_arrow(draw, (uc_man[0], uc_man[1] - ry), (uc_att[0], uc_att[1] + 54), label="<<extend>>", color=PALETTE['slate_blue'], width=2, dashed=True)
    draw_arrow(draw, (uc_sync[0], uc_sync[1] - ry), (uc_att[0] + 80, uc_att[1] + 54), label="<<extend>>", color=PALETTE['emerald'], width=2, dashed=True)
    draw_arrow(draw, (uc_dupl[0] - rx, uc_dupl[1]), (uc_rfid[0] + rx, uc_rfid[1]), label="<<extend>>", color=PALETTE['amber'], width=2, dashed=True)
    
    draw_arrow(draw, (uc_take[0], uc_take[1] + ry), (uc_auto[0], uc_auto[1] - ry), label="<<include>>", color=PALETTE['purple'], width=2, dashed=True)
    draw_arrow(draw, (uc_cheat[0], uc_cheat[1] - ry), (uc_take[0], uc_take[1] + ry), label="<<extend>>", color=PALETTE['rose'], width=2, dashed=True)
    draw_arrow(draw, (uc_grade[0], uc_grade[1] + ry), (uc_trans[0], uc_trans[1] - ry), label="<<include>>", color=PALETTE['navy'], width=2, dashed=True)
    draw_arrow(draw, (uc_gemini[0] - rx, uc_gemini[1]), (uc_lp[0] + rx, uc_lp[1]), label="<<extend>>", color=PALETTE['purple'], width=2, dashed=True)
    draw_arrow(draw, (uc_warn[0] + rx, uc_warn[1]), (uc_att_par[0] - rx, uc_att_par[1]), label="<<extend>>", color=PALETTE['amber'], width=2, dashed=True)
    
    draw_footer(draw, width, height)
    out_path = os.path.join(OUTPUT_DIR, "activity4_use_case.png")
    img.save(out_path, dpi=(300, 300))
    print(f"Generated: {out_path} ({width}x{height})")


# ==============================================================================
# ACTIVITY 4 - FIGURE 3: UML CLASS DIAGRAM
# ==============================================================================
def generate_activity4_class_diagram():
    width = 3800
    height = 2400
    img = Image.new('RGB', (width, height), PALETTE['canvas_bg'])
    draw = ImageDraw.Draw(img)
    
    draw_header(
        draw, width,
        "Activity #4 — UML Class Diagram of CLASSREALM",
        "Object-Oriented Domain Model: Abstract Base Classes, Specialized Roles, Business Entities & Methods",
        "ACTIVITY #4: INTEGRATED UML & DATA MODELING • UML CLASS MODEL"
    )
    
    cw = 420
    
    # 1. Abstract User
    draw_uml_class(draw, 140, 200, cw, 170, "User", stereotype="abstract",
                   attrs=["# id: UUID", "# email: String", "# role: RoleEnum", "# isArchived: Boolean"],
                   methods=["+ login(creds): Boolean", "+ logout(): Void", "+ getSession(): Token"],
                   is_abstract=True, color=PALETTE['navy'])
                   
    # Specialized Roles under User
    # Admin
    draw_uml_class(draw, 80, 440, 380, 150, "Admin",
                   attrs=["+ firstName: String", "+ lastName: String"],
                   methods=["+ provisionTeacher(id): Bool", "+ rolloverAcademicYear(yr): Void", "+ exportAuditLogs(): File"],
                   color=PALETTE['rose'])
    # Teacher
    draw_uml_class(draw, 80, 630, 380, 200, "Teacher",
                   attrs=["+ employeeId: String", "+ department: String", "+ currentSections: List<Sec>"],
                   methods=["+ assignRfid(studId, uid): Bool", "+ recordManualAttendance(rec): Void", "+ computeTermGrades(offId): List", "+ createIlawLesson(topic): Plan"],
                   color=PALETTE['slate_blue'])
    # Student
    draw_uml_class(draw, 80, 860, 380, 180, "Student",
                   attrs=["+ lrn: String", "+ gradeLevel: String", "+ rfidCardUid: String"],
                   methods=["+ viewAttendance(): Summary", "+ submitClasswork(cwId, f): Sub", "+ takeAssessment(asmId): Resp"],
                   color=PALETTE['purple'])
    # Parent
    draw_uml_class(draw, 80, 1070, 380, 170, "Parent",
                   attrs=["+ contactNumber: String", "+ relationship: String"],
                   methods=["+ linkChild(lrn, code): Bool", "+ viewChildAttendance(): Rep", "+ getQuarterlyReportCard(): SF9"],
                   color=PALETTE['amber'])
                   
    # Connect User to subclasses (Generalization)
    draw_arrow(draw, (270, 440), (270, 370), color=PALETTE['navy'], width=2)
    
    # Col 2: Academic Core
    col2_x = 580
    # Section
    draw_uml_class(draw, col2_x, 200, cw, 160, "Section",
                   attrs=["+ id: UUID", "+ name: String", "+ gradeLevel: String", "+ room: String"],
                   methods=["+ getRoster(): List<Student>", "+ isArchived(): Boolean"],
                   color=PALETTE['navy'])
    # SubjectOffering
    draw_uml_class(draw, col2_x, 420, cw, 220, "SubjectOffering",
                   attrs=["+ id: UUID", "+ wwWeight: Double = 0.20", "+ ptWeight: Double = 0.50", "+ exWeight: Double = 0.30", "+ schoolYear: String"],
                   methods=["+ enrollStudent(stud): Void", "+ getSchedule(): Schedule", "+ getAttendanceCutoffs(): Cutoffs"],
                   color=PALETTE['slate_blue'])
    # ClassSchedule
    draw_uml_class(draw, col2_x, 690, cw, 170, "ClassSchedule",
                   attrs=["+ id: UUID", "+ dayOfWeek: DayEnum", "+ startTime: LocalTime", "+ endTime: LocalTime", "+ room: String"],
                   methods=["+ isWithinSchedule(time): Bool", "+ getGraceCutoffs(): Cutoffs"],
                   color=PALETTE['slate_blue'])
    # AttendanceCutoffs
    draw_uml_class(draw, col2_x, 900, cw, 160, "AttendanceCutoffs",
                   attrs=["+ presentCutoffMins: Int = 15", "+ lateCutoffMins: Int = 45", "+ absentCutoffMins: Int = 60"],
                   methods=["+ evaluate(scanTime): Status", "+ validateThresholds(): Bool"],
                   color=PALETTE['emerald'])
                   
    # Col 3: Attendance & Hardware
    col3_x = 1100
    # RFIDScanner
    draw_uml_class(draw, col3_x, 200, cw, 200, "RFIDScanner", stereotype="hardware",
                   attrs=["+ deviceId: String = 'ESP32_302'", "+ firmwareVer: String = 'v2.1.0'", "+ localSpoolCount: Int", "+ batteryVoltage: Double"],
                   methods=["+ pollCardSpi(): CardUid", "+ triggerAudioVisualCue(type): Void", "+ flushSpoolToCloud(): Int"],
                   color=PALETTE['emerald'])
    # AttendanceRecord
    draw_uml_class(draw, col3_x, 450, cw, 230, "AttendanceRecord",
                   attrs=["+ id: UUID", "+ date: LocalDate", "+ timeIn: LocalTime", "+ status: StatusEnum", "+ recordingMethod: MethodEnum", "+ syncStatus: SyncEnum"],
                   methods=["+ evaluateAutoAbsent(): Void", "+ overrideByTeacher(newSt): Void", "+ markSynchronized(): Void"],
                   color=PALETTE['emerald'])
    # SyncCoordinator
    draw_uml_class(draw, col3_x, 730, cw, 180, "SyncCoordinator",
                   attrs=["+ pendingQueueCount: Int", "+ syncIntervalSec: Int = 45", "+ isOnline: Boolean"],
                   methods=["+ startBackgroundSync(): Void", "+ processPendingQueue(): Int", "+ resolveConflict(local, cl): Rec"],
                   color=PALETTE['emerald'])
                   
    # Col 4: Assessments & Grades
    col4_x = 1620
    # Classwork
    draw_uml_class(draw, col4_x, 200, cw, 180, "Classwork",
                   attrs=["+ id: UUID", "+ title: String", "+ component: CompEnum", "+ maxScore: Double", "+ dueDate: DateTime"],
                   methods=["+ addSubmission(sub): Void", "+ isLate(submitTime): Bool"],
                   color=PALETTE['purple'])
    # Submission
    draw_uml_class(draw, col4_x, 430, cw, 180, "Submission",
                   attrs=["+ id: UUID", "+ fileUrl: String", "+ submittedAt: DateTime", "+ score: Double", "+ status: SubStatus"],
                   methods=["+ gradeSubmission(score): Void", "+ returnFeedback(txt): Void"],
                   color=PALETTE['purple'])
    # Assessment
    draw_uml_class(draw, col4_x, 660, cw, 190, "Assessment",
                   attrs=["+ id: UUID", "+ title: String", "+ type: AssessType", "+ totalItems: Int", "+ passingScore: Double"],
                   methods=["+ addQuestion(q): Void", "+ startAttempt(studId): Attempt", "+ autoCheckResponses(): Result"],
                   color=PALETTE['purple'])
    # Question
    draw_uml_class(draw, col4_x, 900, cw, 180, "Question",
                   attrs=["+ id: UUID", "+ itemNumber: Int", "+ questionText: String", "+ correctAnswer: String", "+ points: Double"],
                   methods=["+ validateAnswer(ans): Bool", "+ getItemDiscrimination(): Dbl"],
                   color=PALETTE['purple'])
                   
    # Col 5: Grading & Lessons
    col5_x = 2140
    # GradeComputationEngine
    draw_uml_class(draw, col5_x, 200, cw, 190, "GradeComputationEngine",
                   attrs=["+ wwScale: Double = 0.20", "+ ptScale: Double = 0.50", "+ exScale: Double = 0.30"],
                   methods=["+ computeInitialPercentage(): Dbl", "+ transmuteDepEdDO15(init): Int", "+ generateSF9Export(): File"],
                   color=PALETTE['amber'])
    # TermGrade
    draw_uml_class(draw, col5_x, 440, cw, 190, "TermGrade",
                   attrs=["+ id: UUID", "+ term: TermEnum", "+ initialGrade: Double", "+ transmutedGrade: Int", "+ remarks: String"],
                   methods=["+ isPassing(): Boolean", "+ exportToSF9(): Document"],
                   color=PALETTE['amber'])
    # LessonPlan
    draw_uml_class(draw, col5_x, 680, cw, 190, "LessonPlan",
                   attrs=["+ id: UUID", "+ topic: String", "+ weekNumber: Int", "+ ilawPhase: IlawEnum", "+ competencies: List<Str>"],
                   methods=["+ expandWithGemini(prompt): Void", "+ exportToDocx(): File", "+ publishToStudents(): Void"],
                   color=PALETTE['sky'])
    # LearningMaterial
    draw_uml_class(draw, col5_x, 920, cw, 180, "LearningMaterial",
                   attrs=["+ id: UUID", "+ title: String", "+ fileUrl: String", "+ fileType: String", "+ sizeBytes: Long"],
                   methods=["+ downloadMaterial(): Stream", "+ categorize(folderId): Void"],
                   color=PALETTE['sky'])
                   
    # Associations & Compositions
    # SubjectOffering -> ClassSchedule (1 to 1..*)
    draw_arrow(draw, (col2_x + cw/2, 640), (col2_x + cw/2, 690), label="1..*", color=PALETTE['slate_blue'], width=2)
    # Assessment *-- Question (Composition)
    draw_arrow(draw, (col4_x + cw/2, 850), (col4_x + cw/2, 900), label="1..* items", color=PALETTE['purple'], width=2)
    # Classwork *-- Submission (Composition)
    draw_arrow(draw, (col4_x + cw/2, 380), (col4_x + cw/2, 430), label="0..* subs", color=PALETTE['purple'], width=2)
    # GradeComputationEngine -> TermGrade
    draw_arrow(draw, (col5_x + cw/2, 390), (col5_x + cw/2, 440), label="produces", color=PALETTE['amber'], width=2)
    
    # Legend Box
    draw.rounded_rectangle([2700, 200, width - 80, 1150], radius=12, fill=PALETTE['white'], outline=PALETTE['border'], width=2)
    draw.text((2730, 230), "UML DESIGN PRINCIPLES & CONVENTIONS", font=FONTS['section_header'], fill=PALETTE['navy'])
    principles = [
        ("Abstract Base Class:", "User defines common auth state, implemented by concrete roles."),
        ("Strict Role Isolation:", "Admin handles infrastructure only; Teacher manages academics."),
        ("Dual-Path Attendance:", "AttendanceRecord accepts both 'RFID' hardware and 'Manual' entries."),
        ("Edge Hardware Object:", "RFIDScanner encapsulates FreeRTOS tasks and LittleFS spool buffer."),
        ("Monotonic Grading:", "GradeComputationEngine applies official DepEd DO 15 transmutation."),
        ("Composition Semantics:", "Assessment owns Questions; Classwork owns Submissions."),
        ("Async Queue Worker:", "SyncCoordinator runs 45s periodic cycles draining offline mutations.")
    ]
    py = 280
    for pfx, dsc in principles:
        py = draw_bullet_item(draw, 2730, py, width - 2800, pfx, dsc, bullet="◈", icon_color=PALETTE['slate_blue'])
        py += 24
        
    draw_footer(draw, width, height)
    out_path = os.path.join(OUTPUT_DIR, "activity4_class_diagram.png")
    img.save(out_path, dpi=(300, 300))
    print(f"Generated: {out_path} ({width}x{height})")


# ==============================================================================
# ACTIVITY 4 - FIGURE 4: UML OBJECT DIAGRAM
# ==============================================================================
def generate_activity4_object_diagram():
    width = 3600
    height = 2400
    img = Image.new('RGB', (width, height), PALETTE['canvas_bg'])
    draw = ImageDraw.Draw(img)
    
    draw_header(
        draw, width,
        "Activity #4 — UML Object Diagram: Live Session Runtime Snapshot",
        "Concrete Friday Morning Runtime Snapshot: Grade 11 Mathematics with Ma'am Karen P. Gonzaga at Eduardo Barretto Sr. High School",
        "ACTIVITY #4: INTEGRATED UML & DATA MODELING • RUNTIME OBJECT MODEL"
    )
    
    ow = 460
    
    # Grid of runtime object instances with actual slot values
    # Col 1: Stakeholders & Roles
    col1_x = 80
    draw_uml_object(draw, col1_x, 200, ow, 200, "t_karen", "Teacher",
                    ["id = 'usr_tea_001'", "fullName = 'Karen P. Gonzaga'", "department = 'Mathematics'", "school = 'Eduardo Barretto Sr. HS'", "status = 'Approved'"],
                    color=PALETTE['slate_blue'])
                    
    draw_uml_object(draw, col1_x, 440, ow, 200, "s_juan", "Student",
                    ["id = 'usr_stu_001'", "lrn = '123456789012'", "fullName = 'Juan Dela Cruz'", "gradeLevel = 'Grade 11'", "section = 'STEM 11-A'"],
                    color=PALETTE['purple'])
                    
    draw_uml_object(draw, col1_x, 680, ow, 180, "p_maria", "Parent",
                    ["id = 'usr_par_001'", "fullName = 'Maria Dela Cruz'", "contact = '0917-1234567'", "linkedStudent = 'Juan Dela Cruz'"],
                    color=PALETTE['amber'])
                    
    draw_uml_object(draw, col1_x, 900, ow, 180, "psl_01", "ParentStudentLink",
                    ["id = 'psl_001'", "relationship = 'Mother'", "isVerified = true", "linkedAt = '2026-08-10'"],
                    color=PALETTE['amber'])
                    
    # Col 2: Academic Setup
    col2_x = 640
    draw_uml_object(draw, col2_x, 200, ow, 190, "sec_stem11", "Section",
                    ["id = 'sec_001'", "name = 'STEM 11-A'", "gradeLevel = 'Grade 11'", "room = 'Room 302'", "schoolYear = '2026-2027'"],
                    color=PALETTE['navy'])
                    
    draw_uml_object(draw, col2_x, 430, ow, 180, "sub_gmath", "Subject",
                    ["id = 'sub_001'", "code = 'GMATH11'", "title = 'General Mathematics'", "units = 4"],
                    color=PALETTE['navy'])
                    
    draw_uml_object(draw, col2_x, 650, ow, 220, "off_gmath", "SubjectOffering",
                    ["id = 'off_001'", "teacherId = 'usr_tea_001'", "wwWeight = 0.20", "ptWeight = 0.50", "exWeight = 0.30", "schoolYear = '2026-2027'"],
                    color=PALETTE['slate_blue'])
                    
    draw_uml_object(draw, col2_x, 910, ow, 190, "sched_fri", "ClassSchedule",
                    ["id = 'sch_001'", "dayOfWeek = 'Friday'", "startTime = '07:30:00'", "endTime = '08:30:00'", "room = 'Room 302'"],
                    color=PALETTE['slate_blue'])
                    
    # Col 3: Hardware & Live Attendance Event
    col3_x = 1200
    draw_uml_object(draw, col3_x, 200, ow, 210, "esp32_door", "RFIDScanner",
                    ["deviceId = 'ESP32_ROOM_302'", "firmware = 'v2.1.0'", "ipAddress = '192.168.1.150'", "batteryVoltage = 4.12", "spoolQueueCount = 0"],
                    color=PALETTE['emerald'])
                    
    draw_uml_object(draw, col3_x, 450, ow, 190, "card_juan", "RFIDCard",
                    ["cardUid = '04:5A:B2:1A'", "assignedTo = 'Juan Dela Cruz'", "status = 'Active'", "assignedAt = '2026-08-15'"],
                    color=PALETTE['emerald'])
                    
    draw_uml_object(draw, col3_x, 680, ow, 230, "att_001", "AttendanceRecord",
                    ["date = '2026-10-30' (Friday)", "scanTime = '07:22:15'", "status = 'Present' (Before 07:30)", "recordingMethod = 'RFID'", "syncStatus = 'Synced'", "deviceId = 'ESP32_ROOM_302'"],
                    color=PALETTE['emerald'])
                    
    draw_uml_object(draw, col3_x, 950, ow, 180, "cutoffs_01", "AttendanceCutoffs",
                    ["presentCutoff = 15 mins (07:45)", "lateCutoff = 45 mins (08:15)", "absentCutoff = 60 mins (08:30)"],
                    color=PALETTE['emerald'])
                    
    # Col 4: Classwork & Quiz Instances
    col4_x = 1760
    draw_uml_object(draw, col4_x, 200, ow, 190, "cw_ratfunc", "Classwork",
                    ["id = 'cw_001'", "title = 'Problem Set 1: Rational Funcs'", "component = 'PT'", "maxScore = 50.0", "dueDate = '2026-10-28 23:59'"],
                    color=PALETTE['purple'])
                    
    draw_uml_object(draw, col4_x, 430, ow, 200, "sub_juan", "Submission",
                    ["id = 'sub_001'", "student = 'Juan Dela Cruz'", "score = 48.0 / 50.0", "submittedAt = '2026-10-28 14:15'", "status = 'Graded'"],
                    color=PALETTE['purple'])
                    
    draw_uml_object(draw, col4_x, 670, ow, 190, "quiz_q1", "Assessment",
                    ["id = 'asm_001'", "title = 'Quarter 1 Quiz: Rational Eqns'", "type = 'Quiz'", "totalItems = 15", "component = 'WW'"],
                    color=PALETTE['purple'])
                    
    draw_uml_object(draw, col4_x, 900, ow, 180, "resp_juan", "AssessmentResponse",
                    ["student = 'Juan Dela Cruz'", "itemNumber = 1", "answer = 'x = 2'", "isCorrect = true", "pointsEarned = 1.0"],
                    color=PALETTE['purple'])
                    
    # Col 5: Gradebook & Lesson Plan Instances
    col5_x = 2320
    draw_uml_object(draw, col5_x, 200, ow, 210, "grd_juan_q1", "TermGrade",
                    ["term = 'Quarter 1'", "writtenWorkScore = 92.5%", "performanceTaskScore = 96.0%", "examScore = 88.0%", "initialGrade = 91.4%", "transmutedGrade = 94 (Passed)"],
                    color=PALETTE['amber'])
                    
    draw_uml_object(draw, col5_x, 450, ow, 210, "lp_rational", "LessonPlan",
                    ["topic = 'Rational Functions & Graphs'", "weekNumber = 10", "ilawPhase = 'Aksyon (Action)'", "curriculumCode = 'M11GM-Ib-1'", "status = 'Completed'"],
                    color=PALETTE['sky'])
                    
    draw_uml_object(draw, col5_x, 700, ow, 190, "mat_handout", "LearningMaterial",
                    ["title = 'Handout_Rational_Functions.pdf'", "fileType = 'PDF'", "sizeBytes = 1452000", "storageBucket = 'learning_materials'"],
                    color=PALETTE['sky'])
                    
    # Scenario Narrative Box (Right Column)
    box_x = 2880
    draw.rounded_rectangle([box_x, 200, width - 80, 1150], radius=14, fill=PALETTE['white'], outline=PALETTE['border'], width=2)
    draw.text((box_x + 30, 230), "LIVE CLASSROOM SCENARIO", font=FONTS['section_header'], fill=PALETTE['navy'])
    
    narrative = [
        ("Time & Date:", "Friday, October 30, 2026 at 07:22:15 AM (PST)."),
        ("Pilot Location:", "Room 302, Eduardo Barretto Senior High School."),
        ("Teacher Session:", "Ma'am Karen P. Gonzaga conducting STEM 11-A General Mathematics."),
        ("Physical Tap:", "Student Juan Dela Cruz taps RFID card (04:5A:B2:1A) on ESP32 scanner at door."),
        ("Instant Cue:", "ESP32 Core 1 sounds high-pitch acknowledgment beep & flashes Green LED."),
        ("Auto-Status:", "Scan is 8 mins before 07:30 start; engine marks status as 'Present' (RFID)."),
        ("Sync Protocol:", "Scan is logged to local SQLite and upserted to Supabase within 45s."),
        ("Parent Visibility:", "Mother Maria Dela Cruz views live green presence badge on Parent App."),
        ("Academic Progress:", "Juan's Problem Set 1 (48/50) and Quiz 1 auto-score yield Q1 Transmuted Grade of 94.")
    ]
    
    ny = 280
    for pfx, dsc in narrative:
        ny = draw_bullet_item(draw, box_x + 30, ny, width - box_x - 100, pfx, dsc, bullet="✦", icon_color=PALETTE['emerald'])
        ny += 24
        
    # Link lines between object instances
    draw.line([(col1_x + ow, 540), (col3_x, 760)], fill=PALETTE['purple'], width=2) # Juan to Attendance
    draw.line([(col3_x + ow, 300), (col3_x + ow/2, 680)], fill=PALETTE['emerald'], width=2) # ESP32 to Attendance
    draw.line([(col1_x + ow, 300), (col2_x, 760)], fill=PALETTE['slate_blue'], width=2) # Karen to Offering
    draw.line([(col4_x + ow, 530), (col5_x, 300)], fill=PALETTE['amber'], width=2) # Submission to Grade
    
    draw_footer(draw, width, height)
    out_path = os.path.join(OUTPUT_DIR, "activity4_object_diagram.png")
    img.save(out_path, dpi=(300, 300))
    print(f"Generated: {out_path} ({width}x{height})")


if __name__ == '__main__':
    generate_activity4_erd()
    generate_activity4_use_case()
    generate_activity4_class_diagram()
    generate_activity4_object_diagram()
