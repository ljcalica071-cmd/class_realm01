import 'package:flutter/material.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/core/theme/app_theme.dart';

/// Expandable Notification Card with Unbroken Long String Protection (Edge Cases #8 & #9)
/// - Configured with softWrap: true and TextOverflow.clip inside a constrained LayoutBuilder
/// - Inserts zero-width break opportunities for strings without spaces (e.g. "AAAAA...")
/// - Smooth expand/collapse toggle ("See more" / "See less")
class ExpandableNotificationCard extends StatefulWidget {
  final AppNotificationModel notification;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final bool showDelete;

  const ExpandableNotificationCard({
    super.key,
    required this.notification,
    this.onDelete,
    this.onTap,
    this.showDelete = false,
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
  State<ExpandableNotificationCard> createState() => _ExpandableNotificationCardState();
}

class _ExpandableNotificationCardState extends State<ExpandableNotificationCard> {
  bool _isExpanded = false;

  String _formatAudience(String audience) {
    switch (audience) {
      case 'teachers':
        return 'Teachers Only';
      case 'students_parents':
        return 'Students & Parents';
      case 'all':
      default:
        return 'All Users';
    }
  }

  Color _getAudienceColor(String audience) {
    switch (audience) {
      case 'teachers':
        return AppTheme.catPurple;
      case 'students_parents':
        return AppTheme.catBlue;
      case 'all':
      default:
        return AppTheme.catGreen;
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final n = widget.notification;

    final formattedMessage = ExpandableNotificationCard.wrapUnbrokenString(n.message);
    final isLongMessage = n.message.length > 180;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      color: isDark ? theme.colorScheme.surface : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTap ?? () => setState(() => _isExpanded = !_isExpanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Title & Badges
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getAudienceColor(n.targetAudience).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.campaign_rounded,
                      size: 20,
                      color: _getAudienceColor(n.targetAudience),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title and Audience
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ExpandableNotificationCard.wrapUnbrokenString(n.title),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: theme.colorScheme.onSurface,
                          ),
                          softWrap: true,
                          overflow: TextOverflow.clip,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getAudienceColor(n.targetAudience).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _formatAudience(n.targetAudience),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _getAudienceColor(n.targetAudience),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(n.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.showDelete && widget.onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      color: AppTheme.catRed.withValues(alpha: 0.8),
                      tooltip: 'Archive Broadcast',
                      onPressed: widget.onDelete,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Message Body
              LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    width: constraints.maxWidth,
                    child: Text(
                      formattedMessage,
                      maxLines: _isExpanded ? null : 3,
                      softWrap: true,
                      overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  );
                },
              ),

              // See more / See less button
              if (isLongMessage)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: Text(
                      _isExpanded ? 'See less' : 'See more',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
