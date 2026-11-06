import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/shared/services/in_app_notification_service.dart';

/// In-App Push Notification Banner Overlay
/// Listens to [InAppNotificationService.currentBannerNotifier] and smoothly
/// animates a heads-up top banner down when an alert arrives.
class InAppNotificationBannerOverlay extends StatelessWidget {
  final Widget child;

  const InAppNotificationBannerOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<InAppPushBannerData?>(
          valueListenable: InAppNotificationService.currentBannerNotifier,
          builder: (context, banner, _) {
            if (banner == null) {
              return const SizedBox.shrink();
            }
            return Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 0,
              right: 0,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _BannerCard(banner: banner),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BannerCard extends StatefulWidget {
  final InAppPushBannerData banner;

  const _BannerCard({required this.banner});

  @override
  State<_BannerCard> createState() => _BannerCardState();
}

class _BannerCardState extends State<_BannerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Color _accentColor(InAppNotificationSeverity severity) {
    switch (severity) {
      case InAppNotificationSeverity.warningLevel1:
        return const Color(0xFFF59E0B); // Amber
      case InAppNotificationSeverity.warningLevel2:
        return const Color(0xFFEA580C); // Orange
      case InAppNotificationSeverity.warningCritical:
        return const Color(0xFFDC2626); // Red
      case InAppNotificationSeverity.info:
        return const Color(0xFF3A6B88); // Steel Blue
    }
  }

  IconData _severityIcon(InAppNotificationSeverity severity) {
    switch (severity) {
      case InAppNotificationSeverity.warningLevel1:
        return LucideIcons.alertCircle;
      case InAppNotificationSeverity.warningLevel2:
        return LucideIcons.triangleAlert;
      case InAppNotificationSeverity.warningCritical:
        return LucideIcons.octagonAlert;
      case InAppNotificationSeverity.info:
        return LucideIcons.bell;
    }
  }

  String _severityLabel(InAppNotificationSeverity severity) {
    switch (severity) {
      case InAppNotificationSeverity.warningLevel1:
        return '1st Warning';
      case InAppNotificationSeverity.warningLevel2:
        return '2nd Warning';
      case InAppNotificationSeverity.warningCritical:
        return 'Final Warning';
      case InAppNotificationSeverity.info:
        return 'Notice';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = _accentColor(widget.banner.severity);
    final icon = _severityIcon(widget.banner.severity);
    final badgeLabel = _severityLabel(widget.banner.severity);

    return SlideTransition(
      position: _offsetAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Dismissible(
          key: ValueKey(widget.banner.id),
          direction: DismissDirection.up,
          onDismissed: (_) => InAppNotificationService.dismiss(),
          child: Material(
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                widget.banner.onTap?.call();
                InAppNotificationService.dismiss();
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      // Left Accent Bar (10% Rule)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 4.5,
                        child: Container(color: accent),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 16.5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Leading Icon Circle
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  icon,
                                  size: 17,
                                  color: accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Content: Tag + Title + Message
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Top Row: Badge + Subtitle/Time
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: accent.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            badgeLabel,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: accent,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                        if (widget.banner.subtitle != null) ...[
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              widget.banner.subtitle!,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? const Color(0xFF94A3B8)
                                                    : const Color(0xFF64748B),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 5),

                                    // Title
                                    Text(
                                      widget.banner.title,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),

                                    // Message (Concise 2 lines)
                                    Text(
                                      widget.banner.message,
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.4,
                                        color: isDark
                                            ? const Color(0xFFCBD5E1)
                                            : const Color(0xFF475569),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Dismiss Button (Overlay-safe GestureDetector)
                            GestureDetector(
                              onTap: () => InAppNotificationService.dismiss(),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
                                child: Icon(
                                  LucideIcons.x,
                                  size: 15,
                                  color: isDark
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF94A3B8),
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
            ),
          ),
        ),
      ),
    );
  }
}

