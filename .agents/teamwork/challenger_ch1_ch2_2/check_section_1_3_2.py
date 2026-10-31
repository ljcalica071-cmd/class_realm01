"""
check_section_1_3_2.py
Verify exact count of items in Section 1.3.2 (Specific Objectives).
"""

import docx
import re

DOCX_PATH = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx"

doc = docx.Document(DOCX_PATH)
in_1_3_2 = False
items = []

for p in doc.paragraphs:
    t = p.text.strip()
    if "1.3.2 Specific Objectives" in t:
        in_1_3_2 = True
        continue
    if in_1_3_2 and ("1.4 Scope" in t or "Scope and Delimitation" in t or "1.4" in t):
        in_1_3_2 = False
        break
    if in_1_3_2:
        m = re.match(r'^(10|[1-9])\.\s+(.*?):', t)
        if m:
            items.append((m.group(1), m.group(2), t))

print(f"Total numbered specific objectives in 1.3.2: {len(items)}")
for num, title, full in items:
    print(f"  [{num}] {title}")
