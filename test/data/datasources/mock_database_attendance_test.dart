import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/data/datasources/mock/mock_database.dart';
import 'package:class_realm/models/academic_models.dart';

void main() {
  test('ignores attendance for a student absent from an empty user list', () {
    final database = MockDatabase.instance
      ..users.clear()
      ..attendanceRecords.clear();

    expect(
      () => database.toggleAttendance(
        'unknown-student',
        AttendanceStatus.present,
      ),
      returnsNormally,
    );
    expect(database.attendanceRecords, isEmpty);
  });
}
