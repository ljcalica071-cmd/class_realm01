from docx import Document

doc = Document(r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED_SENIOR_HIGH_SCHOOL_ATTENDANCE_CH1_CH2_CH3.docx")

for idx, p in enumerate(doc.paragraphs):
    txt = p.text.strip()
    if "CHAPTER" in txt:
        print(f"P{idx}: '{txt}'")
