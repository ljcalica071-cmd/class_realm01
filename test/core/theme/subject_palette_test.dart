import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/core/theme/subject_palette.dart';

void main() {
  group('SubjectPalette', () {
    test('contains 16 curated accessible colors', () {
      expect(SubjectPalette.colors.length, 16);
      expect(SubjectPalette.darkTextShades.length, 16);
      expect(SubjectPalette.lightTextShades.length, 16);
    });

    test('guarantees zero duplicate colors for distinct teacher subjects', () {
      final teacherSubjects = [
        'General Mathematics',
        'Effective Communication',
        'General Science',
        'Life and Career Skills',
        'Earth and Life Science',
        'Oral Communication',
        'Physical Education',
        'Introduction to Philosophy',
      ];

      final assignedColors = teacherSubjects
          .map((sub) => SubjectPalette.getColorForSubject(
                sub,
                teacherSubjectNames: teacherSubjects,
              ))
          .toSet();

      expect(assignedColors.length, teacherSubjects.length);
    });

    test('deterministic color resolution with explicit index', () {
      final color0 = SubjectPalette.getColorForSubject('Math', index: 0);
      final color1 = SubjectPalette.getColorForSubject('Math', index: 1);
      expect(color0, SubjectPalette.colors[0]);
      expect(color1, SubjectPalette.colors[1]);
      expect(color0 != color1, isTrue);
    });

    test('provides high-contrast text color for both light and dark backgrounds', () {
      for (final color in SubjectPalette.colors) {
        final darkText = SubjectPalette.getTextColor(color, isDark: false);
        final lightText = SubjectPalette.getTextColor(color, isDark: true);

        // Light background uses dark text
        expect(darkText, isNotNull);
        // Dark background uses light text
        expect(lightText, isNotNull);
        expect(darkText != lightText, isTrue);
      }
    });
  });
}
