import zipfile
import xml.etree.ElementTree as ET

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def inspect_tables(path):
    with zipfile.ZipFile(path, 'r') as z:
        root = ET.fromstring(z.read('word/document.xml'))
        tables = root.findall('.//w:tbl', NS)
        print(f"Total tables: {len(tables)}")
        for i, tbl in enumerate(tables, 1):
            tblPr = tbl.find('w:tblPr', NS)
            tblBorders = tblPr.find('w:tblBorders', NS) if tblPr is not None else None
            borders_info = {}
            if tblBorders is not None:
                for b_tag in ['top', 'left', 'bottom', 'right', 'insideH', 'insideV']:
                    b_el = tblBorders.find(f'w:{b_tag}', NS)
                    if b_el is not None:
                        borders_info[b_tag] = {k: b_el.attrib.get(f"{{{NS['w']}}}{k}") for k in ['val', 'sz', 'space', 'color']}
            print(f"Table {i} borders: {borders_info}")
            
            # Check rows
            rows = tbl.findall('w:tr', NS)
            print(f"Table {i} rows: {len(rows)}")
            if rows:
                header_tr = rows[0]
                trPr = header_tr.find('w:trPr', NS)
                is_tblHeader = trPr.find('w:tblHeader', NS) is not None if trPr is not None else False
                cells = header_tr.findall('w:tc', NS)
                header_texts = ["".join(c.itertext()).strip() for c in cells]
                print(f"Table {i} header row (repeat={is_tblHeader}): {header_texts}")

inspect_tables(r"c:\Users\Admin\Downloads\Acitivity#3_Chapter2.docx")
