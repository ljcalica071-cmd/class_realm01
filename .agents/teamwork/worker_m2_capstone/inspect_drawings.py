import zipfile
import xml.etree.ElementTree as ET

file_path = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED_SENIOR_HIGH_SCHOOL_ATTENDANCE_CH1_CH2_CH3.docx"

with zipfile.ZipFile(file_path, 'r') as z:
    doc_xml = z.read('word/document.xml')
    rels_xml = z.read('word/_rels/document.xml.rels')

rels_root = ET.fromstring(rels_xml)
r_to_target = {r.get('Id'): r.get('Target') for r in rels_root}

doc_root = ET.fromstring(doc_xml)
ns = {
    'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'wp': 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing',
    'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
    'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
}

for drawing in doc_root.findall('.//w:drawing', ns):
    extent = drawing.find('.//wp:extent', ns)
    blip = drawing.find('.//a:blip', ns)
    cx = extent.get('cx') if extent is not None else None
    cy = extent.get('cy') if extent is not None else None
    r_id = blip.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed') if blip is not None else None
    target = r_to_target.get(r_id, "Unknown")
    # EMUs to inches: 914400 EMUs = 1 inch
    cx_in = int(cx)/914400 if cx else 0
    cy_in = int(cy)/914400 if cy else 0
    print(f"Target: {target}, rId: {r_id}, cx: {cx} ({cx_in:.2f} in), cy: {cy} ({cy_in:.2f} in)")
