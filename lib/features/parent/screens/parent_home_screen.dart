import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
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
  UserModel? _parentProfile;
  List<UserModel> _linkedStudents = [];
  List<AttendanceRecord> _childAttendance = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const List<String> _tabTitles = [
    'Parent Portal',
    'Attendance',
    'Schedule',
    'Alerts',
    'Profile',
  ];

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
      final savedChildId = LocalStorageService.getSelectedParentChildId(
        parent.id,
      );
      if (savedChildId != null && savedChildId.isNotEmpty) {
        final idx = cached.indexWhere((s) => s.id == savedChildId);
        if (idx != -1) {
          _selectedChildIndex = idx;
        }
      }
      _isLoadingStudents = false;
      final activeStudent =
          _linkedStudents[_selectedChildIndex % _linkedStudents.length];
      _hydrateAttendanceFromCache(activeStudent.id);
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

  Future<void> _refreshParentPortal() async {
    await _loadLinkedStudents(silent: true);
  }

  Future<void> _loadLinkedStudents({bool silent = false}) async {
    final parent = AuthRepository.instance.currentUser;
    if (parent == null) {
      if (mounted) setState(() => _isLoadingStudents = false);
      return;
    }

    try {
      final repo = SupabaseParentRepository();
      final results = await Future.wait<dynamic>([
        repo.getLinkedStudentsForParent(parent.id),
        repo.getParentProfile(parent.id),
      ]);
      final students = results[0] as List<UserModel>;
      final freshParent = results[1] as UserModel?;
      if (!mounted) return;

      final savedChildId = LocalStorageService.getSelectedParentChildId(
        parent.id,
      );
      int resolvedIndex = _selectedChildIndex;
      if (students.isNotEmpty) {
        if (savedChildId != null && savedChildId.isNotEmpty) {
          final savedIdx = students.indexWhere((s) => s.id == savedChildId);
          if (savedIdx != -1) {
            resolvedIndex = savedIdx;
          }
        }
        resolvedIndex = resolvedIndex % students.length;
      } else {
        resolvedIndex = 0;
      }

      setState(() {
        if (freshParent != null) {
          _parentProfile = freshParent;
        }
        _linkedStudents = students;
        _selectedChildIndex = resolvedIndex;
        _isLoadingStudents = false;
      });
      if (freshParent != null) {
        await LocalStorageService.saveUser(freshParent);
      }
      AppDataCache.instance.set(
        'parent_linked_students_${parent.id}',
        students.map((s) => s.toJson()).toList(),
      );

      if (students.isNotEmpty) {
        await _loadChildAttendance(students[resolvedIndex].id, silent: silent);
      }
    } catch (e) {
      debugPrint('Error loading linked students: $e');
      if (mounted) {
        setState(() => _isLoadingStudents = false);
      }
    }
  }

  Future<void> _loadChildAttendance(
    String studentId, {
    bool silent = false,
  }) async {
    if (studentId.isEmpty) return;
    if (!silent) {
      _hydrateAttendanceFromCache(studentId);
    }

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
    final targetChild = _linkedStudents[safeIndex];
    final parent = AuthRepository.instance.currentUser;
    if (parent != null) {
      LocalStorageService.saveSelectedParentChildId(parent.id, targetChild.id);
    }

    if (safeIndex == _selectedChildIndex && _childAttendance.isNotEmpty) return;

    setState(() {
      _selectedChildIndex = safeIndex;
    });

    _loadChildAttendance(targetChild.id);
  }

  void _switchChildByModel(UserModel child) {
    final idx = _linkedStudents.indexWhere((c) => c.id == child.id);
    if (idx != -1) {
      _switchChild(idx);
    }
  }

  void _openReportCardScreen(UserModel? activeChild) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParentGradesScreen(
          initialStudent: activeChild,
          allChildren: _linkedStudents,
          onSelectChild: _switchChildByModel,
        ),
      ),
    );
  }

  void _openTeachersDirectoryScreen(UserModel? activeChild) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParentTeacherContactView(
          student: activeChild,
          allChildren: _linkedStudents,
          onSelectChild: _switchChildByModel,
        ),
      ),
    );
  }

  void _showChildSwitcherBottomSheet() {
    if (_linkedStudents.isEmpty) return;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeChild =
        _linkedStudents[_selectedChildIndex % _linkedStudents.length];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.family_restroom_rounded,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Linked Students',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_linkedStudents.length} Linked',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap a student below to switch the active portal view.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _linkedStudents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final child = _linkedStudents[index];
                      final isSelected = child.id == activeChild.id;
                      final relationship =
                          (child.parentGuardianRelationship ?? 'Guardian')
                              .trim();
                      final section =
                          child.departmentOrSection?.trim().isNotEmpty == true
                          ? child.departmentOrSection!.trim()
                          : 'Senior High School';
                      final lrn = child.lrn?.trim().isNotEmpty == true
                          ? 'LRN: ${child.lrn!.trim()}'
                          : null;

                      return Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary.withValues(
                                  alpha: isDark ? 0.18 : 0.08,
                                )
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: isDark ? 0.14 : 0.1,
                                  ),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          leading: CircleAvatar(
                            radius: 21,
                            backgroundColor: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primary.withValues(
                                    alpha: 0.14,
                                  ),
                            child: Text(
                              child.fullName.trim().isNotEmpty
                                  ? child.fullName.trim()[0].toUpperCase()
                                  : 'S',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  child.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  relationship,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              [section, ?lrn].join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.65,
                                ),
                              ),
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 22,
                                )
                              : Icon(
                                  Icons.chevron_right_rounded,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            _switchChild(index);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectBottomTab(int index) {
    if (index < 0 || index >= 5) return;
    setState(() => _currentIndex = index);
    LocalStorageService.saveActiveDashboardTab('parent', index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parent =
        _parentProfile ??
        AuthRepository.instance.currentUser ??
        UserModel(
          id: '',
          username: '',
          fullName: 'Parent / Guardian',
          email: '',
          role: UserRole.parent,
        );

    final linkedStudents = _getLinkedStudents(parent);
    final UserModel? linkedStudent = linkedStudents.isNotEmpty
        ? linkedStudents[_selectedChildIndex % linkedStudents.length]
        : null;

    final List<Widget> pages = linkedStudent != null
        ? [
            // 0: Home
            ParentStudentOverviewTab(
              linkedStudent: linkedStudent,
              allChildren: linkedStudents,
              attendance: _childAttendance,
              onRefresh: _refreshParentPortal,
              onSwitchChildTap: _showChildSwitcherBottomSheet,
              onSelectChild: _switchChildByModel,
              onOpenAttendance: () => _selectBottomTab(1),
              onOpenSchedule: () => _selectBottomTab(2),
              onOpenGrades: () => _openReportCardScreen(linkedStudent),
              onOpenTeachers: () => _openTeachersDirectoryScreen(linkedStudent),
            ),
            // 1: Attendance
            ParentAttendanceTab(
              attendance: _childAttendance,
              onRefresh: _refreshParentPortal,
            ),
            // 2: Schedule
            ParentScheduleView(
              linkedStudent: linkedStudent,
              embedded: true,
              onSwitchChildTap: _showChildSwitcherBottomSheet,
            ),
            // 3: Alerts
            const ParentNotificationsTab(),
            // 4: Profile
            ParentProfileTab(
              parent: parent,
              linkedStudent: linkedStudent,
              allChildren: linkedStudents,
              onSelectChild: _switchChildByModel,
              onRefresh: _refreshParentPortal,
            ),
          ]
        : [
            _buildNoChildEmptyState(theme),
            _buildNoChildEmptyState(theme),
            _buildNoChildEmptyState(theme),
            const ParentNotificationsTab(),
            ParentProfileTab(
              parent: parent,
              linkedStudent: null,
              allChildren: const [],
              onRefresh: _refreshParentPortal,
            ),
          ];

    final appBarTitle = _tabTitles[_currentIndex.clamp(0, 4)];

    return SessionActivityTracker(
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          titleSpacing: 4,
          title: Text(
            appBarTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Open Menu',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          actions: [
            IconButton(
              visualDensity: VisualDensity.compact,
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
                padding: EdgeInsets.only(right: 10, left: 4),
                child: SyncStatusBadge(),
              ),
            ),
          ],
        ),
        drawer: ParentDrawer(
          parent: parent,
          linkedStudent: linkedStudent,
          allChildren: linkedStudents,
          currentBottomTabIndex: _currentIndex,
          onSelectBottomTab: _selectBottomTab,
          onSwitchChildTap: _showChildSwitcherBottomSheet,
          onSelectChild: _switchChildByModel,
          onOpenGrades: () => _openReportCardScreen(linkedStudent),
          onOpenTeachers: () => _openTeachersDirectoryScreen(linkedStudent),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final content = Column(
              children: [
                Expanded(
                  child: _isLoadingStudents
                      ? Center(
                          child: LoadingAnimationWidget.staggeredDotsWave(
                            color: theme.colorScheme.primary,
                            size: 42,
                          ),
                        )
                      : StaggeredEntrance(
                          key: ValueKey(
                            '${_currentIndex}_${linkedStudent?.id ?? "none"}',
                          ),
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
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.onSurface.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.14 : 0.08,
                ),
              ),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _selectBottomTab,
            type: BottomNavigationBarType.fixed,
            backgroundColor: theme.colorScheme.surface,
            selectedItemColor: theme.colorScheme.primary,
            unselectedItemColor: theme.brightness == Brightness.dark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF64748B),
            selectedLabelStyle: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.fact_check_outlined),
                activeIcon: Icon(Icons.fact_check_rounded),
                label: 'Attendance',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month_outlined),
                activeIcon: Icon(Icons.calendar_month_rounded),
                label: 'Schedule',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications_outlined),
                activeIcon: Icon(Icons.notifications_rounded),
                label: 'Alerts',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoChildEmptyState(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return AppPullToRefresh(
      onRefresh: _refreshParentPortal,
      child: AppPullToRefresh.scrollableState(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
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
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.family_restroom_outlined,
                  size: 36,
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
                "Your parent account has not been linked to a student yet. Contact the school administrator or class adviser to connect your account to your child's LRN.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
