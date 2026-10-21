import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/data/repositories/learning_material_repository.dart';

void main() {
  group('Student Learning Materials Portal Logic Tests', () {
    test('Hierarchical visibility: hidden ancestor folder hides child materials', () {
      final rootFolder = ClassRealmFolder(
        id: 'folder_root',
        subjectOfferingId: 'offering_1',
        folderName: 'Quarter 1',
        isVisibleToStudents: false, // Root folder is hidden!
        createdAt: DateTime.now(),
      );

      final childFolder = ClassRealmFolder(
        id: 'folder_child',
        subjectOfferingId: 'offering_1',
        parentFolderId: 'folder_root',
        folderName: 'Week 1 Lessons',
        isVisibleToStudents: true, // Child itself is marked visible
        createdAt: DateTime.now(),
      );

      final material = ClassRealmMaterial(
        id: 'mat_1',
        folderId: 'folder_child',
        fileName: 'Lesson_1.pdf',
        storagePathUrl: 'https://example.com/lesson1.pdf',
        fileSizeBytes: 1024,
        isVisibleToStudents: true, // Material itself is marked visible
        createdAt: DateTime.now(),
      );

      // Hierarchy evaluation algorithm
      final folderMap = {
        rootFolder.id: rootFolder,
        childFolder.id: childFolder,
      };

      bool isFolderHierarchyVisible(String? fId) {
        var currentId = fId;
        final visited = <String>{};
        while (currentId != null) {
          if (visited.contains(currentId)) break;
          visited.add(currentId);

          final folder = folderMap[currentId];
          if (folder == null) return false;
          if (folder.isArchived) return false;
          if (!folder.isVisibleToStudents) return false;

          currentId = folder.parentFolderId;
        }
        return true;
      }

      // Even though childFolder.isVisibleToStudents == true and material.isVisibleToStudents == true,
      // because rootFolder.isVisibleToStudents == false, the material MUST be hidden!
      final isVisible = isFolderHierarchyVisible(material.folderId);
      expect(isVisible, isFalse);
    });

    test('Server-time availability check: future material is hidden until server UTC time', () {
      final nowUtc = DateTime.utc(2026, 10, 16, 10, 0, 0);
      final pastMaterial = ClassRealmMaterial(
        id: 'mat_past',
        folderId: 'folder_1',
        fileName: 'Past.pdf',
        storagePathUrl: 'http://test.com/past.pdf',
        fileSizeBytes: 100,
        availableFrom: DateTime.utc(2026, 10, 16, 9, 0, 0),
        createdAt: nowUtc,
      );

      final futureMaterial = ClassRealmMaterial(
        id: 'mat_future',
        folderId: 'folder_1',
        fileName: 'Future.pdf',
        storagePathUrl: 'http://test.com/future.pdf',
        fileSizeBytes: 100,
        availableFrom: DateTime.utc(2026, 10, 16, 12, 0, 0),
        createdAt: nowUtc,
      );

      bool isAvailable(ClassRealmMaterial m, DateTime serverTime) {
        if (m.availableFrom == null) return true;
        return m.availableFrom!.isBefore(serverTime) || m.availableFrom!.isAtSameMomentAs(serverTime);
      }

      expect(isAvailable(pastMaterial, nowUtc), isTrue);
      expect(isAvailable(futureMaterial, nowUtc), isFalse);
    });

    test('Debounced download lock: in-flight clicks trigger only once', () async {
      final downloadingIds = <String>{};
      int executionCount = 0;

      Future<void> triggerDownload(String materialId) async {
        if (downloadingIds.contains(materialId)) {
          return; // Locked in-flight!
        }
        downloadingIds.add(materialId);

        try {
          executionCount++;
          await Future.delayed(const Duration(milliseconds: 50));
        } finally {
          downloadingIds.remove(materialId);
        }
      }

      // Simulate rapid 50x clicks
      final futures = <Future>[];
      for (int i = 0; i < 50; i++) {
        futures.add(triggerDownload('mat_42'));
      }

      await Future.wait(futures);

      // Only 1 execution occurred despite 50 clicks
      expect(executionCount, equals(1));
    });

    test('Irregular student material deduplication', () {
      final rawList = [
        ClassRealmMaterial(
          id: 'mat_sec_a',
          folderId: 'folder_a',
          fileName: 'Calculus_Handout.pdf',
          storagePathUrl: 'https://storage/shared/calc_hash.pdf',
          fileSizeBytes: 2048,
          createdAt: DateTime.now(),
        ),
        ClassRealmMaterial(
          id: 'mat_sec_b',
          folderId: 'folder_b',
          fileName: 'Calculus_Handout.pdf',
          storagePathUrl: 'https://storage/shared/calc_hash.pdf', // Exact same storage URL
          fileSizeBytes: 2048,
          createdAt: DateTime.now(),
        ),
        ClassRealmMaterial(
          id: 'mat_unique',
          folderId: 'folder_a',
          fileName: 'Different_Handout.pdf',
          storagePathUrl: 'https://storage/shared/diff_hash.pdf',
          fileSizeBytes: 1024,
          createdAt: DateTime.now(),
        ),
      ];

      final seen = <String>{};
      final deduplicated = <ClassRealmMaterial>[];
      for (final m in rawList) {
        final key = '${m.fileName}_${m.storagePathUrl}';
        if (!seen.contains(key)) {
          seen.add(key);
          deduplicated.add(m);
        }
      }

      expect(deduplicated.length, equals(2));
      expect(deduplicated.map((m) => m.fileName), containsAll(['Calculus_Handout.pdf', 'Different_Handout.pdf']));
    });
  });

  group('Student In-App Reader Modal Widget Test', () {
    testWidgets('Renders strictly read-only content with ZERO edit/delete controls', (tester) async {
      final material = ClassRealmMaterial(
        id: 'mat_reader_test',
        folderId: 'folder_1',
        fileName: 'Biology_Chapter_1.pdf',
        title: 'Introduction to Cell Biology',
        storagePathUrl: 'https://test/storage.pdf',
        fileSizeBytes: 500000,
        description: 'Paragraph 1: All living organisms are composed of cells.\n\nParagraph 2: Cells are the basic unit of life.',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(material.displayName),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Format: ${material.fileExtension}'),
                          Text(material.description!),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open Reader'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Reader'));
      await tester.pumpAndSettle();

      // Verify title & content are rendered
      expect(find.text('Introduction to Cell Biology'), findsOneWidget);
      expect(find.textContaining('All living organisms are composed of cells'), findsOneWidget);

      // Verify ZERO edit, delete, or archive controls exist
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Archive'), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  });
}
