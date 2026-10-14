import 'package:flutter/material.dart';
import 'package:class_realm/data/repositories/student_dashboard_repository.dart';
import 'package:class_realm/features/student/shared/widgets/student_classwork_card.dart';
import 'package:class_realm/models/student_dashboard_models.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class StudentRequirementsScreen extends StatefulWidget {
  const StudentRequirementsScreen({super.key});

  @override
  State<StudentRequirementsScreen> createState() =>
      _StudentRequirementsScreenState();
}

class _StudentRequirementsScreenState extends State<StudentRequirementsScreen> {
  List<StudentClassworkModel> _requirements = const [];
  Object? _loadError;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequirements();
  }

  Future<void> _loadRequirements() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final dashboard = await StudentDashboardRepository.instance
          .loadDashboard();
      if (mounted) {
        setState(
          () => _requirements = dashboard.classwork
              .where((item) => item.type == 'performance_task')
              .toList(),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Task'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadRequirements,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: theme.colorScheme.primary,
                size: 40,
              ),
            )
          : _loadError != null
          ? _buildMessage(
              context,
              icon: Icons.cloud_off_outlined,
              title: 'Could not load performance tasks',
              message: _loadError.toString(),
              action: TextButton.icon(
                onPressed: _loadRequirements,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            )
          : _requirements.isEmpty
          ? _buildMessage(
              context,
              icon: Icons.workspace_premium_outlined,
              title: 'No performance tasks yet',
              message:
                  'Performance tasks posted by your teachers will appear here.',
            )
          : RefreshIndicator(
              onRefresh: _loadRequirements,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _requirements.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    StudentClassworkCard(classwork: _requirements[index]),
              ),
            ),
    );
  }

  Widget _buildMessage(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 12), action],
          ],
        ),
      ),
    );
  }
}
