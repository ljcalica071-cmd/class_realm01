from docx import Document
import zipfile
import xml.etree.ElementTree as ET

TARGET_DOCX = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx"
BACKUP_DOCX = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_ch1_ch2_compiler\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.backup.docx"

doc = Document(TARGET_DOCX)
print(f"Total paragraphs: {len(doc.paragraphs)}")

print("\n--- Inspecting All Headings and Specific Paragraphs ---")
for idx, p in enumerate(doc.paragraphs):
    txt = p.text.strip()
    if not txt:
        continue
    # print if heading, figure, reference, or first few
    if any(k in txt.lower() for k in ['chapter', 'introduction', 'figure', 'table', 'reference', 'background', 'statement', 'objective', 'framework', 'synthesis', 'definition', 'scope']):
        print(f"P{idx:03d} (Style: {p.style.name}): '{txt[:80]}'")

print("\n--- Inspecting w:pgMar in TARGET vs BACKUP ---")
def inspect_pgmar(path, name):
    with zipfile.ZipFile(path, 'r') as zf:
        xml = zf.read('word/document.xml')
        tree = ET.fromstring(xml)
        for s in tree.iter('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}pgMar'):
            print(f"{name} pgMar attribs: {s.attrib}")

inspect_pgmar(TARGET_DOCX, "TARGET")
inspect_pgmar(BACKUP_DOCX, "BACKUP")
