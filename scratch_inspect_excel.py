import zipfile
import xml.etree.ElementTree as ET
import os

filename = "TEMPLATE-SSHS-E-Class-Record-SY-2026-2027.xlsx"
out_filename = "detailed_output_utf8.txt"

try:
    with open(out_filename, "w", encoding="utf-8") as out:
        out.write("--- EXCEL DEEP INSPECTION ---\n")
        with zipfile.ZipFile(filename, 'r') as z:
            # 1. Read shared strings
            strings = []
            if 'xl/sharedStrings.xml' in z.namelist():
                ss_xml = z.read('xl/sharedStrings.xml')
                ss_root = ET.fromstring(ss_xml)
                for elem in ss_root.iter():
                    if elem.tag.endswith('t') and elem.text:
                        strings.append(elem.text)
            out.write(f"Total Shared Strings: {len(strings)}\n")
            out.write("Sample Strings (First 150):\n")
            for i, s in enumerate(strings[:150]):
                # Remove newlines for cleaner output
                clean_s = s.replace('\n', ' ').replace('\r', '')
                out.write(f"  [{i}] {clean_s}\n")

            # 2. Check Sheet relationship mapping (sheet1.xml -> Sheet Name)
            sheet_map = {}
            if 'xl/workbook.xml' in z.namelist():
                wb_xml = z.read('xl/workbook.xml')
                wb_root = ET.fromstring(wb_xml)
                for elem in wb_root.iter():
                    if elem.tag.endswith('sheet'):
                        name = elem.attrib.get('name')
                        sheet_id = elem.attrib.get('sheetId')
                        rel_id = elem.attrib.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id')
                        out.write(f"Sheet Name: {name}, SheetId: {sheet_id}, RelId: {rel_id}\n")

            # 3. Data Validations in detail
            out.write("\n--- DATA VALIDATIONS BY SHEET ---\n")
            for item in sorted(z.namelist()):
                if item.startswith('xl/worksheets/sheet') and item.endswith('.xml'):
                    sheet_xml = z.read(item)
                    root = ET.fromstring(sheet_xml)
                    validations = []
                    for elem in root.iter():
                        if elem.tag.endswith('dataValidation'):
                            sqref = elem.attrib.get('sqref', '')
                            dv_type = elem.attrib.get('type', '')
                            formula1 = ""
                            formula2 = ""
                            for child in elem:
                                if child.tag.endswith('formula1'):
                                    formula1 = child.text
                                elif child.tag.endswith('formula2'):
                                    formula2 = child.text
                            validations.append(f"Type: {dv_type}, SqRef: {sqref}, F1: {formula1}, F2: {formula2}")
                    if validations:
                        out.write(f"\n{item}:\n")
                        for v in validations:
                            out.write(f"  - {v}\n")

    print(f"Successfully generated {out_filename}")

except Exception as e:
    print(f"Error: {e}")
