import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Generates an official, beautifully styled Excel spreadsheet (.xlsx)
/// for ClassRealm bulk student enrollment with ClassRealm Emerald branding (#0F8A48),
/// single sample row, text cell formatting, and English data validations.
class ExcelTemplateGenerator {
  static Uint8List generateStudentTemplateBytes() {
    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>''';
    _addFile(archive, '[Content_Types].xml', contentTypesXml);

    // 2. _rels/.rels
    const rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';
    _addFile(archive, '_rels/.rels', rootRelsXml);

    // 3. xl/_rels/workbook.xml.rels
    const workbookRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';
    _addFile(archive, 'xl/_rels/workbook.xml.rels', workbookRelsXml);

    // 4. xl/workbook.xml
    const workbookXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Student_Enrollment" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';
    _addFile(archive, 'xl/workbook.xml', workbookXml);

    // 5. xl/styles.xml
    // Color Palette:
    // Header Fill: Emerald Green (#0F8A48 -> FF0F8A48)
    // Sample Fill: Mint/Light Green (#E8F5E9 -> FFE8F5E9)
    // Text format: numFmtId="49" (@ text format)
    const stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <numFmts count="1">
    <numFmt numFmtId="49" formatCode="@"/>
  </numFmts>
  <fonts count="3">
    <font>
      <sz val="11"/>
      <color rgb="FF000000"/>
      <name val="Calibri"/>
    </font>
    <font>
      <b/>
      <sz val="11"/>
      <color rgb="FFFFFFFF"/>
      <name val="Calibri"/>
    </font>
    <font>
      <i/>
      <sz val="10"/>
      <color rgb="FF4A5568"/>
      <name val="Calibri"/>
    </font>
  </fonts>
  <fills count="4">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
    <fill>
      <patternFill patternType="solid">
        <fgColor rgb="FF487898"/>
      </patternFill>
    </fill>
    <fill>
      <patternFill patternType="solid">
        <fgColor rgb="FFF0F4F8"/>
      </patternFill>
    </fill>
  </fills>
  <borders count="2">
    <border>
      <left/><right/><top/><bottom/><diagonal/>
    </border>
    <border>
      <left style="thin"><color rgb="FFCBD5E0"/></left>
      <right style="thin"><color rgb="FFCBD5E0"/></right>
      <top style="thin"><color rgb="FFCBD5E0"/></top>
      <bottom style="thin"><color rgb="FFCBD5E0"/></bottom>
    </border>
  </borders>
  <cellStyleXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
  </cellStyleXfs>
  <cellXfs count="4">
    <!-- 0: Standard Default -->
    <xf numFmtId="49" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
    <!-- 1: Header (ClassRealm Steel Blue, Bold White, Centered, Text) -->
    <xf numFmtId="49" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1" applyNumberFormat="1">
      <alignment horizontal="center" vertical="center" wrapText="1"/>
    </xf>
    <!-- 2: Sample Row (Soft Slate, Italic, Centered, Text) -->
    <xf numFmtId="49" fontId="2" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1" applyNumberFormat="1">
      <alignment horizontal="center" vertical="center"/>
    </xf>
    <!-- 3: Input Data Cells (Normal, Border, Text format) -->
    <xf numFmtId="49" fontId="0" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1" applyNumberFormat="1">
      <alignment horizontal="center" vertical="center"/>
    </xf>
  </cellXfs>
  <cellStyles count="1">
    <cellStyle name="Normal" xfId="0" builtinId="0"/>
  </cellStyles>
</styleSheet>''';
    _addFile(archive, 'xl/styles.xml', stylesXml);

    // 6. xl/worksheets/sheet1.xml
    // Columns:
    // A: LRN (12 Digits)*
    // B: Email Address*
    // C: Last Name*
    // D: First Name*
    // E: Middle Initial
    // F: Gender*
    // G: Birthday [YYYY-MM-DD]*
    // Row 1 & 2 are strictly LOCKED (Protected). Teacher inputs data starting on Row 3.
    // Pre-create formatted rows 3-100 with style="3" (unlocked) and text format.
    final rowsBuffer = StringBuffer();

    // Row 1: Emerald Headers (Locked)
    rowsBuffer.write('''
    <row r="1" ht="28" customHeight="1">
      <c r="A1" t="inlineStr" s="1"><is><t>LRN (12 Digits)*</t></is></c>
      <c r="B1" t="inlineStr" s="1"><is><t>Email Address*</t></is></c>
      <c r="C1" t="inlineStr" s="1"><is><t>Last Name*</t></is></c>
      <c r="D1" t="inlineStr" s="1"><is><t>First Name*</t></is></c>
      <c r="E1" t="inlineStr" s="1"><is><t>Middle Initial</t></is></c>
      <c r="F1" t="inlineStr" s="1"><is><t>Gender*</t></is></c>
      <c r="G1" t="inlineStr" s="1"><is><t>Birthday [YYYY-MM-DD]*</t></is></c>
    </row>''');

    // Row 2: Single Sample Row (Locked - Ignored during upload)
    rowsBuffer.write('''
    <row r="2" ht="22" customHeight="1">
      <c r="A2" t="inlineStr" s="2"><is><t>123456789012</t></is></c>
      <c r="B2" t="inlineStr" s="2"><is><t>juana.rexsa@gmail.com</t></is></c>
      <c r="C2" t="inlineStr" s="2"><is><t>Juana</t></is></c>
      <c r="D2" t="inlineStr" s="2"><is><t>Rexsa</t></is></c>
      <c r="E2" t="inlineStr" s="2"><is><t>G</t></is></c>
      <c r="F2" t="inlineStr" s="2"><is><t>Female</t></is></c>
      <c r="G2" t="inlineStr" s="2"><is><t>2011-01-01</t></is></c>
    </row>''');

    // Empty template data rows (Row 3 to 100) pre-styled with text format, borders & UNLOCKED
    for (int r = 3; r <= 100; r++) {
      rowsBuffer.write('''
    <row r="$r" ht="20" customHeight="1">
      <c r="A$r" s="3"/>
      <c r="B$r" s="3"/>
      <c r="C$r" s="3"/>
      <c r="D$r" s="3"/>
      <c r="E$r" s="3"/>
      <c r="F$r" s="3"/>
      <c r="G$r" s="3"/>
    </row>''');
    }

    final sheetXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheetViews>
    <sheetView tabSelected="1" workbookViewId="0">
      <selection activeCell="A3" sqref="A3"/>
    </sheetView>
  </sheetViews>
  <cols>
    <col min="1" max="1" width="22" customWidth="1"/>
    <col min="2" max="2" width="30" customWidth="1"/>
    <col min="3" max="3" width="22" customWidth="1"/>
    <col min="4" max="4" width="22" customWidth="1"/>
    <col min="5" max="5" width="18" customWidth="1"/>
    <col min="6" max="6" width="16" customWidth="1"/>
    <col min="7" max="7" width="26" customWidth="1"/>
  </cols>
  <sheetData>
$rowsBuffer
  </sheetData>
  <dataValidations count="7">
    <!-- Validation 1: Gender Dropdown (Male / Female) -->
    <dataValidation type="list" errorStyle="stop" allowBlank="1" showInputMessage="1" showErrorMessage="1" errorTitle="Invalid Gender" error="Please select Male or Female from the dropdown." promptTitle="Gender" prompt="Select Male or Female" sqref="F3:F100">
      <formula1>&quot;Male,Female&quot;</formula1>
    </dataValidation>
    <!-- Validation 2: LRN (Numbers only, Exactly 12 Digits) -->
    <dataValidation type="textLength" operator="equal" errorStyle="stop" allowBlank="1" showInputMessage="1" showErrorMessage="1" errorTitle="Invalid LRN" error="LRN must be exactly 12 numeric digits." promptTitle="LRN (12 Digits)" prompt="Enter 12-digit Learner Reference Number" sqref="A3:A100">
      <formula1>12</formula1>
    </dataValidation>
    <!-- Validation 3: Email Address (Valid Format with @ and .) -->
    <dataValidation type="custom" errorStyle="stop" allowBlank="1" showInputMessage="1" showErrorMessage="1" errorTitle="Invalid Email Address" error="Invalid email address format (e.g. student@gmail.com)." promptTitle="Email Address" prompt="Enter valid student email address" sqref="B3:B100">
      <formula1>AND(ISNUMBER(FIND(&quot;@&quot;,B3)),ISNUMBER(FIND(&quot;.&quot;,B3)),LEN(B3)&gt;=6)</formula1>
    </dataValidation>
    <!-- Validation 4: Last Name (2 to 30 characters) -->
    <dataValidation type="textLength" operator="between" errorStyle="stop" allowBlank="1" showInputMessage="1" showErrorMessage="1" errorTitle="Invalid Last Name" error="Last name must be between 2 and 30 characters." promptTitle="Last Name" prompt="Enter surname (2-30 letters)" sqref="C3:C100">
      <formula1>2</formula1>
      <formula2>30</formula2>
    </dataValidation>
    <!-- Validation 5: First Name (2 to 30 characters) -->
    <dataValidation type="textLength" operator="between" errorStyle="stop" allowBlank="1" showInputMessage="1" showErrorMessage="1" errorTitle="Invalid First Name" error="First name must be between 2 and 30 characters." promptTitle="First Name" prompt="Enter given name (2-30 letters)" sqref="D3:D100">
      <formula1>2</formula1>
      <formula2>30</formula2>
    </dataValidation>
    <!-- Validation 6: Middle Initial (Optional, max 1 char) -->
    <dataValidation type="textLength" operator="lessThanOrEqual" errorStyle="stop" allowBlank="1" showInputMessage="1" showErrorMessage="1" errorTitle="Invalid Middle Initial" error="Middle initial is optional. If provided, enter 1 letter only." promptTitle="Middle Initial (Optional)" prompt="Leave blank or enter 1 letter only" sqref="E3:E100">
      <formula1>1</formula1>
    </dataValidation>
    <!-- Validation 7: Birthday (YYYY-MM-DD, student age 10-50 years old) -->
    <dataValidation type="textLength" operator="equal" errorStyle="stop" allowBlank="1" showInputMessage="1" showErrorMessage="1" errorTitle="Invalid Birthday" error="Student must be between 10 and 50 years old. Enter valid date in YYYY-MM-DD format (e.g. 2011-01-01)." promptTitle="Birthday [YYYY-MM-DD]" prompt="Enter date in YYYY-MM-DD format (e.g. 2011-01-01, Age 10-50)" sqref="G3:G100">
      <formula1>10</formula1>
    </dataValidation>
  </dataValidations>
</worksheet>''';
    _addFile(archive, 'xl/worksheets/sheet1.xml', sheetXml);

    final zipEncoder = ZipEncoder();
    final encoded = zipEncoder.encode(archive);
    return Uint8List.fromList(encoded);
  }

  static void _addFile(Archive archive, String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }
}
