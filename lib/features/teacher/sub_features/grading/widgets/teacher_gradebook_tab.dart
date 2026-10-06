import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/supabase_student_repository.dart';

/// DepEd-style Strengthened SHS Class Record (Gradebook).
/// Mirrors the official DepEd grading spreadsheet layout with
/// WW (Written Works), PT (Performance Tasks), EX (Examinations) columns,
/// auto-computed totals, percentage scores, weighted scores, initial grade,
/// and term grade. Students are grouped by gender (Male / Female).
class TeacherGradebookTab extends StatefulWidget {
  const TeacherGradebookTab({super.key});

  @override
  State<TeacherGradebookTab> createState() => _TeacherGradebookTabState();
}

class _TeacherGradebookTabState extends State<TeacherGradebookTab> {
  // Selected schedule determines the section + subject context
  String? _selectedSubject;
  String? _selectedSection;
  List<Map<String, dynamic>> _teacherSubjects = [];
  bool _isLoadingSubjects = true;
  bool _isLoadingStudents = false;
  String? _studentLoadError;
  List<UserModel> _students = [];
  int _studentLoadRequest = 0;

  int _selectedTerm = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
  }

  Future<void> _fetchSubjects() async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoadingSubjects = false;
      });
      return;
    }

    try {
      final subjects = await SubjectRepository.instance.getTeacherSubjects(
        user.id,
      );
      if (!mounted) return;
      final firstSubject = subjects.isEmpty ? null : subjects.first;
      setState(() {
        _teacherSubjects = subjects;
        _selectedSubject = firstSubject?['subject_name']?.toString();
        _selectedSection = firstSubject?['section_name']?.toString();
        _isLoadingSubjects = false;
      });
      final subjectId = firstSubject?['id']?.toString();
      if (subjectId != null) await _fetchStudents(user.id, subjectId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _studentLoadError = 'Failed to load subjects: $error';
        _isLoadingSubjects = false;
      });
    }
  }

  Future<void> _fetchStudents(String teacherId, String subjectId) async {
    final request = ++_studentLoadRequest;
    setState(() {
      _isLoadingStudents = true;
      _studentLoadError = null;
      _students = [];
    });
    try {
      final students = await SupabaseStudentRepository().getStudentsForTeacher(
        teacherId,
        subjectId: subjectId,
      );
      if (!mounted || request != _studentLoadRequest) return;
      setState(() {
        _students = students;
        _isLoadingStudents = false;
      });
    } catch (error) {
      if (!mounted || request != _studentLoadRequest) return;
      setState(() {
        _studentLoadError = 'Failed to load enrolled students: $error';
        _isLoadingStudents = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Scores map: studentId -> category -> column index -> score
  // category: 'ww', 'pt', 'ex'
  final Map<String, Map<String, Map<int, double>>> _scores = {};

  // Highest Possible Score per category per column
  final Map<String, Map<int, double>> _hps = {'ww': {}, 'pt': {}, 'ex': {}};

  // Number of visible columns per category
  static const int wwColumns = 10;
  static const int ptColumns = 10;
  static const int exColumns = 3; // ST1, ST2, TE

  List<UserModel> get _studentsForSchedule => _students;

  List<UserModel> get _maleStudents =>
      _studentsForSchedule.where((s) => s.gender == 'Male').toList()..sort(
        (a, b) =>
            (a.lastName ?? a.fullName).compareTo(b.lastName ?? b.fullName),
      );

  List<UserModel> get _femaleStudents =>
      _studentsForSchedule.where((s) => s.gender == 'Female').toList()..sort(
        (a, b) =>
            (a.lastName ?? a.fullName).compareTo(b.lastName ?? b.fullName),
      );

  // Get the display name: LASTNAME, Firstname M.
  String _displayName(UserModel s) {
    final last = s.lastName ?? '';
    final first = s.firstName ?? '';
    final mid = (s.middleName != null && s.middleName!.isNotEmpty)
        ? ' ${s.middleName![0]}.'
        : '';
    if (last.isEmpty && first.isEmpty) return s.fullName;
    return '${last.toUpperCase()}, $first$mid';
  }

  double _getScore(String studentId, String category, int col) {
    return _scores[studentId]?[category]?[col] ?? 0;
  }

  void _setScore(String studentId, String category, int col, double val) {
    _scores.putIfAbsent(studentId, () => {});
    _scores[studentId]!.putIfAbsent(category, () => {});
    setState(() {
      _scores[studentId]![category]![col] = val;
    });
  }

  double _getHps(String category, int col) {
    return _hps[category]?[col] ?? 0;
  }

  void _setHps(String category, int col, double val) {
    setState(() {
      _hps[category]![col] = val;
    });
  }

  // Compute total raw score for a student in a category
  double _totalRaw(String studentId, String category, int numCols) {
    double total = 0;
    for (int i = 0; i < numCols; i++) {
      total += _getScore(studentId, category, i);
    }
    return total;
  }

  // Total HPS for a category
  double _totalHps(String category, int numCols) {
    double total = 0;
    for (int i = 0; i < numCols; i++) {
      total += _getHps(category, i);
    }
    return total;
  }

  // Percentage Score (PS) = (Total / HPS) * 100
  double _percentageScore(String studentId, String category, int numCols) {
    final hps = _totalHps(category, numCols);
    if (hps == 0) return 0;
    return (_totalRaw(studentId, category, numCols) / hps) * 100;
  }

  // Weighted Score (WS) = PS * weight / 100
  double _weightedScore(
    String studentId,
    String category,
    int numCols,
    double weight,
  ) {
    return _percentageScore(studentId, category, numCols) * weight / 100;
  }

  Map<String, dynamic>? get _currentSubjectData {
    if (_selectedSubject == null || _selectedSection == null) return null;
    try {
      return _teacherSubjects.firstWhere(
        (s) =>
            s['subject_name'] == _selectedSubject &&
            s['section_name'] == _selectedSection,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? get _currentSubjectWeightsData {
    if (_selectedSubject == null) return null;
    try {
      return _teacherSubjects.firstWhere(
        (s) =>
            s['subject_name'] == _selectedSubject &&
            s['section_name'] == _selectedSection,
      );
    } catch (_) {
      return null;
    }
  }

  double _parseWeight(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  // Initial Grade = sum of all weighted scores
  double _initialGrade(String studentId) {
    final data = _currentSubjectWeightsData;
    final wwWeight = _parseWeight(data?['ww_weight']);
    final ptWeight = _parseWeight(data?['pt_weight']);
    final exWeight = _parseWeight(data?['ex_weight']);
    final wsWW = _weightedScore(studentId, 'ww', wwColumns, wwWeight);
    final wsPT = _weightedScore(studentId, 'pt', ptColumns, ptWeight);
    final wsEX = _weightedScore(studentId, 'ex', exColumns, exWeight);
    return wsWW + wsPT + wsEX;
  }

  // Transmuted Grade (DepEd transmutation table simplified)
  double _transmutedGrade(double initialGrade) {
    if (initialGrade >= 100) return 100;
    if (initialGrade >= 98.40) return 99;
    if (initialGrade >= 96.80) return 98;
    if (initialGrade >= 95.20) return 97;
    if (initialGrade >= 93.60) return 96;
    if (initialGrade >= 92.00) return 95;
    if (initialGrade >= 90.40) return 94;
    if (initialGrade >= 88.80) return 93;
    if (initialGrade >= 87.20) return 92;
    if (initialGrade >= 85.60) return 91;
    if (initialGrade >= 84.00) return 90;
    if (initialGrade >= 82.40) return 89;
    if (initialGrade >= 80.80) return 88;
    if (initialGrade >= 79.20) return 87;
    if (initialGrade >= 77.60) return 86;
    if (initialGrade >= 76.00) return 85;
    if (initialGrade >= 74.40) return 84;
    if (initialGrade >= 72.80) return 83;
    if (initialGrade >= 71.20) return 82;
    if (initialGrade >= 69.60) return 81;
    if (initialGrade >= 68.00) return 80;
    if (initialGrade >= 66.40) return 79;
    if (initialGrade >= 64.80) return 78;
    if (initialGrade >= 63.20) return 77;
    if (initialGrade >= 61.60) return 76;
    if (initialGrade >= 60.00) return 75;
    // Below 60: linear mapping down
    if (initialGrade >= 56.00) return 74;
    if (initialGrade >= 52.00) return 73;
    if (initialGrade >= 48.00) return 72;
    if (initialGrade >= 44.00) return 71;
    if (initialGrade >= 40.00) return 70;
    if (initialGrade >= 36.00) return 69;
    if (initialGrade >= 32.00) return 68;
    if (initialGrade >= 28.00) return 67;
    if (initialGrade >= 24.00) return 66;
    if (initialGrade >= 20.00) return 65;
    if (initialGrade >= 16.00) return 64;
    if (initialGrade >= 12.00) return 63;
    if (initialGrade >= 8.00) return 62;
    if (initialGrade >= 4.00) return 61;
    return 60;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Colors that adapt to light/dark mode
    final headerBg = isDark ? const Color(0xFF1E293B) : const Color(0xFF1B3A5C);
    final subHeaderBg = isDark
        ? const Color(0xFF334155)
        : const Color(0xFF2D5A8E);
    final headerText = Colors.white;
    final cellBg = isDark ? theme.colorScheme.surface : Colors.white;
    final cellText = theme.colorScheme.onSurface;
    final borderColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.15)
        : const Color(0xFFCBD5E1);
    final altRowBg = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
        : const Color(0xFFF8FAFC);
    final genderHeaderBg = isDark
        ? const Color(0xFF374151)
        : const Color(0xFF334155);

    // Weights
    final data = _currentSubjectWeightsData;
    final wwWeight = _parseWeight(data?['ww_weight']);
    final ptWeight = _parseWeight(data?['pt_weight']);
    final exWeight = _parseWeight(data?['ex_weight']);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ========== TOP CONTROLS ==========
          _buildTopControls(theme, isDark),
          const SizedBox(height: 16),

          // ========== SPREADSHEET ==========
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cellBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // School Info Header Bar
                  _buildSchoolInfoBar(theme, headerBg, headerText),

                  // Spreadsheet content
                  Expanded(
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // LEFT STICKY COLUMN
                              Container(
                                width: 230.0,
                                decoration: BoxDecoration(
                                  color: cellBg,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isDark ? 0.3 : 0.15,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(4, 0),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    _buildCategoryHeaders(
                                      theme,
                                      subHeaderBg,
                                      headerText,
                                      wwWeight,
                                      ptWeight,
                                      exWeight,
                                      isLeft: true,
                                    ),
                                    _buildColumnSubHeaders(
                                      theme,
                                      headerBg,
                                      headerText,
                                      wwWeight,
                                      ptWeight,
                                      exWeight,
                                      isLeft: true,
                                    ),
                                    _buildHpsRow(
                                      theme,
                                      isDark,
                                      borderColor,
                                      cellText,
                                      wwWeight,
                                      ptWeight,
                                      exWeight,
                                      isLeft: true,
                                    ),
                                    Container(height: 2, color: borderColor),
                                    _buildGenderHeader(
                                      'MALE',
                                      genderHeaderBg,
                                      isLeft: true,
                                    ),
                                    ..._buildStudentRows(
                                      _maleStudents,
                                      theme,
                                      isDark,
                                      cellText,
                                      borderColor,
                                      altRowBg,
                                      cellBg,
                                      wwWeight,
                                      ptWeight,
                                      exWeight,
                                      isLeft: true,
                                    ),
                                    _buildGenderHeader(
                                      'FEMALE',
                                      genderHeaderBg,
                                      isLeft: true,
                                    ),
                                    ..._buildStudentRows(
                                      _femaleStudents,
                                      theme,
                                      isDark,
                                      cellText,
                                      borderColor,
                                      altRowBg,
                                      cellBg,
                                      wwWeight,
                                      ptWeight,
                                      exWeight,
                                      isLeft: true,
                                    ),
                                  ],
                                ),
                              ),
                              // RIGHT SCROLLABLE COLUMNS
                              Expanded(
                                child: Scrollbar(
                                  thickness: 12,
                                  controller: _scrollController,
                                  radius: const Radius.circular(8),
                                  interactive: true,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    controller: _scrollController,
                                    child: SizedBox(
                                      width: _calculateTotalWidth() - 230.0,
                                      child: Column(
                                        children: [
                                          _buildCategoryHeaders(
                                            theme,
                                            subHeaderBg,
                                            headerText,
                                            wwWeight,
                                            ptWeight,
                                            exWeight,
                                            isLeft: false,
                                          ),
                                          _buildColumnSubHeaders(
                                            theme,
                                            headerBg,
                                            headerText,
                                            wwWeight,
                                            ptWeight,
                                            exWeight,
                                            isLeft: false,
                                          ),
                                          _buildHpsRow(
                                            theme,
                                            isDark,
                                            borderColor,
                                            cellText,
                                            wwWeight,
                                            ptWeight,
                                            exWeight,
                                            isLeft: false,
                                          ),
                                          Container(
                                            height: 2,
                                            color: borderColor,
                                          ),
                                          _buildGenderHeader(
                                            '',
                                            genderHeaderBg,
                                            isLeft: false,
                                          ),
                                          ..._buildStudentRows(
                                            _maleStudents,
                                            theme,
                                            isDark,
                                            cellText,
                                            borderColor,
                                            altRowBg,
                                            cellBg,
                                            wwWeight,
                                            ptWeight,
                                            exWeight,
                                            isLeft: false,
                                          ),
                                          _buildGenderHeader(
                                            '',
                                            genderHeaderBg,
                                            isLeft: false,
                                          ),
                                          ..._buildStudentRows(
                                            _femaleStudents,
                                            theme,
                                            isDark,
                                            cellText,
                                            borderColor,
                                            altRowBg,
                                            cellBg,
                                            wwWeight,
                                            ptWeight,
                                            exWeight,
                                            isLeft: false,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isLoadingSubjects || _isLoadingStudents)
                          Positioned.fill(
                            child: ColoredBox(
                              color: cellBg,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ),
                        if (_studentLoadError != null &&
                            !_isLoadingSubjects &&
                            !_isLoadingStudents)
                          Positioned.fill(
                            child: ColoredBox(
                              color: cellBg,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    _studentLoadError!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Term Tabs at the bottom
                  _buildTermTabs(theme, isDark, borderColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // TOP CONTROLS
  // ====================================================================
  Widget _buildTopControls(ThemeData theme, bool isDark) {
    return Row(
      children: [
        // Title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grades Management',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Strengthened Senior High School Class Record',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),

        // Subject selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerHighest
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSubject,
              isDense: true,
              hint: Text(
                'No subject yet',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              items: _teacherSubjects
                  .map((s) => s['subject_name']?.toString() ?? '')
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList()
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) {
                final selectedRow = _teacherSubjects.firstWhere(
                  (subject) => subject['subject_name'] == val,
                );
                setState(() {
                  _selectedSubject = val;
                  _selectedSection = selectedRow['section_name']?.toString();
                });
                final teacherId = AuthRepository.instance.currentUser?.id;
                final subjectId = selectedRow['id']?.toString();
                if (teacherId != null && subjectId != null) {
                  _fetchStudents(teacherId, subjectId);
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Section selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerHighest
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSection,
              isDense: true,
              hint: Text(
                'No section yet',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              items:
                  (_selectedSubject == null
                          ? <String>[]
                          : _teacherSubjects
                                .where(
                                  (s) => s['subject_name'] == _selectedSubject,
                                )
                                .map((s) => s['section_name']?.toString() ?? '')
                                .where((s) => s.isNotEmpty)
                                .toSet()
                                .toList())
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
              onChanged: (val) {
                final selectedRow = _teacherSubjects.firstWhere(
                  (subject) =>
                      subject['subject_name'] == _selectedSubject &&
                      subject['section_name'] == val,
                );
                setState(() {
                  _selectedSection = val;
                });
                final teacherId = AuthRepository.instance.currentUser?.id;
                final subjectId = selectedRow['id']?.toString();
                if (teacherId != null && subjectId != null) {
                  _fetchStudents(teacherId, subjectId);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  // ====================================================================
  // SCHOOL INFO BAR (like the DepEd header)
  // ====================================================================
  Widget _buildSchoolInfoBar(ThemeData theme, Color bg, Color text) {
    final sub = _selectedSubject;
    final sec = _selectedSection;
    final data = _currentSubjectData;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: bg,
      child: Row(
        children: [
          // Left: School Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub != null ? sub : 'No subject selected',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: text,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sec != null ? sec : 'No section selected',
                  style: TextStyle(
                    fontSize: 12,
                    color: text.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          // Center: Subject + Section
          if (sub != null && sec != null) ...[
            _infoChip('Subject', sub, AppTheme.catBlue, text),
            const SizedBox(width: 10),
            _infoChip('Section', sec, AppTheme.catPurple, text),
            const SizedBox(width: 10),
            _infoChip(
              'Grade',
              '${data?['grade_level'] ?? 11}',
              AppTheme.catOrange,
              text,
            ),
          ],
          const SizedBox(width: 10),
          // Right: School Year
          _infoChip(
            'S.Y.',
            '${data?['school_year'] ?? '2026 - 2027'}',
            AppTheme.catGreen,
            text,
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value, Color accent, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, color: text.withValues(alpha: 0.7)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // CATEGORY HEADERS (WW 20%, PT 50%, EX 30%)
  // ====================================================================
  Widget _buildCategoryHeaders(
    ThemeData theme,
    Color bg,
    Color text,
    double wwW,
    double ptW,
    double exW, {
    bool isLeft = true,
  }) {
    const nameW = 200.0;
    const numW = 30.0;
    const colW = 48.0;
    const computedW = 56.0;

    return Container(
      height: 42,
      color: bg,
      child: Row(
        children: isLeft
            ? [
                // # column
                _headerCell(numW, '#', text, bg),
                // Name column header
                _headerCell(
                  nameW,
                  "LEARNERS' NAMES",
                  text,
                  bg,
                  align: Alignment.centerLeft,
                ),
              ]
            : [
                // WW
                _categoryBlock(
                  'WRITTEN / ORAL WORKS (WWs)',
                  '${wwW.toStringAsFixed(0)}%',
                  wwColumns * colW + 3 * computedW,
                  AppTheme.catBlue,
                  text,
                ),
                // PT
                _categoryBlock(
                  'PRODUCT / PERFORMANCE TASKS (PTs)',
                  '${ptW.toStringAsFixed(0)}%',
                  ptColumns * colW + 3 * computedW,
                  AppTheme.catGreen,
                  text,
                ),
                // EX
                _categoryBlock(
                  'EXAMINATIONS (EXs)',
                  '${exW.toStringAsFixed(0)}%',
                  exColumns * colW +
                      (exColumns + 2) *
                          computedW, // Need more space for multiple WS columns
                  AppTheme.catOrange,
                  text,
                ),
                // Initial Grade
                Container(
                  width: computedW,
                  height: 42,
                  color: bg,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    'INITIAL\nGRADE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: text,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Term Grade
                Container(
                  width: computedW,
                  height: 42,
                  color: bg,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    'TERM\nGRADE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: text,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
      ),
    );
  }

  Widget _categoryBlock(
    String title,
    String weight,
    double width,
    Color accent,
    Color text,
  ) {
    return Container(
      width: width,
      height: 42,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.2),
        border: Border(
          left: BorderSide(color: accent, width: 2),
          right: BorderSide(color: accent, width: 2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: text,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            weight,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFD700), // Amber/gold to make it pop!
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // COLUMN SUB-HEADERS (1, 2, 3 ... TOTAL, PS, WS)
  // ====================================================================
  Widget _buildColumnSubHeaders(
    ThemeData theme,
    Color bg,
    Color text,
    double wwWeight,
    double ptWeight,
    double exWeight, {
    bool isLeft = true,
  }) {
    const colW = 48.0;
    const computedW = 56.0;
    const nameW = 200.0;
    const numW = 30.0;

    List<Widget> buildCategoryCols(
      int count,
      Color accent,
      double weight, {
      bool isExam = false,
    }) {
      final cols = <Widget>[];
      for (int i = 0; i < count; i++) {
        String title = isExam ? 'ST ${i + 1}' : '${i + 1}';
        if (isExam && i == count - 1) {
          title = 'TE'; // Last column in exam is Term Exam
        }
        cols.add(_subHeaderCell(colW, title, text, bg));
      }

      if (isExam) {
        for (int i = 0; i < count; i++) {
          String title = (i == count - 1) ? 'WS TE' : 'WS ST${i + 1}';
          cols.add(
            _subHeaderCell(
              computedW,
              title,
              text,
              accent.withValues(alpha: 0.15),
            ),
          );
        }
      } else {
        cols.add(
          _subHeaderCell(
            computedW,
            'TOTAL',
            text,
            accent.withValues(alpha: 0.15),
          ),
        );
      }

      cols.add(
        _subHeaderCell(computedW, 'PS', text, accent.withValues(alpha: 0.1)),
      );
      cols.add(
        _subHeaderCell(computedW, 'WS', text, accent.withValues(alpha: 0.25)),
      );
      return cols;
    }

    return Container(
      height: 28,
      color: bg.withValues(alpha: 0.9),
      child: Row(
        children: isLeft
            ? [
                _subHeaderCell(numW, '', text, bg),
                _subHeaderCell(nameW, '', text, bg),
              ]
            : [
                ...buildCategoryCols(wwColumns, AppTheme.catBlue, wwWeight),
                ...buildCategoryCols(ptColumns, AppTheme.catGreen, ptWeight),
                ...buildCategoryCols(
                  exColumns,
                  AppTheme.catOrange,
                  exWeight,
                  isExam: true,
                ),
                _subHeaderCell(computedW, 'IG', text, bg),
                _subHeaderCell(computedW, 'TG', text, bg),
              ],
      ),
    );
  }

  Widget _headerCell(
    double width,
    String label,
    Color text,
    Color bg, {
    double fontSize = 10,
    Alignment align = Alignment.center,
  }) {
    return Container(
      width: width,
      height: 42,
      color: bg,
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: text,
        ),
        textAlign: align == Alignment.centerLeft
            ? TextAlign.left
            : TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _subHeaderCell(double width, String label, Color text, Color bg) {
    return Container(
      width: width,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: text.withValues(alpha: 0.8),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ====================================================================
  // HPS ROW (Highest Possible Score)
  // ====================================================================
  Widget _buildHpsRow(
    ThemeData theme,
    bool isDark,
    Color borderColor,
    Color cellText,
    double wwWeight,
    double ptWeight,
    double exWeight, {
    bool isLeft = true,
  }) {
    const colW = 48.0;
    const computedW = 56.0;
    const nameW = 200.0;
    const numW = 30.0;

    final hpsBg = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE0ECFF);

    List<Widget> buildHpsCols(
      String category,
      int count,
      Color accent,
      double weight,
    ) {
      final cols = <Widget>[];
      for (int i = 0; i < count; i++) {
        cols.add(
          _buildHpsCell(category, i, colW, hpsBg, cellText, borderColor),
        );
      }
      // Total HPS
      if (category == 'ex') {
        // Exam component WS values will come from Classroom Setup.
        for (int i = 0; i < count; i++) {
          cols.add(_computedCell(computedW, '', hpsBg, cellText, borderColor));
        }
      } else {
        final totalHps = _totalHps(category, count);
        cols.add(
          _computedCell(
            computedW,
            totalHps > 0 ? totalHps.toStringAsFixed(0) : '',
            hpsBg,
            cellText,
            borderColor,
            isBold: true,
          ),
        );
      }
      cols.add(
        _computedCell(
          computedW,
          '100',
          hpsBg,
          accent,
          borderColor,
          isBold: true,
        ),
      );
      cols.add(
        _computedCell(
          computedW,
          '${weight.toStringAsFixed(0)}%',
          hpsBg,
          const Color(
            0xFFD4AF37,
          ), // Elegant gold color that works on both light/dark backgrounds
          borderColor,
          isBold: true,
        ),
      );
      return cols;
    }

    return Container(
      height: 32,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: isLeft
            ? [
                _computedCell(numW, '', hpsBg, cellText, borderColor),
                Container(
                  width: nameW,
                  height: 32,
                  color: hpsBg,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    'HIGHEST POSSIBLE SCORE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: cellText.withValues(alpha: 0.7),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ]
            : [
                ...buildHpsCols('ww', wwColumns, AppTheme.catBlue, wwWeight),
                ...buildHpsCols('pt', ptColumns, AppTheme.catGreen, ptWeight),
                ...buildHpsCols('ex', exColumns, AppTheme.catOrange, exWeight),
                _computedCell(computedW, '', hpsBg, cellText, borderColor),
                _computedCell(computedW, '', hpsBg, cellText, borderColor),
              ],
      ),
    );
  }

  Widget _buildHpsCell(
    String category,
    int col,
    double width,
    Color bg,
    Color text,
    Color border,
  ) {
    final val = _getHps(category, col);
    return Container(
      width: width,
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: border, width: 0.5)),
      ),
      child: Center(
        child: SizedBox(
          width: width - 8,
          child: TextField(
            controller: TextEditingController(
              text: val > 0 ? val.toStringAsFixed(0) : '',
            ),
            onSubmitted: (v) {
              final parsed = double.tryParse(v) ?? 0;
              _setHps(category, col, parsed);
            },
            onChanged: (v) {
              final parsed = double.tryParse(v) ?? 0;
              _setHps(category, col, parsed);
            },
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: text,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 4),
            ),
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // GENDER HEADER
  // ====================================================================
  Widget _buildGenderHeader(String label, Color bg, {bool isLeft = true}) {
    return Container(
      height: 24,
      width: isLeft ? 230.0 : _calculateTotalWidth() - 230.0,
      color: bg,
      padding: isLeft ? const EdgeInsets.only(left: 38) : null,
      alignment: isLeft ? Alignment.centerLeft : Alignment.center,
      child: Text(
        isLeft ? label : '',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // ====================================================================
  // STUDENT ROWS
  // ====================================================================
  List<Widget> _buildStudentRows(
    List<UserModel> students,
    ThemeData theme,
    bool isDark,
    Color cellText,
    Color borderColor,
    Color altRowBg,
    Color cellBg,
    double wwWeight,
    double ptWeight,
    double exWeight, {
    bool isLeft = true,
  }) {
    const colW = 48.0;
    const computedW = 56.0;
    const nameW = 200.0;
    const numW = 30.0;

    if (students.isEmpty) {
      return [
        Container(
          height: 36,
          width: isLeft ? 230.0 : _calculateTotalWidth() - 230.0,
          alignment: Alignment.centerLeft,
          padding: isLeft ? const EdgeInsets.only(left: 38) : null,
          decoration: BoxDecoration(
            color: cellBg,
            border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
          ),
          child: Text(
            isLeft ? 'No students enrolled' : '',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: cellText.withValues(alpha: 0.4),
            ),
          ),
        ),
      ];
    }

    return List.generate(students.length, (idx) {
      final s = students[idx];
      final isAlt = idx.isOdd;
      final rowBg = isAlt ? altRowBg : cellBg;

      final ig = _initialGrade(s.id);
      final tg = _transmutedGrade(ig);

      List<Widget> buildScoreCells(String category, int count, Color accent) {
        final cells = <Widget>[];
        for (int i = 0; i < count; i++) {
          cells.add(
            _buildScoreCell(
              s.id,
              category,
              i,
              colW,
              rowBg,
              cellText,
              borderColor,
            ),
          );
        }
        if (category == 'ex') {
          // Exam component WS values will come from Classroom Setup.
          for (int i = 0; i < count; i++) {
            cells.add(_computedCell(computedW, '', rowBg, accent, borderColor));
          }
        } else {
          final total = _totalRaw(s.id, category, count);
          cells.add(
            _computedCell(
              computedW,
              total > 0 ? total.toStringAsFixed(0) : '',
              rowBg,
              cellText,
              borderColor,
              isBold: true,
            ),
          );
        }
        // PS
        final ps = _percentageScore(s.id, category, count);
        cells.add(
          _computedCell(
            computedW,
            ps > 0 ? ps.toStringAsFixed(0) : '',
            rowBg,
            accent,
            borderColor,
            isBold: true,
          ),
        );
        // WS
        double weight = category == 'ww'
            ? wwWeight
            : (category == 'pt' ? ptWeight : exWeight);
        final ws = _weightedScore(s.id, category, count, weight);
        cells.add(
          _computedCell(
            computedW,
            ws > 0 ? ws.toStringAsFixed(1) : '',
            rowBg,
            accent,
            borderColor,
            isBold: true,
          ),
        );
        return cells;
      }

      return Container(
        height: 32,
        decoration: BoxDecoration(
          color: rowBg,
          border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
        ),
        child: Row(
          children: isLeft
              ? [
                  // Row number
                  Container(
                    width: numW,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: borderColor, width: 0.5),
                      ),
                    ),
                    child: Text(
                      '${idx + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: cellText.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  // Name
                  Container(
                    width: nameW,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: borderColor, width: 0.5),
                      ),
                    ),
                    child: Text(
                      _displayName(s),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cellText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]
              : [
                  // WW scores
                  ...buildScoreCells('ww', wwColumns, AppTheme.catBlue),
                  // PT scores
                  ...buildScoreCells('pt', ptColumns, AppTheme.catGreen),
                  // EX scores
                  ...buildScoreCells('ex', exColumns, AppTheme.catOrange),
                  // Initial Grade
                  _computedCell(
                    computedW,
                    ig > 0 ? ig.toStringAsFixed(1) : '',
                    rowBg,
                    cellText,
                    borderColor,
                    isBold: true,
                  ),
                  // Term Grade (Transmuted)
                  _computedCell(
                    computedW,
                    ig > 0 ? tg.toStringAsFixed(0) : '',
                    rowBg,
                    tg >= 75
                        ? AppTheme.catGreen
                        : (ig > 0 ? AppTheme.catRed : cellText),
                    borderColor,
                    isBold: true,
                    fontSize: 13,
                  ),
                ],
        ),
      );
    });
  }

  Widget _buildScoreCell(
    String studentId,
    String category,
    int col,
    double width,
    Color bg,
    Color text,
    Color border,
  ) {
    final val = _getScore(studentId, category, col);
    return Container(
      width: width,
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: border, width: 0.5)),
      ),
      child: Center(
        child: SizedBox(
          width: width - 8,
          child: TextField(
            controller: TextEditingController(
              text: val > 0 ? val.toStringAsFixed(0) : '',
            ),
            onChanged: (v) {
              final parsed = double.tryParse(v) ?? 0;
              _setScore(studentId, category, col, parsed);
            },
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(fontSize: 11, color: text),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _computedCell(
    double width,
    String value,
    Color bg,
    Color text,
    Color border, {
    bool isBold = false,
    double fontSize = 11,
  }) {
    return Container(
      width: width,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: border, width: 0.5)),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: text,
        ),
      ),
    );
  }

  // ====================================================================
  // TERM TABS (Bottom)
  // ====================================================================
  Widget _buildTermTabs(ThemeData theme, bool isDark, Color borderColor) {
    final tabs = [
      {'label': 'Term 1', 'color': AppTheme.catBlue},
      {'label': 'Term 2', 'color': AppTheme.catGreen},
      {'label': 'Term 3', 'color': AppTheme.catOrange},
      {'label': 'FINAL GRADES', 'color': AppTheme.catPurple},
    ];

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : const Color(0xFFF1F5F9),
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          ...tabs.asMap().entries.map((entry) {
            final i = entry.key;
            final tab = entry.value;
            final isSelected =
                (i < 3 && _selectedTerm == i + 1) ||
                (i == 3 && _selectedTerm == 0);

            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: () => setState(() => _selectedTerm = i < 3 ? i + 1 : 0),
                borderRadius: BorderRadius.circular(6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (tab['color'] as Color)
                        : (tab['color'] as Color).withValues(
                            alpha: isDark ? 0.15 : 0.1,
                          ),
                    borderRadius: BorderRadius.circular(6),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: (tab['color'] as Color).withValues(
                              alpha: 0.3,
                            ),
                          ),
                  ),
                  child: Text(
                    tab['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : (tab['color'] as Color)),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ====================================================================
  // TOTAL WIDTH CALC
  // ====================================================================
  double _calculateTotalWidth() {
    const colW = 48.0;
    const computedW = 56.0;
    const nameW = 200.0;
    const numW = 30.0;

    // EX has three component WS columns in addition to PS and overall WS.
    return numW +
        nameW +
        (wwColumns * colW + 3 * computedW) +
        (ptColumns * colW + 3 * computedW) +
        (exColumns * colW + (exColumns + 2) * computedW) +
        2 * computedW;
  }
}
