import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/student_dashboard_models.dart';
import 'package:class_realm/shared/widgets/app_top_toast.dart';

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
  Uint8List? _fileBytes;
  String? _fileName;
  int? _fileSizeBytes;
  String? _fileError;
  bool _isSubmitting = false;
  String? _submitError;

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
          _fileError =
              'Invalid file format. Only PDF and Word documents (.pdf, .doc, .docx) are accepted.';
        });
        return;
      }

      if (file.name.length > 80) {
        setState(() {
          _fileError =
              'File name is too long (${file.name.length} characters). Maximum allowed is 80 characters. Please rename your file before uploading.';
        });
        return;
      }

      if (file.bytes == null) {
        setState(() => _fileError = 'Unable to read selected file bytes.');
        return;
      }

      if (file.size > 15 * 1024 * 1024) {
        setState(() => _fileError =
            'File size exceeds 15 MB limit (${_formatFileSize(file.size)}). Please compress or choose a smaller file.');
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

      // Check if classwork item still exists in database and deadline has not passed
      final existingItem = await client
          .from('classwork_items')
          .select('id, deadline, is_archived, is_published')
          .eq('id', widget.classwork.id)
          .maybeSingle();

      if (existingItem == null ||
          existingItem['is_archived'] == true ||
          existingItem['is_published'] == false) {
        AppDataCache.instance.invalidatePrefix('student_dashboard_${user.id}');
        if (mounted) {
          Navigator.of(context).pop();
          AppModals.showWarningDialog(
            context: context,
            title: 'Classwork Unavailable',
            message:
                'This activity or performance task has already been deleted or closed by your teacher. Your submission cannot be accepted.',
          );
        }
        return;
      }

      // Check if deadline passed while dialog was open
      final deadlineStr = existingItem['deadline']?.toString();
      if (deadlineStr != null) {
        final deadline = DateTime.tryParse(deadlineStr);
        if (deadline != null && DateTime.now().toUtc().isAfter(deadline.toUtc())) {
          AppDataCache.instance.invalidatePrefix('student_dashboard_${user.id}');
          if (mounted) {
            setState(() {
              _submitError =
                  'The deadline has passed and submission is now closed. Your file could not be submitted.';
              _isSubmitting = false;
            });
          }
          return;
        }
      }

      String? storagePath;

      // 1. Upload file if attached
      if (_fileBytes != null && _fileName != null) {
        final safeName = _fileName!.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final baseName = safeName.contains('.')
            ? safeName.substring(0, safeName.lastIndexOf('.'))
            : safeName;
        final ext = safeName.contains('.') ? safeName.split('.').last : 'pdf';
        final truncatedBase = baseName.length > 50 ? baseName.substring(0, 50) : baseName;
        final finalFileName = '$truncatedBase.$ext';

        storagePath =
            'submissions/${widget.classwork.id}/${user.id}_${DateTime.now().millisecondsSinceEpoch}_$finalFileName';

        try {
          await SupabaseService().adminClient.storage
              .from('classwork-materials')
              .uploadBinary(
                storagePath,
                _fileBytes!,
                fileOptions: const FileOptions(upsert: true),
              )
              .timeout(const Duration(seconds: 45));
        } catch (uploadErr) {
          debugPrint('Notice on admin storage upload: $uploadErr. Retrying with client storage...');
          try {
            await Supabase.instance.client.storage
                .from('classwork-materials')
                .uploadBinary(
                  storagePath,
                  _fileBytes!,
                  fileOptions: const FileOptions(upsert: true),
                )
                .timeout(const Duration(seconds: 45));
          } catch (clientErr) {
            debugPrint('Storage upload error: $clientErr');
            final errStr = clientErr.toString().toLowerCase();
            if (errStr.contains('timeout')) {
              throw Exception('Upload timed out. Please check your internet connection and try again.');
            }
            throw Exception('Failed to upload file: $clientErr');
          }
        }
      }

      // 2. Insert or update student_classwork_submissions
      final submissionData = <String, dynamic>{
        'classwork_id': widget.classwork.id,
        'student_id': user.id,
        'status': 'submitted',
        'submitted_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final subResult = await client
          .from('student_classwork_submissions')
          .upsert(submissionData, onConflict: 'classwork_id,student_id')
          .select('id')
          .single();

      final submissionId = subResult['id']?.toString();

      // 3. Insert or update submission_attachments
      if (submissionId != null && storagePath != null && _fileName != null) {
        String mimeType = 'application/pdf';
        final ext = _fileName!.split('.').last.toLowerCase();
        if (ext == 'doc' || ext == 'docx') {
          // Note: submission_attachments column mime_type has varchar(50) with
          // CHECK constraint allowing 'application/msword'. 'application/msword'
          // safely fits within 50 chars for both .doc and .docx files.
          mimeType = 'application/msword';
        }

        try {
          final adminClient = SupabaseService().adminClient;
          await adminClient
              .from('submission_attachments')
              .delete()
              .eq('submission_id', submissionId);
          await adminClient.from('submission_attachments').insert({
            'submission_id': submissionId,
            'file_name': _fileName!,
            'storage_url': storagePath,
            'mime_type': mimeType,
            if (_fileSizeBytes != null) 'file_size_bytes': _fileSizeBytes,
          });
        } catch (attErr) {
          debugPrint('Notice on submission attachment record: $attErr');
        }
      }

      // Invalidate cache
      AppDataCache.instance.invalidatePrefix('student_dashboard_${user.id}');
      AppDataCache.instance.invalidatePrefix('teacher_activities_');

      widget.onSubmitted();
      if (mounted) {
        Navigator.of(context).pop();
        AppTopToast.success(context, 'Your work has been submitted successfully!');
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.upload_file,
                      color: theme.colorScheme.primary,
                      size: 22,
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
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
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

              // Upfront Submission Guidance (Golden Rule: Prevent errors by showing requirements upfront)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Submission Guidelines & Requirements',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '• Accepted Formats: PDF (.pdf) or Word (.doc, .docx)\n• Max File Size: 15 MB per submission\n• File Name: Up to 80 characters',
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

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
                          size: 26,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Click to upload your output',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Formats: .pdf, .doc, .docx  •  Max: 15 MB  •  Filename: up to 80 chars',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
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
