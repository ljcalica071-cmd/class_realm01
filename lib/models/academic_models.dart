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
  final String? remarks;
  final AttendanceStatus status;
  final String method; // 'RFID (ESP32)' or 'Manual'
  final bool isSynced;

  AttendanceRecord({
    required this.id,
    required this.studentId,
    this.studentName = '',
    this.section = '',
    required this.date,
    required this.timeIn,
    this.remarks,
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
    String? remarks,
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
      remarks: remarks ?? this.remarks,
      status: status ?? this.status,
      method: method ?? this.method,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    AttendanceStatus parseStatus(dynamic val) {
      if (val is AttendanceStatus) return val;
      final s = val?.toString().toLowerCase().trim();
      if (s == 'late') return AttendanceStatus.late;
      if (s == 'absent') return AttendanceStatus.absent;
      if (s == 'excused') return AttendanceStatus.excused;
      return AttendanceStatus.present;
    }

    return AttendanceRecord(
      id: json['id']?.toString() ?? '',
      studentId:
          json['student_id']?.toString() ?? json['studentId']?.toString() ?? '',
      studentName:
          json['student_name']?.toString() ??
          json['studentName']?.toString() ??
          '',
      section: json['section']?.toString() ?? '',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : (json['attendance_date'] != null
                ? DateTime.tryParse(json['attendance_date'].toString()) ??
                      DateTime.now()
                : DateTime.now()),
      timeIn:
          json['time_in']?.toString() ?? json['timeIn']?.toString() ?? '--:--',
      remarks: json['remarks']?.toString(),
      status: parseStatus(json['status']),
      method:
          json['method']?.toString() ?? json['source']?.toString() ?? 'Manual',
      isSynced: json['is_synced'] as bool? ?? json['isSynced'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'section': section,
      'date': date.toIso8601String(),
      'time_in': timeIn,
      'remarks': remarks,
      'status': status.name,
      'method': method,
      'is_synced': isSynced,
    };
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
  final String? subjectOfferingId;
  final String? storagePath;
  final String? mimeType;
  final int? fileSizeBytes;
  final SubmissionType submissionType;
  final int submissionsCount;
  final int totalStudents;
  final Map<String, DateTime> sectionDeadlines;

  // New Classwork Fields
  final int termNumber;
  final int? gradebookColumnIndex;
  final String completionMode; // 'online' or 'in_person'
  final bool allowLateSubmission;
  final String? batchGroupId;
  final bool isArchived;
  final DateTime? updatedInstructionsAt;
  final List<String>? targetStudentIds;
  final String? gradingCategory;

  String get effectiveGradingCategory {
    final cat = gradingCategory?.trim().toLowerCase();
    if (cat == 'ww' || cat == 'pt' || cat == 'ex') return cat!;
    return isRequirement ? 'pt' : 'ww';
  }

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
    this.subjectOfferingId,
    this.storagePath,
    this.mimeType,
    this.fileSizeBytes,
    this.submissionType = SubmissionType.fileAndText,
    this.submissionsCount = 0,
    this.totalStudents = 35,
    Map<String, DateTime>? sectionDeadlines,
    this.termNumber = 1,
    this.gradebookColumnIndex,
    this.completionMode = 'online',
    this.allowLateSubmission = true,
    this.batchGroupId,
    this.isArchived = false,
    this.updatedInstructionsAt,
    this.targetStudentIds,
    this.gradingCategory,
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
    String? subjectOfferingId,
    String? storagePath,
    String? mimeType,
    int? fileSizeBytes,
    SubmissionType? submissionType,
    int? submissionsCount,
    int? totalStudents,
    Map<String, DateTime>? sectionDeadlines,
    int? termNumber,
    int? gradebookColumnIndex,
    String? completionMode,
    bool? allowLateSubmission,
    String? batchGroupId,
    bool? isArchived,
    DateTime? updatedInstructionsAt,
    List<String>? targetStudentIds,
    String? gradingCategory,
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
      subjectOfferingId: subjectOfferingId ?? this.subjectOfferingId,
      storagePath: storagePath ?? this.storagePath,
      mimeType: mimeType ?? this.mimeType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      submissionType: submissionType ?? this.submissionType,
      submissionsCount: submissionsCount ?? this.submissionsCount,
      totalStudents: totalStudents ?? this.totalStudents,
      sectionDeadlines: sectionDeadlines ?? this.sectionDeadlines,
      termNumber: termNumber ?? this.termNumber,
      gradebookColumnIndex: gradebookColumnIndex ?? this.gradebookColumnIndex,
      completionMode: completionMode ?? this.completionMode,
      allowLateSubmission: allowLateSubmission ?? this.allowLateSubmission,
      batchGroupId: batchGroupId ?? this.batchGroupId,
      isArchived: isArchived ?? this.isArchived,
      updatedInstructionsAt:
          updatedInstructionsAt ?? this.updatedInstructionsAt,
      targetStudentIds: targetStudentIds ?? this.targetStudentIds,
      gradingCategory: gradingCategory ?? this.gradingCategory,
    );
  }

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    final deadlineRaw = json['deadline'];
    final assignedRaw = json['assigned_at'] ?? json['date_assigned'];
    final parsedDeadline = deadlineRaw != null
        ? DateTime.tryParse(deadlineRaw.toString())?.toLocal() ?? DateTime.now()
        : DateTime.now();
    final parsedAssigned = assignedRaw != null
        ? DateTime.tryParse(assignedRaw.toString())?.toLocal() ?? DateTime.now()
        : DateTime.now();

    final classworkType = json['classwork_type']?.toString();
    final gradingCat = json['grading_category']?.toString();
    final isReq =
        classworkType == 'performance_task' ||
        gradingCat == 'pt' ||
        json['is_requirement'] == true;

    final offering = json['subject_offerings'];
    final subjectName = (offering is Map && offering['subjects'] is Map)
        ? offering['subjects']['subject_name']?.toString() ?? ''
        : json['subject']?.toString() ?? '';
    final sectionName = (offering is Map && offering['sections'] is Map)
        ? offering['sections']['section_name']?.toString() ?? ''
        : json['section']?.toString() ?? '';
    final gradeLevelName = (offering is Map && offering['sections'] is Map)
        ? offering['sections']['grade_level']?.toString() ?? 'Grade 11'
        : json['grade_level']?.toString() ?? 'Grade 11';

    String? attName;
    String? sPath;
    String? mType;
    int? sBytes;

    if (json['attachment'] is Map) {
      final att = json['attachment'] as Map;
      attName = att['file_name']?.toString();
      sPath = att['storage_path']?.toString();
      mType = att['mime_type']?.toString();
      sBytes = (att['file_size_bytes'] as num?)?.toInt();
    } else if (json['classwork_attachments'] is List &&
        (json['classwork_attachments'] as List).isNotEmpty) {
      final att = (json['classwork_attachments'] as List).first;
      if (att is Map) {
        attName = att['file_name']?.toString();
        sPath = att['storage_path']?.toString();
        mType = att['mime_type']?.toString();
        sBytes = (att['file_size_bytes'] as num?)?.toInt();
      }
    } else {
      attName =
          json['attachment_name']?.toString() ?? json['file_name']?.toString();
      sPath = json['storage_path']?.toString();
      mType = json['mime_type']?.toString();
      sBytes = (json['file_size_bytes'] as num?)?.toInt();
    }

    List<String>? parsedTargetStudentIds;
    if (json['target_student_ids'] != null) {
      parsedTargetStudentIds = (json['target_student_ids'] as List)
          .map((e) => e.toString())
          .toList();
    }

    return ActivityModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      instructions: json['instructions']?.toString() ?? '',
      subject: subjectName,
      gradeLevel: gradeLevelName,
      section: sectionName,
      dateAssigned: parsedAssigned,
      deadline: parsedDeadline,
      maxScore: (json['max_score'] as num?)?.toDouble() ?? 100.0,
      isPublished: json['is_published'] != false,
      isRequirement: isReq,
      attachmentName: attName,
      subjectOfferingId: json['subject_offering_id']?.toString(),
      storagePath: sPath,
      mimeType: mType,
      fileSizeBytes: sBytes,
      termNumber: json['term_number'] is int ? json['term_number'] as int : 1,
      gradebookColumnIndex: json['gradebook_column_index'] as int?,
      completionMode: json['completion_mode']?.toString() ?? 'online',
      allowLateSubmission: json['allow_late_submission'] != false,
      batchGroupId: json['batch_group_id']?.toString(),
      isArchived: json['is_archived'] == true,
      updatedInstructionsAt: json['updated_instructions_at'] != null
          ? DateTime.tryParse(json['updated_instructions_at'].toString())
          : null,
      targetStudentIds: parsedTargetStudentIds,
      gradingCategory: gradingCat,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'instructions': instructions,
      'subject': subject,
      'grade_level': gradeLevel,
      'section': section,
      'deadline': deadline.toIso8601String(),
      'max_score': maxScore,
      'is_published': isPublished,
      'is_requirement': isRequirement,
      'subject_offering_id': subjectOfferingId,
      'attachment_name': attachmentName,
      'storage_path': storagePath,
      'mime_type': mimeType,
      'file_size_bytes': fileSizeBytes,
    };
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

class ClassworkSlotSummary {
  final Set<int> occupiedWwSlots;
  final Set<int> occupiedPtSlots;
  final bool st1Created;
  final bool st2Created;
  final bool teCreated;
  final int maxWwSlot;
  final int maxPtSlot;

  const ClassworkSlotSummary({
    this.occupiedWwSlots = const <int>{},
    this.occupiedPtSlots = const <int>{},
    this.st1Created = false,
    this.st2Created = false,
    this.teCreated = false,
    this.maxWwSlot = 3,
    this.maxPtSlot = 3,
  });
}

bool isSameClassworkSchedule(
  DateTime a,
  DateTime b, {
  required bool isInPerson,
}) {
  final al = a.toLocal();
  final bl = b.toLocal();
  if (isInPerson) {
    return al.year == bl.year && al.month == bl.month && al.day == bl.day;
  }
  return al.year == bl.year &&
      al.month == bl.month &&
      al.day == bl.day &&
      al.hour == bl.hour &&
      al.minute == bl.minute;
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

  factory QuestionModel.fromSupabaseMap(Map<String, dynamic> q) {
    final qTypeStr = q['question_type']?.toString().toLowerCase() ?? '';
    final qType = switch (qTypeStr) {
      'multiple_choice' => QuestionType.multipleChoice,
      'true_false' => QuestionType.trueFalse,
      'identification' => QuestionType.identification,
      'matching_type' => QuestionType.matching,
      _ => QuestionType.multipleChoice,
    };

    final opts = (q['assessment_question_options'] as List? ?? [])
        .map((o) => Map<String, dynamic>.from(o as Map))
        .toList()
      ..sort(
        (a, b) => ((a['position'] as num?) ?? 0).compareTo(
          (b['position'] as num?) ?? 0,
        ),
      );

    final choices = <String>[];
    String correctAnswer = '';

    if (qType == QuestionType.multipleChoice) {
      const labels = ['A', 'B', 'C', 'D'];
      for (int i = 0; i < opts.length; i++) {
        final opt = opts[i];
        final text = opt['option_text']?.toString() ?? '';
        choices.add(text);
        if (opt['is_correct'] == true) {
          final pos = ((opt['position'] as num?)?.toInt() ?? (i + 1)).clamp(
            1,
            labels.length,
          );
          correctAnswer = labels[pos - 1];
        }
      }
    } else if (qType == QuestionType.trueFalse) {
      choices.addAll(const ['True', 'False']);
      for (final opt in opts) {
        if (opt['is_correct'] == true) {
          final txt = opt['option_text']?.toString().trim().toLowerCase();
          final pos = (opt['position'] as num?)?.toInt();
          correctAnswer = (txt == 'false' || pos == 2) ? 'False' : 'True';
        }
      }
    } else if (qType == QuestionType.identification) {
      for (final opt in opts) {
        if (opt['is_correct'] == true) {
          correctAnswer = opt['option_text']?.toString() ?? '';
          break;
        }
      }
      if (correctAnswer.isEmpty && opts.isNotEmpty) {
        correctAnswer = opts.first['option_text']?.toString() ?? '';
      }
    }

    return QuestionModel(
      id: q['id']?.toString() ?? '',
      questionText: q['question_text']?.toString() ?? '',
      type: qType,
      choices: choices,
      correctAnswer: correctAnswer,
      points: (q['points'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'questionText': questionText,
    'type': type.name,
    'choices': choices,
    'correctAnswer': correctAnswer,
    'points': points,
    'matchingPairs': matchingPairs,
  };

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString() ?? '';
    final qType = QuestionType.values.firstWhere(
      (e) => e.name == rawType,
      orElse: () => QuestionType.multipleChoice,
    );
    final rawChoices = (json['choices'] as List? ?? [])
        .map((c) => c.toString())
        .toList();
    final rawPairs = Map<String, String>.from(
      (json['matchingPairs'] as Map? ?? {}).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ),
    );
    return QuestionModel(
      id: json['id']?.toString() ?? '',
      questionText: json['questionText']?.toString() ?? '',
      type: qType,
      choices: rawChoices,
      correctAnswer: json['correctAnswer']?.toString() ?? '',
      points: (json['points'] as num?)?.toDouble() ?? 1.0,
      matchingPairs: rawPairs,
    );
  }

  bool matchesStudentAnswer(String rawAnswer) {
    final studentAns = rawAnswer.trim().toLowerCase();
    if (studentAns.isEmpty || studentAns == 'n/a') return false;

    if (type == QuestionType.matching) {
      return matchingPairs.isNotEmpty &&
          matchingPairs.entries.every(
            (pair) => studentAns.contains(
              '${pair.key.toLowerCase()}=${pair.value.toLowerCase()}',
            ),
          );
    }

    final correctAns = correctAnswer.trim().toLowerCase();
    if (studentAns == correctAns) return true;

    if (type == QuestionType.multipleChoice) {
      const letters = ['a', 'b', 'c', 'd'];
      final idx = letters.indexOf(correctAns);
      if (idx != -1 && idx < choices.length) {
        return choices[idx].trim().toLowerCase() == studentAns;
      }
    }

    return false;
  }
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
  final String completionMode; // 'online' or 'in_person'
  final int termNumber;
  final int? gradebookColumnIndex;
  final String? subjectOfferingId;
  final double? maxScore;
  final String? examType;

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
    this.questions = const [],
    Map<String, DateTime>? sectionDeadlines,
    this.completionMode = 'online',
    this.termNumber = 1,
    this.gradebookColumnIndex,
    this.subjectOfferingId,
    this.maxScore,
    this.examType,
  }) : sectionDeadlines = sectionDeadlines ?? {section: scheduleDate};

  double get totalPoints => questions.isNotEmpty
      ? questions.fold(0, (sum, q) => sum + q.points)
      : (maxScore ?? 0);
  DateTime get scheduledDate => scheduleDate;
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
    String? completionMode,
    int? termNumber,
    int? gradebookColumnIndex,
    String? subjectOfferingId,
    double? maxScore,
    String? examType,
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
      completionMode: completionMode ?? this.completionMode,
      termNumber: termNumber ?? this.termNumber,
      gradebookColumnIndex: gradebookColumnIndex ?? this.gradebookColumnIndex,
      subjectOfferingId: subjectOfferingId ?? this.subjectOfferingId,
      maxScore: maxScore ?? this.maxScore,
      examType: examType ?? this.examType,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'subject': subject,
    'section': section,
    'isExam': isExam,
    'durationMinutes': durationMinutes,
    'scheduleDate': scheduleDate.toIso8601String(),
    'isPublished': isPublished,
    'resultsReleased': resultsReleased,
    'questions': questions.map((q) => q.toJson()).toList(),
    'completionMode': completionMode,
    'termNumber': termNumber,
    'gradebookColumnIndex': gradebookColumnIndex,
    'subjectOfferingId': subjectOfferingId,
    'maxScore': maxScore,
    'examType': examType,
  };

  factory QuizOrExamModel.fromJson(Map<String, dynamic> json) {
    final rawQuestions = (json['questions'] as List? ?? [])
        .map((q) => QuestionModel.fromJson(Map<String, dynamic>.from(q as Map)))
        .toList();
    final schedStr = json['scheduleDate']?.toString();
    final sched = schedStr != null
        ? (DateTime.tryParse(schedStr) ?? DateTime.now())
        : DateTime.now();
    return QuizOrExamModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      section: json['section']?.toString() ?? '',
      isExam: json['isExam'] == true,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 60,
      scheduleDate: sched,
      isPublished: json['isPublished'] != false,
      resultsReleased: json['resultsReleased'] == true,
      questions: rawQuestions,
      completionMode: json['completionMode']?.toString() ?? 'online',
      termNumber: (json['termNumber'] as num?)?.toInt() ?? 1,
      gradebookColumnIndex: (json['gradebookColumnIndex'] as num?)?.toInt(),
      subjectOfferingId: json['subjectOfferingId']?.toString(),
      maxScore: (json['maxScore'] as num?)?.toDouble(),
      examType: json['examType']?.toString(),
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
  final String startTime; // "HH:MM AM/PM"
  final String endTime; // "HH:MM AM/PM"
  final String? sectionId;
  final String? subjectId;
  final String? teacherId;
  final int? gradeLevel;
  final double? wwWeight;
  final double? ptWeight;
  final double? exWeight;

  ScheduleModel({
    required this.id,
    required this.subject,
    required this.section,
    required this.room,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.sectionId,
    this.subjectId,
    this.teacherId,
    this.gradeLevel,
    this.wwWeight,
    this.ptWeight,
    this.exWeight,
  });

  String get subjectName => subject;

  int get startMinutes => _parseTimeToMinutes(startTime);
  int get endMinutes => _parseTimeToMinutes(endTime);
  int get durationMinutes => endMinutes - startMinutes;

  int get dayOfWeekIndex {
    final clean = dayOfWeek.trim().toLowerCase();
    if (clean.startsWith('mon')) return 1;
    if (clean.startsWith('tue')) return 2;
    if (clean.startsWith('wed')) return 3;
    if (clean.startsWith('thu')) return 4;
    if (clean.startsWith('fri')) return 5;
    if (clean.startsWith('sat')) return 6;
    if (clean.startsWith('sun')) return 7;
    return 0;
  }

  static String dayFromIndex(int index) {
    switch (index) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Monday';
    }
  }

  static String formatTime24to12(String time24) {
    try {
      final parts = time24.split(':');
      int h = int.parse(parts[0]);
      int m = int.parse(parts[1]);
      final ampm = h >= 12 ? 'PM' : 'AM';
      int displayHour = h % 12;
      if (displayHour == 0) displayHour = 12;
      return '${displayHour.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return time24;
    }
  }

  static String formatTime12to24(String time12) {
    try {
      final parts = time12.trim().split(' ');
      final hm = parts[0].split(':');
      int h = int.parse(hm[0]);
      int m = int.parse(hm[1]);
      final ampm = parts.length > 1 ? parts[1].toUpperCase() : 'AM';
      if (ampm == 'PM' && h != 12) h += 12;
      if (ampm == 'AM' && h == 12) h = 0;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00';
    } catch (_) {
      return time12;
    }
  }

  int _parseTimeToMinutes(String time) {
    try {
      final parts = time.split(' ');
      if (parts.length < 2) return 0;
      final hm = parts[0].split(':');
      int h = int.parse(hm[0]);
      final m = int.parse(hm[1]);
      final ampm = parts[1].toUpperCase();

      if (ampm == 'PM' && h != 12) h += 12;
      if (ampm == 'AM' && h == 12) h = 0;

      return h * 60 + m;
    } catch (e) {
      return 0;
    }
  }

  ScheduleModel copyWith({
    String? id,
    String? subject,
    String? section,
    String? room,
    String? dayOfWeek,
    String? startTime,
    String? endTime,
    String? sectionId,
    String? subjectId,
    String? teacherId,
    int? gradeLevel,
    double? wwWeight,
    double? ptWeight,
    double? exWeight,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      section: section ?? this.section,
      room: room ?? this.room,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      sectionId: sectionId ?? this.sectionId,
      subjectId: subjectId ?? this.subjectId,
      teacherId: teacherId ?? this.teacherId,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      wwWeight: wwWeight ?? this.wwWeight,
      ptWeight: ptWeight ?? this.ptWeight,
      exWeight: exWeight ?? this.exWeight,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject': subject,
      'section': section,
      'room': room,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'sectionId': sectionId,
      'subjectId': subjectId,
      'teacherId': teacherId,
      'gradeLevel': gradeLevel,
      'wwWeight': wwWeight,
      'ptWeight': ptWeight,
      'exWeight': exWeight,
    };
  }

  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    return ScheduleModel(
      id: map['id']?.toString() ?? '',
      subject: map['subject']?.toString() ?? '',
      section: map['section']?.toString() ?? '',
      room: map['room']?.toString() ?? '',
      dayOfWeek: map['dayOfWeek']?.toString() ?? 'Monday',
      startTime: map['startTime']?.toString() ?? '',
      endTime: map['endTime']?.toString() ?? '',
      sectionId: map['sectionId']?.toString(),
      subjectId: map['subjectId']?.toString(),
      teacherId: map['teacherId']?.toString(),
      gradeLevel: (map['gradeLevel'] as num?)?.toInt(),
      wwWeight: (map['wwWeight'] as num?)?.toDouble(),
      ptWeight: (map['ptWeight'] as num?)?.toDouble(),
      exWeight: (map['exWeight'] as num?)?.toDouble(),
    );
  }
}

class AppNotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String
  type; // 'attendance', 'grade', 'activity', 'announcement', 'general'
  final String targetAudience; // 'all', 'teachers', 'students_parents'
  final bool isArchived;
  final String? createdBy;

  AppNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    required this.type,
    this.targetAudience = 'all',
    this.isArchived = false,
    this.createdBy,
  });

  AppNotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? type,
    String? targetAudience,
    bool? isArchived,
    String? createdBy,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      targetAudience: targetAudience ?? this.targetAudience,
      isArchived: isArchived ?? this.isArchived,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  factory AppNotificationModel.fromJson(
    Map<String, dynamic> json, {
    bool isRead = false,
  }) {
    return AppNotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      timestamp: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: isRead || (json['is_read'] == true) || (json['read_at'] != null),
      type: json['notification_type']?.toString() ?? 'announcement',
      targetAudience: json['target_audience']?.toString() ?? 'all',
      isArchived: json['is_archived'] == true,
      createdBy: json['created_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'notification_type': type,
      'target_audience': targetAudience,
      'is_archived': isArchived,
      'created_by': createdBy,
      'created_at': timestamp.toIso8601String(),
    };
  }
}
