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
          'P${record['id']}'.toLowerCase(): 'parent123',
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
    quizzesAndExams = [
      QuizOrExamModel(
        id: 'EX1',
        title: 'ST1',
        description: 'Summative Test 1',
        subject: currentSubject,
        section: 'Section A, Section B',
        isExam: true,
        durationMinutes: 60,
        scheduleDate: DateTime(2026, 9, 25),
        sectionDeadlines: {
          'Section A': DateTime(2026, 9, 25, 16),
          'Section B': DateTime(2026, 9, 25, 16),
        },
        questions: questions('EX1', 10, 5),
      ),
      QuizOrExamModel(
        id: 'EX2',
        title: 'ST2',
        description: 'Summative Test 2',
        subject: currentSubject,
        section: 'Section A, Section B',
        isExam: true,
        durationMinutes: 60,
        scheduleDate: DateTime(2026, 10, 2),
        sectionDeadlines: {
          'Section A': DateTime(2026, 10, 2, 16),
          'Section B': DateTime(2026, 10, 2, 16),
        },
        questions: questions('EX2', 10, 5),
      ),
      QuizOrExamModel(
        id: 'EX3',
        title: 'TE',
        description: 'Term Examination',
        subject: currentSubject,
        section: 'Section A, Section B',
        isExam: true,
        durationMinutes: 90,
        scheduleDate: DateTime(2026, 10, 9),
        sectionDeadlines: {
          'Section A': DateTime(2026, 10, 9, 16),
          'Section B': DateTime(2026, 10, 9, 16),
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
    lessonPlans = [];
    materials = [];
    schedules = [];
    notifications = [];
  }

  /*
  void _seedLegacyData() {
    // 1. Users
    users = [
      UserModel(
        id: 'usr_admin',
        username: 'admin',
        fullName: 'Dr. Arthur Pendelton',
        email: 'admin@classrealm.edu',
        role: UserRole.admin,
        status: AccountStatus.active,
        departmentOrSection: 'School Administration',
      ),
      UserModel(
        id: 'usr_teacher_1',
        username: 'teacher',
        fullName: 'Prof. Maria Santos',
        email: 'msantos@classrealm.edu',
        role: UserRole.teacher,
        status: AccountStatus.active,
        departmentOrSection: 'Mathematics Department',
      ),
      UserModel(
        id: 'usr_teacher_2',
        username: 'teacher_pending',
        fullName: 'Mr. Roberto Gomez',
        email: 'rgomez@classrealm.edu',
        role: UserRole.teacher,
        status: AccountStatus.pending,
        departmentOrSection: 'Science & Physics',
      ),
      UserModel(
        id: 'usr_teacher_3',
        username: 'teacher_pending2',
        fullName: 'Ms. Clara Reyes',
        email: 'creyes@classrealm.edu',
        role: UserRole.teacher,
        status: AccountStatus.pending,
        departmentOrSection: 'English Literature',
      ),
      // Demo student (existing, keeps working)
      UserModel(
        id: 'usr_student_1',
        username: 'student_legacy',
        fullName: 'Juan Dela Cruz',
        email: 'juan.delacruz@gmail.com',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '123456789001',
        departmentOrSection: 'Section A',
        linkedStudentId: 'usr_parent_1',
        firstName: 'Juan',
        lastName: 'Dela Cruz',
        birthday: DateTime(2006, 5, 12),
        gradeLevel: '11',
      ),
      UserModel(
        id: 'usr_student_2',
        username: 'student2',
        fullName: 'Angelo Reyes',
        email: 'angelo.reyes@gmail.com',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '123456789002',
        departmentOrSection: 'Section A',
        firstName: 'Angelo',
        lastName: 'Reyes',
        birthday: DateTime(2006, 5, 12),
        gradeLevel: '11',
      ),
      UserModel(
        id: 'usr_student_3',
        username: 'student3',
        fullName: 'Bea Alonzo',
        email: 'bea.alonzo@gmail.com',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '123456789003',
        departmentOrSection: 'Section A',
        firstName: 'Bea',
        lastName: 'Alonzo',
        birthday: DateTime(2006, 5, 12),
        gradeLevel: '11',
      ),
      UserModel(
        id: 'usr_student_4',
        username: 'student4',
        fullName: 'Carlos Yulo',
        email: 'carlos.yulo@gmail.com',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '123456789004',
        departmentOrSection: 'Section A',
        firstName: 'Carlos',
        lastName: 'Yulo',
        birthday: DateTime(2006, 5, 12),
        gradeLevel: '11',
      ),
      UserModel(
        id: 'usr_student_5',
        username: 'student5',
        fullName: 'Diana Prince',
        email: 'diana.prince@gmail.com',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '123456789005',
        departmentOrSection: 'Section A',
        firstName: 'Diana',
        lastName: 'Prince',
        birthday: DateTime(2006, 5, 12),
        gradeLevel: '11',
      ),
      // --- NEW MOCK STUDENTS for first-login flow demo ---
      // 1. Pending First Login
      UserModel(
        id: 'usr_student_new_1',
        username: 'John Carlo Del Mundo',
        fullName: 'John Carlo H. Del Mundo',
        email: 'john.delmundo@gmail.com',
        role: UserRole.student,
        status: AccountStatus.pendingFirstLogin,
        studentId: '123456789006',
        departmentOrSection: 'Section A',
        firstName: 'John Carlo',
        middleName: 'H.',
        lastName: 'Del Mundo',
        birthday: DateTime(2005, 7, 1),
        gradeLevel: '11',
        parentGuardianName: 'Maria Del Mundo',
        parentGuardianContact: '09123456789',
        password: 'delmundo07012005',
      ),
      // 2. Active (already completed first login)
      UserModel(
        id: 'usr_student_new_2',
        username: 'Sofia Santos',
        fullName: 'Sofia M. Santos',
        email: 'sofia.santos@gmail.com',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '123456789007',
        departmentOrSection: 'Section A',
        firstName: 'Sofia',
        middleName: 'M.',
        lastName: 'Santos',
        birthday: DateTime(2006, 3, 15),
        gradeLevel: '11',
        parentGuardianName: 'Roberto Santos',
        parentGuardianContact: '09176543210',
        password: 'mypassword2026',
      ),
      // 3. Deactivated
      UserModel(
        id: 'usr_student_new_3',
        username: 'Miguel Garcia',
        fullName: 'Miguel A. Garcia',
        email: 'miguel.garcia@gmail.com',
        role: UserRole.student,
        status: AccountStatus.deactivated,
        studentId: '123456789008',
        departmentOrSection: 'Section B',
        firstName: 'Miguel',
        middleName: 'A.',
        lastName: 'Garcia',
        birthday: DateTime(2005, 11, 20),
        gradeLevel: '11',
        parentGuardianName: 'Elena Garcia',
        parentGuardianContact: '09181112222',
        password: 'garcia11202005',
      ),
      const UserModel(
        id: 'usr_parent_1',
        username: 'parent_legacy',
        fullName: 'Mrs. Josefina Dela Cruz',
        email: 'josefina.delacruz@gmail.com',
        role: UserRole.parent,
        status: AccountStatus.active,
        linkedStudentId: 'usr_student_1',
        contactNumber: '09171234567',
      ),
    ];

    users.addAll([
      const UserModel(
        id: 'usr_student_a8',
        username: 'student_a8',
        fullName: 'Nina Bautista',
        email: 'nina.bautista@classrealm.edu',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '123456789009',
        departmentOrSection: 'Section A',
        firstName: 'Nina',
        lastName: 'Bautista',
        gradeLevel: '11',
      ),
      const UserModel(
        id: 'usr_student_a9',
        username: 'student_a9',
        fullName: 'Paolo Mendoza',
        email: 'paolo.mendoza@classrealm.edu',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '123456789010',
        departmentOrSection: 'Section A',
        firstName: 'Paolo',
        lastName: 'Mendoza',
        gradeLevel: '11',
      ),
      const UserModel(
        id: 'usr_student_a10',
        username: 'student_a10',
        fullName: 'Rhea Villanueva',
        email: 'rhea.villanueva@classrealm.edu',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '123456789011',
        departmentOrSection: 'Section A',
        firstName: 'Rhea',
        lastName: 'Villanueva',
        gradeLevel: '11',
      ),
      const UserModel(
        id: 'usr_student_b2',
        username: 'student_b2',
        fullName: 'Aaron Castillo',
        email: 'aaron.castillo@classrealm.edu',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '123456789012',
        departmentOrSection: 'Section B',
        firstName: 'Aaron',
        lastName: 'Castillo',
        gradeLevel: '11',
      ),
      const UserModel(
        id: 'usr_student_b3',
        username: 'student_b3',
        fullName: 'Bianca Flores',
        email: 'bianca.flores@classrealm.edu',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '123456789013',
        departmentOrSection: 'Section B',
        firstName: 'Bianca',
        lastName: 'Flores',
        gradeLevel: '11',
      ),
      const UserModel(
        id: 'usr_student_b4',
        username: 'student_b4',
        fullName: 'Cedric Navarro',
        email: 'cedric.navarro@classrealm.edu',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '123456789014',
        departmentOrSection: 'Section B',
        firstName: 'Cedric',
        lastName: 'Navarro',
        gradeLevel: '11',
      ),
      const UserModel(
        id: 'usr_student_b5',
        username: 'student_b5',
        fullName: 'Elise Ramos',
        email: 'elise.ramos@classrealm.edu',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '123456789015',
        departmentOrSection: 'Section B',
        firstName: 'Elise',
        lastName: 'Ramos',
        gradeLevel: '11',
      ),
      const UserModel(
        id: 'usr_student_b6',
        username: 'student_b6',
        fullName: 'Felix Soriano',
        email: 'felix.soriano@classrealm.edu',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '123456789016',
        departmentOrSection: 'Section B',
        firstName: 'Felix',
        lastName: 'Soriano',
        gradeLevel: '11',
      ),
      const UserModel(
        id: 'usr_student_b7',
        username: 'student_b7',
        fullName: 'Grace Torres',
        email: 'grace.torres@classrealm.edu',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '123456789017',
        departmentOrSection: 'Section B',
        firstName: 'Grace',
        lastName: 'Torres',
        gradeLevel: '11',
      ),
      const UserModel(
        id: 'usr_student_b8',
        username: 'student_b8',
        fullName: 'Hannah Velasco',
        email: 'hannah.velasco@classrealm.edu',
        role: UserRole.student,
        status: AccountStatus.active,
        studentId: '123456789018',
        departmentOrSection: 'Section B',
        firstName: 'Hannah',
        lastName: 'Velasco',
        gradeLevel: '11',
      ),
    ]);

    // Seed mock passwords for demo accounts
    _mockPasswords['usr_admin'] = 'admin123';
    _mockPasswords['usr_teacher_1'] = 'teacher123';
    _mockPasswords['A01'] = 'student123';
    _mockPasswords['PA01'] = 'parent123';
    _mockPasswords['usr_student_1'] = 'student123';
    _mockPasswords['usr_parent_1'] = 'parent123';
    _mockPasswords['usr_student_new_1'] = 'delmundo07012005';
    _mockPasswords['usr_student_new_2'] = 'mypassword2026';
    _mockPasswords['usr_student_new_3'] = 'garcia11202005';

    // 2. Attendance Records (Simulated RFID & Manual)
    final now = DateTime.now();
    attendanceRecords = [
      AttendanceRecord(
        id: 'att_1',
        studentId: '100001230001',
        studentName: 'Alyssa M. Reyes',
        section: 'Section A',
        date: now,
        timeIn: '07:28 AM',
        status: AttendanceStatus.present,
        method: 'RFID (ESP32 Tap)',
      ),
      AttendanceRecord(
        id: 'att_2',
        studentId: '100001230002',
        studentName: 'Angelo Reyes',
        section: 'Section A',
        date: now,
        timeIn: '07:46 AM',
        status: AttendanceStatus.late,
        method: 'RFID (ESP32 Tap)',
      ),
      AttendanceRecord(
        id: 'att_3',
        studentId: '100001230003',
        studentName: 'Bea Alonzo',
        section: 'Section A',
        date: now,
        timeIn: '07:15 AM',
        status: AttendanceStatus.present,
        method: 'RFID (ESP32 Tap)',
      ),
      AttendanceRecord(
        id: 'att_4',
        studentId: '100001230004',
        studentName: 'Carlos Yulo',
        section: 'Section A',
        date: now,
        timeIn: '--:--',
        status: AttendanceStatus.absent,
        method: 'Manual Check',
      ),
      AttendanceRecord(
        id: 'att_5',
        studentId: '100001230005',
        studentName: 'Diana Prince',
        section: 'Section A',
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
        section: 'Section A',
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
        section: 'Section A',
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
        section: 'Section A',
        deadline: now.subtract(const Duration(days: 2)),
        maxScore: 40.0,
        isPublished: true,
        submissionsCount: 35,
        totalStudents: 35,
      ),
      ActivityModel(
        id: 'pt_mock_1',
        title: 'Rational Functions Performance Portfolio',
        description: 'Grade 11 General Mathematics performance task.',
        instructions: 'Create a portfolio showing the graph, domain, range, and asymptotes of assigned rational functions.',
        subject: 'General Mathematics',
        section: 'Section A, Section B',
        deadline: now.add(const Duration(days: 7)),
        sectionDeadlines: {
          'Section A': DateTime(2026, 9, 18, 16, 0),
          'Section B': DateTime(2026, 9, 18, 16, 30),
        },
        maxScore: 100.0,
        isPublished: true,
        isRequirement: true,
        attachmentName: 'Rational_Functions_Performance_Task.pdf',
      ),
    ];

    // 4. Submissions
    activitySubmissions = [
      StudentSubmission(
        id: 'sub_1',
        activityOrExamId: 'act_1',
        studentId: 'A01',
        studentName: 'Alyssa M. Reyes',
        submittedAt: now.subtract(const Duration(hours: 4)),
        attachedFile: 'AlyssaReyes_RationalFunctions_Act1.pdf',
        score: 48.0,
        maxScore: 50.0,
        status: ActivityStatus.graded,
        feedback: 'Excellent breakdown of vertical and horizontal asymptotes!',
      ),
      StudentSubmission(
        id: 'pt_sub_1',
        activityOrExamId: 'pt_mock_1',
        studentId: 'A01',
        studentName: 'Alyssa M. Reyes',
        submittedAt: now.subtract(const Duration(days: 1, hours: 2)),
        attachedFile: 'Reyes_RationalFunctions.pdf',
        score: 99,
        maxScore: 100,
        status: ActivityStatus.graded,
        feedback: 'Excellent graphing and complete explanation.',
      ),
      StudentSubmission(
        id: 'pt_sub_2',
        activityOrExamId: 'pt_mock_1',
        studentId: 'usr_student_2',
        studentName: 'Angelo Reyes',
        submittedAt: now.subtract(const Duration(hours: 5)),
        attachedFile: 'Reyes_RationalFunctions.docx',
        score: 92,
        maxScore: 100,
        status: ActivityStatus.graded,
        feedback: 'Clear solution. Review the range notation.',
      ),
      StudentSubmission(
        id: 'pt_sub_3',
        activityOrExamId: 'pt_mock_1',
        studentId: 'usr_student_3',
        studentName: 'Bea Alonzo',
        submittedAt: now.subtract(const Duration(hours: 1)),
        attachedFile: 'Alonzo_RationalFunctions.pdf',
        maxScore: 100,
        status: ActivityStatus.submitted,
      ),
    ];

    // 5. Quizzes and Exams
    quizzesAndExams = [
      QuizOrExamModel(
        id: 'quiz_1',
        title: 'Quiz 1: Functions & Domain/Range',
        description: 'Covers piecewise functions, rational expressions, and composite function evaluation.',
        subject: 'General Mathematics',
        section: 'Section A',
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
            choices: [
              'All real numbers except x = 3',
              'All real numbers except x = -3',
              'x > 3',
              'x >= 0',
            ],
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
            questionText:
                'Evaluate (f o g)(2) when f(x) = 2x + 1 and g(x) = x^2.',
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
        section: 'Section A',
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
            choices: [
              'f(x) = 2(0.5)^x',
              'f(x) = 3(2)^x',
              'f(x) = x^2 - 4',
              'f(x) = log(x)',
            ],
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
            questionText:
                'Find the vertical asymptote of f(x) = (2x + 1)/(x - 5).',
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
        studentId: '123456789001',
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
        studentId: '123456789002',
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
        studentId: '123456789004',
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
      GradingCriteria(
        id: 'gc_1',
        name: 'Quarterly Examinations',
        percentage: 30.0,
      ),
      GradingCriteria(
        id: 'gc_2',
        name: 'Written Activities & Worksheets',
        percentage: 25.0,
      ),
      GradingCriteria(
        id: 'gc_3',
        name: 'Quizzes & Unit Tests',
        percentage: 20.0,
      ),
      GradingCriteria(
        id: 'gc_4',
        name: 'Performance Tasks & Projects',
        percentage: 15.0,
      ),
      GradingCriteria(
        id: 'gc_5',
        name: 'Attendance & Class Participation',
        percentage: 10.0,
      ),
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
        assessment:
            '10-point formative assessment on identifying undefined values.',
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
        description:
            'Manipulate numerator and denominator coefficients in real time.',
      ),
    ];

    // 10. Schedules
    schedules = [
      ScheduleModel(
        id: 'sch_1',
        subject: 'General Mathematics',
        section: 'Section A',
        room: 'Room 304 - Science Wing',
        dayOfWeek: 'Monday & Wednesday',
        startTime: '07:30 AM',
        endTime: '09:00 AM',
      ),
      ScheduleModel(
        id: 'sch_2',
        subject: 'General Mathematics',
        section: 'Section B',
        room: 'Room 305 - Science Wing',
        dayOfWeek: 'Monday & Wednesday',
        startTime: '09:15 AM',
        endTime: '10:45 AM',
      ),
      ScheduleModel(
        id: 'sch_3',
        subject: 'General Mathematics',
        section: 'Section A',
        room: 'Room 201 - Business Hall',
        dayOfWeek: 'Tuesday & Thursday',
        startTime: '08:00 AM',
        endTime: '09:30 AM',
      ),
      ScheduleModel(
        id: 'sch_4',
        subject: 'General Mathematics',
        section: 'Section B',
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
  */

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
