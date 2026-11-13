import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/core/utils/file_download_helper.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/learning_material_repository.dart';
import 'package:class_realm/data/repositories/supabase_learning_material_repository.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/widgets/common/expandable_instructions_text.dart';

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

  // Enrolled subjects & active selection
  List<Map<String, dynamic>> _allEnrolledSubjects = [];
  Map<String, dynamic>? _selectedSubject;

  // Folders & Materials within active subject
  List<ClassRealmFolder> _folders = [];
  List<ClassRealmMaterial> _materials = [];
  ClassRealmFolder? _currentFolder;
  final List<ClassRealmFolder> _folderStack = [];

  // In-flight locks for debouncing
  final Set<String> _downloadingIds = {};
  final Set<String> _openingIds = {};

  // Offline cached files: materialId -> localPath
  Map<String, String> _offlineMaterialPaths = {};

  @override
  void initState() {
    super.initState();
    _loadOfflineMaterialPaths();
    _loadStudentEnrolledClasses();
  }

  Future<void> _loadOfflineMaterialPaths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString('student_offline_materials_map');
      if (rawJson != null && rawJson.isNotEmpty) {
        final decoded = json.decode(rawJson) as Map<String, dynamic>;
        final verified = <String, String>{};
        for (final entry in decoded.entries) {
          final path = entry.value.toString();
          if (kIsWeb) {
            verified[entry.key] = path;
          } else {
            if (File(path).existsSync()) {
              verified[entry.key] = path;
            }
          }
        }
        if (mounted) {
          setState(() {
            _offlineMaterialPaths = verified;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading offline material paths: $e');
    }
  }

  Future<void> _recordDownloadedMaterial(
    String materialId,
    String localPath,
  ) async {
    try {
      _offlineMaterialPaths[materialId] = localPath;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'student_offline_materials_map',
        json.encode(_offlineMaterialPaths),
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error recording downloaded material: $e');
    }
  }

  bool _isMaterialOfflineReady(String materialId) {
    final path = _offlineMaterialPaths[materialId];
    if (path == null) return false;
    if (kIsWeb) return true;
    return File(path).existsSync();
  }

  Future<void> _refreshScreen() async {
    if (_selectedSubject == null) {
      await _loadStudentEnrolledClasses(silent: true);
    } else {
      await _loadMaterialsForOffering(silent: true);
    }
  }

  Future<void> _loadStudentEnrolledClasses({bool silent = false}) async {
    setState(() {
      if (!silent) {
        _isLoading = true;
      }
      _errorMessage = null;
    });

    final user = AuthRepository.instance.currentUser;
    if (user == null || user.id.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Please log in as a student to view your learning materials.';
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
              teacher_profiles ( first_name, last_name ),
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
        final teacher = offering['teacher_profiles'] as Map<String, dynamic>?;

        final isSyCurrent = sy['is_current'] == true;
        final isOfferingArchived =
            offering['is_archived'] == true || sy['is_archived'] == true;
        final isPastOrArchived = !isSyCurrent || isOfferingArchived;

        // Skip archived or inactive school years unless none available
        if (isPastOrArchived) continue;

        // Clean section name (prevent "Section Section 1")
        final rawSec = sec['section_name']?.toString().trim() ?? '';
        final cleanSec = rawSec.isEmpty
            ? 'Section'
            : rawSec.toLowerCase().startsWith('section')
                ? rawSec
                : 'Section $rawSec';

        // Teacher full name
        String teacherName = '';
        if (teacher != null) {
          final first = teacher['first_name']?.toString().trim() ?? '';
          final last = teacher['last_name']?.toString().trim() ?? '';
          if (first.isNotEmpty || last.isNotEmpty) {
            teacherName = '$first $last'.trim();
          }
        }

        // Clean term name strictly using "Term"
        final termNum = term['term_number'] ?? offering['term_block'];
        final cleanTerm = termNum != null
            ? 'Term $termNum'
            : (term['term_name']?.toString().replaceAll(
                    RegExp(r'quarter', caseSensitive: false),
                    'Term',
                  ) ??
                'Term');

        mapped.add({
          'offering_id':
              offering['id']?.toString() ??
              e['subject_offering_id']?.toString() ??
              '',
          'subject_name': sub['subject_name']?.toString() ?? 'Subject',
          'subject_code': sub['subject_code']?.toString() ?? '',
          'grade_level': sub['grade_level'] ?? sec['grade_level'] ?? 11,
          'section_name': cleanSec,
          'teacher_name': teacherName,
          'term_name': cleanTerm,
          'school_year': sy['school_year']?.toString() ?? '',
          'is_irregular': e['is_irregular'] == true,
        });
      }

      // Sort alphabetically by subject code / name
      mapped.sort((a, b) {
        final codeComp = (a['subject_code'] as String).compareTo(
          b['subject_code'] as String,
        );
        if (codeComp != 0) return codeComp;
        return (a['subject_name'] as String).compareTo(
          b['subject_name'] as String,
        );
      });

      if (!mounted) return;
      setState(() {
        _allEnrolledSubjects = mapped;
        // Keep selected subject if it still exists in the refreshed list
        if (_selectedSubject != null) {
          final previousId = _selectedSubject!['offering_id'];
          final match = _allEnrolledSubjects.where(
            (s) => s['offering_id'] == previousId,
          );
          _selectedSubject = match.isNotEmpty ? match.first : null;
        }
        _isLoading = false;
      });

      if (_selectedSubject != null) {
        await _loadMaterialsForOffering(silent: silent);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent || _allEnrolledSubjects.isEmpty) {
          _errorMessage = 'Unable to load enrolled classes: $e';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMaterialsForOffering({bool silent = false}) async {
    if (_selectedSubject == null) {
      setState(() {
        _folders = [];
        _materials = [];
        _isLoading = false;
      });
      return;
    }

    final offeringId = _selectedSubject!['offering_id'] as String;
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      // 1. Ensure the 4 default term folders exist in Supabase DB for this offering
      if (_currentFolder == null) {
        await _materialRepo.ensureDefaultTermFolders(offeringId);
      }

      // 2. Fetch folders for this offering (strictly counting student-visible materials)
      final allFolders = await _materialRepo.getFolders(
        subjectOfferingId: offeringId,
        parentFolderId: _currentFolder?.id,
        studentOnly: true,
      );

      final visibleFolders = allFolders
          .where((f) => f.isVisibleToStudents && !f.isArchived)
          .toList();

      // 3. Fetch materials using hierarchical visibility check
      List<ClassRealmMaterial> visibleMaterials = [];
      if (_currentFolder != null) {
        final rawMaterials = await _materialRepo
            .getStudentMaterialsWithHierarchy(
              subjectOfferingId: offeringId,
              folderId: _currentFolder!.id,
            );

        // Deduplicate materials by storage_path_url and fileName
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
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent || (_folders.isEmpty && _materials.isEmpty)) {
          _errorMessage = 'Failed to load materials: $e';
        }
        _isLoading = false;
      });
    }
  }

  void _selectSubject(Map<String, dynamic> subject) {
    setState(() {
      _selectedSubject = subject;
      _folderStack.clear();
      _currentFolder = null;
    });
    _loadMaterialsForOffering();
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

  void _handleBackNavigation() {
    if (_folderStack.isNotEmpty) {
      _navigateBackTo(_folderStack.length - 2);
    } else {
      setState(() {
        _selectedSubject = null;
        _folders = [];
        _materials = [];
      });
    }
  }

  // --- Resolve Supabase Storage Download/View URL ---
  Future<String?> _resolveMaterialUrl(ClassRealmMaterial material) async {
    final raw = material.storagePathUrl.trim();
    if (raw.isEmpty) return null;
    if (material.isEmbedUrl) return raw;
    if (raw.startsWith('lesson://')) return null;

    if (raw.contains('token=') || raw.contains('Signature=')) {
      return raw;
    }

    var cleanPath = raw;
    if (cleanPath.contains('/learning_materials/')) {
      cleanPath = cleanPath.split('/learning_materials/').last;
    }
    if (cleanPath.contains('?')) {
      cleanPath = cleanPath.split('?').first;
    }
    cleanPath = Uri.decodeComponent(cleanPath).trim();

    try {
      final signedUrl = await SupabaseService().adminClient.storage
          .from('learning_materials')
          .createSignedUrl(cleanPath, 60 * 60);
      return signedUrl;
    } catch (_) {}

    try {
      final signedUrl = await _client.storage
          .from('learning_materials')
          .createSignedUrl(cleanPath, 60 * 60);
      return signedUrl;
    } catch (_) {}

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    return _client.storage.from('learning_materials').getPublicUrl(cleanPath);
  }

  // --- View Material File Directly ---
  Future<void> _viewMaterial(ClassRealmMaterial material) async {
    if (_openingIds.contains(material.id)) return;
    setState(() => _openingIds.add(material.id));

    try {
      // 1. If downloaded and available offline on native device, open directly from disk!
      if (!kIsWeb && _isMaterialOfflineReady(material.id)) {
        final localPath = _offlineMaterialPaths[material.id]!;
        final localFile = File(localPath);
        if (localFile.existsSync()) {
          try {
            final launched = await launchUrl(
              Uri.file(localPath),
              mode: LaunchMode.externalApplication,
            );
            if (launched) return;
          } catch (localErr) {
            debugPrint('Failed to open local file via URI: $localErr');
          }
        }
      }

      // 2. Otherwise, resolve secure signed URL
      final resolvedUrl = await _resolveMaterialUrl(material);
      if (resolvedUrl == null || resolvedUrl.isEmpty) {
        if (!mounted) return;
        _showToast('Material file link is not available.');
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
        _showToast('Unable to open file in browser or default viewer.');
      }
    } catch (e) {
      if (mounted) {
        _showToast('Failed to open file: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _openingIds.remove(material.id));
      }
    }
  }

  // --- Download Material File Directly ---
  Future<void> _downloadMaterial(ClassRealmMaterial material) async {
    if (_downloadingIds.contains(material.id)) return;
    setState(() => _downloadingIds.add(material.id));

    try {
      final resolvedUrl = await _resolveMaterialUrl(material);
      if (resolvedUrl == null || resolvedUrl.isEmpty) {
        if (!mounted) return;
        _showToast('Material file link is not available for download.');
        return;
      }

      final extension = material.fileExtension.toLowerCase();
      final sanitizedFileName = material.fileName.isNotEmpty
          ? material.fileName
          : '${material.displayName}.$extension';

      // Fetch bytes from URL
      final response = await http.get(Uri.parse(resolvedUrl));
      if (response.statusCode == 200) {
        final result = await FileDownloadHelper.downloadBytes(
          bytes: response.bodyBytes,
          fileName: sanitizedFileName,
          extension: extension,
          mimeType: material.mimeType ?? 'application/octet-stream',
        );

        // Record offline path if saved
        if (result != null && result.startsWith('Saved to ')) {
          final savedPath = result.replaceFirst('Saved to ', '').trim();
          await _recordDownloadedMaterial(material.id, savedPath);
        } else {
          await _recordDownloadedMaterial(material.id, sanitizedFileName);
        }

        if (mounted) {
          _showToast(result ?? 'Downloaded $sanitizedFileName (Offline Ready)');
        }
      } else {
        // Fallback: launch external URL so browser/device initiates download
        await launchUrl(
          Uri.parse(resolvedUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      if (mounted) {
        _showToast('Download error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingIds.remove(material.id));
      }
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: _selectedSubject == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _selectedSubject != null
                ? (_selectedSubject!['subject_name'] ?? 'Learning Materials')
                : 'Learning Materials',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          leading: _selectedSubject != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: _folderStack.isNotEmpty
                      ? 'Back to parent folder'
                      : 'Back to subjects',
                  onPressed: _handleBackNavigation,
                )
              : null,
          elevation: 0,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: _isLoading
                ? Center(
                    child: LoadingAnimationWidget.staggeredDotsWave(
                      color: theme.colorScheme.primary,
                      size: 42,
                    ),
                  )
                : _selectedSubject == null
                    ? _buildEnrolledSubjectsView(theme)
                    : _buildSubjectMaterialsView(theme),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // LEVEL 1: Enrolled Subjects View (Overview of student's subjects)
  // ===========================================================================
  Widget _buildEnrolledSubjectsView(ThemeData theme) {
    return AppPullToRefresh(
      onRefresh: _refreshScreen,
      child: _errorMessage != null
          ? AppPullToRefresh.scrollableState(
              child: _buildErrorView(theme),
            )
          : _allEnrolledSubjects.isEmpty
              ? AppPullToRefresh.scrollableState(
                  child: _buildNoSubjectsState(theme),
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  children: [
                    // Header Guidance Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.menu_book_rounded,
                              color: theme.colorScheme.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'My Enrolled Subjects',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Select a subject below to access its official modules, handouts, and notes.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Section Heading with Subject Count
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ENROLLED SUBJECTS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_allEnrolledSubjects.length} ${_allEnrolledSubjects.length == 1 ? "Class" : "Classes"}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Enrolled Subject Cards
                    ..._allEnrolledSubjects.map(
                      (subject) => _buildSubjectCard(subject, theme),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject, ThemeData theme) {
    final subName = subject['subject_name'] ?? 'Subject';
    final subCode = subject['subject_code'] ?? '';
    final gradeLevel = subject['grade_level'] ?? 11;
    final sectionName = subject['section_name'] ?? 'Section';
    final teacherName = subject['teacher_name'] as String? ?? '';
    final isIrreg = subject['is_irregular'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.09),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _selectSubject(subject),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badges Row
              Row(
                children: [
                  if (subCode.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        subCode,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'GRADE $gradeLevel',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (isIrreg) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Irregular',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Subject Title
              Text(
                subName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),

              // Section & Teacher Information
              Row(
                children: [
                  Icon(
                    Icons.class_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    sectionName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                  if (teacherName.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.person_outline_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        teacherName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.75,
                          ),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // LEVEL 2: Subject Explorer (Module Folders & Learning Documents)
  // ===========================================================================
  Widget _buildSubjectMaterialsView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subject Context & Quick Switch Strip
        _buildSubjectContextStrip(theme),

        // Folder Breadcrumbs
        _buildBreadcrumbs(theme),

        // Main Folder & Materials Content
        Expanded(
          child: AppPullToRefresh(
            onRefresh: _refreshScreen,
            child: _errorMessage != null
                ? AppPullToRefresh.scrollableState(
                    child: _buildErrorView(theme),
                  )
                : (_folders.isEmpty && _materials.isEmpty)
                    ? AppPullToRefresh.scrollableState(
                        child: _buildEmptyFolderState(theme),
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        children: [
                          // Module Folders Section
                          if (_folders.isNotEmpty) ...[
                            Text(
                              'MODULE FOLDERS (${_folders.length})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._folders.map(
                              (folder) => _buildFolderCard(folder, theme),
                            ),
                            const SizedBox(height: 18),
                          ],

                          // Learning Documents Section
                          if (_materials.isNotEmpty) ...[
                            Text(
                              'LEARNING DOCUMENTS & LESSONS (${_materials.length})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._materials.map(
                              (material) => _buildMaterialCard(material, theme),
                            ),
                          ],
                        ],
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectContextStrip(ThemeData theme) {
    final sub = _selectedSubject ?? {};
    final subCode = sub['subject_code'] ?? '';
    final sectionName = sub['section_name'] ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$subCode • $sectionName',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: const Text(
              'Change Subject',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              setState(() {
                _selectedSubject = null;
                _folders = [];
                _materials = [];
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbs(ThemeData theme) {
    final subName =
        _selectedSubject?['subject_code'] ??
        _selectedSubject?['subject_name'] ??
        'Subject';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _selectedSubject = null;
                  _folders = [];
                  _materials = [];
                });
              },
              child: Row(
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 15,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'All Subjects',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            InkWell(
              onTap: () => _navigateBackTo(-1),
              child: Text(
                subName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _folderStack.isEmpty
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _folderStack.isEmpty
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
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
                    fontWeight: i == _folderStack.length - 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: i == _folderStack.length - 1
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFolderCard(ClassRealmFolder folder, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.09),
        ),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.folder_rounded,
          color: Colors.amber,
          size: 32,
        ),
        title: Text(
          folder.folderName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '${folder.fileCount} ${folder.fileCount == 1 ? "material" : "materials"} available',
          style: TextStyle(
            fontSize: 11.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => _navigateToFolder(folder),
      ),
    );
  }

  Widget _buildMaterialCard(ClassRealmMaterial material, ThemeData theme) {
    final ext = material.fileExtension;
    final isDownloading = _downloadingIds.contains(material.id);
    final isOpening = _openingIds.contains(material.id);
    final hasDescription =
        material.description != null && material.description!.trim().isNotEmpty;
    final isOfflineReady = _isMaterialOfflineReady(material.id);
    final isNew =
        DateTime.now().difference(material.createdAt).inHours <= 48;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Format Icon + Document Title + Size
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getFormatColor(ext).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getFormatIcon(ext),
                    color: _getFormatColor(ext),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isNew || isOfflineReady) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (isNew)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'NEW',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            if (isOfflineReady)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.white,
                                      size: 11,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      'Offline Ready',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 3),
                      Text(
                        '${material.fileExtension} • ${material.formattedSize}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Middle: Teacher's Note (2 lines clamp + See more / See less)
            if (hasDescription) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 13,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "Teacher's Note:",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ExpandableInstructionsText(
                      text: material.description!.trim(),
                      collapsedMaxLines: 2,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.85,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Bottom Actions: Direct View & Direct Download Buttons
            Row(
              children: [
                // View File Button
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: isOpening
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: LoadingAnimationWidget.staggeredDotsWave(
                              color: theme.colorScheme.primary,
                              size: 14,
                            ),
                          )
                        : const Icon(Icons.remove_red_eye_outlined, size: 16),
                    label: Text(
                      isOpening ? 'Opening...' : 'View File',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: isOpening ? null : () => _viewMaterial(material),
                  ),
                ),
                const SizedBox(width: 10),

                // Download File Button
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOfflineReady
                          ? Colors.green.shade700
                          : theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: isDownloading
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: LoadingAnimationWidget.staggeredDotsWave(
                              color: Colors.white,
                              size: 14,
                            ),
                          )
                        : Icon(
                            isOfflineReady
                                ? Icons.file_download_done_rounded
                                : Icons.download_rounded,
                            size: 16,
                          ),
                    label: Text(
                      isDownloading
                          ? 'Saving...'
                          : (isOfflineReady ? 'Downloaded' : 'Download'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: isDownloading
                        ? null
                        : () => _downloadMaterial(material),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Empty & Error States
  // ===========================================================================
  Widget _buildNoSubjectsState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.school_outlined,
              size: 26,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Enrolled Subjects Found',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'You are not currently enrolled in any active classes for this school year.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
            onPressed: () => _loadStudentEnrolledClasses(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFolderState(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(
                alpha: isDark ? 0.18 : 0.1,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 24,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Learning Materials Yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Your teacher has not published any learning materials or modules in this folder yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14.5),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            onPressed: () => _loadStudentEnrolledClasses(),
          ),
        ],
      ),
    );
  }

  IconData _getFormatIcon(String ext) {
    final e = ext.toLowerCase();
    if (e == 'pdf') return Icons.picture_as_pdf_rounded;
    if (e == 'doc' || e == 'docx') return Icons.description_rounded;
    if (e == 'ppt' || e == 'pptx') return Icons.slideshow_rounded;
    if (e == 'lesson') return Icons.article_rounded;
    if (e == 'link') return Icons.link_rounded;
    return Icons.insert_drive_file_rounded;
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
