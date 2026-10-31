import 'package:flutter/material.dart';
import 'package:class_realm/data/repositories/student_dashboard_repository.dart';
import 'package:class_realm/features/student/shared/widgets/student_classwork_card.dart';
import 'package:class_realm/models/student_dashboard_models.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
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

  Future<void> _loadRequirements({
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    setState(() {
      if (!silent) {
        _isLoading = true;
      }
      _loadError = null;
    });
    try {
      final dashboard = await StudentDashboardRepository.instance.loadDashboard(
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(
          () => _requirements = dashboard.classwork
              .where((item) => item.type == 'performance_task')
              .toList(),
        );
      }
    } catch (error) {
      if (mounted && (!silent || _requirements.isEmpty)) {
        setState(() => _loadError = error);
      }
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
      ),
      body: _isLoading
          ? Center(
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: theme.colorScheme.primary,
                size: 40,
              ),
            )
          : AppPullToRefresh(
              onRefresh: () =>
                  _loadRequirements(forceRefresh: true, silent: true),
              child: _loadError != null
                  ? AppPullToRefresh.scrollableState(
                      child: _buildMessage(
                        context,
                        icon: Icons.cloud_off_outlined,
                        title: 'Could not load performance tasks',
                        message: _loadError.toString(),
                        action: TextButton.icon(
                          onPressed: () =>
                              _loadRequirements(forceRefresh: true),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ),
                    )
                  : _requirements.isEmpty
                  ? AppPullToRefresh.scrollableState(
                      child: _buildMessage(
                        context,
                        icon: Icons.workspace_premium_outlined,
                        title: 'No performance tasks yet',
                        message:
                            'Performance tasks posted by your teachers will appear here.',
                      ),
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
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
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isDark ? 0.14 : 0.09,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(
                alpha: isDark ? 0.18 : 0.1,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 14),
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
    );
  }
}
