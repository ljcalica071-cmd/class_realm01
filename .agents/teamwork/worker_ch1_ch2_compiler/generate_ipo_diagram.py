"""
generate_ipo_diagram.py
Generates Figure 2 — Input-Process-Output Diagram (IPO) of CLASSREALM
3-column layout: gold INPUT / dark-blue PROCESS / purple OUTPUT
with FEEDBACK dashed arrow at the bottom.
Uses PIL/Pillow only (no matplotlib).
"""

from PIL import Image, ImageDraw, ImageFont
import os
import sys

OUTPUT_PATH = os.path.join(os.path.dirname(__file__), "figures", "image2.png")

# ─── Canvas & layout constants ───────────────────────────────────────────────
W, H = 1400, 760
MARGIN_X = 30
MARGIN_Y = 30
ARROW_W = 48           # width of arrow connectors
FEEDBACK_Y_OFFSET = 44  # how far below the boxes the feedback line sits
CORNER_R = 18

# ─── Colours ─────────────────────────────────────────────────────────────────
GOLD   = (180, 140, 20)
DBLUE  = (30,  70, 130)
PURPLE = (100, 40, 140)
WHITE  = (255, 255, 255)
LIGHT  = (248, 248, 248)
DARK   = (30,  30,  30)
GRAY   = (120, 120, 120)
ARROW_CLR = (60, 60, 60)
FEEDBACK_CLR = (80, 80, 80)
BG     = (255, 255, 255)

# ─── Column content ──────────────────────────────────────────────────────────
INPUT_HEADER  = "INPUT"
PROCESS_HEADER = "PROCESS"
OUTPUT_HEADER  = "OUTPUT"

INPUT_ITEMS = [
    "Teacher: class roster (LRN),",
    "RFID attendance scans,",
    "assessment scores,",
    "grading weights,",
    "lesson plans,",
    "learning materials",
    "",
    "Student: quiz responses",
    "",
    "Admin: academic year setup,",
    "teacher accounts",
]

PROCESS_ITEMS = [
    "Account & Role Management",
    "",
    "Classroom & Attendance",
    "Management",
    "",
    "Assessment & Grading",
    "",
    "Grade Computation",
    "(DepEd DO 15, s. 2026)",
    "",
    "Lesson Plan Guide",
    "Generation",
    "",
    "Learning Materials",
    "Management",
    "",
    "Notifications & Reporting",
]

OUTPUT_ITEMS = [
    "Audit-defensible",
    "Attendance Logs",
    "",
    "E-Class Records",
    "(PDF / Excel / CSV)",
    "",
    "Assessment & Grade Results",
    "",
    "Lesson Plan Guides",
    "",
    "Learning Materials",
    "Repository",
    "",
    "Student & Parent",
    "Dashboard Access",
    "",
    "Absence Warning",
    "Notifications",
]

FEEDBACK_TEXT = (
    "FEEDBACK: Teacher, Students & Parents review outputs "
    "— corrections and updates fed back as new inputs"
)


def rounded_rect(draw, xy, radius, fill, outline=None, outline_width=3):
    x1, y1, x2, y2 = xy
    draw.rounded_rectangle([x1, y1, x2, y2], radius=radius, fill=fill,
                           outline=outline, width=outline_width)


def load_font(size, bold=False):
    candidates_bold = [
        "arialbd.ttf", "Arial Bold.ttf",
        "C:/Windows/Fonts/arialbd.ttf",
    ]
    candidates_regular = [
        "arial.ttf", "Arial.ttf",
        "C:/Windows/Fonts/arial.ttf",
    ]
    candidates = candidates_bold if bold else candidates_regular
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            pass
    return ImageFont.load_default()


def wrap_text(text, font, max_width, draw):
    """Wrap a single string into lines that fit max_width."""
    if not text.strip():
        return [""]
    words = text.split()
    lines = []
    current = ""
    for word in words:
        test = (current + " " + word).strip()
        w = draw.textlength(test, font=font)
        if w <= max_width:
            current = test
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines if lines else [""]


def draw_column(draw, x1, y1, x2, y2, header_color, header_text, items, img):
    header_h = 58
    # Header box
    rounded_rect(draw, (x1, y1, x2, y1 + header_h), CORNER_R,
                 fill=header_color, outline=header_color)

    # Body box (white/light)
    rounded_rect(draw, (x1, y1 + header_h - CORNER_R, x2, y2), CORNER_R,
                 fill=LIGHT, outline=(200, 200, 200), outline_width=2)

    # Draw header text
    hfont = load_font(28, bold=True)
    htxt_w = draw.textlength(header_text, font=hfont)
    hx = x1 + (x2 - x1 - htxt_w) / 2
    hy = y1 + (header_h - 30) / 2
    draw.text((hx, hy), header_text, font=hfont, fill=WHITE)

    # Draw items
    ifont = load_font(20)
    pad_x = 22
    line_h = 24
    ty = y1 + header_h + 16
    max_w = (x2 - x1) - pad_x * 2
    for item in items:
        if item == "":
            ty += 8
            continue
        lines = wrap_text(item, ifont, max_w, draw)
        for ln in lines:
            if ty + line_h > y2 - 10:
                break
            draw.text((x1 + pad_x, ty), ln, font=ifont, fill=DARK)
            ty += line_h


def draw_arrow(draw, x1, y, x2):
    """Draw a right-pointing solid arrow."""
    ah = 16   # arrowhead height (half)
    aw = 20   # arrowhead depth
    # Shaft
    shaft_y = y
    draw.rectangle([x1, shaft_y - 5, x2 - aw, shaft_y + 5], fill=ARROW_CLR)
    # Arrowhead
    draw.polygon([
        (x2 - aw, shaft_y - ah),
        (x2,      shaft_y),
        (x2 - aw, shaft_y + ah),
    ], fill=ARROW_CLR)


def draw_feedback(draw, lx, rx, top_y, bottom_y, text, font):
    """Draw a dashed feedback arc (rectangle) below the three columns."""
    fy = bottom_y + 28
    dash_len = 14
    gap_len = 8

    def dashed_hline(x1, x2, y, color):
        x = x1
        on = True
        while x < x2:
            xend = min(x + (dash_len if on else gap_len), x2)
            if on:
                draw.line([(x, y), (xend, y)], fill=color, width=2)
            x = xend
            on = not on

    def dashed_vline(x, y1, y2, color):
        y = y1
        on = True
        while y < y2:
            yend = min(y + (dash_len if on else gap_len), y2)
            if on:
                draw.line([(x, y), (x, yend)], fill=color, width=2)
            y = yend
            on = not on

    bx1, bx2 = lx + 10, rx - 10
    by1, by2 = top_y, fy + 26

    # Bottom horizontal dashed line
    dashed_hline(bx1 + 20, bx2 - 20, by2, FEEDBACK_CLR)
    # Left vertical dashed line
    dashed_vline(bx1, by1, by2, FEEDBACK_CLR)
    # Right vertical dashed line (right side closed)
    dashed_vline(bx2, by1, by2, FEEDBACK_CLR)

    # Arrowhead pointing up-left (at top-left, going back to INPUT)
    draw.polygon([
        (bx1 - 10, by1),
        (bx1 + 10, by1),
        (bx1,      by1 - 14),
    ], fill=FEEDBACK_CLR)

    # Feedback label
    ffont = load_font(18)
    tw = draw.textlength(text, font=ffont)
    tx = bx1 + (bx2 - bx1 - tw) / 2
    ty = by2 + 6
    draw.text((tx, ty), text, font=ffont, fill=FEEDBACK_CLR)


def main():
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)

    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)

    # Layout
    col_y1 = MARGIN_Y
    col_y2 = H - 130   # leave room for feedback

    usable_w = W - 2 * MARGIN_X - 2 * ARROW_W
    col_w = usable_w // 3

    col1_x1 = MARGIN_X
    col1_x2 = col1_x1 + col_w

    arrow1_x1 = col1_x2
    arrow1_x2 = col1_x2 + ARROW_W

    col2_x1 = arrow1_x2
    col2_x2 = col2_x1 + col_w

    arrow2_x1 = col2_x2
    arrow2_x2 = col2_x2 + ARROW_W

    col3_x1 = arrow2_x2
    col3_x2 = W - MARGIN_X

    mid_y = (col_y1 + col_y2) // 2

    # Draw columns
    draw_column(draw, col1_x1, col_y1, col1_x2, col_y2,
                GOLD, INPUT_HEADER, INPUT_ITEMS, img)
    draw_column(draw, col2_x1, col_y1, col2_x2, col_y2,
                DBLUE, PROCESS_HEADER, PROCESS_ITEMS, img)
    draw_column(draw, col3_x1, col_y1, col3_x2, col_y2,
                PURPLE, OUTPUT_HEADER, OUTPUT_ITEMS, img)

    # Draw arrows
    draw_arrow(draw, arrow1_x1 + 4, mid_y, arrow1_x2 - 4)
    draw_arrow(draw, arrow2_x1 + 4, mid_y, arrow2_x2 - 4)

    # Draw feedback loop
    draw_feedback(draw, col1_x1, col3_x2, col_y1 + 28, col_y2,
                  FEEDBACK_TEXT, load_font(18))

    img.save(OUTPUT_PATH, "PNG", dpi=(150, 150))
    print(f"Figure 2 IPO diagram saved to: {OUTPUT_PATH}")
    print(f"File size: {os.path.getsize(OUTPUT_PATH):,} bytes")


if __name__ == "__main__":
    main()

