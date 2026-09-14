  import '../models/user_model.dart';
import '../models/academic_models.dart';

class MockDatabase {
  // Singleton instance
  static final MockDatabase instance = MockDatabase._init();
  MockDatabase._init() {
    _seedData();
  }

  // Current session & offline sync state
  UserModel? currentUser;
  SyncStatus syncStatus = SyncStatus.online;

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

  // Teacher Academic Setup
  String academicYear = "2024-2025";
  String gradeLevel = "Grade 11";
  String currentSubject = "General Mathematics";
  List<String> sections = ["STEM 11-A", "STEM 11-B", "ABM 11-A", "HUMSS 11-A"];

  void _seedData() {
    // 1. Users
    users = [
      const UserModel(
        id: 'usr_admin',
        username: 'admin',
        fullName: 'Dr. Arthur Pendelton',
        email: 'admin@classrealm.edu',
        role: UserRole.admin,
        status: AccountStatus.active,
        departmentOrSection: 'School Administration',
      ),
      const UserModel(
        id: 'usr_teacher_1',
        username: 'teacher',
        fullName: 'Prof. Maria Santos',
        email: 'msantos@classrealm.edu',
        role: UserRole.teacher,
        status: AccountStatus.active,
        departmentOrSection: 'Mathematics Department',
      ),
      const UserModel(
        id: 'usr_teacher_2',
        username: 'teacher_pending',
        fullName: 'Mr. Roberto Gomez',
        email: 'rgomez@classrealm.edu',
        role: UserRole.teacher,
        status: AccountStatus.pending,
        departmentOrSection: 'Science & Physics',
      ),
      const UserModel(
        id: 'usr_teacher_3',
        username: 'teacher_pending2',
        fullName: 'Ms. Clara Reyes',
        email: 'creyes@classrealm.edu',
        role: UserRole.teacher,
        status: AccountStatus.pending,
        departmentOrSection: 'English Literature',
      ),
      const UserModel(
        id: 'usr_student_1',
        username: 'student',
        fullName: 'Juan Dela Cruz',
        email: 'juan.delacruz@student.classrealm.edu',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '2024-SHS-0101',
        departmentOrSection: 'STEM 11-A',
        linkedStudentId: 'usr_parent_1',
      ),
      const UserModel(
        id: 'usr_student_2',
        username: 'student2',
        fullName: 'Angelo Reyes',
        email: 'angelo.reyes@student.classrealm.edu',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '2024-SHS-0102',
        departmentOrSection: 'STEM 11-A',
      ),
      const UserModel(
        id: 'usr_student_3',
        username: 'student3',
        fullName: 'Bea Alonzo',
        email: 'bea.alonzo@student.classrealm.edu',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '2024-SHS-0103',
        departmentOrSection: 'STEM 11-A',
      ),
      const UserModel(
        id: 'usr_student_4',
        username: 'student4',
        fullName: 'Carlos Yulo',
        email: 'carlos.yulo@student.classrealm.edu',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '2024-SHS-0104',
        departmentOrSection: 'STEM 11-A',
      ),
      const UserModel(
        id: 'usr_student_5',
        username: 'student5',
        fullName: 'Diana Prince',
        email: 'diana.prince@student.classrealm.edu',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '2024-SHS-0105',
        departmentOrSection: 'STEM 11-A',
      ),
      const UserModel(
        id: 'usr_parent_1',
        username: 'parent',
        fullName: 'Mrs. Josefina Dela Cruz',
        email: 'josefina.delacruz@gmail.com',
        role: UserRole.parent,
        status: AccountStatus.active,
        linkedStudentId: 'usr_student_1',
        contactNumber: '+63 917 123 4567',
      ),
    ];

    // 2. Attendance Records (Simulated RFID & Manual)
    final now = DateTime.now();
    attendanceRecords = [
      AttendanceRecord(
        id: 'att_1',
        studentId: '2024-SHS-0101',
        studentName: 'Juan Dela Cruz',
        section: 'STEM 11-A',
        date: now,
        timeIn: '07:28 AM',
        status: AttendanceStatus.present,
        method: 'RFID (ESP32 Tap)',
      ),
      AttendanceRecord(
        id: 'att_2',
        studentId: '2024-SHS-0102',
        studentName: 'Angelo Reyes',
        section: 'STEM 11-A',
        date: now,
        timeIn: '07:46 AM',
        status: AttendanceStatus.late,
        method: 'RFID (ESP32 Tap)',
      ),
      AttendanceRecord(
        id: 'att_3',
        studentId: '2024-SHS-0103',
        studentName: 'Bea Alonzo',
        section: 'STEM 11-A',
        date: now,
        timeIn: '07:15 AM',
        status: AttendanceStatus.present,
        method: 'RFID (ESP32 Tap)',
      ),
      AttendanceRecord(
        id: 'att_4',
        studentId: '2024-SHS-0104',
        studentName: 'Carlos Yulo',
        section: 'STEM 11-A',
        date: now,
        timeIn: '--:--',
        status: AttendanceStatus.absent,
        method: 'Manual Check',
      ),
      AttendanceRecord(
        id: 'att_5',
        studentId: '2024-SHS-0105',
        studentName: 'Diana Prince',
        section: 'STEM 11-A',
        date: now,
        timeIn: '08:00 AM',
        status: AttendanceStatus.excused,
        method: 'Medical Slip',
      ),
    ];

    // 3. Activities
    activities = [
      ActivityModel(
        id: 'act_1',
        title: 'Rational Functions Problem Set 1',
        description: 'Solve problems 1 through 10 on page 45. Graph the asymptotes and write the domain/range.',
        subject: 'General Mathematics',
        section: 'STEM 11-A',
        deadline: now.add(const Duration(days: 2)),
        maxScore: 50.0,
        isPublished: true,
        attachmentName: 'Rational_Functions_Worksheet_Q1.pdf',
        submissionsCount: 28,
        totalStudents: 35,
      ),
      ActivityModel(
        id: 'act_2',
        title: 'Real-World Exponential Growth Modeling',
        description: 'Construct a mathematical model representing population or viral spread over time.',
        subject: 'General Mathematics',
        section: 'STEM 11-A',
        deadline: now.add(const Duration(days: 5)),
        maxScore: 100.0,
        isPublished: true,
        attachmentName: 'Exponential_Growth_Rubrics.docx',
        submissionsCount: 14,
        totalStudents: 35,
      ),
      ActivityModel(
        id: 'act_3',
        title: 'Logarithmic Equations Synthesis',
        description: 'Derive key properties of logarithms and complete the proof exercises in Section 3.',
        subject: 'General Mathematics',
        section: 'STEM 11-A',
        deadline: now.subtract(const Duration(days: 2)),
        maxScore: 40.0,
        isPublished: true,
        submissionsCount: 35,
        totalStudents: 35,
      ),
    ];

    // 4. Submissions
    activitySubmissions = [
      StudentSubmission(
        id: 'sub_1',
        activityOrExamId: 'act_1',
        studentId: 'usr_student_1',
        studentName: 'Juan Dela Cruz',
        submittedAt: now.subtract(const Duration(hours: 4)),
        attachedFile: 'JuanDelaCruz_RationalFunctions_Act1.pdf',
        score: 48.0,
        maxScore: 50.0,
        status: ActivityStatus.graded,
        feedback: 'Excellent breakdown of vertical and horizontal asymptotes!',
      ),
    ];

    // 5. Quizzes and Exams
    quizzesAndExams = [
      QuizOrExamModel(
        id: 'quiz_1',
        title: 'Quiz 1: Functions & Domain/Range',
        description: 'Covers piecewise functions, rational expressions, and composite function evaluation.',
        subject: 'General Mathematics',
        section: 'STEM 11-A',
        isExam: false,
        durationMinutes: 30,
        scheduleDate: now.add(const Duration(days: 1)),
        isPublished: true,
        resultsReleased: true,
        questions: [
          QuestionModel(
            id: 'q1',
            questionText: 'What is the domain of f(x) = 1 / (x - 3)?',
            type: QuestionType.multipleChoice,
            choices: ['All real numbers except x = 3', 'All real numbers except x = -3', 'x > 3', 'x >= 0'],
            correctAnswer: 'All real numbers except x = 3',
            points: 5.0,
          ),
          QuestionModel(
            id: 'q2',
            questionText: 'The graph of a rational function can have more than one vertical asymptote.',
            type: QuestionType.trueFalse,
            choices: ['True', 'False'],
            correctAnswer: 'True',
            points: 5.0,
          ),
          QuestionModel(
            id: 'q3',
            questionText: 'The point where a graph crosses the y-axis is called the ________.',
            type: QuestionType.identification,
            correctAnswer: 'y-intercept',
            points: 5.0,
          ),
          QuestionModel(
            id: 'q4',
            questionText: 'Evaluate (f o g)(2) when f(x) = 2x + 1 and g(x) = x^2.',
            type: QuestionType.multipleChoice,
            choices: ['9', '8', '11', '5'],
            correctAnswer: '9',
            points: 5.0,
          ),
        ],
      ),
      QuizOrExamModel(
        id: 'exam_1',
        title: 'First Quarter Midterm Examination',
        description: 'Comprehensive Midterm Examination for Grade 11 General Mathematics.',
        subject: 'General Mathematics',
        section: 'STEM 11-A',
        isExam: true,
        durationMinutes: 60,
        scheduleDate: now.add(const Duration(days: 7)),
        isPublished: true,
        resultsReleased: false,
        questions: [
          QuestionModel(
            id: 'eq1',
            questionText: 'Which function represents exponential decay?',
            type: QuestionType.multipleChoice,
            choices: ['f(x) = 2(0.5)^x', 'f(x) = 3(2)^x', 'f(x) = x^2 - 4', 'f(x) = log(x)'],
            correctAnswer: 'f(x) = 2(0.5)^x',
            points: 10.0,
          ),
          QuestionModel(
            id: 'eq2',
            questionText: 'Logarithmic functions are the inverse of exponential functions.',
            type: QuestionType.trueFalse,
            choices: ['True', 'False'],
            correctAnswer: 'True',
            points: 10.0,
          ),
          QuestionModel(
            id: 'eq3',
            questionText: 'Find the vertical asymptote of f(x) = (2x + 1)/(x - 5).',
            type: QuestionType.identification,
            correctAnswer: 'x = 5',
            points: 10.0,
          ),
        ],
      ),
    ];

    // 6. Exam Auto-Checker & Reviews
    examReviews = [
      ExamSubmissionReview(
        id: 'rev_1',
        examId: 'quiz_1',
        studentId: '2024-SHS-0101',
        studentName: 'Juan Dela Cruz',
        submittedAt: now.subtract(const Duration(days: 1)),
        calculatedScore: 20.0,
        manualAdjustedScore: 20.0,
        isChecked: true,
        isFinalized: true,
        answers: [
          ExamStudentAnswer(
            questionId: 'q1',
            studentAnswer: 'All real numbers except x = 3',
            isCorrect: true,
            scoreEarned: 5.0,
          ),
          ExamStudentAnswer(
            questionId: 'q2',
            studentAnswer: 'True',
            isCorrect: true,
            scoreEarned: 5.0,
          ),
          ExamStudentAnswer(
            questionId: 'q3',
            studentAnswer: 'y-intercept',
            isCorrect: true,
            scoreEarned: 5.0,
          ),
          ExamStudentAnswer(
            questionId: 'q4',
            studentAnswer: '9',
            isCorrect: true,
            scoreEarned: 5.0,
          ),
        ],
      ),
      ExamSubmissionReview(
        id: 'rev_2',
        examId: 'quiz_1',
        studentId: '2024-SHS-0102',
        studentName: 'Angelo Reyes',
        submittedAt: now.subtract(const Duration(days: 1)),
        calculatedScore: 15.0,
        manualAdjustedScore: 15.0,
        isChecked: true,
        isFinalized: true,
        answers: [
          ExamStudentAnswer(
            questionId: 'q1',
            studentAnswer: 'All real numbers except x = 3',
            isCorrect: true,
            scoreEarned: 5.0,
          ),
          ExamStudentAnswer(
            questionId: 'q2',
            studentAnswer: 'False',
            isCorrect: false,
            scoreEarned: 0.0,
          ),
          ExamStudentAnswer(
            questionId: 'q3',
            studentAnswer: 'y-intercept',
            isCorrect: true,
            scoreEarned: 5.0,
          ),
          ExamStudentAnswer(
            questionId: 'q4',
            studentAnswer: '9',
            isCorrect: true,
            scoreEarned: 5.0,
          ),
        ],
      ),
      ExamSubmissionReview(
        id: 'rev_3',
        examId: 'quiz_1',
        studentId: '2024-SHS-0104',
        studentName: 'Carlos Yulo',
        submittedAt: now.subtract(const Duration(days: 1)),
        calculatedScore: 10.0,
        manualAdjustedScore: 10.0,
        isChecked: true,
        isFinalized: true,
        answers: [
          ExamStudentAnswer(
            questionId: 'q1',
            studentAnswer: 'x > 3',
            isCorrect: false,
            scoreEarned: 0.0,
          ),
          ExamStudentAnswer(
            questionId: 'q2',
            studentAnswer: 'True',
            isCorrect: true,
            scoreEarned: 5.0,
          ),
          ExamStudentAnswer(
            questionId: 'q3',
            studentAnswer: 'slope',
            isCorrect: false,
            scoreEarned: 0.0,
          ),
          ExamStudentAnswer(
            questionId: 'q4',
            studentAnswer: '9',
            isCorrect: true,
            scoreEarned: 5.0,
          ),
        ],
      ),
    ];

    // 7. Teacher-Configured Grading Criteria
    gradingCriteria = [
      GradingCriteria(id: 'gc_1', name: 'Quarterly Examinations', percentage: 30.0),
      GradingCriteria(id: 'gc_2', name: 'Written Activities & Worksheets', percentage: 25.0),
      GradingCriteria(id: 'gc_3', name: 'Quizzes & Unit Tests', percentage: 20.0),
      GradingCriteria(id: 'gc_4', name: 'Performance Tasks & Projects', percentage: 15.0),
      GradingCriteria(id: 'gc_5', name: 'Attendance & Class Participation', percentage: 10.0),
    ];

    // 8. AI Lesson Plans (Simulated)
    lessonPlans = [
      LessonPlanModel(
        id: 'lp_1',
        topic: 'Introduction to Rational Functions and Asymptotes',
        gradeLevel: 'Grade 11',
        subject: 'General Mathematics',
        duration: '60 minutes',
        objectives: '1. Distinguish between rational functions, rational equations, and rational inequalities.\n2. Determine domain, range, and vertical/horizontal asymptotes.\n3. Solve real-world mixture and rate problems.',
        materials: 'Interactive graphing app (GeoGebra), graphing paper, scientific calculator, projector.',
        procedure: 'A. Motivation (10m): Speed vs Time trip analysis.\nB. Direct Instruction (25m): Asymptote rules and behavior near discontinuities.\nC. Guided Practice (15m): Step-by-step table computation.\nD. Wrap-Up & Synthesis (10m): Exit ticket problem.',
        assessment: '10-point formative assessment on identifying undefined values.',
        assignment: 'Answer Problem Set 1 exercises 1-5.',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      LessonPlanModel(
        id: 'lp_2',
        topic: 'Exponential Growth and Compound Interest Models',
        gradeLevel: 'Grade 11',
        subject: 'General Mathematics',
        duration: '90 minutes',
        objectives: '1. Formulate exponential growth equations.\n2. Calculate compound interest continuously and annually.',
        materials: 'Financial worksheets, financial calculator app.',
        procedure: 'A. Scenario Analysis: Investing 1,000 PHP at 6% annual rate.\nB. Formula derivation for A = P(1 + r/n)^nt.\nC. Group collaboration on savings simulations.',
        assessment: '5-item quiz on compound interest.',
        assignment: 'Research Philippine bank interest rates.',
        createdAt: now.subtract(const Duration(days: 7)),
      ),
    ];

    // 9. Learning Materials
    materials = [
      LearningMaterialModel(
        id: 'mat_1',
        title: 'Module 1: Functions and Their Graphs',
        category: 'PDF Document',
        topic: 'Functions Review',
        fileName: 'GenMath_Module_1_Functions.pdf',
        fileSize: '3.4 MB',
        uploadedAt: now.subtract(const Duration(days: 10)),
        description: 'Complete syllabus and conceptual exercises for piecewise and inverse functions.',
      ),
      LearningMaterialModel(
        id: 'mat_2',
        title: 'Rational Functions Lecture Slide Deck',
        category: 'Presentation',
        topic: 'Rational Expressions',
        fileName: 'Lesson_2_Rational_Functions_Slides.pptx',
        fileSize: '8.1 MB',
        uploadedAt: now.subtract(const Duration(days: 5)),
        description: 'Official slide deck used in class discussion with animated graphs.',
      ),
      LearningMaterialModel(
        id: 'mat_3',
        title: 'Interactive GeoGebra Asymptote Visualizer',
        category: 'Interactive Web Link',
        topic: 'Graphing Lab',
        fileName: 'https://geogebra.org/m/classrealm-asymptotes',
        fileSize: 'Cloud URL',
        uploadedAt: now.subtract(const Duration(days: 2)),
        description: 'Manipulate numerator and denominator coefficients in real time.',
      ),
    ];

    // 10. Schedules
    schedules = [
      ScheduleModel(
        id: 'sch_1',
        subject: 'General Mathematics',
        section: 'STEM 11-A',
        room: 'Room 304 - Science Wing',
        dayOfWeek: 'Monday & Wednesday',
        startTime: '07:30 AM',
        endTime: '09:00 AM',
      ),
      ScheduleModel(
        id: 'sch_2',
        subject: 'General Mathematics',
        section: 'STEM 11-B',
        room: 'Room 305 - Science Wing',
        dayOfWeek: 'Monday & Wednesday',
        startTime: '09:15 AM',
        endTime: '10:45 AM',
      ),
      ScheduleModel(
        id: 'sch_3',
        subject: 'General Mathematics',
        section: 'ABM 11-A',
        room: 'Room 201 - Business Hall',
        dayOfWeek: 'Tuesday & Thursday',
        startTime: '08:00 AM',
        endTime: '09:30 AM',
      ),
      ScheduleModel(
        id: 'sch_4',
        subject: 'General Mathematics',
        section: 'HUMSS 11-A',
        room: 'Room 102 - Arts Bldg',
        dayOfWeek: 'Tuesday & Thursday',
        startTime: '10:00 AM',
        endTime: '11:30 AM',
      ),
    ];

    // 11. Notifications
    notifications = [
      AppNotificationModel(
        id: 'notif_1',
        title: 'Attendance Tap Confirmed',
        message: 'Student Juan Dela Cruz logged IN at 07:28 AM via RFID Reader (Main Gate).',
        timestamp: now.subtract(const Duration(hours: 1)),
        isRead: false,
        type: 'attendance',
      ),
      AppNotificationModel(
        id: 'notif_2',
        title: 'Quiz 1 Scores Released',
        message: 'Your score for Quiz 1: Functions (20/20) is now available for review.',
        timestamp: now.subtract(const Duration(hours: 3)),
        isRead: false,
        type: 'grade',
      ),
      AppNotificationModel(
        id: 'notif_3',
        title: 'New Activity Assigned',
        message: 'Prof. Maria Santos assigned Rational Functions Problem Set 1 due in 2 days.',
        timestamp: now.subtract(const Duration(hours: 6)),
        isRead: true,
        type: 'activity',
      ),
    ];
  }

  // --- Helper CRUD Actions ---

  // Auth Simulation
  UserModel? authenticate(String username, String password) {
    if (username == 'admin' && password == 'admin123') {
      currentUser = users.firstWhere((u) => u.username == 'admin');
      return currentUser;
    } else if (username == 'teacher' && password == 'teacher123') {
      currentUser = users.firstWhere((u) => u.username == 'teacher');
      return currentUser;
    } else if (username == 'student' && password == 'student123') {
      currentUser = users.firstWhere((u) => u.username == 'student');
      return currentUser;
    } else if (username == 'parent' && password == 'parent123') {
      currentUser = users.firstWhere((u) => u.username == 'parent');
      return currentUser;
    }
    return null;
  }

  void logout() {
    currentUser = null;
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
      final student = users.firstWhere((u) => u.studentId == studentId, orElse: () => users.first);
      attendanceRecords.add(
        AttendanceRecord(
          id: 'att_${DateTime.now().millisecondsSinceEpoch}',
          studentId: studentId,
          studentName: student.fullName,
          section: student.departmentOrSection ?? 'STEM 11-A',
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
  }

  void updateStudent(String id, String fullName, String studentId, String section) {
    final idx = users.indexWhere((u) => u.id == id);
    if (idx != -1) {
      users[idx] = users[idx].copyWith(
        fullName: fullName,
        studentId: studentId,
        departmentOrSection: section,
      );
    }
  }

  // Activity Submission & Creation
  void addActivity(ActivityModel activity) {
    activities.insert(0, activity);
  }

  void deleteActivity(String id) {
    activities.removeWhere((a) => a.id == id);
  }

  void submitActivity(String activityId, String studentId, String studentName, String fileName) {
    activitySubmissions.removeWhere((s) => s.activityOrExamId == activityId && s.studentId == studentId);
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
      objectives: '1. Master the fundamental theorems of $topic.\n2. Solve practical mathematical equations in real contexts.\n3. Formulate step-by-step verification methods.',
      materials: 'Teacher slide presentation, Scientific Calculator, Graphing Board, Worksheet $topic-01.',
      procedure: '1. Warm-up Discovery (10m): Introduce real scenario.\n2. Core Modeling (25m): Step-by-step algebraic breakdown of $topic.\n3. Collaborative Problem Solving (15m): Work in pairs on sample problems.\n4. Synthesis & Assessment (10m): Quick diagnostic assessment.',
      assessment: '5-item multiple choice and 1 problem solving item focusing on $topic.',
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
