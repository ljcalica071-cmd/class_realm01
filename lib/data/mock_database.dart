import '../models/user_model.dart';
import '../models/academic_models.dart';

// Mock password store: userId -> password (plain text, prototype only)
final Map<String, String> _mockPasswords = {};

class MockDatabase {
  // Singleton instance
  static final MockDatabase instance = MockDatabase._init();
  MockDatabase._init() {
    _seedData();
  }

  // Current session & offline sync state
  UserModel? currentUser;
  SyncStatus syncStatus = SyncStatus.online;
  bool isOnline = true; // Simulated connectivity flag for Quiz/Exam flow

  // Collections
  List<UserModel> users = [];
  List<AttendanceRecord> attendanceRecords = [];
  List<ActivityModel> activities = [];
  List<StudentSubmission> activitySubmissions = [];
  List<QuizOrExamModel> quizzesAndExams = [];
  List<ExamSubmissionReview> examReviews = [];
  List<GradingCriteria> gradingCriteria = [];
  List<LessonPlanModel> lessonPlans = [];
  List<LearningMaterialModel> materials = [];
  List<ScheduleModel> schedules = [];
  List<AppNotificationModel> notifications = [];
  List<AssessmentResultModel> assessmentResults = [];
  Map<String, Map<String, double>> assessmentScores = {};

  // Teacher Academic Setup
  String academicYear = "2024-2025";
  String gradeLevel = "Grade 11";
  String currentSubject = "General Mathematics";
  List<String> sections = ["Section A", "Section B"];

  void _seedData() {
    _seedCanonicalData();
  }

  void _seedCanonicalData() {
    academicYear = '2026-2027';
    gradeLevel = 'Grade 11';
    currentSubject = 'General Mathematics';
    sections = ['Section A', 'Section B'];

    const studentRecords = [
      {
        'id': 'A01',
        'section': 'Section A',
        'first': 'Alyssa',
        'middle': 'M.',
        'last': 'Reyes',
        'gender': 'Female',
        'email': 'alyssareyes@gmail.com',
        'phone': '09171234501',
        'lrn': '100001230001',
        'birthday': '2009-03-14',
        'parent': 'Maricel Reyes',
        'relationship': 'Mother',
        'parentEmail': 'maricelreyes@gmail.com',
        'parentPhone': '09181234501',
      },
      {
        'id': 'A02',
        'section': 'Section A',
        'first': 'Joshua',
        'middle': 'L.',
        'last': 'Navarro',
        'gender': 'Male',
        'email': 'joshuanavarro@gmail.com',
        'phone': '09171234502',
        'lrn': '100001230002',
        'birthday': '2009-07-22',
        'parent': 'Ramon Navarro',
        'relationship': 'Father',
        'parentEmail': 'ramonnavarro@gmail.com',
        'parentPhone': '09181234502',
      },
      {
        'id': 'A03',
        'section': 'Section A',
        'first': 'Bianca',
        'middle': 'R.',
        'last': 'Dela Cruz',
        'gender': 'Female',
        'email': 'biancadelacruz@gmail.com',
        'phone': '09171234503',
        'lrn': '100001230003',
        'birthday': '2009-11-05',
        'parent': 'Lorna Dela Cruz',
        'relationship': 'Mother',
        'parentEmail': 'lornadelacruz@gmail.com',
        'parentPhone': '09181234503',
      },
      {
        'id': 'A04',
        'section': 'Section A',
        'first': 'Daniel',
        'middle': 'J.',
        'last': 'Mendoza',
        'gender': 'Male',
        'email': 'danielmendoza@gmail.com',
        'phone': '09171234504',
        'lrn': '100001230004',
        'birthday': '2009-01-28',
        'parent': 'Joel Mendoza',
        'relationship': 'Father',
        'parentEmail': 'joelmendoza@gmail.com',
        'parentPhone': '09181234504',
      },
      {
        'id': 'A05',
        'section': 'Section A',
        'first': 'Camille',
        'middle': 'S.',
        'last': 'Villanueva',
        'gender': 'Female',
        'email': 'camillevillanueva@gmail.com',
        'phone': '09171234505',
        'lrn': '100001230005',
        'birthday': '2009-09-09',
        'parent': 'Grace Villanueva',
        'relationship': 'Mother',
        'parentEmail': 'grace.villanueva@gmail.com',
        'parentPhone': '09181234505',
      },
      {
        'id': 'B01',
        'section': 'Section B',
        'first': 'Nathan',
        'middle': 'P.',
        'last': 'Garcia',
        'gender': 'Male',
        'email': 'nathangarcia@gmail.com',
        'phone': '09171234506',
        'lrn': '100001230006',
        'birthday': '2009-02-16',
        'parent': 'Teresa Garcia',
        'relationship': 'Mother',
        'parentEmail': 'teresagarcia@gmail.com',
        'parentPhone': '09181234506',
      },
      {
        'id': 'B02',
        'section': 'Section B',
        'first': 'Sofia',
        'middle': 'C.',
        'last': 'Bautista',
        'gender': 'Female',
        'email': 'sofiabautista@gmail.com',
        'phone': '09171234507',
        'lrn': '100001230007',
        'birthday': '2009-06-30',
        'parent': 'Eduardo Bautista',
        'relationship': 'Father',
        'parentEmail': 'eduardobautista@gmail.com',
        'parentPhone': '09181234507',
      },
      {
        'id': 'B03',
        'section': 'Section B',
        'first': 'Ethan',
        'middle': 'D.',
        'last': 'Aquino',
        'gender': 'Male',
        'email': 'ethanaquino@gmail.com',
        'phone': '09171234508',
        'lrn': '100001230008',
        'birthday': '2009-10-12',
        'parent': 'Monica Aquino',
        'relationship': 'Mother',
        'parentEmail': 'monicaaquino@gmail.com',
        'parentPhone': '09181234508',
      },
      {
        'id': 'B04',
        'section': 'Section B',
        'first': 'Jasmine',
        'middle': 'F.',
        'last': 'Santiago',
        'gender': 'Female',
        'email': 'jasminesantiago@gmail.com',
        'phone': '09171234509',
        'lrn': '100001230009',
        'birthday': '2009-12-03',
        'parent': 'Roberto Santiago',
        'relationship': 'Father',
        'parentEmail': 'robertosantiago@gmail.com',
        'parentPhone': '09181234509',
      },
      {
        'id': 'B05',
        'section': 'Section B',
        'first': 'Marco',
        'middle': 'T.',
        'last': 'Castillo',
        'gender': 'Male',
        'email': 'marcocastillo@gmail.com',
        'phone': '09171234510',
        'lrn': '100001230010',
        'birthday': '2009-04-25',
        'parent': 'Elena Castillo',
        'relationship': 'Mother',
        'parentEmail': 'elenacastillo@gmail.com',
        'parentPhone': '09181234510',
      },
    ];

    DateTime parseBirthday(String value) {
      final parts = value.split('-').map(int.parse).toList();
      return DateTime(parts[0], parts[1], parts[2]);
    }

    users = [
      const UserModel(
        id: 'usr_admin',
        username: 'admin',
        fullName: 'School Administrator',
        email: 'admin@classrealm.edu',
        role: UserRole.admin,
      ),
      const UserModel(
        id: 'T001',
        username: 'teacher',
        fullName: 'Karen P. Gonzaga',
        email: 'karen.gonzaga@classrealm.edu',
        role: UserRole.teacher,
        departmentOrSection: 'General Mathematics',
      ),
      ...studentRecords.map((record) {
        final fullName =
            '${record['first']} ${record['middle']} ${record['last']}';
        return UserModel(
          id: record['id']!,
          username: record['id'] == 'A01'
              ? 'student'
              : '${record['first']}${record['last']}'.toLowerCase().replaceAll(
                  ' ',
                  '',
                ),
          fullName: fullName,
          email: record['email']!,
          role: UserRole.student,
          studentId: record['id'],
          lrn: record['lrn'],
          departmentOrSection: record['section'],
          firstName: record['first'],
          middleName: record['middle'],
          lastName: record['last'],
          gender: record['gender'],
          birthday: parseBirthday(record['birthday']!),
          contactNumber: record['phone'],
          gradeLevel: '11',
          parentGuardianName: record['parent'],
          parentGuardianRelationship: record['relationship'],
          parentGuardianContact: record['parentPhone'],
        );
      }),
      ...studentRecords.map((record) {
        final parentId = 'P${record['id']}';
        return UserModel(
          id: parentId,
          username: record['id'] == 'A01' ? 'parent' : parentId.toLowerCase(),
          fullName: record['parent']!,
          email: record['parentEmail']!,
          role: UserRole.parent,
          linkedStudentId: record['id'],
          contactNumber: record['parentPhone'],
          parentGuardianRelationship: record['relationship'],
        );
      }),
    ];

    _mockPasswords
      ..clear()
      ..addAll({
        'usr_admin': 'admin123',
        'T001': 'teacher123',
        for (final record in studentRecords) record['id']!: 'student123',
        for (final record in studentRecords)
          'P${record['id']}': 'parent123',
      });

    final attendanceDates = [
      DateTime(2026, 9, 14),
      DateTime(2026, 9, 15),
      DateTime(2026, 9, 16),
      DateTime(2026, 9, 17),
      DateTime(2026, 9, 18),
    ];
    const attendanceStatuses = {
      'A01': ['Present', 'Present', 'Absent', 'Present', 'Late'],
      'A02': ['Present', 'Present', 'Present', 'Present', 'Present'],
      'A03': ['Present', 'Present', 'Present', 'Present', 'Present'],
      'A04': ['Present', 'Present', 'Present', 'Present', 'Present'],
      'A05': ['Present', 'Present', 'Present', 'Present', 'Present'],
      'B01': ['Present', 'Late', 'Present', 'Absent', 'Present'],
      'B02': ['Present', 'Present', 'Present', 'Present', 'Present'],
      'B03': ['Present', 'Present', 'Present', 'Present', 'Present'],
      'B04': ['Present', 'Present', 'Present', 'Present', 'Present'],
      'B05': ['Present', 'Present', 'Present', 'Present', 'Present'],
    };
    AttendanceStatus statusFor(String value) => switch (value) {
      'Late' => AttendanceStatus.late,
      'Absent' => AttendanceStatus.absent,
      'Excused' => AttendanceStatus.excused,
      _ => AttendanceStatus.present,
    };
    attendanceRecords = [
      for (final student in users.where(
        (user) => user.role == UserRole.student,
      ))
        for (var index = 0; index < attendanceDates.length; index++)
          AttendanceRecord(
            id: 'att_${student.id}_${index + 1}',
            studentId: student.id,
            studentName: student.fullName,
            section: student.departmentOrSection!,
            date: attendanceDates[index],
            timeIn: attendanceStatuses[student.id]![index] == 'Present'
                ? '07:30 AM'
                : '--:--',
            status: statusFor(attendanceStatuses[student.id]![index]),
            method: 'Manual',
          ),
    ];

    DateTime due(int day) => DateTime(2026, 9, day, 16, 0);
    activities = [
      ActivityModel(
        id: 'WW1',
        title: 'Functions Activity',
        description: '',
        subject: currentSubject,
        section: 'Section A, Section B',
        deadline: due(22),
        sectionDeadlines: {'Section A': due(22), 'Section B': due(22)},
        maxScore: 20,
        totalStudents: 10,
      ),
      ActivityModel(
        id: 'WW2',
        title: 'Function Operations',
        description: '',
        subject: currentSubject,
        section: 'Section A, Section B',
        deadline: due(24),
        sectionDeadlines: {'Section A': due(24), 'Section B': due(24)},
        maxScore: 20,
        totalStudents: 10,
      ),
      ActivityModel(
        id: 'WW3',
        title: 'Functions Quiz',
        description: '',
        subject: currentSubject,
        section: 'Section A, Section B',
        deadline: due(26),
        sectionDeadlines: {'Section A': due(26), 'Section B': due(26)},
        maxScore: 30,
        totalStudents: 10,
      ),
      ActivityModel(
        id: 'PT1',
        title: 'Functions Project',
        description: '',
        instructions: 'Complete the Functions Project.',
        subject: currentSubject,
        section: 'Section A, Section B',
        deadline: due(30),
        sectionDeadlines: {'Section A': due(30), 'Section B': due(30)},
        maxScore: 100,
        isRequirement: true,
        totalStudents: 10,
      ),
    ];

    const scores = {
      'A01': [18, 17, 26, 88, 42, 44, 86],
      'A02': [16, 18, 24, 82, 39, 41, 80],
      'A03': [19, 19, 28, 94, 46, 47, 91],
      'A04': [15, 16, 22, 78, 37, 40, 76],
      'A05': [17, 18, 25, 85, 41, 43, 84],
      'B01': [18, 16, 25, 86, 43, 42, 85],
      'B02': [20, 19, 29, 96, 48, 46, 94],
      'B03': [16, 17, 23, 80, 38, 40, 79],
      'B04': [19, 18, 27, 90, 45, 44, 89],
      'B05': [17, 19, 26, 87, 42, 45, 88],
    };
    assessmentScores = {
      for (final id in ['WW1', 'WW2', 'WW3', 'PT1', 'EX1', 'EX2', 'EX3'])
        id: {
          for (final student in scores.keys)
            student:
                scores[student]![[
                      'WW1',
                      'WW2',
                      'WW3',
                      'PT1',
                      'EX1',
                      'EX2',
                      'EX3',
                    ].indexOf(id)]
                    .toDouble(),
        },
    };

    final submissionScore = <String, Map<String, double>>{
      'WW1': assessmentScores['WW1']!,
      'WW2': assessmentScores['WW2']!,
      'WW3': assessmentScores['WW3']!,
      'PT1': assessmentScores['PT1']!,
    };
    activitySubmissions = [
      for (final activity in activities)
        for (final student in users.where(
          (user) =>
              user.role == UserRole.student && user.departmentOrSection != null,
        ))
          if (student.id.endsWith('04') || student.id.endsWith('05')) ...[
            StudentSubmission(
              id: 'sub_${activity.id}_${student.id}',
              activityOrExamId: activity.id,
              studentId: student.id,
              studentName: student.fullName,
              submittedAt: DateTime(2026, 9, 18, 15),
              attachedFile: '${student.id}_${activity.id}.pdf',
              score: submissionScore[activity.id]?[student.id],
              maxScore: activity.maxScore,
              status: ActivityStatus.graded,
            ),
          ] else if (student.id.endsWith('02') ||
              student.id.endsWith('03')) ...[
            StudentSubmission(
              id: 'sub_${activity.id}_${student.id}',
              activityOrExamId: activity.id,
              studentId: student.id,
              studentName: student.fullName,
              submittedAt: DateTime(2026, 9, 18, 15),
              attachedFile: '${student.id}_${activity.id}.pdf',
              maxScore: activity.maxScore,
              status: ActivityStatus.submitted,
            ),
          ],
    ];

    QuestionModel question(String id, double points) => QuestionModel(
      id: id,
      questionText: 'General Mathematics question',
      type: QuestionType.multipleChoice,
      choices: const ['A', 'B', 'C', 'D'],
      correctAnswer: 'A',
      points: points,
    );
    List<QuestionModel> questions(String prefix, int count, double points) =>
        List.generate(
          count,
          (index) => question('$prefix-Q${index + 1}', points),
        );
    final now = DateTime.now();
    quizzesAndExams = [
      QuizOrExamModel(
        id: 'EX1',
        title: 'ST1',
        description: 'Summative Test 1: Functions',
        subject: currentSubject,
        section: 'Section A, Section B',
        isExam: true,
        durationMinutes: 60,
        scheduleDate: now.subtract(const Duration(days: 10)),
        sectionDeadlines: {
          'Section A': now.subtract(const Duration(days: 10)),
          'Section B': now.subtract(const Duration(days: 10)),
        },
        questions: questions('EX1', 10, 5),
      ),
      QuizOrExamModel(
        id: 'EX2',
        title: 'ST2',
        description: 'Summative Test 2: Rational Functions',
        subject: currentSubject,
        section: 'Section A, Section B',
        isExam: true,
        durationMinutes: 60,
        scheduleDate: now.subtract(const Duration(days: 5)),
        sectionDeadlines: {
          'Section A': now.subtract(const Duration(days: 5)),
          'Section B': now.subtract(const Duration(days: 5)),
        },
        questions: questions('EX2', 10, 5),
      ),
      QuizOrExamModel(
        id: 'EX3',
        title: 'TE',
        description: 'Term Examination: General Mathematics',
        subject: currentSubject,
        section: 'Section A, Section B',
        isExam: true,
        durationMinutes: 90,
        scheduleDate: now.subtract(const Duration(days: 1)),
        sectionDeadlines: {
          'Section A': now.subtract(const Duration(days: 1)),
          'Section B': now.subtract(const Duration(days: 1)),
        },
        questions: questions('EX3', 10, 10),
      ),
    ];
    examReviews = [];
    assessmentResults = [];
    gradingCriteria = [
      GradingCriteria(id: 'WW', name: 'Written Works', percentage: 20),
      GradingCriteria(id: 'PT', name: 'Performance Task', percentage: 50),
      GradingCriteria(id: 'EX', name: 'Examinations', percentage: 30),
    ];
    lessonPlans = [
      LessonPlanModel(
        id: 'LP1',
        topic: 'Functions and Relations',
        gradeLevel: 'Grade 11',
        subject: currentSubject,
        duration: '60 mins',
        objectives: 'Understand domain and range.',
        materials: 'PDF: Module_1_Functions.pdf',
        procedure: 'Discussion and exercises.',
        assessment: 'Quiz 1',
        assignment: 'Problem Set 1',
        createdAt: DateTime(2026, 9, 15),
      ),
      LessonPlanModel(
        id: 'LP2',
        topic: 'Rational Functions',
        gradeLevel: 'Grade 11',
        subject: currentSubject,
        duration: '90 mins',
        objectives: 'Graph rational functions.',
        materials: 'DOCX: Rational_Functions_Guide.docx',
        procedure: 'Step-by-step graphing.',
        assessment: 'Quiz 2',
        assignment: 'Graphing Activity',
        createdAt: DateTime(2026, 9, 18),
      ),
    ];
    materials = [
      LearningMaterialModel(
        id: 'mat_1',
        title: 'Module 1: Functions and Their Graphs',
        category: 'PDF Document',
        topic: 'Functions Review',
        fileName: 'GenMath_Module_1_Functions.pdf',
        fileSize: '3.4 MB',
        uploadedAt: DateTime(2026, 9, 10),
        description: 'Complete syllabus and conceptual exercises for piecewise and inverse functions.',
        section: 'Section A',
      ),
      LearningMaterialModel(
        id: 'mat_2',
        title: 'Rational Functions Lecture Slide Deck',
        category: 'Presentation',
        topic: 'Rational Expressions',
        fileName: 'Lesson_2_Rational_Functions_Slides.pptx',
        fileSize: '8.1 MB',
        uploadedAt: DateTime(2026, 9, 15),
        description: 'Official slide deck used in class discussion with animated graphs.',
        section: 'Section B',
      ),
      LearningMaterialModel(
        id: 'mat_3',
        title: 'Interactive GeoGebra Asymptote Visualizer',
        category: 'Interactive Web Link',
        topic: 'Graphing Lab',
        fileName: 'https://geogebra.org/m/classrealm-asymptotes',
        fileSize: 'Cloud URL',
        uploadedAt: DateTime(2026, 9, 18),
        description:
            'Manipulate numerator and denominator coefficients in real time.',
        section: 'Section A',
      ),
      LearningMaterialModel(
        id: 'mat_lp_1',
        title: 'Lesson Plan: Rational Functions',
        category: 'DOCX Document',
        topic: 'Rational Functions',
        fileName: 'LP_Rational_Functions_Grade_11.docx',
        fileSize: '42 KB',
        uploadedAt: DateTime(2026, 9, 16),
        description: 'Daily lesson plan for Grade 11 General Mathematics on rational functions and asymptotes.',
        section: 'Section A',
      ),
      LearningMaterialModel(
        id: 'mat_lp_2',
        title: 'Lesson Plan: Exponential Growth',
        category: 'DOCX Document',
        topic: 'Exponential Growth',
        fileName: 'LP_Exponential_Growth_Grade_11.docx',
        fileSize: '38 KB',
        uploadedAt: DateTime(2026, 9, 14),
        description: 'Classroom-ready lesson plan covering exponential growth and compound interest models.',
        section: 'Section B',
      ),
      LearningMaterialModel(
        id: 'mat_lp_3',
        title: 'Lesson Plan: Functions Assessment',
        category: 'PDF Document',
        topic: 'Functions Review',
        fileName: 'LP_Functions_Review_Assessment.pdf',
        fileSize: '1.2 MB',
        uploadedAt: DateTime(2026, 9, 12),
        description: 'Printable PDF lesson plan and assessment guide for the Functions review lesson.',
        section: 'Section A',
      ),
    ];
    schedules = [
      ScheduleModel(
        id: 'sch_1',
        subject: 'General Mathematics',
        section: 'Section A',
        room: 'Room 304 - Science Wing',
        dayOfWeek: 'Monday',
        startTime: '07:30 AM',
        endTime: '09:00 AM',
      ),
      ScheduleModel(
        id: 'sch_2',
        subject: 'General Mathematics',
        section: 'Section A',
        room: 'Room 304 - Science Wing',
        dayOfWeek: 'Wednesday',
        startTime: '07:30 AM',
        endTime: '09:00 AM',
      ),
      ScheduleModel(
        id: 'sch_3',
        subject: 'General Mathematics',
        section: 'Section B',
        room: 'Room 305 - Science Wing',
        dayOfWeek: 'Tuesday',
        startTime: '07:30 AM',
        endTime: '09:00 AM',
      ),
      ScheduleModel(
        id: 'sch_4',
        subject: 'General Mathematics',
        section: 'Section B',
        room: 'Room 305 - Science Wing',
        dayOfWeek: 'Thursday',
        startTime: '07:30 AM',
        endTime: '09:00 AM',
      ),
    ];
    notifications = [
      AppNotificationModel(
        id: 'notif_sub_1',
        title: 'New Submission: Performance Task 1',
        message: 'Student Alyssa M. Reyes (A01) has submitted "Functions Project Portfolio".',
        timestamp: now.subtract(const Duration(hours: 2)),
        isRead: false,
        type: 'submission',
      ),
      AppNotificationModel(
        id: 'notif_sub_2',
        title: 'New Submission: Written Work 1',
        message: 'Student Nathan P. Garcia (B01) has submitted "Functions Activity Worksheet".',
        timestamp: now.subtract(const Duration(hours: 5)),
        isRead: false,
        type: 'submission',
      ),
      AppNotificationModel(
        id: 'notif_att_1',
        title: 'Alert: Low Attendance',
        message: 'Student Daniel J. Mendoza (A04) has dropped below 80% attendance this month.',
        timestamp: now.subtract(const Duration(days: 1)),
        isRead: false,
        type: 'attendance_alert',
      ),
      AppNotificationModel(
        id: 'notif_att_2',
        title: 'RFID Attendance Log',
        message: 'RFID Reader "Gate 1" synced 45 student logs at 07:45 AM.',
        timestamp: now.subtract(const Duration(hours: 10)),
        isRead: true,
        type: 'system',
      ),
    ];
  }

  double categoryAverageFor(String studentId, String category) {
    const ids = {
      'Written Works': ['WW1', 'WW2', 'WW3'],
      'Performance Task': ['PT1'],
      'Examinations': ['EX1', 'EX2', 'EX3'],
    };
    const maxPoints = {
      'WW1': 20.0,
      'WW2': 20.0,
      'WW3': 30.0,
      'PT1': 100.0,
      'EX1': 50.0,
      'EX2': 50.0,
      'EX3': 100.0,
    };
    final assessmentIds = ids[category] ?? const <String>[];
    if (assessmentIds.isEmpty) return 0;
    if (category == 'Examinations') {
      const componentWeights = {'EX1': 0.30, 'EX2': 0.30, 'EX3': 0.40};
      return assessmentIds.fold<double>(
            0,
            (total, id) =>
                total +
                ((assessmentScores[id]?[studentId] ?? 0) / maxPoints[id]!) *
                    (componentWeights[id] ?? 0),
          ) *
          100;
    }
    final scores = assessmentIds.map(
      (id) => (assessmentScores[id]?[studentId] ?? 0) / maxPoints[id]!,
    );
    return scores.reduce((sum, value) => sum + value) /
        assessmentIds.length *
        100;
  }

  double quarterlyGradeFor(String studentId) {
    return categoryAverageFor(studentId, 'Written Works') * 0.20 +
        categoryAverageFor(studentId, 'Performance Task') * 0.50 +
        categoryAverageFor(studentId, 'Examinations') * 0.30;
  }

  AssessmentResultModel? resultFor(String assessmentId, String studentId) {
    try {
      return assessmentResults.firstWhere(
        (r) => r.assessmentId == assessmentId && r.studentId == studentId,
      );
    } catch (_) {
      return null;
    }
  }

  StudentSubmission? submissionFor(String activityId, String studentId) {
    try {
      return activitySubmissions.firstWhere(
        (s) => s.activityOrExamId == activityId && s.studentId == studentId,
      );
    } catch (_) {
      return null;
    }
  }

  List<StudentSubmission> submissionsForStudent(String studentId) {
    return activitySubmissions.where((s) => s.studentId == studentId).toList();
  }

  List<ActivityModel> get requirements =>
      activities.where((a) => a.isRequirement).toList();
  List<ActivityModel> get activitiesOnly =>
      activities.where((a) => !a.isRequirement).toList();

  List<AttendanceRecord> attendanceForStudent(String studentId) {
    return attendanceRecords.where((r) => r.studentId == studentId).toList();
  }

  List<ScheduleModel> scheduleForSection(String section) {
    return schedules.where((s) => s.section == section).toList();
  }

  List<LearningMaterialModel> materialsForSection(String section) {
    return materials.where((m) => m.section == section).toList();
  }

  // --- Helper CRUD Actions ---

  // Auth Simulation
  UserModel? authenticate(String username, String password) {
    // Find user by username (case-sensitive for generated usernames)
    final idx = users.indexWhere((u) => u.username == username);
    if (idx == -1) return null;
    final user = users[idx];
    final storedPassword = _mockPasswords[user.id];
    if (storedPassword == null || storedPassword != password) return null;
    currentUser = user;
    return currentUser;
  }

  void logout() {
    currentUser = null;
  }

  String? createParentAccount({
    required String fullName,
    required String email,
    required String contactNumber,
    required String relationship,
    required String linkedStudentId,
  }) {
    if (users.any(
      (user) =>
          user.role == UserRole.parent &&
          (user.email.toLowerCase() == email.toLowerCase() ||
              user.linkedStudentId == linkedStudentId),
    )) {
      return 'A parent account is already linked to this student or email.';
    }

    final id = 'P${DateTime.now().millisecondsSinceEpoch}';
    users.add(
      UserModel(
        id: id,
        username: id.toLowerCase(),
        fullName: fullName,
        email: email,
        role: UserRole.parent,
        linkedStudentId: linkedStudentId,
        contactNumber: contactNumber,
        parentGuardianRelationship: relationship,
      ),
    );
    _mockPasswords[id] = 'parent123';
    return null;
  }

  void updateParentAccount({
    required String id,
    required String fullName,
    required String email,
    required String contactNumber,
    required String relationship,
    required String linkedStudentId,
  }) {
    final idx = users.indexWhere((user) => user.id == id);
    if (idx == -1) return;
    users[idx] = users[idx].copyWith(
      fullName: fullName,
      email: email,
      contactNumber: contactNumber,
      parentGuardianRelationship: relationship,
      linkedStudentId: linkedStudentId,
    );
  }

  // Teacher Approval / Rejection
  void updateTeacherStatus(String teacherId, AccountStatus newStatus) {
    final idx = users.indexWhere((u) => u.id == teacherId);
    if (idx != -1) {
      users[idx] = users[idx].copyWith(status: newStatus);
    }
  }

  // Attendance Check
  void toggleAttendance(String studentId, AttendanceStatus newStatus) {
    final idx = attendanceRecords.indexWhere((r) => r.studentId == studentId);
    if (idx != -1) {
      attendanceRecords[idx] = attendanceRecords[idx].copyWith(
        status: newStatus,
        isSynced: syncStatus == SyncStatus.online,
      );
    } else {
      final student = users.firstWhere(
        (u) => u.studentId == studentId,
        orElse: () => users.first,
      );
      attendanceRecords.add(
        AttendanceRecord(
          id: 'att_${DateTime.now().millisecondsSinceEpoch}',
          studentId: studentId,
          studentName: student.fullName,
          section: student.departmentOrSection ?? 'Section A',
          date: DateTime.now(),
          timeIn: '08:00 AM',
          status: newStatus,
          method: 'Manual Entry',
          isSynced: syncStatus == SyncStatus.online,
        ),
      );
    }
  }

  // Student Archive / Soft Delete Management
  void archiveStudent(String id) {
    final idx = users.indexWhere((u) => u.id == id);
    if (idx != -1) {
      users[idx] = users[idx].copyWith(
        isArchived: true,
        status: AccountStatus.archived,
      );
    }
  }

  void restoreStudent(String id) {
    final idx = users.indexWhere((u) => u.id == id);
    if (idx != -1) {
      users[idx] = users[idx].copyWith(
        isArchived: false,
        status: AccountStatus.active,
      );
    }
  }

  void permanentlyDeleteStudent(String id) {
    users.removeWhere((u) => u.id == id);
    _mockPasswords.remove(id);
  }

  void updateStudent(
    String id,
    String fullName,
    String studentId,
    String section,
  ) {
    final idx = users.indexWhere((u) => u.id == id);
    if (idx != -1) {
      users[idx] = users[idx].copyWith(
        fullName: fullName,
        studentId: studentId,
        departmentOrSection: section,
      );
    }
  }

  // --- Student Account Management ---

  /// Generate username: firstName + lastName (preserving spacing/capitalization)
  static String generateUsername(String firstName, String lastName) {
    return '${firstName.trim()} ${lastName.trim()}';
  }

  /// Generate temp password: lowercase(lastName no spaces) + MMDDYYYY
  static String generateTempPassword(String lastName, DateTime birthday) {
    final ln = lastName.toLowerCase().replaceAll(' ', '');
    final mm = birthday.month.toString().padLeft(2, '0');
    final dd = birthday.day.toString().padLeft(2, '0');
    final yyyy = birthday.year.toString();
    return '$ln$mm$dd$yyyy';
  }

  /// Create a new student account (teacher-initiated)
  /// Returns null on success, or an error message string on duplicate.
  String? createStudentAccount({
    required String firstName,
    required String middleName,
    required String lastName,
    required DateTime birthday,
    required String email,
    required String studentId,
    required String gender,
    required String contactNumber,
  }) {
    if (!RegExp(r'^\d{12}$').hasMatch(studentId)) {
      return 'LRN must contain exactly 12 digits.';
    }
    final username = generateUsername(firstName, lastName);
    final tempPassword = generateTempPassword(lastName, birthday);
    final fullName = [
      firstName.trim(),
      if (middleName.trim().isNotEmpty) middleName.trim(),
      lastName.trim(),
    ].join(' ');

    // Duplicate checks
    if (users.any((u) => u.role == UserRole.student && u.lrn == studentId)) {
      return 'A student with LRN "$studentId" already exists.';
    }
    if (users.any(
      (u) => u.role == UserRole.student && u.username == username,
    )) {
      return 'A student with username "$username" already exists.';
    }
    if (users.any(
      (u) =>
          u.role == UserRole.student &&
          u.email.toLowerCase() == email.toLowerCase(),
    )) {
      return 'A student with email "$email" already exists.';
    }

    final id = 'usr_s_${DateTime.now().millisecondsSinceEpoch}';
    final newStudent = UserModel(
      id: id,
      username: username,
      fullName: fullName,
      email: email,
      role: UserRole.student,
      status: AccountStatus.pendingFirstLogin,
      studentId: studentId,
      lrn: studentId,
      departmentOrSection: 'Section A',
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      birthday: birthday,
      gender: gender,
      contactNumber: contactNumber,
      gradeLevel: '11',
      password: tempPassword,
    );
    users.add(newStudent);
    _mockPasswords[id] = tempPassword;
    return null; // success
  }

  /// Complete first login: validate temp password, set new password, activate account
  /// Returns null on success, or an error message.
  String? completeFirstLogin(
    String userId,
    String enteredTempPassword,
    String newPassword,
  ) {
    final idx = users.indexWhere((u) => u.id == userId);
    if (idx == -1) return 'Account not found.';
    final storedTemp = _mockPasswords[userId];
    if (storedTemp == null || storedTemp != enteredTempPassword) {
      return 'Incorrect temporary password.';
    }
    if (newPassword == enteredTempPassword) {
      return 'New password must be different from the temporary password.';
    }
    users[idx] = users[idx].copyWith(
      status: AccountStatus.active,
      password: newPassword,
    );
    _mockPasswords[userId] = newPassword;
    currentUser = users[idx];
    return null; // success
  }

  void deactivateStudent(String id) {
    final idx = users.indexWhere((u) => u.id == id);
    if (idx != -1) {
      users[idx] = users[idx].copyWith(status: AccountStatus.deactivated);
    }
  }

  void reactivateStudent(String id) {
    final idx = users.indexWhere((u) => u.id == id);
    if (idx != -1) {
      users[idx] = users[idx].copyWith(status: AccountStatus.active);
    }
  }

  void updateStudentFull({
    required String id,
    required String firstName,
    required String middleName,
    required String lastName,
    required String email,
    required String studentId,
    required String gender,
    required String contactNumber,
    required DateTime birthday,
  }) {
    final idx = users.indexWhere((u) => u.id == id);
    if (idx == -1) return;
    final fullName = [
      firstName.trim(),
      if (middleName.trim().isNotEmpty) middleName.trim(),
      lastName.trim(),
    ].join(' ');
    if (!RegExp(r'^\d{12}$').hasMatch(studentId)) return;
    users[idx] = users[idx].copyWith(
      fullName: fullName,
      email: email,
      studentId: studentId,
      lrn: studentId,
      departmentOrSection: users[idx].departmentOrSection ?? 'Section A',
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      birthday: birthday,
      gender: gender,
      contactNumber: contactNumber,
      gradeLevel: users[idx].gradeLevel ?? '11',
    );
  }

  // Activity Submission & Creation
  void addActivity(ActivityModel activity) {
    activities.insert(0, activity);
  }

  void deleteActivity(String id) {
    activities.removeWhere((a) => a.id == id);
  }

  void submitActivity(
    String activityId,
    String studentId,
    String studentName,
    String fileName,
  ) {
    activitySubmissions.removeWhere(
      (s) => s.activityOrExamId == activityId && s.studentId == studentId,
    );
    activitySubmissions.add(
      StudentSubmission(
        id: 'sub_${DateTime.now().millisecondsSinceEpoch}',
        activityOrExamId: activityId,
        studentId: studentId,
        studentName: studentName,
        submittedAt: DateTime.now(),
        attachedFile: fileName,
        maxScore: 50.0,
        status: ActivityStatus.submitted,
      ),
    );
  }

  void scoreSubmission(String submissionId, double score, String feedback) {
    final idx = activitySubmissions.indexWhere((s) => s.id == submissionId);
    if (idx != -1) {
      activitySubmissions[idx] = activitySubmissions[idx].copyWith(
        score: score,
        feedback: feedback,
        status: ActivityStatus.graded,
      );
    }
  }

  // Quiz / Exam actions
  void addQuizOrExam(QuizOrExamModel item) {
    quizzesAndExams.insert(0, item);
  }

  void deleteQuizOrExam(String id) {
    quizzesAndExams.removeWhere((q) => q.id == id);
  }

  // AI Lesson Plan Simulation Generator
  LessonPlanModel generateLessonPlan({
    required String topic,
    required String gradeLevel,
    required String subject,
    required String duration,
  }) {
    final newPlan = LessonPlanModel(
      id: 'lp_${DateTime.now().millisecondsSinceEpoch}',
      topic: topic,
      gradeLevel: gradeLevel,
      subject: subject,
      duration: duration,
      objectives:
          '1. Master the fundamental theorems of $topic.\n2. Solve practical mathematical equations in real contexts.\n3. Formulate step-by-step verification methods.',
      materials:
          'Teacher slide presentation, Scientific Calculator, Graphing Board, Worksheet $topic-01.',
      procedure:
          '1. Warm-up Discovery (10m): Introduce real scenario.\n2. Core Modeling (25m): Step-by-step algebraic breakdown of $topic.\n3. Collaborative Problem Solving (15m): Work in pairs on sample problems.\n4. Synthesis & Assessment (10m): Quick diagnostic assessment.',
      assessment:
          '5-item multiple choice and 1 problem solving item focusing on $topic.',
      assignment: 'Complete exercises 1 to 8 on module workbook page 62.',
      createdAt: DateTime.now(),
    );
    lessonPlans.insert(0, newPlan);
    return newPlan;
  }

  // Sync state simulation toggle
  void toggleOfflineSync() {
    if (syncStatus == SyncStatus.online) {
      syncStatus = SyncStatus.offline;
    } else if (syncStatus == SyncStatus.offline) {
      syncStatus = SyncStatus.pendingSync;
    } else if (syncStatus == SyncStatus.pendingSync) {
      syncStatus = SyncStatus.syncing;
    } else {
      syncStatus = SyncStatus.online;
    }
  }
}
