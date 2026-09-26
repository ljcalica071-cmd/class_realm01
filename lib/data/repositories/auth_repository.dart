import 'package:class_realm/models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel?> authenticate(String username, String password);
  Future<void> logout();
  UserModel? getCurrentUser();
  Future<String?> completeFirstLogin(
    String userId,
    String enteredTempPassword,
    String newPassword,
  );
  Future<String?> createParentAccount({
    required String fullName,
    required String email,
    required String contactNumber,
    required String relationship,
    required String linkedStudentId,
  });
  Future<void> updateParentAccount({
    required String id,
    required String fullName,
    required String email,
    required String contactNumber,
    required String relationship,
    required String linkedStudentId,
  });
}
