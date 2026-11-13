import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:class_realm/core/utils/excel_template_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('student Excel template documents and enforces H. middle initials', () {
    final archive = ZipDecoder().decodeBytes(
      ExcelTemplateGenerator.generateStudentTemplateBytes(),
    );
    final sheet = archive.findFile('xl/worksheets/sheet1.xml');

    expect(sheet, isNotNull);
    final xml = utf8.decode(sheet!.content as List<int>);
    expect(xml, contains('<t>G.</t>'));
    expect(xml, contains('errorTitle="Invalid Format"'));
    expect(xml, contains('Use 1 letter and 1 period only (e.g., H.)'));
    expect(xml, contains('sqref="E3:E100"'));
    expect(xml, contains('RIGHT(TRIM(E3),1)=&quot;.&quot;'));
    expect(xml, contains('<conditionalFormatting sqref="A3:A100">'));
    expect(xml, contains('<conditionalFormatting sqref="C3:D100">'));
    expect(xml, contains('<conditionalFormatting sqref="E3:E100">'));
    expect(xml, contains('<conditionalFormatting sqref="G3:G100">'));
    expect(xml, contains('DATEDIF(G3,TODAY()'));
  });
}
