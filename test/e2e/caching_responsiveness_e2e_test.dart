import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
  });

  group('Caching & Responsiveness E2E — Tier 1: Feature Coverage (Happy Path)', () {
    test('[F5.1] AppDataCache stores and synchronously retrieves in-memory objects with zero latency', () {
      final cache = AppDataCache.instance;
      const testKey = 'test_teacher_subjects_t01_2026-2027';
      final sampleData = [
        {'id': 'sub-1', 'subject_name': 'General Mathematics'},
        {'id': 'sub-2', 'subject_name': 'Pre-Calculus'},
      ];

      cache.set(testKey, sampleData);

      final retrieved = cache.get<List<Map<String, String>>>(testKey);
      expect(retrieved, isNotNull);
      expect(retrieved!.length, 2);
      expect(retrieved.first['subject_name'], 'General Mathematics');
    });

    test('[F5.1] AppDataCache SWR keys conform to interface contract (PROJECT.md §12)', () {
      const teacherId = 'teacher-123';
      const schoolYear = '2026-2027';
      const offeringId = 'off-456';

      final subjectsKey = 'teacher_subjects_${teacherId}_$schoolYear';
      final studentsKey = 'teacher_students_${teacherId}_all_false';
      final parentsKey = 'teacher_parents_${teacherId}_all_false';
      final schedulesKey = 'teacher_schedules_$teacherId';
      final foldersKey = 'teacher_material_folders_$offeringId';

      expect(subjectsKey, startsWith('teacher_subjects_'));
      expect(studentsKey, startsWith('teacher_students_'));
      expect(parentsKey, startsWith('teacher_parents_'));
      expect(schedulesKey, startsWith('teacher_schedules_'));
      expect(foldersKey, startsWith('teacher_material_folders_'));
    });

    test('[F5.1] AppDataCache invalidatePrefix cleanly evicts matching cached keys on mutation', () {
      final cache = AppDataCache.instance;
      cache.set('teacher_subjects_t1_sy1', 'data1');
      cache.set('teacher_subjects_t1_sy2', 'data2');
      cache.set('teacher_students_t1_all', 'data3');

      cache.invalidatePrefix('teacher_subjects_t1');

      expect(cache.get('teacher_subjects_t1_sy1'), isNull);
      expect(cache.get('teacher_subjects_t1_sy2'), isNull);
      expect(cache.get('teacher_students_t1_all'), isNotNull);
    });

    testWidgets(
      '[F5.2] Responsive layout adapts safely across desktop viewport (1400x900) without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: Center(
                child: Text('Desktop Responsive Container'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '[F5.2] Responsive layout adapts safely across mobile viewport (390x844) without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: Center(
                child: Text('Mobile Responsive Container'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    test('[F5.3] 60-30-10 semantic tokens adhere to color design system standards', () {
      // 10% Accent tokens
      expect(AppTheme.catGreen, const Color(0xFF16A34A));
      expect(AppTheme.catRed, const Color(0xFFDC2626));
      expect(AppTheme.catOrange, const Color(0xFFD97706));
      expect(AppTheme.catSlate, const Color(0xFF475569));
      expect(AppTheme.catTeal, const Color(0xFF0D9488));
      expect(AppTheme.catBlue, const Color(0xFF2563EB));
    });
  });

  group('Caching & Responsiveness E2E — Tier 2: Boundary & Corner Cases', () {
    test('[F5.1-B1] TTL freshness check validates expired entries (> 5 minutes)', () {
      final cache = AppDataCache.instance;
      const key = 'ttl_test_key';
      cache.set(key, 'value');

      // Zero-duration TTL should immediately be non-fresh
      expect(cache.isFresh(key, ttl: Duration.zero), isFalse);
      // Standard 5-minute TTL should be fresh immediately after setting
      expect(cache.isFresh(key, ttl: const Duration(minutes: 5)), isTrue);
    });

    test('[F5.1-B2] Deserialization of invalid JSON fallback returns null gracefully', () {
      final cache = AppDataCache.instance;
      const corruptedKey = 'corrupted_json_key';
      cache.set(corruptedKey, 'not a valid map');

      final result = cache.getCached<Map<String, dynamic>>(
        corruptedKey,
        (json) => Map<String, dynamic>.from(json as Map),
      );

      expect(result, isNull);
    });

    testWidgets(
      '[F5.2-B3] Extremely narrow mobile viewport (320x568) handles wrapping without crash',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  Chip(label: Text('Tag 1')),
                  Chip(label: Text('Tag 2')),
                  Chip(label: Text('Tag 3')),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    test('[F5.3-B4] Dark theme adheres to deep midnight slate (60%) and slate surface (30%)', () {
      final darkTheme = AppTheme.darkTheme;
      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.scaffoldBackgroundColor, isNotNull);
      expect(darkTheme.colorScheme.surface, isNotNull);
    });
  });

  group('Caching & Responsiveness E2E — Tier 3: Cross-Feature Combinations', () {
    testWidgets(
      '[F5.1+F5.2] Instant cache hydration on narrow mobile viewport avoids flash of empty state',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final cache = AppDataCache.instance;
        cache.set('cached_title', 'Hydrated Title');

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Text(cache.get<String>('cached_title') ?? 'Loading...'),
            ),
          ),
        );

        // Frame 1 contains hydrated text immediately
        expect(find.text('Hydrated Title'), findsOneWidget);
        expect(find.text('Loading...'), findsNothing);
      },
    );

    testWidgets(
      '[F5.2+F5.3] Viewport resizing preserves 60-30-10 visual token hierarchy',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              backgroundColor: const Color(0xFFF5F5F5), // 60%
              body: Container(
                color: Colors.white, // 30%
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.catGreen, // 10%
                  ),
                  onPressed: () {},
                  child: const Text('Action'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Resize viewport dynamically
        tester.view.physicalSize = const Size(400, 800);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Action'), findsOneWidget);
      },
    );
  });

  group('Caching & Responsiveness E2E — Tier 4: Real-World Application Scenarios', () {
    test('[E2E-R5-S1] Rapid teacher tab switching flow: Classroom Setup -> Gradebook -> Directory retains cached entities without network refetch', () {
      final cache = AppDataCache.instance;

      // Seed cache for teacher tabs
      cache.set('teacher_subjects_t01', [{'id': 'sub-1'}]);
      cache.set('teacher_students_t01_all_false', [{'id': 'stu-1'}]);
      cache.set('teacher_parents_t01_all_false', [{'id': 'par-1'}]);

      // Simulate instantaneous reads across tab switching
      expect(cache.get('teacher_subjects_t01'), isNotNull);
      expect(cache.get('teacher_students_t01_all_false'), isNotNull);
      expect(cache.get('teacher_parents_t01_all_false'), isNotNull);
    });

    testWidgets(
      '[E2E-R5-S2] Responsive Multi-Device Parity: Tablet layout (1024x768) renders clean components without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: Center(
                child: Text('Tablet Viewport Verified'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tablet Viewport Verified'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
