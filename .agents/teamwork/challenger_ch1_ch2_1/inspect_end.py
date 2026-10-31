from docx import Document

TARGET_DOCX = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx"
doc = Document(TARGET_DOCX)

print("=== INSPECTING PARAGRAPHS 135 to 170 ===")
for i in range(135, len(doc.paragraphs)):
    p = doc.paragraphs[i]
    txt = p.text.strip()
    pPr = p._element.pPr
    xml_snip = ""
    if pPr is not None:
        ind = pPr.find('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}ind')
        ind_str = f"left={ind.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}left')}, hanging={ind.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}hanging')}, firstLine={ind.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}firstLine')}" if ind is not None else "no ind"
        sp = pPr.find('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}spacing')
        sp_str = f"line={sp.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}line')}, before={sp.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}before')}, after={sp.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}after')}" if sp is not None else "no spacing"
        has_draw = '<w:drawing' in p._element.xml
    else:
        ind_str, sp_str, has_draw = "none", "none", False
        
    runs_info = []
    for r in p.runs:
        if r.text:
            runs_info.append(f"[{r.text[:20]}|b={r.bold}|i={r.italic}|f={r.font.name}|sz={r.font.size.pt if r.font.size else None}]")
    print(f"P{i:03d} | draw={has_draw} | {ind_str} | {sp_str} | runs={runs_info[:3]}")
    print(f"     text: '{txt[:100]}'")
