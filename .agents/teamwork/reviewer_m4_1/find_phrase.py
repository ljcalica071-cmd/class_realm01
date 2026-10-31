import docx

doc = docx.Document(r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED_SENIOR_HIGH_SCHOOL_ATTENDANCE_CH1_CH2_CH3.docx")

bad = "landmark local philippine empirical investigation"
for i, p in enumerate(doc.paragraphs):
    if bad in p.text.lower():
        print(f"FOUND in Paragraph {i}:")
        print(f"Text: {p.text}")
