import 'package:class_realm/core/utils/search_utils.dart';
import 'package:flutter_test/flutter_test.dart';

class _Student {
  final String name;
  final String lrn;
  final String email;
  _Student(this.name, this.lrn, this.email);
}

void main() {
  // Mirrors the Manage Students screenshot: typing "c" used to show everyone
  // because emails ("...cr@gmail.com") and middle initials matched.
  final students = [
    _Student('Cruz, Carlos D.', '120000000103', 'carlos.cruz.cr@gmail.com'),
    _Student('Roxas, Chloe N.', '120000000113', 'chloe.roxas.cr@gmail.com'),
    _Student('Castro, Bea M.', '120000000112', 'bea.castro.cr@gmail.com'),
    _Student('Reyes, Bryan C.', '120000000102', 'bryan.reyes.cr@gmail.com'),
    _Student('Dela Cruz, Justin K.', '120000000110', 'justin.delacruz.cr@gmail.com'),
    _Student('Calica, Ljay H.', '099123456789', 'ljcalica317@gmail.com'),
    _Student('Mercado, Diana O.', '120000000114', 'diana.mercado.cr@gmail.com'),
  ];

  List<String> search(String q) => SearchUtils.filter<_Student>(
        q,
        students,
        names: (s) => [s.name],
        ids: (s) => [s.lrn],
      ).map((s) => s.name).toList();

  test('empty query returns everything in original order', () {
    expect(search('').length, students.length);
    expect(search('   ').length, students.length);
  });

  test('single letter matches word starts only (not emails/mid-word)', () {
    final r = search('c');
    expect(r, containsAll(['Cruz, Carlos D.', 'Castro, Bea M.', 'Calica, Ljay H.']));
    // Roxas "Chloe", Reyes "Bryan C.", Dela "Cruz" also START a word with c.
    expect(r, isNot(contains('Mercado, Diana O.'))); // only has c mid-word
  });

  test('names starting with the query rank first', () {
    final r = search('c');
    // Cruz / Castro / Calica start the full name -> before Roxas, Chloe etc.
    final firstThree = r.take(3).toSet();
    expect(firstThree, {
      'Cruz, Carlos D.',
      'Castro, Bea M.',
      'Calica, Ljay H.',
    });
  });

  test('multi-token search ignores order and punctuation', () {
    expect(search('carlos cruz'), ['Cruz, Carlos D.']);
    expect(search('cruz, carlos'), ['Cruz, Carlos D.']);
    expect(search('delacruz'), isEmpty); // not a word prefix of any name
    expect(search('dela cruz'), ['Dela Cruz, Justin K.']);
  });

  test('LRN: prefix, or substring from 3 characters', () {
    expect(search('1200000001'), hasLength(6));
    expect(search('456789'), ['Calica, Ljay H.']);
    expect(search('09'), ['Calica, Ljay H.']); // prefix of LRN
  });

  test('accents and case are ignored', () {
    expect(SearchUtils.matches('PENA', names: ['Peña, Juan']), isTrue);
    expect(SearchUtils.matches('peña', names: ['PENA, JUAN']), isTrue);
  });

  test('loose fields (email) never match a single character', () {
    expect(
      SearchUtils.matches('c', names: ['Smith, John'], loose: ['john@cr.com']),
      isFalse,
    );
    expect(
      SearchUtils.matches('john', names: ['Smith, John'], loose: ['x@y.com']),
      isTrue,
    );
  });

  test('subject template style search: "ma" is a word prefix', () {
    final subjects = [
      'General Mathematics',
      'Mabisang Komunikasyon',
      'Contemporary Marketing',
      'Animation',
      'Pharmacy',
    ];
    final r = SearchUtils.filter<String>(
      'ma',
      subjects,
      names: (s) => [s],
    );
    expect(r, containsAll(['General Mathematics', 'Mabisang Komunikasyon', 'Contemporary Marketing']));
    expect(r, isNot(contains('Animation')));
    expect(r, isNot(contains('Pharmacy')));
    expect(r.first, 'Mabisang Komunikasyon'); // starts with "ma" -> best
  });
}
