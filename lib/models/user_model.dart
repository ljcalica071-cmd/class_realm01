enum UserRole { admin, teacher, student, parent }

enum AccountStatus { active, pending, rejected, archived }

class UserModel {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final UserRole role;
  final AccountStatus status;
  final String? profileImage;
  final String? departmentOrSection;
  final String? studentId;
  final String? linkedStudentId;
  final String? contactNumber;
  final bool isArchived;

  const UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    this.status = AccountStatus.active,
    this.profileImage,
    this.departmentOrSection,
    this.studentId,
    this.linkedStudentId,
    this.contactNumber,
    this.isArchived = false,
  });

  UserModel copyWith({
    String? id,
    String? username,
    String? fullName,
    String? email,
    UserRole? role,
    AccountStatus? status,
    String? profileImage,
    String? departmentOrSection,
    String? studentId,
    String? linkedStudentId,
    String? contactNumber,
    bool? isArchived,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      profileImage: profileImage ?? this.profileImage,
      departmentOrSection: departmentOrSection ?? this.departmentOrSection,
      studentId: studentId ?? this.studentId,
      linkedStudentId: linkedStudentId ?? this.linkedStudentId,
      contactNumber: contactNumber ?? this.contactNumber,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
