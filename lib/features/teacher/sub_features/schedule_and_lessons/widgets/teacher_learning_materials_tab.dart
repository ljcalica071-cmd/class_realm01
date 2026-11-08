import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/core/utils/file_download_helper.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/learning_material_repository.dart';
import 'package:class_realm/data/repositories/supabase_learning_material_repository.dart';

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
        _errorMessage =
            'Please log in as a teacher to manage learning materials.';
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

  static final List<ClassRealmFolder> _defaultPlaceholderFolders = [
    ClassRealmFolder(
      id: 'placeholder_term_1',
      subjectOfferingId: '',
      folderName: 'Term 1 - First Quarter',
      createdAt: DateTime.now(),
      fileCount: 0,
    ),
    ClassRealmFolder(
      id: 'placeholder_term_2',
      subjectOfferingId: '',
      folderName: 'Term 2 - Second Quarter',
      createdAt: DateTime.now(),
      fileCount: 0,
    ),
    ClassRealmFolder(
      id: 'placeholder_term_3',
      subjectOfferingId: '',
      folderName: 'Term 3 - Third Quarter',
      createdAt: DateTime.now(),
      fileCount: 0,
    ),
    ClassRealmFolder(
      id: 'placeholder_term_handouts',
      subjectOfferingId: '',
      folderName: 'Supplementary Handouts & Reviewers',
      createdAt: DateTime.now(),
      fileCount: 0,
    ),
  ];

  void _navigateToFolder(ClassRealmFolder folder) {
    if (_selectedOffering == null) {
      _showFeedbackModal(
        'Class Setup Required',
        'Learning materials can only be managed for classes that have actively enrolled students. Please set up subjects and enroll students in Classroom Setup first.',
        isError: false,
      );
      return;
    }
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
    final list = _folders.isNotEmpty
        ? _folders
        : (_offerings.isEmpty ? _defaultPlaceholderFolders : <ClassRealmFolder>[]);
    if (list.isEmpty) return [];
    if (_searchQuery.isEmpty) return list;
    return list
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
    if (_selectedOffering == null) {
      _showFeedbackModal(
        'Class Setup Required',
        'Learning materials can only be uploaded for classes that have actively enrolled students. Please set up subjects and enroll students in Classroom Setup first.',
        isError: false,
      );
      return;
    }

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

    // Strict 15MB size cap and magic-byte checks
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
                                'Target Class: Grade $gradeLevel • $subjectName — $sectionName',
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
                                    'Format: ${ext.toUpperCase()} • Size: ${_formatBytes(file.size)}',
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
                                '<= 15MB Limit OK',
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
                        maxLength: 100,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Document title is required.';
                          }
                          if (v.trim().length > 100) {
                            return 'Document title cannot exceed 100 characters.';
                          }
                          return null;
                        },
                        decoration: _buildInputDecoration(
                          theme: theme,
                          hint: 'e.g. Lesson 1: Introduction to Functions (max 100 chars)',
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Direct Destination Folder indicator (No dropdown as requested)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
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
                            const Icon(
                              Icons.folder,
                              size: 18,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Destination Folder',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  Text(
                                    targetFolder?.folderName ?? 'Current Folder',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Description / Teacher notes (max 100 chars)
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
                        maxLength: 100,
                        decoration: _buildInputDecoration(
                          theme: theme,
                          hint: 'Enter study guide or student notes (max 100 characters)...',
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
                          ClassRealmFolder? resolvedFolder = targetFolder;
                          if (resolvedFolder == null) {
                            await _materialRepo.ensureDefaultTermFolders(
                              offeringId,
                            );
                            final refreshedFolders = await _materialRepo
                                .getFolders(subjectOfferingId: offeringId);
                            if (refreshedFolders.isNotEmpty) {
                              resolvedFolder = refreshedFolders.first;
                            } else {
                              resolvedFolder = await _materialRepo.createFolder(
                                subjectOfferingId: offeringId,
                                folderName: 'General Materials',
                              );
                            }
                          }

                          await _materialRepo.uploadMaterial(
                            folderId: resolvedFolder.id,
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
                                  getUserFriendlyUploadErrorMessage(e);
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
    if (_selectedOffering == null) {
      _showFeedbackModal(
        'Class Setup Required',
        'Folders can only be created for classes that have actively enrolled students. Please set up subjects and enroll students in Classroom Setup first.',
        isError: false,
      );
      return;
    }
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
                      'Adding to: Grade $gradeLevel • $subjectName — $sectionName',
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
      barrierDismissible: false,
      builder: (ctx) => _PermanentDeleteConfirmDialog(
        title: 'Permanently Delete Folder?',
        itemName: folder.folderName,
        details:
            'This will permanently delete the folder "${folder.folderName}" and all of its ${folder.fileCount} materials from the school system.\n\nOnce deleted, these files and folders cannot be recovered.',
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
      barrierDismissible: false,
      builder: (ctx) => _ArchiveCooldownDialog(
        title: 'Archive Material?',
        content:
            'Archiving "${material.displayName}" will hide it from students and move it to the Archived Items view.\n\nYou can restore it to active status anytime.',
        actionLabel: 'Archive Material',
        actionColor: Colors.orange.shade800,
        icon: Icons.archive_outlined,
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
      barrierDismissible: false,
      builder: (ctx) => _PermanentDeleteConfirmDialog(
        title: 'Permanently Delete Material?',
        itemName: material.displayName,
        details:
            'This will permanently erase "${material.displayName}" (${material.fileName}, ${material.formattedSize}) from the school database and purge the physical file from cloud storage.\n\nAll student reading logs and access history linked to this document will be permanently deleted and cannot be recovered.',
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

  // --- Storage Quota & User-Friendly Errors ---
  int get _totalStorageBytes {
    final activeBytes =
        _materials.fold<int>(0, (acc, m) => acc + m.fileSizeBytes);
    final archivedBytes =
        _archivedMaterials.fold<int>(0, (acc, m) => acc + m.fileSizeBytes);
    return activeBytes + archivedBytes;
  }

  static String getUserFriendlyUploadErrorMessage(dynamic error) {
    final errStr = error.toString().toLowerCase();

    // 1. Storage Quota Exceeded / Bucket Full
    if (errStr.contains('quota') ||
        errStr.contains('storage limit') ||
        errStr.contains('insufficient_storage') ||
        errStr.contains('bucket full') ||
        errStr.contains('507') ||
        errStr.contains('exceeded your project') ||
        errStr.contains('resource limit')) {
      return 'Cloud Storage Full: The school\'s cloud storage capacity has reached its limit. Please notify your administrator to free up space or upgrade storage before uploading new materials.';
    }

    // 2. File size / Payload too large
    if (errStr.contains('413') ||
        errStr.contains('payload too large') ||
        errStr.contains('file too large') ||
        errStr.contains('maximum size')) {
      return 'File Too Large: The selected file exceeds the allowable upload size. Please choose a file smaller than 15 MB.';
    }

    // 3. Network or timeout issues
    if (errStr.contains('timeout') ||
        errStr.contains('socketexception') ||
        errStr.contains('network') ||
        errStr.contains('clientexception') ||
        errStr.contains('failed host lookup')) {
      return 'Connection Interrupted: Unable to connect to the server. Please check your internet connection and click "Retry Upload".';
    }

    // 4. Unauthorized / Permission
    if (errStr.contains('unauthorized') ||
        errStr.contains('permission denied') ||
        errStr.contains('row-level security') ||
        errStr.contains('policy') ||
        errStr.contains('403') ||
        errStr.contains('jwt')) {
      return 'Access Denied: You do not have permission to upload materials to this subject offering. Please make sure you are signed in as the assigned teacher.';
    }

    // 5. Duplicate filename / Conflict
    if (errStr.contains('duplicate') ||
        errStr.contains('already exists') ||
        errStr.contains('conflict') ||
        errStr.contains('409')) {
      return 'A document with this file name already exists in this folder. Please rename the file before uploading.';
    }

    // Fallback friendly message (NO raw technical stack traces)
    return 'Upload Encountered an Issue: We could not finish uploading your file right now. Your inputs have been kept intact—please try clicking "Retry Upload".';
  }

  // --- Material URL & Direct View / Download ---
  final Set<String> _openingIds = {};
  final Set<String> _downloadingIds = {};

  Future<String?> _resolveMaterialUrl(ClassRealmMaterial material) async {
    final raw = material.storagePathUrl;
    var path = raw.contains('/learning_materials/')
        ? raw.split('/learning_materials/').last
        : raw;
    if (path.contains('?')) {
      path = path.split('?').first;
    }
    path = Uri.decodeComponent(path).trim();
    if (path.isEmpty) return null;

    try {
      final url = await SupabaseService().adminClient.storage
          .from('learning_materials')
          .createSignedUrl(path, 60 * 60);
      return url;
    } catch (e) {
      debugPrint('Failed to create signed URL: $e');
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        return raw;
      }
      return null;
    }
  }

  Future<void> _viewMaterial(ClassRealmMaterial material) async {
    if (_openingIds.contains(material.id)) return;
    setState(() => _openingIds.add(material.id));

    try {
      final resolvedUrl = await _resolveMaterialUrl(material);
      if (resolvedUrl == null || resolvedUrl.isEmpty) {
        if (!mounted) return;
        _showFeedbackModal(
          'Error',
          'Material file link is not available.',
          isError: true,
        );
        return;
      }

      final ext = material.fileExtension.toLowerCase();
      final isOfficeDoc =
          ext == 'doc' || ext == 'docx' || ext == 'ppt' || ext == 'pptx';

      Uri targetUri = Uri.parse(resolvedUrl);

      if (kIsWeb && isOfficeDoc) {
        // In Web browsers, doc/docx/ppt/pptx cannot be natively viewed without downloading.
        // Google Docs Viewer renders it inline in a new tab without downloading.
        targetUri = Uri.parse(
          'https://docs.google.com/viewer?url=${Uri.encodeComponent(resolvedUrl)}&embedded=true',
        );
      }

      bool launched = false;
      if (kIsWeb) {
        launched = await launchUrl(targetUri, webOnlyWindowName: '_blank');
      } else {
        // Native App (Android / iOS):
        // 1. Try launching in external application (e.g. Acrobat Reader, Word, Drive)
        try {
          launched =
              await launchUrl(targetUri, mode: LaunchMode.externalApplication);
        } catch (_) {}

        // 2. Fallback: If no external app is installed or handler fails, open via in-app browser overlay
        if (!launched) {
          try {
            final inAppUri = isOfficeDoc
                ? Uri.parse(
                    'https://docs.google.com/viewer?url=${Uri.encodeComponent(resolvedUrl)}&embedded=true',
                  )
                : targetUri;
            launched =
                await launchUrl(inAppUri, mode: LaunchMode.inAppBrowserView);
          } catch (_) {}
        }

        // 3. Last-resort fallback to platform default
        if (!launched) {
          launched =
              await launchUrl(targetUri, mode: LaunchMode.platformDefault);
        }
      }

      if (!launched && mounted) {
        _showFeedbackModal(
          'Notice',
          'Unable to open file in browser or default viewer.',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackModal('Error', 'Failed to open file: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _openingIds.remove(material.id));
      }
    }
  }

  Future<void> _downloadMaterial(ClassRealmMaterial material) async {
    if (_downloadingIds.contains(material.id)) return;
    setState(() => _downloadingIds.add(material.id));

    try {
      final resolvedUrl = await _resolveMaterialUrl(material);
      if (resolvedUrl == null || resolvedUrl.isEmpty) {
        if (!mounted) return;
        _showFeedbackModal('Error', 'Material file link is not available for download.', isError: true);
        return;
      }

      final extension = material.fileExtension.toLowerCase();
      final sanitizedFileName = material.fileName.isNotEmpty
          ? material.fileName
          : '${material.displayName}.$extension';

      final response = await http.get(Uri.parse(resolvedUrl));
      if (response.statusCode == 200) {
        final result = await FileDownloadHelper.downloadBytes(
          bytes: response.bodyBytes,
          fileName: sanitizedFileName,
          extension: extension,
          mimeType: material.mimeType ?? 'application/octet-stream',
        );

        if (mounted && result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await launchUrl(Uri.parse(resolvedUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackModal('Download Error', '$e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingIds.remove(material.id));
      }
    }
  }

  void _showFeedbackModal(
    String title,
    String message, {
    required bool isError,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isError ? Icons.error_outline : Icons.check_circle_outline,
                      color: isError ? Colors.red : Colors.green,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        ),
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

          if (_offerings.isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Learning materials can only be managed for classes that have actively enrolled students. Please enroll students in "Manage Students" or "Classroom Setup" first.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

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
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Grade Level',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ],
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
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Subject',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
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
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Section',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],

          const SizedBox(width: 12),

          // Cloud Storage Meter Indicator (1 GB Cap Monitoring)
          Builder(
            builder: (context) {
              final usedMb = _totalStorageBytes / (1024 * 1024);
              final isWarning = usedMb >= 800;
              final isCritical = usedMb >= 950;

              return Tooltip(
                message: isCritical
                    ? 'Cloud Storage Full (1 GB reached). Remove unused items to free space.'
                    : isWarning
                        ? 'Storage usage is high (${usedMb.toStringAsFixed(1)} MB / 1 GB).'
                        : 'Free-tier cloud storage usage: ${usedMb.toStringAsFixed(1)} MB of 1 GB used.',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCritical
                        ? Colors.red.withValues(alpha: 0.12)
                        : isWarning
                            ? Colors.amber.withValues(alpha: 0.15)
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCritical
                          ? Colors.red.withValues(alpha: 0.4)
                          : isWarning
                              ? Colors.amber.withValues(alpha: 0.4)
                              : theme.colorScheme.outline.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCritical
                            ? Icons.cloud_off
                            : isWarning
                                ? Icons.cloud_queue
                                : Icons.cloud_done,
                        size: 15,
                        color: isCritical
                            ? Colors.red
                            : isWarning
                                ? Colors.amber.shade800
                                : const Color(0xFF3A6B88),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Storage: ${usedMb.toStringAsFixed(1)} MB / 1 GB',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isCritical
                              ? Colors.red
                              : isWarning
                                  ? Colors.amber.shade900
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 10),

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
              'Archived Items — Grade $activeGrade • $activeSubject ($activeSection)',
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
                    _selectedOffering != null
                        ? 'Grade $activeGrade ($activeSection)'
                        : 'Grade Level (No Active Class)',
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
                    '${folder.fileCount} items • Archived (Hidden from students)',
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
                    '${mat.fileName} • ${mat.formattedSize} • Archived',
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
          '${folder.fileCount} items ${folder.isVisibleToStudents ? "" : "• Hidden from students"}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _navigateToFolder(folder),
      ),
    );
  }

  // --- File Widgets (Direct View & Download, Archive without Delete Button) ---
  Widget _buildFileCard(ClassRealmMaterial material, ThemeData theme) {
    final ext = material.fileExtension;
    final isVisible = material.isVisibleToStudents;
    final isOpening = _openingIds.contains(material.id);
    final isDownloading = _downloadingIds.contains(material.id);

    return InkWell(
      onTap: () => _viewMaterial(material),
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
                if (isOpening)
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
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
                  '${material.formattedSize} • ${_formatDate(material.createdAt)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const Spacer(),
                // Direct Download button
                IconButton(
                  icon: isDownloading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.download_rounded,
                          size: 18,
                          color: Color(0xFF3A6B88),
                        ),
                  tooltip: 'Download File',
                  onPressed: () => _downloadMaterial(material),
                ),
                // Archive button (Active materials only have Archive, NO permanent delete)
                IconButton(
                  icon: const Icon(
                    Icons.archive_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                  tooltip: 'Archive Material',
                  onPressed: () => _archiveMaterialConfirm(material),
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
    final isOpening = _openingIds.contains(material.id);
    final isDownloading = _downloadingIds.contains(material.id);

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
        leading: isOpening
            ? const SizedBox(
                width: 28,
                height: 28,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Icon(
                _getFormatIcon(ext),
                color: _getFormatColor(ext),
                size: 28,
              ),
        title: Text(
          material.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(
          '${material.fileName} • ${material.formattedSize} • ${_formatDate(material.createdAt)}',
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
            // Direct download button
            IconButton(
              icon: isDownloading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.download_rounded,
                      color: Color(0xFF3A6B88),
                      size: 20,
                    ),
              tooltip: 'Download File',
              onPressed: () => _downloadMaterial(material),
            ),
            // Archive action (Active materials only have Archive, NO permanent delete)
            IconButton(
              icon: const Icon(
                Icons.archive_outlined,
                color: Colors.grey,
                size: 20,
              ),
              tooltip: 'Archive Material',
              onPressed: () => _archiveMaterialConfirm(material),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.open_in_new, size: 18, color: Colors.grey),
          ],
        ),
        onTap: () => _viewMaterial(material),
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

// ============================================================================
// ARCHIVE COOLDOWN DIALOG (5-Second Safety Countdown before Archive Action)
// ============================================================================
class _ArchiveCooldownDialog extends StatefulWidget {
  final String title;
  final String content;
  final String actionLabel;
  final Color actionColor;
  final IconData icon;

  const _ArchiveCooldownDialog({
    required this.title,
    required this.content,
    required this.actionLabel,
    required this.actionColor,
    required this.icon,
  });

  @override
  State<_ArchiveCooldownDialog> createState() => _ArchiveCooldownDialogState();
}

class _ArchiveCooldownDialogState extends State<_ArchiveCooldownDialog> {
  int _remainingSeconds = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = _remainingSeconds > 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          Icon(widget.icon, color: widget.actionColor, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.title)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.content,
            style: const TextStyle(fontSize: 13.5, height: 1.45),
          ),
          const SizedBox(height: 14),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isLocked ? Colors.orange.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isLocked ? Colors.orange.shade200 : Colors.green.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isLocked ? Icons.timer_outlined : Icons.check_circle_outline,
                  size: 16,
                  color: isLocked ? Colors.orange.shade800 : Colors.green.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isLocked
                        ? 'Safety Cooldown: Please review carefully. Archive unlocks in $_remainingSeconds second${_remainingSeconds > 1 ? 's' : ''}...'
                        : 'Cooldown complete. You may now confirm archiving.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isLocked ? Colors.orange.shade900 : Colors.green.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.actionColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade600,
          ),
          onPressed: isLocked ? null : () => Navigator.pop(context, true),
          child: Text(
            isLocked ? '${widget.actionLabel} ($_remainingSeconds s)' : widget.actionLabel,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// PERMANENT DELETE CONFIRM DIALOG (Requires typing "CONFIRM" like Maintenance Mode)
// ============================================================================
class _PermanentDeleteConfirmDialog extends StatefulWidget {
  final String title;
  final String itemName;
  final String details;

  const _PermanentDeleteConfirmDialog({
    required this.title,
    required this.itemName,
    required this.details,
  });

  @override
  State<_PermanentDeleteConfirmDialog> createState() =>
      _PermanentDeleteConfirmDialogState();
}

class _PermanentDeleteConfirmDialogState
    extends State<_PermanentDeleteConfirmDialog> {
  final _controller = TextEditingController();

  bool get _isConfirmed => _controller.text.trim().toUpperCase() == 'CONFIRM';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.delete_forever, color: Colors.red.shade700, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PERMANENT DATA ERASURE: This action is destructive and CANNOT be undone.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.details,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
                children: const [
                  TextSpan(text: 'To confirm permanent deletion, please type '),
                  TextSpan(
                    text: 'CONFIRM',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  TextSpan(text: ' in the box below:'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Type CONFIRM to proceed',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade600,
          ),
          onPressed: _isConfirmed ? () => Navigator.pop(context, true) : null,
          child: const Text('Delete Permanently'),
        ),
      ],
    );
  }
}
