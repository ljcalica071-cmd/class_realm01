import 'dart:convert';
import 'dart:typed_data';

import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/models/ilaw_lesson_plan.dart';

/// Pure-Dart multi-page PDF 1.4 generator for the DepEd Senior High School
/// (SHS) Strengthened Curriculum Daily Lesson Log (I.L.A.W. Framework).
///
/// Produces official DepEd-formatted tables with authentic cyan/teal grid lines (#2C8896),
/// light-cyan section banner headers (#E2F4F7), two-column category rows,
/// multi-session flow, formative assessments, remarks evaluation grid,
/// DepEd DO 3 s.2026 Annex A AI declaration, and official signatories.
class IlawPdfExporter {
  static const double _pageWidth = 595.28; // A4 width in points
  static const double _pageHeight = 841.89; // A4 height in points
  static const double _margin = 36.0;
  static const double _contentWidth = _pageWidth - (_margin * 2);
  static const double _col1W = 145.0;
  static const double _col2W = _contentWidth - _col1W;
  static const double _bottomLimit = 48.0;

  // DepEd Cyan/Teal Brand Colors
  static const double _borderR = 0.173;
  static const double _borderG = 0.533;
  static const double _borderB = 0.588;

  static const double _bannerFillR = 0.886;
  static const double _bannerFillG = 0.957;
  static const double _bannerFillB = 0.969;

  static const double _col1FillR = 0.965;
  static const double _col1FillG = 0.984;
  static const double _col1FillB = 0.988;

  static Uint8List generateBytes(IlawLessonPlan plan) {
    final pages = <StringBuffer>[];
    late StringBuffer currentStream;
    double cursorY = _pageHeight - _margin;

    void startNewPage() {
      currentStream = StringBuffer();
      pages.add(currentStream);
      cursorY = _pageHeight - _margin;
    }

    void ensureSpace(double requiredHeight) {
      if (cursorY - requiredHeight < _bottomLimit) {
        startNewPage();
      }
    }

    startNewPage();

    final teacher = plan.teacherName.trim().isNotEmpty
        ? plan.teacherName.trim()
        : 'Karen P. Gonzaga';
    final termUpper = plan.term.replaceAll('Quarter', 'Term').toUpperCase();

    // -------------------------------------------------------------
    // Helper: Draw Section Banner Row
    // -------------------------------------------------------------
    void drawBannerRow(String mainTitle, String subtitleQuote) {
      final quoteLines = _wrapMultiline(subtitleQuote, maxChars: 110);
      final bannerH = 18.0 + (quoteLines.length * 10.5) + 6.0;

      ensureSpace(bannerH);

      final boxTop = cursorY;
      final boxBottom = boxTop - bannerH;

      // Fill banner background with cyan tint and cyan border
      _drawBox(
        currentStream,
        x: _margin,
        y: boxBottom,
        w: _contentWidth,
        h: bannerH,
        fillR: _bannerFillR,
        fillG: _bannerFillG,
        fillB: _bannerFillB,
        strokeR: _borderR,
        strokeG: _borderG,
        strokeB: _borderB,
        lineWidth: 1.0,
      );

      // Main Banner Title
      _drawText(
        currentStream,
        text: mainTitle,
        x: _margin + 8,
        y: boxTop - 13,
        fontSize: 10.5,
        bold: true,
        r: 0.055,
        g: 0.294,
        b: 0.333,
      );

      // Subtitle quote in italic tone
      var qY = boxTop - 24;
      for (final qLine in quoteLines) {
        _drawText(
          currentStream,
          text: qLine,
          x: _margin + 8,
          y: qY,
          fontSize: 7.5,
          bold: false,
          r: 0.12,
          g: 0.16,
          b: 0.20,
        );
        qY -= 9.5;
      }

      cursorY = boxBottom;
    }

    // -------------------------------------------------------------
    // Helper: Draw Two-Column Table Row
    // -------------------------------------------------------------
    void drawTableRow({
      required String categoryTitle,
      String? categoryPrompt,
      required List<String> contentLines,
      double minHeight = 28.0,
    }) {
      final promptWrapped = categoryPrompt != null && categoryPrompt.trim().isNotEmpty
          ? _wrapMultiline(categoryPrompt.trim(), maxChars: 28)
          : <String>[];

      final leftLinesCount = 1 + (promptWrapped.isNotEmpty ? promptWrapped.length + 1 : 0);
      final rightLinesCount = contentLines.isEmpty ? 1 : contentLines.length;

      final requiredH = [
        minHeight,
        leftLinesCount * 11.5 + 10.0,
        rightLinesCount * 11.5 + 10.0,
      ].reduce((a, b) => a > b ? a : b);

      ensureSpace(requiredH);

      final boxTop = cursorY;
      final boxBottom = boxTop - requiredH;

      // Outer row box
      _drawBox(
        currentStream,
        x: _margin,
        y: boxBottom,
        w: _contentWidth,
        h: requiredH,
        fillR: 1.0,
        fillG: 1.0,
        fillB: 1.0,
        strokeR: _borderR,
        strokeG: _borderG,
        strokeB: _borderB,
        lineWidth: 0.8,
      );

      // Tint left column
      _drawFilledRect(
        currentStream,
        x: _margin + 0.5,
        y: boxBottom + 0.5,
        w: _col1W - 0.5,
        h: requiredH - 1.0,
        r: _col1FillR,
        g: _col1FillG,
        b: _col1FillB,
      );

      // Column vertical divider line
      _drawLine(
        currentStream,
        x1: _margin + _col1W,
        y1: boxTop,
        x2: _margin + _col1W,
        y2: boxBottom,
        strokeR: _borderR,
        strokeG: _borderG,
        strokeB: _borderB,
        lineWidth: 0.8,
      );

      // Draw Left Column: Title & Prompt
      var leftY = boxTop - 12;
      _drawText(
        currentStream,
        text: categoryTitle,
        x: _margin + 6,
        y: leftY,
        fontSize: 8.5,
        bold: true,
        r: 0.055,
        g: 0.294,
        b: 0.333,
      );
      leftY -= 11;

      for (final pLine in promptWrapped) {
        _drawText(
          currentStream,
          text: pLine,
          x: _margin + 6,
          y: leftY,
          fontSize: 7.0,
          bold: false,
          r: 0.25,
          g: 0.30,
          b: 0.35,
        );
        leftY -= 9.0;
      }

      // Draw Right Column: Content Lines
      var rightY = boxTop - 12;
      for (final cLine in contentLines) {
        if (cLine.isEmpty) {
          rightY -= 5;
          continue;
        }
        final isSubHeader = cLine.endsWith(':') || cLine.startsWith('Session ') || cLine.startsWith('DAY ');
        _drawText(
          currentStream,
          text: cLine,
          x: _margin + _col1W + 8,
          y: rightY,
          fontSize: 8.0,
          bold: isSubHeader,
          r: isSubHeader ? 0.055 : 0.08,
          g: isSubHeader ? 0.294 : 0.10,
          b: isSubHeader ? 0.333 : 0.14,
        );
        rightY -= 10.5;
      }

      cursorY = boxBottom;
    }

    // =============================================================
    // 1. TOP HEADER BLOCK & METADATA GRID
    // =============================================================
    ensureSpace(120);

    // Top Header Banner
    final headerH = 46.0;
    final headerTop = cursorY;
    final headerBottom = headerTop - headerH;

    _drawBox(
      currentStream,
      x: _margin,
      y: headerBottom,
      w: _contentWidth,
      h: headerH,
      fillR: _bannerFillR,
      fillG: _bannerFillG,
      fillB: _bannerFillB,
      strokeR: _borderR,
      strokeG: _borderG,
      strokeB: _borderB,
      lineWidth: 1.2,
    );

    // Header Titles
    _drawText(
      currentStream,
      text: 'DAILY LESSON LOG  •  iLAW LESSON PLAN',
      x: _margin + 16,
      y: headerTop - 18,
      fontSize: 12.0,
      bold: true,
      r: 0.055,
      g: 0.294,
      b: 0.333,
    );
    _drawText(
      currentStream,
      text: 'I.L.A.W. Framework  •  SENIOR HIGH SCHOOL',
      x: _margin + 16,
      y: headerTop - 32,
      fontSize: 8.5,
      bold: true,
      r: 0.20,
      g: 0.35,
      b: 0.45,
    );

    cursorY = headerBottom;

    // Metadata Table Grid (School, Grade, Teacher, Learning Area, Dates, Term)
    void drawTwoColMeta(String leftKey, String leftVal, String rightKey, String rightVal) {
      final rowH = 22.0;
      ensureSpace(rowH);
      final rTop = cursorY;
      final rBottom = rTop - rowH;
      final midX = _margin + (_contentWidth * 0.5);

      _drawBox(
        currentStream,
        x: _margin,
        y: rBottom,
        w: _contentWidth,
        h: rowH,
        fillR: 1.0,
        fillG: 1.0,
        fillB: 1.0,
        strokeR: _borderR,
        strokeG: _borderG,
        strokeB: _borderB,
        lineWidth: 0.8,
      );

      _drawLine(
        currentStream,
        x1: midX,
        y1: rTop,
        x2: midX,
        y2: rBottom,
        strokeR: _borderR,
        strokeG: _borderG,
        strokeB: _borderB,
        lineWidth: 0.8,
      );

      // Left Meta
      _drawText(currentStream, text: '$leftKey:', x: _margin + 8, y: rTop - 14, fontSize: 8.0, bold: true, r: 0.055, g: 0.294, b: 0.333);
      _drawText(currentStream, text: leftVal, x: _margin + 80, y: rTop - 14, fontSize: 8.0, bold: false, r: 0.08, g: 0.10, b: 0.14);

      // Right Meta
      _drawText(currentStream, text: '$rightKey:', x: midX + 8, y: rTop - 14, fontSize: 8.0, bold: true, r: 0.055, g: 0.294, b: 0.333);
      _drawText(currentStream, text: rightVal, x: midX + 85, y: rTop - 14, fontSize: 8.0, bold: false, r: 0.08, g: 0.10, b: 0.14);

      cursorY = rBottom;
    }

    drawTwoColMeta('School', 'EDUARDO BARRETTO SR. INTEGRATED SCHOOL', 'Grade Level', plan.gradeLevel.toUpperCase());
    drawTwoColMeta('Teacher', teacher.toUpperCase(), 'Learning Area', plan.subject.toUpperCase());
    drawTwoColMeta('Teaching Dates', 'DAY 1 - DAY ${plan.numberOfSessions} (TUESDAY - FRIDAY)', 'Term', '$termUpper (Instructional Block - Week 1)');

    // Lesson Title & Sessions Rows
    final titleLines = _wrapMultiline(plan.topic.toUpperCase(), maxChars: 72);
    drawTableRow(
      categoryTitle: 'Lesson Title',
      contentLines: titleLines,
      minHeight: 24.0,
    );

    final sessionsLabels = List.generate(plan.numberOfSessions, (i) => 'DAY ${i + 1}').join('        ');
    drawTableRow(
      categoryTitle: 'Number of Sessions',
      contentLines: [sessionsLabels],
      minHeight: 22.0,
    );

    // References Row
    final referencesLines = <String>[
      'Curriculum References:',
      '• Department of Education. K to 12 ${plan.subject} Curriculum Guide.',
      '• Department of Education. ${plan.subject} Teacher\'s Guide & Learner\'s Module.',
      'Teacher-Made / Digital Resources:',
      '• PPT Slides & Contextualized Worksheet Exercises.',
      '• Desmos Graphing Calculator/App, Scientific Calculators, Board/Markers.',
    ];
    drawTableRow(
      categoryTitle: 'References',
      categoryPrompt: '(books, websites, toolkits, etc.)',
      contentLines: referencesLines,
    );

    // Declaration of AI Use Row
    final aiCitationLines = _wrapMultiline(
      'Generative AI was used to assist in organizing, wording, and aligning the ILAW lesson-plan components with the teacher-provided materials. The teacher reviewed, revised, and validated the competencies, examples, activities, assessments, and contextualized applications before use in class, consistent with responsible teacher oversight (DepEd Order No. 003, s. 2026 Annex A).',
      maxChars: 68,
    );
    drawTableRow(
      categoryTitle: 'Declaration of AI use',
      categoryPrompt: 'Cite how AI was used in the formulation of the lesson plan. See DO 3 s.2026 Annex A.',
      contentLines: aiCitationLines,
    );

    // =============================================================
    // 2. SECTION I: INTENTIONS
    // =============================================================
    drawBannerRow(
      'INTENTIONS',
      'Meaningful learning experiences are anchored in how we frame them. Start by deciding what you want learners to master by the end of the lesson - keep it clear and simple. Remember: Understanding your learners\' evolving context and designing around it ensure that your lessons connect with and are relevant to them.',
    );

    // Learning Competency & Curriculum Standards
    final compLines = <String>[
      'Content Standard:',
      'The learners demonstrate understanding of key concepts, principles, and representations in ${plan.subject}.',
      '',
      'Performance Standard:',
      'The learners are able to accurately formulate, illustrate, and solve real-life problems involving ${plan.topic}.',
      '',
      'Learning Competencies:',
      if (plan.learningCompetency.trim().isNotEmpty)
        ..._wrapMultiline('• ${plan.learningCompetency.trim()}', maxChars: 66)
      else ...[
        '• Analyzes and represents real-world scenarios through ${plan.topic}.',
        '• Solves practical mathematical and contextual problems with critical reasoning.',
      ],
    ];
    drawTableRow(
      categoryTitle: 'Learning Competency and Curriculum Standards',
      categoryPrompt: 'Write the competency/ies from the curriculum that we are targeting, and applicable standards.',
      contentLines: compLines,
    );

    // Learning Objectives
    final objectivesLines = <String>[
      'By the end of the instructional sessions, learners should be able to:',
      ..._wrapMultiline(plan.intendedOutcomes, maxChars: 66),
    ];
    drawTableRow(
      categoryTitle: 'Learning Objectives',
      categoryPrompt: 'Write the smaller knowledge, skills, or tasks from the competency that learners will work on.',
      contentLines: objectivesLines,
    );

    // Learners Context
    final learnersContextLines = <String>[
      'Learners enter the lesson with prerequisite foundational knowledge. Instruction begins with recall and catch-up activities before formalizing abstract notations.',
      'Contextualized examples (real-life transactions, ride fares, digital data plans) make abstract conditions concrete. Guided scaffolding is provided for emerging learners.',
      'Proficiency Focus: Target diagnostic level set to ${plan.targetProficiency.label}.',
    ];
    drawTableRow(
      categoryTitle: 'Learners Context',
      categoryPrompt: 'Write observations of learners, how they respond, strengths, interests, and barriers to learning.',
      contentLines: learnersContextLines,
    );

    // =============================================================
    // 3. SECTION II: LEARNING EXPERIENCE
    // =============================================================
    drawBannerRow(
      'LEARNING EXPERIENCE',
      'A learning experience is like a thoughtfully designed journey. Each activity and interaction build towards meaningful understanding and growth. Identify activities and interactions to help learners gain knowledge, skills, or understanding in a purposeful way.',
    );

    // Pre-Lesson
    final preLessonLines = <String>[
      '• Begin with a brief check-in and communicate the session learning targets in learner-friendly language.',
      '• Activate prior knowledge through quick concept matching and real-world scenario classification.',
      '• Administer diagnostic catch-up check to identify prerequisites and misconceptions before starting new topics.',
    ];
    drawTableRow(
      categoryTitle: 'Pre-Lesson',
      categoryPrompt: 'Describe how you will help the learners get ready for the lesson.',
      contentLines: preLessonLines,
    );

    // Flow Across Sessions
    final flowLines = <String>[];
    for (final s in plan.effectiveSessions) {
      flowLines.add('Session ${s.sessionNumber} — ${s.sessionTitle}:');
      flowLines.addAll(_wrapMultiline(s.learningExperiences, maxChars: 66));
      flowLines.add('');
    }
    if (flowLines.isEmpty) {
      flowLines.addAll(_wrapMultiline(plan.workExperiences, maxChars: 66));
    }
    drawTableRow(
      categoryTitle: 'Flow',
      categoryPrompt: 'Describe the activities that you can implement in 1 or more sessions to meet the learning objectives.',
      contentLines: flowLines,
    );

    // Differentiation / Inclusion Across Sessions
    final diffLines = <String>[
      '• Use think-pair-share before whole-class sharing to give processing time to all learners.',
      '• Provide worked examples and interval cues for learners needing scaffolding.',
      '• Allow digital tools (Desmos/calculator) and visual diagram representations as acceptable evidence of understanding.',
    ];
    drawTableRow(
      categoryTitle: 'Differentiation / Inclusion',
      categoryPrompt: 'Ensure inclusion for learners\' varied abilities, learning styles, and contexts.',
      contentLines: diffLines,
    );

    // Learning Resources
    final resLines = <String>[
      '• PowerPoint: Lesson slides with interactive checks, worked models, and practice prompts.',
      '• Practice Worksheets: Scaffolding sheets and tiered problem sets.',
      '• Digital and Concrete Tools: Desmos graphing app, whiteboard/markers, graphing paper.',
      '• Offline Alternative: Printed coordinate grids, teacher tables, and board demonstrations.',
    ];
    drawTableRow(
      categoryTitle: 'Learning Resources',
      categoryPrompt: 'List down the learning resources that will help you reach your objectives.',
      contentLines: resLines,
    );

    // Opportunities for Integration
    final integLines = <String>[
      '• ICT / Digital Literacy: Responsible use of graphing tools to visualize and verify relationships.',
      '• Financial Literacy: Interpreting tiered fares, pricing models, data charges, and income tax brackets.',
      '• Communication: Explaining why specific rules apply and justifying solutions in mathematical language.',
      '• Values / Life Skills: Reflecting on rule-based reasoning, fairness, and flexible problem-solving.',
    ];
    drawTableRow(
      categoryTitle: 'Opportunities for Integration',
      categoryPrompt: 'Write down possibilities to meaningfully connect to another learning area, special topic, or technology.',
      contentLines: integLines,
    );

    // =============================================================
    // 4. SECTION III: ASSESSMENT
    // =============================================================
    drawBannerRow(
      'ASSESSMENT',
      'Assessments reveal what learners have gained and what they still need help with. These are helpful in providing you with information to guide your future instruction throughout the entire session.',
    );

    // Formative Assessment per session
    final assessLines = <String>[];
    for (final s in plan.effectiveSessions) {
      assessLines.add('Session ${s.sessionNumber}:');
      assessLines.addAll(_wrapMultiline(s.formativeAssessment, maxChars: 66));
      assessLines.add('');
    }
    if (assessLines.isEmpty) {
      assessLines.addAll(_wrapMultiline(plan.assessment, maxChars: 66));
    }
    drawTableRow(
      categoryTitle: 'Formative Assessment',
      categoryPrompt: 'Create a task, activity or questions to evaluate learning and provide feedback every now and then.',
      contentLines: assessLines,
    );

    // =============================================================
    // 5. SECTION IV: WAYS FORWARD
    // =============================================================
    drawBannerRow(
      'WAYS FORWARD',
      'Meaningful learning can also happen beyond the classroom - for both the learners and the teacher. Pause and reflect on what happened today.',
    );

    // Extended Learning Opportunities
    final extLines = <String>[
      '• Ask learners to identify one real-life service or pricing system at home or in the community that follows conditional rules.',
      '• Provide a short remediation set on prerequisite functions for learners needing additional reinforcement.',
      '• Challenge proficient learners with an enrichment task to model a multi-tier delivery or mobile data pricing scenario.',
    ];
    drawTableRow(
      categoryTitle: 'Extended Learning Opportunities',
      categoryPrompt: 'Suggest other learning experiences outside the classroom/class hours that learners may want to access.',
      contentLines: extLines,
    );

    // Teacher Reflections
    final refLines = <String>[
      '• Review which prerequisite ideas still caused difficulty (boundary points, condition interpretation, intervals).',
      '• Note which contexts generated the strongest participation and reuse familiar situations in future mathematical models.',
      '• Seek instructional coach feedback on multi-tier pacing and strengthening questioning techniques.',
    ];
    drawTableRow(
      categoryTitle: 'Reflections',
      categoryPrompt: 'Think about what you need to change for the next session based on what happened today.',
      contentLines: refLines,
    );

    // =============================================================
    // 6. REMARKS & EVALUATION MATRIX
    // =============================================================
    ensureSpace(120);
    final evalH = 92.0;
    final evalTop = cursorY;
    final evalBottom = evalTop - evalH;

    _drawBox(
      currentStream,
      x: _margin,
      y: evalBottom,
      w: _contentWidth,
      h: evalH,
      fillR: 1.0,
      fillG: 1.0,
      fillB: 1.0,
      strokeR: _borderR,
      strokeG: _borderG,
      strokeB: _borderB,
      lineWidth: 0.8,
    );

    // Left label for REMARKS
    _drawFilledRect(
      currentStream,
      x: _margin + 0.5,
      y: evalBottom + 0.5,
      w: _col1W - 0.5,
      h: evalH - 1.0,
      r: _col1FillR,
      g: _col1FillG,
      b: _col1FillB,
    );
    _drawLine(
      currentStream,
      x1: _margin + _col1W,
      y1: evalTop,
      x2: _margin + _col1W,
      y2: evalBottom,
      strokeR: _borderR,
      strokeG: _borderG,
      strokeB: _borderB,
      lineWidth: 0.8,
    );

    _drawText(
      currentStream,
      text: 'REMARKS',
      x: _margin + 8,
      y: evalTop - 14,
      fontSize: 8.5,
      bold: true,
      r: 0.055,
      g: 0.294,
      b: 0.333,
    );
    _drawText(
      currentStream,
      text: 'Evaluation & Mastery Tracking',
      x: _margin + 8,
      y: evalTop - 26,
      fontSize: 7.0,
      bold: false,
      r: 0.25,
      g: 0.30,
      b: 0.35,
    );

    // Right side evaluation columns: Section 1, Section 2
    final colW = (_col2W) / 4;
    for (int c = 1; c <= 4; c++) {
      _drawLine(
        currentStream,
        x1: _margin + _col1W + (c * colW),
        y1: evalTop,
        x2: _margin + _col1W + (c * colW),
        y2: evalBottom,
        strokeR: _borderR,
        strokeG: _borderG,
        strokeB: _borderB,
        lineWidth: 0.5,
      );
    }

    _drawText(currentStream, text: 'ANDROMEDA', x: _margin + _col1W + 6, y: evalTop - 12, fontSize: 7.0, bold: true, r: 0.055, g: 0.294, b: 0.333);
    _drawText(currentStream, text: 'MILKY WAY', x: _margin + _col1W + colW + 6, y: evalTop - 12, fontSize: 7.0, bold: true, r: 0.055, g: 0.294, b: 0.333);
    _drawText(currentStream, text: 'ORION', x: _margin + _col1W + (colW * 2) + 6, y: evalTop - 12, fontSize: 7.0, bold: true, r: 0.055, g: 0.294, b: 0.333);
    _drawText(currentStream, text: 'PEGASUS', x: _margin + _col1W + (colW * 3) + 6, y: evalTop - 12, fontSize: 7.0, bold: true, r: 0.055, g: 0.294, b: 0.333);

    final scoreLabels = ['Score 5', 'Score 4', 'Score 3', 'Score 2', 'Score 1 / 0', 'MEAN / MPS'];
    var sY = evalTop - 24;
    for (final sl in scoreLabels) {
      _drawText(
        currentStream,
        text: sl,
        x: _margin + 8,
        y: sY - 6,
        fontSize: 6.5,
        bold: false,
        r: 0.25,
        g: 0.30,
        b: 0.35,
      );
      _drawLine(
        currentStream,
        x1: _margin + _col1W,
        y1: sY + 3,
        x2: _margin + _contentWidth,
        y2: sY + 3,
        strokeR: _borderR,
        strokeG: _borderG,
        strokeB: _borderB,
        lineWidth: 0.4,
      );
      sY -= 11;
    }

    cursorY = evalBottom - 18;

    // =============================================================
    // 7. OFFICIAL SIGNATORIES BLOCK
    // =============================================================
    ensureSpace(70);
    final sigColW = _contentWidth / 3;

    // 1. Prepared by
    _drawText(currentStream, text: 'Prepared by:', x: _margin, y: cursorY, fontSize: 8.0, bold: false, r: 0.3, g: 0.35, b: 0.4);
    _drawText(currentStream, text: teacher.toUpperCase(), x: _margin, y: cursorY - 14, fontSize: 8.8, bold: true, r: 0.05, g: 0.08, b: 0.12);
    _drawText(currentStream, text: 'SHS Teacher I', x: _margin, y: cursorY - 24, fontSize: 7.5, bold: false, r: 0.2, g: 0.25, b: 0.3);

    // 2. Checked by
    final sig2X = _margin + sigColW;
    _drawText(currentStream, text: 'Checked by:', x: sig2X, y: cursorY, fontSize: 8.0, bold: false, r: 0.3, g: 0.35, b: 0.4);
    _drawText(currentStream, text: 'BRYAN ANTHONY O. SARIO', x: sig2X, y: cursorY - 14, fontSize: 8.8, bold: true, r: 0.05, g: 0.08, b: 0.12);
    _drawText(currentStream, text: 'Head Teacher II', x: sig2X, y: cursorY - 24, fontSize: 7.5, bold: false, r: 0.2, g: 0.25, b: 0.3);

    // 3. Approved by
    final sig3X = _margin + (sigColW * 2);
    _drawText(currentStream, text: 'Approved by:', x: sig3X, y: cursorY, fontSize: 8.0, bold: false, r: 0.3, g: 0.35, b: 0.4);
    _drawText(currentStream, text: 'SUSAN D. SAMSON', x: sig3X, y: cursorY - 14, fontSize: 8.8, bold: true, r: 0.05, g: 0.08, b: 0.12);
    _drawText(currentStream, text: 'Principal I', x: sig3X, y: cursorY - 24, fontSize: 7.5, bold: false, r: 0.2, g: 0.25, b: 0.3);

    return _assemblePdf(pages);
  }

  // -------------------------------------------------------------
  // Low-Level PDF 1.4 Drawing Primitives
  // -------------------------------------------------------------
  static void _drawText(
    StringBuffer stream, {
    required String text,
    required double x,
    required double y,
    required double fontSize,
    bool bold = false,
    double r = 0.0,
    double g = 0.0,
    double b = 0.0,
  }) {
    final fontName = bold ? '/F2' : '/F1';
    final escaped = _escapePdfString(text);
    stream.writeln('BT');
    stream.writeln('$fontName $fontSize Tf');
    stream.writeln(
      '${r.toStringAsFixed(3)} ${g.toStringAsFixed(3)} ${b.toStringAsFixed(3)} rg',
    );
    stream.writeln('${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} Td');
    stream.writeln('($escaped) Tj');
    stream.writeln('ET');
  }

  static void _drawLine(
    StringBuffer stream, {
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    double strokeR = 0.0,
    double strokeG = 0.0,
    double strokeB = 0.0,
    double lineWidth = 0.8,
  }) {
    stream.writeln(
      '${strokeR.toStringAsFixed(3)} ${strokeG.toStringAsFixed(3)} ${strokeB.toStringAsFixed(3)} RG',
    );
    stream.writeln('$lineWidth w');
    stream.writeln('${x1.toStringAsFixed(2)} ${y1.toStringAsFixed(2)} m');
    stream.writeln('${x2.toStringAsFixed(2)} ${y2.toStringAsFixed(2)} l S');
  }

  static void _drawFilledRect(
    StringBuffer stream, {
    required double x,
    required double y,
    required double w,
    required double h,
    required double r,
    required double g,
    required double b,
  }) {
    stream.writeln(
      '${r.toStringAsFixed(3)} ${g.toStringAsFixed(3)} ${b.toStringAsFixed(3)} rg',
    );
    stream.writeln(
      '${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} ${w.toStringAsFixed(2)} ${h.toStringAsFixed(2)} re f',
    );
  }

  static void _drawBox(
    StringBuffer stream, {
    required double x,
    required double y,
    required double w,
    required double h,
    required double fillR,
    required double fillG,
    required double fillB,
    required double strokeR,
    required double strokeG,
    required double strokeB,
    double lineWidth = 0.8,
  }) {
    stream.writeln(
      '${fillR.toStringAsFixed(3)} ${fillG.toStringAsFixed(3)} ${fillB.toStringAsFixed(3)} rg',
    );
    stream.writeln(
      '${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} ${w.toStringAsFixed(2)} ${h.toStringAsFixed(2)} re f',
    );
    stream.writeln(
      '${strokeR.toStringAsFixed(3)} ${strokeG.toStringAsFixed(3)} ${strokeB.toStringAsFixed(3)} RG',
    );
    stream.writeln('$lineWidth w');
    stream.writeln(
      '${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} ${w.toStringAsFixed(2)} ${h.toStringAsFixed(2)} re S',
    );
  }

  static String _escapePdfString(String input) {
    final sb = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      final code = char.codeUnitAt(0);
      if (code < 32 || code > 126) {
        sb.write(' ');
      } else if (char == '(') {
        sb.write(r'\(');
      } else if (char == ')') {
        sb.write(r'\)');
      } else if (char == '\\') {
        sb.write(r'\\');
      } else {
        sb.write(char);
      }
    }
    return sb.toString();
  }

  static List<String> _wrapMultiline(String text, {int maxChars = 75}) {
    final lines = <String>[];
    for (final rawLine in text.replaceAll('\r\n', '\n').split('\n')) {
      final trimmed = rawLine.trimRight();
      if (trimmed.isEmpty) {
        lines.add('');
      } else {
        lines.addAll(_wrapText(trimmed, maxChars: maxChars));
      }
    }
    return lines;
  }

  static List<String> _wrapText(String line, {int maxChars = 75}) {
    if (line.length <= maxChars) return [line];
    final words = line.split(' ');
    final results = <String>[];
    var current = StringBuffer();

    for (final w in words) {
      if (current.isEmpty) {
        current.write(w);
      } else if (current.length + 1 + w.length <= maxChars) {
        current.write(' ');
        current.write(w);
      } else {
        results.add(current.toString());
        current = StringBuffer(w);
      }
    }
    if (current.isNotEmpty) {
      results.add(current.toString());
    }
    return results;
  }

  static Uint8List _assemblePdf(List<StringBuffer> pageStreams) {
    final bytes = BytesBuilder();
    final offsets = <int>[];

    void writeAscii(String s) {
      bytes.add(ascii.encode(s));
    }

    writeAscii('%PDF-1.4\n');

    int objIndex = 1;

    offsets.add(bytes.length);
    writeAscii('$objIndex 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');
    objIndex++;

    offsets.add(bytes.length);
    final pageRefList = StringBuffer();
    for (var i = 0; i < pageStreams.length; i++) {
      final pNum = 5 + (i * 2);
      pageRefList.write('$pNum 0 R ');
    }
    writeAscii(
      '$objIndex 0 obj\n<< /Type /Pages /Kids [ $pageRefList] /Count ${pageStreams.length} >>\nendobj\n',
    );
    objIndex++;

    offsets.add(bytes.length);
    writeAscii(
      '$objIndex 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n',
    );
    objIndex++;

    offsets.add(bytes.length);
    writeAscii(
      '$objIndex 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n',
    );
    objIndex++;

    for (var i = 0; i < pageStreams.length; i++) {
      final contentObjNum = 6 + (i * 2);
      offsets.add(bytes.length);
      writeAscii(
        '$objIndex 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $_pageWidth $_pageHeight] /Contents $contentObjNum 0 R /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> >>\nendobj\n',
      );
      objIndex++;

      final streamContent = pageStreams[i].toString();
      final streamBytes = ascii.encode(streamContent);
      offsets.add(bytes.length);
      writeAscii('$objIndex 0 obj\n<< /Length ${streamBytes.length} >>\nstream\n');
      bytes.add(streamBytes);
      writeAscii('\nendstream\nendobj\n');
      objIndex++;
    }

    final xrefStart = bytes.length;
    final totalObjects = objIndex;
    writeAscii('xref\n0 $totalObjects\n');
    writeAscii('0000000000 65535 f \n');
    for (final off in offsets) {
      final offStr = off.toString().padLeft(10, '0');
      writeAscii('$offStr 00000 n \n');
    }

    writeAscii(
      'trailer\n<< /Size $totalObjects /Root 1 0 R >>\nstartxref\n$xrefStart\n%%EOF',
    );

    return bytes.toBytes();
  }
}
