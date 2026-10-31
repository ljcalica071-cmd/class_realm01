from docx import Document
from docx.shared import Inches, Pt
from docx.oxml.ns import qn

doc = Document(r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED_SENIOR_HIGH_SCHOOL_ATTENDANCE_CH1_CH2_CH3.docx")

# Measure Chapter 1 paragraphs
ch1_paras = []
in_ch1 = False
for idx, p in enumerate(doc.paragraphs):
    txt = p.text.strip()
    if idx <= 27: # Title page & front matter
        ch1_paras.append((idx, p, "Title Page"))
    elif "CHAPTER I" in txt:
        in_ch1 = True
        ch1_paras.append((idx, p, "Chapter 1"))
    elif "CHAPTER II" in txt:
        break
    elif in_ch1:
        ch1_paras.append((idx, p, "Chapter 1"))

print(f"Total paragraphs in Title Page + Chapter 1: {len(ch1_paras)}")

# Simulate line count for each paragraph
# Page capacity:
# Page height = 11 inches = 792 pt
# Top margin = 1.6 in = 115.2 pt
# Bottom margin = 1.2 in = 86.4 pt
# Printable height = 792 - 115.2 - 86.4 = 590.4 pt
# Page width = 8.5 in = 612 pt
# Left margin = 1.6 in = 115.2 pt
# Right margin = 1.4 in = 100.8 pt
# Printable width = 612 - 115.2 - 100.8 = 396 pt (5.5 in)

# With Arial 12pt, line height at 1.5 line spacing: 18 pt per line.
# Printable height 590.4 pt / 18 pt = 32.8 lines per page (~32 lines).
# Average chars per line at 396 pt width with Arial 12pt:
# In Arial 12pt, average character width is ~6.2 pt.
# 396 pt / 6.2 pt = ~64 characters per line.
# With first-line indent of 0.5 in (36 pt), the first line has 360 pt / 6.2 pt = ~58 chars.

def estimate_lines(p):
    txt = p.text.strip()
    if not txt:
        # check if it's an empty paragraph / spacing
        return 1
    # Check if heading
    if txt.startswith("CHAPTER") or txt in ["INTRODUCTION", "1.1 Project Context", "1.2 Purpose and Description", "1.3 Objectives of the Study", "1.3.1 General Objective", "1.3.2 Specific Objectives", "1.4 Scope and Limitations of the Study", "1.4.1 Scope of the Study", "1.4.2 Boundaries and Limitations", "1.5 Quantifiable SMART Evaluation Criteria", "1.6 Definition of Terms"]:
        return 2 # Heading line + space
    # Body text:
    char_count = len(txt)
    # First line has ~58 chars, subsequent lines have ~64 chars
    if char_count <= 58:
        return 1
    rem = char_count - 58
    return 1 + (rem + 63) // 64

lines_title_page = 0
for idx, p, sec in ch1_paras:
    if sec == "Title Page":
        lines_title_page += estimate_lines(p)

print(f"Title page estimated lines: {lines_title_page} (Fixed to exactly 1 page via page break)")

lines_ch1 = 0
current_section = "Start"
section_lines = {}
section_words = {}

for idx, p, sec in ch1_paras:
    if sec == "Chapter 1":
        txt = p.text.strip()
        if txt.startswith("1.") or txt.startswith("CHAPTER"):
            current_section = txt
            section_lines[current_section] = 0
            section_words[current_section] = 0
        l = estimate_lines(p)
        w = len(txt.split())
        lines_ch1 += l
        section_lines[current_section] = section_lines.get(current_section, 0) + l
        section_words[current_section] = section_words.get(current_section, 0) + w

print(f"\nTotal estimated lines in Chapter 1: {lines_ch1}")
print(f"Estimated pages for Chapter 1 (at 32 lines/page): {lines_ch1 / 32:.2f} pages")
print(f"Total pages from Title Page to end of Ch1: 1 (Title) + {lines_ch1 / 32:.2f} = {1 + lines_ch1 / 32:.2f} pages")

print("\n--- SECTION BREAKDOWN ---")
for s, l in section_lines.items():
    pages = l / 32
    words = section_words.get(s, 0)
    print(f"{s[:40]:<40} | Lines: {l:>3} | Words: {words:>4} | Est Pages: {pages:.2f}")
