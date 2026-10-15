import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/widgets/common/sync_status_badge.dart';
import 'package:class_realm/features/parent/widgets/widgets.dart';
import 'package:class_realm/data/repositories/supabase_parent_repository.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  int _currentIndex = 0;
  int _selectedChildIndex = 0;
  bool _isSwitchingChild = false;
  bool _isLoadingStudents = true;
  List<UserModel> _linkedStudents = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadLinkedStudents();
  }

  Future<void> _loadLinkedStudents() async {
    final parent =
        AuthRepository.instance.currentUser ??
        MockDatabase.instance.currentUser;
    if (parent == null) {
      if (mounted) setState(() => _isLoadingStudents = false);
      return;
    }

    try {
      final repo = SupabaseParentRepository();
      final students = await repo.getLinkedStudentsForParent(parent.id);
      if (mounted) {
        setState(() {
          _linkedStudents = students;
          _isLoadingStudents = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading linked students: $e');
      if (mounted) {
        setState(() => _isLoadingStudents = false);
      }
    }
  }

  List<UserModel> _getLinkedStudents(UserModel parent) {
    if (_linkedStudents.isNotEmpty) return _linkedStudents;
    return MockDatabase.instance.users
        .where(
          (u) =>
              u.role == UserRole.student &&
              (u.id == parent.linkedStudentId ||
                  parent.linkedStudentId == null),
        )
        .take(1)
        .toList();
  }

  void _switchChildWithLoading(int targetIndex) async {
    if (_isSwitchingChild) return;
    _isSwitchingChild = true;

    final parent =
        AuthRepository.instance.currentUser ??
        MockDatabase.instance.currentUser ??
        UserModel(
          id: 'parent',
          username: 'parent',
          fullName: 'Parent User',
          email: '',
          role: UserRole.parent,
        );

    final linkedStudents = _getLinkedStudents(parent);
    if (linkedStudents.isEmpty) return;
    final targetChild = linkedStudents[targetIndex % linkedStudents.length];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: LoadingAnimationWidget.staggeredDotsWave(
                  color: Theme.of(context).colorScheme.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Switching Child Profile...',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Loading ${targetChild.fullName}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pop();

    setState(() {
      _selectedChildIndex = targetIndex % linkedStudents.length;
      _isSwitchingChild = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Active child switched to ${targetChild.fullName}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parent =
        AuthRepository.instance.currentUser ??
        MockDatabase.instance.currentUser ??
        UserModel(
          id: 'parent',
          username: 'parent',
          fullName: 'Parent User',
          email: '',
          role: UserRole.parent,
        );

    final linkedStudents = _getLinkedStudents(parent);
    final UserModel? linkedStudent = linkedStudents.isNotEmpty
        ? linkedStudents[_selectedChildIndex % linkedStudents.length]
        : null;

    final List<Widget> pages = linkedStudent != null
        ? [
            ParentStudentOverviewTab(
              linkedStudent: linkedStudent,
              allChildren: linkedStudents,
              onSelectChild: (child) {
                final idx = linkedStudents.indexWhere((c) => c.id == child.id);
                if (idx != -1 && idx != _selectedChildIndex) {
                  _switchChildWithLoading(idx);
                }
              },
            ),
            const ParentAttendanceTab(attendance: []),
            ParentGradesTab(student: linkedStudent),
            const ParentNotificationsTab(notifications: []),
            ParentProfileTab(parent: parent, linkedStudent: linkedStudent),
          ]
        : [
            _buildNoChildEmptyState(theme),
            _buildNoChildEmptyState(theme),
            _buildNoChildEmptyState(theme),
            _buildNoChildEmptyState(theme),
            ParentProfileTab(parent: parent, linkedStudent: null),
          ];

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text(
          'Parent Portal',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          if (linkedStudents.length > 1)
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              tooltip:
                  'Switch Child Profile (${linkedStudent?.firstName ?? ""})',
              onPressed: () {
                _switchChildWithLoading(_selectedChildIndex + 1);
              },
            ),
          IconButton(
            icon: Icon(
              theme.brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () {
              final isDark = theme.brightness != Brightness.dark;
              AppTheme.themeModeNotifier.value = isDark
                  ? ThemeMode.dark
                  : ThemeMode.light;
              LocalStorageService.saveUserThemeMode(
                parent.id,
                isDark,
                email: parent.email,
              );
            },
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SyncStatusBadge(),
            ),
          ),
        ],
      ),
      drawer: ParentDrawer(parent: parent, linkedStudent: linkedStudent),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final content = Column(
            children: [
              // Active Child Banner (if parent has multiple children)
              if (linkedStudents.length > 1 && linkedStudent != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.35,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_circle,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Viewing: ${linkedStudent.fullName} (${linkedStudent.departmentOrSection ?? "Active"})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: theme.colorScheme.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.swap_horiz, size: 16),
                        label: const Text(
                          'Switch',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () =>
                            _switchChildWithLoading(_selectedChildIndex + 1),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _isLoadingStudents
                    ? Center(
                        child: LoadingAnimationWidget.staggeredDotsWave(
                          color: theme.colorScheme.primary,
                          size: 40,
                        ),
                      )
                    : pages[_currentIndex],
              ),
            ],
          );
          if (constraints.maxWidth <= 600) return content;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: content,
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grade_outlined),
            activeIcon: Icon(Icons.grade),
            label: 'Grades',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildNoChildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.family_restroom_outlined,
                size: 38,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Linked Student Found',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your parent account has not been linked to a student yet. Contact the school administrator to connect your account to your child’s LRN.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
