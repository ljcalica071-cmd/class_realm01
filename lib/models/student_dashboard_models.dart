import 'package:class_realm/models/user_model.dart';

class StudentEnrollmentModel {
  const StudentEnrollmentModel({
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.sectionName,
    required this.gradeLevel,
    required this.teacherName,
  });

  final String subjectId;
  final String subjectName;
  final String subjectCode;
  final String sectionName;
  final String gradeLevel;
  final String teacherName;

  factory StudentEnrollmentModel.fromJson(Map<String, dynamic> json) {
    return StudentEnrollmentModel(
      subjectId: json['subject_id']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      subjectCode: json['subject_code']?.toString() ?? '',
      sectionName: json['section_name']?.toString() ?? '',
      gradeLevel: json['grade_level']?.toString() ?? '',
      teacherName: json['teacher_name']?.toString() ?? '',
    );
  }
}

class StudentDashboardData {
  const StudentDashboardData({
    required this.student,
    required this.classwork,
    this.enrollments = const [],
  });

  final UserModel student;
  final List<StudentClassworkModel> classwork;
  final List<StudentEnrollmentModel> enrollments;

  factory StudentDashboardData.fromJson(Map<String, dynamic> json) {
    final studentJson = Map<String, dynamic>.from(json['student'] as Map);
    final rawEnrollments = (studentJson['enrollments'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final enrollments = rawEnrollments
        .map((item) => StudentEnrollmentModel.fromJson(item))
        .toList();
    final primaryEnrollment = rawEnrollments.isEmpty
        ? null
        : rawEnrollments.first;
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
      enrollments: enrollments,
    );
  }
}

class StudentAttachmentModel {
  const StudentAttachmentModel({
    required this.id,
    required this.fileName,
    this.mimeType,
    this.fileSizeBytes,
    this.signedUrl,
  });

  final String id;
  final String fileName;
  final String? mimeType;
  final int? fileSizeBytes;
  final String? signedUrl;

  factory StudentAttachmentModel.fromJson(Map<String, dynamic> json) {
    return StudentAttachmentModel(
      id: json['id']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      mimeType: json['mime_type']?.toString(),
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt(),
      signedUrl: json['signed_url']?.toString(),
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
    this.attachment,
    this.studentSubmission,
    this.submittedAt,
    this.completionMode = 'online',
    this.termNumber = 1,
    this.gradebookColumnIndex,
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
  final StudentAttachmentModel? attachment;
  final StudentAttachmentModel? studentSubmission;
  final DateTime? submittedAt;
  final String completionMode;
  final int termNumber;
  final int? gradebookColumnIndex;

  factory StudentClassworkModel.fromJson(Map<String, dynamic> json) {
    final subject = json['subject'] is Map
        ? Map<String, dynamic>.from(json['subject'] as Map)
        : <String, dynamic>{};
    final submission = json['submission'] is Map
        ? Map<String, dynamic>.from(json['submission'] as Map)
        : <String, dynamic>{};
    final assignedAt = json['assigned_at']?.toString();
    final deadline = json['deadline']?.toString();
    final submittedAtStr =
        json['submitted_at']?.toString() ??
        submission['submitted_at']?.toString();
    final maxScore = json['max_score'];
    final score = json['score'] ?? submission['score'];

    StudentAttachmentModel? parsedAttachment;
    if (json['attachments'] is List &&
        (json['attachments'] as List).isNotEmpty) {
      final first = (json['attachments'] as List).first;
      if (first is Map) {
        parsedAttachment = StudentAttachmentModel.fromJson(
          Map<String, dynamic>.from(first),
        );
      }
    } else if (json['attachment'] is Map) {
      parsedAttachment = StudentAttachmentModel.fromJson(
        Map<String, dynamic>.from(json['attachment'] as Map),
      );
    }

    StudentAttachmentModel? parsedStudentSubmission;
    if (json['student_submission'] is Map) {
      parsedStudentSubmission = StudentAttachmentModel.fromJson(
        Map<String, dynamic>.from(json['student_submission'] as Map),
      );
    } else if (submission['file_name'] != null ||
        submission['storage_path'] != null) {
      parsedStudentSubmission = StudentAttachmentModel.fromJson(
        Map<String, dynamic>.from(submission),
      );
    }

    return StudentClassworkModel(
      id: json['id'].toString(),
      type: (json['type'] ?? json['classwork_type'])?.toString() ?? 'activity',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      instructions: json['instructions']?.toString() ?? '',
      subjectName:
          (json['subject_name'] ?? subject['subject_name'])?.toString() ?? '',
      sectionName:
          (json['section_name'] ?? subject['section_name'])?.toString() ?? '',
      gradeLevel:
          (json['grade_level'] ?? subject['grade_level'])?.toString() ?? '',
      assignedAt: assignedAt == null ? null : DateTime.tryParse(assignedAt),
      deadline: deadline == null ? null : DateTime.tryParse(deadline),
      maxScore: maxScore is num ? maxScore.toDouble() : 0,
      status: (json['status'] ?? submission['status'])?.toString(),
      score: score is num ? score.toDouble() : null,
      feedback: (json['feedback'] ?? submission['feedback'])?.toString(),
      attachment: parsedAttachment,
      studentSubmission: parsedStudentSubmission,
      submittedAt: submittedAtStr == null
          ? null
          : DateTime.tryParse(submittedAtStr),
      completionMode: json['completion_mode']?.toString() ?? 'online',
      termNumber: json['term_number'] is num
          ? (json['term_number'] as num).toInt()
          : (int.tryParse(json['term_number']?.toString() ?? '') ?? 1),
      gradebookColumnIndex: json['gradebook_column_index'] is num
          ? (json['gradebook_column_index'] as num).toInt()
          : int.tryParse(json['gradebook_column_index']?.toString() ?? ''),
    );
  }
}
