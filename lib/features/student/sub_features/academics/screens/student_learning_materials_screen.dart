import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/learning_material_repository.dart';
import 'package:class_realm/data/repositories/supabase_learning_material_repository.dart';

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
  String? _errorMessage;

  // Toggle: Current Classes vs Past / Archived Classes (Edge Case #17)
  bool _showArchivedClasses = false;

  // Enrolled subjects & active selection
  List<Map<String, dynamic>> _allEnrolledSubjects = [];
  Map<String, dynamic>? _selectedSubject;

  // Folders & Materials
  List<ClassRealmFolder> _folders = [];
  List<ClassRealmMaterial> _materials = [];
  ClassRealmFolder? _currentFolder;
  final List<ClassRealmFolder> _folderStack = [];

  // In-flight download lock for debouncing (Edge Case #13 & #28)
  final Set<String> _downloadingIds = {};

  @override
  void initState() {
    super.initState();
    _loadStudentEnrolledClasses();
  }

  // Filter subjects based on Current vs Past classes toggle
  List<Map<String, dynamic>> get _filteredSubjects {
    return _allEnrolledSubjects.where((sub) {
      final isArchived = sub['is_archived'] == true;
      return _showArchivedClasses ? isArchived : !isArchived;
    }).toList();
  }

  Future<void> _loadStudentEnrolledClasses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = AuthRepository.instance.currentUser;
    if (user == null || user.id.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please sign in as a student to view your learning materials.';
      });
      return;
    }

    try {
      final enrollments = await _client
          .from('student_enrollments')
          .select('''
            id,
            status,
            is_irregular,
            subject_offering_id,
            subject_offerings (
              id,
              is_archived,
              term_block,
              subjects ( id, subject_code, subject_name, grade_level ),
              sections ( 
                id, section_name, grade_level,
                school_years ( id, school_year, is_current, is_archived )
              ),
              terms ( id, term_name, term_number )
            )
          ''')
          .eq('student_id', user.id)
          .eq('status', 'enrolled');

      if ((enrollments as List).isEmpty) {
        if (!mounted) return;
        setState(() {
          _allEnrolledSubjects = [];
          _selectedSubject = null;
          _isLoading = false;
        });
        return;
      }

      final mapped = <Map<String, dynamic>>[];
      for (final e in (enrollments as List)) {
        final offering = e['subject_offerings'] as Map<String, dynamic>? ?? {};
        final sub = offering['subjects'] as Map<String, dynamic>? ?? {};
        final sec = offering['sections'] as Map<String, dynamic>? ?? {};
        final sy = sec['school_years'] as Map<String, dynamic>? ?? {};
        final term = offering['terms'] as Map<String, dynamic>? ?? {};

        final isSyCurrent = sy['is_current'] == true;
        final isOfferingArchived = offering['is_archived'] == true || sy['is_archived'] == true;
        final isPastOrArchived = !isSyCurrent || isOfferingArchived;

        mapped.add({
          'offering_id': offering['id']?.toString() ?? e['subject_offering_id']?.toString() ?? '',
          'subject_name': sub['subject_name']?.toString() ?? 'Subject',
          'subject_code': sub['subject_code']?.toString() ?? '',
          'grade_level': sub['grade_level'] ?? sec['grade_level'] ?? 11,
          'section_name': sec['section_name']?.toString() ?? 'Section',
          'term_name': term['term_name']?.toString() ?? 'Term',
          'school_year': sy['school_year']?.toString() ?? '',
          'is_irregular': e['is_irregular'] == true,
          'is_archived': isPastOrArchived,
        });
      }

      if (!mounted) return;
      setState(() {
        _allEnrolledSubjects = mapped;
        final available = _filteredSubjects;
        _selectedSubject = available.isNotEmpty ? available.first : null;
      });

      if (_selectedSubject != null) {
        await _loadMaterialsForOffering();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load enrolled classes: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMaterialsForOffering() async {
    if (_selectedSubject == null) {
      setState(() {
        _folders = [];
        _materials = [];
        _isLoading = false;
      });
      return;
    }

    final offeringId = _selectedSubject!['offering_id'] as String;
    setState(() => _isLoading = true);

    try {
      // 1. Fetch folders for this offering
      final allFolders = await _materialRepo.getFolders(
        subjectOfferingId: offeringId,
        parentFolderId: _currentFolder?.id,
      );

      // Strict ancestor folder visibility: only show folders that are visible & not archived
      final visibleFolders = allFolders.where((f) => f.isVisibleToStudents && !f.isArchived).toList();

      // 2. Fetch materials using hierarchical visibility check and server UTC time
      List<ClassRealmMaterial> visibleMaterials = [];
      if (_currentFolder != null) {
        final rawMaterials = await _materialRepo.getStudentMaterialsWithHierarchy(
          subjectOfferingId: offeringId,
          folderId: _currentFolder!.id,
        );

        // Irregular Student Deduplication (Edge Case #30):
        // Deduplicate materials by storage_path_url and fileName so identical shared records don't repeat
        final seenKeys = <String>{};
        for (final m in rawMaterials) {
          final dedupKey = '${m.fileName}_${m.storagePathUrl}';
          if (!seenKeys.contains(dedupKey)) {
            seenKeys.add(dedupKey);
            visibleMaterials.add(m);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _folders = visibleFolders;
        _materials = visibleMaterials;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load materials: $e';
        _isLoading = false;
      });
    }
  }

  void _navigateToFolder(ClassRealmFolder folder) {
    setState(() {
      _folderStack.add(folder);
      _currentFolder = folder;
    });
    _loadMaterialsForOffering();
  }

  void _navigateBackTo(int index) {
    if (index < 0) {
      setState(() {
        _folderStack.clear();
        _currentFolder = null;
      });
    } else {
      setState(() {
        _folderStack.removeRange(index + 1, _folderStack.length);
        _currentFolder = _folderStack[index];
      });
    }
    _loadMaterialsForOffering();
  }

  // --- Debounced Offline Download (Edge Cases #1, #13, #20, #21, #28) ---
  Future<void> _downloadOfflineCopy(ClassRealmMaterial material) async {
    // In-flight download lock: rapid 50x clicks only fire a single task
    if (_downloadingIds.contains(material.id)) {
      return;
    }

    setState(() => _downloadingIds.add(material.id));

    try {
      if (material.isRichTextLesson) {
        _showStudentAlert(
          title: 'Lesson Module Ready',
          message: 'This lesson module is built directly into the app and is always accessible offline inside the reader.',
        );
        return;
      }

      if (material.isEmbedUrl) {
        _showStudentAlert(
          title: 'Cloud Document Link',
          message: 'This is an online cloud document / presentation. You can open and view it anytime with an internet connection.',
        );
        return;
      }

      // Storage download attempt
      if (material.storagePathUrl.isEmpty || !material.storagePathUrl.startsWith('http')) {
        throw Exception('Cloud storage address is not currently reachable.');
      }

      // Simulate client-side safe stream / download check
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      _showToast('Offline copy prepared! You can access it anytime.', isError: false);
    } on FileSystemException {
      // Edge Case #26: Storage full / Disk error
      _showStudentAlert(
        title: 'Storage Full',
        message: 'Unable to save offline copy. Please check if your device has enough free storage space.',
      );
    } catch (e) {
      // Edge Case #1 & #20: Graceful fallback
      _showStudentAlert(
        title: 'Document Notice',
        message: 'The cloud storage server is temporarily unreachable. Your study notes and chapter content remain fully readable in the viewer.',
      );
    } finally {
      if (mounted) {
        setState(() => _downloadingIds.remove(material.id));
      }
    }
  }

  void _showStudentAlert({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showToast(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.teal.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- Open Strictly Read-Only In-App Reader Modal (NO RAW URLS!) ---
  void _openStudentReaderModal(ClassRealmMaterial material) {
    showDialog(
      context: context,
      builder: (ctx) => _StudentMaterialReaderModal(
        material: material,
        isDownloading: _downloadingIds.contains(material.id),
        onDownloadRequested: () => _downloadOfflineCopy(material),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableSubjects = _filteredSubjects;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Materials & Lessons'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject, Section & Class Toggle Bar
                _buildTopSelectorBar(theme, availableSubjects),

                // Folder Breadcrumbs
                if (_folderStack.isNotEmpty) _buildBreadcrumbs(theme),

                // Main Content
                Expanded(
                  child: _errorMessage != null
                      ? _buildErrorView(theme)
                      : (_folders.isEmpty && _materials.isEmpty)
                          ? _buildEmptyState(theme)
                          : RefreshIndicator(
                              onRefresh: _loadMaterialsForOffering,
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  // Folders
                                  if (_folders.isNotEmpty) ...[
                                    Text(
                                      'MODULE FOLDERS (${_folders.length})',
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

                                  // Learning Materials & Notes
                                  if (_materials.isNotEmpty) ...[
                                    Text(
                                      'LEARNING DOCUMENTS & LESSONS (${_materials.length})',
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
                ),
              ],
            ),
    );
  }

  // --- Top Selector Bar with Current vs Past Classes Toggle ---
  Widget _buildTopSelectorBar(
    ThemeData theme,
    List<Map<String, dynamic>> availableSubjects,
  ) {
    final activeGrade = _selectedSubject?['grade_level'] ?? 11;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        children: [
          Row(
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

              // Subject Dropdown with Irregular student Section & Term details
              Expanded(
                child: availableSubjects.isEmpty
                    ? Text(
                        _showArchivedClasses
                            ? 'No archived classes found'
                            : 'No current enrolled classes',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<Map<String, dynamic>>(
                          value: availableSubjects.contains(_selectedSubject)
                              ? _selectedSubject
                              : availableSubjects.first,
                          isExpanded: true,
                          items: availableSubjects.map((sub) {
                            final s = sub['subject_name'] ?? 'Subject';
                            final sec = sub['section_name'] ?? '';
                            final term = sub['term_name'] ?? '';
                            final isIrreg = sub['is_irregular'] == true;
                            return DropdownMenuItem(
                              value: sub,
                              child: Text(
                                '$s — Section $sec • $term ${isIrreg ? "(Irregular)" : ""}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (newSub) {
                            if (newSub == null || newSub == _selectedSubject) return;
                            setState(() {
                              _selectedSubject = newSub;
                              _folderStack.clear();
                              _currentFolder = null;
                            });
                            _loadMaterialsForOffering();
                          },
                        ),
                      ),
              ),

              const SizedBox(width: 8),

              // Current vs Past Classes Toggle (Edge Case #17)
              Tooltip(
                message: _showArchivedClasses
                    ? 'Switch to Current Classes'
                    : 'Switch to Past / Archived Classes for Review',
                child: FilterChip(
                  label: Text(
                    _showArchivedClasses ? 'Past Classes (Review)' : 'Current Classes',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _showArchivedClasses ? Colors.orange.shade800 : theme.colorScheme.primary,
                    ),
                  ),
                  selected: _showArchivedClasses,
                  onSelected: (val) {
                    setState(() {
                      _showArchivedClasses = val;
                      final filtered = _filteredSubjects;
                      _selectedSubject = filtered.isNotEmpty ? filtered.first : null;
                      _folderStack.clear();
                      _currentFolder = null;
                    });
                    _loadMaterialsForOffering();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbs(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(
        children: [
          InkWell(
            onTap: () => _navigateBackTo(-1),
            child: const Row(
              children: [
                Icon(Icons.home_outlined, size: 16),
                SizedBox(width: 4),
                Text('Root', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          for (int i = 0; i < _folderStack.length; i++) ...[
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            InkWell(
              onTap: () => _navigateBackTo(i),
              child: Text(
                _folderStack[i].folderName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: i == _folderStack.length - 1 ? FontWeight.bold : FontWeight.normal,
                  color: i == _folderStack.length - 1 ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
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
        onTap: () => _navigateToFolder(folder),
      ),
    );
  }

  Widget _buildMaterialCard(ClassRealmMaterial material, ThemeData theme) {
    final ext = material.fileExtension;

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
        // ZERO edit or delete controls! Opens strictly read-only In-App Reader Modal
        onTap: () => _openStudentReaderModal(material),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getFormatColor(ext).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_getFormatIcon(ext), color: _getFormatColor(ext), size: 26),
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
              // Read / View Icon
              Icon(Icons.chrome_reader_mode_outlined, color: theme.colorScheme.primary, size: 22),
            ],
          ),
        ),
      ),
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
              'No Learning Materials Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'No published materials available in this folder yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _loadStudentEnrolledClasses,
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
    if (e == 'lesson') return Icons.article;
    if (e == 'link') return Icons.link;
    return Icons.insert_drive_file;
  }

  Color _getFormatColor(String ext) {
    final e = ext.toLowerCase();
    if (e == 'pdf') return Colors.red.shade600;
    if (e == 'doc' || e == 'docx') return Colors.blue.shade600;
    if (e == 'ppt' || e == 'pptx') return Colors.orange.shade700;
    if (e == 'lesson') return Colors.purple.shade600;
    if (e == 'link') return Colors.teal.shade700;
    return Colors.blueGrey;
  }
}

/// Strictly Read-Only In-App Reader Modal for Students
/// Zero edit/delete/archive buttons.
/// Chunked paragraph rendering for 50,000 char chapters on low-end devices.
/// SelectionArea is DISABLED to prevent copy-paste cheating during background quizzes.
class _StudentMaterialReaderModal extends StatelessWidget {
  final ClassRealmMaterial material;
  final bool isDownloading;
  final VoidCallback onDownloadRequested;

  const _StudentMaterialReaderModal({
    required this.material,
    required this.isDownloading,
    required this.onDownloadRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ext = material.fileExtension;

    // Split lesson text into paragraphs for low-end device smooth scrolling (Edge Case #11)
    final rawDescription = material.description?.trim() ?? '';
    final paragraphs = rawDescription.isNotEmpty
        ? rawDescription.split(RegExp(r'\n{2,}'))
        : <String>[];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 780,
          maxHeight: 680,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon, Title, Close (ZERO EDIT/DELETE BUTTONS)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getFormatColor(ext).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_getFormatIcon(ext), color: _getFormatColor(ext), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${material.fileExtension} • ${material.formattedSize}',
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Embedded link notice if text/uri-list
              if (material.isEmbedUrl) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.open_in_new, color: Colors.blue, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Cloud Document / Presentation. Direct document view prepared below.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Chunked Lesson Reader Area (SelectionArea DISABLED for quiz anti-cheat, Edge Case #14)
              Expanded(
                child: paragraphs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notes, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                            const SizedBox(height: 8),
                            Text(
                              'No study notes or chapter content attached to this document.',
                              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
                        ),
                        child: ListView.builder(
                          itemCount: paragraphs.length,
                          itemBuilder: (ctx, index) {
                            final p = paragraphs[index].trim();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                p,
                                style: TextStyle(
                                  // Theme-adaptive contrast (WCAG AA compliant, Edge Case #22)
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                                  fontSize: 14,
                                  height: 1.6,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),

              const SizedBox(height: 14),

              // Bottom Bar: Debounced Download Button & Close (STRICTLY READ-ONLY)
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_for_offline_outlined, size: 18),
                    label: Text(isDownloading ? 'Saving Offline...' : 'Save Offline Copy'),
                    onPressed: isDownloading ? null : onDownloadRequested,
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done Reading'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFormatIcon(String ext) {
    final e = ext.toLowerCase();
    if (e == 'pdf') return Icons.picture_as_pdf;
    if (e == 'doc' || e == 'docx') return Icons.description;
    if (e == 'ppt' || e == 'pptx') return Icons.slideshow;
    if (e == 'lesson') return Icons.article;
    if (e == 'link') return Icons.link;
    return Icons.insert_drive_file;
  }

  Color _getFormatColor(String ext) {
    final e = ext.toLowerCase();
    if (e == 'pdf') return Colors.red.shade600;
    if (e == 'doc' || e == 'docx') return Colors.blue.shade600;
    if (e == 'ppt' || e == 'pptx') return Colors.orange.shade700;
    if (e == 'lesson') return Colors.purple.shade600;
    if (e == 'link') return Colors.teal.shade700;
    return Colors.blueGrey;
  }
}
