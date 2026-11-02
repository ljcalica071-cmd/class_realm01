import 'package:flutter/material.dart';
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
        ? (widget.stats.fold<double>(0.0, (sum, s) => sum + s.pIndex) / totalItems) * 100
        : 0.0;

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
            child: const Icon(Icons.analytics_outlined, color: Colors.indigo, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Item Analysis (DepEd Tiers)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                Text(widget.assessmentTitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 650,
        height: 480,
        child: Column(
          children: [
            // Analytics Summary Bar & Release Switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildMetricChip('Total Items', '$totalItems', theme),
                      const SizedBox(width: 8),
                      _buildMetricChip('Mean Accuracy', '${avgP.toStringAsFixed(1)}%', theme),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Release Answer Key to Students',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _resultsReleased ? const Color(0xFF0F8A48) : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Switch(
                        value: _resultsReleased,
                        activeColor: const Color(0xFF0F8A48),
                        onChanged: (val) {
                          setState(() => _resultsReleased = val);
                          widget.onToggleRelease?.call(val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Item by Item Breakdown List
            Expanded(
              child: widget.stats.isEmpty
                  ? const Center(
                      child: Text('No student responses available yet to compute item analysis.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    )
                  : ListView.separated(
                      itemCount: widget.stats.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final item = widget.stats[i];
                        final color = _badgeColor(item.classification);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  'Q${item.itemNumber}',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: theme.colorScheme.primary),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.questionText,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.correctCount} of ${item.totalAttempts} correct (${(item.pIndex * 100).toStringAsFixed(1)}% accuracy • P = ${item.pIndex.toStringAsFixed(2)})',
                                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: color.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  item.classification,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildMetricChip(String label, String value, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
