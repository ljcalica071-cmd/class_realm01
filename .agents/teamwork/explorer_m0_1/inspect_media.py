import zipfile
import xml.etree.ElementTree as ET
from docx import Document

file_path = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED_SENIOR_HIGH_SCHOOL_ATTENDANCE_CH1_CH2_CH3.docx"

with zipfile.ZipFile(file_path, 'r') as z:
    media_files = [n for n in z.namelist() if n.startswith('word/media/')]
    print(f"Total media files in docx: {len(media_files)}")
    for m in media_files:
        info = z.getinfo(m)
        print(f"  {m} - {info.file_size} bytes")

doc = Document(file_path)
for p_idx, p in enumerate(doc.paragraphs):
    if 'graphic' in p._p.xml or 'drawing' in p._p.xml:
        txt = p.text.strip()
        print(f"Paragraph {p_idx} has drawing/graphic. Text around it: {txt[:60]}")
