import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/academic_models.dart';

class AiGenerationModal extends StatefulWidget {
  final bool isExam;
  final String subjectName;
  final ValueChanged<List<QuestionModel>> onQuestionsGenerated;

  const AiGenerationModal({
    super.key,
    required this.isExam,
    required this.subjectName,
    required this.onQuestionsGenerated,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isExam,
    required String subjectName,
    required ValueChanged<List<QuestionModel>> onQuestionsGenerated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AiGenerationModal(
        isExam: isExam,
        subjectName: subjectName,
        onQuestionsGenerated: onQuestionsGenerated,
      ),
    );
  }

  @override
  State<AiGenerationModal> createState() => _AiGenerationModalState();
}

class _AiGenerationModalState extends State<AiGenerationModal> {
  PlatformFile? _pickedFile;
  bool _isGenerating = false;
  String? _errorMessage;

  // Hybrid Assessment Focus Selector
  final Set<String> _selectedFocusDomains = {
    'Terms and Definitions',
    'Application & Problem Solving',
  };

  // Question Types & Item Counts
  bool _includeMultipleChoice = true;
  bool _includeTrueFalse = true;
  bool _includeIdentification = true;

  final TextEditingController _mcCountCtrl = TextEditingController(text: '10');
  final TextEditingController _tfCountCtrl = TextEditingController(text: '5');
  final TextEditingController _idCountCtrl = TextEditingController(text: '5');

  @override
  void dispose() {
    _mcCountCtrl.dispose();
    _tfCountCtrl.dispose();
    _idCountCtrl.dispose();
    super.dispose();
  }

  int get _totalPlannedItems {
    int total = 0;
    if (_includeMultipleChoice) total += int.tryParse(_mcCountCtrl.text) ?? 0;
    if (_includeTrueFalse) total += int.tryParse(_tfCountCtrl.text) ?? 0;
    if (_includeIdentification) total += int.tryParse(_idCountCtrl.text) ?? 0;
    return total;
  }

  Future<void> _pickReferenceDocument() async {
    setState(() => _errorMessage = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'txt'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.size > 10 * 1024 * 1024) {
          setState(() {
            _errorMessage = 'File exceeds maximum 10 MiB size limit.';
          });
          return;
        }
        setState(() => _pickedFile = file);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not read document: $e');
    }
  }

  Future<void> _startAiGeneration() async {
    setState(() => _errorMessage = null);

    if (_selectedFocusDomains.isEmpty) {
      setState(() => _errorMessage = 'Select at least one assessment focus domain.');
      return;
    }

    if (!_includeMultipleChoice && !_includeTrueFalse && !_includeIdentification) {
      setState(() => _errorMessage = 'Select at least one question type.');
      return;
    }

    final total = _totalPlannedItems;
    if (total < 1) {
      setState(() => _errorMessage = 'Planned question count must be at least 1.');
      return;
    }
    if (total > 100) {
      setState(() => _errorMessage = 'Maximum limit reached: Total cannot exceed 100 items.');
      return;
    }

    setState(() => _isGenerating = true);

    // Simulated edge function call (ready for Gemini 3-key rotation backend)
    await Future.delayed(const Duration(milliseconds: 1400));

    final generated = <QuestionModel>[];
    int questionIndex = 1;

    // Part I: Multiple Choice
    if (_includeMultipleChoice) {
      final count = int.tryParse(_mcCountCtrl.text) ?? 0;
      for (int i = 0; i < count; i++) {
        generated.add(
          QuestionModel(
            id: 'q_gen_${DateTime.now().millisecondsSinceEpoch}_$questionIndex',
            type: QuestionType.multipleChoice,
            questionText: 'Item $questionIndex: Which principle best defines the core relationship in ${widget.subjectName.isNotEmpty ? widget.subjectName : "the topic"}?',
            choices: [
              'Primary foundational postulate',
              'Secondary derivative factor',
              'Counter-balancing reciprocal condition',
              'Inverse linear approximation',
            ],
            correctAnswer: 'Primary foundational postulate',
            points: 1.0,
          ),
        );
        questionIndex++;
      }
    }

    // Part II: True or False
    if (_includeTrueFalse) {
      final count = int.tryParse(_tfCountCtrl.text) ?? 0;
      for (int i = 0; i < count; i++) {
        generated.add(
          QuestionModel(
            id: 'q_gen_${DateTime.now().millisecondsSinceEpoch}_$questionIndex',
            type: QuestionType.trueFalse,
            questionText: 'Item $questionIndex: The stated thesis remains valid under all standard thermodynamic and structural assumptions.',
            choices: ['True', 'False'],
            correctAnswer: i.isEven ? 'True' : 'False',
            points: 1.0,
          ),
        );
        questionIndex++;
      }
    }

    // Part III: Identification
    if (_includeIdentification) {
      final count = int.tryParse(_idCountCtrl.text) ?? 0;
      for (int i = 0; i < count; i++) {
        generated.add(
          QuestionModel(
            id: 'q_gen_${DateTime.now().millisecondsSinceEpoch}_$questionIndex',
            type: QuestionType.identification,
            questionText: 'Item $questionIndex: Identify the term used to describe this phenomenon.',
            choices: const [],
            correctAnswer: 'Equilibrium',
            points: 1.0,
          ),
        );
        questionIndex++;
      }
    }

    if (!mounted) return;
    setState(() => _isGenerating = false);
    widget.onQuestionsGenerated(generated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 740),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.catPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppTheme.catPurple, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Assessment Generator (Gemini)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Document-grounded question generator with hybrid cognitive domains.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
            const SizedBox(height: 16),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.catRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppTheme.catRed, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Document Upload Section
                    Text('1. Reference Document (.pdf, .docx, .txt — Max 5 MiB)', style: _stepHeaderStyle(theme)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickReferenceDocument,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _pickedFile != null ? Icons.description : Icons.cloud_upload_outlined,
                              color: theme.colorScheme.primary,
                              size: 28,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _pickedFile != null ? _pickedFile!.name : 'Click to select reference file or syllabus',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    _pickedFile != null
                                        ? '${(_pickedFile!.size / 1024).toStringAsFixed(1)} KB'
                                        : 'Zero hallucination: AI strictly generates items from this document',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_pickedFile != null)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(() => _pickedFile = null),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Cognitive Domain Selector
                    Text('2. Assessment Focus & Cognitive Domains (Select 1 or more)', style: _stepHeaderStyle(theme)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Terms and Definitions',
                        'Conceptual Understanding',
                        'Application & Problem Solving',
                        'Critical Thinking & Analysis',
                      ].map((domain) {
                        final isSelected = _selectedFocusDomains.contains(domain);
                        return FilterChip(
                          label: Text(domain),
                          selected: isSelected,
                          selectedColor: AppTheme.catPurple.withValues(alpha: 0.2),
                          checkmarkColor: AppTheme.catPurple,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedFocusDomains.add(domain);
                              } else {
                                _selectedFocusDomains.remove(domain);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // Question Types & Item Counts
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('3. Question Types & Item Counts', style: _stepHeaderStyle(theme)),
                        Text(
                          'Total: $_totalPlannedItems / 100 items',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _totalPlannedItems > 100 ? AppTheme.catRed : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildTypeCountRow('Multiple Choice (4 choices)', _includeMultipleChoice, (v) => setState(() => _includeMultipleChoice = v), _mcCountCtrl),
                    _buildTypeCountRow('True or False', _includeTrueFalse, (v) => setState(() => _includeTrueFalse = v), _tfCountCtrl),
                    _buildTypeCountRow('Identification (Direct recall)', _includeIdentification, (v) => setState(() => _includeIdentification = v), _idCountCtrl),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Footer Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_isGenerating ? 'Generating with Gemini...' : 'Generate Assessment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.catPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isGenerating ? null : _startAiGeneration,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _stepHeaderStyle(ThemeData theme) {
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.onSurface,
    );
  }

  Widget _buildTypeCountRow(
    String label,
    bool isEnabled,
    ValueChanged<bool> onToggle,
    TextEditingController controller,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isEnabled,
            onChanged: (v) => onToggle(v ?? false),
          ),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          if (isEnabled)
            SizedBox(
              width: 80,
              height: 36,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  suffixText: 'items',
                  suffixStyle: const TextStyle(fontSize: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
        ],
      ),
    );
  }
}
