enum UserRole { admin, teacher, student, parent }

enum AccountStatus { active, pending, rejected, archived, pendingFirstLogin, deactivated }

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
  final String? lrn;
  final String? linkedStudentId;
  final String? contactNumber;
  final bool isArchived;
  // Student-specific fields
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? gender;
  final DateTime? birthday;
  final String? gradeLevel;
  final String? parentGuardianName;
  final String? parentGuardianRelationship;
  final String? parentGuardianContact;
  final String? password; // mock only — not for production

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
    this.lrn,
    this.linkedStudentId,
    this.contactNumber,
    this.isArchived = false,
    this.firstName,
    this.middleName,
    this.lastName,
    this.gender,
    this.birthday,
    this.gradeLevel,
    this.parentGuardianName,
    this.parentGuardianRelationship,
    this.parentGuardianContact,
    this.password,
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
    String? lrn,
    String? linkedStudentId,
    String? contactNumber,
    bool? isArchived,
    String? firstName,
    String? middleName,
    String? lastName,
    String? gender,
    DateTime? birthday,
    String? gradeLevel,
    String? parentGuardianName,
    String? parentGuardianRelationship,
    String? parentGuardianContact,
    String? password,
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
      lrn: lrn ?? this.lrn,
      linkedStudentId: linkedStudentId ?? this.linkedStudentId,
      contactNumber: contactNumber ?? this.contactNumber,
      isArchived: isArchived ?? this.isArchived,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      parentGuardianName: parentGuardianName ?? this.parentGuardianName,
      parentGuardianRelationship:
          parentGuardianRelationship ?? this.parentGuardianRelationship,
      parentGuardianContact: parentGuardianContact ?? this.parentGuardianContact,
      password: password ?? this.password,
    );
  }
}
