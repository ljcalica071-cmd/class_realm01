import 'dart:async';

import 'package:flutter/material.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/utils/deped_grading_engine.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/supabase_student_repository.dart';
import 'package:class_realm/features/teacher/sub_features/grading/widgets/gradebook_grid_cell.dart';
import 'package:class_realm/models/subject_catalog_model.dart';
import 'package:class_realm/shared/widgets/shimmer_loading.dart';

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
  int _sheetLoadRequest = 0;
  String? _sheetLoadError;
  bool _isLoadingSheets = false;

  int _selectedTerm = 1;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int> _hpsRevision = ValueNotifier(0);
  final Map<String, ValueNotifier<int>> _studentRevisions = {};
  Timer? _sheetSaveTimer;

  final Map<int, Map<String, Map<int, double?>>> _termHps = {
    1: {'ww': {}, 'pt': {}, 'ex': {}},
    2: {'ww': {}, 'pt': {}, 'ex': {}},
    3: {'ww': {}, 'pt': {}, 'ex': {}},
  };
  final Map<int, Map<String, Map<String, Map<int, double?>>>> _termScores = {
    1: {},
    2: {},
    3: {},
  };

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
        onlyWithEnrolledStudents: true,
      );
      if (!mounted) return;
      final firstSubject = subjects.isEmpty ? null : subjects.first;
      setState(() {
        _teacherSubjects = subjects;
        _selectedSubject = firstSubject?['subject_name']?.toString();
        _selectedSection = firstSubject?['section_name']?.toString();
        _isLoadingSubjects = false;
        _studentLoadError = null;
        if (firstSubject != null) {
          final termsTaught = firstSubject['terms_taught'] is int
              ? firstSubject['terms_taught'] as int
              : int.tryParse(firstSubject['terms_taught']?.toString() ?? '') ?? 3;
          final termBlock =
              firstSubject['term_block']?.toString() ?? '1ST, 2ND, 3RD';
          final active = DepEdSubjectCatalog.getActiveTermsForBlock(
            termsTaught,
            termBlock,
          );
          if (_selectedTerm != 0 && !active.contains(_selectedTerm)) {
            _selectedTerm = active.isNotEmpty ? active.first : 1;
          }
        }
      });
      final subjectId = firstSubject?['id']?.toString();
      if (subjectId != null) {
        await Future.wait([
          _fetchStudents(user.id, subjectId),
          _loadOfferingSheets(subjectId),
        ]);
      }
    } catch (error) {
      debugPrint('Gradebook subjects load notice: $error');
      if (!mounted) return;
      setState(() {
        _teacherSubjects = [];
        _selectedSubject = null;
        _selectedSection = null;
        _isLoadingSubjects = false;
        _studentLoadError = null;
      });
    }
  }

  Future<void> _fetchStudents(String teacherId, String subjectId) async {
    final request = ++_studentLoadRequest;
    setState(() {
      _isLoadingStudents = true;
      _studentLoadError = null;
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
      debugPrint('Gradebook students load notice: $error');
      if (!mounted || request != _studentLoadRequest) return;
      setState(() {
        _students = [];
        _isLoadingStudents = false;
        _studentLoadError = 'Could not load learners for this subject.';
      });
    }
  }

  @override
  void dispose() {
    _sheetSaveTimer?.cancel();
    final offeringId = _currentSubjectData?['id']?.toString();
    if (offeringId != null && _selectedTerm > 0) {
      unawaited(
        _persistSheet(offeringId, _selectedTerm).catchError((Object error) {
          debugPrint('Gradebook save during dispose failed: $error');
        }),
      );
    }
    _hpsRevision.dispose();
    for (final revision in _studentRevisions.values) {
      revision.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

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

  ValueNotifier<int> _revisionFor(String studentId) =>
      _studentRevisions.putIfAbsent(studentId, () => ValueNotifier(0));

  double? _getScore(String studentId, String category, int col, {int? term}) {
    final selected = term ?? _selectedTerm;
    return _termScores[selected]?[studentId]?[category]?[col];
  }

  void _setScore(String studentId, String category, int col, double? value) {
    final term = _selectedTerm;
    final scores = _termScores[term]!;
    scores.putIfAbsent(studentId, () => {});
    scores[studentId]!.putIfAbsent(category, () => {});
    scores[studentId]![category]![col] = value;
    _revisionFor(studentId).value++;
    _scheduleSheetSave();
  }

  double? _getHps(String category, int col, {int? term}) {
    final selected = term ?? _selectedTerm;
    return _termHps[selected]?[category]?[col];
  }

  void _setHps(String category, int col, double? value) {
    final term = _selectedTerm;
    _termHps[term]![category]![col] = value;
    _hpsRevision.value++;
    _scheduleSheetSave();
  }

  void _scheduleSheetSave() {
    final offeringId = _currentSubjectData?['id']?.toString();
    final term = _selectedTerm;
    if (offeringId == null || term < 1 || term > 3) return;
    _sheetSaveTimer?.cancel();
    _sheetSaveTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(
        _persistSheet(offeringId, term).catchError((Object error) {
          debugPrint('Gradebook local save failed: $error');
        }),
      );
    });
  }

  static String _columnToKey(String category, int col) {
    if (category == 'ex') {
      if (col == 0) return 'st1';
      if (col == 1) return 'st2';
      if (col == 2) return 'te';
      return col.toString();
    }
    return '${col + 1}';
  }

  static int? _keyToColumnIndex(String category, dynamic rawKey, Map allValues) {
    final keyStr = rawKey.toString().toLowerCase().trim();
    if (category == 'ex') {
      if (keyStr == 'st1' || keyStr == 'ex1') return 0;
      if (keyStr == 'st2' || keyStr == 'ex2') return 1;
      if (keyStr == 'te' || keyStr == 'ex3') return 2;
      final parsed = int.tryParse(keyStr);
      if (parsed != null) {
        if (allValues.containsKey(0) || allValues.containsKey('0')) {
          if (parsed >= 0 && parsed < 3) return parsed;
        } else {
          if (parsed >= 1 && parsed <= 3) return parsed - 1;
          if (parsed == 0) return 0;
        }
      }
      return null;
    }

    final parsed = int.tryParse(keyStr);
    if (parsed == null) return null;
    if (allValues.containsKey(0) || allValues.containsKey('0')) {
      if (parsed >= 0 && parsed < 10) return parsed;
    } else {
      if (parsed >= 1 && parsed <= 10) return parsed - 1;
      if (parsed == 0) return 0;
    }
    return null;
  }

  Map<String, dynamic> _encodeSheet(int term) {
    final hps = <String, dynamic>{};
    for (final category in const ['ww', 'pt', 'ex']) {
      final catMap = <String, dynamic>{};
      final source = _termHps[term]?[category];
      if (source != null) {
        for (final entry in source.entries) {
          if (entry.value != null) {
            catMap[_columnToKey(category, entry.key)] = entry.value;
          }
        }
      }
      hps[category] = catMap;
    }
    final scores = <String, dynamic>{};
    final termScoreMap = _termScores[term];
    if (termScoreMap != null) {
      for (final student in termScoreMap.entries) {
        final studentMap = <String, dynamic>{};
        for (final category in student.value.entries) {
          final catMap = <String, dynamic>{};
          for (final entry in category.value.entries) {
            if (entry.value != null) {
              catMap[_columnToKey(category.key, entry.key)] = entry.value;
            }
          }
          studentMap[category.key] = catMap;
        }
        scores[student.key] = studentMap;
      }
    }
    return {'hps': hps, 'scores': scores};
  }

  Future<void> _persistSheet(String offeringId, int term) async {
    final payload = _encodeSheet(term);
    if (DepEdSubjectCatalog.getActiveTermsForBlock(
      _termsTaught,
      _termBlock,
    ).contains(term)) {
      payload['term_grades'] = [
        for (final student in _students)
          _buildPersistedTermGrade(student.id, term),
      ];
    }
    await SubjectRepository.instance.saveGradebookTermSheet(
      offeringId,
      term,
      payload,
    );
  }

  Map<String, dynamic> _buildPersistedTermGrade(String studentId, int term) {
    final initialGrade = _initialGrade(studentId, term: term);
    if (initialGrade == null) {
      return {
        'student_id': studentId,
        'initial_grade': 0,
        'transmuted_grade': 0,
        'remarks': 'Incomplete',
        'is_finalized': false,
      };
    }
    final termGrade = DepEdGradingEngine.transmuteDO15(initialGrade);
    return {
      'student_id': studentId,
      'initial_grade': initialGrade,
      'transmuted_grade': termGrade,
      'remarks': DepEdGradingEngine.getRemarks(termGrade),
      'is_finalized': false,
    };
  }

  Future<void> _loadOfferingSheets(String offeringId) async {
    final request = ++_sheetLoadRequest;
    setState(() {
      _isLoadingSheets = true;
      _sheetLoadError = null;
    });
    for (final term in const [1, 2, 3]) {
      for (final category in const ['ww', 'pt', 'ex']) {
        _termHps[term]![category]!.clear();
      }
      _termScores[term]!.clear();
    }
    try {
      final sheets = await Future.wait([
        for (final term in const [1, 2, 3])
          SubjectRepository.instance.getGradebookTermSheet(offeringId, term),
      ]);
      if (!mounted || request != _sheetLoadRequest) return;
      for (var index = 0; index < sheets.length; index++) {
        final sheet = sheets[index];
        if (sheet != null) _decodeSheet(index + 1, sheet);
      }
      _hpsRevision.value++;
      for (final studentId in _studentRevisions.keys) {
        _studentRevisions[studentId]!.value++;
      }
      setState(() {
        _isLoadingSheets = false;
        _sheetLoadError = null;
      });
    } catch (error) {
      debugPrint('Gradebook term sheets load notice: $error');
      if (!mounted || request != _sheetLoadRequest) return;
      setState(() {
        _isLoadingSheets = false;
        _sheetLoadError =
            'Could not load this offering’s saved gradebook data.';
      });
    }
  }

  void _decodeSheet(int term, Map<String, dynamic> sheet) {
    final rawHps = sheet['hps'] ?? sheet['hps_json'];
    final rawScores = sheet['scores'] ?? sheet['scores_json'];
    if (rawHps is! Map || rawScores is! Map) {
      return;
    }
    for (final category in const ['ww', 'pt', 'ex']) {
      final values = rawHps[category];
      if (values is! Map) continue;
      _termHps[term]![category]!.addAll(_decodeCategoryColumns(category, values));
    }
    for (final studentEntry in rawScores.entries) {
      if (studentEntry.value is! Map) continue;
      final studentScores = <String, Map<int, double?>>{};
      for (final categoryEntry in (studentEntry.value as Map).entries) {
        if (categoryEntry.value is! Map) continue;
        final catKey = categoryEntry.key.toString();
        studentScores[catKey] = _decodeCategoryColumns(
          catKey,
          categoryEntry.value as Map,
        );
      }
      _termScores[term]![studentEntry.key.toString()] = studentScores;
    }
  }

  Map<int, double?> _decodeCategoryColumns(String category, Map values) {
    final result = <int, double?>{};
    for (final entry in values.entries) {
      final colIndex = _keyToColumnIndex(category, entry.key, values);
      final value = entry.value;
      if (colIndex == null || (value != null && value is! num)) {
        continue;
      }
      result[colIndex] = (value as num?)?.toDouble();
    }
    return result;
  }

  Future<void> _changeTerm(int term) async {
    if (term == _selectedTerm) return;
    _sheetSaveTimer?.cancel();
    final offeringId = _currentSubjectData?['id']?.toString();
    try {
      if (offeringId != null && _selectedTerm > 0) {
        await _persistSheet(offeringId, _selectedTerm);
      }
    } catch (error) {
      debugPrint('Could not persist gradebook before changing terms: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this term sheet.')),
        );
      }
      return;
    }
    if (mounted) setState(() => _selectedTerm = term);
  }

  Future<void> _selectOffering(Map<String, dynamic> offering) async {
    _sheetSaveTimer?.cancel();
    final previousId = _currentSubjectData?['id']?.toString();
    try {
      if (previousId != null && _selectedTerm > 0) {
        await _persistSheet(previousId, _selectedTerm);
      }
    } catch (error) {
      debugPrint(
        'Could not persist gradebook before changing subjects: $error',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this term sheet.')),
        );
      }
      return;
    }
    final subjectName = offering['subject_name']?.toString();
    final sectionName = offering['section_name']?.toString();
    if (!mounted || subjectName == null || sectionName == null) return;
    setState(() {
      _selectedSubject = subjectName;
      _selectedSection = sectionName;
      final termsTaught = offering['terms_taught'] is int
          ? offering['terms_taught'] as int
          : int.tryParse(offering['terms_taught']?.toString() ?? '') ?? 3;
      final termBlock = offering['term_block']?.toString() ?? '1ST, 2ND, 3RD';
      final active = DepEdSubjectCatalog.getActiveTermsForBlock(
        termsTaught,
        termBlock,
      );
      if (_selectedTerm != 0 && !active.contains(_selectedTerm)) {
        _selectedTerm = active.isNotEmpty ? active.first : 1;
      }
    });
    final teacherId = AuthRepository.instance.currentUser?.id;
    final offeringId = offering['id']?.toString();
    if (teacherId != null && offeringId != null) {
      await Future.wait([
        _fetchStudents(teacherId, offeringId),
        _loadOfferingSheets(offeringId),
      ]);
    }
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

  double _parseWeight(dynamic val, {double fallback = 0}) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? fallback;
    return fallback;
  }

  int get _termsTaught {
    final data = _currentSubjectWeightsData;
    final value = data?['terms_taught'];
    return value is num ? value.toInt() : int.tryParse('$value') ?? 3;
  }

  String get _termBlock =>
      _currentSubjectWeightsData?['term_block']?.toString() ?? '1ST, 2ND, 3RD';

  double get _unitsPerTerm =>
      _parseWeight(_currentSubjectWeightsData?['units_per_term'], fallback: 2);

  double get _unitsPerYear => _unitsPerTerm * _termsTaught;

  List<int> get _activeTerms =>
      DepEdSubjectCatalog.getActiveTermsForBlock(_termsTaught, _termBlock);

  bool get _isSelectedTermActive =>
      _selectedTerm > 0 &&
      _currentSubjectData != null &&
      _activeTerms.contains(_selectedTerm);

  String _formatUnits(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  double _totalHps(String category, int count, {required int term}) {
    var total = 0.0;
    for (var index = 0; index < count; index++) {
      total += _getHps(category, index, term: term) ?? 0;
    }
    return total;
  }

  ComponentMetrics _componentMetrics(
    String studentId,
    String category,
    int count,
    double weight, {
    required int term,
  }) {
    return DepEdGradingEngine.computeComponentMetrics(
      hps: List.generate(
        count,
        (index) => _getHps(category, index, term: term),
      ),
      scores: List.generate(
        count,
        (index) => _getScore(studentId, category, index, term: term),
      ),
      componentWeight: weight,
    );
  }

  ExamMetrics _examMetrics(String studentId, {required int term}) {
    final data = _currentSubjectWeightsData;
    return DepEdGradingEngine.computeExamMetrics(
      hps: List.generate(
        exColumns,
        (index) => _getHps('ex', index, term: term),
      ),
      scores: List.generate(
        exColumns,
        (index) => _getScore(studentId, 'ex', index, term: term),
      ),
      examWeight: _parseWeight(data?['ex_weight']),
      subWeights: [
        _parseWeight(data?['st1_weight'], fallback: 30),
        _parseWeight(data?['st2_weight'], fallback: 30),
        _parseWeight(data?['te_weight'], fallback: 40),
      ],
    );
  }

  double? _initialGrade(String studentId, {required int term}) {
    final data = _currentSubjectWeightsData;
    final ww = _componentMetrics(
      studentId,
      'ww',
      wwColumns,
      _parseWeight(data?['ww_weight']),
      term: term,
    );
    final pt = _componentMetrics(
      studentId,
      'pt',
      ptColumns,
      _parseWeight(data?['pt_weight']),
      term: term,
    );
    final exWeight = _parseWeight(data?['ex_weight']);
    return DepEdGradingEngine.computeInitialGrade(
      wwWs: ww.ws,
      ptWs: pt.ws,
      exWs: _examMetrics(studentId, term: term).exWs,
      exWeight: exWeight,
    );
  }

  int? _termGrade(String studentId, int term) {
    if (!_activeTerms.contains(term)) return null;
    final initialGrade = _initialGrade(studentId, term: term);
    return initialGrade == null
        ? null
        : DepEdGradingEngine.transmuteDO15(initialGrade);
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

          if (_teacherSubjects.isEmpty || _students.isEmpty) ...[
            _buildNoStudentsBanner(theme, isDark),
            const SizedBox(height: 12),
          ],

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
                    child: (_isLoadingSubjects || (_isLoadingStudents && _students.isEmpty))
                        ? _buildGradebookSkeleton(theme, isDark, borderColor)
                        : Stack(
                            children: [
                              if (_selectedTerm == 0)
                                _buildFinalGradesView(theme, isDark, borderColor)
                              else
                                Column(
                                  children: [
                                    if (!_isSelectedTermActive)
                                      _buildInactiveTermBanner(theme),
                              if (_studentLoadError != null)
                                MaterialBanner(
                                  content: Text(_studentLoadError!),
                                  leading: Icon(
                                    Icons.people_outline,
                                    color: theme.colorScheme.error,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        final teacherId = AuthRepository
                                            .instance
                                            .currentUser
                                            ?.id;
                                        final offeringId =
                                            _currentSubjectData?['id']
                                                ?.toString();
                                        if (teacherId != null &&
                                            offeringId != null) {
                                          unawaited(
                                            _fetchStudents(
                                              teacherId,
                                              offeringId,
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              if (_sheetLoadError != null)
                                MaterialBanner(
                                  content: Text(_sheetLoadError!),
                                  leading: Icon(
                                    Icons.error_outline,
                                    color: theme.colorScheme.error,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        final id = _currentSubjectData?['id']
                                            ?.toString();
                                        if (id != null) {
                                          unawaited(_loadOfferingSheets(id));
                                        }
                                      },
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            ValueListenableBuilder<int>(
                                              valueListenable: _hpsRevision,
                                              builder: (context, _, _) =>
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
                                            ),
                                            Container(
                                              height: 2,
                                              color: borderColor,
                                            ),
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
                                              width:
                                                  _calculateTotalWidth() -
                                                  230.0,
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
                                                  ValueListenableBuilder<int>(
                                                    valueListenable:
                                                        _hpsRevision,
                                                    builder: (context, _, _) =>
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
                              ),
                            ],
                          ),
                        if (_isLoadingSubjects ||
                            _isLoadingStudents ||
                            _isLoadingSheets)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              color: theme.colorScheme.primary,
                              backgroundColor: Colors.transparent,
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

  Widget _buildGradebookSkeleton(ThemeData theme, bool isDark, Color borderColor) {
    return ShimmerLoading(
      child: Column(
        children: [
          // Header Bar Skeleton
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
            child: Row(
              children: const [
                ShimmerBox(width: 200, height: 16, borderRadius: 4),
                Spacer(),
                ShimmerBox(width: 100, height: 14, borderRadius: 4),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),
          // Sub-headers Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
            child: Row(
              children: const [
                ShimmerBox(width: 180, height: 14, borderRadius: 4),
                SizedBox(width: 24),
                ShimmerBox(width: 140, height: 14, borderRadius: 4),
                SizedBox(width: 24),
                ShimmerBox(width: 140, height: 14, borderRadius: 4),
                SizedBox(width: 24),
                ShimmerBox(width: 120, height: 14, borderRadius: 4),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),
          // Skeleton Student Rows
          Expanded(
            child: ListView.separated(
              itemCount: 12,
              separatorBuilder: (_, _) => Divider(height: 1, color: borderColor.withValues(alpha: 0.5)),
              itemBuilder: (_, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: const [
                    ShimmerBox(width: 28, height: 12, borderRadius: 4),
                    SizedBox(width: 16),
                    ShimmerBox(width: 160, height: 14, borderRadius: 4),
                    SizedBox(width: 32),
                    ShimmerBox(width: 45, height: 14, borderRadius: 4),
                    SizedBox(width: 14),
                    ShimmerBox(width: 45, height: 14, borderRadius: 4),
                    SizedBox(width: 14),
                    ShimmerBox(width: 45, height: 14, borderRadius: 4),
                    SizedBox(width: 32),
                    ShimmerBox(width: 45, height: 14, borderRadius: 4),
                    SizedBox(width: 14),
                    ShimmerBox(width: 45, height: 14, borderRadius: 4),
                    Spacer(),
                    ShimmerBox(width: 60, height: 16, borderRadius: 6),
                  ],
                ),
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
                if (val == null) return;
                final selectedRow = _teacherSubjects.firstWhere(
                  (subject) => subject['subject_name'] == val,
                );
                unawaited(_selectOffering(selectedRow));
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
              items: (_selectedSubject == null
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
                if (val == null) return;
                final selectedRow = _teacherSubjects.firstWhere(
                  (subject) =>
                      subject['subject_name'] == _selectedSubject &&
                      subject['section_name'] == val,
                );
                unawaited(_selectOffering(selectedRow));
              },
            ),
          ),
        ),
        const Spacer(),
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
                  sub ?? 'No subject yet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: text,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sec != null ? 'Section: $sec' : 'No section yet',
                  style: TextStyle(
                    fontSize: 12,
                    color: text.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          // Right: School Year
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.catGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppTheme.catGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'S.Y.: ',
                  style: TextStyle(
                    fontSize: 11,
                    color: text.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  '${data?['school_year'] ?? '2026-2027'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveTermBanner(ThemeData theme) {
    final activeTerm = _activeTerms.isEmpty ? 1 : _activeTerms.first;
    return Material(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.75),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'INCORRECT SHEET. Do not use this sheet to input data. This subject is configured for $_termBlock only.',
                style: TextStyle(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            TextButton(
              onPressed: () => unawaited(_changeTerm(activeTerm)),
              child: const Text('Switch to Active Term'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoStudentsBanner(ThemeData theme, bool isDark) {
    final bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);
    final border = isDark
        ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
        : const Color(0xFFBFDBFE);
    final iconColor = const Color(0xFF3B82F6);
    final textColor = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Note: You currently have no subjects with enrolled students. Once you enroll students into a subject and section, they will appear in the dropdowns and you can begin recording scores here.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalGradesView(
    ThemeData theme,
    bool isDark,
    Color borderColor,
  ) {
    final headerColor = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : const Color(0xFFE8EDF5);
    final activeTermsList = _activeTerms.isEmpty ? const [1] : _activeTerms;
    final termCount = activeTermsList.length;
    final minTableWidth = 740.0 + (termCount * 100.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final tableWidth = availableWidth > minTableWidth
            ? availableWidth
            : minTableWidth;
        final extraWidth = tableWidth - minTableWidth;

        final numW = 40.0;
        final lrnW = 130.0;
        const termW = 100.0;
        final totalTermsW = termW * termCount;
        final finalGradeW = 105.0;
        final nameW = 260.0 + (extraWidth * 0.55);
        final descriptorW = 145.0 + (extraWidth * 0.25);
        final remarkW = tableWidth -
            (numW +
                lrnW +
                nameW +
                totalTermsW +
                finalGradeW +
                descriptorW);

        final widths = [
          numW,
          lrnW,
          nameW,
          for (int i = 0; i < termCount; i++) termW,
          finalGradeW,
          descriptorW,
          remarkW,
        ];

        Widget headerCell(String label, double width, double height) =>
            Container(
              width: width,
              height: height,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: borderColor, width: 0.5),
                ),
              ),
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: 0.4,
                ),
              ),
            );

        Widget buildTwoTierHeader() => Container(
              height: 52,
              decoration: BoxDecoration(
                color: headerColor,
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  headerCell('#', numW, 52),
                  headerCell('LRN', lrnW, 52),
                  headerCell("LEARNERS' NAMES", nameW, 52),
                  SizedBox(
                    width: totalTermsW,
                    height: 52,
                    child: Column(
                      children: [
                        Container(
                          height: 26,
                          width: totalTermsW,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              right:
                                  BorderSide(color: borderColor, width: 0.5),
                              bottom:
                                  BorderSide(color: borderColor, width: 0.5),
                            ),
                          ),
                          child: Text(
                            'TERM GRADES',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 26,
                          child: Row(
                            children: [
                              for (final term in activeTermsList)
                                headerCell(
                                  term == 1
                                      ? 'FIRST TERM'
                                      : (term == 2
                                          ? 'SECOND TERM'
                                          : 'THIRD TERM'),
                                  termW,
                                  26,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  headerCell('FINAL GRADE', finalGradeW, 52),
                  headerCell('DESCRIPTOR', descriptorW, 52),
                  headerCell('REMARK', remarkW, 52),
                ],
              ),
            );

        Widget genderHeader(String label) => Container(
              height: 26,
              width: tableWidth,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 12),
              color: isDark
                  ? const Color(0xFF374151)
                  : const Color(0xFF334155),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            );

        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildTwoTierHeader(),
                  genderHeader('MALE'),
                  if (_maleStudents.isEmpty)
                    ..._buildFinalGradeEmptyRows(widths, borderColor, theme)
                  else
                    ..._maleStudents.asMap().entries.map(
                          (entry) => _buildFinalGradeStudentRow(
                            entry.value,
                            entry.key + 1,
                            widths,
                            borderColor,
                            theme,
                          ),
                        ),
                  genderHeader('FEMALE'),
                  if (_femaleStudents.isEmpty)
                    ..._buildFinalGradeEmptyRows(widths, borderColor, theme)
                  else
                    ..._femaleStudents.asMap().entries.map(
                          (entry) => _buildFinalGradeStudentRow(
                            entry.value,
                            entry.key + 1,
                            widths,
                            borderColor,
                            theme,
                          ),
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFinalGradeStudentRow(
    UserModel student,
    int rowNumber,
    List<double> widths,
    Color borderColor,
    ThemeData theme,
  ) {
    return AnimatedBuilder(
      animation: Listenable.merge([_revisionFor(student.id), _hpsRevision]),
      builder: (context, _) {
        final activeTermsList = _activeTerms.isEmpty ? const [1] : _activeTerms;
        final termCount = activeTermsList.length;
        final termGrades = {
          for (final term in activeTermsList)
            term: _termGrade(student.id, term),
        };
        final finalGrade = DepEdGradingEngine.computeFinalGrade(
          termsTaught: _termsTaught,
          activeTerms: activeTermsList,
          termGrades: termGrades,
          unitsPerTerm: _unitsPerTerm,
          totalUnitsEarned: _unitsPerYear,
        );
        final values = <String>[
          '$rowNumber',
          student.lrn ?? '-',
          _displayName(student),
          for (final term in activeTermsList)
            termGrades[term]?.toString() ?? '',
          finalGrade?.toString() ?? '',
          finalGrade == null
              ? ''
              : DepEdGradingEngine.getDescriptor(finalGrade),
          finalGrade == null ? '' : DepEdGradingEngine.getRemarks(finalGrade),
        ];
        final isDark = theme.brightness == Brightness.dark;
        final rowBackground = rowNumber.isOdd
            ? (isDark
                  ? theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    )
                  : const Color(0xFFF8FAFC))
            : theme.colorScheme.surface;

        final finalGradeIndex = 3 + termCount;
        final descriptorIndex = finalGradeIndex + 1;
        final remarkIndex = finalGradeIndex + 2;

        return Container(
          height: 38,
          decoration: BoxDecoration(
            color: rowBackground,
            border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
          ),
          child: Row(
            children: List.generate(values.length, (index) {
              final isName = index == 2;
              final isFinalGrade = index == finalGradeIndex;
              final isRemark = index == remarkIndex;
              final textColor = theme.colorScheme.onSurface;

              return Container(
                width: widths[index],
                alignment: isName ? Alignment.centerLeft : Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: isName ? 10 : 4),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: borderColor, width: 0.5),
                  ),
                ),
                child: Text(
                  values[index],
                  style: TextStyle(
                    fontSize: isName ? 12 : 11,
                    fontWeight: (isFinalGrade || isRemark)
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: isName ? TextAlign.left : TextAlign.center,
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildFinalGradeEmptyRow(
    int rowNumber,
    String label,
    List<double> widths,
    Color borderColor,
    ThemeData theme,
  ) {
    final rowBackground = theme.colorScheme.surface;
    final textColor = theme.colorScheme.onSurface.withValues(alpha: 0.45);
    final activeTermsList = _activeTerms.isEmpty ? const [1] : _activeTerms;

    final values = [
      '$rowNumber',
      '-',
      label,
      for (int i = 0; i < activeTermsList.length; i++) '-',
      '-',
      '-',
      '-',
    ];

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: rowBackground,
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Row(
        children: List.generate(values.length, (index) {
          final isName = index == 2;
          return Container(
            width: widths[index],
            alignment: isName ? Alignment.centerLeft : Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: isName ? 10 : 4),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: borderColor, width: 0.5)),
            ),
            child: Text(
              values[index],
              style: TextStyle(
                fontSize: 11,
                fontStyle:
                    isName && label != '-' ? FontStyle.italic : FontStyle.normal,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _buildFinalGradeEmptyRows(
    List<double> widths,
    Color borderColor,
    ThemeData theme,
  ) {
    return [
      _buildFinalGradeEmptyRow(
        1,
        'No students yet',
        widths,
        borderColor,
        theme,
      ),
      _buildFinalGradeEmptyRow(2, '-', widths, borderColor, theme),
      _buildFinalGradeEmptyRow(3, '-', widths, borderColor, theme),
    ];
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
                  exW == 0 ? 'NO EXAM (EXs)' : 'EXAMINATIONS (EXs)',
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
          _buildHpsCell(
            category,
            i,
            colW,
            hpsBg,
            cellText,
            borderColor,
            isEnabled: _isSelectedTermActive,
          ),
        );
      }
      // Total HPS
      if (category == 'ex') {
        final examWeights = [
          _parseWeight(_currentSubjectData?['st1_weight'], fallback: 30),
          _parseWeight(_currentSubjectData?['st2_weight'], fallback: 30),
          _parseWeight(_currentSubjectData?['te_weight'], fallback: 40),
        ];
        for (final subWeight in examWeights) {
          cols.add(
            _computedCell(
              computedW,
              _formatUnits(subWeight),
              hpsBg,
              cellText,
              borderColor,
            ),
          );
        }
      } else {
        final totalHps = _totalHps(category, count, term: _selectedTerm);
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
    Color border, {
    required bool isEnabled,
  }) {
    final val = _getHps(category, col);
    final offeringId = _currentSubjectData?['id']?.toString() ?? 'no_offering';
    final hasStudents = _students.isNotEmpty;
    final enabled = isEnabled && hasStudents;
    return GradebookGridCell(
      key: ValueKey('hps-$offeringId-$_selectedTerm-$category-$col'),
      value: val?.toStringAsFixed(0) ?? '',
      onChanged: (value) =>
          _setHps(category, col, value.isEmpty ? null : double.parse(value)),
      isHpsCell: true,
      columnHps: null,
      isEnabled: enabled,
      width: width,
      backgroundColor: bg,
      borderColor: border,
      textColor: text,
      disabledTooltip: !hasStudents
          ? 'Enroll students into this subject and section to edit scores.'
          : 'This term is not active for the selected subject.',
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
      return List.generate(3, (idx) {
        final isFirst = idx == 0;
        final isAlt = idx.isOdd;
        final rowBg = isAlt ? altRowBg : cellBg;
        return Container(
          height: 32,
          decoration: BoxDecoration(
            color: rowBg,
            border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
          ),
          child: Row(
            children: isLeft
                ? [
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
                          color: cellText.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
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
                        isFirst ? 'No students yet' : '-',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: isFirst
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: cellText.withValues(
                            alpha: isFirst ? 0.45 : 0.2,
                          ),
                        ),
                      ),
                    ),
                  ]
                : [
                    ...List.generate(
                      wwColumns,
                      (_) => _emptyGridCell(colW, rowBg, borderColor, cellText),
                    ),
                    _emptyGridCell(computedW, rowBg, borderColor, cellText),
                    _emptyGridCell(computedW, rowBg, borderColor, cellText),
                    _emptyGridCell(computedW, rowBg, borderColor, cellText),
                    ...List.generate(
                      ptColumns,
                      (_) => _emptyGridCell(colW, rowBg, borderColor, cellText),
                    ),
                    _emptyGridCell(computedW, rowBg, borderColor, cellText),
                    _emptyGridCell(computedW, rowBg, borderColor, cellText),
                    _emptyGridCell(computedW, rowBg, borderColor, cellText),
                    ...List.generate(
                      exColumns,
                      (_) => _emptyGridCell(colW, rowBg, borderColor, cellText),
                    ),
                    ...List.generate(
                      exColumns,
                      (_) => _emptyGridCell(
                        computedW,
                        rowBg,
                        borderColor,
                        cellText,
                      ),
                    ),
                    _emptyGridCell(computedW, rowBg, borderColor, cellText),
                    _emptyGridCell(computedW, rowBg, borderColor, cellText),
                    _emptyGridCell(computedW, rowBg, borderColor, cellText),
                    _emptyGridCell(computedW, rowBg, borderColor, cellText),
                  ],
          ),
        );
      });
    }

    return List.generate(students.length, (idx) {
      final s = students[idx];
      return AnimatedBuilder(
        key: ValueKey('gradebook-row-${s.id}-$isLeft'),
        animation: Listenable.merge([_revisionFor(s.id), _hpsRevision]),
        builder: (context, _) {
          final rowBg = idx.isOdd ? altRowBg : cellBg;
          final ig = _initialGrade(s.id, term: _selectedTerm);
          final tg = ig == null ? null : DepEdGradingEngine.transmuteDO15(ig);

          List<Widget> buildScoreCells(
            String category,
            int count,
            Color accent,
          ) {
            final cells = <Widget>[];
            for (var i = 0; i < count; i++) {
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
              final exam = _examMetrics(s.id, term: _selectedTerm);
              for (final score in [exam.wsSt1, exam.wsSt2, exam.wsTe]) {
                cells.add(
                  _computedCell(
                    computedW,
                    score?.toStringAsFixed(2) ?? '',
                    rowBg,
                    accent,
                    borderColor,
                  ),
                );
              }
              cells.add(
                _computedCell(
                  computedW,
                  exam.exPs?.toStringAsFixed(2) ?? '',
                  rowBg,
                  accent,
                  borderColor,
                  isBold: true,
                ),
              );
              cells.add(
                _computedCell(
                  computedW,
                  exam.exWs?.toStringAsFixed(2) ?? '',
                  rowBg,
                  accent,
                  borderColor,
                  isBold: true,
                ),
              );
              return cells;
            }

            final weight = category == 'ww' ? wwWeight : ptWeight;
            final metrics = _componentMetrics(
              s.id,
              category,
              count,
              weight,
              term: _selectedTerm,
            );
            cells
              ..add(
                _computedCell(
                  computedW,
                  metrics.totalRaw?.toStringAsFixed(0) ?? '',
                  rowBg,
                  cellText,
                  borderColor,
                  isBold: true,
                ),
              )
              ..add(
                _computedCell(
                  computedW,
                  metrics.ps?.toStringAsFixed(2) ?? '',
                  rowBg,
                  accent,
                  borderColor,
                  isBold: true,
                ),
              )
              ..add(
                _computedCell(
                  computedW,
                  metrics.ws?.toStringAsFixed(2) ?? '',
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
              border: Border(
                bottom: BorderSide(color: borderColor, width: 0.5),
              ),
            ),
            child: Row(
              children: isLeft
                  ? [
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
                      ...buildScoreCells('ww', wwColumns, AppTheme.catBlue),
                      ...buildScoreCells('pt', ptColumns, AppTheme.catGreen),
                      ...buildScoreCells('ex', exColumns, AppTheme.catOrange),
                      _computedCell(
                        computedW,
                        ig?.toStringAsFixed(2) ?? '',
                        rowBg,
                        cellText,
                        borderColor,
                        isBold: true,
                      ),
                      _computedCell(
                        computedW,
                        tg?.toString() ?? '',
                        rowBg,
                        tg != null
                            ? (tg >= 75 ? AppTheme.catGreen : AppTheme.catRed)
                            : cellText,
                        borderColor,
                        isBold: true,
                        fontSize: 13,
                      ),
                    ],
            ),
          );
        },
      );
    });
  }

  Widget _emptyGridCell(double width, Color bg, Color border, Color text) {
    return Container(
      width: width,
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: border, width: 0.5)),
      ),
      alignment: Alignment.center,
      child: Text(
        '-',
        style: TextStyle(fontSize: 11, color: text.withValues(alpha: 0.2)),
      ),
    );
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
    final hps = _getHps(category, col);
    final invalidValue = val != null && (hps == null || val > hps);
    final hasStudents = _students.isNotEmpty;
    final enabled =
        _isSelectedTermActive && hps != null && hps > 0 && hasStudents;
    final offeringId = _currentSubjectData?['id']?.toString() ?? 'no_offering';
    return GradebookGridCell(
      key: ValueKey('score-$offeringId-$_selectedTerm-$studentId-$category-$col'),
      value: val?.toStringAsFixed(0) ?? '',
      onChanged: (value) => _setScore(
        studentId,
        category,
        col,
        value.isEmpty ? null : double.parse(value),
      ),
      isHpsCell: false,
      columnHps: hps,
      isEnabled: enabled,
      isInvalidValue: invalidValue,
      width: width,
      backgroundColor: bg,
      borderColor: border,
      textColor: val == 0 ? AppTheme.catRed : text,
      disabledTooltip: !hasStudents
          ? 'Enroll students into this subject and section to edit scores.'
          : !_isSelectedTermActive
              ? 'This term is not active for the selected subject.'
              : 'Set Highest Possible Score (HPS) for this column first.',
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
    final allTermTabs = [
      {'term': 1, 'label': 'Term 1', 'color': AppTheme.catBlue},
      {'term': 2, 'label': 'Term 2', 'color': AppTheme.catGreen},
      {'term': 3, 'label': 'Term 3', 'color': AppTheme.catOrange},
    ];

    final activeTermsList = _activeTerms.isEmpty ? const [1] : _activeTerms;
    final tabs = [
      ...allTermTabs.where((t) => activeTermsList.contains(t['term'] as int)),
      {'term': 0, 'label': 'FINAL GRADES', 'color': AppTheme.catPurple},
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
          ...tabs.map((tab) {
            final term = tab['term'] as int;
            final isSelected = _selectedTerm == term;

            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: () => unawaited(_changeTerm(term)),
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
