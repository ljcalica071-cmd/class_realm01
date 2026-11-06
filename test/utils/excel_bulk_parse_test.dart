import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/core/utils/excel_template_generator.dart';

void main() {
  test('ExcelTemplateGenerator produces valid .xlsx with headers and sample row', () {
    final bytes = ExcelTemplateGenerator.generateStudentTemplateBytes();
    expect(bytes, isNotEmpty);

    final archive = ZipDecoder().decodeBytes(Uint8List.fromList(bytes));
    final sheetFile = archive.findFile('xl/worksheets/sheet1.xml');
    expect(sheetFile, isNotNull);

    final sheetXml = utf8.decode(sheetFile!.content as List<int>);
    final rowMatches = RegExp(
      r'<row\b[^>]*>(.*?)<\/row>',
      dotAll: true,
    ).allMatches(sheetXml);

    expect(rowMatches.length, greaterThanOrEqualTo(2));

    // Verify self-closing cell regex does not swallow adjacent cells
    const mixedRowXml =
        '<c r="A3" s="3" t="inlineStr"><is><t>102938475612</t></is></c>'
        '<c r="B3" s="3" t="inlineStr"><is><r><t>Sophia.cr</t></r><r><t>@gmail.com</t></r></is></c>'
        '<c r="C3" s="3" t="inlineStr"><is><t>Reyes</t></is></c>'
        '<c r="D3" s="3" t="inlineStr"><is><t>Sophia</t></is></c>'
        '<c r="E3" s="3"/>'
        '<c r="F3" s="3" t="inlineStr"><is><t>Female</t></is></c>'
        '<c r="G3" s="3" t="inlineStr"><is><t>2006-08-22</t></is></c>';

    final cellTagMatches = RegExp(
      r'<c\b([^>\/]*)(?:\/>|>(.*?)<\/c>)',
      dotAll: true,
    ).allMatches(mixedRowXml).toList();

    expect(cellTagMatches.length, equals(7));

    // Verify rich text inline string concatenation on B3
    final b3Body = cellTagMatches[1].group(2) ?? '';
    final tMatches = RegExp(r'<t(?:\s[^>]*)?>([^<]*)<\/t>').allMatches(b3Body);
    final emailBuf = StringBuffer();
    for (final tm in tMatches) {
      emailBuf.write(tm.group(1) ?? '');
    }
    expect(emailBuf.toString(), equals('Sophia.cr@gmail.com'));

    // Verify F3 is preserved after self-closing E3
    final f3Body = cellTagMatches[5].group(2) ?? '';
    final f3Text = RegExp(r'<t(?:\s[^>]*)?>([^<]*)<\/t>')
        .firstMatch(f3Body)
        ?.group(1);
    expect(f3Text, equals('Female'));
  });
}

