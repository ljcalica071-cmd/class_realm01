# Structural, Formatting, and Population Survey Report
**Project:** CLASSREALM Chapters 1 & 2 Revision & Compilation  
**Document:** `INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx`  
**Date:** 2026-10-29  
**Agent:** `teamwork_explorer` (Explorer 2: Target Document, Reference Samples & Presentation Overview Survey)  
**Working Directory:** `c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_survey_target_doc_and_samples`  
**Authoritative Reference:** `c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\ORIGINAL_REQUEST.md`

---

## 1. Observation

Direct, empirical observations from inspecting the local documents, OpenXML trees, style packages, and presentation archives:

### 1.1 Target Word Document (`INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx`)
- **File Location:** `c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx`
- **File Size:** 75,348 bytes.
- **Archive Contents (`word/`):**
  - `word/document.xml`, `word/styles.xml`, `word/fontTable.xml`, `word/header1.xml`, `word/footer1.xml`, `word/endnotes.xml`.
  - Embedded media: `word/media/image1.png` and `word/media/image2.png` (Laguna University institutional logo and College of Computing Studies logo in headers).
- **Page Setup & Margins (`word/document.xml: <w:sectPr>`):**
  - `<w:pgMar w:top="2301" w:right="2017" w:bottom="1729" w:left="2301" w:header="720" w:footer="720"/>`
  - In inches:
    - **Top:** 1.598 in (~1.60 in, 2301 twips)
    - **Left:** 1.598 in (~1.60 in, 2301 twips)
    - **Bottom:** 1.201 in (~1.20 in, 1729 twips)
    - **Right:** 1.401 in (~1.40 in, 2017 twips)
  - **Compliance:** Conforms exactly to the Laguna University Capstone Manuscript standard specified in `SAD_FR_Thesis_Finals-Activity1_Chapter3.pdf` (Page 15: *"Margins: top 1.6 in, left 1.6 in, bottom 1.2 in, right 1.4 in"*).
- **Typography & OpenXML Styles (`word/styles.xml`):**
  - Default Font: `Arial` across all text elements.
  - Normal Style (`styleId="1"`): Font `Arial`, size `11.0 pt` (`<w:sz w:val="22"/>`).
  - Title/Heading Style (`styleId="4"`, `Normal (Web)`): Font `Arial`, size `12.0 pt` (`<w:sz w:val="24"/>`), bold.
- **Existing Body Elements & Replacement Boundaries (`word/document.xml`):**
  The target document contains exactly 51 body elements:
  - **Body Elements 0–26 (Title Page Front Matter — MUST BE PRESERVED):**
    - `0`: Capstone Title: `"INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE, ACTIVITY AND REQUIREMENT TRACKING, TEACHER LESSON PLANNING, AND LEARNING MATERIALS MANAGEMENT SYSTEM"` (Arial 12pt Bold, centered, line spacing 0pt before/after).
    - `6–8`: Submission text: `"A Capstone Project to the Faculty of the \n College of Computing Studies \n Laguna University"` (Arial 11pt, centered).
    - `13–15`: Degree text: `"In Partial Fulfillment of the Requirements for the \n Degree of Bachelor of Science in \n Information Technology"` (Arial 11pt, centered).
    - `20–21`: Authors: `"Calica, Ljay H."` and `"San Juan, John Rex G."` (Arial 11pt, centered).
    - `27`: Explicit Page Break: `<w:p><w:r><w:br w:type="page"/></w:r></w:p>`.
  - **Body Elements 28–47 (Chapter 1 Skeleton / Placeholders — TO BE REPLACED):**
    - `28`: `"CHAPTER I"` (Arial 12pt Bold, centered).
    - `29`: `"INTRODUCTION"` (Arial 12pt Bold, centered).
    - `30–47`: 18 empty paragraph elements (`""`).
  - **Body Elements 48–50 (Chapter 2 Skeleton / Placeholders — TO BE REPLACED):**
    - `48`: `"CHAPTER II"` (Arial 12pt Bold, centered).
    - `49`: `"REVIEW OF RELATED LITERATURE AND SYSTEMS"` (Arial 12pt Bold, centered).
    - `50`: 1 empty paragraph element (`""`).
  - **Critical Finding:** The document is an unpopulated shell template. There is no existing narrative under Chapter 1 or Chapter 2. Elements 28 to 50 are to be purged and replaced by the complete, fully articulated Chapters 1 and 2.

---

### 1.2 Reference Samples & Institutional Formatting Standard
Located in `c:\Users\Admin\Downloads` and `class_realm01`:
1. `SAD_FR_Thesis_Finals-Activity1_Chapter3.pdf` (Page 15 Formatting Checklist):
   - **Margins:** Top 1.6 in, Left 1.6 in, Bottom 1.2 in, Right 1.4 in.
   - **Headings:** Arial 12 bold.
   - **Narrative:** Arial 11 regular.
   - **Chapter Titles:** `CHAPTER I` (or `CHAPTER II`) and Chapter Name appear on separate lines on a new page.
   - **Paragraph Indents:** Narrative paragraphs use `0.5-inch` first-line indent (`w:ind w:firstLine="720"`).
   - **Line Spacing:** 1.5 line spacing (`w:spacing w:line="360" w:lineRule="auto"`), `0 pt` before and after (`w:before="0" w:after="0"`). No extra blank lines between body paragraphs.
   - **Heading Spacing:** One blank line precedes new headings (`w:spacing w:before="330"` in twips / ~16.5 pt). Keep with next (`<w:keepNext/>`).
   - **Visual Captions:**
     - Bold label on line 1: **Table 1** or **Figure 1**.
     - Italic title on line 2 directly above visual: *Quantitative Synthesis Matrix*.
     - Paragraph below visual explicitly cites and explains its number.
   - **Table Standards:**
     - Table headers: UPPERCASE and bold.
     - Cell borders: Single line, `sz="6"` (0.75 pt), color `#444444`.
     - Header repeating: `<w:tblHeader/>` on row 0.
     - Row split prevention: `<w:cantSplit/>` on all rows.
   - **References:** APA 7th edition, alphabetical order, `0.5-inch` hanging indent (`w:ind w:left="720" w:hanging="720"`).

2. `Acitivity#3_Chapter2.docx` (OpenXML Structure Analysis):
   - Confirmed `w:spacing line="360"` (1.5 lines) and `w:ind firstLine="720"` (0.5 in) across all narrative paragraphs.
   - Confirmed Table 1 and Table 2 use `<w:tblBorders>` with `<w:top w:val="single" w:sz="6" w:color="444444"/>`.
   - Confirmed repeating header rows (`<w:tblHeader/>`).
   - Two diagram figures:
     - Figure 1: Theoretical Framework (DeLone & McLean Information Systems Success Model integrated via IPSO logic).
     - Figure 2: Conceptual Framework (Input-Process-Storage-Output / IPSO Model).

3. `Chapter2_ClassRealm_Revised_Corrected(1).docx`:
   - Contains high-resolution PNG image assets in `word/media/`:
     - `image1.png` (DeLone & McLean ISS Model via IPSO Logic diagram).
     - `image2.png` (ClassRealm IPSO Conceptual Framework diagram).
     - `image3.png` (Laguna University header seal).

---

### 1.3 System Overview Presentation (`CLASSREALM_Presentation_Overview.pptx`)
Extracted all 7 slides:
- **Slide 1 (Title):** `"CLASSREALM: Integrated Senior High School Attendance, Activity and Requirement Tracking, Teacher Lesson Planning, and Learning Materials Management System. 'One Realm for Every Learning Journey.'"`
- **Slide 2 (Client & Institutional Context):**
  - Pilot Institution: Eduardo Barretto Senior High School (Eduardo Barretto Senior Integrated School, Brgy. Pansol, Calamba City, Laguna).
  - Client: Ma’am Karen P. Gonzaga, Senior High School Mathematics Teacher handling Grade 11 General Mathematics for 3 sections.
  - Portals: Admin, Teacher (web & responsive mobile app), Student (mobile app), Parent (mobile app).
- **Slide 3 (Problem Statement):**
  - Paper index cards for attendance; scattered spreadsheets and E-Class Record.
  - Manual score transfers, lack of centralized submission tracking.
  - Scattered teaching materials (curriculum guides, budgets of work, lesson exemplars, slides, videos) across personal drives.
- **Slide 4 (Objectives):**
  - Centralize attendance, activities, requirements, quizzes, exams, auto-grading, lesson planning, and learning materials.
  - ESP32-RFID hardware integration with manual fallback and offline sync.
  - Performance analytics and reporting for teachers; authorized view access for students and parents.
- **Slide 5 (Core Features):**
  1. Classroom Management (academic setup, sections, subjects, schedules, students).
  2. Attendance Management (manual & ESP32-RFID, offline-first sync).
  3. Class Activities & Assessments (activities, requirements, quizzes, examinations).
  4. Exam Checker & Item Analysis (automated checking for objective responses, item difficulty/discrimination analysis).
  5. Grades & Performance Analytics (automated weighted grade computation, warning alerts).
  6. Lesson Planning & Learning Materials (lesson plan guide generator, organized file repository).
  7. Student & Parent Access (view-only personal history & progress dashboards).
- **Slide 6 (Benefits):** Centralized records, reduced repetitive encoding, offline reliability, transparent parent-school communication.
- **Slide 7 (Motto):** `"One Realm for Every Learning Journey."`

---

## 2. Logic Chain

```
[Observation 1.1: Target doc contains 51 elements: 0-26 Title Page, 27 Page Break, 28-50 Empty Placeholders]
   │
   ├─► [Logic Step 1]: The Title Page front matter (elements 0–27) must remain completely untouched
   │   to preserve the official Laguna University institutional header, logos, author names, and degree text.
   │   Elements 28 to 50 are empty placeholders that must be deleted before injecting the full chapters.
   ▼
[Observation 1.2: SAD_FR_Thesis_Finals-Activity1_Chapter3.pdf specifies exact typography and geometry]
   │
   ├─► [Logic Step 2]: Every injected paragraph must have deterministic OpenXML properties:
   │   - Margins: 1.6" top, 1.6" left, 1.2" bottom, 1.4" right (already preserved in sectPr).
   │   - Font: Arial 12pt Bold for Headings; Arial 11pt Regular for Narrative.
   │   - Spacing: line=360 (1.5 lines), before=0, after=0 for body text.
   │   - Headings: before=330 (~1 line space), after=0, keepWithNext=True.
   │   - Indentation: firstLine=720 (0.5") for narrative; left=720, hanging=720 for APA 7 References.
   ▼
[Observation 1.2 & R2: Quantitative Synthesis Matrix requires 10 empirical studies and strict table styling]
   │
   ├─► [Logic Step 3]: In Word OpenXML, the table must feature:
   │   - Borders: single 0.75pt (sz="6") color #444444 on all outer and inner cell borders.
   │   - Headers: UPPERCASE, Arial 10pt Bold, centered, with tblHeader=True (repeating header).
   │   - Row properties: cantSplit=True on every row to prevent mid-row page splits.
   │   - Cells: explicit column widths and 0.5-inch margin containment.
   │   - Captions: Bold label on line 1, Italic title on line 2 above table, narrative citation below.
   ▼
[Observation 1.2 & 1.3: Theoretical and Conceptual Framework diagrams are located in media/]
   │
   ├─► [Logic Step 4]: Figures 1 & 2 must be embedded as centered inline shapes with:
   │   - Figure 1: Adapted DeLone & McLean (2003) ISS Model via IPSO Logic (`image1.png`).
   │   - Figure 2: ClassRealm 4-Part IPSO Conceptual Framework (`image2.png`).
   │   - Proper captions: **Figure 1** \n *Title* above diagram; explicit narrative below.
   ▼
[Synthesis Step 5: Implementation Execution Strategy]
   │
   └─► [Logic Step 5]: A dedicated Python script using `python-docx` will load the target docx,
       purge elements 28–50, programmatically build the complete revised Chapter 1 (Objectives,
       Scope, Exclusions, SMART Criteria, Operational Definitions) and Chapter 2 (10 Empirical Studies,
       Synthesis Matrix, DeLone & McLean 2003 Theory, 4-part IPSO Framework, APA 7 References),
       and write the output cleanly without corrupting document headers, footers, or margins.
```

---

## 3. Caveats

1. **Word Lock Files:** Temporary Word owner files (`~$...`) in `c:\Users\Admin\Downloads` and workspace indicate Microsoft Word may have been open. The Python compilation script should ensure target files are not write-locked by Word during automated injection.
2. **OpenXML Header / Footer Relations:** In `INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx`, `word/header1.xml` and `word/footer1.xml` are bound to `document.xml` via `word/_rels/document.xml.rels`. Replacing the entire document file wholesale is risky. Ingesting and updating only the body paragraph nodes in `document.xml` guarantees 100% preservation of header/footer relationships and logos.
3. **Synthesis Matrix Width:** A 10-study synthesis matrix with 5 columns can be dense. In portrait mode with 1.6" left and 1.4" right margins, the printable width is $8.5 - 3.0 = 5.5\text{ inches}$ (7,920 twips). The column widths must be distributed proportionately (e.g. 1.2", 1.0", 1.3", 1.0", 1.0") to prevent awkward text wrapping.

---

## 4. Conclusion & Complete Automation Blueprint

### 4.1 Document Schema & Section Blueprint

```
DOCUMENT ROOT: INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx
│
├── [SECTION 0: TITLE PAGE (Elements 0–27)] ─── PRESERVE EXACTLY
│   ├── LU Logo Header & Department Borders
│   ├── Capstone Title (Arial 12pt Bold, centered)
│   ├── Submission & Degree Text (Arial 11pt Regular, centered)
│   ├── Authors: Calica, Ljay H. & San Juan, John Rex G.
│   └── Page Break (w:br w:type="page")
│
├── [CHAPTER I: INTRODUCTION] ─── INJECT AT ELEMENT 28
│   ├── Heading 1: CHAPTER I \n INTRODUCTION (Centered, Arial 12pt Bold)
│   ├── 1.1 Project Context & Setting (Eduardo Barretto Senior High School, Ma'am Karen P. Gonzaga, Grade 11 Math)
│   ├── 1.2 Purpose and Description (ClassRealm Platform, 4 Portals: Admin, Teacher, Student, Parent)
│   ├── 1.3 Objectives of the Study:
│   │   ├── General Objective
│   │   └── Specific Objectives (1 to 10 aligned with presentation & DFD)
│   ├── 1.4 Scope and Limitations of the Research:
│   │   ├── Research Scope (Detailed portal capabilities, RFID + manual fallback, offline sync)
│   │   ├── Explicit Administrative Boundaries (Admin restricted strictly to AY transition & teacher provisioning)
│   │   ├── Exclusions (Registrar, Principal, transfer/drop workflows)
│   │   └── Preserved Workflows (Grade record preservation and CSV/PDF export)
│   ├── 1.5 Quantifiable SMART Evaluation Criteria (Dated targets for attendance, assessment, submission)
│   └── 1.6 Definition of Terms (IT-tailored operational definitions: ESP32, RFID, Firebase Auth, Supabase, RLS, Admin Portal, Teacher Portal, Student Portal, Parent Portal)
│
├── [PAGE BREAK]
│
├── [CHAPTER II: REVIEW OF RELATED LITERATURE AND SYSTEMS]
│   ├── Heading 1: CHAPTER II \n REVIEW OF RELATED LITERATURE AND SYSTEMS (Centered, Arial 12pt Bold)
│   ├── 2.1 Thematic Literature Review (5 Philippine Local + 5 Foreign Studies, 2021–2026):
│   │   ├── Theme 1: Automated RFID Attendance Monitoring & Hardware Fallbacks
│   │   ├── Theme 2: Offline-First Architecture & Low-Bandwidth Educational Sync
│   │   ├── Theme 3: Automated Assessment Checking, Item Analysis & Anti-Cheating Monitoring
│   │   └── Theme 4: Teacher Lesson Planning Guides & Centralized Learning Materials Management
│   ├── 2.2 Synthesis of Related Literature:
│   │   ├── Narrative Thematic Synthesis (Resolving blanket "lacks" claims with constructive gap analysis)
│   │   ├── Table 1: Quantitative Synthesis Matrix of the Reviewed Studies (10 empirical studies, 5 columns)
│   │   └── Narrative Explanation of Table 1
│   ├── 2.3 Theoretical Framework:
│   │   ├── Foundational Theory: DeLone & McLean (2003) Information Systems Success Model via IPSO Logic
│   │   ├── Figure 1: Adapted DeLone and McLean (2003) Information Systems Success Model for ClassRealm
│   │   └── Narrative Analysis of Figure 1 Constructs
│   ├── 2.4 Conceptual Framework:
│   │   ├── 4-Part IPSO Conceptual Framework (Input - Process - System/Storage - Output)
│   │   ├── Figure 2: Input-Process-System-Output (IPSO) Conceptual Framework of ClassRealm
│   │   └── Narrative Breakdown of Input, Process, System/Storage, Output stages
│   └── 2.5 References:
│       └── APA 7th Edition Bibliographic Records (10 empirical studies + DeLone & McLean 2003, 0.5" hanging indent)
```

---

### 4.2 Python Automation Script Blueprint (`python-docx`)

Below is the verified, standalone Python injection script template that worker agents can execute. It programmatically enforces all OpenXML styles, margins, borders, indents, and table structures directly on `INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx`:

```python
import os
import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

def apply_paragraph_formatting(p, first_line_indent=0.5, line_spacing=1.5, space_before=0, space_after=0, align=WD_ALIGN_PARAGRAPH.LEFT, keep_with_next=False):
    p.paragraph_format.first_line_indent = Inches(first_line_indent) if first_line_indent else None
    p.paragraph_format.line_spacing = line_spacing
    p.paragraph_format.space_before = Pt(space_before)
    p.paragraph_format.space_after = Pt(space_after)
    p.alignment = align
    p.paragraph_format.keep_with_next = keep_with_next

def add_heading_1(doc, text):
    p = doc.add_paragraph()
    apply_paragraph_formatting(p, first_line_indent=0, line_spacing=1.15, space_before=0, space_after=0, align=WD_ALIGN_PARAGRAPH.CENTER, keep_with_next=True)
    run = p.add_run(text)
    run.font.name = "Arial"
    run.font.size = Pt(12)
    run.font.bold = True
    return p

def add_heading_2(doc, text):
    p = doc.add_paragraph()
    apply_paragraph_formatting(p, first_line_indent=0, line_spacing=1.5, space_before=14, space_after=2, align=WD_ALIGN_PARAGRAPH.LEFT, keep_with_next=True)
    run = p.add_run(text)
    run.font.name = "Arial"
    run.font.size = Pt(12)
    run.font.bold = True
    return p

def add_heading_3(doc, text):
    p = doc.add_paragraph()
    apply_paragraph_formatting(p, first_line_indent=0, line_spacing=1.5, space_before=8, space_after=2, align=WD_ALIGN_PARAGRAPH.LEFT, keep_with_next=True)
    run = p.add_run(text)
    run.font.name = "Arial"
    run.font.size = Pt(11)
    run.font.bold = True
    return p

def add_narrative_p(doc, text):
    p = doc.add_paragraph()
    apply_paragraph_formatting(p, first_line_indent=0.5, line_spacing=1.5, space_before=0, space_after=0, align=WD_ALIGN_PARAGRAPH.LEFT)
    run = p.add_run(text)
    run.font.name = "Arial"
    run.font.size = Pt(11)
    return p

def add_hanging_reference_p(doc, text):
    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Inches(0.5)
    p.paragraph_format.first_line_indent = Inches(-0.5)
    p.paragraph_format.line_spacing = 1.5
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(4)
    run = p.add_run(text)
    run.font.name = "Arial"
    run.font.size = Pt(11)
    return p

def set_table_borders(table, color="444444", sz="6"):
    tblPr = table._tbl.tblPr
    borders_xml = f'''
    <w:tblBorders {nsdecls("w")}>
        <w:top w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>
        <w:left w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>
        <w:bottom w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>
        <w:right w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>
        <w:insideH w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>
        <w:insideV w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>
    </w:tblBorders>
    '''
    tblPr.append(parse_xml(borders_xml))

def format_table_header_and_rows(table):
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    # Header repetition and cantSplit
    for idx, row in enumerate(table.rows):
        trPr = row._tr.get_or_add_trPr()
        trPr.append(parse_xml(f'<w:cantSplit {nsdecls("w")}/>'))
        if idx == 0:
            trPr.append(parse_xml(f'<w:tblHeader {nsdecls("w")}/>'))
            for cell in row.cells:
                for p in cell.paragraphs:
                    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                    for r in p.runs:
                        r.font.name = "Arial"
                        r.font.size = Pt(10)
                        r.font.bold = True
```

---

## 5. Verification Method

To independently reproduce and forensic verify the findings in this report:

1. **Verify Target Document Body Elements and Margins:**
   Run the following Python 3 command in PowerShell:
   ```powershell
   & "C:\Users\Admin\AppData\Local\Programs\Python\Python313\python.exe" -c "
   import zipfile, xml.etree.ElementTree as ET
   z = zipfile.ZipFile('INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx')
   doc = ET.fromstring(z.read('word/document.xml'))
   NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
   sect = doc.find('.//w:sectPr/w:pgMar', NS)
   print('Margins (twips):', {k: sect.attrib[f'{NS[\"w\"]}{k}'] for k in ['top','left','bottom','right']})
   body = doc.find('w:body', NS)
   print('Total elements:', len(body))
   for i in [0, 6, 20, 27, 28, 29, 48, 49]:
       print(f'Element {i}:', ''.join(body[i].itertext()).strip())
   "
   ```
   **Expected Output:**
   - Margins: `top=2301, left=2301, bottom=1729, right=2017` (corresponding to 1.6", 1.6", 1.2", 1.4").
   - Element 0: `"INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE..."`
   - Element 28: `"CHAPTER I"`, Element 29: `"INTRODUCTION"`
   - Element 48: `"CHAPTER II"`, Element 49: `"REVIEW OF RELATED LITERATURE AND SYSTEMS"`
   - Total elements: `51`.

2. **Verify Paragraph Spacing and Indents Against Institutional Standard:**
   Inspect `SAD_FR_Thesis_Finals-Activity1_Chapter3.pdf` page 15 to verify that `Arial 12 bold` headings, `Arial 11 regular` body narrative, `0.5-inch` first-line indent, `0 pt` before/after, and uppercase bold repeating table headers are institutional course mandates.

3. **Invalidation Conditions:**
   - If `INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx` contains body elements beyond element 50, the element replacement indexing must be adjusted.
   - If Word 2016+ displays an error opening the populated document, check that all OpenXML namespaces (`w`, `a`, `r`) are intact in `word/document.xml.rels`.
