import docx
from docx.oxml.ns import qn
import xml.etree.ElementTree as ET
import zipfile

DOCX_PATH = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED_SENIOR_HIGH_SCHOOL_ATTENDANCE_CH1_CH2_CH3.docx"

doc = docx.Document(DOCX_PATH)

# Check lastRenderedPageBreak in document.xml
with zipfile.ZipFile(DOCX_PATH) as z:
    xml_content = z.read("word/document.xml")
    root = ET.fromstring(xml_content)

namespaces = {
    'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
}

rendered_breaks = root.findall('.//w:lastRenderedPageBreak', namespaces)
page_breaks = root.findall('.//w:br[@w:type="page"]', namespaces)
pageBreakBefore = root.findall('.//w:pageBreakBefore', namespaces)

print(f"w:lastRenderedPageBreak count: {len(rendered_breaks)}")
print(f"w:br[@w:type='page'] count: {len(page_breaks)}")
print(f"w:pageBreakBefore count: {len(pageBreakBefore)}")

# Let's inspect where these page breaks occur
print("\n--- DETAILED PARAGRAPH ANALYSIS FOR CH1 (p0 to p105) ---")
total_words_title = 0
total_words_ch1 = 0
total_chars_ch1 = 0

fonts = set()
sizes = set()
line_spacings = set()

for i, p in enumerate(doc.paragraphs[:105]):
    txt = p.text.strip()
    words = len(txt.split())
    chars = len(txt)
    
    # Check runs for font, size, line spacing
    pPr = p._p.find(qn('w:pPr'))
    spacing_val = None
    if pPr is not None:
        sp = pPr.find(qn('w:spacing'))
        if sp is not None:
            spacing_val = sp.attrib
    
    for r in p.runs:
        if r.font.name:
            fonts.add(r.font.name)
        if r.font.size:
            sizes.add(r.font.size.pt)
    
    # Check for breaks in this paragraph
    has_rendered = len(p._p.findall('.//' + qn('w:lastRenderedPageBreak'))) > 0
    has_page_br = any(br.get(qn('w:type')) == 'page' for br in p._p.findall('.//' + qn('w:br')))
    
    if i < 28:
        total_words_title += words
    elif 28 <= i <= 100:
        total_words_ch1 += words
        total_chars_ch1 += chars

    if txt:
        marker = ""
        if has_page_br: marker += " [PAGE_BR]"
        if has_rendered: marker += " [RENDERED_PAGE_BR]"
        print(f"P{i:03d} ({words:3d}w, {chars:4d}c){marker}: {txt[:70]}")
    else:
        marker = ""
        if has_page_br: marker += " [PAGE_BR]"
        if has_rendered: marker += " [RENDERED_PAGE_BR]"
        if marker:
            print(f"P{i:03d} (EMPTY){marker}")

print(f"\nTitle section words: {total_words_title}")
print(f"Chapter 1 words: {total_words_ch1}")
print(f"Chapter 1 chars: {total_chars_ch1}")
print(f"Total Title + Chapter 1 words: {total_words_title + total_words_ch1}")
print(f"Detected fonts: {fonts}")
print(f"Detected font sizes (pt): {sizes}")
