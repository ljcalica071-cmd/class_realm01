import 'package:flutter/material.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/item_analysis/item_difficulty_stat.dart';

class ItemAnalysisModal extends StatefulWidget {
  final String assessmentTitle;
  final List<ItemDifficultyStat> stats;
  final bool initialResultsReleased;
  final ValueChanged<bool>? onToggleRelease;

  const ItemAnalysisModal({
    super.key,
    required this.assessmentTitle,
    required this.stats,
    this.initialResultsReleased = false,
    this.onToggleRelease,
  });

  static Future<void> show(
    BuildContext context, {
    required String assessmentTitle,
    required List<ItemDifficultyStat> stats,
    bool initialResultsReleased = false,
    ValueChanged<bool>? onToggleRelease,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ItemAnalysisModal(
        assessmentTitle: assessmentTitle,
        stats: stats,
        initialResultsReleased: initialResultsReleased,
        onToggleRelease: onToggleRelease,
      ),
    );
  }

  @override
  State<ItemAnalysisModal> createState() => _ItemAnalysisModalState();
}

class _ItemAnalysisModalState extends State<ItemAnalysisModal> {
  late bool _resultsReleased;
  QuestionType? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _resultsReleased = widget.initialResultsReleased;
  }

  Color _badgeColor(String classification) {
    switch (classification) {
      case 'Very Easy':
        return Colors.blue;
      case 'Easy':
        return const Color(0xFF0F8A48);
      case 'Moderate / Ideal':
        return Colors.teal;
      case 'Difficult':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalItems = widget.stats.length;
    final avgP = totalItems > 0
        ? (widget.stats.fold<double>(0.0, (sum, s) => sum + s.pIndex) /
                  totalItems) *
              100
        : 0.0;

    const orderedCategories = [
      QuestionType.multipleChoice,
      QuestionType.trueFalse,
      QuestionType.identification,
      QuestionType.matching,
    ];

    final Map<QuestionType, List<ItemDifficultyStat>> groupedStats = {};
    final List<ItemDifficultyStat> otherItems = [];

    for (final s in widget.stats) {
      if (s.questionType != null && orderedCategories.contains(s.questionType)) {
        groupedStats.putIfAbsent(s.questionType!, () => []).add(s);
      } else {
        otherItems.add(s);
      }
    }

    for (final list in groupedStats.values) {
      list.sort((a, b) => a.itemNumber.compareTo(b.itemNumber));
    }
    otherItems.sort((a, b) => a.itemNumber.compareTo(b.itemNumber));

    final categoriesInStats =
        orderedCategories.where((c) => groupedStats.containsKey(c)).toList();
    final hasOther = otherItems.isNotEmpty;

    final categoriesToDisplay = _selectedCategory != null
        ? [_selectedCategory!]
        : categoriesInStats;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: Colors.indigo,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Item Analysis (DepEd Tiers)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                Text(
                  widget.assessmentTitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 650,
        height: 520,
        child: Column(
          children: [
            // Analytics Summary Bar & Release Switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildMetricChip('Total Items', '$totalItems', theme),
                          const SizedBox(width: 8),
                          _buildMetricChip(
                            'Mean Accuracy',
                            '${avgP.toStringAsFixed(1)}%',
                            theme,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'Release Answer Key to Students',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _resultsReleased
                                  ? const Color(0xFF0F8A48)
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Switch(
                            value: _resultsReleased,
                            activeThumbColor: const Color(0xFF0F8A48),
                            onChanged: (val) {
                              setState(() => _resultsReleased = val);
                              widget.onToggleRelease?.call(val);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (categoriesInStats.length > 1) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text('All ($totalItems)'),
                          selected: _selectedCategory == null,
                          onSelected: (_) => setState(() => _selectedCategory = null),
                        ),
                        ...categoriesInStats.map((cat) {
                          final count = groupedStats[cat]?.length ?? 0;
                          final label = switch (cat) {
                            QuestionType.multipleChoice => 'Multiple Choice',
                            QuestionType.trueFalse => 'True / False',
                            QuestionType.identification => 'Identification',
                            QuestionType.matching => 'Matching',
                          };
                          return ChoiceChip(
                            label: Text('$label ($count)'),
                            selected: _selectedCategory == cat,
                            onSelected: (_) => setState(() {
                              _selectedCategory =
                                  _selectedCategory == cat ? null : cat;
                            }),
                          );
                        }),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Item by Item Breakdown List
            Expanded(
              child: widget.stats.isEmpty
                  ? const Center(
                      child: Text(
                        'No student responses available yet to compute item analysis.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final cat in categoriesToDisplay) ...[
                          if (groupedStats[cat]?.isNotEmpty == true) ...[
                            _buildCategoryHeader(
                              theme: theme,
                              category: cat,
                              items: groupedStats[cat]!,
                              partIndex: categoriesInStats.indexOf(cat) + 1,
                            ),
                            const SizedBox(height: 4),
                            ...groupedStats[cat]!.map(
                              (item) => _buildItemRow(theme, isDark, item),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                        if (hasOther && (_selectedCategory == null)) ...[
                          _buildCategoryHeader(
                            theme: theme,
                            category: null,
                            items: otherItems,
                            partIndex: categoriesInStats.length + 1,
                          ),
                          const SizedBox(height: 4),
                          ...otherItems.map(
                            (item) => _buildItemRow(theme, isDark, item),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Okay'),
        ),
      ],
    );
  }

  Widget _buildCategoryHeader({
    required ThemeData theme,
    required QuestionType? category,
    required List<ItemDifficultyStat> items,
    required int partIndex,
  }) {
    final title = switch (category) {
      QuestionType.multipleChoice => 'PART ${_toRoman(partIndex)}: MULTIPLE CHOICE',
      QuestionType.trueFalse => 'PART ${_toRoman(partIndex)}: TRUE OR FALSE',
      QuestionType.identification => 'PART ${_toRoman(partIndex)}: IDENTIFICATION',
      QuestionType.matching => 'PART ${_toRoman(partIndex)}: MATCHING TYPE',
      null => 'PART ${_toRoman(partIndex)}: OTHER QUESTIONS',
    };

    final rangeText = items.isEmpty
        ? ''
        : (items.first.itemNumber == items.last.itemNumber
            ? 'Item ${items.first.itemNumber}'
            : 'Items ${items.first.itemNumber}–${items.last.itemNumber}');

    final catAvg = items.isNotEmpty
        ? (items.fold<double>(0.0, (sum, s) => sum + s.pIndex) / items.length) * 100
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${items.length} ${items.length == 1 ? 'Item' : 'Items'} • $rangeText)',
                style: TextStyle(
                  fontSize: 10.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          Text(
            'Avg: ${catAvg.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(ThemeData theme, bool isDark, ItemDifficultyStat item) {
    final color = _badgeColor(item.classification);
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 6,
        horizontal: 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              'Q${item.itemNumber}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.questionText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.correctCount} of ${item.totalAttempts} correct (${(item.pIndex * 100).toStringAsFixed(1)}% accuracy • P = ${item.pIndex.toStringAsFixed(2)})',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              item.classification,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _toRoman(int number) {
    return switch (number) {
      1 => 'I',
      2 => 'II',
      3 => 'III',
      4 => 'IV',
      5 => 'V',
      _ => '$number',
    };
  }

  Widget _buildMetricChip(String label, String value, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
