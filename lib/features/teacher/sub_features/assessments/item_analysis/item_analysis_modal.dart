import 'package:flutter/material.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/item_analysis/item_difficulty_stat.dart';

class ItemAnalysisModal extends StatelessWidget {
  final String assessmentTitle;
  final List<ItemDifficultyStat> stats;

  const ItemAnalysisModal({
    super.key,
    required this.assessmentTitle,
    required this.stats,
  });

  static Future<void> show(
    BuildContext context, {
    required String assessmentTitle,
    required List<ItemDifficultyStat> stats,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ItemAnalysisModal(
        assessmentTitle: assessmentTitle,
        stats: stats,
      ),
    );
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
                Text(assessmentTitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        height: 420,
        child: stats.isEmpty
            ? const Center(
                child: Text('No student responses available yet to compute item analysis.', style: TextStyle(fontSize: 13, color: Colors.grey)),
              )
            : ListView.separated(
                itemCount: stats.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final item = stats[i];
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
                                '${item.correctCount} of ${item.totalAttempts} correct (${(item.pIndex * 100).toStringAsFixed(1)}%)',
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
