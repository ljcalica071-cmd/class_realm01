import docx
from docx.shared import Inches, Pt

doc = docx.Document(r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx")

ch1_paras = []
in_ch1 = False
for p in doc.paragraphs:
    t = p.text.strip()
    if t == "CHAPTER I":
        in_ch1 = True
    elif t == "CHAPTER II":
        in_ch1 = False
        break
    if in_ch1 and t:
        ch1_paras.append(p)

print(f"Total Chapter 1 paragraphs to check: {len(ch1_paras)}")

font_names = set()
font_sizes = set()

for p in ch1_paras:
    for r in p.runs:
        if r.font.name:
            font_names.add(r.font.name)
        if r.font.size:
            font_sizes.add(r.font.size.pt)

print(f"Font names in Chapter 1: {font_names}")
print(f"Font sizes in Chapter 1: {font_sizes}")
