import os
import shutil
import zipfile
import xml.etree.ElementTree as ET
from docx import Document
from docx.shared import Inches, Pt
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

# Paths
SOURCE_DOCX = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED_SENIOR_HIGH_SCHOOL_ATTENDANCE_CH1_CH2_CH3.docx"
TEST_OUTPUT_DOCX = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_m2_capstone\test_output.docx"
DIAGRAMS_DIR = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\docs\diagrams"

def set_para_font_and_format(p, text, is_bold=False, is_italic=False, align=WD_ALIGN_PARAGRAPH.JUSTIFY, first_line_indent=0.5, line_spacing=1.5, space_before=0, space_after=0):
    p.text = ""
    run = p.add_run(text)
    run.font.name = "Arial"
    run.font.size = Pt(12)
    run.bold = is_bold
    run.italic = is_italic
    p.alignment = align
    pf = p.paragraph_format
    pf.line_spacing = line_spacing
    pf.first_line_indent = Inches(first_line_indent)
    pf.space_before = Pt(space_before)
    pf.space_after = Pt(space_after)
    
    # Ensure XML properties are strictly compliant
    pPr = p._p.get_or_add_pPr()
    # Spacing
    spacing = pPr.find(qn('w:spacing'))
    if spacing is None:
        spacing = OxmlElement('w:spacing')
        pPr.append(spacing)
    spacing.set(qn('w:line'), str(int(line_spacing * 240)))
    spacing.set(qn('w:lineRule'), 'auto')
    spacing.set(qn('w:before'), str(int(space_before * 20)))
    spacing.set(qn('w:after'), str(int(space_after * 20)))
    
    # Indent
    ind = pPr.find(qn('w:ind'))
    if ind is None:
        ind = OxmlElement('w:ind')
        pPr.append(ind)
    ind.set(qn('w:firstLine'), str(int(first_line_indent * 1440)))
    if first_line_indent == 0:
        if qn('w:firstLine') in ind.attrib:
            del ind.attrib[qn('w:firstLine')]

    # rFonts
    rPr = run._r.get_or_add_rPr()
    rFonts = rPr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = OxmlElement('w:rFonts')
        rPr.append(rFonts)
    rFonts.set(qn('w:ascii'), 'Arial')
    rFonts.set(qn('w:hAnsi'), 'Arial')
    rFonts.set(qn('w:cs'), 'Arial')

print("Defined helper formatting functions.")
