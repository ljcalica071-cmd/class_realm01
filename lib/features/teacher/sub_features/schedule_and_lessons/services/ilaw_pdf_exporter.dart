import 'dart:convert';
import 'dart:typed_data';

import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/models/ilaw_lesson_plan.dart';

/// Pure-Dart multi-page PDF 1.4 generator for the minimalist Senior High School
/// (SHS) New Curriculum iLAW Lesson Plan format.
///
/// Requires zero third-party native or pubspec dependencies while generating
/// standards-compliant `%PDF-1.4` binary files with accurate `xref` offsets,
/// automatic word-wrapping, multi-page pagination, and safe PDF escaping.
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
    final strategy = plan.teachingStrategy.trim().isNotEmpty
        ? plan.teachingStrategy.trim()
        : 'Collaborative / Inquiry-Based';
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
      text: 'DEPARTMENT OF EDUCATION  |  SENIOR HIGH SCHOOL NEW CURRICULUM',
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
      text: 'iLAW LESSON PLAN',
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
        76.0 +
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
    final colRight = _margin + (_contentWidth * 0.54);
    double metaY = boxTop - 16;

    _drawKeyValue(
      currentStream,
      'Subject:',
      _truncate(plan.subject, 34),
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
    metaY -= 16;

    _drawKeyValue(
      currentStream,
      'Topic:',
      _truncate(plan.topic, 36),
      colLeft,
      metaY,
    );
    _drawKeyValue(
      currentStream,
      'Duration:',
      '${plan.durationMinutes} Minutes',
      colRight,
      metaY,
    );
    metaY -= 16;

    _drawKeyValue(
      currentStream,
      'Teacher:',
      _truncate(teacher, 34),
      colLeft,
      metaY,
    );
    _drawKeyValue(currentStream, 'Date:', dateStr, colRight, metaY);
    metaY -= 16;

    _drawKeyValue(
      currentStream,
      'Approach:',
      _truncate(strategy, 34),
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

    if (competencyLines.isNotEmpty) {
      metaY -= 16;
      for (final cLine in competencyLines) {
        _drawText(
          currentStream,
          text: cLine,
          x: colLeft,
          y: metaY,
          fontSize: 9.2,
          bold: false,
          r: 0.118,
          g: 0.161,
          b: 0.231,
        );
        metaY -= 13;
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
          fontSize: 10.0,
          bold: false,
          r: 0.118,
          g: 0.161,
          b: 0.231,
        );
        cursorY -= 14.5;
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
      fontSize: 9.0,
      bold: false,
      r: 0.278,
      g: 0.333,
      b: 0.412,
    );

    // Add page numbers at the bottom of every page
    final totalPages = pages.length;
    for (var i = 0; i < totalPages; i++) {
      _drawText(
        pages[i],
        text: 'ClassRealm SHS iLAW Format  |  Page ${i + 1} of $totalPages',
        x: _margin,
        y: 28,
        fontSize: 8.2,
        bold: false,
        r: 0.580,
        g: 0.639,
        b: 0.722,
      );
    }

    return _assemblePdfDocument(pages.map((p) => p.toString()).toList());
  }

  static void _drawKeyValue(
    StringBuffer stream,
    String label,
    String value,
    double x,
    double y,
  ) {
    _drawText(
      stream,
      text: label,
      x: x,
      y: y,
      fontSize: 9.2,
      bold: true,
      r: 0.278,
      g: 0.333,
      b: 0.412,
    );
    final labelOffset = (label.length * 4.8) + 6;
    _drawText(
      stream,
      text: value,
      x: x + labelOffset,
      y: y,
      fontSize: 9.5,
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
      'q ${r.toStringAsFixed(3)} ${g.toStringAsFixed(3)} ${b.toStringAsFixed(3)} rg '
      '${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} ${w.toStringAsFixed(2)} ${h.toStringAsFixed(2)} re f Q',
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
  }) {
    stream.writeln(
      'q 0.75 w '
      '${fillR.toStringAsFixed(3)} ${fillG.toStringAsFixed(3)} ${fillB.toStringAsFixed(3)} rg '
      '${strokeR.toStringAsFixed(3)} ${strokeG.toStringAsFixed(3)} ${strokeB.toStringAsFixed(3)} RG '
      '${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} ${w.toStringAsFixed(2)} ${h.toStringAsFixed(2)} re B Q',
    );
  }

  static void _drawText(
    StringBuffer stream, {
    required String text,
    required double x,
    required double y,
    required double fontSize,
    required bool bold,
    required double r,
    required double g,
    required double b,
  }) {
    final fontRef = bold ? '/F2' : '/F1';
    final escaped = escapePdfText(text);
    stream.writeln(
      'BT $fontRef ${fontSize.toStringAsFixed(1)} Tf '
      '${r.toStringAsFixed(3)} ${g.toStringAsFixed(3)} ${b.toStringAsFixed(3)} rg '
      '1 0 0 1 ${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} Tm ($escaped) Tj ET',
    );
  }

  static String escapePdfText(String raw) {
    final normalized = raw
        .replaceAll('•', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('≠', '!=')
        .replaceAll('≤', '<=')
        .replaceAll('≥', '>=')
        .replaceAll('×', 'x')
        .replaceAll('÷', '/');

    final sb = StringBuffer();
    for (final rune in normalized.runes) {
      if (rune < 32 || rune == 127) {
        continue;
      }
      if (rune == 0x5C) {
        sb.write(r'\\');
      } else if (rune == 0x28) {
        sb.write(r'\(');
      } else if (rune == 0x29) {
        sb.write(r'\)');
      } else if (rune <= 255) {
        sb.writeCharCode(rune);
      } else {
        sb.write('?');
      }
    }
    return sb.toString();
  }

  static List<String> _wrapMultiline(String content, {required int maxChars}) {
    final rawLines = content.replaceAll('\r\n', '\n').split('\n');
    final out = <String>[];
    for (final line in rawLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        out.add('');
        continue;
      }
      out.addAll(_wrapText(trimmed, maxChars: maxChars));
    }
    return out;
  }

  static List<String> _wrapText(String line, {required int maxChars}) {
    if (line.length <= maxChars) return [line];
    final words = line.split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      if (word.length > maxChars) {
        if (current.isNotEmpty) {
          lines.add(current);
          current = '';
        }
        var rest = word;
        while (rest.length > maxChars) {
          lines.add(rest.substring(0, maxChars));
          rest = rest.substring(maxChars);
        }
        current = rest;
      } else if (current.isEmpty) {
        current = word;
      } else if (current.length + 1 + word.length <= maxChars) {
        current = '$current $word';
      } else {
        lines.add(current);
        current = '   $word';
      }
    }
    if (current.isNotEmpty) {
      lines.add(current);
    }
    return lines;
  }

  static String _truncate(String input, int maxLen) {
    final clean = input.trim();
    if (clean.length <= maxLen) return clean;
    return '${clean.substring(0, maxLen - 3)}...';
  }

  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static Uint8List _assemblePdfDocument(List<String> pageStreams) {
    // Object numbering:
    // 1: Catalog
    // 2: Pages
    // 3: Font F1 (Helvetica)
    // 4: Font F2 (Helvetica-Bold)
    // For each page i (0..N-1):
    //   pageObjId = 5 + (i * 2)
    //   contentObjId = 6 + (i * 2)
    final totalObjects = 4 + (pageStreams.length * 2);
    final offsets = List<int>.filled(totalObjects + 1, 0);
    final bytes = BytesBuilder();

    void writeStr(String s) {
      bytes.add(latin1.encode(s));
    }

    writeStr('%PDF-1.4\n');

    void beginObj(int id) {
      offsets[id] = bytes.length;
      writeStr('$id 0 obj\n');
    }

    void endObj() {
      writeStr('endobj\n');
    }

    beginObj(1);
    writeStr('<< /Type /Catalog /Pages 2 0 R >>\n');
    endObj();

    final kidsRefs = List.generate(
      pageStreams.length,
      (i) => '${5 + (i * 2)} 0 R',
    ).join(' ');
    beginObj(2);
    writeStr(
      '<< /Type /Pages /Kids [ $kidsRefs ] /Count ${pageStreams.length} >>\n',
    );
    endObj();

    beginObj(3);
    writeStr(
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>\n',
    );
    endObj();

    beginObj(4);
    writeStr(
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>\n',
    );
    endObj();

    for (var i = 0; i < pageStreams.length; i++) {
      final pageObjId = 5 + (i * 2);
      final contentObjId = 6 + (i * 2);
      final streamBytes = latin1.encode(pageStreams[i]);

      beginObj(pageObjId);
      writeStr(
        '<< /Type /Page /Parent 2 0 R '
        '/MediaBox [ 0 0 ${_pageWidth.toStringAsFixed(2)} ${_pageHeight.toStringAsFixed(2)} ] '
        '/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> '
        '/Contents $contentObjId 0 R >>\n',
      );
      endObj();

      beginObj(contentObjId);
      writeStr('<< /Length ${streamBytes.length} >>\nstream\n');
      bytes.add(streamBytes);
      writeStr('\nendstream\n');
      endObj();
    }

    final xrefOffset = bytes.length;
    writeStr('xref\n');
    writeStr('0 ${totalObjects + 1}\n');
    writeStr('0000000000 65535 f \n');
    for (var id = 1; id <= totalObjects; id++) {
      final padded = offsets[id].toString().padLeft(10, '0');
      writeStr('$padded 00000 n \n');
    }

    writeStr('trailer\n');
    writeStr('<< /Size ${totalObjects + 1} /Root 1 0 R >>\n');
    writeStr('startxref\n');
    writeStr('$xrefOffset\n');
    writeStr('%%EOF\n');

    return bytes.toBytes();
  }
}
