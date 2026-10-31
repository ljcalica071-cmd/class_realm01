import os
import sys
import zipfile
import xml.etree.ElementTree as ET
import json

output_dir = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_survey_target_doc_and_samples"

target_docx = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx"
sample_ch1 = r"c:\Users\Admin\Downloads\Activity#1_Chapter1.docx"
sample_ch2 = r"c:\Users\Admin\Downloads\Acitivity#3_Chapter2.docx"
overview_pptx = r"c:\Users\Admin\Downloads\CLASSREALM_Presentation_Overview.pptx"

NS = {
    'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
    'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
    'p': 'http://schemas.openxmlformats.org/presentationml/2006/main'
}

def analyze_docx(path, name):
    print(f"Analyzing DOCX: {name} ({path})")
    if not os.path.exists(path):
        return {"error": f"File not found: {path}"}
    
    res = {
        "filename": os.path.basename(path),
        "size": os.path.getsize(path),
        "paragraphs": [],
        "styles": {},
        "sections": [],
        "tables": []
    }
    
    with zipfile.ZipFile(path, 'r') as z:
        file_list = z.namelist()
        res["files"] = [f for f in file_list if f.startswith('word/')]
        
        # Styles
        if 'word/styles.xml' in file_list:
            styles_xml = z.read('word/styles.xml')
            root = ET.fromstring(styles_xml)
            for style in root.findall('w:style', NS):
                s_id = style.attrib.get(f"{{{NS['w']}}}styleId")
                s_type = style.attrib.get(f"{{{NS['w']}}}type")
                name_el = style.find('w:name', NS)
                s_name = name_el.attrib.get(f"{{{NS['w']}}}val") if name_el is not None else s_id
                
                # Check font & size in style
                rPr = style.find('w:rPr', NS)
                font_name = None
                font_size = None
                if rPr is not None:
                    rFonts = rPr.find('w:rFonts', NS)
                    if rFonts is not None:
                        font_name = rFonts.attrib.get(f"{{{NS['w']}}}ascii")
                    sz = rPr.find('w:sz', NS)
                    if sz is not None:
                        font_size = int(sz.attrib.get(f"{{{NS['w']}}}val")) / 2.0
                
                res["styles"][s_id] = {
                    "name": s_name,
                    "type": s_type,
                    "font": font_name,
                    "size_pt": font_size
                }
        
        # Document body
        if 'word/document.xml' in file_list:
            doc_xml = z.read('word/document.xml')
            root = ET.fromstring(doc_xml)
            body = root.find('w:body', NS)
            
            # Sections / Margins
            for sectPr in root.findall('.//w:sectPr', NS):
                pgMar = sectPr.find('w:pgMar', NS)
                pgSz = sectPr.find('w:pgSz', NS)
                sect_info = {}
                if pgMar is not None:
                    sect_info["margins_twips"] = {
                        k: pgMar.attrib.get(f"{{{NS['w']}}}{k}")
                        for k in ['top', 'right', 'bottom', 'left', 'header', 'footer']
                        if f"{{{NS['w']}}}{k}" in pgMar.attrib
                    }
                    sect_info["margins_in"] = {
                        k: round(int(v)/1440.0, 3) for k, v in sect_info["margins_twips"].items()
                    }
                if pgSz is not None:
                    sect_info["page_size_twips"] = {
                        'w': pgSz.attrib.get(f"{{{NS['w']}}}w"),
                        'h': pgSz.attrib.get(f"{{{NS['w']}}}h"),
                        'orient': pgSz.attrib.get(f"{{{NS['w']}}}orient", "portrait")
                    }
                    sect_info["page_size_in"] = {
                        'w': round(int(sect_info["page_size_twips"]['w'])/1440.0, 3),
                        'h': round(int(sect_info["page_size_twips"]['h'])/1440.0, 3),
                        'orient': sect_info["page_size_twips"]['orient']
                    }
                res["sections"].append(sect_info)
            
            # Iterate through children of body
            for idx, child in enumerate(body):
                tag = child.tag.split('}')[-1]
                if tag == 'p':
                    # Paragraph
                    p_text = "".join(child.itertext()).strip()
                    pPr = child.find('w:pPr', NS)
                    p_style = "Normal"
                    jc = None
                    ind = {}
                    spacing = {}
                    runs_info = []
                    
                    if pPr is not None:
                        pStyle_el = pPr.find('w:pStyle', NS)
                        if pStyle_el is not None:
                            p_style = pStyle_el.attrib.get(f"{{{NS['w']}}}val")
                        jc_el = pPr.find('w:jc', NS)
                        if jc_el is not None:
                            jc = jc_el.attrib.get(f"{{{NS['w']}}}val")
                        ind_el = pPr.find('w:ind', NS)
                        if ind_el is not None:
                            ind = {k: ind_el.attrib.get(f"{{{NS['w']}}}{k}") for k in ['left', 'right', 'firstLine', 'hanging'] if f"{{{NS['w']}}}{k}" in ind_el.attrib}
                        sp_el = pPr.find('w:spacing', NS)
                        if sp_el is not None:
                            spacing = {k: sp_el.attrib.get(f"{{{NS['w']}}}{k}") for k in ['before', 'after', 'line', 'lineRule'] if f"{{{NS['w']}}}{k}" in sp_el.attrib}
                    
                    # Inspect runs
                    for run in child.findall('w:r', NS):
                        r_text = "".join(run.itertext())
                        rPr = run.find('w:rPr', NS)
                        font = None
                        size = None
                        bold = False
                        italic = False
                        if rPr is not None:
                            rFonts = rPr.find('w:rFonts', NS)
                            if rFonts is not None:
                                font = rFonts.attrib.get(f"{{{NS['w']}}}ascii")
                            sz = rPr.find('w:sz', NS)
                            if sz is not None:
                                size = int(sz.attrib.get(f"{{{NS['w']}}}val")) / 2.0
                            if rPr.find('w:b', NS) is not None:
                                bold = True
                            if rPr.find('w:i', NS) is not None:
                                italic = True
                        if r_text:
                            runs_info.append({
                                "text": r_text[:40] if len(r_text) > 40 else r_text,
                                "font": font,
                                "size": size,
                                "b": bold,
                                "i": italic
                            })
                    
                    if p_text or runs_info or p_style != "Normal":
                        res["paragraphs"].append({
                            "idx": idx,
                            "style": p_style,
                            "jc": jc,
                            "indent": ind,
                            "spacing": spacing,
                            "text": p_text,
                            "run_sample": runs_info[:2]
                        })
                elif tag == 'tbl':
                    # Table
                    rows = child.findall('w:tr', NS)
                    tbl_info = {"rows": len(rows), "cols": 0, "sample_headers": []}
                    if rows:
                        first_cells = rows[0].findall('w:tc', NS)
                        tbl_info["cols"] = len(first_cells)
                        tbl_info["sample_headers"] = ["".join(c.itertext()).strip() for c in first_cells]
                    res["tables"].append(tbl_info)
                    res["paragraphs"].append({
                        "idx": idx,
                        "type": "table",
                        "rows": tbl_info["rows"],
                        "cols": tbl_info["cols"],
                        "headers": tbl_info["sample_headers"]
                    })
    return res

def analyze_pptx(path):
    print(f"Analyzing PPTX: {path}")
    if not os.path.exists(path):
        return {"error": f"File not found: {path}"}
    
    res = {"filename": os.path.basename(path), "slides": []}
    with zipfile.ZipFile(path, 'r') as z:
        file_list = z.namelist()
        slide_files = sorted([f for f in file_list if f.startswith('ppt/slides/slide') and f.endswith('.xml')],
                             key=lambda x: int(''.join(filter(str.isdigit, x)) or 0))
        
        for sf in slide_files:
            s_xml = z.read(sf)
            root = ET.fromstring(s_xml)
            slide_texts = []
            for sp in root.findall('.//p:sp', NS):
                txBody = sp.find('p:txBody', NS)
                if txBody is not None:
                    txt = "".join(txBody.itertext()).strip()
                    if txt:
                        slide_texts.append(txt)
            res["slides"].append({
                "file": sf,
                "texts": slide_texts
            })
    return res

print("Starting analysis...")
target_data = analyze_docx(target_docx, "target_doc")
sample1_data = analyze_docx(sample_ch1, "sample_ch1")
sample2_data = analyze_docx(sample_ch2, "sample_ch2")
pptx_data = analyze_pptx(overview_pptx)

with open(os.path.join(output_dir, "target_doc_analysis.json"), "w", encoding="utf-8") as f:
    json.dump(target_data, f, indent=2)

with open(os.path.join(output_dir, "sample_ch1_analysis.json"), "w", encoding="utf-8") as f:
    json.dump(sample1_data, f, indent=2)

with open(os.path.join(output_dir, "sample_ch2_analysis.json"), "w", encoding="utf-8") as f:
    json.dump(sample2_data, f, indent=2)

with open(os.path.join(output_dir, "pptx_analysis.json"), "w", encoding="utf-8") as f:
    json.dump(pptx_data, f, indent=2)

print("Analysis written successfully.")
