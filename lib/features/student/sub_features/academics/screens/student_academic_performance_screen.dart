import 'package:flutter/material.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/student_dashboard_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class StudentAcademicPerformanceScreen extends StatefulWidget {
  const StudentAcademicPerformanceScreen({super.key});

  @override
  State<StudentAcademicPerformanceScreen> createState() =>
      _StudentAcademicPerformanceScreenState();
}

class _StudentAcademicPerformanceScreenState
    extends State<StudentAcademicPerformanceScreen> {
  Future<void> _refreshPerformance() async {
    try {
      final dashboard = await StudentDashboardRepository.instance.loadDashboard(
        forceRefresh: true,
      );
      AuthRepository.instance.setCurrentUser(dashboard.student);
      if (mounted) setState(() {});
    } catch (_) {
      // Keep cached display intact if offline
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dashboard = StudentDashboardRepository.instance.currentDashboard;
    final student =
        dashboard?.student ??
        AuthRepository.instance.currentUser ??
        UserModel(
          id: '',
          username: '',
          fullName: 'Student',
          email: '',
          role: UserRole.student,
        );

    final schoolInfo = [
      if (student.gradeLevel?.isNotEmpty == true) 'Grade ${student.gradeLevel}',
      if (student.departmentOrSection?.isNotEmpty == true)
        student.departmentOrSection!,
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Performance'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: AppPullToRefresh(
        onRefresh: _refreshPerformance,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            // Student Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      student.fullName.isNotEmpty
                          ? student.fullName.trim()[0].toUpperCase()
                          : 'S',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (schoolInfo.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            schoolInfo,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        if (student.lrn?.isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(
                            'LRN: ${student.lrn}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Polished Empty State Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: isDark ? 0.14 : 0.09,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(
                        alpha: isDark ? 0.18 : 0.1,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.school_outlined,
                      size: 36,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'No Academic Records Yet',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your official senior high school academic records and curriculum evaluations will appear here.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
