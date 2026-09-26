import 'package:flutter/material.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/widgets/common/app_modals.dart';

class StudentLearningMaterialsScreen extends StatelessWidget {
  const StudentLearningMaterialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final section =
        MockDatabase.instance.currentUser?.departmentOrSection ?? 'Section A';
    final materials = MockDatabase.instance.materialsForSection(section);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Materials'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: materials.isEmpty
            ? const Center(child: Text('No learning materials shared yet.'))
            : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: materials.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final mat = materials[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
                  ),
                  child: InkWell(
                    onTap: () {
                      AppModals.showSuccessDialog(
                        context: context,
                        title: 'Material Preview',
                        message:
                            'Material: ${mat.title}\nTopic: ${mat.topic}\nFile: ${mat.fileName}\nSize: ${mat.fileSize}\n\nDownload is simulated for this prototype.',
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getCategoryIcon(mat.category),
                            color: theme.colorScheme.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mat.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${mat.category} • ${mat.fileSize}',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Uploaded: ${_formatDate(mat.uploadedAt)}',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.file_download_outlined,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final c = category.toLowerCase();
    if (c.contains('pdf')) return Icons.picture_as_pdf;
    if (c.contains('presentation') || c.contains('slide')) {
      return Icons.slideshow;
    }
    if (c.contains('video') || c.contains('link')) return Icons.link;
    if (c.contains('image')) return Icons.image;
    return Icons.description;
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
