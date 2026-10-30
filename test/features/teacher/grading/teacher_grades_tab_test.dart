import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/features/teacher/sub_features/grading/widgets/teacher_grades_tab.dart';
import 'package:class_realm/models/user_model.dart';

void main() {
  testWidgets('TeacherGradesTab displays Pending/— for unrecorded student grades, never mock 85.0', (tester) async {
    final mockStudent = UserModel(
      id: 'student_123',
      username: 'student@test.com',
      fullName: 'Juan Dela Cruz',
      email: 'student@test.com',
      role: UserRole.student,
      lrn: '123456789012',
      departmentOrSection: 'Diamond',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherGradesTab(
            students: [mockStudent],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify student name is shown
    expect(find.text('Juan Dela Cruz'), findsOneWidget);

    // Verify NO mock 85.0 is shown anywhere
    expect(find.text('85.0'), findsNothing);
    expect(find.text('Very Satisfactory'), findsNothing);

    // Verify clean '—' and 'Pending' are shown
    expect(find.text('—'), findsAtLeastNWidgets(1));
    expect(find.text('Pending'), findsOneWidget);
  });
}

