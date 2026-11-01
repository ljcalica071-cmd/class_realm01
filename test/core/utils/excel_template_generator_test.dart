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
    expect(xml, contains('LEN(TRIM(E3))=2'));
    expect(xml, contains('RIGHT(TRIM(E3),1)=&quot;.&quot;'));
  });
}
