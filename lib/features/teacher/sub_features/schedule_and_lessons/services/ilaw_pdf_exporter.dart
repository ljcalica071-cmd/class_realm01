import 'dart:convert';
import 'dart:typed_data';

import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/models/ilaw_lesson_plan.dart';

/// Pure-Dart multi-page PDF 1.4 generator for the DepEd Senior High School
/// (SHS) Strengthened Curriculum iLAW Modified Lesson Plan format.
///
/// Generates standards-compliant `%PDF-1.4` binary files with accurate `xref`
/// offsets, automatic word-wrapping, multi-session matrices, self-check rubrics,
/// and safe PDF string escaping.
class IlawPdfExporter {
  static const double _pageWidth = 595.28; // A4 width in points
  static const double _pageHeight = 841.89; // A4 height in points
  static const double _margin = 52.0;
  static const double _contentWidth = _pageWidth - (_margin * 2);
  static const double _bottomLimit = 62.0;

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
        : 'Subject Teacher';
    final dateStr = _formatDate(plan.updatedAt);

    // Top Steel-Blue Minimalist Accent Rule (#487898 -> 0.282, 0.471, 0.596)
    _drawFilledRect(
      currentStream,
      x: _margin,
      y: cursorY - 3,
      w: _contentWidth,
      h: 3,
      r: 0.282,
      g: 0.471,
      b: 0.596,
    );
    cursorY -= 18;

    _drawText(
      currentStream,
      text:
          'REPUBLIC OF THE PHILIPPINES  |  DEPARTMENT OF EDUCATION  |  SHS CURRICULUM',
      x: _margin,
      y: cursorY,
      fontSize: 8.5,
      bold: true,
      r: 0.278,
      g: 0.333,
      b: 0.412,
    );
    cursorY -= 18;

    _drawText(
      currentStream,
      text: 'iLAW LESSON PLAN (MODIFIED DEPED 2026)',
      x: _margin,
      y: cursorY,
      fontSize: 16,
      bold: true,
      r: 0.067,
      g: 0.094,
      b: 0.153,
    );
    cursorY -= 16;

    // Metadata Card Box
    final competencyLines = plan.learningCompetency.trim().isNotEmpty
        ? _wrapText(
            'Competency: ${plan.learningCompetency.trim()}',
            maxChars: 86,
          )
        : const <String>[];
    final metaBoxHeight =
        100.0 +
        (competencyLines.isNotEmpty
            ? (competencyLines.length * 13.0 + 8.0)
            : 0.0);

    ensureSpace(metaBoxHeight + 12);
    final boxTop = cursorY;
    final boxBottom = boxTop - metaBoxHeight;
    _drawBox(
      currentStream,
      x: _margin,
      y: boxBottom,
      w: _contentWidth,
      h: metaBoxHeight,
      fillR: 0.973,
      fillG: 0.980,
      fillB: 0.988,
      strokeR: 0.796,
      strokeG: 0.835,
      strokeB: 0.882,
    );

    final colLeft = _margin + 12;
    final colRight = _margin + (_contentWidth * 0.52);
    double metaY = boxTop - 16;

    _drawKeyValue(
      currentStream,
      'Subject:',
      _truncate(plan.subject, 32),
      colLeft,
      metaY,
    );
    _drawKeyValue(
      currentStream,
      'Grade & Quarter:',
      '${plan.gradeLevel} - ${plan.quarter}',
      colRight,
      metaY,
    );
    metaY -= 15;

    _drawKeyValue(
      currentStream,
      'Topic:',
      _truncate(plan.topic, 34),
      colLeft,
      metaY,
    );
    _drawKeyValue(
      currentStream,
      'Duration & Sessions:',
      '${plan.durationMinutes}m  •  ${plan.numberOfSessions} Sessions',
      colRight,
      metaY,
    );
    metaY -= 15;

    _drawKeyValue(
      currentStream,
      'Proficiency Target:',
      plan.targetProficiency.label,
      colLeft,
      metaY,
    );
    _drawKeyValue(
      currentStream,
      'Status:',
      plan.isApproved ? 'Approved' : 'Draft',
      colRight,
      metaY,
    );
    metaY -= 15;

    _drawKeyValue(
      currentStream,
      'Prepared By:',
      _truncate(teacher, 32),
      colLeft,
      metaY,
    );
    _drawKeyValue(currentStream, 'Date:', dateStr, colRight, metaY);
    metaY -= 15;

    _drawKeyValue(
      currentStream,
      'AI Governance:',
      _truncate(plan.depedOrderCitation, 70),
      colLeft,
      metaY,
    );

    if (competencyLines.isNotEmpty) {
      metaY -= 15;
      for (final cLine in competencyLines) {
        _drawText(
          currentStream,
          text: cLine,
          x: colLeft,
          y: metaY,
          fontSize: 9.0,
          bold: false,
          r: 0.118,
          g: 0.161,
          b: 0.231,
        );
        metaY -= 12;
      }
    }

    cursorY = boxBottom - 18;

    void writeIlawSection(String code, String title, String content) {
      ensureSpace(46);

      // Section Header Bar
      final headerH = 22.0;
      final headerBottom = cursorY - headerH;
      _drawFilledRect(
        currentStream,
        x: _margin,
        y: headerBottom,
        w: _contentWidth,
        h: headerH,
        r: 0.945,
        g: 0.961,
        b: 0.976,
      );
      _drawFilledRect(
        currentStream,
        x: _margin,
        y: headerBottom,
        w: 3.5,
        h: headerH,
        r: 0.282,
        g: 0.471,
        b: 0.596,
      );
      _drawText(
        currentStream,
        text: '$code.  $title',
        x: _margin + 12,
        y: headerBottom + 7,
        fontSize: 10.2,
        bold: true,
        r: 0.118,
        g: 0.161,
        b: 0.231,
      );
      cursorY = headerBottom - 14;

      final wrappedLines = _wrapMultiline(content, maxChars: 86);
      for (final line in wrappedLines) {
        if (line.isEmpty) {
          cursorY -= 6;
          continue;
        }
        ensureSpace(16);
        _drawText(
          currentStream,
          text: line,
          x: _margin + 10,
          y: cursorY,
          fontSize: 9.8,
          bold: false,
          r: 0.118,
          g: 0.161,
          b: 0.231,
        );
        cursorY -= 14.0;
      }

      // Subtle section divider
      cursorY -= 4;
      _drawFilledRect(
        currentStream,
        x: _margin,
        y: cursorY,
        w: _contentWidth,
        h: 0.6,
        r: 0.886,
        g: 0.910,
        b: 0.941,
      );
      cursorY -= 14;
    }

    writeIlawSection(
      'I',
      'INTENDED LEARNING OUTCOMES (OBJECTIVES)',
      plan.intendedOutcomes,
    );
    writeIlawSection('L', 'LEARNING CONTENT & RESOURCES', plan.learningContent);
    writeIlawSection('A', 'ASSESSMENT & LEARNING ACTIVITIES', plan.assessment);
    writeIlawSection(
      'W',
      'WORK / LEARNING EXPERIENCES (PROCEDURE)',
      plan.workExperiences,
    );

    // Multi-Session Detailed Matrix
    if (plan.effectiveSessions.isNotEmpty) {
      ensureSpace(40);
      _drawText(
        currentStream,
        text: 'MULTI-SESSION INSTRUCTIONAL DELIVERY MATRIX',
        x: _margin,
        y: cursorY,
        fontSize: 11.5,
        bold: true,
        r: 0.059,
        g: 0.090,
        b: 0.165,
      );
      cursorY -= 16;

      for (final s in plan.effectiveSessions) {
        ensureSpace(60);
        _drawFilledRect(
          currentStream,
          x: _margin,
          y: cursorY - 18,
          w: _contentWidth,
          h: 18,
          r: 0.937,
          g: 0.965,
          b: 1.0,
        );
        _drawText(
          currentStream,
          text: s.sessionTitle,
          x: _margin + 8,
          y: cursorY - 13,
          fontSize: 9.5,
          bold: true,
          r: 0.118,
          g: 0.227,
          b: 0.541,
        );
        cursorY -= 26;

        void writeSubField(String label, String content) {
          ensureSpace(24);
          _drawText(
            currentStream,
            text: '$label:',
            x: _margin + 8,
            y: cursorY,
            fontSize: 9.0,
            bold: true,
            r: 0.278,
            g: 0.333,
            b: 0.412,
          );
          cursorY -= 12;
          final lines = _wrapMultiline(content, maxChars: 82);
          for (final l in lines) {
            ensureSpace(14);
            _drawText(
              currentStream,
              text: l,
              x: _margin + 16,
              y: cursorY,
              fontSize: 8.8,
              bold: false,
              r: 0.118,
              g: 0.161,
              b: 0.231,
            );
            cursorY -= 12.0;
          }
          cursorY -= 4;
        }

        writeSubField('Objectives', s.objectives);
        writeSubField('Learning Experiences', s.learningExperiences);
        writeSubField('Formative Assessment', s.formativeAssessment);
        writeSubField('Parent Guide', s.parentGuide);
        writeSubField('Community Experience', s.communityExperience);
        writeSubField('Teacher Reflections', s.teacherReflections);
        cursorY -= 10;
      }
    }

    // Rubric Table
    if (plan.effectiveRubrics.isNotEmpty) {
      ensureSpace(40);
      _drawText(
        currentStream,
        text: 'Rubric for Lesson Planning Self-Check and/or Peer Coaching',
        x: _margin,
        y: cursorY,
        fontSize: 11.5,
        bold: true,
        r: 0.059,
        g: 0.090,
        b: 0.165,
      );
      cursorY -= 16;

      for (final r in plan.effectiveRubrics) {
        ensureSpace(24);
        final status = r.isMet ? '[X] Met' : '[ ] Not Yet';
        _drawText(
          currentStream,
          text: '$status  ${r.criterion}',
          x: _margin + 8,
          y: cursorY,
          fontSize: 8.8,
          bold: r.isMet,
          r: r.isMet ? 0.086 : 0.600,
          g: r.isMet ? 0.396 : 0.106,
          b: r.isMet ? 0.204 : 0.106,
        );
        cursorY -= 14;
        if (r.notes.isNotEmpty) {
          _drawText(
            currentStream,
            text: '     Notes: ${r.notes}',
            x: _margin + 16,
            y: cursorY,
            fontSize: 8.2,
            bold: false,
            r: 0.392,
            g: 0.455,
            b: 0.545,
          );
          cursorY -= 12;
        }
      }
      cursorY -= 10;
    }

    // Signature Block
    ensureSpace(68);
    cursorY -= 14;
    _drawText(
      currentStream,
      text: 'Prepared and Approved by:',
      x: _margin,
      y: cursorY,
      fontSize: 9.5,
      bold: false,
      r: 0.392,
      g: 0.455,
      b: 0.545,
    );
    cursorY -= 26;
    _drawFilledRect(
      currentStream,
      x: _margin,
      y: cursorY + 10,
      w: 190,
      h: 0.7,
      r: 0.580,
      g: 0.639,
      b: 0.722,
    );
    _drawText(
      currentStream,
      text: teacher.toUpperCase(),
      x: _margin,
      y: cursorY - 2,
      fontSize: 10.5,
      bold: true,
      r: 0.067,
      g: 0.094,
      b: 0.153,
    );
    cursorY -= 14;
    _drawText(
      currentStream,
      text: 'Senior High School Subject Teacher',
      x: _margin,
      y: cursorY,
      fontSize: 8.5,
      bold: false,
      r: 0.278,
      g: 0.333,
      b: 0.412,
    );

    return _assemblePdf(pages);
  }

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

  static void _drawKeyValue(
    StringBuffer stream,
    String key,
    String value,
    double x,
    double y,
  ) {
    _drawText(
      stream,
      text: key,
      x: x,
      y: y,
      fontSize: 8.8,
      bold: true,
      r: 0.278,
      g: 0.333,
      b: 0.412,
    );
    final keyOffset = (key.length * 5.2).clamp(42.0, 110.0);
    _drawText(
      stream,
      text: value,
      x: x + keyOffset,
      y: y,
      fontSize: 8.8,
      bold: false,
      r: 0.067,
      g: 0.094,
      b: 0.153,
    );
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

  static List<String> _wrapMultiline(String text, {int maxChars = 84}) {
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

  static List<String> _wrapText(String line, {int maxChars = 84}) {
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

  static String _truncate(String s, int maxLen) {
    final trimmed = s.trim();
    if (trimmed.length <= maxLen) return trimmed;
    return '${trimmed.substring(0, maxLen - 1)}…';
  }

  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
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
