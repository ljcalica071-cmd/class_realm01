import docx
import re
import json

doc_path = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx"
doc = docx.Document(doc_path)

ch1_paragraphs = []
in_ch1 = False

for i, p in enumerate(doc.paragraphs):
    text = p.text.strip()
    if text == "CHAPTER I":
        in_ch1 = True
    elif text == "CHAPTER II":
        in_ch1 = False
        break
    if in_ch1:
        ch1_paragraphs.append((i, text))

print(f"Extracted {len(ch1_paragraphs)} paragraphs from Chapter 1.")

with open(r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\reviewer_ch1_ch2_1\ch1_dump.txt", "w", encoding="utf-8") as f:
    for idx, text in ch1_paragraphs:
        f.write(f"[{idx}] {text}\n\n")

print("Saved ch1_dump.txt successfully.")
