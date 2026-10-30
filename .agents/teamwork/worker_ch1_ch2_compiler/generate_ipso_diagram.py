"""
generate_ipso_diagram.py
Generates an ultra-high-definition Input-Process-Storage-Output (IPSO) diagram
matching the style of Figure 1 in Image 2 for CLASSREALM.
"""

import os
from PIL import Image, ImageDraw, ImageFont

OUTPUT_PATH = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_ch1_ch2_compiler\figures\image1.png"
os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)

# Image dimensions (high-res for 300 DPI print quality)
WIDTH = 2600
HEIGHT = 1500
BG_COLOR = (255, 255, 255)

img = Image.new("RGB", (WIDTH, HEIGHT), BG_COLOR)
draw = ImageDraw.Draw(img)

# Fonts
font_dir = r"C:\Windows\Fonts"
try:
    title_font = ImageFont.truetype(os.path.join(font_dir, "arialbd.ttf"), 46)
    header_font = ImageFont.truetype(os.path.join(font_dir, "arialbd.ttf"), 38)
    body_bold = ImageFont.truetype(os.path.join(font_dir, "arialbd.ttf"), 26)
    body_font = ImageFont.truetype(os.path.join(font_dir, "arial.ttf"), 25)
    bullet_font = ImageFont.truetype(os.path.join(font_dir, "arial.ttf"), 32)
except Exception:
    title_font = ImageFont.load_default()
    header_font = ImageFont.load_default()
    body_bold = ImageFont.load_default()
    body_font = ImageFont.load_default()
    bullet_font = ImageFont.load_default()

# 4 Columns definitions
# Colors matching Image 2:
# 1. INPUT: Mustard / Ochre
# 2. PROCESS: Deep Teal / Blue
# 3. STORAGE: Deep Forest Green
# 4. OUTPUT: Deep Purple / Violet

cols_data = [
    {
        "title": "INPUT",
        "header_bg": (196, 138, 25),      # Ochre / Gold
        "border_color": (196, 138, 25),
        "items": [
            "Official student rosters & 12-digit LRNs (Registrar-issued)",
            "RFID card UIDs (via ESP32 hardware scanner or NFC mobile tap)",
            "Plotted class schedules & teacher cutoff thresholds (Present, Late, Absent)",
            "Assessment tasks, quiz items, and answer keys",
            "Raw scores for Written Work, Performance Tasks & Quarterly Exams",
            "DepEd DO 15, s. 2026 grading percentages & weights",
            "Grade 11 Mathematics curriculum competencies & learning materials"
        ]
    },
    {
        "title": "PROCESS",
        "header_bg": (38, 88, 126),       # Deep Teal / Navy Blue
        "border_color": (38, 88, 126),
        "items": [
            "Role-based authentication & credential validation (Firebase Auth)",
            "Schedule-bound attendance validation & duplicate tap suppression",
            "ESP32 offline buffering & cloud synchronization",
            "Nightly 23:59 Supabase Edge Function auto-absent background worker",
            "Real-time objective quiz checking & psychometric item analysis",
            "Automated DepEd DO 15 weighted grade computation & 41-tier transmutation",
            "Lesson plan guide generation & instructional scaffolding",
            "Automated push notification dispatch for absence warnings (>=3 absences)"
        ]
    },
    {
        "title": "STORAGE",
        "header_bg": (32, 105, 54),       # Deep Forest Green
        "border_color": (32, 105, 54),
        "items": [
            "Supabase PostgreSQL relational database",
            "Row-Level Security (RLS) policies by user role",
            "Supabase Storage for learning materials & assignment files",
            "Encrypted multi-year academic & grade archives",
            "Audit-defensible attendance logs (RFID vs. Manual tag)"
        ]
    },
    {
        "title": "OUTPUT",
        "header_bg": (102, 36, 122),      # Deep Purple / Violet
        "border_color": (102, 36, 122),
        "items": [
            "Audit-defensible attendance logs & daily roll call summaries",
            "Automated student absence alerts & parental warning notifications",
            "Official DepEd E-Class Records exportable to PDF, Excel, and CSV",
            "Individual student & parent academic performance dashboards",
            "Formatted Grade 11 Mathematics lesson plan guides",
            "Centralized & searchable digital learning materials repository"
        ]
    }
]

# Layout geometry
margin_x = 80
margin_top = 80
margin_bottom = 80
total_w = WIDTH - (2 * margin_x)
gap_w = 60
col_w = int((total_w - (3 * gap_w)) / 4)
col_h = HEIGHT - margin_top - margin_bottom
header_h = 100
corner_radius = 20

def draw_rounded_card(draw, x, y, w, h, radius, header_color, border_color):
    # Outer box border
    draw.rounded_rectangle([x, y, x + w, y + h], radius=radius, outline=border_color, width=4, fill=(255, 255, 255))
    # Header fill (rounded on top, square at bottom of header)
    # Draw header with mask or rounded rectangle and overlay
    header_img = Image.new("RGBA", (w, header_h), (0, 0, 0, 0))
    h_draw = ImageDraw.Draw(header_img)
    h_draw.rounded_rectangle([0, 0, w, header_h + radius], radius=radius, fill=header_color)
    img.paste(header_img.convert("RGB"), (x, y))
    # Re-draw the card border so header doesn't spill over
    draw.rounded_rectangle([x, y, x + w, y + h], radius=radius, outline=border_color, width=4)

def wrap_text(text, font, max_width):
    words = text.split()
    lines = []
    current_line = []
    for word in words:
        test_line = " ".join(current_line + [word])
        bbox = font.getbbox(test_line)
        line_w = bbox[2] - bbox[0]
        if line_w <= max_width:
            current_line.append(word)
        else:
            if current_line:
                lines.append(" ".join(current_line))
                current_line = [word]
            else:
                lines.append(word)
    if current_line:
        lines.append(" ".join(current_line))
    return lines

# Draw columns
for idx, cdata in enumerate(cols_data):
    cx = margin_x + idx * (col_w + gap_w)
    cy = margin_top
    draw_rounded_card(draw, cx, cy, col_w, col_h, corner_radius, cdata["header_bg"], cdata["border_color"])
    
    # Title
    t_bbox = header_font.getbbox(cdata["title"])
    tw = t_bbox[2] - t_bbox[0]
    th = t_bbox[3] - t_bbox[1]
    tx = cx + (col_w - tw) // 2
    ty = cy + (header_h - th) // 2 - 4
    draw.text((tx, ty), cdata["title"], fill=(255, 255, 255), font=header_font)
    
    # Body items
    cur_y = cy + header_h + 35
    bullet_indent = 45
    text_max_w = col_w - bullet_indent - 30
    
    for item in cdata["items"]:
        # Draw bullet dot
        dot_x = cx + 24
        dot_y = cur_y + 10
        draw.ellipse([dot_x, dot_y, dot_x + 8, dot_y + 8], fill=(40, 40, 40))
        
        # Wrapped text
        lines = wrap_text(item, body_font, text_max_w)
        for line in lines:
            draw.text((cx + bullet_indent, cur_y), line, fill=(35, 35, 35), font=body_font)
            cur_y += 34
        cur_y += 22  # gap between items

# Draw horizontal connecting arrows between columns
arrow_y = margin_top + col_h // 2
for idx in range(3):
    start_x = margin_x + (idx + 1) * col_w + idx * gap_w + 10
    end_x = start_x + gap_w - 20
    # Arrow line
    draw.line([(start_x, arrow_y), (end_x, arrow_y)], fill=(40, 40, 40), width=5)
    # Arrow head
    draw.polygon([(end_x, arrow_y - 10), (end_x + 12, arrow_y), (end_x, arrow_y + 10)], fill=(40, 40, 40))

img.save(OUTPUT_PATH, "PNG", dpi=(300, 300))
print(f"Generated IPSO diagram successfully at {OUTPUT_PATH}! File size: {os.path.getsize(OUTPUT_PATH)} bytes.")

