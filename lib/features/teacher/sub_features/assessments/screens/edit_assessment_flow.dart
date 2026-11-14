import 'dart:async';
import 'package:flutter/material.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class EditAssessmentFlowDialog extends StatefulWidget {
  final QuizOrExamModel assessment;
  final FutureOr<void> Function() onAssessmentUpdated;

  const EditAssessmentFlowDialog({
    super.key,
    required this.assessment,
    required this.onAssessmentUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required QuizOrExamModel assessment,
    required FutureOr<void> Function() onAssessmentUpdated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditAssessmentFlowDialog(
        assessment: assessment,
        onAssessmentUpdated: onAssessmentUpdated,
      ),
    );
  }

  @override
  State<EditAssessmentFlowDialog> createState() =>
      _EditAssessmentFlowDialogState();
}

class _EditPlannedQuestion {
  final String id;
  int position;
  final QuestionType type;
  final int points;
  String questionText;
  List<String> choices;
  String correctAnswer;
  List<String> optionIds;

  _EditPlannedQuestion({
    required this.id,
    required this.position,
    required this.type,
    required this.points,
    required this.questionText,
    required this.choices,
    required this.correctAnswer,
    this.optionIds = const [],
  });

  bool get isComplete {
    if (questionText.trim().isEmpty) return false;
    if (type == QuestionType.multipleChoice) {
      if (choices.length < 4) return false;
      if (choices.any((c) => c.trim().isEmpty)) return false;
      if (correctAnswer.trim().isEmpty) return false;
      return true;
    } else if (type == QuestionType.trueFalse) {
      return correctAnswer.trim().isNotEmpty;
    } else if (type == QuestionType.identification) {
      final ans = correctAnswer.trim();
      return ans.length >= 2 && ans.length <= 50;
    }
    return true;
  }
}

class _EditAssessmentFlowDialogState extends State<EditAssessmentFlowDialog> {
  final List<_EditPlannedQuestion> _questions = [];
  final List<String> _deletedQuestionIds = [];
  int _activeQuestionIndex = 0;
  bool _isLoading = true;
  bool _isSaving = false;

  // Active question input controllers
  late final TextEditingController _statementCtrl;
  late final List<TextEditingController> _choiceCtrls;
  late final TextEditingController _qIdAnswerCtrl;
  String? _selectedMcqChoice;
  String? _selectedTfAnswer;

  // Inline error strings
  String? _statementError;
  String? _choicesError;
  String? _answerKeyError;
  String? _editorError;

  @override
  void initState() {
    super.initState();
    _statementCtrl = TextEditingController();
    _choiceCtrls = List.generate(4, (_) => TextEditingController());
    _qIdAnswerCtrl = TextEditingController();
    _loadQuestionsFromDb();
  }

  @override
  void dispose() {
    _statementCtrl.dispose();
    for (final c in _choiceCtrls) {
      c.dispose();
    }
    _qIdAnswerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuestionsFromDb() async {
    try {
      final client = SupabaseService().client;
      final questionsData = await client
          .from('assessment_questions')
          .select("""
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
          """)
          .eq('assessment_id', widget.assessment.id)
          .order('position', ascending: true);

      final questionRows = List<Map<String, dynamic>>.from(
        questionsData as List? ?? [],
      );

      _questions.clear();

      if (questionRows.isNotEmpty) {
        for (int i = 0; i < questionRows.length; i++) {
          final row = questionRows[i];
          final rawType = row['question_type']?.toString().toLowerCase() ?? '';
          QuestionType qType = QuestionType.multipleChoice;
          if (rawType.contains('true') || rawType.contains('tf')) {
            qType = QuestionType.trueFalse;
          } else if (rawType.contains('ident')) {
            qType = QuestionType.identification;
          }

          final rawOptions = List<Map<String, dynamic>>.from(
            row['assessment_question_options'] as List? ?? [],
          );
          rawOptions.sort(
            (a, b) => ((a['position'] as num?)?.toInt() ?? 0)
                .compareTo((b['position'] as num?)?.toInt() ?? 0),
          );

          final choices = <String>[];
          final optionIds = <String>[];
          String correctAnswer = '';

          for (final opt in rawOptions) {
            final optText = opt['option_text']?.toString() ?? '';
            final optId = opt['id']?.toString() ?? '';
            choices.add(optText);
            optionIds.add(optId);
            if (opt['is_correct'] == true) {
              correctAnswer = optText;
            }
          }

          _questions.add(
            _EditPlannedQuestion(
              id: row['id']?.toString() ?? '',
              position: (row['position'] as num?)?.toInt() ?? (i + 1),
              type: qType,
              points: (row['points'] as num?)?.toInt() ?? 1,
              questionText: row['question_text']?.toString() ?? '',
              choices: choices,
              correctAnswer: correctAnswer,
              optionIds: optionIds,
            ),
          );
        }
      } else {
        // Fallback to widget.assessment.questions
        for (int i = 0; i < widget.assessment.questions.length; i++) {
          final q = widget.assessment.questions[i];
          _questions.add(
            _EditPlannedQuestion(
              id: q.id,
              position: i + 1,
              type: q.type,
              points: q.points.toInt(),
              questionText: q.questionText,
              choices: List<String>.from(q.choices),
              correctAnswer: q.correctAnswer,
            ),
          );
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (_questions.isNotEmpty) {
          _loadQuestionIntoEditor(0);
        }
      }
    } catch (e) {
      debugPrint('Error loading questions for edit: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadQuestionIntoEditor(int index) {
    if (index < 0 || index >= _questions.length) return;
    final q = _questions[index];
    setState(() {
      _activeQuestionIndex = index;
      _statementCtrl.text = q.questionText;
      _statementError = null;
      _choicesError = null;
      _answerKeyError = null;
      _editorError = null;

      if (q.type == QuestionType.multipleChoice) {
        for (int i = 0; i < 4; i++) {
          _choiceCtrls[i].text = i < q.choices.length ? q.choices[i] : '';
        }
        _selectedMcqChoice = q.correctAnswer.isNotEmpty ? q.correctAnswer : null;
        _selectedTfAnswer = null;
        _qIdAnswerCtrl.clear();
      } else if (q.type == QuestionType.trueFalse) {
        for (final c in _choiceCtrls) {
          c.clear();
        }
        _selectedMcqChoice = null;
        _selectedTfAnswer = q.correctAnswer.isNotEmpty ? q.correctAnswer : null;
        _qIdAnswerCtrl.clear();
      } else if (q.type == QuestionType.identification) {
        for (final c in _choiceCtrls) {
          c.clear();
        }
        _selectedMcqChoice = null;
        _selectedTfAnswer = null;
        _qIdAnswerCtrl.text = q.correctAnswer;
      }
    });
  }

  bool _saveCurrentEditorState() {
    if (_activeQuestionIndex < 0 || _activeQuestionIndex >= _questions.length) {
      return true;
    }
    final q = _questions[_activeQuestionIndex];
    final statement = _statementCtrl.text.trim();

    if (statement.isEmpty) {
      setState(() => _statementError = 'Question statement is required.');
      return false;
    }
    if (statement.length > 500) {
      setState(
        () => _statementError = 'Statement must not exceed 500 characters.',
      );
      return false;
    }
    _statementError = null;

    if (q.type == QuestionType.multipleChoice) {
      final choices = _choiceCtrls.map((c) => c.text.trim()).toList();
      if (choices.any((c) => c.isEmpty)) {
        setState(
          () => _choicesError = 'All 4 multiple choice options must be filled.',
        );
        return false;
      }

      // Check duplicates
      final lower = choices.map((c) => c.toLowerCase()).toSet();
      if (lower.length < 4) {
        setState(() => _choicesError = 'Duplicate choices are not allowed.');
        return false;
      }
      _choicesError = null;

      if (_selectedMcqChoice == null || _selectedMcqChoice!.trim().isEmpty) {
        setState(
          () => _answerKeyError =
              'Select the radio corresponding to the correct answer.',
        );
        return false;
      }
      _answerKeyError = null;

      q.questionText = statement;
      q.choices = choices;
      q.correctAnswer = _selectedMcqChoice!;
    } else if (q.type == QuestionType.trueFalse) {
      if (_selectedTfAnswer == null || _selectedTfAnswer!.isEmpty) {
        setState(() => _answerKeyError = 'Select either True or False.');
        return false;
      }
      _answerKeyError = null;
      q.questionText = statement;
      q.choices = ['True', 'False'];
      q.correctAnswer = _selectedTfAnswer!;
    } else if (q.type == QuestionType.identification) {
      final ans = _qIdAnswerCtrl.text.trim();
      if (ans.length < 2 || ans.length > 50) {
        setState(
          () => _answerKeyError =
              'Correct answer must be between 2 and 50 characters.',
        );
        return false;
      }
      _answerKeyError = null;
      q.questionText = statement;
      q.choices = const [];
      q.correctAnswer = ans;
    }

    return true;
  }

  Future<void> _saveAllQuestionsToDb() async {
    if (_isSaving) return;
    if (!_saveCurrentEditorState()) return;

    // Validate that all questions are complete
    for (int i = 0; i < _questions.length; i++) {
      if (!_questions[i].isComplete) {
        _loadQuestionIntoEditor(i);
        setState(() {
          _editorError = 'Please complete Question ${i + 1} before saving.';
        });
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final client = SupabaseService().client;

      // Delete removed questions & options first
      for (final deletedId in _deletedQuestionIds) {
        if (deletedId.isEmpty) continue;
        await client
            .from('assessment_question_options')
            .delete()
            .eq('question_id', deletedId);
        await client.from('assessment_questions').delete().eq('id', deletedId);
      }

      for (final q in _questions) {
        // Update question statement and sequential position
        if (q.id.isNotEmpty) {
          await client
              .from('assessment_questions')
              .update({
                'question_text': q.questionText,
                'position': q.position,
              })
              .eq('id', q.id);

          // Update options
          if (q.type == QuestionType.multipleChoice) {
            for (int i = 0; i < q.choices.length; i++) {
              final choiceText = q.choices[i];
              final isCorrect = choiceText == q.correctAnswer;
              if (i < q.optionIds.length) {
                await client
                    .from('assessment_question_options')
                    .update({
                      'option_text': choiceText,
                      'is_correct': isCorrect,
                    })
                    .eq('id', q.optionIds[i]);
              }
            }
          } else if (q.type == QuestionType.trueFalse) {
            for (int i = 0; i < q.choices.length; i++) {
              final choiceText = q.choices[i];
              final isCorrect = choiceText == q.correctAnswer;
              if (i < q.optionIds.length) {
                await client
                    .from('assessment_question_options')
                    .update({
                      'option_text': choiceText,
                      'is_correct': isCorrect,
                    })
                    .eq('id', q.optionIds[i]);
              }
            }
          } else if (q.type == QuestionType.identification) {
            if (q.optionIds.isNotEmpty) {
              await client
                  .from('assessment_question_options')
                  .update({
                    'option_text': q.correctAnswer,
                    'is_correct': true,
                  })
                  .eq('id', q.optionIds.first);
            }
          }
        }
      }

      if (_deletedQuestionIds.isNotEmpty) {
        final totalPoints = _questions.fold<int>(0, (sum, q) => sum + q.points);
        await client
            .from('classwork_items')
            .update({'max_score': totalPoints})
            .eq('id', widget.assessment.id);
      }

      AppDataCache.instance.invalidatePrefix('teacher_assessments_');
      AppDataCache.instance.invalidatePrefix('student_dashboard_');
      await widget.onAssessmentUpdated();

      if (!mounted) return;
      AppTopToast.success(
        context,
        'Questions for "${widget.assessment.title}" updated.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Save questions error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        await AppModals.showErrorDialog(
          context: context,
          title: 'Save Failed',
          message:
              'We could not save your question updates right now. Please check your connection and try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 980,
        height: 680,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header (Red Document Icon + Title + Close X)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.catRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: AppTheme.catRed,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configure ${widget.assessment.isExam ? "Periodical Examination" : "Classroom Quiz"}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Question Builder — Author statements and mandatory answer keys',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            // Content Area
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _questions.isEmpty
                  ? Center(
                      child: Text(
                        'No questions found for this assessment.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Active Question Editor (Flex 6)
                        Expanded(
                          flex: 6,
                          child: Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.only(right: 20),
                                  child: _buildQuestionEditor(context),
                                ),
                              ),
                              _buildStepperButtons(context),
                            ],
                          ),
                        ),

                        // Vertical Divider
                        Container(
                          width: 1,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.1,
                          ),
                        ),

                        // Right Column: Question Navigator Matrix (Flex 4)
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: _buildQuestionNavigator(context),
                          ),
                        ),
                      ],
                    ),
            ),

            const Divider(height: 24),

            // Bottom Footer (Back / Cancel on left, Save Changes on right)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back to Details'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveAllQuestionsToDb,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(_isSaving ? 'Saving...' : 'Save & Update Questions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _deleteQuestionAt(int index) {
    if (_questions.length <= 1 || index < 0 || index >= _questions.length) {
      AppTopToast.warning(context, 'At least 1 question is required.');
      return;
    }
    final removed = _questions.removeAt(index);
    if (removed.id.isNotEmpty) {
      _deletedQuestionIds.add(removed.id);
    }
    for (int i = 0; i < _questions.length; i++) {
      _questions[i].position = i + 1;
    }
    final nextIndex = _activeQuestionIndex >= _questions.length
        ? _questions.length - 1
        : _activeQuestionIndex;
    setState(() {
      _activeQuestionIndex = nextIndex;
      _statementError = null;
      _choicesError = null;
      _answerKeyError = null;
      _editorError = null;
    });
    _loadQuestionIntoEditor(nextIndex);
  }

  Widget _buildQuestionEditor(BuildContext context) {
    if (_activeQuestionIndex < 0 || _activeQuestionIndex >= _questions.length) {
      return const SizedBox.shrink();
    }
    final q = _questions[_activeQuestionIndex];
    final theme = Theme.of(context);

    String typeLabel = 'MULTIPLE CHOICE';
    if (q.type == QuestionType.trueFalse) {
      typeLabel = 'TRUE OR FALSE';
    } else if (q.type == QuestionType.identification) {
      typeLabel = 'IDENTIFICATION';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Question Chip & Points
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Q${q.position}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Question ${q.position} of ${_questions.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: _questions.length > 1
                  ? () => _deleteQuestionAt(_activeQuestionIndex)
                  : null,
              icon: Icon(
                Icons.delete_outline,
                size: 15,
                color: _questions.length > 1
                    ? const Color(0xFFDC2626)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              label: Text(
                'Delete',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _questions.length > 1
                      ? const Color(0xFFDC2626)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: const Size(0, 32),
                side: BorderSide(
                  color: _questions.length > 1
                      ? const Color(0xFFDC2626).withValues(alpha: 0.4)
                      : theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Statement Header & Counter
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Question Statement *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              '${_statementCtrl.text.length} / 500',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Statement TextField
        TextField(
          controller: _statementCtrl,
          minLines: 3,
          maxLines: 6,
          maxLength: 500,
          keyboardType: TextInputType.multiline,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
              const SizedBox.shrink(),
          onChanged: (_) {
            q.questionText = _statementCtrl.text;
            setState(() {
              _statementError = null;
              _editorError = null;
            });
          },
          decoration: InputDecoration(
            hintText: 'Enter question text or problem statement...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: _statementError != null
                    ? const Color(0xFFDC2626)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: _statementError != null
                    ? const Color(0xFFDC2626)
                    : theme.colorScheme.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (_statementError != null) ...[
          const SizedBox(height: 4),
          Text(
            _statementError!,
            style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
          ),
        ],

        const SizedBox(height: 18),

        // Options & Answer Key Section
        if (q.type == QuestionType.multipleChoice) ...[
          Text(
            'Options & Answer Key (Fill all 4 and select the correct radio):',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < 4; i++) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Radio<String>(
                    value: _choiceCtrls[i].text.trim().isNotEmpty
                        ? _choiceCtrls[i].text.trim()
                        : 'option_$i',
                    groupValue: _selectedMcqChoice,
                    activeColor: theme.colorScheme.primary,
                    onChanged: (val) {
                      setState(() {
                        _selectedMcqChoice = _choiceCtrls[i].text.trim();
                        _answerKeyError = null;
                        _editorError = null;
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _choiceCtrls[i],
                      minLines: 1,
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                      onChanged: (val) {
                        setState(() {
                          _choicesError = null;
                          _editorError = null;
                        });
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Choice ${String.fromCharCode(65 + i)}',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _choicesError != null
                                ? const Color(0xFFDC2626)
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.2,
                                  ),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _choicesError != null
                                ? const Color(0xFFDC2626)
                                : theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_choicesError != null) ...[
            Text(
              _choicesError!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
            ),
            const SizedBox(height: 4),
          ],
          if (_answerKeyError != null) ...[
            Text(
              _answerKeyError!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
            ),
          ],
        ] else if (q.type == QuestionType.trueFalse) ...[
          Text(
            'Answer Key (Select the correct answer):',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() {
                    _selectedTfAnswer = 'True';
                    _answerKeyError = null;
                    _editorError = null;
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedTfAnswer == 'True'
                          ? theme.colorScheme.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedTfAnswer == 'True'
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Radio<String>(
                          value: 'True',
                          groupValue: _selectedTfAnswer,
                          activeColor: theme.colorScheme.primary,
                          onChanged: (val) => setState(() {
                            _selectedTfAnswer = val;
                            _answerKeyError = null;
                          }),
                        ),
                        const Text(
                          'True',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() {
                    _selectedTfAnswer = 'False';
                    _answerKeyError = null;
                    _editorError = null;
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedTfAnswer == 'False'
                          ? theme.colorScheme.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedTfAnswer == 'False'
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Radio<String>(
                          value: 'False',
                          groupValue: _selectedTfAnswer,
                          activeColor: theme.colorScheme.primary,
                          onChanged: (val) => setState(() {
                            _selectedTfAnswer = val;
                            _answerKeyError = null;
                          }),
                        ),
                        const Text(
                          'False',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_answerKeyError != null) ...[
            const SizedBox(height: 6),
            Text(
              _answerKeyError!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
            ),
          ],
        ] else if (q.type == QuestionType.identification) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Answer Key (Enter the exact correct answer):',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                '${_qIdAnswerCtrl.text.length} / 50 chars',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _qIdAnswerCtrl,
            maxLength: 50,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                const SizedBox.shrink(),
            onChanged: (val) => setState(() {
              _answerKeyError = null;
              _editorError = null;
            }),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Enter correct term or phrase (2-50 chars)...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: _answerKeyError != null
                      ? const Color(0xFFDC2626)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: _answerKeyError != null
                      ? const Color(0xFFDC2626)
                      : theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          if (_answerKeyError != null) ...[
            const SizedBox(height: 4),
            Text(
              _answerKeyError!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
            ),
          ],
        ],

        if (_editorError != null) ...[
          const SizedBox(height: 12),
          Text(
            _editorError!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFFDC2626),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepperButtons(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.only(right: 20, top: 12, bottom: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_activeQuestionIndex > 0)
            OutlinedButton.icon(
              onPressed: () {
                if (_saveCurrentEditorState()) {
                  _loadQuestionIntoEditor(_activeQuestionIndex - 1);
                }
              },
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Previous Question'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          if (_activeQuestionIndex < _questions.length - 1)
            ElevatedButton.icon(
              onPressed: () {
                if (_saveCurrentEditorState()) {
                  _loadQuestionIntoEditor(_activeQuestionIndex + 1);
                }
              },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Next Question'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                _saveCurrentEditorState();
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Review Complete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.catGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionNavigator(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question Navigator (${_questions.length} Items)',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Click any question number to edit or delete from the editor.',
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 14),

        // Grouped Categories
        Expanded(
          child: ListView(
            children: [
              _buildCategoryChips(
                'Multiple Choice',
                QuestionType.multipleChoice,
              ),
              const SizedBox(height: 12),
              _buildCategoryChips('True or False', QuestionType.trueFalse),
              const SizedBox(height: 12),
              _buildCategoryChips(
                'Identification',
                QuestionType.identification,
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildLegendItem('Done', AppTheme.catGreen),
            _buildLegendItem('Active', theme.colorScheme.primary),
            _buildLegendItem('Pending', Colors.grey),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryChips(String title, QuestionType type) {
    final categoryIndices = <int>[];
    for (int i = 0; i < _questions.length; i++) {
      if (_questions[i].type == type) {
        categoryIndices.add(i);
      }
    }
    if (categoryIndices.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: categoryIndices.map((idx) {
            final q = _questions[idx];
            final isActive = idx == _activeQuestionIndex;
            final isDone = q.isComplete;

            final Color chipBg = isActive
                ? theme.colorScheme.primary
                : (isDone
                    ? AppTheme.catGreen.withValues(alpha: 0.12)
                    : Colors.grey.shade200);

            final Color chipBorder = isActive
                ? theme.colorScheme.primary
                : (isDone ? AppTheme.catGreen : Colors.grey.shade300);

            final Color chipTextColor = isActive
                ? Colors.white
                : (isDone ? AppTheme.catGreen : Colors.black87);

            return InkWell(
              onTap: () {
                if (_saveCurrentEditorState()) {
                  _loadQuestionIntoEditor(idx);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: chipBorder,
                    width: isActive ? 2 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${q.position}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: chipTextColor,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
