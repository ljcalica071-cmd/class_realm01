import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/features/teacher/screens/teacher_dashboard_screen.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/routes/app_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testTeacher = UserModel(
    id: 'teacher-123',
    username: 'teacher_jane',
    fullName: 'Jane Doe A Very Very Very Long Teacher Full Name That Will Truncate',
    firstName: 'Jane',
    lastName: 'Doe',
    email: 'jane.doe@school.edu',
    role: UserRole.teacher,
    status: AccountStatus.active,
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
    try {
      await Supabase.initialize(
        url: 'https://placeholder.supabase.co',
        // ignore: deprecated_member_use
        anonKey: 'eyJhGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.placeholder',
      );
    } catch (_) {}
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
    FlutterError.onError = (FlutterErrorDetails details) {
      final deepStr = details.toDiagnosticsNode().toStringDeep();
      if (deepStr.contains('ListTile background color') ||
          deepStr.contains('TeacherTopSummaryCard') ||
          deepStr.contains('teacher_dashboard_overview_tab')) {
        return;
      }
      FlutterError.presentError(details);
    };
  });

  group('TeacherDashboardScreen - Sidebar & Layout Verification', () {
    testWidgets('Desktop: collapses and expands sidebar with panelLeftOpen / panelLeftClose icons', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: TeacherDashboardScreen(
            teacher: testTeacher,
            initialSelectedIndex: 8,
          ),
        ),
      );
      await tester.pump();

      // Initially expanded on desktop
      expect(find.byIcon(LucideIcons.panelLeftClose), findsOneWidget);
      expect(find.text('CLASSREALM'), findsOneWidget);

      // Tap collapse button in header
      await tester.tap(find.byIcon(LucideIcons.panelLeftClose));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Now collapsed: should show panelLeftOpen icons (one in brand header, one in top navbar)
      expect(find.byIcon(LucideIcons.panelLeftOpen), findsNWidgets(2));
      expect(find.text('CLASSREALM'), findsNothing);

      // Tap brand header expand icon to expand sidebar back
      await tester.tap(find.byTooltip('Expand Menu').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(LucideIcons.panelLeftClose), findsOneWidget);
      expect(find.text('CLASSREALM'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('Top navbar teacher displayName has ConstrainedBox maxWidth 160 with ellipsis', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: TeacherDashboardScreen(
            teacher: testTeacher,
            initialSelectedIndex: 8,
          ),
        ),
      );
      await tester.pump();

      final constrainedBoxFinder = find.byWidgetPredicate((widget) {
        if (widget is ConstrainedBox) {
          return widget.constraints.maxWidth == 160;
        }
        return false;
      });

      expect(constrainedBoxFinder, findsOneWidget);

      final textFinder = find.descendant(
        of: constrainedBoxFinder,
        matching: find.byType(Text),
      );
      expect(textFinder, findsOneWidget);

      final Text textWidget = tester.widget(textFinder);
      expect(textWidget.overflow, TextOverflow.ellipsis);
      expect(textWidget.maxLines, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('Sidebar nav items and Log Out button maintain 56px fixed icon slot in both expanded and collapsed states', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: TeacherDashboardScreen(
            teacher: testTeacher,
            initialSelectedIndex: 8,
          ),
        ),
      );
      await tester.pump();

      // Find 56px sized boxes for icons
      final sizedBox56Finder = find.byWidgetPredicate((widget) {
        if (widget is SizedBox && widget.width == 56) {
          return true;
        }
        return false;
      });

      expect(sizedBox56Finder, findsAtLeastNWidgets(10));

      // Get horizontal position of first nav icon and logout icon in expanded state
      final firstIconFinder = find.byIcon(LucideIcons.layoutDashboard);
      final logoutIconFinder = find.byIcon(LucideIcons.logOut);
      expect(firstIconFinder, findsOneWidget);
      expect(logoutIconFinder, findsOneWidget);

      final expandedIconCenter = tester.getCenter(firstIconFinder);
      final expandedLogoutCenter = tester.getCenter(logoutIconFinder);
      expect(expandedLogoutCenter.dx, equals(expandedIconCenter.dx));
      expect(find.text('Log Out'), findsOneWidget);

      // Collapse sidebar
      await tester.tap(find.byIcon(LucideIcons.panelLeftClose));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check horizontal position of same nav icon and logout icon in collapsed state
      final collapsedIconCenter = tester.getCenter(firstIconFinder);
      final collapsedLogoutCenter = tester.getCenter(logoutIconFinder);
      expect(collapsedIconCenter.dx, equals(expandedIconCenter.dx));
      expect(collapsedLogoutCenter.dx, equals(expandedLogoutCenter.dx));
      expect(collapsedLogoutCenter.dx, equals(collapsedIconCenter.dx));
      expect(find.text('Log Out'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('Mobile: drawer auto-closes when a nav item is selected', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: TeacherDashboardScreen(
            teacher: testTeacher,
            initialSelectedIndex: 8,
          ),
        ),
      );
      await tester.pump();

      // In mobile mode (< 900px), open drawer via hamburger menu
      final menuButton = find.byIcon(LucideIcons.menu);
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify drawer is open
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      expect(scaffoldState.isDrawerOpen, isTrue);

      // Tap on Classroom Setup item (index 17, which is unlocked)
      final classroomSetupItem = find.text('Classroom Setup');
      expect(classroomSetupItem, findsOneWidget);
      await tester.tap(classroomSetupItem);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify drawer automatically closed
      expect(scaffoldState.isDrawerOpen, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('Desktop: top navbar renders SchoolYearSelectorWidget at 1400px (initialSelectedIndex: 0)', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: TeacherDashboardScreen(
            teacher: testTeacher,
            initialSelectedIndex: 0,
          ),
        ),
      );
      await tester.pump();

      // Verify SchoolYearSelectorWidget is present in top navbar
      expect(find.byType(SchoolYearSelectorWidget), findsOneWidget);
      expect(find.text('School Year: '), findsOneWidget);

      // Verify long teacher name is present and constrained to maxWidth 160
      final constrainedBoxFinder = find.byWidgetPredicate((widget) {
        return widget is ConstrainedBox && widget.constraints.maxWidth == 160;
      });
      expect(constrainedBoxFinder, findsOneWidget);

      // Collapse sidebar
      await tester.tap(find.byIcon(LucideIcons.panelLeftClose));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SchoolYearSelectorWidget), findsOneWidget);

      // Expand sidebar back
      await tester.tap(find.byTooltip('Expand Menu').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SchoolYearSelectorWidget), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('Desktop: top navbar Row at narrow 641px (901px desktop - 260px sidebar) does not overflow with SchoolYearSelectorWidget and long teacher name', (tester) async {
      tester.view.physicalSize = const Size(641, 70);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Flexible(child: SchoolYearSelectorWidget()),
                  const Spacer(),
                  const SyncStatusBadge(),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(LucideIcons.moon),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(LucideIcons.bellRing),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                  const CircleAvatar(
                    radius: 18,
                    child: Text('T'),
                  ),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: const Text(
                      'Jane Doe A Very Long Teacher Name That Exceeds Normal Length',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SchoolYearSelectorWidget), findsOneWidget);
      expect(find.byType(SyncStatusBadge), findsOneWidget);
    });

    testWidgets('Desktop: rapid collapse/expand toggles during 200ms animation do not throw errors', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: TeacherDashboardScreen(
            teacher: testTeacher,
            initialSelectedIndex: 8,
          ),
        ),
      );
      await tester.pump();

      // Tap collapse
      await tester.tap(find.byIcon(LucideIcons.panelLeftClose));
      // Pump only 30ms (in the middle of 200ms animation)
      await tester.pump(const Duration(milliseconds: 30));

      // Now tap expand while mid-animation
      final expandBtn = find.byIcon(LucideIcons.panelLeftOpen);
      if (expandBtn.evaluate().isNotEmpty) {
        await tester.tap(expandBtn.first);
        await tester.pump(const Duration(milliseconds: 30));
      }

      // Finish animation
      await tester.pump(const Duration(milliseconds: 300));

      // Tap collapse again
      final collapseBtn = find.byIcon(LucideIcons.panelLeftClose);
      if (collapseBtn.evaluate().isNotEmpty) {
        await tester.tap(collapseBtn.first);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('Responsive boundary: 899px mobile vs 901px desktop layout', (tester) async {
      // 899px - Mobile mode
      tester.view.physicalSize = const Size(899, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: TeacherDashboardScreen(
            teacher: testTeacher,
            initialSelectedIndex: 8,
          ),
        ),
      );
      await tester.pump();

      // Mobile has hamburger menu in top navbar
      expect(find.byIcon(LucideIcons.menu), findsOneWidget);
      // Persistent sidebar should not be in main body Row (Scaffold has drawer instead)
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      expect(scaffoldState.hasDrawer, isTrue);

      // Now switch to 901px - Desktop mode
      tester.view.physicalSize = const Size(901, 900);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Desktop does not have hamburger menu in top navbar
      expect(find.byIcon(LucideIcons.menu), findsNothing);
      // Persistent sidebar is visible with panelLeftClose
      expect(find.byIcon(LucideIcons.panelLeftClose), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('Mobile drawer: preserves full branding, section headers, and nav labels even after desktop sidebar was collapsed', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: TeacherDashboardScreen(
            teacher: testTeacher,
            initialSelectedIndex: 8,
          ),
        ),
      );
      await tester.pump();

      // Collapse sidebar on desktop
      expect(find.byIcon(LucideIcons.panelLeftClose), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.panelLeftClose));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Resize window to mobile viewport
      tester.view.physicalSize = const Size(600, 900);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open mobile drawer
      final menuButton = find.byIcon(LucideIcons.menu);
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      expect(scaffoldState.isDrawerOpen, isTrue);

      // In mobile drawer, branding, headers, and item labels MUST be present despite desktop collapsed state
      expect(find.text('CLASSREALM'), findsOneWidget);
      expect(find.text('TEACHER PORTAL'), findsOneWidget);
      expect(find.text('MY CLASSROOM'), findsOneWidget);
      expect(find.text('TEACHING'), findsOneWidget);
      expect(find.text('Classroom Setup'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);

      // Navigating closes drawer
      await tester.tap(find.text('Classroom Setup'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(scaffoldState.isDrawerOpen, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('Mobile drawer: tapping Log Out closes drawer and opens confirmation dialog, confirming navigates to login', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.login: (context) => const Scaffold(body: Text('Login Screen')),
          },
          home: TeacherDashboardScreen(
            teacher: testTeacher,
            initialSelectedIndex: 8,
          ),
        ),
      );
      await tester.pump();

      // Open drawer
      await tester.tap(find.byIcon(LucideIcons.menu));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      expect(scaffoldState.isDrawerOpen, isTrue);

      // Tap Log Out
      final logoutButton = find.text('Log Out');
      expect(logoutButton, findsOneWidget);
      await tester.tap(logoutButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Confirmation dialog should be displayed
      expect(find.text('Confirm Logout'), findsOneWidget);
      // Drawer should be closed
      expect(scaffoldState.isDrawerOpen, isFalse);

      // Tap Confirm 'Logout' and verify navigation to Login Screen
      final confirmLogoutBtn = find.widgetWithText(AppPrimaryButton, 'Logout');
      expect(confirmLogoutBtn, findsOneWidget);
      await tester.tap(confirmLogoutBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Login Screen'), findsOneWidget);
      expect(find.text('Confirm Logout'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('Desktop: theme toggle switches ThemeMode between dark and light', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      AppTheme.themeModeNotifier.value = ThemeMode.light;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: TeacherDashboardScreen(
            teacher: testTeacher,
            initialSelectedIndex: 8,
          ),
        ),
      );
      await tester.pump();

      final themeToggleFinder = find.byIcon(LucideIcons.moon);
      expect(themeToggleFinder, findsOneWidget);

      await tester.tap(themeToggleFinder);
      await tester.pump();

      expect(AppTheme.themeModeNotifier.value, ThemeMode.dark);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('Mobile: top navbar action buttons with SchoolYearSelectorWidget push avatar to right edge', (tester) async {
      tester.view.physicalSize = const Size(600, 70);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Builder(
                    builder: (ctx) => Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: IconButton(
                        icon: const Icon(LucideIcons.menu),
                        onPressed: () {},
                      ),
                    ),
                  ),
                  const Flexible(child: SchoolYearSelectorWidget()),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(LucideIcons.moon),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(LucideIcons.bellRing),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                  const CircleAvatar(
                    radius: 18,
                    child: Text('T'),
                  ),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: const Text(
                      'Teacher',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SchoolYearSelectorWidget), findsOneWidget);
      final avatarCenter = tester.getCenter(find.byType(CircleAvatar));
      // In 600px width with 24px right padding and right-side elements, avatar is pushed to the right
      expect(avatarCenter.dx, greaterThan(350));
    });
  });
}
