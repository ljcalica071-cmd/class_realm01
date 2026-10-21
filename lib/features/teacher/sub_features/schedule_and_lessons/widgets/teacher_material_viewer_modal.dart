import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/data/repositories/learning_material_repository.dart';
import 'package:class_realm/data/repositories/supabase_learning_material_repository.dart';

class TeacherMaterialViewerModal extends StatefulWidget {
  final ClassRealmMaterial material;
  final List<ClassRealmFolder> availableFolders;
  final String currentOfferingId;
  final ValueChanged<ClassRealmMaterial> onMaterialUpdated;
  final VoidCallback onMaterialDeleted;

  const TeacherMaterialViewerModal({
    super.key,
    required this.material,
    required this.availableFolders,
    required this.currentOfferingId,
    required this.onMaterialUpdated,
    required this.onMaterialDeleted,
  });

  static Future<void> show({
    required BuildContext context,
    required ClassRealmMaterial material,
    required List<ClassRealmFolder> availableFolders,
    required String currentOfferingId,
    required ValueChanged<ClassRealmMaterial> onMaterialUpdated,
    required VoidCallback onMaterialDeleted,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TeacherMaterialViewerModal(
        material: material,
        availableFolders: availableFolders,
        currentOfferingId: currentOfferingId,
        onMaterialUpdated: onMaterialUpdated,
        onMaterialDeleted: onMaterialDeleted,
      ),
    );
  }

  @override
  State<TeacherMaterialViewerModal> createState() =>
      _TeacherMaterialViewerModalState();
}

class _TeacherMaterialViewerModalState extends State<TeacherMaterialViewerModal> {
  final _materialRepo = SupabaseLearningMaterialRepository.instance;

  late ClassRealmMaterial _currentMaterial;
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late ClassRealmFolder _selectedFolder;
  late bool _isVisibleToStudents;

  bool _isSaving = false;
  bool _isReplacingFile = false;
  String? _draftRestoreedText;
  DateTime? _lastAutoSavedAt;
  Timer? _autoSaveTimer;

  static const int _maxDescriptionLength = 50000;

  @override
  void initState() {
    super.initState();
    _currentMaterial = widget.material;
    _titleController = TextEditingController(text: _currentMaterial.displayName);
    _descController = TextEditingController(text: _currentMaterial.description ?? '');
    _isVisibleToStudents = _currentMaterial.isVisibleToStudents;

    _selectedFolder = widget.availableFolders.firstWhere(
      (f) => f.id == _currentMaterial.folderId,
      orElse: () => widget.availableFolders.isNotEmpty
          ? widget.availableFolders.first
          : ClassRealmFolder(
              id: _currentMaterial.folderId,
              subjectOfferingId: widget.currentOfferingId,
              folderName: 'Current Folder',
              createdAt: DateTime.now(),
            ),
    );

    _checkForSavedDraft();
    _startAutoSaveTimer();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String get _draftPrefKey => 'draft_material_${_currentMaterial.id}';

  Future<void> _checkForSavedDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDraft = prefs.getString(_draftPrefKey);
      if (savedDraft != null &&
          savedDraft.trim().isNotEmpty &&
          savedDraft != (_currentMaterial.description ?? '')) {
        setState(() {
          _draftRestoreedText = savedDraft;
        });
      }
    } catch (e) {
      debugPrint('Draft check error: $e');
    }
  }

  void _startAutoSaveTimer() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) return;
      final currentText = _descController.text;
      if (currentText != (_currentMaterial.description ?? '') &&
          currentText.trim().isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_draftPrefKey, currentText);
          if (mounted) {
            setState(() {
              _lastAutoSavedAt = DateTime.now();
            });
          }
        } catch (_) {}
      }
    });
  }

  Future<void> _clearSavedDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftPrefKey);
    } catch (_) {}
  }

  void _restoreDraft() {
    if (_draftRestoreedText != null) {
      setState(() {
        _descController.text = _draftRestoreedText!;
        _draftRestoreedText = null;
      });
      _showToast('Local draft restored!', isError: false);
    }
  }

  void _discardDraft() {
    _clearSavedDraft();
    setState(() {
      _draftRestoreedText = null;
    });
    _showToast('Local draft discarded.', isError: false);
  }

  String _sanitizeHtml(String input) {
    // Strip malicious script and event handler tags
    return input
        .replaceAll(RegExp(r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'onload\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'onerror\s*=', caseSensitive: false), '');
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      final cleanTitle = _titleController.text.trim();
      final cleanDesc = _sanitizeHtml(_descController.text.trim());

      final updated = await _materialRepo.updateMaterialDetails(
        materialId: _currentMaterial.id,
        title: cleanTitle.isNotEmpty ? cleanTitle : _currentMaterial.fileName,
        description: cleanDesc,
        folderId: _selectedFolder.id,
        isVisibleToStudents: _isVisibleToStudents,
      );

      await _clearSavedDraft();

      if (!mounted) return;
      setState(() {
        _currentMaterial = updated;
        _isSaving = false;
        _lastAutoSavedAt = null;
      });

      widget.onMaterialUpdated(updated);
      _showToast('Material changes saved successfully!', isError: false);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showToast('Failed to save changes: $e', isError: true);
    }
  }

  Future<void> _showReplaceFileDialog() async {
    // 1. Pick new file
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx'],
        withData: true,
      );
    } catch (e) {
      _showToast('File picker error: $e', isError: true);
      return;
    }

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    // 2. Validate format, magic bytes, and 3MB size limit
    Uint8List? bytes = file.bytes;
    if (bytes == null && !kIsWeb && file.path != null) {
      try {
        bytes = await File(file.path!).readAsBytes();
      } catch (e) {
        debugPrint('File read warning: $e');
      }
    }

    if (bytes == null || bytes.isEmpty) {
      _showToast('Unable to read selected file.', isError: true);
      return;
    }

    final validationError = MaterialFileValidator.validateFile(
      fileName: file.name,
      fileBytes: bytes,
      byteSize: file.size,
    );

    if (validationError != null) {
      _showErrorModal(title: 'Validation Failed', message: validationError);
      return;
    }

    final nonNullBytes = bytes;
    final ext = (file.extension ?? '').toLowerCase();
    final mimeType = MaterialFileValidator.getMimeType(file.name);

    // 3. Prompt teacher for Replacement Scope (Edge Case #9)
    if (!mounted) return;
    bool updateAll = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: Colors.blue),
                SizedBox(width: 8),
                Text('Replace Document File'),
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
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.attach_file, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
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
                              Text(
                                'Size: ${(file.size / 1024).toStringAsFixed(1)} KB • ${ext.toUpperCase()}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select replacement scope across sections:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Update for this section only', style: TextStyle(fontSize: 13)),
                    subtitle: const Text(
                      'Other sections will continue using their current copy.',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: false,
                    groupValue: updateAll,
                    onChanged: (val) => setDialogState(() => updateAll = val ?? false),
                  ),
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Update across all shared sections', style: TextStyle(fontSize: 13)),
                    subtitle: const Text(
                      'Replaces the file simultaneously for all sections that share this document.',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: true,
                    groupValue: updateAll,
                    onChanged: (val) => setDialogState(() => updateAll = val ?? true),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm Replacement'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    setState(() => _isReplacingFile = true);

    try {
      final updatedMat = await _materialRepo.replaceMaterialFile(
        materialId: _currentMaterial.id,
        currentStoragePathUrl: _currentMaterial.storagePathUrl,
        newFileName: file.name,
        newFileBytes: nonNullBytes,
        newFileSizeBytes: file.size,
        mimeType: mimeType,
        updateAllSharedSections: updateAll,
      );

      if (!mounted) return;
      setState(() {
        _currentMaterial = updatedMat;
        _isReplacingFile = false;
      });

      widget.onMaterialUpdated(updatedMat);
      _showToast('File replaced successfully!', isError: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isReplacingFile = false);
      _showToast('Failed to replace file: $e', isError: true);
    }
  }

  Future<void> _confirmArchive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Material?'),
        content: Text(
          'Are you sure you want to archive "${_currentMaterial.displayName}"?\n\n'
          'It will be hidden from students and moved to the Archived Items view.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _materialRepo.archiveMaterial(_currentMaterial.id);
      await _clearSavedDraft();
      widget.onMaterialDeleted();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showToast('Archive error: $e', isError: true);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanently Delete Material?'),
        content: Text(
          'Are you sure you want to permanently delete "${_currentMaterial.displayName}" from the school system?\n\n'
          'This will completely erase the material and purge the file. This action cannot be undone.',
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

    if (confirmed != true) return;

    try {
      await _materialRepo.deleteMaterialReferenceCounted(
        materialId: _currentMaterial.id,
        storagePathUrl: _currentMaterial.storagePathUrl,
      );
      await _clearSavedDraft();
      widget.onMaterialDeleted();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showToast('Delete error: $e', isError: true);
    }
  }

  void _showErrorModal({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 960,
          maxHeight: 740,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Title & Close
              _buildTopBar(theme),

              if (_draftRestoreedText != null) ...[
                const SizedBox(height: 10),
                _buildDraftRestoreyBanner(theme),
              ],

              const SizedBox(height: 16),

              // Split Layout: Left Preview Card, Right Editor
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Document Preview & Metadata Area (Width: 360)
                    SizedBox(
                      width: 360,
                      child: _buildDocumentPreviewArea(theme, isDark),
                    ),

                    const SizedBox(width: 20),
                    const VerticalDivider(width: 1),
                    const SizedBox(width: 20),

                    // Right Column: Direct Live Editor
                    Expanded(
                      child: _buildEditorArea(theme, isDark),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Bottom Actions Bar
              _buildBottomActionsBar(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.menu_book_rounded, color: theme.colorScheme.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'In-App Material Viewer & Live Editor',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'Manage document details, lesson content, and multi-section visibility.',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildDraftRestoreyBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Unsaved lesson notes draft found in local storage.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: _restoreDraft,
            child: const Text('Restore Draft', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: 'Discard Draft',
            onPressed: _discardDraft,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPreviewArea(ThemeData theme, bool isDark) {
    final ext = _currentMaterial.fileExtension;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DOCUMENT OVERVIEW',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),

          // Document Card (NO RAW URLS!)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                // Big file icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getFormatColor(ext).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getFormatIcon(ext), color: _getFormatColor(ext), size: 44),
                ),
                const SizedBox(height: 12),

                // Display Name
                Text(
                  _currentMaterial.displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Sanitized file name
                Text(
                  _currentMaterial.fileName,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Metadata Badges (Format, Size, Visibility)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildBadge(ext, _getFormatColor(ext)),
                    _buildBadge(_currentMaterial.formattedSize, Colors.blueGrey),
                    _buildBadge(
                      _isVisibleToStudents ? 'Live (Visible)' : 'Draft (Hidden)',
                      _isVisibleToStudents ? Colors.green : Colors.amber.shade800,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Embed Link validation banner if uri-list
          if (_currentMaterial.isEmbedUrl) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Embedded Cloud Document / Video.\nRemember to set Google Drive or Slide sharing permissions to "Anyone with the link can view".',
                      style: TextStyle(fontSize: 11, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Replace File Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _isReplacingFile
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_upload_outlined, size: 18),
              label: Text(_isReplacingFile ? 'Replacing File...' : 'Replace File / Upload New Version'),
              onPressed: _isReplacingFile ? null : _showReplaceFileDialog,
            ),
          ),

          const SizedBox(height: 10),

          // Graceful fallback helper card
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.security_update_good, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cloud Storage: Free-tier deduplicated. Verified ≤ 3MB.',
                    style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorArea(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'LESSON DETAILS & CONTENT',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            if (_lastAutoSavedAt != null)
              Text(
                'Auto-saved locally at ${_formatTime(_lastAutoSavedAt!)}',
                style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Document Title
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Document Title',
            hintText: 'e.g. Chapter 3: Data Structures and Algorithms',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),

        // Folder & Visibility Row
        Row(
          children: [
            // Target Folder Selector
            Expanded(
              child: DropdownButtonFormField<ClassRealmFolder>(
                initialValue: _selectedFolder,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Folder Location',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: widget.availableFolders.map((f) {
                  return DropdownMenuItem(
                    value: f,
                    child: Text(f.folderName, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedFolder = val);
                },
              ),
            ),
            const SizedBox(width: 14),

            // Visibility Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Visible to Students', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Switch(
                    value: _isVisibleToStudents,
                    activeThumbColor: Colors.green,
                    onChanged: (v) => setState(() => _isVisibleToStudents = v),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Lesson Content / Notes Editor (up to 50,000 characters)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Study Notes & Chapter Content (Markdown/Text):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    '${_descController.text.length} / $_maxDescriptionLength characters',
                    style: TextStyle(
                      fontSize: 10,
                      color: _descController.text.length > _maxDescriptionLength * 0.95
                          ? Colors.red
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: TextField(
                  controller: _descController,
                  maxLines: null,
                  expands: true,
                  maxLength: _maxDescriptionLength,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade100 : Colors.grey.shade900,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Enter comprehensive chapter notes, reading guides, formulas, or instructions...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionsBar(ThemeData theme) {
    return Row(
      children: [
        IconButton.filledTonal(
          icon: const Icon(Icons.archive_outlined, color: Colors.orange, size: 20),
          tooltip: 'Archive Material',
          onPressed: _confirmArchive,
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 20),
          tooltip: 'Permanently Delete Material',
          onPressed: _confirmDelete,
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.check, size: 18),
          label: Text(_isSaving ? 'Saving...' : 'Save & Publish Changes'),
          onPressed: _isSaving ? null : _saveChanges,
        ),
      ],
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
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

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
