import zipfile
import xml.etree.ElementTree as ET

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def check_spacing(path, name):
    print(f"=== {name} ===")
    with zipfile.ZipFile(path, 'r') as z:
        root = ET.fromstring(z.read('word/document.xml'))
        for p in root.findall('.//w:p', NS)[:20]:
            txt = "".join(p.itertext()).strip()
            if not txt:
                continue
            pPr = p.find('w:pPr', NS)
            sp = None
            ind = None
            if pPr is not None:
                sp_el = pPr.find('w:spacing', NS)
                if sp_el is not None:
                    sp = {k: sp_el.attrib.get(f"{{{NS['w']}}}{k}") for k in ['before', 'after', 'line', 'lineRule'] if f"{{{NS['w']}}}{k}" in sp_el.attrib}
                ind_el = pPr.find('w:ind', NS)
                if ind_el is not None:
                    ind = {k: ind_el.attrib.get(f"{{{NS['w']}}}{k}") for k in ['left', 'right', 'firstLine', 'hanging'] if f"{{{NS['w']}}}{k}" in ind_el.attrib}
            print(f"[{txt[:30]}] spacing={sp} ind={ind}")

check_spacing(r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx", "Target")
check_spacing(r"c:\Users\Admin\Downloads\Acitivity#3_Chapter2.docx", "Sample Ch2")
