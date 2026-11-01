import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/supabase_attendance_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/features/parent/widgets/widgets.dart';
import 'package:class_realm/data/repositories/supabase_parent_repository.dart';
import 'package:class_realm/core/services/session_activity_tracker.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/routes/app_routes.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  int _currentIndex = 0;
  int _selectedChildIndex = 0;
  bool _isLoadingStudents = true;
  List<UserModel> _linkedStudents = [];
  List<AttendanceRecord> _childAttendance = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    final savedTab = LocalStorageService.getActiveDashboardTab('parent');
    if (savedTab >= 0 && savedTab < 5) {
      _currentIndex = savedTab;
    }
    LocalStorageService.saveLastActiveRoute(AppRoutes.parentHome);
    _hydrateLinkedStudentsFromCache();
    _loadLinkedStudents();
  }

  void _hydrateLinkedStudentsFromCache() {
    final parent = AuthRepository.instance.currentUser;
    if (parent == null) return;
    final cached = AppDataCache.instance.getCached<List<UserModel>>(
      'parent_linked_students_${parent.id}',
      (json) => (json as List)
          .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
    if (cached != null && cached.isNotEmpty) {
      _linkedStudents = cached;
      _isLoadingStudents = false;
      _hydrateAttendanceFromCache(cached.first.id);
    }
  }

  void _hydrateAttendanceFromCache(String studentId) {
    if (studentId.isEmpty) return;
    final cachedAtt = AppDataCache.instance.getCached<List<AttendanceRecord>>(
      'parent_child_attendance_$studentId',
      (json) => (json as List)
          .map(
            (e) =>
                AttendanceRecord.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
    if (cachedAtt != null) {
      _childAttendance = cachedAtt;
    }
  }

  Future<void> _loadLinkedStudents() async {
    final parent = AuthRepository.instance.currentUser;
    if (parent == null) {
      if (mounted) setState(() => _isLoadingStudents = false);
      return;
    }

    try {
      final repo = SupabaseParentRepository();
      final students = await repo.getLinkedStudentsForParent(parent.id);
      if (!mounted) return;
      setState(() {
        _linkedStudents = students;
        _isLoadingStudents = false;
      });
      AppDataCache.instance.set(
        'parent_linked_students_${parent.id}',
        students.map((s) => s.toJson()).toList(),
      );

      if (students.isNotEmpty) {
        final safeIndex = _selectedChildIndex % students.length;
        _loadChildAttendance(students[safeIndex].id);
      }
    } catch (e) {
      debugPrint('Error loading linked students: $e');
      if (mounted) {
        setState(() => _isLoadingStudents = false);
      }
    }
  }

  Future<void> _loadChildAttendance(String studentId) async {
    if (studentId.isEmpty) return;
    _hydrateAttendanceFromCache(studentId);

    try {
      final records = await SupabaseAttendanceRepository.instance
          .getAttendanceForStudent(studentId);
      if (!mounted) return;
      setState(() {
        _childAttendance = records;
      });
      AppDataCache.instance.set(
        'parent_child_attendance_$studentId',
        records.map((r) => r.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('Error loading child attendance: $e');
    }
  }

  List<UserModel> _getLinkedStudents(UserModel parent) {
    return _linkedStudents;
  }

  void _switchChild(int targetIndex) {
    if (_linkedStudents.isEmpty) return;
    final safeIndex = targetIndex % _linkedStudents.length;
    if (safeIndex == _selectedChildIndex && _childAttendance.isNotEmpty) return;

    setState(() {
      _selectedChildIndex = safeIndex;
    });

    final targetChild = _linkedStudents[safeIndex];
    _loadChildAttendance(targetChild.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parent =
        AuthRepository.instance.currentUser ??
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
              attendance: _childAttendance,
              onSelectChild: (child) {
                final idx = linkedStudents.indexWhere((c) => c.id == child.id);
                if (idx != -1) {
                  _switchChild(idx);
                }
              },
              onOpenAttendance: () => setState(() => _currentIndex = 1),
              onOpenGrades: () => setState(() => _currentIndex = 2),
            ),
            ParentAttendanceTab(attendance: _childAttendance),
            ParentGradesTab(student: linkedStudent),
            const ParentNotificationsTab(),
            ParentProfileTab(parent: parent, linkedStudent: linkedStudent),
          ]
        : [
            _buildNoChildEmptyState(theme),
            _buildNoChildEmptyState(theme),
            _buildNoChildEmptyState(theme),
            _buildNoChildEmptyState(theme),
            ParentProfileTab(parent: parent, linkedStudent: null),
          ];

    return SessionActivityTracker(
      child: Scaffold(
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
            _buildTopRightChildSwitcher(theme, linkedStudents, linkedStudent),
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
                Expanded(
                  child: _isLoadingStudents
                      ? Center(
                          child: CircularProgressIndicator(
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : StaggeredEntrance(
                          key: ValueKey(_currentIndex),
                          index: 0,
                          duration: const Duration(milliseconds: 280),
                          child: pages[_currentIndex],
                        ),
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
          onTap: (index) {
            setState(() => _currentIndex = index);
            LocalStorageService.saveActiveDashboardTab('parent', index);
          },
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
      ),
    );
  }

  Widget _buildTopRightChildSwitcher(
    ThemeData theme,
    List<UserModel> students,
    UserModel? activeChild,
  ) {
    if (students.isEmpty) return const SizedBox.shrink();

    // If only 1 child is linked, show a clean, non-intrusive badge
    if (students.length == 1) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 11,
              backgroundColor: theme.colorScheme.primary,
              child: Text(
                (activeChild?.firstName?.isNotEmpty ?? false)
                    ? activeChild!.firstName![0].toUpperCase()
                    : 'C',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                activeChild?.fullName ?? 'Child',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Multiple children linked (2, 3, or more): Elegant Dropdown Menu
    return PopupMenuButton<int>(
      tooltip: 'Switch Active Child',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      color: theme.colorScheme.surface,
      elevation: 6,
      onSelected: (int targetIndex) {
        _switchChild(targetIndex);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: theme.colorScheme.primary,
              child: Text(
                (activeChild?.firstName?.isNotEmpty ?? false)
                    ? activeChild!.firstName![0].toUpperCase()
                    : 'C',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeChild?.fullName ?? 'Select Child',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (activeChild?.departmentOrSection != null)
                    Text(
                      activeChild!.departmentOrSection!,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) {
        return List<PopupMenuEntry<int>>.generate(
          students.length,
          (index) {
            final child = students[index];
            final isSelected = index == (_selectedChildIndex % students.length);

            return PopupMenuItem<int>(
              value: index,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      child: Text(
                        (child.firstName?.isNotEmpty ?? false)
                            ? child.firstName![0].toUpperCase()
                            : 'C',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child.fullName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              if (child.lrn != null &&
                                  child.lrn!.isNotEmpty) ...[
                                Text(
                                  'LRN: ${child.lrn}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.55),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (child.departmentOrSection != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    child.departmentOrSection!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
              'Your parent account has not been linked to a student yet. Contact the school administrator to connect your account to your childâ€™s LRN.',
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
