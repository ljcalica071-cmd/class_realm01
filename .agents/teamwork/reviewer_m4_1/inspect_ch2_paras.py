import docx
import sys

sys.stdout.reconfigure(encoding='utf-8', errors='backslashreplace', line_buffering=True)
doc = docx.Document(r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED_SENIOR_HIGH_SCHOOL_ATTENDANCE_CH1_CH2_CH3.docx")

print("=== INSPECTING ALL PARAGRAPHS IN CHAPTER 2 (P101 to P171) ===")
for i in range(101, 172):
    p = doc.paragraphs[i]
    txt = p.text.strip()
    if txt:
        print(f"--- P{i} (len={len(txt)}) ---")
        print(txt[:150] + ("..." if len(txt) > 150 else ""))
