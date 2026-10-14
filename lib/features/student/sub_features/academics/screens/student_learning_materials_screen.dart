import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/learning_material_repository.dart';
import 'package:class_realm/data/repositories/supabase_learning_material_repository.dart';
import 'package:class_realm/widgets/common/app_modals.dart';

class StudentLearningMaterialsScreen extends StatefulWidget {
  const StudentLearningMaterialsScreen({super.key});

  @override
  State<StudentLearningMaterialsScreen> createState() =>
      _StudentLearningMaterialsScreenState();
}

class _StudentLearningMaterialsScreenState
    extends State<StudentLearningMaterialsScreen> {
  final _materialRepo = SupabaseLearningMaterialRepository.instance;
  final _client = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _enrolledSubjects = [];
  Map<String, dynamic>? _selectedSubject;

  List<ClassRealmFolder> _folders = [];
  List<ClassRealmMaterial> _materials = [];
  ClassRealmFolder? _currentFolder;

  @override
  void initState() {
    super.initState();
    _loadStudentEnrolledClasses();
  }

  Future<void> _loadStudentEnrolledClasses() async {
    setState(() => _isLoading = true);
    final user = AuthRepository.instance.currentUser;

    if (user != null && user.id.isNotEmpty) {
      try {
        final enrollments = await _client
            .from('student_enrollments')
            .select('''
              subject_offering_id,
              subject_offerings (
                id,
                subjects ( id, subject_name, grade_level ),
                sections ( id, section_name, grade_level )
              )
            ''')
            .eq('student_id', user.id)
            .eq('status', 'enrolled');

        if ((enrollments as List).isNotEmpty) {
          final mapped = enrollments.map<Map<String, dynamic>>((e) {
            final offering = e['subject_offerings'] as Map<String, dynamic>? ?? {};
            final sub = offering['subjects'] as Map<String, dynamic>? ?? {};
            final sec = offering['sections'] as Map<String, dynamic>? ?? {};
            return {
              'offering_id': offering['id']?.toString() ?? e['subject_offering_id']?.toString() ?? '',
              'subject_name': sub['subject_name']?.toString() ?? 'Subject',
              'grade_level': sub['grade_level'] ?? sec['grade_level'] ?? 11,
              'section_name': sec['section_name']?.toString() ?? 'Section',
            };
          }).toList();

          if (mounted) {
            setState(() {
              _enrolledSubjects = mapped;
              _selectedSubject = mapped.first;
            });
            await _loadMaterialsForOffering();
            return;
          }
        }
      } catch (e) {
        debugPrint('Student learning materials cloud load fallback: $e');
      }
    }

    // No enrolled subjects found or error loading from cloud
    if (mounted) {
      setState(() {
        _enrolledSubjects = [];
        _selectedSubject = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMaterialsForOffering() async {
    if (_selectedSubject == null) return;
    final offeringId = _selectedSubject!['offering_id'] as String;

    setState(() => _isLoading = true);

    try {
      final folders = await _materialRepo.getFolders(
        subjectOfferingId: offeringId,
        parentFolderId: _currentFolder?.id,
      );

      // Filter only visible folders for student
      final visibleFolders = folders.where((f) => f.isVisibleToStudents).toList();

      List<ClassRealmMaterial> materials = [];
      if (_currentFolder != null) {
        materials = await _materialRepo.getMaterials(
          folderId: _currentFolder!.id,
          studentOnly: true, // Only fetch is_visible_to_students == true
        );
      }

      if (!mounted) return;
      setState(() {
        _folders = visibleFolders;
        _materials = materials;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _openFolder(ClassRealmFolder folder) {
    setState(() => _currentFolder = folder);
    _loadMaterialsForOffering();
  }

  void _goBackToRoot() {
    setState(() => _currentFolder = null);
    _loadMaterialsForOffering();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Materials'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject & Grade Header Bar
                _buildSubjectSelectorBar(theme),

                // Breadcrumb if inside folder
                if (_currentFolder != null) _buildBreadcrumbBar(theme),

                // Main Content List
                Expanded(
                  child: _folders.isEmpty && _materials.isEmpty
                      ? _buildEmptyState(theme)
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (_folders.isNotEmpty) ...[
                              Text(
                                'FOLDERS (${_folders.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._folders.map((f) => _buildFolderCard(f, theme)),
                              const SizedBox(height: 16),
                            ],
                            if (_materials.isNotEmpty) ...[
                              Text(
                                'DOCUMENTS (${_materials.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._materials.map((m) => _buildMaterialCard(m, theme)),
                            ],
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSubjectSelectorBar(ThemeData theme) {
    if (_selectedSubject == null) return const SizedBox.shrink();
    final activeGrade = _selectedSubject?['grade_level'] ?? 11;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          // Grade Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'GRADE $activeGrade',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Subject dropdown
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Map<String, dynamic>>(
                value: _selectedSubject,
                isExpanded: true,
                items: _enrolledSubjects.map((sub) {
                  final s = sub['subject_name'] ?? 'Subject';
                  final sec = sub['section_name'] ?? '';
                  return DropdownMenuItem(
                    value: sub,
                    child: Text(
                      '$s — Section $sec',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (newSub) {
                  if (newSub == null || newSub == _selectedSubject) return;
                  setState(() {
                    _selectedSubject = newSub;
                    _currentFolder = null;
                  });
                  _loadMaterialsForOffering();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(
        children: [
          InkWell(
            onTap: _goBackToRoot,
            child: const Row(
              children: [
                Icon(Icons.arrow_back, size: 16),
                SizedBox(width: 4),
                Text('All Folders', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _currentFolder!.folderName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderCard(ClassRealmFolder folder, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        leading: const Icon(Icons.folder, color: Colors.amber, size: 30),
        title: Text(folder.folderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('${folder.fileCount} materials available', style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => _openFolder(folder),
      ),
    );
  }

  Widget _buildMaterialCard(ClassRealmMaterial material, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showMaterialDetails(material),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getFormatColor(material.fileExtension).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getFormatIcon(material.fileExtension),
                  color: _getFormatColor(material.fileExtension),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${material.fileExtension} • ${material.formattedSize}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.file_download_outlined, color: Colors.teal),
            ],
          ),
        ),
      ),
    );
  }

  void _showMaterialDetails(ClassRealmMaterial material) {
    AppModals.showSuccessDialog(
      context: context,
      title: material.displayName,
      message:
          'Filename: ${material.fileName}\nFormat: ${material.fileExtension}\nSize: ${material.formattedSize}\n'
          '${material.description != null && material.description!.isNotEmpty ? "\nInstructions:\n${material.description}\n" : ""}\n'
          'Status: Shared by your Teacher.\nDirect document link prepared.',
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined, size: 56, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            const Text(
              'No Learning Materials Yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Your teacher hasn\'t published any documents in this folder yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFormatIcon(String ext) {
    final e = ext.toLowerCase();
    if (e == 'pdf') return Icons.picture_as_pdf;
    if (e == 'doc' || e == 'docx') return Icons.description;
    if (e == 'ppt' || e == 'pptx') return Icons.slideshow;
    if (e == 'xls' || e == 'xlsx') return Icons.table_chart;
    return Icons.insert_drive_file;
  }

  Color _getFormatColor(String ext) {
    final e = ext.toLowerCase();
    if (e == 'pdf') return Colors.red.shade600;
    if (e == 'doc' || e == 'docx') return Colors.blue.shade600;
    if (e == 'ppt' || e == 'pptx') return Colors.orange.shade700;
    if (e == 'xls' || e == 'xlsx') return Colors.green.shade700;
    return Colors.blueGrey;
  }
}
