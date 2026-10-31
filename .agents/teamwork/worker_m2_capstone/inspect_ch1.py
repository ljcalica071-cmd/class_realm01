from docx import Document

doc = Document(r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED_SENIOR_HIGH_SCHOOL_ATTENDANCE_CH1_CH2_CH3.docx")

with open(r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_m2_capstone\ch1_paragraphs.txt", "w", encoding="utf-8") as f:
    for idx, p in enumerate(doc.paragraphs):
        txt = p.text.strip()
        if "CHAPTER II" in txt:
            break
        f.write(f"[{idx}] (style={p.style.name if p.style else 'None'}) ({len(txt.split())} words) {txt}\n")

print("Done extracting Chapter 1")
