import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/subject_catalog_model.dart';

void main() {
  group('DepEdSubjectCatalog.getActiveTermsForBlock', () {
    test('provides term and unit defaults for subject offerings', () {
      final core = DepEdSubjectCatalog.allSubjects.firstWhere(
        (subject) => subject.id == 'core_genmath',
      );
      final academic = DepEdSubjectCatalog.allSubjects.firstWhere(
        (subject) => subject.id == 'acad_precalc',
      );
      final techPro = DepEdSubjectCatalog.allSubjects.firstWhere(
        (subject) => subject.id == 'tech_cp_java',
      );

      expect(core.termsTaught, 3);
      expect(core.defaultTermBlock, '1ST, 2ND, 3RD');
      expect(core.unitsPerTerm, 2);
      expect(core.unitsPerYear, 6);
      expect(academic.termsTaught, 1);
      expect(academic.defaultTermBlock, 'FIRST TERM');
      expect(academic.unitsPerTerm, 3);
      expect(academic.unitsPerYear, 3);
      expect(techPro.unitsPerTerm, 4);
      expect(techPro.unitsPerYear, 12);
    });

    test('returns all terms for full-year subjects', () {
      expect(DepEdSubjectCatalog.getActiveTermsForBlock(3, '1ST, 2ND, 3RD'), [
        1,
        2,
        3,
      ]);
    });

    test('supports one-term offerings in each term', () {
      expect(DepEdSubjectCatalog.getActiveTermsForBlock(1, 'FIRST TERM'), [1]);
      expect(DepEdSubjectCatalog.getActiveTermsForBlock(1, 'SECOND TERM'), [2]);
      expect(DepEdSubjectCatalog.getActiveTermsForBlock(1, 'THIRD TERM'), [3]);
    });

    test('supports two-term offerings starting in term one or two', () {
      expect(DepEdSubjectCatalog.getActiveTermsForBlock(2, '1ST & 2ND'), [
        1,
        2,
      ]);
      expect(DepEdSubjectCatalog.getActiveTermsForBlock(2, '2ND & 3RD'), [
        2,
        3,
      ]);
    });

    test('rejects a two-term block starting in term three', () {
      expect(
        () => DepEdSubjectCatalog.getActiveTermsForBlock(2, 'THIRD TERM'),
        throwsArgumentError,
      );
    });
  });
}
