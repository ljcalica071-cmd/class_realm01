import 'package:class_realm/models/user_model.dart';

abstract class StudentRepository {
  Future<List<UserModel>> getStudents({
    String? section,
    bool includeArchived = false,
  });
  Future<UserModel?> getStudentById(String id);
  Future<String?> createStudentAccount({
    required String firstName,
    required String middleName,
    required String lastName,
    required DateTime birthday,
    required String email,
    required String studentId,
    required String gender,
    required String contactNumber,
  });
  Future<void> updateStudent(
    String id,
    String fullName,
    String studentId,
    String section,
  );
  Future<void> updateStudentFull({
    required String id,
    required String firstName,
    required String middleName,
    required String lastName,
    required String email,
    required String studentId,
    required String gender,
    required DateTime birthday,
    required String subjectId,
  });
  Future<void> archiveStudent(String id, [String? subjectId, String? currentStatusHint]);
  Future<void> restoreStudent(String id, [String? subjectId]);
  Future<void> deactivateStudent(String id);
  Future<void> reactivateStudent(String id);
  Future<void> permanentlyDeleteStudent(String id, [String? subjectId]);
}
