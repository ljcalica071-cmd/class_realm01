import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/supabase_notification_repository.dart';

/// Minimalist Expandable Notification Card (60-30-10 System)
/// - Strict 2-line preview clamp when collapsed with "See more" / "See less" toggle
/// - 60-30-10 palette with distinct 3/6/10 absence warning badges
/// - Zero emojis; real Lucide vector icons
/// - Unbroken long string protection (\u200B zero-width spacing)
class ExpandableNotificationCard extends StatefulWidget {
  final AppNotificationModel notification;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onTap;
  final bool showDelete;
  final bool showEdit;
  final int maxCollapsedLines;
  final bool showUnreadIndicator;

  const ExpandableNotificationCard({
    super.key,
    required this.notification,
    this.onDelete,
    this.onEdit,
    this.onTap,
    this.showDelete = false,
    this.showEdit = false,
    this.maxCollapsedLines = 2,
    this.showUnreadIndicator = true,
  });

  /// Injects zero-width spaces (\u200B) every 20 characters into strings without spaces
  /// to ensure unbroken strings like "AAAAA..." wrap cleanly without overflowing horizontally.
  static String wrapUnbrokenString(String text, {int chunkLength = 20}) {
    if (text.isEmpty) return text;
    final buffer = StringBuffer();
    int consecutiveNonSpace = 0;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      buffer.write(char);
      if (char == ' ' || char == '\n' || char == '\t') {
        consecutiveNonSpace = 0;
      } else {
        consecutiveNonSpace++;
        if (consecutiveNonSpace >= chunkLength) {
          buffer.write('\u200B'); // Zero-width space
          consecutiveNonSpace = 0;
        }
      }
    }
    return buffer.toString();
  }

  @override
  State<ExpandableNotificationCard> createState() =>
      _ExpandableNotificationCardState();
}

class _ExpandableNotificationCardState
    extends State<ExpandableNotificationCard> {
  bool _isExpanded = false;

  // 60-30-10 Colors
  static const Color _crSteelBlue = Color(0xFF3A6B88);
  static const Color _crAmber = Color(0xFFF59E0B);
  static const Color _crOrange = Color(0xFFEA580C);
  static const Color _crRed = Color(0xFFDC2626);
  static const Color _crSlateDark = Color(0xFF0F172A);
  static const Color _crSlateBody = Color(0xFF334155);
  static const Color _crSlateMuted = Color(0xFF64748B);

  int _detectWarningLevel(String title, String message) {
    final combined = '$title $message'.toLowerCase();
    if (combined.contains('10 absence') ||
        combined.contains('critical') ||
        combined.contains('final warning') ||
        combined.contains('sardo')) {
      return 10;
    }
    if (combined.contains('6 absence') ||
        combined.contains('2nd warning') ||
        combined.contains('2nd attendance')) {
      return 6;
    }
    if (combined.contains('3 absence') ||
        combined.contains('1st warning') ||
        combined.contains('1st attendance') ||
        combined.contains('early attendance')) {
      return 3;
    }
    return 0;
  }

  Color _getAccentColor(int warningLevel) {
    switch (warningLevel) {
      case 10:
        return _crRed;
      case 6:
        return _crOrange;
      case 3:
        return _crAmber;
      default:
        return _crSteelBlue;
    }
  }

  IconData _getIcon(int warningLevel, String type) {
    switch (warningLevel) {
      case 10:
        return LucideIcons.octagonAlert;
      case 6:
        return LucideIcons.triangleAlert;
      case 3:
        return LucideIcons.alertCircle;
      default:
        if (type == 'attendance') return LucideIcons.calendarCheck;
        return LucideIcons.bell;
    }
  }

  String _getBadgeLabel(int warningLevel, String audience) {
    switch (warningLevel) {
      case 10:
        return 'Final Warning';
      case 6:
        return '2nd Warning';
      case 3:
        return '1st Warning';
      default:
        switch (audience) {
          case 'teachers':
            return 'Teachers Only';
          case 'students':
            return 'Students Only';
          case 'parents':
            return 'Parents Only';
          case 'students_parents':
            return 'Students & Parents';
          default:
            return 'General Announcement';
        }
    }
  }

  String _cleanTitle(String rawTitle) {
    return rawTitle
        .replaceFirst(
          RegExp(
            r'^(1st|2nd|3rd|Final|Critical|URGENT:?)\s+Attendance\s+(Warning|Notice|Alert)\s*[:—-]\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  void _markAsRead() {
    final user = AuthRepository.instance.currentUser;
    if (user != null && widget.notification.id.isNotEmpty) {
      SupabaseNotificationRepository.instance.markAsRead(
        user.id,
        widget.notification.id,
      );
      SupabaseNotificationRepository.instance.calculateUnreadCount(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final n = widget.notification;

    final warningLevel = _detectWarningLevel(n.title, n.message);
    final accentColor = _getAccentColor(warningLevel);
    final iconData = _getIcon(warningLevel, n.type);
    final badgeLabel = _getBadgeLabel(warningLevel, n.targetAudience);

    final formattedTitle = ExpandableNotificationCard.wrapUnbrokenString(
      _cleanTitle(n.title),
    );
    final formattedMessage = ExpandableNotificationCard.wrapUnbrokenString(
      n.message,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double textMaxWidth = (constraints.maxWidth - 48).clamp(
          100.0,
          2000.0,
        );
        const textStyle = TextStyle(fontSize: 13, height: 1.45);
        final effectiveTextStyle = DefaultTextStyle.of(context).style.merge(
          textStyle.copyWith(fontWeight: FontWeight.w500),
        );

        final textSpan = TextSpan(
          text: formattedMessage,
          style: effectiveTextStyle,
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: Directionality.of(context),
          maxLines: widget.maxCollapsedLines,
        )..layout(maxWidth: textMaxWidth);

        final bool didExceedMaxLines = textPainter.didExceedMaxLines;
        final bool canExpand =
            didExceedMaxLines ||
            n.message.trim().length > 130 ||
            n.message.contains('\n');

        final currentUserId = AuthRepository.instance.currentUser?.id ?? '';

        return ValueListenableBuilder<int>(
          valueListenable: LocalStorageService.notificationReadStateEpoch,
          builder: (context, _, child) {
            final isReadNow = !widget.showUnreadIndicator
                ? true
                : (n.isRead ||
                      LocalStorageService.isNotificationRead(
                        currentUserId,
                        n.id,
                      ));

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? (isReadNow
                          ? const Color(0xFF1E293B)
                          : const Color(0xFF1E2B45))
                    : (isReadNow ? Colors.white : const Color(0xFFEFF6FF)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isReadNow
                      ? (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0))
                      : (isDark
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.7)
                            : const Color(0xFF93C5FD)),
                  width: isReadNow ? 1 : 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    if (widget.showUnreadIndicator) {
                      _markAsRead();
                    }
                    if (widget.onTap != null) {
                      widget.onTap!();
                    } else if (canExpand) {
                      setState(() => _isExpanded = !_isExpanded);
                    }
                  },
                  child: Stack(
                    children: [
                      // 10% Left Accent Indicator Bar
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 4,
                        child: Container(color: accentColor),
                      ),

                      // Card Body
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: Icon + Meta Badge + Time + Delete
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Icon Circle
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    iconData,
                                    size: 16,
                                    color: accentColor,
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Badge Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    badgeLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: accentColor,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Timestamp
                                Text(
                                  _formatTime(n.timestamp),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : _crSlateMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),

                                const Spacer(),

                                // Unread Dot Indicator
                                if (!isReadNow) ...[
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF3B82F6),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],

                                // Optional Edit Action
                                if (widget.showEdit &&
                                    widget.onEdit != null) ...[
                                  IconButton(
                                    icon: Icon(
                                      LucideIcons.pencil,
                                      size: 15,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Edit Announcement',
                                    onPressed: widget.onEdit,
                                  ),
                                  const SizedBox(width: 10),
                                ],

                                // Optional Delete Action
                                if (widget.showDelete &&
                                    widget.onDelete != null)
                                  IconButton(
                                    icon: Icon(
                                      LucideIcons.trash2,
                                      size: 16,
                                      color: AppTheme.catRed.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Delete Announcement',
                                    onPressed: widget.onDelete,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Title: Bold on unread, normal on read
                            Text(
                              formattedTitle,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: isReadNow
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                                color: isDark ? Colors.white : _crSlateDark,
                                height: 1.3,
                              ),
                              softWrap: true,
                            ),
                            const SizedBox(height: 6),

                            // Message Body (Strict 2-line preview when collapsed)
                            Text(
                              formattedMessage,
                              maxLines: _isExpanded
                                  ? null
                                  : widget.maxCollapsedLines,
                              softWrap: true,
                              overflow: _isExpanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: textStyle.copyWith(
                                fontWeight: isReadNow
                                    ? FontWeight.w400
                                    : FontWeight.w500,
                                color: isDark
                                    ? (isReadNow
                                          ? const Color(0xFFCBD5E1)
                                          : Colors.white)
                                    : (isReadNow
                                          ? _crSlateBody
                                          : const Color(0xFF0F172A)),
                              ),
                            ),

                            // See more / See less button
                            if (canExpand) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  if (widget.showUnreadIndicator) {
                                    _markAsRead();
                                  }
                                  setState(() => _isExpanded = !_isExpanded);
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _isExpanded ? 'See less' : 'See more',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? const Color(0xFF60A5FA)
                                            : _crSteelBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(
                                      _isExpanded
                                          ? LucideIcons.chevronUp
                                          : LucideIcons.chevronDown,
                                      size: 13,
                                      color: isDark
                                          ? const Color(0xFF60A5FA)
                                          : _crSteelBlue,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
