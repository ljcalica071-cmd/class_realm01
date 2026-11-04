enum IlawPlanStatus { draft, approved }

enum IlawTemplateType {
  ilawStandard,
  ilawModified,
  multipleSession;

  String get label {
    switch (this) {
      case IlawTemplateType.ilawStandard:
        return 'iLAW Standard';
      case IlawTemplateType.ilawModified:
        return 'iLAW Modified (DepEd 2026)';
      case IlawTemplateType.multipleSession:
        return 'Multiple Session Matrix';
    }
  }

  static IlawTemplateType fromString(String? raw) {
    final clean = (raw ?? '').trim().toLowerCase();
    if (clean.contains('standard')) return IlawTemplateType.ilawStandard;
    if (clean.contains('multi')) return IlawTemplateType.multipleSession;
    return IlawTemplateType.ilawModified;
  }
}

enum IlawContentSource {
  curriculumBased,
  manual,
  uploadExemplar;

  String get label {
    switch (this) {
      case IlawContentSource.curriculumBased:
        return 'Curriculum Based';
      case IlawContentSource.manual:
        return 'Manual Input';
      case IlawContentSource.uploadExemplar:
        return 'Upload Exemplar';
    }
  }

  static IlawContentSource fromString(String? raw) {
    final clean = (raw ?? '').trim().toLowerCase();
    if (clean.contains('manual')) return IlawContentSource.manual;
    if (clean.contains('upload') || clean.contains('exemplar')) {
      return IlawContentSource.uploadExemplar;
    }
    return IlawContentSource.curriculumBased;
  }
}

enum DepEdProficiencyLevel {
  beginning,
  developing,
  approachingProficiency,
  proficient,
  advanced;

  String get label {
    switch (this) {
      case DepEdProficiencyLevel.beginning:
        return 'Beginning (74% and below)';
      case DepEdProficiencyLevel.developing:
        return 'Developing (75-79%)';
      case DepEdProficiencyLevel.approachingProficiency:
        return 'Approaching Proficiency (80-84%)';
      case DepEdProficiencyLevel.proficient:
        return 'Proficient (85-89%)';
      case DepEdProficiencyLevel.advanced:
        return 'Advanced (90-100%)';
    }
  }

  static DepEdProficiencyLevel fromString(String? raw) {
    final clean = (raw ?? '').trim().toLowerCase();
    if (clean.contains('begin')) return DepEdProficiencyLevel.beginning;
    if (clean.contains('approach')) {
      return DepEdProficiencyLevel.approachingProficiency;
    }
    if (clean.contains('advanced')) return DepEdProficiencyLevel.advanced;
    if (clean.contains('proficient')) return DepEdProficiencyLevel.proficient;
    return DepEdProficiencyLevel.developing;
  }
}

class IlawSessionData {
  final int sessionNumber;
  final String sessionTitle;
  final String objectives;
  final String learningExperiences;
  final String formativeAssessment;
  final String parentGuide;
  final String communityExperience;
  final String teacherReflections;

  const IlawSessionData({
    required this.sessionNumber,
    required this.sessionTitle,
    required this.objectives,
    required this.learningExperiences,
    required this.formativeAssessment,
    required this.parentGuide,
    required this.communityExperience,
    required this.teacherReflections,
  });

  IlawSessionData copyWith({
    int? sessionNumber,
    String? sessionTitle,
    String? objectives,
    String? learningExperiences,
    String? formativeAssessment,
    String? parentGuide,
    String? communityExperience,
    String? teacherReflections,
  }) {
    return IlawSessionData(
      sessionNumber: sessionNumber ?? this.sessionNumber,
      sessionTitle: sessionTitle ?? this.sessionTitle,
      objectives: objectives ?? this.objectives,
      learningExperiences: learningExperiences ?? this.learningExperiences,
      formativeAssessment: formativeAssessment ?? this.formativeAssessment,
      parentGuide: parentGuide ?? this.parentGuide,
      communityExperience: communityExperience ?? this.communityExperience,
      teacherReflections: teacherReflections ?? this.teacherReflections,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_number': sessionNumber,
      'session_title': sessionTitle,
      'objectives': objectives,
      'learning_experiences': learningExperiences,
      'formative_assessment': formativeAssessment,
      'parent_guide': parentGuide,
      'community_experience': communityExperience,
      'teacher_reflections': teacherReflections,
    };
  }

  factory IlawSessionData.fromJson(Map<String, dynamic> json) {
    return IlawSessionData(
      sessionNumber: (json['session_number'] is int)
          ? json['session_number'] as int
          : (int.tryParse(json['session_number']?.toString() ?? '') ?? 1),
      sessionTitle: (json['session_title'] ?? '').toString(),
      objectives: (json['objectives'] ?? '').toString(),
      learningExperiences: (json['learning_experiences'] ?? '').toString(),
      formativeAssessment: (json['formative_assessment'] ?? '').toString(),
      parentGuide: (json['parent_guide'] ?? '').toString(),
      communityExperience: (json['community_experience'] ?? '').toString(),
      teacherReflections: (json['teacher_reflections'] ?? '').toString(),
    );
  }
}

class IlawRubricItem {
  final String criterion;
  final bool isMet;
  final String notes;

  const IlawRubricItem({
    required this.criterion,
    required this.isMet,
    this.notes = '',
  });

  IlawRubricItem copyWith({String? criterion, bool? isMet, String? notes}) {
    return IlawRubricItem(
      criterion: criterion ?? this.criterion,
      isMet: isMet ?? this.isMet,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {'criterion': criterion, 'is_met': isMet, 'notes': notes};
  }

  factory IlawRubricItem.fromJson(Map<String, dynamic> json) {
    return IlawRubricItem(
      criterion: (json['criterion'] ?? '').toString(),
      isMet: json['is_met'] == true || json['is_met']?.toString() == 'true',
      notes: (json['notes'] ?? '').toString(),
    );
  }

  static List<IlawRubricItem> defaultRubrics() {
    return const [
      IlawRubricItem(
        criterion: 'Intentions & Objectives: Clearly aligned with DepEd SHS curriculum competencies and measurable.',
        isMet: true,
      ),
      IlawRubricItem(
        criterion: 'Inclusive Learning Experiences: Activities are active, scaffolded, and differentiated by learner proficiency level.',
        isMet: true,
      ),
      IlawRubricItem(
        criterion: 'Formative Assessment: Aligned with session objectives with actionable feedback for learning gaps.',
        isMet: true,
      ),
      IlawRubricItem(
        criterion: 'Ways Forward: Clear parent guidance prompts and relevant real-world community context connections.',
        isMet: true,
      ),
      IlawRubricItem(
        criterion: 'Teacher Reflection: Meaningful reflection questions included for ongoing instructional refinement.',
        isMet: true,
      ),
    ];
  }
}

class IlawGeneratedSections {
  final String intendedOutcomes;
  final String learningContent;
  final String assessment;
  final String workExperiences;
  final List<IlawSessionData> sessions;
  final List<IlawRubricItem> rubricItems;

  const IlawGeneratedSections({
    required this.intendedOutcomes,
    required this.learningContent,
    required this.assessment,
    required this.workExperiences,
    this.sessions = const [],
    this.rubricItems = const [],
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
  final IlawTemplateType templateType;
  final IlawContentSource contentSource;
  final DepEdProficiencyLevel targetProficiency;
  final int numberOfSessions;
  final String language;
  final String depedOrderCitation;
  final List<IlawSessionData> sessions;
  final List<IlawRubricItem> rubricItems;
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
    this.templateType = IlawTemplateType.ilawModified,
    this.contentSource = IlawContentSource.curriculumBased,
    this.targetProficiency = DepEdProficiencyLevel.developing,
    this.numberOfSessions = 4,
    this.language = 'English',
    this.depedOrderCitation = 'DepEd Order No. 003, s. 2026 (Guidelines on the Responsible Use of AI in Basic Education)',
    this.sessions = const [],
    this.rubricItems = const [],
    this.status = IlawPlanStatus.draft,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isApproved => status == IlawPlanStatus.approved;

  String get term => quarter;

  String get formattedDuration => '$durationMinutes mins';

  List<IlawSessionData> get effectiveSessions {
    if (sessions.isNotEmpty) return sessions;
    return [
      IlawSessionData(
        sessionNumber: 1,
        sessionTitle: 'Session 1: $topic',
        objectives: intendedOutcomes,
        learningExperiences: workExperiences,
        formativeAssessment: assessment,
        parentGuide:
            'Review key concepts of $topic with student through home discussions.',
        communityExperience:
            'Apply concepts of $topic to daily community and school environment.',
        teacherReflections:
            'Observe student participation and mastery during discussion.',
      ),
    ];
  }

  List<IlawRubricItem> get effectiveRubrics {
    if (rubricItems.isNotEmpty) return rubricItems;
    return IlawRubricItem.defaultRubrics();
  }

  IlawLessonPlan copyWith({
    String? id,
    String? teacherId,
    String? teacherName,
    String? gradeLevel,
    String? quarter,
    String? term,
    String? subject,
    String? topic,
    int? durationMinutes,
    String? teachingStrategy,
    String? learningCompetency,
    String? intendedOutcomes,
    String? learningContent,
    String? assessment,
    String? workExperiences,
    IlawTemplateType? templateType,
    IlawContentSource? contentSource,
    DepEdProficiencyLevel? targetProficiency,
    int? numberOfSessions,
    String? language,
    String? depedOrderCitation,
    List<IlawSessionData>? sessions,
    List<IlawRubricItem>? rubricItems,
    IlawPlanStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IlawLessonPlan(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      quarter: term ?? quarter ?? this.quarter,
      subject: subject ?? this.subject,
      topic: topic ?? this.topic,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      teachingStrategy: teachingStrategy ?? this.teachingStrategy,
      learningCompetency: learningCompetency ?? this.learningCompetency,
      intendedOutcomes: intendedOutcomes ?? this.intendedOutcomes,
      learningContent: learningContent ?? this.learningContent,
      assessment: assessment ?? this.assessment,
      workExperiences: workExperiences ?? this.workExperiences,
      templateType: templateType ?? this.templateType,
      contentSource: contentSource ?? this.contentSource,
      targetProficiency: targetProficiency ?? this.targetProficiency,
      numberOfSessions: numberOfSessions ?? this.numberOfSessions,
      language: language ?? this.language,
      depedOrderCitation: depedOrderCitation ?? this.depedOrderCitation,
      sessions: sessions ?? this.sessions,
      rubricItems: rubricItems ?? this.rubricItems,
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
      'term': quarter,
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
      'template_type': templateType.name,
      'content_source': contentSource.name,
      'target_proficiency': targetProficiency.name,
      'number_of_sessions': numberOfSessions,
      'language': language,
      'deped_order_citation': depedOrderCitation,
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'rubric_items': rubricItems.map((r) => r.toJson()).toList(),
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

    final rawSessions = json['sessions'];
    final List<IlawSessionData> parsedSessions = [];
    if (rawSessions is List) {
      for (final s in rawSessions) {
        if (s is Map<String, dynamic>) {
          parsedSessions.add(IlawSessionData.fromJson(s));
        } else if (s is Map) {
          parsedSessions.add(
            IlawSessionData.fromJson(Map<String, dynamic>.from(s)),
          );
        }
      }
    }

    final rawRubrics = json['rubric_items'];
    final List<IlawRubricItem> parsedRubrics = [];
    if (rawRubrics is List) {
      for (final r in rawRubrics) {
        if (r is Map<String, dynamic>) {
          parsedRubrics.add(IlawRubricItem.fromJson(r));
        } else if (r is Map) {
          parsedRubrics.add(
            IlawRubricItem.fromJson(Map<String, dynamic>.from(r)),
          );
        }
      }
    }

    return IlawLessonPlan(
      id: (json['id'] ?? '').toString(),
      teacherId: (json['teacher_id'] ?? '').toString(),
      teacherName: (json['teacher_name'] ?? '').toString(),
      gradeLevel: (json['grade_level'] ?? 'Grade 11').toString(),
      quarter: _normalizeTerm(
        (json['term'] ?? json['quarter'] ?? 'Term 1').toString(),
      ),
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
      templateType: IlawTemplateType.fromString(
        json['template_type']?.toString(),
      ),
      contentSource: IlawContentSource.fromString(
        json['content_source']?.toString(),
      ),
      targetProficiency: DepEdProficiencyLevel.fromString(
        json['target_proficiency']?.toString(),
      ),
      numberOfSessions: (json['number_of_sessions'] is int)
          ? json['number_of_sessions'] as int
          : (int.tryParse(json['number_of_sessions']?.toString() ?? '') ?? 4),
      language: (json['language'] ?? 'English').toString(),
      depedOrderCitation:
          (json['deped_order_citation'] ??
                  'DepEd Order No. 003, s. 2026 (Guidelines on the Responsible Use of AI in Basic Education)')
              .toString(),
      sessions: parsedSessions,
      rubricItems: parsedRubrics,
      status: parsedStatus,
      createdAt: created,
      updatedAt: updated,
    );
  }

  static String _normalizeTerm(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Term 1';
    if (trimmed == 'Quarter 1' || trimmed == 'Term 1') return 'Term 1';
    if (trimmed == 'Quarter 2' || trimmed == 'Term 2') return 'Term 2';
    if (trimmed == 'Quarter 3' ||
        trimmed == 'Quarter 4' ||
        trimmed == 'Term 3') {
      return 'Term 3';
    }
    return trimmed;
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
    int numberOfSessions = 4,
    DepEdProficiencyLevel proficiencyLevel = DepEdProficiencyLevel.developing,
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

    final sessionsCount = numberOfSessions.clamp(1, 5);
    final List<IlawSessionData> sessionsList = [];
    for (int i = 1; i <= sessionsCount; i++) {
      sessionsList.add(
        IlawSessionData(
          sessionNumber: i,
          sessionTitle: 'Session $i: $topic (Phase $i of $sessionsCount)',
          objectives:
              '1. Understand and apply $topic principles according to ${proficiencyLevel.label} standards.\n'
              '2. Solve contextualized Senior High School tasks with accuracy and critical reasoning.',
          learningExperiences:
              '• Warm-up ($introMins mins): Activate prior knowledge on related SHS prerequisites.\n'
              '• Teacher Modeling ($discussMins mins): Demonstrate core concept and worked problems using $strategyNote.\n'
              '• Guided & Collaborative Practice ($applyMins mins): Peer problem solving differentiated for ${proficiencyLevel.label}.\n'
              '• Synthesis ($wrapMins mins): Learner generalization and key takeaways.',
          formativeAssessment:
              'Quick exit ticket (5-10 mins) assessing session $i mastery on $topic.',
          parentGuide:
              'Inquire about what the student learned in $topic and review completed worksheet calculations.',
          communityExperience:
              'Observe real-world applications of $topic in local community transactions and workplaces.',
          teacherReflections:
              'Record student learning pace and note any competencies requiring review in Session ${i < sessionsCount ? i + 1 : i}.',
        ),
      );
    }

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
          '- Learner Proficiency Target: ${proficiencyLevel.label}\n'
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
      sessions: sessionsList,
      rubricItems: IlawRubricItem.defaultRubrics(),
    );
  }
}
