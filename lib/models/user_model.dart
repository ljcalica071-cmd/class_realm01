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
  final String? enrolledSubjectId;
  final String? enrolledSubjectName;
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
  final bool isSetupComplete;
  
  // Teacher-specific / Profile fields
  final String? subjectSpecialization;
  final String? facebookLink;
  final bool isFacebookPublic;
  final bool isPhonePublic;
  final String? consultationHours;

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
    this.enrolledSubjectId,
    this.enrolledSubjectName,
    this.contactNumber,
    this.isArchived = false,
    this.isSetupComplete = false,
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
    this.subjectSpecialization,
    this.facebookLink,
    this.isFacebookPublic = false,
    this.isPhonePublic = false,
    this.consultationHours,
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
    String? enrolledSubjectId,
    String? enrolledSubjectName,
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
    bool? isSetupComplete,
    String? subjectSpecialization,
    String? facebookLink,
    bool? isFacebookPublic,
    bool? isPhonePublic,
    String? consultationHours,
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
      enrolledSubjectId: enrolledSubjectId ?? this.enrolledSubjectId,
      enrolledSubjectName: enrolledSubjectName ?? this.enrolledSubjectName,
      contactNumber: contactNumber ?? this.contactNumber,
      isArchived: isArchived ?? this.isArchived,
      isSetupComplete: isSetupComplete ?? this.isSetupComplete,
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
      subjectSpecialization: subjectSpecialization ?? this.subjectSpecialization,
      facebookLink: facebookLink ?? this.facebookLink,
      isFacebookPublic: isFacebookPublic ?? this.isFacebookPublic,
      isPhonePublic: isPhonePublic ?? this.isPhonePublic,
      consultationHours: consultationHours ?? this.consultationHours,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'fullName': fullName,
      'email': email,
      'role': role.toString().split('.').last,
      'status': status.toString().split('.').last,
      'profileImage': profileImage,
      'departmentOrSection': departmentOrSection,
      'studentId': studentId,
      'lrn': lrn,
      'linkedStudentId': linkedStudentId,
      'enrolledSubjectId': enrolledSubjectId,
      'enrolledSubjectName': enrolledSubjectName,
      'contactNumber': contactNumber,
      'isArchived': isArchived,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'gender': gender,
      'birthday': birthday?.toIso8601String(),
      'gradeLevel': gradeLevel,
      'parentGuardianName': parentGuardianName,
      'parentGuardianRelationship': parentGuardianRelationship,
      'parentGuardianContact': parentGuardianContact,
      'password': password,
      'isSetupComplete': isSetupComplete,
      'subjectSpecialization': subjectSpecialization,
      'facebookLink': facebookLink,
      'isFacebookPublic': isFacebookPublic,
      'isPhonePublic': isPhonePublic,
      'consultationHours': consultationHours,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['role'],
        orElse: () => UserRole.student,
      ),
      status: AccountStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => AccountStatus.active,
      ),
      profileImage: json['profileImage'] as String?,
      departmentOrSection: json['departmentOrSection'] as String?,
      studentId: json['studentId'] as String?,
      lrn: json['lrn'] as String?,
      linkedStudentId: json['linkedStudentId'] as String?,
      enrolledSubjectId: json['enrolledSubjectId'] as String?,
      enrolledSubjectName: json['enrolledSubjectName'] as String?,
      contactNumber: json['contactNumber'] as String?,
      isArchived: json['isArchived'] as bool? ?? false,
      firstName: json['firstName'] as String?,
      middleName: json['middleName'] as String?,
      lastName: json['lastName'] as String?,
      gender: json['gender'] as String?,
      birthday: json['birthday'] != null
          ? DateTime.tryParse(json['birthday'] as String)
          : null,
      gradeLevel: json['gradeLevel'] as String?,
      parentGuardianName: json['parentGuardianName'] as String?,
      parentGuardianRelationship: json['parentGuardianRelationship'] as String?,
      parentGuardianContact: json['parentGuardianContact'] as String?,
      password: json['password'] as String?,
      isSetupComplete: json['isSetupComplete'] as bool? ?? false,
      subjectSpecialization: json['subjectSpecialization'] as String?,
      facebookLink: json['facebookLink'] as String?,
      isFacebookPublic: json['isFacebookPublic'] as bool? ?? false,
      isPhonePublic: json['isPhonePublic'] as bool? ?? false,
      consultationHours: json['consultationHours'] as String?,
    );
  }
}
