enum IlawPlanStatus { draft, approved }

class IlawGeneratedSections {
  final String intendedOutcomes;
  final String learningContent;
  final String assessment;
  final String workExperiences;

  const IlawGeneratedSections({
    required this.intendedOutcomes,
    required this.learningContent,
    required this.assessment,
    required this.workExperiences,
  });
}

class IlawLessonPlan {
  final String id;
  final String teacherId;
  final String teacherName;
  final String gradeLevel;
  final String quarter;
  final String subject;
  final String topic;
  final int durationMinutes;
  final String teachingStrategy;
  final String learningCompetency;
  final String intendedOutcomes;
  final String learningContent;
  final String assessment;
  final String workExperiences;
  final IlawPlanStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IlawLessonPlan({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.gradeLevel,
    required this.quarter,
    required this.subject,
    required this.topic,
    required this.durationMinutes,
    this.teachingStrategy = '',
    this.learningCompetency = '',
    required this.intendedOutcomes,
    required this.learningContent,
    required this.assessment,
    required this.workExperiences,
    this.status = IlawPlanStatus.draft,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isApproved => status == IlawPlanStatus.approved;

  String get formattedDuration => '$durationMinutes mins';

  IlawLessonPlan copyWith({
    String? id,
    String? teacherId,
    String? teacherName,
    String? gradeLevel,
    String? quarter,
    String? subject,
    String? topic,
    int? durationMinutes,
    String? teachingStrategy,
    String? learningCompetency,
    String? intendedOutcomes,
    String? learningContent,
    String? assessment,
    String? workExperiences,
    IlawPlanStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IlawLessonPlan(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      quarter: quarter ?? this.quarter,
      subject: subject ?? this.subject,
      topic: topic ?? this.topic,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      teachingStrategy: teachingStrategy ?? this.teachingStrategy,
      learningCompetency: learningCompetency ?? this.learningCompetency,
      intendedOutcomes: intendedOutcomes ?? this.intendedOutcomes,
      learningContent: learningContent ?? this.learningContent,
      assessment: assessment ?? this.assessment,
      workExperiences: workExperiences ?? this.workExperiences,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'grade_level': gradeLevel,
      'quarter': quarter,
      'subject': subject,
      'topic': topic,
      'duration_minutes': durationMinutes,
      'teaching_strategy': teachingStrategy,
      'learning_competency': learningCompetency,
      'intended_outcomes': intendedOutcomes,
      'learning_content': learningContent,
      'assessment': assessment,
      'work_experiences': workExperiences,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory IlawLessonPlan.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] ?? 'draft').toString().toLowerCase();
    final parsedStatus = rawStatus == 'approved'
        ? IlawPlanStatus.approved
        : IlawPlanStatus.draft;
    final created =
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now();
    final updated =
        DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? created;

    return IlawLessonPlan(
      id: (json['id'] ?? '').toString(),
      teacherId: (json['teacher_id'] ?? '').toString(),
      teacherName: (json['teacher_name'] ?? '').toString(),
      gradeLevel: (json['grade_level'] ?? 'Grade 11').toString(),
      quarter: (json['quarter'] ?? 'Quarter 1').toString(),
      subject: (json['subject'] ?? '').toString(),
      topic: (json['topic'] ?? '').toString(),
      durationMinutes: (json['duration_minutes'] is int)
          ? json['duration_minutes'] as int
          : (int.tryParse(json['duration_minutes']?.toString() ?? '') ?? 60),
      teachingStrategy: (json['teaching_strategy'] ?? '').toString(),
      learningCompetency: (json['learning_competency'] ?? '').toString(),
      intendedOutcomes: (json['intended_outcomes'] ?? '').toString(),
      learningContent: (json['learning_content'] ?? '').toString(),
      assessment: (json['assessment'] ?? '').toString(),
      workExperiences: (json['work_experiences'] ?? '').toString(),
      status: parsedStatus,
      createdAt: created,
      updatedAt: updated,
    );
  }

  /// Structured SHS New Curriculum iLAW template draft for manual authoring or
  /// offline testing before Gemini API keys are inserted into `.env`.
  static IlawGeneratedSections buildTemplateSections({
    required String subject,
    required String topic,
    required String gradeLevel,
    required String quarter,
    required int durationMinutes,
    String teachingStrategy = '',
    String learningCompetency = '',
  }) {
    final introMins = (durationMinutes * 0.15).round().clamp(5, 30);
    final purposeMins = (durationMinutes * 0.15).round().clamp(5, 30);
    final discussMins = (durationMinutes * 0.35).round().clamp(10, 90);
    final applyMins = (durationMinutes * 0.25).round().clamp(10, 60);
    final wrapMins =
        (durationMinutes - introMins - purposeMins - discussMins - applyMins)
            .clamp(5, 30);

    final competencyLine = learningCompetency.trim().isNotEmpty
        ? '\n- Target Competency: ${learningCompetency.trim()}'
        : '';
    final strategyNote = teachingStrategy.trim().isNotEmpty
        ? teachingStrategy.trim()
        : 'Collaborative & Inquiry-Based Learning';

    return IlawGeneratedSections(
      intendedOutcomes:
          'At the end of the $durationMinutes-minute lesson in $subject ($gradeLevel - $quarter), the learners shall be able to:\n'
          '1. Explain the core concepts and principles of $topic accurately;\n'
          '2. Apply $topic skills to solve contextualized Senior High School tasks; and\n'
          '3. Demonstrate active collaboration and critical thinking during class activities.',
      learningContent:
          '- Subject Matter / Topic: $topic$competencyLine\n'
          '- Curriculum Alignment: DepEd Senior High School (SHS) Strengthened Curriculum ($gradeLevel, $quarter)\n'
          '- Instructional Approach: $strategyNote\n'
          '- Learning Resources & Materials: Presentation slides, structured activity worksheet, board markers, and DepEd SHS reference guide.',
      assessment:
          '- Formative Assessment (10 Points): Short concept check and structured situational problem on $topic.\n'
          '- Performance Check: Rubric-guided peer evaluation focusing on accuracy (50%), reasoning clarity (30%), and group participation (20%).',
      workExperiences:
          '1. Activating Prior Knowledge ($introMins mins): Facilitate a brief recall activity connecting previous lessons to $topic.\n'
          '2. Establishing Lesson Purpose ($purposeMins mins): Present a real-world SHS situational prompt showing why $topic matters.\n'
          '3. Developing and Deepening Understanding ($discussMins mins): Guide learners through key concepts, worked examples, and interactive questioning using $strategyNote.\n'
          '4. Collaborative Application ($applyMins mins): Group learners into small teams to complete a structured practice task on $topic and present key findings.\n'
          '5. Making Generalizations & Assignment ($wrapMins mins): Synthesize lesson takeaways through learner reflection and assign a brief follow-up practice item.',
    );
  }
}
