import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/models/ilaw_lesson_plan.dart';

/// Generates a genuine, standards-compliant Microsoft Word (.docx) OpenXML
/// document formatted in the authentic DepEd Senior High School (SHS)
/// Daily Lesson Log (I.L.A.W. Framework).
///
/// Matches the exact official DepEd table layout and branding as the PDF:
/// - DepEd Cyan/Teal borders (#2A8896) and light-cyan banner fills (#E2F4F7)
/// - Top Daily Lesson Log metadata grid
/// - Four section banners (INTENTIONS, LEARNING EXPERIENCE, ASSESSMENT, WAYS FORWARD)
/// - Multi-session matrix and self-check rubric
/// - Teacher-only signatory block
class IlawDocxExporter {
  static const String _borderHex = '2A8896';
  static const String _bannerFillHex = 'E2F4F7';
  static const String _col1FillHex = 'F6FBFC';
  static const String _primaryDarkHex = '0E4B55';

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
        <w:sz w:val="20"/>
        <w:szCs w:val="20"/>
        <w:color w:val="1E293B"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr>
        <w:spacing w:after="80" w:line="260" w:lineRule="auto"/>
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
    final teacher = plan.teacherName.trim().isNotEmpty
        ? plan.teacherName.trim()
        : 'Karen P. Gonzaga';
    final termUpper = plan.term.replaceAll('Quarter', 'Term').toUpperCase();

    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sb.writeln(
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">',
    );
    sb.writeln('  <w:body>');

    // 1. TOP HEADER BANNER
    sb.writeln(
      _paragraph(
        'DAILY LESSON LOG  •  iLAW LESSON PLAN',
        bold: true,
        fontSizeHalfPts: 26,
        colorHex: _primaryDarkHex,
        align: 'center',
        spaceAfterTwips: 40,
      ),
    );
    sb.writeln(
      _paragraph(
        'I.L.A.W. Framework  •  SENIOR HIGH SCHOOL',
        bold: true,
        fontSizeHalfPts: 18,
        colorHex: _borderHex,
        align: 'center',
        spaceAfterTwips: 140,
      ),
    );

    // 2. MAIN DEPED TABLE
    sb.writeln('''    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="10000" w:type="dxa"/>
        <w:tblBorders>
          <w:top w:val="single" w:sz="8" w:space="0" w:color="$_borderHex"/>
          <w:left w:val="single" w:sz="8" w:space="0" w:color="$_borderHex"/>
          <w:bottom w:val="single" w:sz="8" w:space="0" w:color="$_borderHex"/>
          <w:right w:val="single" w:sz="8" w:space="0" w:color="$_borderHex"/>
          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="$_borderHex"/>
          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="$_borderHex"/>
        </w:tblBorders>
      </w:tblPr>''');

    // Metadata Grid Rows
    sb.writeln(
      _meta2ColRow(
        'School',
        'EDUARDO BARRETTO SR. INTEGRATED SCHOOL',
        'Grade Level',
        plan.gradeLevel.toUpperCase(),
      ),
    );
    sb.writeln(
      _meta2ColRow(
        'Teacher',
        teacher,
        'Learning Area',
        plan.subject.toUpperCase(),
      ),
    );
    sb.writeln(
      _meta2ColRow(
        'Teaching Dates',
        'DAY 1 - DAY ${plan.numberOfSessions} (TUESDAY - FRIDAY)',
        'Term',
        '$termUpper (Instructional Block - Week 1)',
      ),
    );

    // Overview Rows
    sb.writeln(_tableRow('Lesson Title', null, [plan.topic.toUpperCase()]));

    final sessionsLabels = List.generate(
      plan.numberOfSessions,
      (i) => 'DAY ${i + 1}',
    ).join('        ');
    sb.writeln(_tableRow('Number of Sessions', null, [sessionsLabels]));

    final referencesLines = [
      'Curriculum References:',
      '• Department of Education. K to 12 ${plan.subject} Curriculum Guide.',
      '• Department of Education. ${plan.subject} Teacher\'s Guide & Learner\'s Module.',
      'Teacher-Made / Digital Resources:',
      '• PPT Slides & Contextualized Worksheet Exercises.',
      '• Desmos Graphing Calculator/App, Scientific Calculators, Board/Markers.',
    ];
    sb.writeln(
      _tableRow(
        'References',
        '(books, websites, toolkits, etc.)',
        referencesLines,
      ),
    );

    final aiCitationLines = [
      'Generative AI was used to assist in organizing, wording, and aligning the ILAW lesson-plan components with the teacher-provided materials. The teacher reviewed, revised, and validated the competencies, examples, activities, assessments, and contextualized applications before use in class, consistent with responsible teacher oversight (DepEd Order No. 003, s. 2026 Annex A).',
    ];
    sb.writeln(
      _tableRow(
        'Declaration of AI use',
        'Cite how AI was used in the formulation of the lesson plan. See DO 3 s.2026 Annex A.',
        aiCitationLines,
      ),
    );

    // =============================================================
    // SECTION I: INTENTIONS
    // =============================================================
    sb.writeln(
      _bannerRow(
        'INTENTIONS',
        'Meaningful learning experiences are anchored in how we frame them. Start by deciding what you want learners to master by the end of the lesson - keep it clear and simple. Remember: Understanding your learners\' evolving context and designing around it ensure that your lessons connect with and are relevant to them.',
      ),
    );

    final compLines = [
      'Content Standard:',
      'The learners demonstrate understanding of key concepts, principles, and representations in ${plan.subject}.',
      '',
      'Performance Standard:',
      'The learners are able to accurately formulate, illustrate, and solve real-life problems involving ${plan.topic}.',
      '',
      'Learning Competencies:',
      if (plan.learningCompetency.trim().isNotEmpty)
        '• ${plan.learningCompetency.trim()}'
      else ...[
        '• Analyzes and represents real-world scenarios through ${plan.topic}.',
        '• Solves practical mathematical and contextual problems with critical reasoning.',
      ],
    ];
    sb.writeln(
      _tableRow(
        'Learning Competency and Curriculum Standards',
        'Write the competency/ies from the curriculum that we are targeting, and applicable standards.',
        compLines,
      ),
    );

    final objectivesLines = [
      'By the end of the instructional sessions, learners should be able to:',
      plan.intendedOutcomes,
    ];
    sb.writeln(
      _tableRow(
        'Learning Objectives',
        'Write the smaller knowledge, skills, or tasks from the competency that learners will work on.',
        objectivesLines,
      ),
    );

    final learnersContextLines = [
      'Learners enter the lesson with prerequisite foundational knowledge. Instruction begins with recall and catch-up activities before formalizing abstract notations.',
      'Contextualized examples (real-life transactions, ride fares, digital data plans) make abstract conditions concrete. Guided scaffolding is provided for emerging learners.',
      'Target Diagnostic Level: ${plan.targetProficiency.label}.',
    ];
    sb.writeln(
      _tableRow(
        'Learners Context',
        'Write observations of learners, how they respond, strengths, interests, and barriers to learning.',
        learnersContextLines,
      ),
    );

    // =============================================================
    // SECTION II: LEARNING EXPERIENCE
    // =============================================================
    sb.writeln(
      _bannerRow(
        'LEARNING EXPERIENCE',
        'A learning experience is like a thoughtfully designed journey. Each activity and interaction build towards meaningful understanding and growth. Identify activities and interactions to help learners gain knowledge, skills, or understanding in a purposeful way.',
      ),
    );

    final preLessonLines = [
      '• Begin with a brief check-in and communicate the session learning targets in learner-friendly language.',
      '• Activate prior knowledge through quick concept matching and real-world scenario classification.',
      '• Administer diagnostic catch-up check to identify prerequisites and misconceptions before starting new topics.',
    ];
    sb.writeln(
      _tableRow(
        'Pre-Lesson',
        'Describe how you will help the learners get ready for the lesson.',
        preLessonLines,
      ),
    );

    final flowLines = <String>[];
    for (final s in plan.effectiveSessions) {
      flowLines.add('Session ${s.sessionNumber} — ${s.sessionTitle}:');
      flowLines.add(s.learningExperiences);
      flowLines.add('');
    }
    if (flowLines.isEmpty) {
      flowLines.add(plan.workExperiences);
    }
    sb.writeln(
      _tableRow(
        'Flow',
        'Describe the activities that you can implement in 1 or more sessions to meet the learning objectives.',
        flowLines,
      ),
    );

    final diffLines = [
      '• Use think-pair-share before whole-class sharing to give processing time to all learners.',
      '• Provide worked examples and interval cues for learners needing scaffolding.',
      '• Allow digital tools (Desmos/calculator) and visual diagram representations as acceptable evidence of understanding.',
    ];
    sb.writeln(
      _tableRow(
        'Differentiation / Inclusion',
        'Ensure inclusion for learners\' varied abilities, learning styles, and contexts.',
        diffLines,
      ),
    );

    final resLines = [
      '• PowerPoint: Lesson slides with interactive checks, worked models, and practice prompts.',
      '• Practice Worksheets: Scaffolding sheets and tiered problem sets.',
      '• Digital and Concrete Tools: Desmos graphing app, whiteboard/markers, graphing paper.',
      '• Offline Alternative: Printed coordinate grids, teacher tables, and board demonstrations.',
    ];
    sb.writeln(
      _tableRow(
        'Learning Resources',
        'List down the learning resources that will help you reach your objectives.',
        resLines,
      ),
    );

    final integLines = [
      '• ICT / Digital Literacy: Responsible use of graphing tools to visualize and verify relationships.',
      '• Financial Literacy: Interpreting tiered fares, pricing models, data charges, and income tax brackets.',
      '• Communication: Explaining why specific rules apply and justifying solutions in mathematical language.',
      '• Values / Life Skills: Reflecting on rule-based reasoning, fairness, and flexible problem-solving.',
    ];
    sb.writeln(
      _tableRow(
        'Opportunities for Integration',
        'Write down possibilities to meaningfully connect to another learning area, special topic, or technology.',
        integLines,
      ),
    );

    // =============================================================
    // SECTION III: ASSESSMENT
    // =============================================================
    sb.writeln(
      _bannerRow(
        'ASSESSMENT',
        'Assessments reveal what learners have gained and what they still need help with. These are helpful in providing you with information to guide your future instruction throughout the entire session.',
      ),
    );

    final assessLines = <String>[];
    for (final s in plan.effectiveSessions) {
      assessLines.add('Session ${s.sessionNumber}:');
      assessLines.add(s.formativeAssessment);
      assessLines.add('');
    }
    if (assessLines.isEmpty) {
      assessLines.add(plan.assessment);
    }
    sb.writeln(
      _tableRow(
        'Formative Assessment',
        'Create a task, activity or questions to evaluate learning and provide feedback every now and then.',
        assessLines,
      ),
    );

    // =============================================================
    // SECTION IV: WAYS FORWARD
    // =============================================================
    sb.writeln(
      _bannerRow(
        'WAYS FORWARD',
        'Meaningful learning can also happen beyond the classroom - for both the learners and the teacher. Pause and reflect on what happened today.',
      ),
    );

    final extLines = [
      '• Ask learners to identify one real-life service or pricing system at home or in the community that follows conditional rules.',
      '• Provide a short remediation set on prerequisite functions for learners needing additional reinforcement.',
      '• Challenge proficient learners with an enrichment task to model a multi-tier delivery or mobile data pricing scenario.',
    ];
    sb.writeln(
      _tableRow(
        'Extended Learning Opportunities',
        'Suggest other learning experiences outside the classroom/class hours that learners may want to access.',
        extLines,
      ),
    );

    final refLines = [
      '• Review which prerequisite ideas still caused difficulty (boundary points, condition interpretation, intervals).',
      '• Note which contexts generated the strongest participation and reuse familiar situations in future mathematical models.',
      '• Seek instructional coach feedback on multi-tier pacing and strengthening questioning techniques.',
    ];
    sb.writeln(
      _tableRow(
        'Reflections',
        'Think about what you need to change for the next session based on what happened today.',
        refLines,
      ),
    );

    sb.writeln('    </w:tbl>');
    sb.writeln(_spacerParagraph(160));

    // =============================================================
    // SELF-CHECK RUBRIC (Checklist Table)
    // =============================================================
    _appendRubricTable(sb, plan.effectiveRubrics);

    // =============================================================
    // OFFICIAL SIGNATORY BLOCK (Teacher Only)
    // =============================================================
    sb.writeln(_spacerParagraph(140));
    sb.writeln(
      _paragraph(
        'Prepared by:',
        bold: false,
        fontSizeHalfPts: 18,
        colorHex: '64748B',
        spaceAfterTwips: 80,
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
        'SHS Subject Teacher',
        bold: false,
        fontSizeHalfPts: 18,
        colorHex: '475569',
        spaceAfterTwips: 120,
      ),
    );

    // A4 Page Setup with 0.75-inch (1080 twips) margins
    sb.writeln('''    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1080" w:right="953" w:bottom="1080" w:left="953" w:header="720" w:footer="720" w:gutter="0"/>
    </w:sectPr>''');

    sb.writeln('  </w:body>');
    sb.writeln('</w:document>');
    return sb.toString();
  }

  // -------------------------------------------------------------
  // XML Table Row Generators
  // -------------------------------------------------------------
  static String _bannerRow(String title, String quote) {
    return '''      <w:tr>
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="10000" w:type="dxa"/>
            <w:gridSpan w:val="2"/>
            <w:shd w:val="clear" w:color="auto" w:fill="$_bannerFillHex"/>
            <w:tcMar>
              <w:top w:w="140" w:type="dxa"/>
              <w:bottom w:w="140" w:type="dxa"/>
              <w:left w:w="180" w:type="dxa"/>
              <w:right w:w="180" w:type="dxa"/>
            </w:tcMar>
          </w:tcPr>
          ${_paragraph(title, bold: true, fontSizeHalfPts: 22, colorHex: _primaryDarkHex, spaceAfterTwips: 30)}
          ${_paragraph(quote, bold: false, italic: true, fontSizeHalfPts: 17, colorHex: '1E293B', spaceAfterTwips: 0)}
        </w:tc>
      </w:tr>''';
  }

  static String _tableRow(
    String categoryTitle,
    String? categoryPrompt,
    List<String> contentLines,
  ) {
    final leftSb = StringBuffer();
    leftSb.writeln(
      _paragraph(
        categoryTitle,
        bold: true,
        fontSizeHalfPts: 18,
        colorHex: _primaryDarkHex,
        spaceAfterTwips: categoryPrompt != null ? 30 : 0,
      ),
    );
    if (categoryPrompt != null && categoryPrompt.trim().isNotEmpty) {
      leftSb.writeln(
        _paragraph(
          categoryPrompt.trim(),
          bold: false,
          italic: true,
          fontSizeHalfPts: 15,
          colorHex: '475569',
          spaceAfterTwips: 0,
        ),
      );
    }

    final rightSb = StringBuffer();
    final nonNullLines = <String>[];
    for (final raw in contentLines) {
      for (final sub in raw.replaceAll('\r\n', '\n').split('\n')) {
        nonNullLines.add(sub.trimRight());
      }
    }

    if (nonNullLines.isEmpty) {
      rightSb.writeln(
        _paragraph(
          '—',
          fontSizeHalfPts: 18,
          colorHex: '64748B',
          spaceAfterTwips: 0,
        ),
      );
    } else {
      for (var i = 0; i < nonNullLines.length; i++) {
        final line = nonNullLines[i];
        final isLast = i == nonNullLines.length - 1;
        if (line.isEmpty) {
          rightSb.writeln(_spacerParagraph(50));
          continue;
        }
        final isSubHeader =
            line.endsWith(':') ||
            line.startsWith('Session ') ||
            line.startsWith('DAY ');
        rightSb.writeln(
          _paragraph(
            line,
            bold: isSubHeader,
            fontSizeHalfPts: 18,
            colorHex: isSubHeader ? _primaryDarkHex : '1E293B',
            spaceAfterTwips: isLast ? 0 : 50,
          ),
        );
      }
    }

    return '''      <w:tr>
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="2600" w:type="dxa"/>
            <w:shd w:val="clear" w:color="auto" w:fill="$_col1FillHex"/>
            <w:tcMar>
              <w:top w:w="120" w:type="dxa"/>
              <w:bottom w:w="120" w:type="dxa"/>
              <w:left w:w="140" w:type="dxa"/>
              <w:right w:w="140" w:type="dxa"/>
            </w:tcMar>
          </w:tcPr>
          $leftSb
        </w:tc>
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="7400" w:type="dxa"/>
            <w:tcMar>
              <w:top w:w="120" w:type="dxa"/>
              <w:bottom w:w="120" w:type="dxa"/>
              <w:left w:w="160" w:type="dxa"/>
              <w:right w:w="160" w:type="dxa"/>
            </w:tcMar>
          </w:tcPr>
          $rightSb
        </w:tc>
      </w:tr>''';
  }

  static String _meta2ColRow(String k1, String v1, String k2, String v2) {
    return '''      <w:tr>
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="5000" w:type="dxa"/>
            <w:tcMar>
              <w:top w:w="90" w:type="dxa"/>
              <w:bottom w:w="90" w:type="dxa"/>
              <w:left w:w="140" w:type="dxa"/>
              <w:right w:w="140" w:type="dxa"/>
            </w:tcMar>
          </w:tcPr>
          ${_paragraph('$k1:  $v1', bold: false, fontSizeHalfPts: 17, colorHex: '1E293B', spaceAfterTwips: 0)}
        </w:tc>
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="5000" w:type="dxa"/>
            <w:tcMar>
              <w:top w:w="90" w:type="dxa"/>
              <w:bottom w:w="90" w:type="dxa"/>
              <w:left w:w="140" w:type="dxa"/>
              <w:right w:w="140" w:type="dxa"/>
            </w:tcMar>
          </w:tcPr>
          ${_paragraph('$k2:  $v2', bold: false, fontSizeHalfPts: 17, colorHex: '1E293B', spaceAfterTwips: 0)}
        </w:tc>
      </w:tr>''';
  }

  static void _appendRubricTable(
    StringBuffer sb,
    List<IlawRubricItem> rubrics,
  ) {
    if (rubrics.isEmpty) return;

    sb.writeln(
      _paragraph(
        'Rubric for Lesson Planning Self-Check and/or Peer Coaching',
        bold: true,
        fontSizeHalfPts: 22,
        colorHex: _primaryDarkHex,
        spaceAfterTwips: 100,
      ),
    );

    sb.writeln('''    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="10000" w:type="dxa"/>
        <w:tblBorders>
          <w:top w:val="single" w:sz="6" w:space="0" w:color="$_borderHex"/>
          <w:left w:val="single" w:sz="6" w:space="0" w:color="$_borderHex"/>
          <w:bottom w:val="single" w:sz="6" w:space="0" w:color="$_borderHex"/>
          <w:right w:val="single" w:sz="6" w:space="0" w:color="$_borderHex"/>
          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="$_borderHex"/>
          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="$_borderHex"/>
        </w:tblBorders>
      </w:tblPr>
      <w:tr>
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="6000" w:type="dxa"/>
            <w:shd w:val="clear" w:color="auto" w:fill="$_bannerFillHex"/>
            <w:tcMar>
              <w:top w:w="100" w:type="dxa"/><w:bottom w:w="100" w:type="dxa"/>
              <w:left w:w="140" w:type="dxa"/><w:right w:w="140" w:type="dxa"/>
            </w:tcMar>
          </w:tcPr>
          ${_paragraph('DepEd Lesson Planning Criteria', bold: true, fontSizeHalfPts: 18, colorHex: _primaryDarkHex, spaceAfterTwips: 0)}
        </w:tc>
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="1500" w:type="dxa"/>
            <w:shd w:val="clear" w:color="auto" w:fill="$_bannerFillHex"/>
            <w:tcMar>
              <w:top w:w="100" w:type="dxa"/><w:bottom w:w="100" w:type="dxa"/>
              <w:left w:w="140" w:type="dxa"/><w:right w:w="140" w:type="dxa"/>
            </w:tcMar>
          </w:tcPr>
          ${_paragraph('Status', bold: true, fontSizeHalfPts: 18, colorHex: _primaryDarkHex, align: 'center', spaceAfterTwips: 0)}
        </w:tc>
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="2500" w:type="dxa"/>
            <w:shd w:val="clear" w:color="auto" w:fill="$_bannerFillHex"/>
            <w:tcMar>
              <w:top w:w="100" w:type="dxa"/><w:bottom w:w="100" w:type="dxa"/>
              <w:left w:w="140" w:type="dxa"/><w:right w:w="140" w:type="dxa"/>
            </w:tcMar>
          </w:tcPr>
          ${_paragraph('Notes / Evidence', bold: true, fontSizeHalfPts: 18, colorHex: _primaryDarkHex, spaceAfterTwips: 0)}
        </w:tc>
      </w:tr>''');

    for (final r in rubrics) {
      final statusText = r.isMet ? '[✓] Met' : '[ ] Not Yet';
      final statusColor = r.isMet ? '166534' : '991B1B';
      sb.writeln('''      <w:tr>
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="6000" w:type="dxa"/>
            <w:tcMar>
              <w:top w:w="90" w:type="dxa"/><w:bottom w:w="90" w:type="dxa"/>
              <w:left w:w="140" w:type="dxa"/><w:right w:w="140" w:type="dxa"/>
            </w:tcMar>
          </w:tcPr>
          ${_paragraph(r.criterion, bold: false, fontSizeHalfPts: 17, colorHex: '1E293B', spaceAfterTwips: 0)}
        </w:tc>
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="1500" w:type="dxa"/>
            <w:tcMar>
              <w:top w:w="90" w:type="dxa"/><w:bottom w:w="90" w:type="dxa"/>
              <w:left w:w="140" w:type="dxa"/><w:right w:w="140" w:type="dxa"/>
            </w:tcMar>
          </w:tcPr>
          ${_paragraph(statusText, bold: true, fontSizeHalfPts: 17, colorHex: statusColor, align: 'center', spaceAfterTwips: 0)}
        </w:tc>
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="2500" w:type="dxa"/>
            <w:tcMar>
              <w:top w:w="90" w:type="dxa"/><w:bottom w:w="90" w:type="dxa"/>
              <w:left w:w="140" w:type="dxa"/><w:right w:w="140" w:type="dxa"/>
            </w:tcMar>
          </w:tcPr>
          ${_paragraph(r.notes.isNotEmpty ? r.notes : '—', bold: false, fontSizeHalfPts: 17, colorHex: '475569', spaceAfterTwips: 0)}
        </w:tc>
      </w:tr>''');
    }

    sb.writeln('    </w:tbl>');
  }

  static String _paragraph(
    String text, {
    bool bold = false,
    bool italic = false,
    int fontSizeHalfPts = 20,
    String colorHex = '1E293B',
    String align = 'left',
    int spaceAfterTwips = 80,
  }) {
    final escaped = escapeXml(text);
    final boldTag = bold ? '<w:b/>' : '';
    final italicTag = italic ? '<w:i/>' : '';
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="$align"/>
        <w:spacing w:after="$spaceAfterTwips" w:line="260" w:lineRule="auto"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
          $boldTag
          $italicTag
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

  static void _addXml(Archive archive, String path, String xmlContent) {
    final bytes = utf8.encode(xmlContent);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }
}
