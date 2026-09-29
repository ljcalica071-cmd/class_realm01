import zipfile
import xml.etree.ElementTree as ET
import sys

filename = "TEMPLATE-SSHS-E-Class-Record-SY-2026-2027.xlsx"

print("Trying to open Excel as ZIP archive...")
try:
    with zipfile.ZipFile(filename, 'r') as z:
        print("Successfully opened ZIP.")
        print("Sheets found:")
        
        # Parse workbook.xml to get sheet names
        if 'xl/workbook.xml' in z.namelist():
            wb_xml = z.read('xl/workbook.xml')
            root = ET.fromstring(wb_xml)
            # Find all sheet elements
            for elem in root.iter():
                if 'sheet' in elem.tag:
                    name = elem.attrib.get('name')
                    print(f" - {name}")
        
        print("\nChecking for Data Validations (Dropdowns) in sheets...")
        for name in z.namelist():
            if name.startswith('xl/worksheets/sheet') and name.endswith('.xml'):
                sheet_xml = z.read(name)
                if b'dataValidation' in sheet_xml:
                    print(f"Found data validation rules in {name}")
                    
except Exception as e:
    print(f"Error reading {filename}: {e}")
