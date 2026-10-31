from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import parse_xml

doc = Document()
table = doc.add_table(rows=3, cols=3)
table.alignment = WD_TABLE_ALIGNMENT.CENTER

def set_table_styling(table):
    tblPr = table._element.xpath('w:tblPr')
    if tblPr:
        borders = parse_xml('''
            <w:tblBorders xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                <w:top w:val="single" w:sz="6" w:space="0" w:color="555555"/>
                <w:left w:val="single" w:sz="6" w:space="0" w:color="555555"/>
                <w:bottom w:val="single" w:sz="6" w:space="0" w:color="555555"/>
                <w:right w:val="single" w:sz="6" w:space="0" w:color="555555"/>
                <w:insideH w:val="single" w:sz="6" w:space="0" w:color="555555"/>
                <w:insideV w:val="single" w:sz="6" w:space="0" w:color="555555"/>
            </w:tblBorders>
        ''')
        tblPr[0].append(borders)
    
    for i, row in enumerate(table.rows):
        trPr = row._element.get_or_add_trPr()
        trPr.append(parse_xml('<w:cantSplit xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"/>'))
        if i == 0:
            trPr.append(parse_xml('<w:tblHeader xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"/>'))
        for cell in row.cells:
            tcPr = cell._element.get_or_add_tcPr()
            if i == 0:
                tcPr.append(parse_xml('<w:shd xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" w:fill="F2F4F8"/>'))
            tcPr.append(parse_xml('''
                <w:tcMar xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                    <w:top w:w="120" w:type="dxa"/>
                    <w:bottom w:w="120" w:type="dxa"/>
                    <w:left w:w="160" w:type="dxa"/>
                    <w:right w:w="160" w:type="dxa"/>
                </w:tcMar>
            '''))

set_table_styling(table)
doc.save(r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_m3_activities\test_table.docx")
print("Table styling test OK!")
