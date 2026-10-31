import zipfile
import xml.etree.ElementTree as ET

file_path = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED_SENIOR_HIGH_SCHOOL_ATTENDANCE_CH1_CH2_CH3.docx"

with zipfile.ZipFile(file_path, 'r') as z:
    rels_xml = z.read('word/_rels/document.xml.rels')
    doc_xml = z.read('word/document.xml')
    
rels_root = ET.fromstring(rels_xml)
id_to_target = {}
for r in rels_root:
    id_to_target[r.get('Id')] = r.get('Target')

doc_root = ET.fromstring(doc_xml)
ns = {
    'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
    'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
}

with open(r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_m0_1\images_mapping.txt", "w", encoding="utf-8") as out:
    paras = doc_root.findall('.//w:p', ns)
    for p_idx, p in enumerate(paras):
        blips = p.findall('.//a:blip', ns)
        if blips:
            text = "".join(p.itertext()).strip()
            out.write(f"\nParagraph {p_idx} has {len(blips)} blip(s):\n")
            for b in blips:
                r_id = b.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed')
                target = id_to_target.get(r_id, "Unknown")
                out.write(f"  r:embed={r_id} -> {target}\n")
            # find surrounding text
            out.write(f"  Text: {text}\n")
            if p_idx > 0:
                prev_text = "".join(paras[p_idx-1].itertext()).strip()
                out.write(f"  Prev Paragraph: {prev_text}\n")
            if p_idx < len(paras) - 1:
                next_text = "".join(paras[p_idx+1].itertext()).strip()
                out.write(f"  Next Paragraph: {next_text}\n")

print("Done mapping images!")
