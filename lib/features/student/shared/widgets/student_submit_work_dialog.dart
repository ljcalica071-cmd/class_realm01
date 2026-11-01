import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/student_dashboard_models.dart';

class StudentSubmitWorkDialog extends StatefulWidget {
  final StudentClassworkModel classwork;
  final VoidCallback onSubmitted;

  const StudentSubmitWorkDialog({
    super.key,
    required this.classwork,
    required this.onSubmitted,
  });

  static Future<void> show(
    BuildContext context, {
    required StudentClassworkModel classwork,
    required VoidCallback onSubmitted,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StudentSubmitWorkDialog(
        classwork: classwork,
        onSubmitted: onSubmitted,
      ),
    );
  }

  @override
  State<StudentSubmitWorkDialog> createState() =>
      _StudentSubmitWorkDialogState();
}

class _StudentSubmitWorkDialogState extends State<StudentSubmitWorkDialog> {
  final TextEditingController _commentCtrl = TextEditingController();
  Uint8List? _fileBytes;
  String? _fileName;
  int? _fileSizeBytes;
  String? _fileError;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MiB';
  }

  Future<void> _pickFile() async {
    setState(() => _fileError = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final ext = (file.extension ?? '').toLowerCase();

      if (!['pdf', 'doc', 'docx'].contains(ext)) {
        setState(() {
          _fileError = 'Invalid file type. Only PDF and Word Documents (.pdf, .doc, .docx) are accepted.';
        });
        return;
      }

      if (file.bytes == null) {
        setState(() => _fileError = 'Unable to read selected file bytes.');
        return;
      }

      if (file.size > 15 * 1024 * 1024) {
        setState(() => _fileError = 'File size exceeds maximum 15 MB limit.');
        return;
      }

      setState(() {
        _fileBytes = file.bytes;
        _fileName = file.name;
        _fileSizeBytes = file.size;
        _fileError = null;
      });
    } catch (e) {
      setState(() => _fileError = 'Failed to attach file: $e');
    }
  }

  void _removeFile() {
    setState(() {
      _fileBytes = null;
      _fileName = null;
      _fileSizeBytes = null;
      _fileError = null;
    });
  }

  Future<void> _submitWork() async {
    if (_fileBytes == null) {
      setState(() {
        _fileError =
            'Please attach your output document (.pdf, .doc, or .docx).';
      });
      return;
    }

    final user = AuthRepository.instance.currentUser;
    if (user == null) {
      setState(
        () => _submitError = 'Student session not found. Please log in.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final client = Supabase.instance.client;
      String? storagePath;

      // 1. Upload file if attached
      if (_fileBytes != null && _fileName != null) {
        final safeName = _fileName!.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        storagePath =
            'submissions/${widget.classwork.id}/${user.id}_${DateTime.now().millisecondsSinceEpoch}_$safeName';

        try {
          await client.storage
              .from('classwork-materials')
              .uploadBinary(
                storagePath,
                _fileBytes!,
                fileOptions: const FileOptions(upsert: true),
              );
        } catch (uploadErr) {
          debugPrint('Notice on storage upload: $uploadErr');
        }
      }

      // 2. Insert or update student_classwork_submissions
      final submissionData = <String, dynamic>{
        'classwork_id': widget.classwork.id,
        'student_id': user.id,
        'status': 'submitted',
        'feedback': _commentCtrl.text.trim().isNotEmpty
            ? _commentCtrl.text.trim()
            : null,
        'submitted_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        if (storagePath != null) 'storage_path': storagePath,
        if (_fileName != null) 'file_name': _fileName,
        if (_fileSizeBytes != null) 'file_size_bytes': _fileSizeBytes,
      };

      await client
          .from('student_classwork_submissions')
          .upsert(submissionData, onConflict: 'classwork_id,student_id');

      // Invalidate cache
      AppDataCache.instance.invalidatePrefix('student_dashboard_${user.id}');
      AppDataCache.instance.invalidatePrefix('teacher_activities_');

      widget.onSubmitted();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your work has been submitted successfully!'),
            backgroundColor: Color(0xFF0F8A48),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitError = 'Error submitting work: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.upload_file,
                      color: theme.colorScheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Submit Work',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.classwork.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // File upload container
              Text(
                'Attach Your File *',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              if (_fileName == null) ...[
                InkWell(
                  onTap: _isSubmitting ? null : _pickFile,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _fileError != null
                            ? const Color(0xFFDC2626)
                            : (isDark ? Colors.white24 : Colors.grey.shade300),
                        width: _fileError != null ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 38,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Click to upload your output',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Accepts PDF and Word Documents only (.pdf, .doc, .docx)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.15,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _fileName!.toLowerCase().endsWith('.pdf')
                            ? Icons.picture_as_pdf
                            : Icons.description,
                        color: _fileName!.toLowerCase().endsWith('.pdf')
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _fileName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (_fileSizeBytes != null)
                              Text(
                                _formatFileSize(_fileSizeBytes!),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                        tooltip: 'Remove file',
                        onPressed: _isSubmitting ? null : _removeFile,
                      ),
                    ],
                  ),
                ),
              ],

              if (_fileError != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 14,
                      color: Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _fileError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Remarks field
              Text(
                'Student Notes / Remarks (Optional)',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'Add an optional note or explanation for your teacher...',
                  hintStyle: const TextStyle(fontSize: 13),
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),

              if (_submitError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDC2626)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _submitError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submitWork,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                      _isSubmitting ? 'Submitting...' : 'Turn In Work',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
