import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock_database.dart';
import '../../../widgets/common/app_modals.dart';

class StudentLearningMaterialsScreen extends StatelessWidget {
  const StudentLearningMaterialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final section =
        MockDatabase.instance.currentUser?.departmentOrSection ?? 'Section A';
    final materials = MockDatabase.instance.materialsForSection(section);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Materials'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: AppColors.background,
        child: materials.isEmpty
            ? const Center(child: Text('No learning materials shared yet.'))
            : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: materials.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final mat = materials[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
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
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getCategoryIcon(mat.category),
                            color: AppColors.primary,
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
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Uploaded: ${_formatDate(mat.uploadedAt)}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.file_download_outlined,
                          color: AppColors.textSecondary,
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
