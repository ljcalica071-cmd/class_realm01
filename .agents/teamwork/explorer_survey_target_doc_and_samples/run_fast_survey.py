import os
import sys
import zipfile
import xml.etree.ElementTree as ET
import json

base_dir = r"c:\Users\Admin\AndroidStudioProjects\class_realm01"
work_dir = os.path.join(base_dir, r".agents\teamwork\explorer_survey_target_doc_and_samples")
target_docx = os.path.join(base_dir, "INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx")
sample_ch1 = r"c:\Users\Admin\Downloads\Activity#1_Chapter1.docx"
sample_ch2 = r"c:\Users\Admin\Downloads\Acitivity#3_Chapter2.docx"
overview_pptx = r"c:\Users\Admin\Downloads\CLASSREALM_Presentation_Overview.pptx"

NS = {
    'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
    'p': 'http://schemas.openxmlformats.org/presentationml/2006/main'
}

results = {}

# 1. Target DOCX
print("Inspecting Target Docx...", flush=True)
if os.path.exists(target_docx):
    with zipfile.ZipFile(target_docx, 'r') as z:
        files = z.namelist()
        results["target_docx"] = {
            "size": os.path.getsize(target_docx),
            "files": files[:15],
            "styles": {},
            "margins": [],
            "paragraphs": []
        }
        if 'word/styles.xml' in files:
            s_root = ET.fromstring(z.read('word/styles.xml'))
            for s in s_root.findall('w:style', NS):
                sid = s.attrib.get(f"{{{NS['w']}}}styleId")
                name_el = s.find('w:name', NS)
                sname = name_el.attrib.get(f"{{{NS['w']}}}val") if name_el is not None else sid
                rPr = s.find('w:rPr', NS)
                font = None
                sz = None
                if rPr is not None:
                    rf = rPr.find('w:rFonts', NS)
                    if rf is not None:
                        font = rf.attrib.get(f"{{{NS['w']}}}ascii")
                    sze = rPr.find('w:sz', NS)
                    if sze is not None:
                        sz = int(sze.attrib.get(f"{{{NS['w']}}}val")) / 2.0
                results["target_docx"]["styles"][sid] = {"name": sname, "font": font, "size": sz}
        
        if 'word/document.xml' in files:
            doc_root = ET.fromstring(z.read('word/document.xml'))
            # margins
            for sect in doc_root.findall('.//w:sectPr', NS):
                pgMar = sect.find('w:pgMar', NS)
                if pgMar is not None:
                    m = {k: round(int(pgMar.attrib.get(f"{{{NS['w']}}}{k}", 0))/1440.0, 3) for k in ['top', 'left', 'bottom', 'right']}
                    results["target_docx"]["margins"].append(m)
            
            body = doc_root.find('w:body', NS)
            p_idx = 0
            for el in body:
                tag = el.tag.split('}')[-1]
                if tag == 'p':
                    txt = "".join(el.itertext()).strip()
                    pPr = el.find('w:pPr', NS)
                    pStyle = "Normal"
                    if pPr is not None:
                        pStyle_el = pPr.find('w:pStyle', NS)
                        if pStyle_el is not None:
                            pStyle = pStyle_el.attrib.get(f"{{{NS['w']}}}val")
                    # runs font
                    r_font = None
                    r_sz = None
                    for r in el.findall('w:r', NS):
                        rPr = r.find('w:rPr', NS)
                        if rPr is not None:
                            rf = rPr.find('w:rFonts', NS)
                            if rf is not None:
                                r_font = rf.attrib.get(f"{{{NS['w']}}}ascii")
                            sze = rPr.find('w:sz', NS)
                            if sze is not None:
                                r_sz = int(sze.attrib.get(f"{{{NS['w']}}}val")) / 2.0
                            break
                    if txt:
                        results["target_docx"]["paragraphs"].append({
                            "idx": p_idx,
                            "style": pStyle,
                            "font": r_font,
                            "size": r_sz,
                            "text": txt[:120]
                        })
                    p_idx += 1
                elif tag == 'tbl':
                    results["target_docx"]["paragraphs"].append({
                        "idx": p_idx,
                        "type": "table",
                        "text": "[TABLE]"
                    })
                    p_idx += 1

# 2. PPTX
print("Inspecting PPTX...", flush=True)
if os.path.exists(overview_pptx):
    with zipfile.ZipFile(overview_pptx, 'r') as z:
        results["pptx"] = []
        slide_files = sorted([f for f in z.namelist() if f.startswith('ppt/slides/slide') and f.endswith('.xml')],
                             key=lambda x: int(''.join(filter(str.isdigit, x)) or 0))
        for idx, sf in enumerate(slide_files, 1):
            root = ET.fromstring(z.read(sf))
            texts = ["".join(p.itertext()).strip() for p in root.findall('.//a:p', NS) if "".join(p.itertext()).strip()]
            results["pptx"].append({"slide": idx, "texts": texts})

# 3. Sample Ch1 & Ch2
print("Inspecting Sample Ch1 & Ch2...", flush=True)
for name, pth in [("sample_ch1", sample_ch1), ("sample_ch2", sample_ch2)]:
    if os.path.exists(pth):
        with zipfile.ZipFile(pth, 'r') as z:
            results[name] = {"paragraphs": []}
            if 'word/document.xml' in z.namelist():
                root = ET.fromstring(z.read('word/document.xml'))
                p_idx = 0
                for el in root.find('w:body', NS):
                    tag = el.tag.split('}')[-1]
                    if tag == 'p':
                        txt = "".join(el.itertext()).strip()
                        if txt:
                            results[name]["paragraphs"].append({"idx": p_idx, "text": txt[:100]})
                        p_idx += 1
                    elif tag == 'tbl':
                        results[name]["paragraphs"].append({"idx": p_idx, "text": "[TABLE]"})
                        p_idx += 1

out_json = os.path.join(work_dir, "survey_results.json")
with open(out_json, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2)

print(f"ALL DONE! Saved to {out_json}", flush=True)
