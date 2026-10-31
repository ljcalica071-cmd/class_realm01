import zipfile
import xml.etree.ElementTree as ET

TARGET_DOCX = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx"
with zipfile.ZipFile(TARGET_DOCX, 'r') as zf:
    doc_xml = zf.read('word/document.xml')
tree = ET.fromstring(doc_xml)
body = tree.find('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}body')
elem27 = list(body)[27]
print("Element 27 XML:")
print(ET.tostring(elem27, encoding='utf-8').decode('utf-8'))
