import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/models/ilaw_lesson_plan.dart';

/// Generates a genuine, standards-compliant Microsoft Word (.docx) OpenXML
/// document formatted in the minimalist Senior High School (SHS) New Curriculum
/// iLAW Lesson Plan layout.
class IlawDocxExporter {
  static Uint8List generateBytes(IlawLessonPlan plan) {
    final archive = Archive();

    const contentTypesXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';
    _addXml(archive, '[Content_Types].xml', contentTypesXml);

    const rootRelsXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    _addXml(archive, '_rels/.rels', rootRelsXml);

    const docRelsXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';
    _addXml(archive, 'word/_rels/document.xml.rels', docRelsXml);

    const stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
        <w:sz w:val="22"/>
        <w:szCs w:val="22"/>
        <w:color w:val="1E293B"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr>
        <w:spacing w:after="120" w:line="276" w:lineRule="auto"/>
      </w:pPr>
    </w:pPrDefault>
  </w:docDefaults>
</w:styles>''';
    _addXml(archive, 'word/styles.xml', stylesXml);

    final documentXml = _buildDocumentXml(plan);
    _addXml(archive, 'word/document.xml', documentXml);

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  static String _buildDocumentXml(IlawLessonPlan plan) {
    final dateStr = _formatDate(plan.updatedAt);
    final strategy = plan.teachingStrategy.trim().isNotEmpty
        ? plan.teachingStrategy.trim()
        : 'Collaborative / Inquiry-Based';
    final teacher = plan.teacherName.trim().isNotEmpty
        ? plan.teacherName.trim()
        : 'Subject Teacher';

    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sb.writeln(
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">',
    );
    sb.writeln('  <w:body>');

    // Minimalist Document Header
    sb.writeln(
      _paragraph(
        'DEPARTMENT OF EDUCATION  |  SENIOR HIGH SCHOOL NEW CURRICULUM',
        bold: true,
        fontSizeHalfPts: 18,
        colorHex: '475569',
        align: 'center',
        spaceAfterTwips: 60,
      ),
    );
    sb.writeln(
      _paragraph(
        'iLAW LESSON PLAN',
        bold: true,
        fontSizeHalfPts: 32,
        colorHex: '111827',
        align: 'center',
        spaceAfterTwips: 220,
      ),
    );

    // 4-Column Metadata Grid Table
    sb.writeln(_buildMetadataTable(plan, teacher, strategy, dateStr));
    sb.writeln(_spacerParagraph(160));

    // Four iLAW Sections
    _appendIlawSection(
      sb,
      code: 'I',
      title: 'INTENDED LEARNING OUTCOMES (OBJECTIVES)',
      body: plan.intendedOutcomes,
    );
    _appendIlawSection(
      sb,
      code: 'L',
      title: 'LEARNING CONTENT & RESOURCES',
      body: plan.learningContent,
    );
    _appendIlawSection(
      sb,
      code: 'A',
      title: 'ASSESSMENT & LEARNING ACTIVITIES',
      body: plan.assessment,
    );
    _appendIlawSection(
      sb,
      code: 'W',
      title: 'WORK / LEARNING EXPERIENCES (PROCEDURE)',
      body: plan.workExperiences,
    );

    // Teacher Approval Footer
    sb.writeln(_spacerParagraph(280));
    sb.writeln(
      _paragraph(
        'Prepared and Approved by:',
        bold: false,
        fontSizeHalfPts: 20,
        colorHex: '64748B',
        spaceAfterTwips: 240,
      ),
    );
    sb.writeln(
      _paragraph(
        teacher.toUpperCase(),
        bold: true,
        fontSizeHalfPts: 22,
        colorHex: '111827',
        spaceAfterTwips: 40,
      ),
    );
    sb.writeln(
      _paragraph(
        'Senior High School Subject Teacher',
        bold: false,
        fontSizeHalfPts: 19,
        colorHex: '475569',
        spaceAfterTwips: 120,
      ),
    );

    // A4 Page Setup with clean 1-inch (1440 twips) margins
    sb.writeln('''    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>
    </w:sectPr>''');

    sb.writeln('  </w:body>');
    sb.writeln('</w:document>');
    return sb.toString();
  }

  static String _buildMetadataTable(
    IlawLessonPlan plan,
    String teacher,
    String strategy,
    String dateStr,
  ) {
    final sb = StringBuffer();
    sb.writeln('''    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="9026" w:type="dxa"/>
        <w:tblBorders>
          <w:top w:val="single" w:sz="6" w:space="0" w:color="CBD5E1"/>
          <w:left w:val="single" w:sz="6" w:space="0" w:color="CBD5E1"/>
          <w:bottom w:val="single" w:sz="6" w:space="0" w:color="CBD5E1"/>
          <w:right w:val="single" w:sz="6" w:space="0" w:color="CBD5E1"/>
          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
        </w:tblBorders>
      </w:tblPr>''');

    sb.writeln(
      _metaRow(
        'Subject',
        plan.subject,
        'Grade & Quarter',
        '${plan.gradeLevel}  •  ${plan.quarter}',
      ),
    );
    sb.writeln(
      _metaRow(
        'Lesson Topic',
        plan.topic,
        'Time Allotment',
        '${plan.durationMinutes} Minutes',
      ),
    );
    sb.writeln(_metaRow('Prepared By', teacher, 'Date Prepared', dateStr));
    sb.writeln(
      _metaRow(
        'Approach',
        strategy,
        'Status',
        plan.isApproved ? 'Teacher Approved' : 'Draft',
      ),
    );

    if (plan.learningCompetency.trim().isNotEmpty) {
      sb.writeln('''      <w:tr>
        ${_metaCell('Competency', isLabel: true, widthDxa: 1600)}
        ${_metaCell(plan.learningCompetency.trim(), isLabel: false, widthDxa: 7426, gridSpan: 3)}
      </w:tr>''');
    }

    sb.writeln('    </w:tbl>');
    return sb.toString();
  }

  static String _metaRow(String l1, String v1, String l2, String v2) {
    return '''      <w:tr>
        ${_metaCell(l1, isLabel: true, widthDxa: 1600)}
        ${_metaCell(v1, isLabel: false, widthDxa: 2913)}
        ${_metaCell(l2, isLabel: true, widthDxa: 1600)}
        ${_metaCell(v2, isLabel: false, widthDxa: 2913)}
      </w:tr>''';
  }

  static String _metaCell(
    String text, {
    required bool isLabel,
    required int widthDxa,
    int gridSpan = 1,
  }) {
    final fill = isLabel ? '<w:shd w:val="clear" w:color="auto" w:fill="F8FAFC"/>' : '';
    final span = gridSpan > 1 ? '<w:gridSpan w:val="$gridSpan"/>' : '';
    return '''        <w:tc>
          <w:tcPr>
            <w:tcW w:w="$widthDxa" w:type="dxa"/>
            $span
            $fill
            <w:tcMar>
              <w:top w:w="100" w:type="dxa"/>
              <w:bottom w:w="100" w:type="dxa"/>
              <w:left w:w="140" w:type="dxa"/>
              <w:right w:w="140" w:type="dxa"/>
            </w:tcMar>
          </w:tcPr>
          ${_paragraph(text, bold: isLabel, fontSizeHalfPts: 20, colorHex: isLabel ? '475569' : '0F172A', spaceAfterTwips: 0)}
        </w:tc>''';
  }

  static void _appendIlawSection(
    StringBuffer sb, {
    required String code,
    required String title,
    required String body,
  }) {
    final lines = body
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((l) => l.trimRight())
        .toList();

    sb.writeln('''    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="9026" w:type="dxa"/>
        <w:tblBorders>
          <w:top w:val="single" w:sz="6" w:space="0" w:color="CBD5E1"/>
          <w:left w:val="single" w:sz="18" w:space="0" w:color="487898"/>
          <w:bottom w:val="single" w:sz="6" w:space="0" w:color="CBD5E1"/>
          <w:right w:val="single" w:sz="6" w:space="0" w:color="CBD5E1"/>
          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
        </w:tblBorders>
      </w:tblPr>
      <w:tr>
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="9026" w:type="dxa"/>
            <w:shd w:val="clear" w:color="auto" w:fill="F1F5F9"/>
            <w:tcMar>
              <w:top w:w="110" w:type="dxa"/>
              <w:bottom w:w="110" w:type="dxa"/>
              <w:left w:w="180" w:type="dxa"/>
              <w:right w:w="180" w:type="dxa"/>
            </w:tcMar>
          </w:tcPr>
          ${_paragraph('$code.  $title', bold: true, fontSizeHalfPts: 21, colorHex: '1E293B', spaceAfterTwips: 0)}
        </w:tc>
      </w:tr>
      <w:tr>
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="9026" w:type="dxa"/>
            <w:tcMar>
              <w:top w:w="140" w:type="dxa"/>
              <w:bottom w:w="140" w:type="dxa"/>
              <w:left w:w="180" w:type="dxa"/>
              <w:right w:w="180" w:type="dxa"/>
            </w:tcMar>
          </w:tcPr>''');

    final nonEmptyLines = lines.where((l) => l.trim().isNotEmpty).toList();
    if (nonEmptyLines.isEmpty) {
      sb.writeln(
        _paragraph(
          '—',
          fontSizeHalfPts: 21,
          colorHex: '64748B',
          spaceAfterTwips: 0,
        ),
      );
    } else {
      for (var i = 0; i < nonEmptyLines.length; i++) {
        final isLast = i == nonEmptyLines.length - 1;
        sb.writeln(
          _paragraph(
            nonEmptyLines[i],
            fontSizeHalfPts: 21,
            colorHex: '1E293B',
            spaceAfterTwips: isLast ? 0 : 90,
          ),
        );
      }
    }

    sb.writeln('''        </w:tc>
      </w:tr>
    </w:tbl>''');
    sb.writeln(_spacerParagraph(140));
  }

  static String _paragraph(
    String text, {
    bool bold = false,
    int fontSizeHalfPts = 22,
    String colorHex = '1E293B',
    String align = 'left',
    int spaceAfterTwips = 100,
  }) {
    final escaped = escapeXml(text);
    final boldTag = bold ? '<w:b/>' : '';
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="$align"/>
        <w:spacing w:after="$spaceAfterTwips" w:line="276" w:lineRule="auto"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
          $boldTag
          <w:color w:val="$colorHex"/>
          <w:sz w:val="$fontSizeHalfPts"/>
          <w:szCs w:val="$fontSizeHalfPts"/>
        </w:rPr>
        <w:t xml:space="preserve">$escaped</w:t>
      </w:r>
    </w:p>''';
  }

  static String _spacerParagraph(int afterTwips) {
    return '''    <w:p>
      <w:pPr>
        <w:spacing w:after="$afterTwips" w:line="120" w:lineRule="auto"/>
      </w:pPr>
    </w:p>''';
  }

  static String escapeXml(String input) {
    final stripped = input.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'),
      '',
    );
    return stripped
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static void _addXml(Archive archive, String path, String xmlContent) {
    final bytes = utf8.encode(xmlContent);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }
}
