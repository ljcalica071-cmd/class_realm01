import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/learning_material_repository.dart';
import 'package:class_realm/data/repositories/supabase_learning_material_repository.dart';

class TeacherLearningMaterialsTab extends StatefulWidget {
  final List<LearningMaterialModel>? materials;

  const TeacherLearningMaterialsTab({super.key, this.materials});

  @override
  State<TeacherLearningMaterialsTab> createState() =>
      _TeacherLearningMaterialsTabState();
}

class _TeacherLearningMaterialsTabState
    extends State<TeacherLearningMaterialsTab> {
  final _materialRepo = SupabaseLearningMaterialRepository.instance;
  final _subjectRepo = SubjectRepository.instance;

  bool _isLoading = true;
  String? _errorMessage;

  // Teacher offerings
  List<Map<String, dynamic>> _offerings = [];
  Map<String, dynamic>? _selectedOffering;

  // Navigation & Folder hierarchy
  ClassRealmFolder? _currentFolder;
  final List<ClassRealmFolder> _folderStack = [];

  // Data
  List<ClassRealmFolder> _folders = [];
  List<ClassRealmMaterial> _materials = [];

  // View state
  bool _isGridView = true;
  String _searchQuery = '';
  String _selectedTypeFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadTeacherClasses();
  }

  Future<void> _loadTeacherClasses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final teacherId = AuthRepository.instance.currentUser?.id;
      if (teacherId == null || teacherId.isEmpty) {
        throw StateError('Please sign in as a teacher to manage learning materials.');
      }

      final classes = await _subjectRepo.getTeacherSubjects(teacherId);
      if (!mounted) return;

      if (classes.isEmpty) {
        setState(() {
          _offerings = [];
          _selectedOffering = null;
          _isLoading = false;
        });
        return;
      }

      _offerings = classes;
      _selectedOffering = classes.first;

      await _loadFolderContents();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFolderContents() async {
    if (_selectedOffering == null) return;
    final offeringId = _selectedOffering!['id'] as String;

    setState(() => _isLoading = true);

    try {
      // Ensure initial term folders exist
      if (_currentFolder == null) {
        await _materialRepo.ensureDefaultTermFolders(offeringId);
      }

      final fetchedFolders = await _materialRepo.getFolders(
        subjectOfferingId: offeringId,
        parentFolderId: _currentFolder?.id,
      );

      List<ClassRealmMaterial> fetchedMaterials = [];
      if (_currentFolder != null) {
        fetchedMaterials = await _materialRepo.getMaterials(
          folderId: _currentFolder!.id,
          studentOnly: false,
        );
      }

      if (!mounted) return;
      setState(() {
        _folders = fetchedFolders;
        _materials = fetchedMaterials;
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
    _loadFolderContents();
  }

  void _navigateBackTo(int index) {
    if (index < 0) {
      // Root
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
    _loadFolderContents();
  }

  // --- Filtering ---
  List<ClassRealmMaterial> get _filteredMaterials {
    return _materials.where((m) {
      final matchesSearch = _searchQuery.isEmpty ||
          m.fileName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (m.title?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      if (!matchesSearch) return false;

      if (_selectedTypeFilter == 'PDF') return m.isPdf;
      if (_selectedTypeFilter == 'WORD') return m.isWord;
      if (_selectedTypeFilter == 'SLIDES') return m.isPresentation;
      if (_selectedTypeFilter == 'SHEETS') return m.isSpreadsheet;

      return true;
    }).toList();
  }

  List<ClassRealmFolder> get _filteredFolders {
    if (_searchQuery.isEmpty) return _folders;
    return _folders
        .where((f) =>
            f.folderName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  // --- Upload Modal Flow ---
  Future<void> _showUploadDialog() async {
    if (_selectedOffering == null) {
      _showSnack('Please select a class first.', isError: true);
      return;
    }

    final offeringId = _selectedOffering!['id'] as String;
    final subjectName = _selectedOffering!['subject_name'] ?? 'Subject';
    final gradeLevel = _selectedOffering!['grade_level'] ?? 11;

    // Siblings for multi-section broadcast
    final otherOfferings = _offerings
        .where((o) =>
            o['id'] != offeringId &&
            o['subject_name'] == subjectName &&
            o['grade_level'] == gradeLevel)
        .toList();

    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'],
        withData: true,
      );
    } catch (e) {
      _showSnack('File picker error: $e', isError: true);
      return;
    }

    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;

    // Strict validation
    final ext = (file.extension ?? '').toLowerCase();
    final allowedExts = ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'];
    if (!allowedExts.contains(ext)) {
      _showFormatAlert();
      return;
    }

    // 5 MB limit (5 * 1024 * 1024 = 5,242,880 bytes)
    const maxBytes = 5 * 1024 * 1024;
    if (file.size > maxBytes) {
      _showSizeLimitAlert(file.size);
      return;
    }

    Uint8List? fileBytes = file.bytes;
    if (fileBytes == null && !kIsWeb && file.path != null) {
      try {
        fileBytes = await File(file.path!).readAsBytes();
      } catch (e) {
        debugPrint('File read from disk warning: $e');
      }
    }

    if (fileBytes == null) {
      _showSnack('Unable to read file content. Please try another file.', isError: true);
      return;
    }
    final nonNullBytes = fileBytes;

    // Show upload confirmation modal
    if (!mounted) return;
    final titleController = TextEditingController(text: file.name);
    final descController = TextEditingController();
    bool isVisibleToStudents = true;
    ClassRealmFolder? targetFolder = _currentFolder ?? (_folders.isNotEmpty ? _folders.first : null);
    final selectedOtherOfferings = <String>{};

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.cloud_upload_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                const Text('Upload Learning Material'),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selected file overview card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(_getFormatIcon(ext), color: _getFormatColor(ext), size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Format: ${ext.toUpperCase()} • Size: ${_formatBytes(file.size)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Verified ≤ 5MB',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Display Title
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Document Title (Display Name)',
                        hintText: 'e.g. Lesson 1: Introduction to Functions',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Target Folder Selection
                    DropdownButtonFormField<ClassRealmFolder>(
                      value: targetFolder,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Save to Folder',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _folders.map((f) {
                        return DropdownMenuItem(
                          value: f,
                          child: Row(
                            children: [
                              const Icon(Icons.folder_outlined, size: 18, color: Colors.amber),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  f.folderName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setModalState(() => targetFolder = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Description / Teacher notes
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Instructions / Description (Optional)',
                        hintText: 'e.g. Read pages 1–10 before our Wednesday session.',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Student Visibility Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Visible to Enrolled Students',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      subtitle: Text(
                        isVisibleToStudents
                            ? 'Students can view and download this document immediately.'
                            : 'Kept as Draft/Hidden. Only you can view this until published.',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      value: isVisibleToStudents,
                      activeColor: Colors.green,
                      onChanged: (val) => setModalState(() => isVisibleToStudents = val),
                    ),

                    // Multi-Section Broadcast Option
                    if (otherOfferings.isNotEmpty) ...[
                      const Divider(height: 24),
                      Text(
                        'Share to other sections of $subjectName:',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Single upload linked with 0 extra cloud storage consumption.',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...otherOfferings.map((other) {
                        final otherId = other['id'] as String;
                        final otherSec = other['section_name'] ?? 'Section';
                        final isSelected = selectedOtherOfferings.contains(otherId);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text('Grade $gradeLevel — Section $otherSec'),
                          value: isSelected,
                          onChanged: (checked) {
                            setModalState(() {
                              if (checked == true) {
                                selectedOtherOfferings.add(otherId);
                              } else {
                                selectedOtherOfferings.remove(otherId);
                              }
                            });
                          },
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Upload Document'),
                onPressed: () async {
                  if (targetFolder == null) {
                    _showSnack('Please select a destination folder.', isError: true);
                    return;
                  }

                  Navigator.pop(ctx);
                  await _executeUpload(
                    folderId: targetFolder!.id,
                    folderName: targetFolder!.folderName,
                    fileName: file.name,
                    fileBytes: nonNullBytes,
                    fileSize: file.size,
                    mimeType: _getMimeType(ext),
                    title: titleController.text,
                    description: descController.text,
                    isVisibleToStudents: isVisibleToStudents,
                    otherOfferingIds: selectedOtherOfferings.toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _executeUpload({
    required String folderId,
    required String folderName,
    required String fileName,
    required Uint8List fileBytes,
    required int fileSize,
    required String mimeType,
    required String title,
    required String description,
    required bool isVisibleToStudents,
    required List<String> otherOfferingIds,
  }) async {
    if (_selectedOffering == null) return;
    final offeringId = _selectedOffering!['id'] as String;

    setState(() => _isLoading = true);

    try {
      final newMat = await _materialRepo.uploadMaterial(
        folderId: folderId,
        subjectOfferingId: offeringId,
        fileName: fileName,
        fileBytes: fileBytes,
        fileSizeBytes: fileSize,
        mimeType: mimeType,
        title: title,
        description: description,
        isVisibleToStudents: isVisibleToStudents,
      );

      // Multi-section replication
      if (otherOfferingIds.isNotEmpty) {
        await _materialRepo.duplicateMaterialToOfferings(
          material: newMat,
          targetOfferingIds: otherOfferingIds,
          targetFolderName: folderName,
        );
      }

      _showSnack('Document uploaded successfully!', isError: false);
      await _loadFolderContents();
    } catch (e) {
      _showSnack('Upload failed: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  // --- Folder Management ---
  Future<void> _showCreateFolderDialog() async {
    if (_selectedOffering == null) return;
    final folderController = TextEditingController();
    bool isVisible = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.create_new_folder_outlined, color: Colors.amber),
                SizedBox(width: 8),
                Text('Create New Folder'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: folderController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Folder Name',
                    hintText: 'e.g. Chapter 2 Modules',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visible to Students'),
                  value: isVisible,
                  activeColor: Colors.green,
                  onChanged: (v) => setModalState(() => isVisible = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = folderController.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(ctx);

                  setState(() => _isLoading = true);
                  try {
                    await _materialRepo.createFolder(
                      subjectOfferingId: _selectedOffering!['id'] as String,
                      folderName: name,
                      parentFolderId: _currentFolder?.id,
                      isVisibleToStudents: isVisible,
                    );
                    _showSnack('Folder created!', isError: false);
                    await _loadFolderContents();
                  } catch (e) {
                    _showSnack('Failed to create folder: $e', isError: true);
                    setState(() => _isLoading = false);
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleMaterialVisibility(ClassRealmMaterial material) async {
    final nextState = !material.isVisibleToStudents;
    try {
      await _materialRepo.toggleMaterialVisibility(
        materialId: material.id,
        isVisible: nextState,
      );
      setState(() {
        final idx = _materials.indexWhere((m) => m.id == material.id);
        if (idx != -1) {
          _materials[idx] = material.copyWith(isVisibleToStudents: nextState);
        }
      });
      _showSnack(
        nextState
            ? 'Document is now visible to enrolled students.'
            : 'Document is now hidden (Draft mode).',
        isError: false,
      );
    } catch (e) {
      _showSnack('Failed to update visibility: $e', isError: true);
    }
  }

  Future<void> _deleteMaterialConfirm(ClassRealmMaterial material) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text(
          'Are you sure you want to delete "${material.displayName}"? This will remove the file from cloud storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _materialRepo.deleteMaterial(material.id, material.storagePathUrl);
        _showSnack('Document deleted.', isError: false);
        await _loadFolderContents();
      } catch (e) {
        _showSnack('Failed to delete: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  // --- UI Alerts ---
  void _showFormatAlert() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Invalid File Format'),
          ],
        ),
        content: const Text(
          'Direct videos (.mp4) and images (.png, .jpg) are strictly prohibited to conserve database cloud quota.\n\n'
          'Allowed documents only:\n• PDF (.pdf)\n• Word (.docx, .doc)\n• PowerPoint (.pptx, .ppt)\n• Excel (.xlsx, .xls)',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showSizeLimitAlert(int byteSize) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.report_problem, color: Colors.red),
            SizedBox(width: 8),
            Text('File Size Exceeded'),
          ],
        ),
        content: Text(
          'Selected file size is ${_formatBytes(byteSize)}, which exceeds the maximum limit of 5.0 MB per document.\n\n'
          'Please compress your document before uploading.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.teal.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_errorMessage != null) {
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
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _loadTeacherClasses,
              ),
            ],
          ),
        ),
      );
    }

    if (_offerings.isEmpty && !_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_off_outlined, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              const Text(
                'No Teaching Classes Found',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Please configure your assigned subjects and sections in "Classroom Setup" first.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      );
    }

    final activeGrade = _selectedOffering?['grade_level'] ?? 11;
    final activeSubject = _selectedOffering?['subject_name'] ?? 'Subject';
    final activeSection = _selectedOffering?['section_name'] ?? 'Section';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Workspace Bar: Grade & Class Selector + Action Buttons
          _buildTopHeader(theme, activeGrade, activeSubject, activeSection),

          const SizedBox(height: 16),

          // Google Drive-Style Breadcrumbs & View Controls
          _buildBreadcrumbsAndControls(theme, activeGrade, activeSubject, activeSection),

          const SizedBox(height: 12),

          // Search & Filter Bar
          _buildSearchAndFilters(theme),

          const SizedBox(height: 16),

          // Main Drive Browser Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadFolderContents,
                    child: _buildDriveContent(theme),
                  ),
          ),
        ],
      ),
    );
  }

  // --- Top Header ---
  Widget _buildTopHeader(
    ThemeData theme,
    dynamic activeGrade,
    dynamic activeSubject,
    dynamic activeSection,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // Grade Level Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Text(
              'GRADE $activeGrade',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 1.0,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Class Picker Dropdown
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Map<String, dynamic>>(
                value: _selectedOffering,
                isExpanded: true,
                items: _offerings.map((offering) {
                  final g = offering['grade_level'] ?? 11;
                  final s = offering['subject_name'] ?? 'Subject';
                  final sec = offering['section_name'] ?? 'Section';
                  return DropdownMenuItem(
                    value: offering,
                    child: Text(
                      'Grade $g • $s — Section $sec',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  );
                }).toList(),
                onChanged: (newVal) {
                  if (newVal == null || newVal == _selectedOffering) return;
                  setState(() {
                    _selectedOffering = newVal;
                    _folderStack.clear();
                    _currentFolder = null;
                  });
                  _loadFolderContents();
                },
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Upload Material Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.upload_file, size: 20),
            label: const Text('Upload Document', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _showUploadDialog,
          ),
        ],
      ),
    );
  }

  // --- Breadcrumbs & Controls ---
  Widget _buildBreadcrumbsAndControls(
    ThemeData theme,
    dynamic activeGrade,
    dynamic activeSubject,
    dynamic activeSection,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Root Item
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _navigateBackTo(-1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.home_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Grade $activeGrade ($activeSection)',
                    style: TextStyle(
                      fontWeight: _folderStack.isEmpty ? FontWeight.bold : FontWeight.normal,
                      color: _folderStack.isEmpty ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Subfolders Breadcrumbs
          for (int i = 0; i < _folderStack.length; i++) ...[
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => _navigateBackTo(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  _folderStack[i].folderName,
                  style: TextStyle(
                    fontWeight: i == _folderStack.length - 1 ? FontWeight.bold : FontWeight.normal,
                    color: i == _folderStack.length - 1 ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],

          const Spacer(),

          // New Folder Button
          TextButton.icon(
            icon: const Icon(Icons.create_new_folder_outlined, size: 18, color: Colors.amber),
            label: const Text('New Folder', style: TextStyle(fontSize: 13)),
            onPressed: _showCreateFolderDialog,
          ),

          const SizedBox(width: 8),

          // Grid / List View Toggle
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, size: 20),
            tooltip: _isGridView ? 'Switch to List View' : 'Switch to Grid View',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
    );
  }

  // --- Search & Filter Bar ---
  Widget _buildSearchAndFilters(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search documents and folders...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Wrap(
          spacing: 8,
          children: [
            _buildFilterChip('ALL', 'All'),
            _buildFilterChip('PDF', 'PDF'),
            _buildFilterChip('WORD', 'Word'),
            _buildFilterChip('SLIDES', 'PowerPoint'),
            _buildFilterChip('SHEETS', 'Excel'),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedTypeFilter == key;
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
      onSelected: (_) => setState(() => _selectedTypeFilter = key),
    );
  }

  // --- Drive Browser Content ---
  Widget _buildDriveContent(ThemeData theme) {
    final folders = _filteredFolders;
    final files = _filteredMaterials;

    if (folders.isEmpty && files.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_upload_outlined, size: 56, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
              const SizedBox(height: 12),
              const Text(
                'This folder is empty',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Upload PDF, Word, PowerPoint, or Excel documents to share with your students.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Document Now'),
                onPressed: _showUploadDialog,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: [
        // Folders Section
        if (folders.isNotEmpty) ...[
          Text(
            'FOLDERS (${folders.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 10),
          _isGridView
              ? GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisExtent: 80,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: folders.length,
                  itemBuilder: (ctx, i) => _buildFolderCard(folders[i], theme),
                )
              : Column(
                  children: folders.map((f) => _buildFolderListRow(f, theme)).toList(),
                ),
          const SizedBox(height: 24),
        ],

        // Files Section
        if (files.isNotEmpty) ...[
          Text(
            'DOCUMENTS & FILES (${files.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 10),
          _isGridView
              ? GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    mainAxisExtent: 140,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: files.length,
                  itemBuilder: (ctx, i) => _buildFileCard(files[i], theme),
                )
              : Column(
                  children: files.map((f) => _buildFileListRow(f, theme)).toList(),
                ),
        ],
      ],
    );
  }

  // --- Folder Widgets ---
  Widget _buildFolderCard(ClassRealmFolder folder, ThemeData theme) {
    return InkWell(
      onTap: () => _navigateToFolder(folder),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.folder, color: Colors.amber, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    folder.folderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${folder.fileCount} items',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderListRow(ClassRealmFolder folder, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: const Icon(Icons.folder, color: Colors.amber, size: 28),
        title: Text(folder.folderName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${folder.fileCount} items'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _navigateToFolder(folder),
      ),
    );
  }

  // --- File Widgets ---
  Widget _buildFileCard(ClassRealmMaterial material, ThemeData theme) {
    final ext = material.fileExtension;
    final isVisible = material.isVisibleToStudents;

    return InkWell(
      onTap: () => _showMaterialDetails(material),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isVisible
                ? theme.colorScheme.onSurface.withValues(alpha: 0.12)
                : Colors.amber.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getFormatIcon(ext), color: _getFormatColor(ext), size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    material.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                // Visibility Toggle Badge
                Tooltip(
                  message: isVisible
                      ? 'Published: Visible to enrolled students. Click to hide.'
                      : 'Draft: Hidden from students. Click to publish.',
                  child: InkWell(
                    onTap: () => _toggleMaterialVisibility(material),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: isVisible
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVisible ? Icons.visibility : Icons.visibility_off,
                            size: 12,
                            color: isVisible ? Colors.green : Colors.amber.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVisible ? 'Live' : 'Draft',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isVisible ? Colors.green : Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              material.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Text(
                  '${material.formattedSize} • ${_formatDate(material.createdAt)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  tooltip: 'Delete document',
                  onPressed: () => _deleteMaterialConfirm(material),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileListRow(ClassRealmMaterial material, ThemeData theme) {
    final ext = material.fileExtension;
    final isVisible = material.isVisibleToStudents;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: Icon(_getFormatIcon(ext), color: _getFormatColor(ext), size: 28),
        title: Text(material.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(
          '${material.fileName} • ${material.formattedSize} • ${_formatDate(material.createdAt)}',
          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _toggleMaterialVisibility(material),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isVisible ? Colors.green.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isVisible ? 'Visible to Students' : 'Hidden (Draft)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isVisible ? Colors.green : Colors.amber.shade900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              tooltip: 'Delete',
              onPressed: () => _deleteMaterialConfirm(material),
            ),
          ],
        ),
        onTap: () => _showMaterialDetails(material),
      ),
    );
  }

  void _showMaterialDetails(ClassRealmMaterial material) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(_getFormatIcon(material.fileExtension), color: _getFormatColor(material.fileExtension)),
            const SizedBox(width: 10),
            Expanded(child: Text(material.displayName, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File Name: ${material.fileName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Size: ${material.formattedSize} • Format: ${material.fileExtension}'),
            const SizedBox(height: 4),
            Text('Status: ${material.isVisibleToStudents ? "🟢 Visible to Enrolled Students" : "🔒 Hidden (Draft)"}'),
            const SizedBox(height: 4),
            Text('Uploaded: ${_formatDate(material.createdAt)}'),
            if (material.description != null && material.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Instructions / Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(material.description!),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                'Cloud Link:\n${material.storagePathUrl}',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // --- Helper formatters & icons ---
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

  String _getMimeType(String ext) {
    final e = ext.toLowerCase();
    switch (e) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
