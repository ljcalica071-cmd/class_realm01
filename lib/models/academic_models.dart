enum AttendanceStatus { present, late, absent, excused }

enum SyncStatus { online, offline, pendingSync, syncing, synced, syncError }

enum ActivityStatus {
  pending,
  submitted,
  checked,
  graded,
  lateSubmission,
  returned,
}

enum AssessmentType { quiz, examination }

enum SubmissionType { fileOnly, textOnly, fileAndText }

enum QuestionType { multipleChoice, trueFalse, identification, matching }

class AttendanceRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String section;
  final DateTime date;
  final String timeIn;
  final AttendanceStatus status;
  final String method; // 'RFID (ESP32)' or 'Manual'
  final bool isSynced;

  AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.section,
    required this.date,
    required this.timeIn,
    required this.status,
    this.method = 'Manual',
    this.isSynced = true,
  });

  AttendanceRecord copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? section,
    DateTime? date,
    String? timeIn,
    AttendanceStatus? status,
    String? method,
    bool? isSynced,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      section: section ?? this.section,
      date: date ?? this.date,
      timeIn: timeIn ?? this.timeIn,
      status: status ?? this.status,
      method: method ?? this.method,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

class ActivityModel {
  final String id;
  final String title;
  final String description;
  final String instructions;
  final String subject;
  final String gradeLevel;
  final String section;
  final DateTime dateAssigned;
  final DateTime deadline;
  final double maxScore;
  final bool isPublished;
  final bool
  isRequirement; // true if Performance Task / Requirement, false if Activity
  final String? attachmentName;
  final SubmissionType submissionType;
  final int submissionsCount;
  final int totalStudents;
  final Map<String, DateTime> sectionDeadlines;

  ActivityModel({
    required this.id,
    required this.title,
    required this.description,
    this.instructions = '',
    required this.subject,
    this.gradeLevel = 'Grade 11',
    required this.section,
    DateTime? dateAssigned,
    required this.deadline,
    required this.maxScore,
    this.isPublished = true,
    this.isRequirement = false,
    this.attachmentName,
    this.submissionType = SubmissionType.fileAndText,
    this.submissionsCount = 0,
    this.totalStudents = 35,
    Map<String, DateTime>? sectionDeadlines,
  }) : dateAssigned = dateAssigned ?? DateTime.now(),
       sectionDeadlines = sectionDeadlines ?? {section: deadline};

  List<String> get assignedSections => sectionDeadlines.keys.toList();

  DateTime deadlineForSection(String targetSection) =>
      sectionDeadlines[targetSection] ?? deadline;

  ActivityModel copyWith({
    String? id,
    String? title,
    String? description,
    String? instructions,
    String? subject,
    String? gradeLevel,
    String? section,
    DateTime? dateAssigned,
    DateTime? deadline,
    double? maxScore,
    bool? isPublished,
    bool? isRequirement,
    String? attachmentName,
    SubmissionType? submissionType,
    int? submissionsCount,
    int? totalStudents,
    Map<String, DateTime>? sectionDeadlines,
  }) {
    return ActivityModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      instructions: instructions ?? this.instructions,
      subject: subject ?? this.subject,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      section: section ?? this.section,
      dateAssigned: dateAssigned ?? this.dateAssigned,
      deadline: deadline ?? this.deadline,
      maxScore: maxScore ?? this.maxScore,
      isPublished: isPublished ?? this.isPublished,
      isRequirement: isRequirement ?? this.isRequirement,
      attachmentName: attachmentName ?? this.attachmentName,
      submissionType: submissionType ?? this.submissionType,
      submissionsCount: submissionsCount ?? this.submissionsCount,
      totalStudents: totalStudents ?? this.totalStudents,
      sectionDeadlines: sectionDeadlines ?? this.sectionDeadlines,
    );
  }
}

class StudentSubmission {
  final String id;
  final String activityOrExamId;
  final String studentId;
  final String studentName;
  final DateTime submittedAt;
  final String? attachedFile;
  final String? textSubmission;
  final double? score;
  final double maxScore;
  final ActivityStatus status;
  final String? feedback;

  StudentSubmission({
    required this.id,
    required this.activityOrExamId,
    required this.studentId,
    required this.studentName,
    required this.submittedAt,
    this.attachedFile,
    this.textSubmission,
    this.score,
    required this.maxScore,
    this.status = ActivityStatus.pending,
    this.feedback,
  });

  StudentSubmission copyWith({
    String? id,
    String? activityOrExamId,
    String? studentId,
    String? studentName,
    DateTime? submittedAt,
    String? attachedFile,
    String? textSubmission,
    double? score,
    double? maxScore,
    ActivityStatus? status,
    String? feedback,
  }) {
    return StudentSubmission(
      id: id ?? this.id,
      activityOrExamId: activityOrExamId ?? this.activityOrExamId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      submittedAt: submittedAt ?? this.submittedAt,
      attachedFile: attachedFile ?? this.attachedFile,
      textSubmission: textSubmission ?? this.textSubmission,
      score: score ?? this.score,
      maxScore: maxScore ?? this.maxScore,
      status: status ?? this.status,
      feedback: feedback ?? this.feedback,
    );
  }
}

class QuestionModel {
  final String id;
  final String questionText;
  final QuestionType type;
  final List<String> choices;
  final String correctAnswer; // e.g. "A", "True", "Quadratic Formula", etc.
  final double points;
  final Map<String, String> matchingPairs;

  QuestionModel({
    required this.id,
    required this.questionText,
    required this.type,
    this.choices = const [],
    required this.correctAnswer,
    this.points = 1.0,
    this.matchingPairs = const {},
  });
}

class QuizOrExamModel {
  final String id;
  final String title;
  final String description;
  final String subject;
  final String section;
  final bool isExam; // true: Examination, false: Quiz
  final int durationMinutes;
  final DateTime scheduleDate;
  final bool isPublished;
  final bool resultsReleased;
  final List<QuestionModel> questions;
  final Map<String, DateTime> sectionDeadlines;

  QuizOrExamModel({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.section,
    required this.isExam,
    required this.durationMinutes,
    required this.scheduleDate,
    this.isPublished = true,
    this.resultsReleased = false,
    required this.questions,
    Map<String, DateTime>? sectionDeadlines,
  }) : sectionDeadlines = sectionDeadlines ?? {section: scheduleDate};

  double get totalPoints => questions.fold(0, (sum, q) => sum + q.points);
  List<String> get assignedSections => sectionDeadlines.keys.toList();
  DateTime deadlineForSection(String targetSection) =>
      sectionDeadlines[targetSection] ?? scheduleDate;

  QuizOrExamModel copyWith({
    String? id,
    String? title,
    String? description,
    String? subject,
    String? section,
    bool? isExam,
    int? durationMinutes,
    DateTime? scheduleDate,
    bool? isPublished,
    bool? resultsReleased,
    List<QuestionModel>? questions,
    Map<String, DateTime>? sectionDeadlines,
  }) {
    return QuizOrExamModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      section: section ?? this.section,
      isExam: isExam ?? this.isExam,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      scheduleDate: scheduleDate ?? this.scheduleDate,
      isPublished: isPublished ?? this.isPublished,
      resultsReleased: resultsReleased ?? this.resultsReleased,
      questions: questions ?? this.questions,
      sectionDeadlines: sectionDeadlines ?? this.sectionDeadlines,
    );
  }
}

class AssessmentResultModel {
  final String id;
  final String assessmentId;
  final String studentId;
  final String studentName;
  final DateTime submittedAt;
  final int durationTakenMinutes;
  final int violationCount;
  final List<Map<String, dynamic>> violationLog;
  final Map<String, String> answers; // questionId -> student answer
  final double scoreEarned;
  final double totalPoints;
  final bool isReleased;
  final bool needsTeacherReview;

  AssessmentResultModel({
    required this.id,
    required this.assessmentId,
    required this.studentId,
    required this.studentName,
    required this.submittedAt,
    required this.durationTakenMinutes,
    this.violationCount = 0,
    this.violationLog = const [],
    required this.answers,
    required this.scoreEarned,
    required this.totalPoints,
    this.isReleased = false,
    this.needsTeacherReview = false,
  });

  AssessmentResultModel copyWith({
    String? id,
    String? assessmentId,
    String? studentId,
    String? studentName,
    DateTime? submittedAt,
    int? durationTakenMinutes,
    int? violationCount,
    List<Map<String, dynamic>>? violationLog,
    Map<String, String>? answers,
    double? scoreEarned,
    double? totalPoints,
    bool? isReleased,
    bool? needsTeacherReview,
  }) {
    return AssessmentResultModel(
      id: id ?? this.id,
      assessmentId: assessmentId ?? this.assessmentId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      submittedAt: submittedAt ?? this.submittedAt,
      durationTakenMinutes: durationTakenMinutes ?? this.durationTakenMinutes,
      violationCount: violationCount ?? this.violationCount,
      violationLog: violationLog ?? this.violationLog,
      answers: answers ?? this.answers,
      scoreEarned: scoreEarned ?? this.scoreEarned,
      totalPoints: totalPoints ?? this.totalPoints,
      isReleased: isReleased ?? this.isReleased,
      needsTeacherReview: needsTeacherReview ?? this.needsTeacherReview,
    );
  }

  double get percentage =>
      totalPoints > 0 ? (scoreEarned / totalPoints) * 100 : 0.0;
}

class ExamStudentAnswer {
  final String questionId;
  final String studentAnswer;
  final bool isCorrect;
  final double scoreEarned;

  ExamStudentAnswer({
    required this.questionId,
    required this.studentAnswer,
    required this.isCorrect,
    required this.scoreEarned,
  });
}

class ExamSubmissionReview {
  final String id;
  final String examId;
  final String studentId;
  final String studentName;
  final DateTime submittedAt;
  final List<ExamStudentAnswer> answers;
  final double calculatedScore;
  final double manualAdjustedScore;
  final bool isChecked;
  final bool isFinalized;

  ExamSubmissionReview({
    required this.id,
    required this.examId,
    required this.studentId,
    required this.studentName,
    required this.submittedAt,
    required this.answers,
    required this.calculatedScore,
    required this.manualAdjustedScore,
    this.isChecked = true,
    this.isFinalized = false,
  });

  ExamSubmissionReview copyWith({
    String? id,
    String? examId,
    String? studentId,
    String? studentName,
    DateTime? submittedAt,
    List<ExamStudentAnswer>? answers,
    double? calculatedScore,
    double? manualAdjustedScore,
    bool? isChecked,
    bool? isFinalized,
  }) {
    return ExamSubmissionReview(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      submittedAt: submittedAt ?? this.submittedAt,
      answers: answers ?? this.answers,
      calculatedScore: calculatedScore ?? this.calculatedScore,
      manualAdjustedScore: manualAdjustedScore ?? this.manualAdjustedScore,
      isChecked: isChecked ?? this.isChecked,
      isFinalized: isFinalized ?? this.isFinalized,
    );
  }
}

class GradingCriteria {
  final String id;
  final String name;
  final double percentage; // e.g., 30.0 for 30%

  GradingCriteria({
    required this.id,
    required this.name,
    required this.percentage,
  });

  GradingCriteria copyWith({String? id, String? name, double? percentage}) {
    return GradingCriteria(
      id: id ?? this.id,
      name: name ?? this.name,
      percentage: percentage ?? this.percentage,
    );
  }
}

class LessonPlanModel {
  final String id;
  final String topic;
  final String gradeLevel;
  final String subject;
  final String duration;
  final String objectives;
  final String materials;
  final String procedure;
  final String assessment;
  final String assignment;
  final DateTime createdAt;
  final bool isArchived;

  LessonPlanModel({
    required this.id,
    required this.topic,
    required this.gradeLevel,
    required this.subject,
    required this.duration,
    required this.objectives,
    required this.materials,
    required this.procedure,
    required this.assessment,
    required this.assignment,
    required this.createdAt,
    this.isArchived = false,
  });

  LessonPlanModel copyWith({
    String? id,
    String? topic,
    String? gradeLevel,
    String? subject,
    String? duration,
    String? objectives,
    String? materials,
    String? procedure,
    String? assessment,
    String? assignment,
    DateTime? createdAt,
    bool? isArchived,
  }) {
    return LessonPlanModel(
      id: id ?? this.id,
      topic: topic ?? this.topic,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      subject: subject ?? this.subject,
      duration: duration ?? this.duration,
      objectives: objectives ?? this.objectives,
      materials: materials ?? this.materials,
      procedure: procedure ?? this.procedure,
      assessment: assessment ?? this.assessment,
      assignment: assignment ?? this.assignment,
      createdAt: createdAt ?? this.createdAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}

class LearningMaterialModel {
  final String id;
  final String title;
  final String category; // PDF, Document, Slide, Video Link
  final String topic;
  final String fileName;
  final String fileSize;
  final DateTime uploadedAt;
  final String description;
  final String section;

  LearningMaterialModel({
    required this.id,
    required this.title,
    required this.category,
    required this.topic,
    required this.fileName,
    required this.fileSize,
    required this.uploadedAt,
    required this.description,
    required this.section,
  });
}

class ScheduleModel {
  final String id;
  final String subject;
  final String section;
  final String room;
  final String dayOfWeek; // 'Monday', 'Tuesday', etc.
  final String startTime;
  final String endTime;

  ScheduleModel({
    required this.id,
    required this.subject,
    required this.section,
    required this.room,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });
}

class AppNotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String type; // 'attendance', 'grade', 'activity', 'announcement'

  AppNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    required this.type,
  });
}
