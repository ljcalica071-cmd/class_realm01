import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/data/repositories/supabase_attendance_repository.dart';
import 'package:class_realm/shared/widgets/buttons/app_buttons.dart';
import 'package:class_realm/shared/widgets/modals/app_modals.dart';

class RfidAssignmentModal extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String? lrn;
  final String? currentRfidUid;
  final String? prefillRfidUid;
  final AttendanceRepository? repository;

  const RfidAssignmentModal({
    super.key,
    required this.studentId,
    required this.studentName,
    this.lrn,
    this.currentRfidUid,
    this.prefillRfidUid,
    this.repository,
  });

  /// Opens the Dual RFID Card Assignment modal.
  /// Returns:
  /// - The newly linked uppercase hex UID (`String`) when linked/reassigned
  /// - `''` (empty string) when an existing card is unlinked
  /// - `null` when cancelled/dismissed without changes
  static Future<String?> show(
    BuildContext context, {
    required String studentId,
    required String studentName,
    String? lrn,
    String? currentRfidUid,
    String? prefillRfidUid,
    AttendanceRepository? repository,
  }) {
    final theme = Theme.of(context);
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Theme(
        data: theme,
        child: RfidAssignmentModal(
          studentId: studentId,
          studentName: studentName,
          lrn: lrn,
          currentRfidUid: currentRfidUid,
          prefillRfidUid: prefillRfidUid,
          repository: repository,
        ),
      ),
    );
  }

  @override
  State<RfidAssignmentModal> createState() => _RfidAssignmentModalState();
}

class _RfidAssignmentModalState extends State<RfidAssignmentModal> {
  static final RegExp _hexUidRegex = RegExp(r'^[A-Fa-f0-9]{8,14}$');
  static const Color _errorRed = Color(0xFFDC2626);

  late final AttendanceRepository _repository;
  late final TextEditingController _uidController;
  final FocusNode _keyboardFocusNode = FocusNode();
  final FocusNode _inputFocusNode = FocusNode();

  String _wedgeBuffer = '';
  DateTime? _lastWedgeKeyTime;
  String? _uidError;
  bool _isSubmitting = false;
  bool _isUnlinking = false;
  bool _lastCaptureFromScanner = false;

  String? get _normalizedCurrentUid {
    final raw = widget.currentRfidUid?.trim().toUpperCase();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseAttendanceRepository.instance;
    final initialText = widget.prefillRfidUid?.trim().toUpperCase() ??
        _normalizedCurrentUid ??
        '';
    _uidController = TextEditingController(text: initialText);
    _lastCaptureFromScanner =
        widget.prefillRfidUid != null && widget.prefillRfidUid!.trim().isNotEmpty;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _inputFocusNode.requestFocus();
        _uidController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _uidController.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _uidController.dispose();
    _keyboardFocusNode.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _handleWedgeKeyEvent(KeyEvent event) {
    if (_isSubmitting || _isUnlinking) return;
    if (_inputFocusNode.hasFocus) return;

    if (event is KeyDownEvent) {
      final now = DateTime.now();
      if (_lastWedgeKeyTime != null &&
          now.difference(_lastWedgeKeyTime!).inMilliseconds > 1200) {
        _wedgeBuffer = '';
      }
      _lastWedgeKeyTime = now;

      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        final captured = _wedgeBuffer.trim().toUpperCase();
        _wedgeBuffer = '';
        if (captured.isNotEmpty) {
          setState(() {
            _uidController.text = captured;
            _uidController.selection = TextSelection.collapsed(
              offset: captured.length,
            );
            _uidError = null;
            _lastCaptureFromScanner = true;
          });
          _validateAndSubmit();
        }
      } else {
        final char = event.character;
        if (char != null && char.trim().isNotEmpty) {
          _wedgeBuffer += char.trim().toUpperCase();
        }
      }
    }
  }

  Future<void> _handleUnlink() async {
    final currentUid = _normalizedCurrentUid;
    if (currentUid == null || _isSubmitting || _isUnlinking) return;

    final confirmed = await AppModals.showConfirmDialog(
      context: context,
      title: 'Unlink RFID Card?',
      message:
          'Remove RFID card $currentUid from ${widget.studentName}? They will not be able to scan in with this card until a card is linked again.',
      confirmLabel: 'Unlink Card',
      confirmColor: AppTheme.catRed,
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isUnlinking = true;
      _uidError = null;
    });

    try {
      await _repository.assignStudentRfid(
        studentId: widget.studentId,
        rfidUid: null,
      );
      AppDataCache.instance.invalidatePrefix('teacher_students_');
      if (!mounted) return;
      Navigator.of(context).pop('');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUnlinking = false);
      await AppModals.showErrorDialog(
        context: context,
        title: 'Unable to Unlink RFID Card',
        message: e.toString(),
      );
    }
  }

  Future<void> _validateAndSubmit() async {
    if (_isSubmitting || _isUnlinking) return;

    final newUid = _uidController.text.trim().toUpperCase();

    // E1: Invalid / Empty Format
    if (!_hexUidRegex.hasMatch(newUid)) {
      setState(() {
        _uidError =
            'Enter or scan a valid 8–14 character hexadecimal RFID UID (0–9, A–F).';
      });
      return;
    }

    final currentUid = _normalizedCurrentUid;
    if (currentUid != null && currentUid == newUid) {
      setState(() {
        _uidError =
            'RFID card $newUid is already linked to ${widget.studentName}.';
      });
      return;
    }

    // E3: Student Already Has Card & Replacing
    if (currentUid != null && currentUid != newUid) {
      final replaceConfirmed = await AppModals.showConfirmDialog(
        context: context,
        title: 'Replace Linked RFID Card?',
        message:
            '${widget.studentName} currently has RFID card $currentUid linked. Replace it with $newUid?',
        confirmLabel: 'Replace Card',
        confirmColor: AppTheme.catOrange,
      );
      if (replaceConfirmed != true || !mounted) return;
    }

    setState(() {
      _isSubmitting = true;
      _uidError = null;
    });

    try {
      // E2: Card Already Linked to Another Student
      final conflict = await _repository.checkRfidUidConflict(
        rfidUid: newUid,
        excludeStudentId: widget.studentId,
      );
      if (!mounted) return;

      bool forceReassign = false;
      if (conflict.isTaken) {
        final ownerLabel = (conflict.existingStudentName != null &&
                conflict.existingStudentName!.trim().isNotEmpty)
            ? conflict.existingStudentName!.trim()
            : 'another student';
        final reassignConfirmed = await AppModals.showConfirmDialog(
          context: context,
          title: 'Reassign RFID Card?',
          message:
              'RFID card $newUid is currently assigned to $ownerLabel. Reassign it to ${widget.studentName}?',
          confirmLabel: 'Reassign Card',
          confirmColor: AppTheme.catOrange,
        );
        if (reassignConfirmed != true || !mounted) {
          setState(() => _isSubmitting = false);
          return;
        }
        forceReassign = true;
      }

      await _repository.assignStudentRfid(
        studentId: widget.studentId,
        rfidUid: newUid,
        forceReassign: forceReassign,
      );
      AppDataCache.instance.invalidatePrefix('teacher_students_');

      if (!mounted) return;
      Navigator.of(context).pop(newUid);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await AppModals.showErrorDialog(
        context: context,
        title: 'RFID Assignment Failed',
        message: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUid = _normalizedCurrentUid;
    final hasError = _uidError != null;

    final subtleSurface = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
        : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.14)
        : const Color(0xFFE2E8F0);

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleWedgeKeyEvent,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 18,
        backgroundColor: theme.colorScheme.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.catTeal.withValues(
                          alpha: isDark ? 0.2 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.contactless_rounded,
                        color: AppTheme.catTeal,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUid != null
                                ? 'Manage Student RFID Card'
                                : 'Link Student RFID Card',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.studentName,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                          if (widget.lrn != null &&
                              widget.lrn!.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'LRN: ${widget.lrn!.trim()}',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: (_isSubmitting || _isUnlinking)
                          ? null
                          : () => Navigator.of(context).pop(null),
                      icon: Icon(
                        LucideIcons.x,
                        size: 18,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Current Linked Card Banner (when assigned)
                if (currentUid != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.catTeal.withValues(
                        alpha: isDark ? 0.14 : 0.08,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.catTeal.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.badgeCheck,
                          size: 18,
                          color: AppTheme.catTeal,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CURRENT LINKED UID',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: isDark
                                      ? const Color(0xFF5EEAD4)
                                      : const Color(0xFF0F766E),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentUid,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'monospace',
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: (_isSubmitting || _isUnlinking)
                              ? null
                              : _handleUnlink,
                          style: TextButton.styleFrom(
                            foregroundColor: _errorRed,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: _errorRed.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                          icon: _isUnlinking
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _errorRed,
                                  ),
                                )
                              : const Icon(LucideIcons.unlink, size: 14),
                          label: const Text(
                            'Unlink Card',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Mode 1: USB / Reader Wedge Scan Zone
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    _inputFocusNode.requestFocus();
                    _uidController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _uidController.text.length,
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: subtleSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: isDark ? 0.2 : 0.1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.radio,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'USB RFID Reader Ready',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _lastCaptureFromScanner
                                    ? 'Card UID captured from USB scanner. Review or press Link below.'
                                    : 'Tap a 13.56 MHz RFID card on a connected USB reader to auto-fill, or enter the hexadecimal UID manually below.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.4,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.68,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Mode 2: Manual Hex UID Input with Strict Inline Validation
                Text(
                  'RFID Card Hexadecimal UID',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _uidController,
                  focusNode: _inputFocusNode,
                  enabled: !_isSubmitting && !_isUnlinking,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(20),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return newValue.copyWith(
                        text: newValue.text.toUpperCase(),
                      );
                    }),
                  ],
                  onChanged: (_) {
                    if (_uidError != null || _lastCaptureFromScanner) {
                      setState(() {
                        _uidError = null;
                        _lastCaptureFromScanner = false;
                      });
                    }
                  },
                  onSubmitted: (_) => _validateAndSubmit(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    letterSpacing: 1.1,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. A1B2C3D4',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.6,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    prefixIcon: Icon(
                      Icons.nfc_rounded,
                      size: 18,
                      color: hasError
                          ? _errorRed
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    suffixIcon: _uidController.text.isNotEmpty
                        ? IconButton(
                            tooltip: 'Clear UID',
                            icon: Icon(
                              LucideIcons.x,
                              size: 15,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _uidController.clear();
                                _uidError = null;
                                _lastCaptureFromScanner = false;
                              });
                              _inputFocusNode.requestFocus();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: hasError ? _errorRed : borderColor,
                        width: hasError ? 1.5 : 1.0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: hasError ? _errorRed : borderColor,
                        width: hasError ? 1.5 : 1.0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: hasError ? _errorRed : theme.colorScheme.primary,
                        width: hasError ? 1.5 : 1.6,
                      ),
                    ),
                  ),
                ),
                if (hasError) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.error_outline_rounded,
                          size: 14,
                          color: _errorRed,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _uidError!,
                          style: const TextStyle(
                            color: _errorRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  Text(
                    '8–14 hex characters (0–9, A–F). Syncs automatically with ESP32 classroom terminals.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Equal-sized Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: AppSecondaryButton(
                        label: 'Cancel',
                        height: 42,
                        onPressed: (_isSubmitting || _isUnlinking)
                            ? null
                            : () => Navigator.of(context).pop(null),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPrimaryButton(
                        label: 'Link RFID Card',
                        icon: Icons.contactless_rounded,
                        height: 42,
                        isLoading: _isSubmitting,
                        onPressed: (_isSubmitting || _isUnlinking)
                            ? null
                            : _validateAndSubmit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
