import os
import zipfile
import xml.etree.ElementTree as ET
import json

target_docx = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx"
work_dir = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_survey_target_doc_and_samples"

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

paragraphs = []
tables = []

with zipfile.ZipFile(target_docx, 'r') as z:
    doc_root = ET.fromstring(z.read('word/document.xml'))
    body = doc_root.find('w:body', NS)
    
    for idx, child in enumerate(body):
        tag = child.tag.split('}')[-1]
        if tag == 'p':
            txt = "".join(child.itertext()).strip()
            pPr = child.find('w:pPr', NS)
            pStyle = "Normal"
            jc = None
            ind = None
            if pPr is not None:
                pStyle_el = pPr.find('w:pStyle', NS)
                if pStyle_el is not None:
                    pStyle = pStyle_el.attrib.get(f"{{{NS['w']}}}val")
                jc_el = pPr.find('w:jc', NS)
                if jc_el is not None:
                    jc = jc_el.attrib.get(f"{{{NS['w']}}}val")
                ind_el = pPr.find('w:ind', NS)
                if ind_el is not None:
                    ind = {k: ind_el.attrib.get(f"{{{NS['w']}}}{k}") for k in ['left', 'right', 'firstLine', 'hanging'] if f"{{{NS['w']}}}{k}" in ind_el.attrib}
            
            has_br = child.find('.//w:br[@w:type="page"]', NS) is not None
            
            paragraphs.append({
                "body_idx": idx,
                "type": "p",
                "style": pStyle,
                "jc": jc,
                "ind": ind,
                "page_break": has_br,
                "text": txt
            })
        elif tag == 'tbl':
            rows = child.findall('w:tr', NS)
            tbl_info = {"body_idx": idx, "type": "tbl", "rows": len(rows), "headers": []}
            if rows:
                cells = rows[0].findall('w:tc', NS)
                tbl_info["headers"] = ["".join(c.itertext()).strip() for c in cells]
            paragraphs.append(tbl_info)

with open(os.path.join(work_dir, "target_doc_full_structure.json"), "w", encoding="utf-8") as f:
    json.dump(paragraphs, f, indent=2)

print(f"Total body elements: {len(paragraphs)}")
