import 'package:flutter/material.dart';

/// YouTube-style traveling shine shimmer wrapper
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.28)
        : Colors.white;

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.8, -0.3),
              end: const Alignment(1.8, 0.3),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.1, 0.5, 0.9],
              transform: _SlidingGradientTransform(
                slidePercent: _shimmerController.value,
              ),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2.6 - 1.3),
      0.0,
      0.0,
    );
  }
}

/// Helper block for shimmer skeleton building
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Preset: Overview KPI Card Skeleton
class ShimmerKpiCard extends StatelessWidget {
  const ShimmerKpiCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: const ShimmerLoading(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBox(width: 90, height: 14, borderRadius: 4),
                ShimmerBox(width: 34, height: 34, borderRadius: 10),
              ],
            ),
            SizedBox(height: 12),
            ShimmerBox(width: 70, height: 26, borderRadius: 6),
            SizedBox(height: 8),
            ShimmerBox(width: 130, height: 12, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

/// Preset: Academic School Year Card Skeleton
class ShimmerAcademicCard extends StatelessWidget {
  const ShimmerAcademicCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: const ShimmerLoading(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ShimmerBox(width: 36, height: 36, borderRadius: 10),
                    SizedBox(width: 12),
                    ShimmerBox(width: 220, height: 18, borderRadius: 4),
                  ],
                ),
                ShimmerBox(width: 140, height: 38, borderRadius: 10),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                ShimmerBox(width: 120, height: 26, borderRadius: 8),
                SizedBox(width: 12),
                ShimmerBox(width: 180, height: 26, borderRadius: 8),
              ],
            ),
            SizedBox(height: 18),
            Row(
              children: [
                ShimmerBox(width: 160, height: 14, borderRadius: 4),
                SizedBox(width: 12),
                ShimmerBox(width: 140, height: 36, borderRadius: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Preset: Compose Announcement Card Skeleton
class ShimmerComposeCard extends StatelessWidget {
  const ShimmerComposeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: const ShimmerLoading(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShimmerBox(width: 36, height: 36, borderRadius: 10),
                SizedBox(width: 12),
                ShimmerBox(width: 240, height: 18, borderRadius: 4),
              ],
            ),
            SizedBox(height: 20),
            ShimmerBox(width: 110, height: 14, borderRadius: 4),
            SizedBox(height: 8),
            Row(
              children: [
                ShimmerBox(width: 90, height: 34, borderRadius: 8),
                SizedBox(width: 8),
                ShimmerBox(width: 90, height: 34, borderRadius: 8),
                SizedBox(width: 8),
                ShimmerBox(width: 90, height: 34, borderRadius: 8),
              ],
            ),
            SizedBox(height: 18),
            ShimmerBox(width: double.infinity, height: 44, borderRadius: 10),
            SizedBox(height: 14),
            ShimmerBox(width: double.infinity, height: 90, borderRadius: 10),
            SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBox(width: 120, height: 14, borderRadius: 4),
                ShimmerBox(width: 130, height: 38, borderRadius: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Preset: Broadcast Item Skeleton
class ShimmerBroadcastItem extends StatelessWidget {
  const ShimmerBroadcastItem({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: const ShimmerLoading(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBox(width: 180, height: 16, borderRadius: 4),
                ShimmerBox(width: 70, height: 22, borderRadius: 6),
              ],
            ),
            SizedBox(height: 10),
            ShimmerBox(width: double.infinity, height: 14, borderRadius: 4),
            SizedBox(height: 6),
            ShimmerBox(width: 200, height: 14, borderRadius: 4),
            SizedBox(height: 12),
            Row(
              children: [
                ShimmerBox(width: 80, height: 12, borderRadius: 4),
                SizedBox(width: 16),
                ShimmerBox(width: 60, height: 12, borderRadius: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Preset: Teacher Dashboard Stat Card Skeleton
class ShimmerTeacherStatCard extends StatelessWidget {
  const ShimmerTeacherStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: const ShimmerLoading(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBox(width: 110, height: 14, borderRadius: 4),
                ShimmerBox(width: 42, height: 42, borderRadius: 12),
              ],
            ),
            SizedBox(height: 16),
            ShimmerBox(width: 60, height: 38, borderRadius: 8),
            SizedBox(height: 12),
            ShimmerBox(width: 120, height: 24, borderRadius: 8),
          ],
        ),
      ),
    );
  }
}

/// Preset: Teacher Subject Card Skeleton (Classroom Setup)
class ShimmerTeacherSubjectCard extends StatelessWidget {
  const ShimmerTeacherSubjectCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: const ShimmerLoading(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBox(width: 70, height: 20, borderRadius: 6),
                Row(
                  children: [
                    ShimmerBox(width: 24, height: 24, borderRadius: 6),
                    SizedBox(width: 8),
                    ShimmerBox(width: 24, height: 24, borderRadius: 6),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            ShimmerBox(width: 200, height: 18, borderRadius: 4),
            SizedBox(height: 12),
            Row(
              children: [
                ShimmerBox(width: 80, height: 12, borderRadius: 4),
                SizedBox(width: 12),
                ShimmerBox(width: 110, height: 12, borderRadius: 4),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                ShimmerBox(width: 60, height: 20, borderRadius: 6),
                SizedBox(width: 6),
                ShimmerBox(width: 60, height: 20, borderRadius: 6),
                SizedBox(width: 6),
                ShimmerBox(width: 60, height: 20, borderRadius: 6),
              ],
            ),
            Spacer(),
            ShimmerBox(width: double.infinity, height: 38, borderRadius: 8),
            SizedBox(height: 10),
            ShimmerBox(width: double.infinity, height: 38, borderRadius: 10),
          ],
        ),
      ),
    );
  }
}

/// Preset: Teacher Management Table Skeleton (Students & Parents)
class ShimmerManagementTable extends StatelessWidget {
  final int rowCount;
  const ShimmerManagementTable({super.key, this.rowCount = 5});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: ShimmerLoading(
        child: Column(
          children: [
            // Filter Bar Skeleton
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: const [
                  ShimmerBox(width: 120, height: 36, borderRadius: 8),
                  SizedBox(width: 10),
                  ShimmerBox(width: 180, height: 36, borderRadius: 8),
                  SizedBox(width: 10),
                  ShimmerBox(width: 120, height: 36, borderRadius: 8),
                  Spacer(),
                  ShimmerBox(width: 140, height: 36, borderRadius: 8),
                  SizedBox(width: 10),
                  ShimmerBox(width: 120, height: 36, borderRadius: 8),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            // Table Header Skeleton
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: const [
                  ShimmerBox(width: 30, height: 14, borderRadius: 4),
                  SizedBox(width: 20),
                  ShimmerBox(width: 100, height: 14, borderRadius: 4),
                  SizedBox(width: 40),
                  ShimmerBox(width: 150, height: 14, borderRadius: 4),
                  SizedBox(width: 40),
                  ShimmerBox(width: 120, height: 14, borderRadius: 4),
                  Spacer(),
                  ShimmerBox(width: 80, height: 14, borderRadius: 4),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            // Table Rows Skeleton
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rowCount,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
              itemBuilder: (_, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: const [
                    ShimmerBox(width: 30, height: 14, borderRadius: 4),
                    SizedBox(width: 20),
                    ShimmerBox(width: 110, height: 14, borderRadius: 4),
                    SizedBox(width: 40),
                    ShimmerBox(width: 180, height: 14, borderRadius: 4),
                    SizedBox(width: 40),
                    ShimmerBox(width: 130, height: 14, borderRadius: 4),
                    Spacer(),
                    ShimmerBox(width: 70, height: 26, borderRadius: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Preset: Attendance Tab Skeleton
class ShimmerAttendanceSkeleton extends StatelessWidget {
  const ShimmerAttendanceSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ShimmerLoading(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class & Section Selection Card Skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: const [
                ShimmerBox(width: 120, height: 40, borderRadius: 10),
                SizedBox(width: 14),
                ShimmerBox(width: 220, height: 40, borderRadius: 10),
                SizedBox(width: 14),
                ShimmerBox(width: 140, height: 40, borderRadius: 10),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Action Toolbar & 4 Stats Cards Skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: const [
                    Expanded(child: ShimmerBox(height: 42, borderRadius: 10)),
                    SizedBox(width: 14),
                    ShimmerBox(width: 160, height: 42, borderRadius: 10),
                    SizedBox(width: 14),
                    ShimmerBox(width: 100, height: 42, borderRadius: 10),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    ShimmerBox(width: 130, height: 38, borderRadius: 8),
                    SizedBox(width: 10),
                    ShimmerBox(width: 170, height: 38, borderRadius: 8),
                    SizedBox(width: 10),
                    ShimmerBox(width: 130, height: 38, borderRadius: 8),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    Expanded(child: ShimmerBox(height: 60, borderRadius: 12)),
                    SizedBox(width: 12),
                    Expanded(child: ShimmerBox(height: 60, borderRadius: 12)),
                    SizedBox(width: 12),
                    Expanded(child: ShimmerBox(height: 60, borderRadius: 12)),
                    SizedBox(width: 12),
                    Expanded(child: ShimmerBox(height: 60, borderRadius: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Student Roster Rows Skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: List.generate(
                5,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: const [
                      ShimmerBox(width: 24, height: 16, borderRadius: 4),
                      SizedBox(width: 12),
                      ShimmerBox(width: 36, height: 36, borderRadius: 18),
                      SizedBox(width: 14),
                      ShimmerBox(width: 180, height: 16, borderRadius: 4),
                      Spacer(),
                      ShimmerBox(width: 180, height: 32, borderRadius: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Preset: Teacher Classwork / Assessment Card Skeleton (WW, PT, EX)
class ShimmerClassworkCard extends StatelessWidget {
  const ShimmerClassworkCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: const ShimmerLoading(
        child: Row(
          children: [
            ShimmerBox(width: 36, height: 36, borderRadius: 10),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShimmerBox(width: 180, height: 16, borderRadius: 4),
                      SizedBox(width: 8),
                      ShimmerBox(width: 40, height: 18, borderRadius: 4),
                    ],
                  ),
                  SizedBox(height: 8),
                  ShimmerBox(width: 260, height: 12, borderRadius: 4),
                  SizedBox(height: 6),
                  ShimmerBox(width: 150, height: 12, borderRadius: 4),
                ],
              ),
            ),
            SizedBox(width: 16),
            ShimmerBox(width: 120, height: 34, borderRadius: 8),
            SizedBox(width: 8),
            ShimmerBox(width: 32, height: 32, borderRadius: 8),
          ],
        ),
      ),
    );
  }
}

/// Preset: Teacher Profile Skeleton
class ShimmerProfileSkeleton extends StatelessWidget {
  const ShimmerProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ShimmerLoading(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Cover and Avatar Card
            Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  // Cover Photo skeleton
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -50),
                          child: const Center(
                            child: ShimmerBox(width: 100, height: 100, borderRadius: 50),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const ShimmerBox(width: 220, height: 22, borderRadius: 6),
                        const SizedBox(height: 8),
                        const ShimmerBox(width: 140, height: 14, borderRadius: 4),
                        const SizedBox(height: 8),
                        const ShimmerBox(width: 180, height: 14, borderRadius: 4),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            ShimmerBox(width: 130, height: 38, borderRadius: 8),
                            SizedBox(width: 12),
                            ShimmerBox(width: 130, height: 38, borderRadius: 8),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Info Sections
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? theme.colorScheme.surface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          ShimmerBox(width: 100, height: 18, borderRadius: 4),
                          SizedBox(height: 16),
                          ShimmerBox(width: double.infinity, height: 14, borderRadius: 4),
                          SizedBox(height: 10),
                          ShimmerBox(width: double.infinity, height: 14, borderRadius: 4),
                          SizedBox(height: 10),
                          ShimmerBox(width: 180, height: 14, borderRadius: 4),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? theme.colorScheme.surface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          ShimmerBox(width: 140, height: 18, borderRadius: 4),
                          SizedBox(height: 16),
                          ShimmerBox(width: double.infinity, height: 44, borderRadius: 8),
                          SizedBox(height: 12),
                          ShimmerBox(width: double.infinity, height: 44, borderRadius: 8),
                          SizedBox(height: 12),
                          ShimmerBox(width: double.infinity, height: 44, borderRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
