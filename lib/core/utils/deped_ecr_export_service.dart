import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:archive/archive.dart';

import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/features/teacher/sub_features/setup/widgets/teacher_classroom_setup_templates.dart';
import 'package:class_realm/core/utils/file_download_helper.dart';

/// Service that exports official DepEd Order 15, series of 2026
/// Electronic-Class Record (ECR) spreadsheets for Strengthened SHS.
///
/// Modifies the official DepEd template (`deped_sshs_ecr_template.xlsx`)
/// by injecting teacher data, learners' names, highest possible scores (HPS),
/// and student raw scores directly into the OpenXML worksheet XMLs while preserving
/// 100% of the native formulas, styles, layouts, logos, and data validations.
class DepEdEcrExportService {
  static const String templateAssetPath =
      'assets/templates/deped_sshs_ecr_template.xlsx';

  /// Check whether a subject matches an official Strengthened SHS template subject.
  static SubjectTemplate? findMatchingTemplate(String? subjectName) {
    if (subjectName == null || subjectName.trim().isEmpty) return null;
    final clean = subjectName.trim().toLowerCase();
    for (final template in defaultSubjectTemplates) {
      if (template.name.trim().toLowerCase() == clean) {
        return template;
      }
    }
    return null;
  }

  /// Returns true if the subject is an official DepEd template subject.
  static bool isTemplateSubject(String? subjectName) {
    return findMatchingTemplate(subjectName) != null;
  }

  /// Formats a student's name into: `LASTNAME, Firstname Middlename` (or M.).
  static String formatLearnerName(UserModel s) {
    final last = (s.lastName ?? '').trim().toUpperCase();
    final first = (s.firstName ?? '').trim();
    final middle = (s.middleName ?? '').trim();
    if (last.isEmpty && first.isEmpty) return s.fullName.trim();
    if (middle.isEmpty) return '$last, $first';
    return '$last, $first $middle';
  }

  /// Exports the pre-filled DepEd E-Class Record (.xlsx) file and triggers download.
  static Future<String?> exportEcr({
    required String teacherName,
    required String subjectName,
    required String sectionName,
    required dynamic gradeLevel,
    required List<UserModel> maleStudents,
    required List<UserModel> femaleStudents,
    required Map<int, Map<String, Map<int, double?>>> termHps,
    required Map<int, Map<String, Map<String, Map<int, double?>>>> termScores,
    String? schoolYear,
  }) async {
    final template = findMatchingTemplate(subjectName);
    if (template == null) {
      throw UnsupportedError(
        'Official DepEd ECR export is only available for standard Strengthened SHS template subjects.',
      );
    }

    // 1. Load official template asset
    final ByteData assetData = await rootBundle.load(templateAssetPath);
    final srcArchive = ZipDecoder().decodeBytes(assetData.buffer.asUint8List());

    // 2. Parse Grade Level
    int parsedGradeLevel = 11;
    final glStr = gradeLevel?.toString() ?? '';
    if (glStr.contains('12')) {
      parsedGradeLevel = 12;
    }

    // 3. Resolve Teacher Name
    final cleanTeacherName = teacherName.trim().toUpperCase();

    // 4. Sort learners alphabetically by Last Name
    final sortedMales = List<UserModel>.from(maleStudents)..sort((a, b) {
      final nameA = (a.lastName ?? a.fullName).toLowerCase();
      final nameB = (b.lastName ?? b.fullName).toLowerCase();
      return nameA.compareTo(nameB);
    });

    final sortedFemales = List<UserModel>.from(femaleStudents)..sort((a, b) {
      final nameA = (a.lastName ?? a.fullName).toLowerCase();
      final nameB = (b.lastName ?? b.fullName).toLowerCase();
      return nameA.compareTo(nameB);
    });

    final modifiedXmlFiles = <String, String>{};

    // 5. Update INPUT DATA sheet (xl/worksheets/sheet2.xml)
    final sheet2File = srcArchive.findFile('xl/worksheets/sheet2.xml');
    if (sheet2File != null) {
      var sheet2Xml = utf8.decode(sheet2File.content as List<int>);

      // Basic Information
      sheet2Xml = _updateStringCell(sheet2Xml, 'F22', cleanTeacherName);
      sheet2Xml = _updateNumericCell(sheet2Xml, 'F24', parsedGradeLevel);
      sheet2Xml = _updateStringCell(sheet2Xml, 'F25', sectionName.trim());

      // Subject Info under Strengthened SHS
      sheet2Xml = _updateStringCell(sheet2Xml, 'F28', template.category);
      sheet2Xml = _updateStringCell(sheet2Xml, 'F29', template.cluster);
      sheet2Xml = _updateStringCell(sheet2Xml, 'F30', template.name);

      // Term Block for 1 or 2 term electives
      if (template.termsTaught < 3) {
        final block = template.termBlock.toUpperCase();
        final String resolvedBlock;
        if (block.contains('SECOND') || block.contains('2ND')) {
          resolvedBlock = 'SECOND TERM';
        } else if (block.contains('THIRD') || block.contains('3RD')) {
          resolvedBlock = 'THIRD TERM';
        } else {
          resolvedBlock = 'FIRST TERM';
        }
        sheet2Xml = _updateStringCell(sheet2Xml, 'H33', resolvedBlock);
      }

      // Male Learners (Rows 11 to 60)
      for (int i = 0; i < 50; i++) {
        final row = 11 + i;
        if (i < sortedMales.length) {
          final s = sortedMales[i];
          final lrn = (s.lrn ?? '').trim();
          final name = formatLearnerName(s);
          sheet2Xml = _updateStringCell(sheet2Xml, 'N$row', lrn);
          sheet2Xml = _updateStringCell(sheet2Xml, 'O$row', name);
        } else {
          sheet2Xml = _updateStringCell(sheet2Xml, 'N$row', '');
          sheet2Xml = _updateStringCell(sheet2Xml, 'O$row', '');
        }
      }

      // Female Learners (Rows 11 to 60)
      for (int i = 0; i < 50; i++) {
        final row = 11 + i;
        if (i < sortedFemales.length) {
          final s = sortedFemales[i];
          final lrn = (s.lrn ?? '').trim();
          final name = formatLearnerName(s);
          sheet2Xml = _updateStringCell(sheet2Xml, 'R$row', lrn);
          sheet2Xml = _updateStringCell(sheet2Xml, 'S$row', name);
        } else {
          sheet2Xml = _updateStringCell(sheet2Xml, 'R$row', '');
          sheet2Xml = _updateStringCell(sheet2Xml, 'S$row', '');
        }
      }

      modifiedXmlFiles['xl/worksheets/sheet2.xml'] = sheet2Xml;
    }

    // 6. Update Term Sheets (Term 1: sheet3.xml, Term 2: sheet4.xml, Term 3: sheet5.xml)
    final termSheetPaths = {
      1: 'xl/worksheets/sheet3.xml',
      2: 'xl/worksheets/sheet4.xml',
      3: 'xl/worksheets/sheet5.xml',
    };

    const wwColLetters = ['D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M'];
    const ptColLetters = ['Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'];
    const exColLetters = ['AD', 'AE', 'AF']; // ST 1, ST 2, TE

    for (final entry in termSheetPaths.entries) {
      final termNumber = entry.key;
      final sheetPath = entry.value;
      final termFile = srcArchive.findFile(sheetPath);
      if (termFile == null) continue;

      var termXml = utf8.decode(termFile.content as List<int>);

      final hpsMap = termHps[termNumber];
      final scoresMap = termScores[termNumber];

      // A. Populate Highest Possible Scores (Row 14)
      if (hpsMap != null) {
        // WW 1..10
        final wwHps = hpsMap['ww'] ?? {};
        for (int col = 0; col < 10; col++) {
          final val = wwHps[col];
          termXml = _updateNumericCell(termXml, '${wwColLetters[col]}14', val);
        }

        // PT 1..10
        final ptHps = hpsMap['pt'] ?? {};
        for (int col = 0; col < 10; col++) {
          final val = ptHps[col];
          termXml = _updateNumericCell(termXml, '${ptColLetters[col]}14', val);
        }

        // EX (ST 1, ST 2, TE)
        final exHps = hpsMap['ex'] ?? {};
        for (int col = 0; col < 3; col++) {
          final val = exHps[col];
          termXml = _updateNumericCell(termXml, '${exColLetters[col]}14', val);
        }
      }

      // B. Populate Male Learners' Scores (Rows 17 to 66)
      for (int i = 0; i < 50; i++) {
        final row = 17 + i;
        if (i < sortedMales.length && scoresMap != null) {
          final sId = sortedMales[i].id;
          final sScores = scoresMap[sId];

          final sWw = sScores?['ww'] ?? {};
          for (int col = 0; col < 10; col++) {
            final val = sWw[col];
            termXml = _updateNumericCell(termXml, '${wwColLetters[col]}$row', val);
          }

          final sPt = sScores?['pt'] ?? {};
          for (int col = 0; col < 10; col++) {
            final val = sPt[col];
            termXml = _updateNumericCell(termXml, '${ptColLetters[col]}$row', val);
          }

          final sEx = sScores?['ex'] ?? {};
          for (int col = 0; col < 3; col++) {
            final val = sEx[col];
            termXml = _updateNumericCell(termXml, '${exColLetters[col]}$row', val);
          }
        } else {
          // Clear scores for unused rows
          for (int col = 0; col < 10; col++) {
            termXml = _updateNumericCell(termXml, '${wwColLetters[col]}$row', null);
            termXml = _updateNumericCell(termXml, '${ptColLetters[col]}$row', null);
          }
          for (int col = 0; col < 3; col++) {
            termXml = _updateNumericCell(termXml, '${exColLetters[col]}$row', null);
          }
        }
      }

      // C. Populate Female Learners' Scores (Rows 68 to 117)
      for (int i = 0; i < 50; i++) {
        final row = 68 + i;
        if (i < sortedFemales.length && scoresMap != null) {
          final sId = sortedFemales[i].id;
          final sScores = scoresMap[sId];

          final sWw = sScores?['ww'] ?? {};
          for (int col = 0; col < 10; col++) {
            final val = sWw[col];
            termXml = _updateNumericCell(termXml, '${wwColLetters[col]}$row', val);
          }

          final sPt = sScores?['pt'] ?? {};
          for (int col = 0; col < 10; col++) {
            final val = sPt[col];
            termXml = _updateNumericCell(termXml, '${ptColLetters[col]}$row', val);
          }

          final sEx = sScores?['ex'] ?? {};
          for (int col = 0; col < 3; col++) {
            final val = sEx[col];
            termXml = _updateNumericCell(termXml, '${exColLetters[col]}$row', val);
          }
        } else {
          // Clear scores for unused rows
          for (int col = 0; col < 10; col++) {
            termXml = _updateNumericCell(termXml, '${wwColLetters[col]}$row', null);
            termXml = _updateNumericCell(termXml, '${ptColLetters[col]}$row', null);
          }
          for (int col = 0; col < 3; col++) {
            termXml = _updateNumericCell(termXml, '${exColLetters[col]}$row', null);
          }
        }
      }

      modifiedXmlFiles[sheetPath] = termXml;
    }

    // 7. Ensure <calcPr fullCalcOnLoad="1"/> in xl/workbook.xml
    final workbookFile = srcArchive.findFile('xl/workbook.xml');
    if (workbookFile != null) {
      var wbXml = utf8.decode(workbookFile.content as List<int>);
      if (wbXml.contains('<calcPr')) {
        wbXml = wbXml.replaceAll(
          RegExp(r'<calcPr[^>]*?>'),
          '<calcPr fullCalcOnLoad="1" iterate="0"/>',
        );
      } else {
        wbXml = wbXml.replaceFirst('</workbook>', '<calcPr fullCalcOnLoad="1"/></workbook>');
      }
      modifiedXmlFiles['xl/workbook.xml'] = wbXml;
    }

    // 8. Reconstruct new archive with updated XML files
    final outArchive = Archive();
    for (final file in srcArchive) {
      if (modifiedXmlFiles.containsKey(file.name)) {
        final newBytes = utf8.encode(modifiedXmlFiles[file.name]!);
        outArchive.addFile(ArchiveFile(file.name, newBytes.length, newBytes));
      } else {
        outArchive.addFile(file);
      }
    }

    // 9. Pack and download
    final encodedBytes = ZipEncoder().encode(outArchive);

    final safeSubject = subjectName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(' ', '_');
    final safeSection = sectionName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(' ', '_');
    final cleanSy = (schoolYear ?? '2026-2027').replaceAll(' ', '');
    final fileName = 'ECR_${safeSubject}_${safeSection}_SY$cleanSy.xlsx';

    return await FileDownloadHelper.downloadBytes(
      bytes: Uint8List.fromList(encodedBytes),
      fileName: fileName,
      extension: 'xlsx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  /// Updates or sets an inline string in an existing OpenXML cell reference while preserving style `s="..."`.
  static String _updateStringCell(String xml, String cellRef, String value) {
    final pattern = RegExp(
      '<c\\s+r="$cellRef"([^>]*?)(?:/>|>(.*?)</c>)',
      dotAll: true,
    );
    final match = pattern.firstMatch(xml);
    if (match == null) return xml;

    final existingAttrs = match.group(1) ?? '';
    // Extract style attribute if present
    final sMatch = RegExp(r's="(\d+)"').firstMatch(existingAttrs);
    final sAttr = sMatch != null ? ' s="${sMatch.group(1)}"' : '';

    final cleanVal = value.trim();
    final String replacement;
    if (cleanVal.isEmpty) {
      replacement = '<c r="$cellRef"$sAttr/>';
    } else {
      final escaped = _xmlEscape(cleanVal);
      replacement =
          '<c r="$cellRef"$sAttr t="inlineStr"><is><t>$escaped</t></is></c>';
    }

    return xml.replaceRange(match.start, match.end, replacement);
  }

  /// Updates or sets a numeric value in an existing OpenXML cell reference while preserving style `s="..."`.
  static String _updateNumericCell(String xml, String cellRef, num? value) {
    final pattern = RegExp(
      '<c\\s+r="$cellRef"([^>]*?)(?:/>|>(.*?)</c>)',
      dotAll: true,
    );
    final match = pattern.firstMatch(xml);
    if (match == null) return xml;

    final existingAttrs = match.group(1) ?? '';
    final sMatch = RegExp(r's="(\d+)"').firstMatch(existingAttrs);
    final sAttr = sMatch != null ? ' s="${sMatch.group(1)}"' : '';

    final String replacement;
    if (value == null) {
      replacement = '<c r="$cellRef"$sAttr/>';
    } else {
      final numVal = value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toString();
      replacement = '<c r="$cellRef"$sAttr><v>$numVal</v></c>';
    }

    return xml.replaceRange(match.start, match.end, replacement);
  }

  static String _xmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
