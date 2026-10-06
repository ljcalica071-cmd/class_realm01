import 'package:flutter/material.dart';

class TeacherTopSummaryCard extends StatelessWidget {
  final String title;
  final String mainValue;
  final String subText;
  final Color baseColor;
  final IconData icon;

  const TeacherTopSummaryCard({
    super.key,
    required this.title,
    required this.mainValue,
    required this.subText,
    required this.baseColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: baseColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      letterSpacing: 1.2,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          baseColor.withValues(alpha: 0.25),
                          baseColor.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: baseColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(icon, color: baseColor, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                mainValue,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: baseColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  subText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: baseColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
