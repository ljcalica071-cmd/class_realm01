import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/features/parent/sub_features/profile/widgets/parent_profile_tab.dart';
import 'package:class_realm/features/parent/sub_features/child_details/widgets/parent_grades_tab.dart';
import 'package:class_realm/features/parent/sub_features/child_details/widgets/parent_subject_details_sheet.dart';

void main() {
  group('UserModel 18+ Grade Privacy Eligibility', () {
    test('Student under 18 is not a legal adult and cannot hide grades', () {
      final minorStudent = UserModel(
        id: 'stu-minor',
        username: 'minor',
        fullName: 'Juan Dela Cruz',
        email: 'juan@school.edu',
        role: UserRole.student,
        birthday: DateTime(DateTime.now().year - 16, 6, 15),
        hideTermGradesFromParent: true,
        hideFinalGradesFromParent: true,
      );

      expect(minorStudent.isLegalAdult, isFalse);
      expect(minorStudent.effectiveHideTermGradesFromParent, isFalse);
      expect(minorStudent.effectiveHideFinalGradesFromParent, isFalse);
    });

    test('Student aged 18+ is a legal adult and can hide term/final grades', () {
      final adultStudent = UserModel(
        id: 'stu-adult',
        username: 'adult',
        fullName: 'Carlos D. Cruz',
        email: 'carlos@school.edu',
        role: UserRole.student,
        birthday: DateTime(DateTime.now().year - 19, 1, 10),
        hideTermGradesFromParent: true,
        hideFinalGradesFromParent: false,
      );

      expect(adultStudent.isLegalAdult, isTrue);
      expect(adultStudent.effectiveHideTermGradesFromParent, isTrue);
      expect(adultStudent.effectiveHideFinalGradesFromParent, isFalse);
    });
  });

  group('ParentProfileTab Relationship Grouping & Parent Details', () {
    testWidgets(
      'displays parent own details and groups linked students by relationship category',
      (tester) async {
        final parent = UserModel(
          id: 'par-1',
          username: 'maria_cruz',
          fullName: 'Maria Santos Cruz',
          email: 'maria.cruz@example.com',
          role: UserRole.parent,
          birthday: DateTime(1982, 5, 14),
        );

        final child1 = UserModel(
          id: 'stu-1',
          username: 'carlos',
          fullName: 'Carlos D. Cruz',
          email: 'carlos@school.edu',
          role: UserRole.student,
          parentGuardianRelationship: 'Mother',
        );

        final child2 = UserModel(
          id: 'stu-2',
          username: 'angela',
          fullName: 'Angela D. Cruz',
          email: 'angela@school.edu',
          role: UserRole.student,
          parentGuardianRelationship: 'Mother',
        );

        final child3 = UserModel(
          id: 'stu-3',
          username: 'marco',
          fullName: 'Marco Reyes',
          email: 'marco@school.edu',
          role: UserRole.student,
          parentGuardianRelationship: 'Guardian',
        );

        await tester.binding.setSurfaceSize(const Size(390, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ParentProfileTab(
                parent: parent,
                linkedStudent: child1,
                allChildren: [child1, child2, child3],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Maria Santos Cruz'), findsWidgets);
        expect(find.text('maria.cruz@example.com'), findsWidgets);
        expect(find.text('May 14, 1982'), findsOneWidget);
        expect(find.text('MOTHER'), findsOneWidget);
        expect(find.text('GUARDIAN'), findsOneWidget);
        expect(find.text('Cruz, Carlos D.'), findsOneWidget);
        expect(find.text('Cruz, Angela D.'), findsOneWidget);
        expect(find.text('Reyes, Marco'), findsOneWidget);
      },
    );
  });

  group('ParentGradesTab Unfinalized 0 Fix & 18+ Privacy Masking', () {
    final mockOfferings = <Map<String, dynamic>>[
      {
        'id': 'off-1',
        'terms_taught': 1,
        'term_block': 'SECOND TERM',
        'subjects': {
          'id': 'sub-1',
          'subject_name': 'Art Criticism and Creative Markets',
          'subject_code': 'ACACM_G11_3834',
        },
        'teacher_profiles': {
          'teacher_id': 't-1',
          'first_name': 'Naruto',
          'last_name': 'Uzumaki',
          'gender': 'male',
        },
      },
    ];

    testWidgets(
      'unfinalized 0 grade is shown as Ongoing (—) and inactive terms as N/A',
      (tester) async {
        final minorStudent = UserModel(
          id: 'stu-1',
          username: 'carlos',
          fullName: 'Carlos D. Cruz',
          email: 'carlos@school.edu',
          role: UserRole.student,
          birthday: DateTime(DateTime.now().year - 16, 3, 10),
        );

        final unfinalizedZeroGrades = <String, Map<int, Map<String, dynamic>>>{
          'off-1': {
            2: {
              'subject_offering_id': 'off-1',
              'term_number': 2,
              'transmuted_grade': 0,
              'remarks': 'incomplete',
              'is_finalized': false,
              'is_published': true,
            },
          },
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ParentGradesTab(
                student: minorStudent,
                initialOfferings: mockOfferings,
                initialTermGrades: unfinalizedZeroGrades,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should NOT show Needs Help or 0 for unfinalized placeholder
        expect(find.text('Needs Help'), findsNothing);
        expect(find.text('N/A'), findsNWidgets(2)); // Term 1 & Term 3 inactive
        expect(find.text('Ongoing'), findsOneWidget); // Term 2 active but unencoded
      },
    );

    testWidgets(
      '18+ student hiding term and final grades masks values with Hidden (18+) & Protected',
      (tester) async {
        final adultStudent = UserModel(
          id: 'stu-adult',
          username: 'carlos',
          fullName: 'Carlos D. Cruz',
          email: 'carlos@school.edu',
          role: UserRole.student,
          birthday: DateTime(DateTime.now().year - 19, 3, 10),
          hideTermGradesFromParent: true,
          hideFinalGradesFromParent: true,
        );

        final encodedGrades = <String, Map<int, Map<String, dynamic>>>{
          'off-1': {
            2: {
              'subject_offering_id': 'off-1',
              'term_number': 2,
              'transmuted_grade': 92,
              'remarks': 'passed',
              'is_finalized': true,
            },
          },
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ParentGradesTab(
                student: adultStudent,
                initialOfferings: mockOfferings,
                initialTermGrades: encodedGrades,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('18+ Student Grade Privacy Active'), findsOneWidget);
        expect(find.text('Hidden (18+)'), findsOneWidget);
        expect(find.text('Protected'), findsOneWidget);
        // Actual grade 92 must not be leaked
        expect(find.text('92'), findsNothing);
      },
    );
  });

  group('ParentSubjectDetailsSheet Public Teacher Details', () {
    testWidgets(
      'shows teacher consultation hours, email, and public phone while respecting private facebook flag',
      (tester) async {
        final offering = <String, dynamic>{
          'id': 'off-1',
          'terms_taught': 3,
          'subjects': {
            'id': 'sub-1',
            'subject_name': 'General Mathematics',
            'subject_code': 'GENMATH_11',
          },
          'teacher_profiles': {
            'teacher_id': 't-1',
            'first_name': 'Kakashi',
            'last_name': 'Hatake',
            'gender': 'male',
            'contact_number': '09171234567',
            'subject_specialization': 'Mathematics',
            'email': 'kakashi.hatake@school.edu',
            'teacher_settings': {
              'consultation_hours': 'MWF 2:00 PM - 4:00 PM',
              'facebook_link': 'fb.com/private.kakashi',
              'is_phone_public': true,
              'is_facebook_public': false,
            },
          },
        };

        await tester.binding.setSurfaceSize(const Size(390, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ParentSubjectDetailsSheet(
                offering: offering,
                schedules: const <ScheduleModel>[],
                termGrades: const <int, Map<String, dynamic>>{},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sir Kakashi Hatake'), findsOneWidget);
        expect(find.textContaining('MWF 2:00 PM - 4:00 PM'), findsOneWidget);
        expect(find.text('kakashi.hatake@school.edu'), findsOneWidget);
        expect(find.textContaining('09171234567'), findsOneWidget);
        // Private Facebook link must NOT be shown
        expect(find.textContaining('fb.com/private.kakashi'), findsNothing);
      },
    );
  });
}
