"""
generate_ch3_diagrams.py
Generates figures for Chapter III Methodology:
- Figure 3: Agile Scrum Methodology Framework of CLASSREALM
- Figure 4: System Architecture and Data Interaction Topology of CLASSREALM
- Figure 5: Context Diagram (Level 0 DFD) of CLASSREALM
Uses PIL/Pillow only.
"""

import os
import sys
from PIL import Image, ImageDraw, ImageFont

FIG_DIR = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_ch1_ch2_compiler\figures"
os.makedirs(FIG_DIR, exist_ok=True)

def load_font(size, bold=False):
    candidates_bold = ["arialbd.ttf", "Arial Bold.ttf", "C:/Windows/Fonts/arialbd.ttf"]
    candidates_regular = ["arial.ttf", "Arial.ttf", "C:/Windows/Fonts/arial.ttf"]
    candidates = candidates_bold if bold else candidates_regular
    for p in candidates:
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            pass
    return ImageFont.load_default()

def draw_rounded_card(draw, xy, r, fill, outline=None, width=2):
    draw.rounded_rectangle(xy, radius=r, fill=fill, outline=outline, width=width)

# -------------------------------------------------------------------------
# FIGURE 3: Agile Scrum Framework
# -------------------------------------------------------------------------
def generate_figure3():
    W, H = 1300, 680
    img = Image.new("RGB", (W, H), (255, 255, 255))
    draw = ImageDraw.Draw(img)

    f_title = load_font(26, bold=True)
    f_box_h = load_font(20, bold=True)
    f_body = load_font(16)
    f_small = load_font(14)

    # Outer border
    draw.rectangle([20, 20, W - 20, H - 20], outline=(200, 200, 200), width=2)

    # 4 Sequential Phase Boxes
    phases = [
        ("Phase 1: Sprint 0 & Elicitation", [
            "• Client Teacher Consultation (Ma'am Karen)",
            "• Form 137 / SF2 / SF10 Review",
            "• DepEd DO 15, s. 2026 Table Mapping",
            "• Core Product Backlog Creation",
            "• Environment & Hardware Setup"
        ], (41, 128, 185)), # Blue
        ("Phase 2: Sprint Iterations (1–4)", [
            "• 2-Week Sprint Timeboxes",
            "• S1: Auth & Role Governance (RLS)",
            "• S2: ESP32 RFID Capture & Buffering",
            "• S3: DepEd Grade Calculation Engine",
            "• S4: iLAW Lesson Plan & Materials"
        ], (39, 174, 96)), # Green
        ("Phase 3: Verification & Review", [
            "• Daily Team Synchronization",
            "• Sprint Review with Client Teacher",
            "• Hardware & Scan Latency Trials",
            "• Sprint Retrospective & Refinement",
            "• Increment Validation"
        ], (211, 84, 0)), # Orange
        ("Phase 4: Release & Evaluation", [
            "• System Pilot Deployment",
            "• Class Doorway Edge Hardware Setup",
            "• Teacher & Student Onboarding",
            "• ISO/IEC 25010:2023 Evaluation",
            "• Acceptability Assessment"
        ], (142, 68, 173)) # Purple
    ]

    card_w = 270
    card_h = 360
    card_y = 120
    gap = 35
    start_x = 55

    for idx, (header, items, color) in enumerate(phases):
        cx = start_x + idx * (card_w + gap)
        # Header banner
        draw_rounded_card(draw, (cx, card_y, cx + card_w, card_y + 60), 12, fill=color, outline=color)
        # Body card
        draw_rounded_card(draw, (cx, card_y + 50, cx + card_w, card_y + card_h), 12, fill=(248, 249, 250), outline=(210, 215, 220), width=2)
        
        # Header text
        tw = draw.textlength(header[:18], font=f_box_h)
        draw.text((cx + (card_w - tw) / 2, card_y + 8), header[:18], font=f_box_h, fill=(255, 255, 255))
        tw2 = draw.textlength(header[18:].strip(), font=load_font(16, bold=True))
        draw.text((cx + (card_w - tw2) / 2, card_y + 32), header[18:].strip(), font=load_font(16, bold=True), fill=(255, 255, 255))

        # Body items
        item_y = card_y + 70
        for itm in items:
            draw.text((cx + 14, item_y), itm, font=f_body, fill=(44, 62, 80))
            item_y += 50

        # Flow Arrow to next phase
        if idx < len(phases) - 1:
            ax = cx + card_w + 6
            ay = card_y + card_h // 2
            draw.polygon([(ax, ay - 12), (ax + 20, ay), (ax, ay + 12)], fill=(52, 73, 94))
            draw.rectangle([ax - 8, ay - 4, ax, ay + 4], fill=(52, 73, 94))

    # Cyclic Feedback Loop Arrow at the bottom (Sprint Review/Retrospective back to Sprint Backlog)
    loop_y = card_y + card_h + 50
    draw.line([(start_x + card_w + gap + 40, loop_y), (start_x + 3 * (card_w + gap) - 40, loop_y)], fill=(127, 140, 141), width=3)
    draw.line([(start_x + card_w + gap + 40, loop_y), (start_x + card_w + gap + 40, card_y + card_h + 10)], fill=(127, 140, 141), width=3)
    draw.line([(start_x + 3 * (card_w + gap) - 40, loop_y), (start_x + 3 * (card_w + gap) - 40, card_y + card_h + 10)], fill=(127, 140, 141), width=3)
    # Arrow pointing up back to Sprint Iterations
    ax_up = start_x + card_w + gap + 40
    draw.polygon([(ax_up - 8, card_y + card_h + 16), (ax_up, card_y + card_h + 2), (ax_up + 8, card_y + card_h + 16)], fill=(127, 140, 141))

    loop_lbl = "Continuous Sprint Review & Retrospective Feedback Loop (Refining Backlog with Client Teacher)"
    ltw = draw.textlength(loop_lbl, font=f_small)
    draw.text(((W - ltw) / 2, loop_y + 12), loop_lbl, font=f_small, fill=(100, 110, 120))

    out_p = os.path.join(FIG_DIR, "image3_agile.png")
    img.save(out_p, "PNG", dpi=(150, 150))
    print(f"Figure 3 generated: {out_p} ({os.path.getsize(out_p):,} bytes)")

# -------------------------------------------------------------------------
# FIGURE 4: System Architecture Topology
# -------------------------------------------------------------------------
def generate_figure4():
    W, H = 1300, 720
    img = Image.new("RGB", (W, H), (255, 255, 255))
    draw = ImageDraw.Draw(img)

    f_box_h = load_font(20, bold=True)
    f_item_h = load_font(18, bold=True)
    f_body = load_font(15)

    draw.rectangle([20, 20, W - 20, H - 20], outline=(200, 200, 200), width=2)

    # 3 Layers: Left (Hardware), Center (Client Applications), Right (Cloud BaaS Backend)
    layers = [
        ("1. PHYSICAL EDGE HARDWARE LAYER", [
            ("ESP32 DevKit Edge Microcontroller", "32-bit Xtensa dual-core, 2.4 GHz Wi-Fi"),
            ("RC522 / PN532 RFID Module", "13.56 MHz High-Frequency Card Detection"),
            ("Offline Local Flash Buffer (SPIFFS/NVS)", "Retains >=5,000 scans during network drop"),
            ("Audiovisual Feedback & Power", "Status Dual LEDs, Buzzer, 5V Li-ion circuit"),
            ("Permanent Fallback Pipeline", "Direct Manual Roster Attendance Logging")
        ], 50, (230, 126, 34)), # Orange

        ("2. MULTI-PLATFORM CLIENT PORTALS", [
            ("Admin Web Portal (Restricted)", "Academic Year Setup & Teacher Provisioning"),
            ("Teacher Web Portal (Responsive)", "Rosters, DO 15 Grading, iLAW Lesson Plans"),
            ("Student Mobile App (Flutter)", "Personal Attendance, Quizzes, Submissions"),
            ("Parent Mobile App (Flutter)", "Attendance Logs, 3+ Absence Alert Notices"),
            ("Offline Resilient Local Cache", "Shared Preferences & In-Memory App Cache")
        ], 460, (41, 128, 185)), # Blue

        ("3. CLOUD BACKEND & BAAS LAYER", [
            ("Supabase PostgreSQL Database", "Relational persistence across multi-year cohorts"),
            ("PostgreSQL Row-Level Security (RLS)", "Role-based data isolation & tenant policies"),
            ("Firebase Authentication", "Encrypted credentials, JWT tokens & password reset"),
            ("Supabase Storage Buckets", "Secure storage for submissions & materials"),
            ("Scheduled Edge Functions", "23:59 Daily Cron Job Auto-Marking Absences")
        ], 870, (39, 174, 96)) # Green
    ]

    col_w = 380
    col_h = 600
    col_y = 60

    for title, items, cx, color in layers:
        # Header
        draw_rounded_card(draw, (cx, col_y, cx + col_w, col_y + 54), 10, fill=color, outline=color)
        tw = draw.textlength(title, font=load_font(16, bold=True))
        draw.text((cx + (col_w - tw) / 2, col_y + 16), title, font=load_font(16, bold=True), fill=(255, 255, 255))

        # Body container
        draw_rounded_card(draw, (cx, col_y + 50, cx + col_w, col_y + col_h), 10, fill=(248, 249, 250), outline=(210, 215, 220), width=2)

        # Item cards
        item_y = col_y + 70
        for header, desc in items:
            draw_rounded_card(draw, (cx + 14, item_y, cx + col_w - 14, item_y + 90), 8, fill=(255, 255, 255), outline=(220, 225, 230), width=1)
            draw.text((cx + 26, item_y + 12), header, font=f_item_h, fill=(44, 62, 80))
            draw.text((cx + 26, item_y + 45), desc, font=f_body, fill=(120, 130, 140))
            item_y += 102

    # Bi-directional communication arrows between layers
    # Hardware <-> Client / Cloud
    ay1 = col_y + col_h // 2
    # Arrow between Layer 1 and 2
    draw.rectangle([430, ay1 - 3, 460, ay1 + 3], fill=(52, 73, 94))
    draw.polygon([(450, ay1 - 8), (460, ay1), (450, ay1 + 8)], fill=(52, 73, 94))
    draw.polygon([(440, ay1 - 8), (430, ay1), (440, ay1 + 8)], fill=(52, 73, 94))

    # Arrow between Layer 2 and 3
    draw.rectangle([840, ay1 - 3, 870, ay1 + 3], fill=(52, 73, 94))
    draw.polygon([(860, ay1 - 8), (870, ay1), (860, ay1 + 8)], fill=(52, 73, 94))
    draw.polygon([(850, ay1 - 8), (840, ay1), (850, ay1 + 8)], fill=(52, 73, 94))

    out_p = os.path.join(FIG_DIR, "image4_architecture.png")
    img.save(out_p, "PNG", dpi=(150, 150))
    print(f"Figure 4 generated: {out_p} ({os.path.getsize(out_p):,} bytes)")

# -------------------------------------------------------------------------
# FIGURE 5: Context Diagram (Level 0 DFD)
# -------------------------------------------------------------------------
def generate_figure5():
    W, H = 1300, 720
    img = Image.new("RGB", (W, H), (255, 255, 255))
    draw = ImageDraw.Draw(img)

    f_title = load_font(20, bold=True)
    f_body = load_font(15, bold=True)
    f_small = load_font(13)

    draw.rectangle([20, 20, W - 20, H - 20], outline=(200, 200, 200), width=2)

    # Central Process Circle: 0 CLASSREALM
    cx, cy, cr = W // 2, H // 2, 130
    draw.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], fill=(41, 128, 185), outline=(26, 82, 118), width=3)
    
    t0 = "0"
    t1 = "CLASSREALM"
    t2 = "Integrated Senior High School"
    t3 = "Attendance & Academic Management"
    t4 = "System"
    
    draw.text((cx - draw.textlength(t0, font=load_font(24, bold=True)) / 2, cy - 65), t0, font=load_font(24, bold=True), fill=(255, 255, 255))
    draw.text((cx - draw.textlength(t1, font=f_title) / 2, cy - 35), t1, font=f_title, fill=(255, 255, 255))
    draw.text((cx - draw.textlength(t2, font=load_font(13)) / 2, cy + 5), t2, font=load_font(13), fill=(240, 240, 240))
    draw.text((cx - draw.textlength(t3, font=load_font(13)) / 2, cy + 25), t3, font=load_font(13), fill=(240, 240, 240))
    draw.text((cx - draw.textlength(t4, font=load_font(13)) / 2, cy + 45), t4, font=load_font(13), fill=(240, 240, 240))

    # 4 External Entities (Rectangles)
    # Top: System Administrator
    ent_w, ent_h = 240, 70
    draw_rounded_card(draw, (cx - ent_w // 2, 45, cx + ent_w // 2, 45 + ent_h), 8, fill=(236, 240, 241), outline=(52, 73, 94), width=2)
    et1 = "SYSTEM ADMINISTRATOR"
    draw.text((cx - draw.textlength(et1, font=f_body) / 2, 45 + 24), et1, font=f_body, fill=(44, 62, 80))

    # Left: Client Teacher (Ma'am Karen Gonzaga)
    draw_rounded_card(draw, (50, cy - ent_h // 2, 50 + ent_w, cy + ent_h // 2), 8, fill=(236, 240, 241), outline=(52, 73, 94), width=2)
    et2 = "CLIENT TEACHER"
    et2_sub = "(Ma'am Karen P. Gonzaga)"
    draw.text((50 + (ent_w - draw.textlength(et2, font=f_body)) / 2, cy - 18), et2, font=f_body, fill=(44, 62, 80))
    draw.text((50 + (ent_w - draw.textlength(et2_sub, font=f_small)) / 2, cy + 8), et2_sub, font=f_small, fill=(100, 110, 120))

    # Right: Grade 11 Student
    draw_rounded_card(draw, (W - 50 - ent_w, cy - ent_h // 2 - 60, W - 50, cy + ent_h // 2 - 60), 8, fill=(236, 240, 241), outline=(52, 73, 94), width=2)
    et3 = "GRADE 11 STUDENT"
    draw.text((W - 50 - ent_w + (ent_w - draw.textlength(et3, font=f_body)) / 2, cy - 60 - 12), et3, font=f_body, fill=(44, 62, 80))

    # Right Bottom: Parent / Legal Guardian
    draw_rounded_card(draw, (W - 50 - ent_w, cy - ent_h // 2 + 80, W - 50, cy + ent_h // 2 + 80), 8, fill=(236, 240, 241), outline=(52, 73, 94), width=2)
    et4 = "PARENT / GUARDIAN"
    draw.text((W - 50 - ent_w + (ent_w - draw.textlength(et4, font=f_body)) / 2, cy + 80 - 12), et4, font=f_body, fill=(44, 62, 80))

    # Flow annotations and lines
    # Admin to System
    draw.line([(cx - 20, 115), (cx - 20, cy - cr)], fill=(41, 128, 185), width=2)
    draw.polygon([(cx - 25, cy - cr - 10), (cx - 20, cy - cr), (cx - 15, cy - cr - 10)], fill=(41, 128, 185))
    draw.text((cx - 190, 140), "Teacher Credentials & AY Setup", font=f_small, fill=(44, 62, 80))

    draw.line([(cx + 20, cy - cr), (cx + 20, 115)], fill=(39, 174, 96), width=2)
    draw.polygon([(cx + 15, 125), (cx + 20, 115), (cx + 25, 125)], fill=(39, 174, 96))
    draw.text((cx + 28, 140), "System Logs & Confirmation", font=f_small, fill=(44, 62, 80))

    # Teacher to System (Left)
    draw.line([(290, cy - 30), (cx - cr, cy - 30)], fill=(41, 128, 185), width=2)
    draw.polygon([(cx - cr - 10, cy - 35), (cx - cr, cy - 30), (cx - cr - 10, cy - 25)], fill=(41, 128, 185))
    draw.text((305, cy - 52), "Rosters, RFID Taps, Scores, DO 15 Weights, Lessons", font=f_small, fill=(44, 62, 80))

    draw.line([(cx - cr, cy + 30), (290, cy + 30)], fill=(39, 174, 96), width=2)
    draw.polygon([(300, cy + 25), (290, cy + 30), (300, cy + 35)], fill=(39, 174, 96))
    draw.text((305, cy + 36), "E-Class Records, Transmuted Grades, Lesson Guides", font=f_small, fill=(44, 62, 80))

    # Student to System (Right Top)
    sy_t = cy - 60
    draw.line([(W - 290, sy_t - 10), (cx + cr, cy - 20)], fill=(41, 128, 185), width=2)
    draw.polygon([(cx + cr + 10, cy - 26), (cx + cr, cy - 20), (cx + cr + 6, cy - 14)], fill=(41, 128, 185))
    draw.text((cx + cr + 45, sy_t - 24), "Quiz Submissions & File Uploads", font=f_small, fill=(44, 62, 80))

    draw.line([(cx + cr, cy - 5), (W - 290, sy_t + 10)], fill=(39, 174, 96), width=2)
    draw.polygon([(W - 300, sy_t + 6), (W - 290, sy_t + 10), (W - 302, sy_t + 16)], fill=(39, 174, 96))
    draw.text((cx + cr + 45, sy_t + 14), "Attendance Logs, Grades, Materials", font=f_small, fill=(44, 62, 80))

    # Parent to System (Right Bottom)
    sy_b = cy + 80
    draw.line([(cx + cr, cy + 20), (W - 290, sy_b - 5)], fill=(39, 174, 96), width=2)
    draw.polygon([(W - 300, sy_b - 9), (W - 290, sy_b - 5), (W - 300, sy_b + 1)], fill=(39, 174, 96))
    draw.text((cx + cr + 45, sy_b - 20), "Real-time Attendance, 3+ Absence Alerts, Grades", font=f_small, fill=(44, 62, 80))

    out_p = os.path.join(FIG_DIR, "image5_context_dfd.png")
    img.save(out_p, "PNG", dpi=(150, 150))
    print(f"Figure 5 generated: {out_p} ({os.path.getsize(out_p):,} bytes)")

if __name__ == "__main__":
    generate_figure3()
    generate_figure4()
    generate_figure5()
    print("All Chapter III diagrams generated successfully!")

