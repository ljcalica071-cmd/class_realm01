import 'package:class_realm/models/user_model.dart';

class StudentDashboardData {
  const StudentDashboardData({required this.student, required this.classwork});

  final UserModel student;
  final List<StudentClassworkModel> classwork;

  factory StudentDashboardData.fromJson(Map<String, dynamic> json) {
    final studentJson = Map<String, dynamic>.from(json['student'] as Map);
    final enrollments = (studentJson['enrollments'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final primaryEnrollment = enrollments.isEmpty ? null : enrollments.first;
    final birthdayValue = studentJson['birthday']?.toString();
    final firstName = studentJson['first_name']?.toString() ?? '';
    final middleName = studentJson['middle_name']?.toString();
    final lastName = studentJson['last_name']?.toString() ?? '';
    final fullName = [
      firstName,
      middleName,
      lastName,
    ].where((part) => part != null && part.trim().isNotEmpty).join(' ');

    return StudentDashboardData(
      student: UserModel(
        id: studentJson['id'].toString(),
        username: studentJson['lrn']?.toString() ?? '',
        fullName: fullName,
        email: studentJson['email']?.toString() ?? '',
        role: UserRole.student,
        studentId: studentJson['id'].toString(),
        lrn: studentJson['lrn']?.toString(),
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        gender: studentJson['gender']?.toString(),
        birthday: birthdayValue == null
            ? null
            : DateTime.tryParse(birthdayValue),
        departmentOrSection: primaryEnrollment?['section_name']?.toString(),
        gradeLevel: primaryEnrollment?['grade_level']?.toString(),
      ),
      classwork: (json['classwork'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                StudentClassworkModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

class StudentClassworkModel {
  const StudentClassworkModel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.instructions,
    required this.subjectName,
    required this.sectionName,
    required this.gradeLevel,
    required this.assignedAt,
    required this.deadline,
    required this.maxScore,
    required this.status,
    required this.score,
    required this.feedback,
  });

  final String id;
  final String type;
  final String title;
  final String description;
  final String instructions;
  final String subjectName;
  final String sectionName;
  final String gradeLevel;
  final DateTime? assignedAt;
  final DateTime? deadline;
  final double maxScore;
  final String? status;
  final double? score;
  final String? feedback;

  factory StudentClassworkModel.fromJson(Map<String, dynamic> json) {
    final subject = json['subject'] is Map
        ? Map<String, dynamic>.from(json['subject'] as Map)
        : <String, dynamic>{};
    final submission = json['submission'] is Map
        ? Map<String, dynamic>.from(json['submission'] as Map)
        : <String, dynamic>{};
    final assignedAt = json['assigned_at']?.toString();
    final deadline = json['deadline']?.toString();
    final maxScore = json['max_score'];
    final score = submission['score'];

    return StudentClassworkModel(
      id: json['id'].toString(),
      type: json['classwork_type']?.toString() ?? 'assignment',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      instructions: json['instructions']?.toString() ?? '',
      subjectName: subject['subject_name']?.toString() ?? '',
      sectionName: subject['section_name']?.toString() ?? '',
      gradeLevel: subject['grade_level']?.toString() ?? '',
      assignedAt: assignedAt == null ? null : DateTime.tryParse(assignedAt),
      deadline: deadline == null ? null : DateTime.tryParse(deadline),
      maxScore: maxScore is num ? maxScore.toDouble() : 0,
      status: submission['status']?.toString(),
      score: score is num ? score.toDouble() : null,
      feedback: submission['feedback']?.toString(),
    );
  }
}
