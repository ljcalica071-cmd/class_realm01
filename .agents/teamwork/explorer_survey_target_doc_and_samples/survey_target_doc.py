import os
import sys
import zipfile
import xml.etree.ElementTree as ET
import json

output_file = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_survey_target_doc_and_samples\target_doc_summary.json"
target_docx = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx"

print(f"Target Doc exists: {os.path.exists(target_docx)}", flush=True)
print(f"Target Doc size: {os.path.getsize(target_docx)} bytes", flush=True)

NS = {
    'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
}

summary = {
    "files": [],
    "styles": {},
    "margins": [],
    "paragraphs": [],
    "tables_count": 0
}

with zipfile.ZipFile(target_docx, 'r') as z:
    summary["files"] = z.namelist()
    print(f"Zip files count: {len(summary['files'])}", flush=True)
    
    # Read styles
    if 'word/styles.xml' in summary["files"]:
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
            summary["styles"][sid] = {"name": sname, "font": font, "size_pt": sz}
    print(f"Styles extracted: {len(summary['styles'])}", flush=True)
    
    # Read document
    if 'word/document.xml' in summary["files"]:
        doc_root = ET.fromstring(z.read('word/document.xml'))
        body = doc_root.find('w:body', NS)
        
        # Margins & Section properties
        for sect in doc_root.findall('.//w:sectPr', NS):
            pgMar = sect.find('w:pgMar', NS)
            pgSz = sect.find('w:pgSz', NS)
            m_info = {}
            if pgMar is not None:
                m_info["margins_in"] = {
                    k: round(int(pgMar.attrib.get(f"{{{NS['w']}}}{k}", 0))/1440.0, 3)
                    for k in ['top', 'right', 'bottom', 'left', 'header', 'footer']
                }
            if pgSz is not None:
                m_info["page_size_in"] = {
                    'w': round(int(pgSz.attrib.get(f"{{{NS['w']}}}w", 0))/1440.0, 3),
                    'h': round(int(pgSz.attrib.get(f"{{{NS['w']}}}h", 0))/1440.0, 3),
                    'orient': pgSz.attrib.get(f"{{{NS['w']}}}orient", "portrait")
                }
            summary["margins"].append(m_info)
        
        # Paragraphs and tables
        p_index = 0
        for child in body:
            tag = child.tag.split('}')[-1]
            if tag == 'p':
                text = "".join(child.itertext()).strip()
                pPr = child.find('w:pPr', NS)
                pStyle = "Normal"
                jc = None
                spacing = {}
                ind = {}
                if pPr is not None:
                    pStyle_el = pPr.find('w:pStyle', NS)
                    if pStyle_el is not None:
                        pStyle = pStyle_el.attrib.get(f"{{{NS['w']}}}val")
                    jc_el = pPr.find('w:jc', NS)
                    if jc_el is not None:
                        jc = jc_el.attrib.get(f"{{{NS['w']}}}val")
                    sp_el = pPr.find('w:spacing', NS)
                    if sp_el is not None:
                        spacing = {k: sp_el.attrib.get(f"{{{NS['w']}}}{k}") for k in ['before', 'after', 'line', 'lineRule'] if f"{{{NS['w']}}}{k}" in sp_el.attrib}
                    ind_el = pPr.find('w:ind', NS)
                    if ind_el is not None:
                        ind = {k: ind_el.attrib.get(f"{{{NS['w']}}}{k}") for k in ['left', 'right', 'firstLine', 'hanging'] if f"{{{NS['w']}}}{k}" in ind_el.attrib}
                
                # Runs details
                runs = []
                for r in child.findall('w:r', NS):
                    r_text = "".join(r.itertext())
                    if not r_text:
                        continue
                    rPr = r.find('w:rPr', NS)
                    f_name = None
                    f_sz = None
                    b = False
                    i = False
                    if rPr is not None:
                        rf = rPr.find('w:rFonts', NS)
                        if rf is not None:
                            f_name = rf.attrib.get(f"{{{NS['w']}}}ascii")
                        sze = rPr.find('w:sz', NS)
                        if sze is not None:
                            f_sz = int(sze.attrib.get(f"{{{NS['w']}}}val")) / 2.0
                        b = rPr.find('w:b', NS) is not None
                        i = rPr.find('w:i', NS) is not None
                    runs.append({"t": r_text[:60], "f": f_name, "sz": f_sz, "b": b, "i": i})
                
                # Check for page break
                has_page_break = child.find('.//w:br[@w:type="page"]', NS) is not None
                
                summary["paragraphs"].append({
                    "p_idx": p_index,
                    "style": pStyle,
                    "jc": jc,
                    "spacing": spacing,
                    "ind": ind,
                    "page_break": has_page_break,
                    "text": text,
                    "runs": runs[:3]
                })
                p_index += 1
            elif tag == 'tbl':
                summary["tables_count"] += 1
                rows = child.findall('w:tr', NS)
                headers = []
                if rows:
                    cells = rows[0].findall('w:tc', NS)
                    headers = ["".join(c.itertext()).strip() for c in cells]
                summary["paragraphs"].append({
                    "p_idx": p_index,
                    "type": "table",
                    "rows": len(rows),
                    "headers": headers
                })
                p_index += 1

print(f"Total paragraphs/elements: {len(summary['paragraphs'])}", flush=True)

with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(summary, f, indent=2)

print("Saved target_doc_summary.json successfully!", flush=True)
