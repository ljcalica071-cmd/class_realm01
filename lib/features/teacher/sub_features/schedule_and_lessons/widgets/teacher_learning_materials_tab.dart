import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/learning_material_repository.dart';
import 'package:class_realm/data/repositories/supabase_learning_material_repository.dart';

import 'teacher_material_viewer_modal.dart';

import 'package:class_realm/shared/widgets/shimmer_loading.dart';

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

  // Teacher offerings (only offerings with actively enrolled students)
  List<Map<String, dynamic>> _offerings = [];
  Map<String, dynamic>? _selectedOffering;

  // Cascading selections: Grade Level -> Subject -> Section
  int? _selectedGrade;
  String? _selectedSubject;

  // Archive Mode State (matches Classroom Setup pattern)
  bool _isViewingArchived = false;
  List<ClassRealmFolder> _archivedFolders = [];
  List<ClassRealmMaterial> _archivedMaterials = [];
  int get _archivedCount => _archivedFolders.length + _archivedMaterials.length;

  // Active Drive Navigation & Folder hierarchy
  ClassRealmFolder? _currentFolder;
  List<ClassRealmFolder> _folderStack = [];

  // Active Data
  List<ClassRealmFolder> _folders = [];
  List<ClassRealmMaterial> _materials = [];

  // View state
  bool _isGridView = false;
  String _searchQuery = '';
  String _selectedTypeFilter = 'ALL'; // 'ALL', 'PDF', 'WORD', 'SLIDES'

  @override
  void initState() {
    super.initState();
    _offerings = [];
    _archivedFolders = [];
    _archivedMaterials = [];
    _folders = [];
    _materials = [];
    _folderStack = [];
    _loadTeacherClasses();
  }

  @override
  void didUpdateWidget(covariant TeacherLearningMaterialsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  // --- Helper parsers & formatters ---
  int _parseGrade(dynamic g) {
    if (g is int) return g;
    return int.tryParse(g?.toString() ?? '') ?? 11;
  }

  String _formatSectionName(dynamic raw) {
    if (raw == null) return 'Section';
    final clean = raw.toString().trim();
    if (clean.isEmpty) return 'Section';
    if (clean.toLowerCase().startsWith('section')) {
      return clean[0].toUpperCase() + clean.substring(1);
    }
    return 'Section $clean';
  }

  // --- Cascading Dropdown Selectors (Only with enrolled students) ---
  List<int> get _availableGrades {
    if (_offerings.isEmpty) return [];
    final set = <int>{};
    for (final o in _offerings) {
      set.add(_parseGrade(o['grade_level']));
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get _availableSubjects {
    if (_selectedGrade == null || _offerings.isEmpty) {
      return [];
    }
    final set = <String>{};
    for (final o in _offerings) {
      if (_parseGrade(o['grade_level']) == _selectedGrade) {
        final name = o['subject_name']?.toString();
        if (name != null && name.trim().isNotEmpty) {
          set.add(name.trim());
        }
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Map<String, dynamic>> get _availableSections {
    if (_selectedGrade == null ||
        _selectedSubject == null ||
        _offerings.isEmpty) {
      return [];
    }
    final list = _offerings.where((o) {
      return _parseGrade(o['grade_level']) == _selectedGrade &&
          (o['subject_name']?.toString() ?? '').trim() == _selectedSubject;
    }).toList();
    list.sort(
      (a, b) => (a['section_name']?.toString() ?? '').compareTo(
        b['section_name']?.toString() ?? '',
      ),
    );
    return list;
  }

  Future<void> _loadTeacherClasses() async {
    final teacherId = AuthRepository.instance.currentUser?.id;
    if (teacherId == null || teacherId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please log in as a teacher to manage learning materials.';
      });
      return;
    }

    final cachedClasses = _subjectRepo.getCachedTeacherSubjects(teacherId);
    if (cachedClasses.isNotEmpty && _offerings.isEmpty) {
      _offerings = cachedClasses;
      final grades = _availableGrades;
      _selectedGrade = grades.isNotEmpty ? grades.first : null;
      final subjects = _availableSubjects;
      _selectedSubject = subjects.isNotEmpty ? subjects.first : null;
      final sections = _availableSections;
      _selectedOffering = sections.isNotEmpty ? sections.first : null;
      _isLoading = false;
    } else if (_offerings.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // STRICT REQUIREMENT: Only show subjects/sections with enrolled students
      final classes = await _subjectRepo.getTeacherSubjects(
        teacherId,
        onlyWithEnrolledStudents: true,
      );
      if (!mounted) return;

      if (classes.isEmpty) {
        setState(() {
          _offerings = [];
          _selectedOffering = null;
          _selectedGrade = null;
          _selectedSubject = null;
          _isLoading = false;
        });
        return;
      }

      _offerings = classes;

      // Select default Grade
      final grades = _availableGrades;
      if (_selectedGrade == null || !grades.contains(_selectedGrade)) {
        _selectedGrade = grades.isNotEmpty ? grades.first : null;
      }

      // Select default Subject
      final subjects = _availableSubjects;
      if (_selectedSubject == null || !subjects.contains(_selectedSubject)) {
        _selectedSubject = subjects.isNotEmpty ? subjects.first : null;
      }

      // Select default Offering (Section)
      final sections = _availableSections;
      if (_selectedOffering == null || !sections.contains(_selectedOffering)) {
        _selectedOffering = sections.isNotEmpty ? sections.first : null;
      }

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
    if (_selectedOffering == null) {
      setState(() => _isLoading = false);
      return;
    }
    final offeringId = _selectedOffering!['id'] as String;

    setState(() => _isLoading = true);

    try {
      // 1. Ensure the 4 default term folders exist in Supabase DB
      if (_currentFolder == null) {
        await _materialRepo.ensureDefaultTermFolders(offeringId);
      }

      // 2. Fetch active folders
      final fetchedFolders = await _materialRepo.getFolders(
        subjectOfferingId: offeringId,
        parentFolderId: _currentFolder?.id,
      );

      // 3. Fetch active materials in current folder
      List<ClassRealmMaterial> fetchedMaterials = [];
      if (_currentFolder != null) {
        fetchedMaterials = await _materialRepo.getMaterials(
          folderId: _currentFolder!.id,
          studentOnly: false,
        );
      }

      // 4. Fetch archived folders & materials for Archive View counter
      final archivedF = await _materialRepo.getArchivedFolders(offeringId);
      final archivedM = await _materialRepo.getArchivedMaterials(offeringId);

      if (!mounted) return;
      setState(() {
        _folders = fetchedFolders;
        _materials = fetchedMaterials;
        _archivedFolders = archivedF;
        _archivedMaterials = archivedM;
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
      if (index >= 0 && index < _folderStack.length) {
        setState(() {
          _folderStack.removeRange(index + 1, _folderStack.length);
          _currentFolder = _folderStack[index];
        });
      }
    }
    _loadFolderContents();
  }

  // --- Material & Folder Filtering ---
  List<ClassRealmMaterial> get _filteredMaterials {
    if (_materials.isEmpty) return [];
    return _materials.where((m) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          m.fileName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (m.title?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false);

      if (!matchesSearch) return false;

      if (_selectedTypeFilter == 'PDF') return m.isPdf;
      if (_selectedTypeFilter == 'WORD') return m.isWord;
      if (_selectedTypeFilter == 'SLIDES') return m.isPresentation;

      return true;
    }).toList();
  }

  List<ClassRealmFolder> get _filteredFolders {
    if (_folders.isEmpty) return [];
    if (_searchQuery.isEmpty) return _folders;
    return _folders
        .where(
          (f) =>
              f.folderName.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  List<ClassRealmMaterial> get _filteredArchivedMaterials {
    if (_archivedMaterials.isEmpty) return [];
    if (_searchQuery.isEmpty) return _archivedMaterials;
    return _archivedMaterials.where((m) {
      return m.fileName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (m.title?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false);
    }).toList();
  }

  List<ClassRealmFolder> get _filteredArchivedFolders {
    if (_archivedFolders.isEmpty) return [];
    if (_searchQuery.isEmpty) return _archivedFolders;
    return _archivedFolders.where((f) {
      return f.folderName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  // --- Upload Modal Flow with Inline Error Messages (No bottom banners!) ---
  Future<void> _showUploadFileDialog() async {
    if (_selectedOffering == null) return;

    final offeringId = _selectedOffering!['id'] as String;
    final subjectName = _selectedOffering!['subject_name'] ?? 'Subject';
    final gradeLevel = _selectedOffering!['grade_level'] ?? 11;
    final sectionName = _formatSectionName(_selectedOffering!['section_name']);

    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx'],
        withData: true,
      );
    } catch (e) {
      _showFeedbackModal(
        'File Picker Error',
        'Could not open file picker: $e',
        isError: true,
      );
      return;
    }

    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;

    Uint8List? fileBytes = file.bytes;
    if (fileBytes == null && !kIsWeb && file.path != null) {
      try {
        fileBytes = await File(file.path!).readAsBytes();
      } catch (e) {
        debugPrint('File read warning: $e');
      }
    }

    if (fileBytes == null || fileBytes.isEmpty) {
      _showFeedbackModal(
        'Error',
        'Unable to read file content. Please choose another file.',
        isError: true,
      );
      return;
    }

    // Strict 3MB size cap and magic-byte checks
    final validationError = MaterialFileValidator.validateFile(
      fileName: file.name,
      fileBytes: fileBytes,
      byteSize: file.size,
    );

    if (validationError != null) {
      _showFeedbackModal('Validation Failed', validationError, isError: true);
      return;
    }

    final nonNullBytes = fileBytes;
    final ext = (file.extension ?? '').toLowerCase();
    final sanitizedFileName = MaterialFileValidator.sanitizeFileName(file.name);

    if (!mounted) return;
    final titleController = TextEditingController(text: sanitizedFileName);
    final descController = TextEditingController();
    bool isVisibleToStudents = true;
    ClassRealmFolder? targetFolder =
        _currentFolder ?? (_folders.isNotEmpty ? _folders.first : null);

    final formKey = GlobalKey<FormState>();
    bool isUploading = false;
    String? inModalUploadError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Upload Learning Material',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Target class badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.school,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Target Class: Grade $gradeLevel â€¢ $subjectName â€” $sectionName',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // In-modal active upload progress banner
                      if (isUploading) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Uploading to Supabase database & storage... Please wait.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // In-modal error message with 1-click retry
                      if (inModalUploadError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  inModalUploadError!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Selected file card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getFormatIcon(ext),
                              color: _getFormatColor(ext),
                              size: 36,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sanitizedFileName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Format: ${ext.toUpperCase()} â€¢ Size: ${_formatBytes(file.size)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'â‰¤ 3MB Limit OK',
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

                      // Document Title with Inline Error (matches UnifiedEnrollStudentDialog style)
                      Text(
                        'Document Title *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: titleController,
                        enabled: !isUploading,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Document title is required.';
                          }
                          return null;
                        },
                        decoration: _buildInputDecoration(
                          theme: theme,
                          hint: 'e.g. Lesson 1: Introduction to Functions',
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Destination Folder with Inline Error
                      Text(
                        'Destination Folder *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<ClassRealmFolder>(
                        initialValue: targetFolder,
                        isExpanded: true,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (v) {
                          if (v == null) {
                            return 'Please select a destination folder.';
                          }
                          return null;
                        },
                        decoration: _buildInputDecoration(
                          theme: theme,
                          hint: 'Select destination folder',
                        ),
                        items: _folders.map((f) {
                          return DropdownMenuItem(
                            value: f,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.folder_outlined,
                                  size: 18,
                                  color: Colors.amber,
                                ),
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
                        onChanged: isUploading
                            ? null
                            : (val) {
                                setModalState(() => targetFolder = val);
                              },
                      ),
                      const SizedBox(height: 14),

                      // Description / Teacher notes
                      Text(
                        'Lesson Content / Study Notes (Optional)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: descController,
                        enabled: !isUploading,
                        maxLines: 3,
                        maxLength: 50000,
                        decoration: _buildInputDecoration(
                          theme: theme,
                          hint: 'Enter study guide or student notes...',
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Student Visibility Switch
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Visible to Enrolled Students',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          isVisibleToStudents
                              ? 'Live mode: Students can view and download immediately.'
                              : 'Draft mode: Only visible to you until made live.',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        value: isVisibleToStudents,
                        activeThumbColor: Colors.green,
                        onChanged: isUploading
                            ? null
                            : (val) => setModalState(
                                () => isVisibleToStudents = val,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isUploading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        inModalUploadError != null
                            ? Icons.refresh
                            : Icons.cloud_upload,
                      ),
                label: Text(
                  isUploading
                      ? 'Uploading...'
                      : (inModalUploadError != null
                            ? 'Retry Upload'
                            : 'Upload Document'),
                ),
                onPressed: isUploading
                    ? null
                    : () async {
                        // Validate form fields inline: NO bottom banner!
                        if (!formKey.currentState!.validate()) {
                          return;
                        }

                        setModalState(() {
                          isUploading = true;
                          inModalUploadError = null;
                        });

                        try {
                          await _materialRepo.uploadMaterial(
                            folderId: targetFolder!.id,
                            subjectOfferingId: offeringId,
                            fileName: sanitizedFileName,
                            fileBytes: nonNullBytes,
                            fileSizeBytes: file.size,
                            mimeType: MaterialFileValidator.getMimeType(
                              sanitizedFileName,
                            ),
                            title: titleController.text.trim(),
                            description: descController.text.trim(),
                            isVisibleToStudents: isVisibleToStudents,
                          );

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          await _loadFolderContents();
                        } catch (e) {
                          if (ctx.mounted) {
                            setModalState(() {
                              isUploading = false;
                              inModalUploadError =
                                  'Upload failed: $e. Your inputs are saved. Click "Retry Upload" to try again.';
                            });
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Create Folder Dialog with Inline Error Messages (No bottom banners!) ---
  Future<void> _showCreateFolderDialog() async {
    if (_selectedOffering == null) return;
    final folderController = TextEditingController();
    bool isVisible = true;
    final formKey = GlobalKey<FormState>();

    final subjectName = _selectedOffering!['subject_name'] ?? 'Subject';
    final gradeLevel = _selectedOffering!['grade_level'] ?? 11;
    final sectionName = _formatSectionName(_selectedOffering!['section_name']);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.create_new_folder_outlined,
                  color: Colors.amber,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Create New Folder',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adding to: Grade $gradeLevel â€¢ $subjectName â€” $sectionName',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Folder Name *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: folderController,
                      autofocus: true,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Folder name is required.';
                        }
                        return null;
                      },
                      decoration: _buildInputDecoration(
                        theme: theme,
                        hint: 'e.g. Chapter 4 Additional Exercises',
                      ),
                    ),
                    const SizedBox(height: 14),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Visible to Students',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Students can browse contents of this folder',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: isVisible,
                      activeThumbColor: Colors.green,
                      onChanged: (v) => setModalState(() => isVisible = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }
                  final name = folderController.text.trim();
                  Navigator.pop(ctx);

                  setState(() => _isLoading = true);
                  try {
                    await _materialRepo.createFolder(
                      subjectOfferingId: _selectedOffering!['id'] as String,
                      folderName: name,
                      parentFolderId: _currentFolder?.id,
                      isVisibleToStudents: isVisible,
                    );
                    await _loadFolderContents();
                  } catch (e) {
                    setState(() => _isLoading = false);
                    _showFeedbackModal(
                      'Error',
                      'Failed to create folder: $e',
                      isError: true,
                    );
                  }
                },
                child: const Text('Create Folder'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Archive & Delete Confirmations for Folders ---
  Future<void> _deleteFolderPermanentlyConfirm(ClassRealmFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text('Permanently Delete Folder?'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${folder.folderName}" from the school system?\n\n'
          'This will completely remove the folder and all its child documents. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _materialRepo.deleteFolder(folder.id);
        await _loadFolderContents();
      } catch (e) {
        setState(() => _isLoading = false);
        _showFeedbackModal(
          'Error',
          'Failed to permanently delete folder: $e',
          isError: true,
        );
      }
    }
  }

  // --- Archive & Delete Confirmations for Materials ---
  Future<void> _archiveMaterialConfirm(ClassRealmMaterial material) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.archive_outlined, color: Colors.orange, size: 22),
            SizedBox(width: 8),
            Text('Archive Material?'),
          ],
        ),
        content: Text(
          'Archiving "${material.displayName}" will hide it from students and move it to the Archived Items view.\n\nYou can restore it anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive Material'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _materialRepo.archiveMaterial(material.id);
        await _loadFolderContents();
      } catch (e) {
        setState(() => _isLoading = false);
        _showFeedbackModal(
          'Error',
          'Failed to archive material: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _deleteMaterialPermanentlyConfirm(
    ClassRealmMaterial material,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text('Permanently Delete Material?'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${material.displayName}" from the school system?\n\n'
          'This will completely erase the material record and cloud file. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _materialRepo.deleteMaterialReferenceCounted(
          materialId: material.id,
          storagePathUrl: material.storagePathUrl,
        );
        await _loadFolderContents();
      } catch (e) {
        setState(() => _isLoading = false);
        _showFeedbackModal(
          'Error',
          'Failed to permanently delete material: $e',
          isError: true,
        );
      }
    }
  }

  // --- Restore Actions from Archive View ---
  Future<void> _restoreFolder(ClassRealmFolder folder) async {
    setState(() => _isLoading = true);
    try {
      await _materialRepo.restoreFolder(folder.id);
      await _loadFolderContents();
    } catch (e) {
      setState(() => _isLoading = false);
      _showFeedbackModal(
        'Error',
        'Failed to restore folder: $e',
        isError: true,
      );
    }
  }

  Future<void> _restoreMaterial(ClassRealmMaterial material) async {
    setState(() => _isLoading = true);
    try {
      await _materialRepo.restoreMaterial(material.id);
      await _loadFolderContents();
    } catch (e) {
      setState(() => _isLoading = false);
      _showFeedbackModal(
        'Error',
        'Failed to restore material: $e',
        isError: true,
      );
    }
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
    } catch (e) {
      _showFeedbackModal(
        'Error',
        'Failed to update visibility: $e',
        isError: true,
      );
    }
  }

  void _openInAppViewerAndEditor(ClassRealmMaterial material) {
    if (_selectedOffering == null) return;
    TeacherMaterialViewerModal.show(
      context: context,
      material: material,
      availableFolders: _folders,
      currentOfferingId: _selectedOffering!['id'] as String,
      onMaterialUpdated: (updatedMat) {
        setState(() {
          final idx = _materials.indexWhere((m) => m.id == updatedMat.id);
          if (idx != -1) {
            _materials[idx] = updatedMat;
          }
        });
      },
      onMaterialDeleted: () {
        _loadFolderContents();
      },
    );
  }

  void _showFeedbackModal(
    String title,
    String message, {
    required bool isError,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
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

  // Input decoration matching Screenshot 4 with inline red error styling
  InputDecoration _buildInputDecoration({
    required ThemeData theme,
    required String hint,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: theme.colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      errorStyle: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
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

    if (_isLoading && (_offerings.isEmpty)) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: ShimmerLoading(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top filter bar skeleton
              Row(
                children: const [
                  ShimmerBox(width: 100, height: 38, borderRadius: 8),
                  SizedBox(width: 10),
                  ShimmerBox(width: 220, height: 38, borderRadius: 8),
                  SizedBox(width: 10),
                  ShimmerBox(width: 140, height: 38, borderRadius: 8),
                ],
              ),
              const SizedBox(height: 24),
              // List items skeleton
              Expanded(
                child: ListView.separated(
                  itemCount: 4,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, _) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.08,
                        ),
                      ),
                    ),
                    child: Row(
                      children: const [
                        ShimmerBox(width: 32, height: 32, borderRadius: 8),
                        SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 200, height: 16, borderRadius: 4),
                            SizedBox(height: 6),
                            ShimmerBox(width: 80, height: 12, borderRadius: 4),
                          ],
                        ),
                        Spacer(),
                        ShimmerBox(width: 24, height: 24, borderRadius: 6),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_offerings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_off_outlined,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Classes with Enrolled Students Found',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Learning materials can only be managed for classes that have actively enrolled students.\nPlease enroll students in "Manage Students" or "Classroom Setup" first.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Safely guarantee cascading selection hierarchy
    final availableGrades = _availableGrades;
    if (_selectedGrade == null || !availableGrades.contains(_selectedGrade)) {
      _selectedGrade = availableGrades.isNotEmpty
          ? availableGrades.first
          : null;
    }
    final activeGrade = _selectedGrade ?? 11;

    final availableSubjects = _availableSubjects;
    if (_selectedSubject == null ||
        !availableSubjects.contains(_selectedSubject)) {
      _selectedSubject = availableSubjects.isNotEmpty
          ? availableSubjects.first
          : null;
    }
    final activeSubject = _selectedSubject ?? 'Subject';

    final availableSections = _availableSections;
    if (_selectedOffering == null ||
        !availableSections.contains(_selectedOffering)) {
      _selectedOffering = availableSections.isNotEmpty
          ? availableSections.first
          : null;
    }
    final activeSection = _formatSectionName(
      _selectedOffering?['section_name'],
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Workspace Bar: Grade Level, Subject, Section Dropdowns & Archive Toggle
          _buildTopHeader(theme, activeGrade, activeSubject, activeSection),

          const SizedBox(height: 16),

          // Breadcrumbs & View Controls
          _buildBreadcrumbsAndControls(
            theme,
            activeGrade,
            activeSubject,
            activeSection,
          ),

          const SizedBox(height: 12),

          // Search & Filter Bar (PDF, Word, PowerPoint)
          _buildSearchAndFilters(theme),

          const SizedBox(height: 16),

          // Main Drive Browser Area
          Expanded(
            child: _isLoading
                ? ShimmerLoading(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: 4,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, _) => Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.08,
                            ),
                          ),
                        ),
                        child: Row(
                          children: const [
                            ShimmerBox(width: 32, height: 32, borderRadius: 8),
                            SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShimmerBox(
                                  width: 180,
                                  height: 16,
                                  borderRadius: 4,
                                ),
                                SizedBox(height: 6),
                                ShimmerBox(
                                  width: 80,
                                  height: 12,
                                  borderRadius: 4,
                                ),
                              ],
                            ),
                            Spacer(),
                            ShimmerBox(width: 24, height: 24, borderRadius: 6),
                            SizedBox(width: 10),
                            ShimmerBox(width: 24, height: 24, borderRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadFolderContents,
                    child: _isViewingArchived
                        ? _buildArchivedView(
                            theme,
                            activeGrade,
                            activeSubject,
                            activeSection,
                          )
                        : _buildDriveContent(theme),
                  ),
          ),
        ],
      ),
    );
  }

  // --- Top Header with 3 Cascading Dropdowns: Grade Level, Subject, Section ---
  Widget _buildTopHeader(
    ThemeData theme,
    int activeGrade,
    String activeSubject,
    String activeSection,
  ) {
    final availableGrades = _availableGrades;
    final availableSubjects = _availableSubjects;
    final availableSections = _availableSections;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // 1. Grade Level Dropdown (NO ALL GRADES)
          if (availableGrades.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: availableGrades.contains(_selectedGrade)
                      ? _selectedGrade
                      : availableGrades.first,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                  ),
                  items: availableGrades.map((g) {
                    return DropdownMenuItem(value: g, child: Text('Grade $g'));
                  }).toList(),
                  onChanged: (val) {
                    if (val == null || val == _selectedGrade) return;
                    setState(() {
                      _selectedGrade = val;
                      final subs = _availableSubjects;
                      _selectedSubject = subs.isNotEmpty ? subs.first : null;
                      final secs = _availableSections;
                      _selectedOffering = secs.isNotEmpty ? secs.first : null;
                      _folderStack.clear();
                      _currentFolder = null;
                    });
                    _loadFolderContents();
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // 2. Subject Dropdown (NO All Subjects)
          if (availableSubjects.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: availableSubjects.contains(_selectedSubject)
                      ? _selectedSubject
                      : availableSubjects.first,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                  items: availableSubjects.map((name) {
                    return DropdownMenuItem(
                      value: name,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val == null || val == _selectedSubject) return;
                    setState(() {
                      _selectedSubject = val;
                      final secs = _availableSections;
                      _selectedOffering = secs.isNotEmpty ? secs.first : null;
                      _folderStack.clear();
                      _currentFolder = null;
                    });
                    _loadFolderContents();
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // 3. Section Dropdown
          if (availableSections.isNotEmpty) ...[
            SizedBox(
              width: 170,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    value: availableSections.contains(_selectedOffering)
                        ? _selectedOffering
                        : availableSections.first,
                    isExpanded: true,
                    items: availableSections.map((offering) {
                      final secName = _formatSectionName(
                        offering['section_name'],
                      );
                      return DropdownMenuItem(
                        value: offering,
                        child: Text(
                          secName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
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
            ),
            const Spacer(),
          ] else ...[
            const Spacer(),
          ],

          const SizedBox(width: 12),

          // 4. Archive View Toggle Button (Like Classroom Setup)
          OutlinedButton.icon(
            icon: Icon(
              _isViewingArchived ? Icons.arrow_back : Icons.archive_outlined,
              size: 16,
            ),
            label: Text(
              _isViewingArchived
                  ? 'Active Materials'
                  : 'Archived Items ($_archivedCount)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              foregroundColor: _isViewingArchived
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
              side: BorderSide(
                color: _isViewingArchived
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              setState(() {
                _isViewingArchived = !_isViewingArchived;
              });
              _loadFolderContents();
            },
          ),

          // 5. Upload Document Button (Single action, NO redundant dropdown menu!)
          if (!_isViewingArchived) ...[
            const SizedBox(width: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text(
                'Upload Document',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _showUploadFileDialog,
            ),
          ],
        ],
      ),
    );
  }

  // --- Breadcrumbs & Controls ---
  Widget _buildBreadcrumbsAndControls(
    ThemeData theme,
    int activeGrade,
    String activeSubject,
    String activeSection,
  ) {
    if (_isViewingArchived) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.archive_outlined, size: 18, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'Archived Items â€” Grade $activeGrade â€¢ $activeSubject ($activeSection)',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      );
    }

    final isParentFolderHidden =
        _currentFolder != null && !_currentFolder!.isVisibleToStudents;

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
                      fontWeight: _folderStack.isEmpty
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: _folderStack.isEmpty
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
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
                    fontWeight: i == _folderStack.length - 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: i == _folderStack.length - 1
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],

          if (isParentFolderHidden) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_off,
                    size: 12,
                    color: Colors.amber.shade900,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Hidden from students',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),

          // New Folder Button
          TextButton.icon(
            icon: const Icon(
              Icons.create_new_folder_outlined,
              size: 18,
              color: Colors.amber,
            ),
            label: const Text('New Folder', style: TextStyle(fontSize: 13)),
            onPressed: _showCreateFolderDialog,
          ),

          const SizedBox(width: 8),

          // Grid / List View Toggle
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list : Icons.grid_view,
              size: 20,
            ),
            tooltip: _isGridView
                ? 'Switch to List View'
                : 'Switch to Grid View',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
    );
  }

  // --- Search & Filter Bar (Only standard document types: PDF, Word, PowerPoint) ---
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
                borderSide: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
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

  // --- Drive Browser Content (Active Folders and Files) ---
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
              Icon(
                Icons.cloud_upload_outlined,
                size: 56,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 12),
              const Text(
                'This folder is empty',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Upload PDF, Word, or PowerPoint documents to share with your students.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Document Now'),
                onPressed: _showUploadFileDialog,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: [
        // Folders Section (Term 1, Term 2, Term 3, Supplementary Handouts guaranteed first)
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
                    maxCrossAxisExtent: 290,
                    mainAxisExtent: 96,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: folders.length,
                  itemBuilder: (ctx, i) => _buildFolderCard(folders[i], theme),
                )
              : Column(
                  children: folders
                      .map((f) => _buildFolderListRow(f, theme))
                      .toList(),
                ),
          const SizedBox(height: 24),
        ],

        // Files Section
        if (files.isNotEmpty) ...[
          Text(
            'DOCUMENTS (${files.length})',
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
                  children: files
                      .map((f) => _buildFileListRow(f, theme))
                      .toList(),
                ),
        ],
      ],
    );
  }

  // --- Archived View (Matches Classroom Setup pattern) ---
  Widget _buildArchivedView(
    ThemeData theme,
    int activeGrade,
    String activeSubject,
    String activeSection,
  ) {
    final archivedF = _filteredArchivedFolders;
    final archivedM = _filteredArchivedMaterials;

    if (archivedF.isEmpty && archivedM.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.archive_outlined,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Archived Items',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Folders and materials you archive will be stored here safely.\nYou can restore them to active status anytime or delete them permanently from the school system.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: [
        if (archivedF.isNotEmpty) ...[
          Text(
            'ARCHIVED FOLDERS (${archivedF.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 10),
          Column(
            children: archivedF.map((folder) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.folder_zip_outlined,
                    color: Colors.orange,
                    size: 28,
                  ),
                  title: Text(
                    folder.folderName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${folder.fileCount} items â€¢ Archived (Hidden from students)',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Restore button
                      Tooltip(
                        message: 'Restore Folder to Active',
                        child: TextButton.icon(
                          icon: const Icon(
                            Icons.unarchive_outlined,
                            size: 16,
                            color: Colors.green,
                          ),
                          label: const Text(
                            'Restore',
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          ),
                          onPressed: () => _restoreFolder(folder),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Permanent delete button
                      Tooltip(
                        message: 'Permanently Delete Folder',
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete_forever,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () =>
                              _deleteFolderPermanentlyConfirm(folder),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        if (archivedM.isNotEmpty) ...[
          Text(
            'ARCHIVED DOCUMENTS (${archivedM.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 10),
          Column(
            children: archivedM.map((mat) {
              final ext = mat.fileExtension;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: ListTile(
                  leading: Icon(
                    _getFormatIcon(ext),
                    color: _getFormatColor(ext),
                    size: 28,
                  ),
                  title: Text(
                    mat.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${mat.fileName} â€¢ ${mat.formattedSize} â€¢ Archived',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Restore button
                      Tooltip(
                        message: 'Restore Document to Active',
                        child: TextButton.icon(
                          icon: const Icon(
                            Icons.unarchive_outlined,
                            size: 16,
                            color: Colors.green,
                          ),
                          label: const Text(
                            'Restore',
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          ),
                          onPressed: () => _restoreMaterial(mat),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Permanent delete button
                      Tooltip(
                        message: 'Permanently Delete Material',
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete_forever,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () =>
                              _deleteMaterialPermanentlyConfirm(mat),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // --- Folder Widgets with Archive and Permanent Delete Actions ---
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
            color: folder.isVisibleToStudents
                ? theme.colorScheme.onSurface.withValues(alpha: 0.1)
                : Colors.amber.withValues(alpha: 0.4),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${folder.fileCount} items',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      if (!folder.isVisibleToStudents) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Hidden',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
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
        side: BorderSide(
          color: folder.isVisibleToStudents
              ? theme.colorScheme.onSurface.withValues(alpha: 0.1)
              : Colors.amber.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        leading: const Icon(Icons.folder, color: Colors.amber, size: 28),
        title: Text(
          folder.folderName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${folder.fileCount} items ${folder.isVisibleToStudents ? "" : "â€¢ Hidden from students"}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _navigateToFolder(folder),
      ),
    );
  }

  // --- File Widgets (Opening In-App Viewer Modal) ---
  Widget _buildFileCard(ClassRealmMaterial material, ThemeData theme) {
    final ext = material.fileExtension;
    final isVisible = material.isVisibleToStudents;

    return InkWell(
      onTap: () => _openInAppViewerAndEditor(material),
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
                Icon(
                  _getFormatIcon(ext),
                  color: _getFormatColor(ext),
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    material.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                // Visibility Toggle Badge
                Tooltip(
                  message: isVisible
                      ? 'Live: Visible to students. Click to hide.'
                      : 'Draft: Hidden from students. Click to publish.',
                  child: InkWell(
                    onTap: () => _toggleMaterialVisibility(material),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
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
                            color: isVisible
                                ? Colors.green
                                : Colors.amber.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVisible ? 'Live' : 'Draft',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isVisible
                                  ? Colors.green
                                  : Colors.amber.shade900,
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
                  '${material.formattedSize} â€¢ ${_formatDate(material.createdAt)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const Spacer(),
                // Archive button
                IconButton(
                  icon: const Icon(
                    Icons.archive_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
                  tooltip: 'Archive Material',
                  onPressed: () => _archiveMaterialConfirm(material),
                ),
                // Delete button
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Colors.redAccent,
                  ),
                  tooltip: 'Delete Permanently from Database',
                  onPressed: () => _deleteMaterialPermanentlyConfirm(material),
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
        side: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        leading: Icon(
          _getFormatIcon(ext),
          color: _getFormatColor(ext),
          size: 28,
        ),
        title: Text(
          material.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(
          '${material.fileName} â€¢ ${material.formattedSize} â€¢ ${_formatDate(material.createdAt)}',
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
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
                  color: isVisible
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.amber.withValues(alpha: 0.2),
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
            // Archive action
            IconButton(
              icon: const Icon(
                Icons.archive_outlined,
                color: Colors.grey,
                size: 20,
              ),
              tooltip: 'Archive Material',
              onPressed: () => _archiveMaterialConfirm(material),
            ),
            // Delete action
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: 20,
              ),
              tooltip: 'Delete Material Permanently',
              onPressed: () => _deleteMaterialPermanentlyConfirm(material),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _openInAppViewerAndEditor(material),
      ),
    );
  }

  // --- Helper formatters & icons ---
  IconData _getFormatIcon(String ext) {
    final e = ext.toLowerCase();
    if (e == 'pdf') return Icons.picture_as_pdf;
    if (e == 'doc' || e == 'docx') return Icons.description;
    if (e == 'ppt' || e == 'pptx') return Icons.slideshow;
    return Icons.insert_drive_file;
  }

  Color _getFormatColor(String ext) {
    final e = ext.toLowerCase();
    if (e == 'pdf') return Colors.red.shade600;
    if (e == 'doc' || e == 'docx') return Colors.blue.shade600;
    if (e == 'ppt' || e == 'pptx') return Colors.orange.shade700;
    return Colors.blueGrey;
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
