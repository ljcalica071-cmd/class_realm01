import 'package:flutter/material.dart';

class TeacherTopSummaryCard extends StatelessWidget {
  final String title;
  final String mainValue;
  final String subText;
  final Color subColor;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const TeacherTopSummaryCard({
    super.key,
    required this.title,
    required this.mainValue,
    required this.subText,
    required this.subColor,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      // The Card automatically applies the 30% Surface Color, border radius and soft shadows
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              mainValue,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: subColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
