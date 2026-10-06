import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/core/utils/deped_grading_engine.dart';

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

    const List<Map<String, String>> studentRecords = [];

    DateTime parseBirthday(String value) {
      final parts = value.split('-').map(int.parse).toList();
      return DateTime(parts[0], parts[1], parts[2]);
    }

    users = [
      const UserModel(
        id: 'usr_admin',
        username: 'ljcalica971@gmail.com',
        fullName: 'School Administrator',
        email: 'ljcalica971@gmail.com',
        role: UserRole.admin,
      ),
      const UserModel(
        id: 'T001',
        username: 'teacher',
        fullName: 'Karen P. Gonzaga',
        email: 'karen.gonzaga@classrealm.edu',
        role: UserRole.teacher,
        departmentOrSection: 'General Mathematics',
        isSetupComplete: true,
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
        'T001': 'teacher123',
        for (final record in studentRecords) record['id']!: 'student123',
        for (final record in studentRecords) 'P${record['id']}': 'parent123',
      });

    attendanceRecords = [];
    activities = [];
    assessmentScores = {};
    activitySubmissions = [];

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
    quizzesAndExams = [];
    examReviews = [];
    assessmentResults = [];
    gradingCriteria = [
      GradingCriteria(id: 'WW', name: 'Written Works', percentage: 20),
      GradingCriteria(id: 'PT', name: 'Performance Task', percentage: 50),
      GradingCriteria(id: 'EX', name: 'Examinations', percentage: 30),
    ];
    lessonPlans = [];
    materials = [];
    schedules = [];
    notifications = [
      AppNotificationModel(
        id: 'notif_att_1',
        title: 'Alert: Low Attendance detected',
        message: 'Student Daniel J. Mendoza (A04) has dropped below 80% attendance this month.',
        timestamp: now.subtract(const Duration(days: 1)),
        isRead: false,
        type: 'attendance_alert',
      ),
      AppNotificationModel(
        id: 'notif_risk_1',
        title: 'Alert: At-Risk Student Identified',
        message: 'Student Camille S. Villanueva (A05) current standing is below 75%. Remedial intervention recommended.',
        timestamp: now.subtract(const Duration(hours: 3)),
        isRead: false,
        type: 'academic_alert',
      ),
      AppNotificationModel(
        id: 'notif_att_2',
        title: 'RFID Attendance Log Sync',
        message: 'RFID Reader "Gate 1" synced 45 student logs at 07:45 AM.',
        timestamp: now.subtract(const Duration(hours: 10)),
        isRead: true,
        type: 'system',
      ),
    ];
  }

  double categoryAverageFor(String studentId, String category) {
    return DepEdGradingEngine.calculateCategoryAverage(
      studentId: studentId,
      category: category,
      assessmentScores: assessmentScores,
    );
  }

  double quarterlyGradeFor(String studentId) {
    return DepEdGradingEngine.calculateQuarterlyGrade(
      studentId: studentId,
      assessmentScores: assessmentScores,
    );
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
      if (newStatus == AccountStatus.pendingFirstLogin) {
        final teacher = users[idx];
        final lastName = (teacher.lastName ?? teacher.fullName.split(' ').last)
            .toLowerCase();
        String formattedBday = '19950101';
        if (teacher.birthday != null) {
          formattedBday =
              teacher.birthday!.year.toString() +
              teacher.birthday!.month.toString().padLeft(2, '0') +
              teacher.birthday!.day.toString().padLeft(2, '0');
        }
        _mockPasswords[teacherId] = '$lastName$formattedBday';
      }
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
  void archiveStudent(String id, [String? subjectId]) {
    final idx = users.indexWhere((u) => u.id == id);
    if (idx != -1) {
      users[idx] = users[idx].copyWith(
        isArchived: true,
        status: AccountStatus.archived,
      );
    }
  }

  void restoreStudent(String id, [String? subjectId]) {
    final idx = users.indexWhere((u) => u.id == id);
    if (idx != -1) {
      users[idx] = users[idx].copyWith(
        isArchived: false,
        status: AccountStatus.active,
      );
    }
  }

  void permanentlyDeleteStudent(String id, [String? subjectId]) {
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
    required String parentName,
    required String parentContactNumber,
    required String parentRelationship,
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
      parentGuardianName: parentName,
      parentGuardianContact: parentContactNumber,
      parentGuardianRelationship: parentRelationship,
    );
    users.add(newStudent);
    _mockPasswords[id] = tempPassword;

    // Auto-create Parent Account
    final parentId = 'P$studentId';
    final parentEmail = 'parent.$studentId@classrealm.edu';
    final newParent = UserModel(
      id: parentId,
      username: parentId.toLowerCase(),
      fullName: parentName,
      email: parentEmail,
      role: UserRole.parent,
      linkedStudentId: id,
      contactNumber: parentContactNumber,
      parentGuardianRelationship: parentRelationship,
    );
    users.add(newParent);
    _mockPasswords[parentId] = 'parent123'; // Default mock password for parents

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
    required DateTime birthday,
    required String parentName,
    required String parentContactNumber,
    required String parentRelationship,
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
      gradeLevel: users[idx].gradeLevel ?? '11',
      parentGuardianName: parentName,
      parentGuardianContact: parentContactNumber,
      parentGuardianRelationship: parentRelationship,
    );

    // Update Linked Parent Account if exists
    final parentIdx = users.indexWhere(
      (u) => u.role == UserRole.parent && u.linkedStudentId == id,
    );
    if (parentIdx != -1) {
      users[parentIdx] = users[parentIdx].copyWith(
        fullName: parentName,
        contactNumber: parentContactNumber,
        parentGuardianRelationship: parentRelationship,
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

  // Schedule Actions
  void addSchedule(ScheduleModel schedule) {
    schedules.add(schedule);
  }

  void updateSchedule(ScheduleModel schedule) {
    final idx = schedules.indexWhere((s) => s.id == schedule.id);
    if (idx != -1) {
      schedules[idx] = schedule;
    }
  }

  void deleteSchedule(String id) {
    schedules.removeWhere((s) => s.id == id);
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
