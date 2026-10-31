import zipfile
import xml.etree.ElementTree as ET

TARGET_DOCX = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx"
with zipfile.ZipFile(TARGET_DOCX, 'r') as zf:
    styles_xml = zf.read('word/styles.xml')
    
tree = ET.fromstring(styles_xml)
W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
NS = {'w': W_NS}

# Check docDefaults
docDefaults = tree.find('.//w:docDefaults', NS)
if docDefaults is not None:
    rFonts = docDefaults.find('.//w:rFonts', NS)
    if rFonts is not None:
        print("docDefaults rFonts:", rFonts.attrib)

# Check Normal style
for s in tree.findall('.//w:style', NS):
    if s.get(f'{{{W_NS}}}styleId') == 'Normal':
        rFonts = s.find('.//w:rFonts', NS)
        if rFonts is not None:
            print("Normal style rFonts:", rFonts.attrib)
        else:
            print("Normal style has no explicit rFonts")
