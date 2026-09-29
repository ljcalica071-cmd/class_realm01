import zipfile
import xml.etree.ElementTree as ET

filename = "TEMPLATE-SSHS-E-Class-Record-SY-2026-2027.xlsx"
out_filename = "java_info.txt"

with zipfile.ZipFile(filename, 'r') as z:
    strings = []
    if 'xl/sharedStrings.xml' in z.namelist():
        root = ET.fromstring(z.read('xl/sharedStrings.xml'))
        for elem in root.iter():
            if elem.tag.endswith('t') and elem.text is not None:
                strings.append(elem.text)
                
    with open(out_filename, "w", encoding="utf-8") as out:
        out.write("=== SEARCH IN SHARED STRINGS ===\n")
        for i, s in enumerate(strings):
            if any(k in s.lower() for k in ['java', 'programming', 'tech-pro', 'techpro', 'ict']):
                out.write(f"[{i}] {s}\n")
                
        out.write("\n=== DUMPING ROWS IN HELPER (sheet7.xml) WITH 'Programming' OR 'Java' ===\n")
        # In sheet7.xml, let's look through all rows
        if 'xl/worksheets/sheet7.xml' in z.namelist():
            s_root = ET.fromstring(z.read('xl/worksheets/sheet7.xml'))
            for row in s_root.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}row'):
                row_cells = {}
                row_has_target = False
                for cell in row.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}c'):
                    val_elem = cell.find('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}v')
                    val = val_elem.text if val_elem is not None else ""
                    if cell.attrib.get('t') == 's' and val.isdigit():
                        val = strings[int(val)]
                    col_ref = cell.attrib.get('r', '')
                    row_cells[col_ref] = val
                    if any(k in val.lower() for k in ['java', 'programming', 'techpro', 'tech-pro']):
                        row_has_target = True
                if row_has_target:
                    r_num = row.attrib.get('r')
                    out.write(f"Row {r_num}: " + " | ".join(f"{k}: {v}" for k, v in row_cells.items()) + "\n")

print("Generated java_info.txt")
