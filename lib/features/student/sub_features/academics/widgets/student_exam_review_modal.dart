import 'package:flutter/material.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';

class StudentExamReviewModal extends StatefulWidget {
  final String assessmentId;
  final String title;
  final String subjectName;
  final double maxScore;

  const StudentExamReviewModal({
    super.key,
    required this.assessmentId,
    required this.title,
    required this.subjectName,
    required this.maxScore,
  });

  static Future<void> show(
    BuildContext context, {
    required String assessmentId,
    required String title,
    required String subjectName,
    required double maxScore,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => StudentExamReviewModal(
        assessmentId: assessmentId,
        title: title,
        subjectName: subjectName,
        maxScore: maxScore,
      ),
    );
  }

  @override
  State<StudentExamReviewModal> createState() => _StudentExamReviewModalState();
}

class _ReviewItem {
  final int position;
  final String
  questionType; // 'multiple_choice', 'true_false', 'identification'
  final String questionText;
  final double points;
  final String studentAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final double pointsEarned;
  final List<Map<String, dynamic>> options;

  _ReviewItem({
    required this.position,
    required this.questionType,
    required this.questionText,
    required this.points,
    required this.studentAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.pointsEarned,
    required this.options,
  });
}

class _StudentExamReviewModalState extends State<StudentExamReviewModal>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  double _totalScoreEarned = 0.0;
  List<_ReviewItem> _mcItems = [];
  List<_ReviewItem> _tfItems = [];
  List<_ReviewItem> _idItems = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReviewData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReviewData() async {
    try {
      final client = SupabaseService().client;
      final user = AuthRepository.instance.currentUser;
      final studentId = user?.id;

      if (studentId == null) {
        setState(() {
          _errorMessage = 'Student session not found.';
          _isLoading = false;
        });
        return;
      }

      // 1. Fetch latest attempt
      final attemptRes = await client
          .from('assessment_attempts')
          .select('id, score_earned, status, submitted_at')
          .eq('assessment_id', widget.assessmentId)
          .eq('student_id', studentId)
          .order('submitted_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (attemptRes == null) {
        setState(() {
          _errorMessage = 'No submitted assessment record found.';
          _isLoading = false;
        });
        return;
      }

      _totalScoreEarned =
          (attemptRes['score_earned'] as num?)?.toDouble() ?? 0.0;
      final attemptId = attemptRes['id'].toString();

      // 2. Fetch questions with options
      final questionsRes = await client
          .from('assessment_questions')
          .select('''
            id,
            position,
            question_type,
            question_text,
            points,
            assessment_question_options (
              id,
              position,
              option_text,
              is_correct
            )
          ''')
          .eq('assessment_id', widget.assessmentId)
          .order('position', ascending: true);

      final questionList = List<Map<String, dynamic>>.from(
        questionsRes as List? ?? [],
      );

      // 3. Fetch student's responses
      final responsesRes = await client
          .from('assessment_responses')
          .select(
            'question_id, selected_option_id, text_response, is_correct, points_earned',
          )
          .eq('attempt_id', attemptId);

      final responseList = List<Map<String, dynamic>>.from(
        responsesRes as List? ?? [],
      );
      final responseMap = <String, Map<String, dynamic>>{
        for (final r in responseList) r['question_id'].toString(): r,
      };

      final mc = <_ReviewItem>[];
      final tf = <_ReviewItem>[];
      final id = <_ReviewItem>[];

      for (int i = 0; i < questionList.length; i++) {
        final q = questionList[i];
        final qId = q['id'].toString();
        final qType = (q['question_type'] ?? '').toString().toLowerCase();
        final points = (q['points'] as num?)?.toDouble() ?? 1.0;
        final position = (q['position'] as num?)?.toInt() ?? (i + 1);
        final qText = q['question_text']?.toString() ?? '';

        final opts = (q['assessment_question_options'] as List? ?? [])
            .map((o) => Map<String, dynamic>.from(o as Map))
            .toList()
          ..sort(
            (a, b) => ((a['position'] as num?) ?? 0).compareTo(
              (b['position'] as num?) ?? 0,
            ),
          );

        String correctKey = '';
        if (qType == 'multiple_choice') {
          const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
          for (int idx = 0; idx < opts.length; idx++) {
            final pos = (opts[idx]['position'] as num?)?.toInt() ?? (idx + 1);
            final label = (pos >= 1 && pos <= letters.length)
                ? letters[pos - 1]
                : '$pos';
            opts[idx]['_derived_label'] = label;
            if (opts[idx]['is_correct'] == true) {
              correctKey =
                  '$label (${opts[idx]['option_text']?.toString() ?? ''})';
            }
          }
        } else if (qType == 'true_false') {
          for (int idx = 0; idx < opts.length; idx++) {
            if (opts[idx]['is_correct'] == true) {
              final text = opts[idx]['option_text']?.toString().trim() ?? '';
              final pos = (opts[idx]['position'] as num?)?.toInt() ?? (idx + 1);
              correctKey = text.isNotEmpty
                  ? text
                  : (pos == 1 ? 'True' : 'False');
            }
          }
        } else if (qType == 'identification') {
          final correctOpt = opts.firstWhere(
            (o) => o['is_correct'] == true,
            orElse: () => <String, dynamic>{},
          );
          correctKey = correctOpt['option_text']?.toString() ?? '';
        }

        final resp = responseMap[qId];
        final studentAns = resp?['text_response']?.toString() ?? '';
        final isCorrect = resp?['is_correct'] == true;
        final ptsEarned =
            (resp?['points_earned'] as num?)?.toDouble() ??
            (isCorrect ? points : 0.0);

        final item = _ReviewItem(
          position: position,
          questionType: qType,
          questionText: qText,
          points: points,
          studentAnswer: studentAns,
          correctAnswer: correctKey,
          isCorrect: isCorrect,
          pointsEarned: ptsEarned,
          options: opts,
        );

        if (qType == 'multiple_choice') {
          mc.add(item);
        } else if (qType == 'true_false') {
          tf.add(item);
        } else {
          id.add(item);
        }
      }

      if (mounted) {
        setState(() {
          _mcItems = mc;
          _tfItems = tf;
          _idItems = id;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load exam review: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F8A48).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fact_check_outlined,
                      color: Color(0xFF0F8A48),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${widget.subjectName} • Official Answer Key & Student Review',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F8A48).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF0F8A48).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Score: ${_totalScoreEarned.round()} / ${widget.maxScore.round()} pts',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF0F8A48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tab Bar for Categories
            Container(
              color: theme.colorScheme.surface,
              child: TabBar(
                controller: _tabController,
                indicatorColor: theme.colorScheme.primary,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.6,
                ),
                tabs: [
                  Tab(text: 'Multiple Choice (${_mcItems.length})'),
                  Tab(text: 'True or False (${_tfItems.length})'),
                  Tab(text: 'Identification (${_idItems.length})'),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: theme.colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildItemList(_mcItems),
                        _buildItemList(_tfItems),
                        _buildItemList(_idItems),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemList(List<_ReviewItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No questions in this category.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildQuestionCard(item);
      },
    );
  }

  Widget _buildQuestionCard(_ReviewItem item) {
    final theme = Theme.of(context);
    final borderColor = item.isCorrect
        ? const Color(0xFF0F8A48).withValues(alpha: 0.3)
        : const Color(0xFFDC2626).withValues(alpha: 0.3);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Header: Item # and Correct/Incorrect Badge
          Row(
            children: [
              Text(
                'Question #${item.position}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: item.isCorrect
                      ? const Color(0xFF0F8A48).withValues(alpha: 0.12)
                      : const Color(0xFFDC2626).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.isCorrect ? Icons.check_circle : Icons.cancel,
                      size: 15,
                      color: item.isCorrect
                          ? const Color(0xFF0F8A48)
                          : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item.isCorrect
                          ? 'Correct (+${item.points.round()} ${item.points.round() == 1 ? 'pt' : 'pts'})'
                          : 'Incorrect (0 pts)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: item.isCorrect
                            ? const Color(0xFF0F8A48)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.questionText,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),

          // Options breakdown for Multiple Choice
          if (item.questionType == 'multiple_choice' &&
              item.options.isNotEmpty) ...[
            ...item.options.asMap().entries.map((entry) {
              final opt = entry.value;
              const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
              final pos =
                  (opt['position'] as num?)?.toInt() ?? (entry.key + 1);
              final label =
                  opt['_derived_label']?.toString() ??
                  ((pos >= 1 && pos <= letters.length)
                      ? letters[pos - 1]
                      : '$pos');
              final text = opt['option_text']?.toString() ?? '';
              final isCorrectOpt = opt['is_correct'] == true;
              final isSelectedByStudent =
                  item.studentAnswer.trim().toUpperCase() ==
                      label.toUpperCase() ||
                  item.studentAnswer.trim().toLowerCase() ==
                      text.trim().toLowerCase();

              Color optBg = Colors.transparent;
              Color optBorder = theme.colorScheme.onSurface.withValues(
                alpha: 0.1,
              );
              if (isSelectedByStudent && isCorrectOpt) {
                optBg = const Color(0xFF0F8A48).withValues(alpha: 0.08);
                optBorder = const Color(0xFF0F8A48).withValues(alpha: 0.4);
              } else if (isSelectedByStudent && !isCorrectOpt) {
                optBg = const Color(0xFFDC2626).withValues(alpha: 0.08);
                optBorder = const Color(0xFFDC2626).withValues(alpha: 0.4);
              } else if (isCorrectOpt) {
                optBg = const Color(0xFF0F8A48).withValues(alpha: 0.06);
                optBorder = const Color(0xFF0F8A48).withValues(alpha: 0.3);
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: optBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: optBorder),
                ),
                child: Row(
                  children: [
                    Text(
                      '[$label] $text',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelectedByStudent || isCorrectOpt
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const Spacer(),
                    if (isSelectedByStudent)
                      Text(
                        '(Your Answer)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isCorrectOpt
                              ? const Color(0xFF0F8A48)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                    if (isCorrectOpt && !isSelectedByStudent)
                      const Text(
                        '★ Correct Key',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F8A48),
                        ),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
          ],

          // True/False & Identification specific summary box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.25,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Answer:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.studentAnswer.isNotEmpty
                            ? item.studentAnswer
                            : '(No answer given)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: item.isCorrect
                              ? const Color(0xFF0F8A48)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!item.isCorrect) ...[
                  const VerticalDivider(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Correct Answer Key:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F8A48),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.correctAnswer,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F8A48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
