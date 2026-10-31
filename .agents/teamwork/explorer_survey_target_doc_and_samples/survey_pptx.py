import os
import sys
import zipfile
import xml.etree.ElementTree as ET
import json

output_file = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_survey_target_doc_and_samples\pptx_summary.json"
overview_pptx = r"c:\Users\Admin\Downloads\CLASSREALM_Presentation_Overview.pptx"

print(f"PPTX exists: {os.path.exists(overview_pptx)}", flush=True)
if not os.path.exists(overview_pptx):
    sys.exit(1)

NS = {
    'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
    'p': 'http://schemas.openxmlformats.org/presentationml/2006/main',
    'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
}

slides_data = []

with zipfile.ZipFile(overview_pptx, 'r') as z:
    file_list = z.namelist()
    slide_files = sorted([f for f in file_list if f.startswith('ppt/slides/slide') and f.endswith('.xml')],
                         key=lambda x: int(''.join(filter(str.isdigit, x)) or 0))
    print(f"Found {len(slide_files)} slides.", flush=True)
    
    for idx, sf in enumerate(slide_files, start=1):
        s_xml = z.read(sf)
        root = ET.fromstring(s_xml)
        
        slide_info = {
            "slide_num": idx,
            "file": sf,
            "shapes": [],
            "tables": []
        }
        
        # Text shapes
        for sp in root.findall('.//p:sp', NS):
            txBody = sp.find('p:txBody', NS)
            if txBody is not None:
                paragraphs = []
                for p in txBody.findall('a:p', NS):
                    p_txt = "".join(p.itertext()).strip()
                    if p_txt:
                        paragraphs.append(p_txt)
                if paragraphs:
                    slide_info["shapes"].append(paragraphs)
        
        # Tables
        for tbl in root.findall('.//a:tbl', NS):
            tbl_rows = []
            for tr in tbl.findall('a:tr', NS):
                row_cells = []
                for tc in tr.findall('a:tc', NS):
                    c_txt = "".join(tc.itertext()).strip()
                    row_cells.append(c_txt)
                if row_cells:
                    tbl_rows.append(row_cells)
            if tbl_rows:
                slide_info["tables"].append(tbl_rows)
        
        slides_data.append(slide_info)

with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(slides_data, f, indent=2)

print(f"Saved {len(slides_data)} slides to pptx_summary.json successfully!", flush=True)
