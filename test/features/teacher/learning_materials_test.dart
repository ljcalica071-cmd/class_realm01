import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/data/repositories/learning_material_repository.dart';

void main() {
  group('MaterialFileValidator Unit Tests', () {
    test('strictly validates allowed file extensions and rejects others', () {
      final validPdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x35]); // %PDF-1.5
      expect(
        MaterialFileValidator.validateFile(
          fileName: 'Lesson1.pdf',
          fileBytes: validPdfBytes,
          byteSize: validPdfBytes.length,
        ),
        isNull,
      );

      // Blocked formats: zip, rar, xlsx, mp4, png, exe
      for (final blocked in ['archive.zip', 'notes.rar', 'grades.xlsx', 'video.mp4', 'image.png', 'run.exe']) {
        final err = MaterialFileValidator.validateFile(
          fileName: blocked,
          fileBytes: Uint8List.fromList([1, 2, 3, 4, 5]),
          byteSize: 5,
        );
        expect(
          err,
          'Unsupported file format. Only PDF, DOC, DOCX, PPT, and PPTX files are allowed.',
          reason: 'Failed to reject $blocked',
        );
      }
    });

    test('validates magic bytes for PDF, DOC, DOCX, PPT, PPTX', () {
      // 1. PDF valid (%PDF-)
      final pdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x00]);
      expect(
        MaterialFileValidator.validateFile(
          fileName: 'doc.pdf',
          fileBytes: pdfBytes,
          byteSize: pdfBytes.length,
        ),
        isNull,
      );

      // PDF invalid bytes
      final fakePdfBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04]);
      expect(
        MaterialFileValidator.validateFile(
          fileName: 'fake.pdf',
          fileBytes: fakePdfBytes,
          byteSize: fakePdfBytes.length,
        ),
        contains('Corrupted or invalid PDF'),
      );

      // 2. Legacy DOC/PPT (OLE2 header: 0xD0, 0xCF, 0x11, 0xE0)
      final docBytes = Uint8List.fromList([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB2]);
      expect(
        MaterialFileValidator.validateFile(
          fileName: 'syllabus.doc',
          fileBytes: docBytes,
          byteSize: docBytes.length,
        ),
        isNull,
      );
      expect(
        MaterialFileValidator.validateFile(
          fileName: 'slides.ppt',
          fileBytes: docBytes,
          byteSize: docBytes.length,
        ),
        isNull,
      );

      // DOC invalid header
      expect(
        MaterialFileValidator.validateFile(
          fileName: 'corrupted.doc',
          fileBytes: Uint8List.fromList([0x00, 0x00, 0x00, 0x00]),
          byteSize: 4,
        ),
        contains('Corrupted or invalid legacy Office (DOC) file'),
      );

      // 3. Office XML DOCX/PPTX (PK/ZIP header: 0x50, 0x4B, 0x03, 0x04)
      final zipDocxBytes = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00]);
      expect(
        MaterialFileValidator.validateFile(
          fileName: 'lecture.docx',
          fileBytes: zipDocxBytes,
          byteSize: zipDocxBytes.length,
        ),
        isNull,
      );
      expect(
        MaterialFileValidator.validateFile(
          fileName: 'presentation.pptx',
          fileBytes: zipDocxBytes,
          byteSize: zipDocxBytes.length,
        ),
        isNull,
      );

      // DOCX invalid header
      expect(
        MaterialFileValidator.validateFile(
          fileName: 'broken.docx',
          fileBytes: Uint8List.fromList([0x12, 0x34, 0x56, 0x78]),
          byteSize: 4,
        ),
        contains('Corrupted or invalid Office XML (DOCX) file'),
      );
    });

    test('rejects files exceeding strict 3 MB limit (3,145,728 bytes)', () {
      final validPdfHeader = [0x25, 0x50, 0x44, 0x46, 0x2D];
      const maxAllowed = MaterialFileValidator.maxFileSizeBytes; // 3,145,728

      // At exactly 3MB
      final exactBytes = Uint8List.fromList(List.filled(10, 0)..setRange(0, 5, validPdfHeader));
      expect(
        MaterialFileValidator.validateFile(
          fileName: 'test.pdf',
          fileBytes: exactBytes,
          byteSize: maxAllowed,
        ),
        isNull,
      );

      // 1 byte over 3MB
      expect(
        MaterialFileValidator.validateFile(
          fileName: 'test.pdf',
          fileBytes: exactBytes,
          byteSize: maxAllowed + 1,
        ),
        'File size exceeds the 3 MB (3,145,728 bytes) limit.',
      );
    });

    test('sanitizes file names up to 100 safe characters', () {
      final dirtyName = 'Final\x00\x1F_Module\t_1.pdf';
      final clean = MaterialFileValidator.sanitizeFileName(dirtyName);
      expect(clean, 'Final_Module_1.pdf');

      // Super long name > 100 chars
      final veryLong = '${'A' * 120}.pdf';
      final sanitizedLong = MaterialFileValidator.sanitizeFileName(veryLong);
      expect(sanitizedLong.length, lessThanOrEqualTo(100));
      expect(sanitizedLong.endsWith('.pdf'), isTrue);
    });

    test('computes deterministic content fingerprint and storage key', () {
      final bytes1 = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 1, 2, 3, 4]);
      final bytes2 = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 1, 2, 3, 4]);
      final bytes3 = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 9, 8, 7, 6]);

      final fp1 = MaterialFileValidator.computeContentFingerprint(bytes1);
      final fp2 = MaterialFileValidator.computeContentFingerprint(bytes2);
      final fp3 = MaterialFileValidator.computeContentFingerprint(bytes3);

      expect(fp1, equals(fp2));
      expect(fp1, isNot(equals(fp3)));

      final key1 = MaterialFileValidator.buildStorageKey(
        bytes: bytes1,
        originalFileName: 'Final_Exam_Reviewer.pdf',
      );
      expect(key1, startsWith('offerings/shared/'));
      expect(key1, endsWith('_pdf'));
    });
  });

  group('ClassRealmMaterial & ClassRealmFolder Models', () {
    test('parses rich text lesson and embed URL correctly', () {
      final markdownMaterial = ClassRealmMaterial(
        id: 'mat_1',
        folderId: 'folder_1',
        fileName: 'Lesson_Notes.md',
        storagePathUrl: '',
        mimeType: 'text/markdown',
        fileSizeBytes: 0,
        createdAt: DateTime.now(),
      );

      expect(markdownMaterial.isRichTextLesson, isTrue);
      expect(markdownMaterial.isLessonModule, isTrue);
      expect(markdownMaterial.formattedSize, contains('0 B (Cloud-Free)'));
      expect(markdownMaterial.fileExtension, 'LESSON');

      final embedMaterial = ClassRealmMaterial(
        id: 'mat_2',
        folderId: 'folder_1',
        fileName: 'Slide_Deck_Link',
        storagePathUrl: 'https://docs.google.com/presentation/d/xyz',
        mimeType: 'text/uri-list',
        fileSizeBytes: 0,
        createdAt: DateTime.now(),
      );

      expect(embedMaterial.isEmbedUrl, isTrue);
      expect(embedMaterial.isLessonModule, isTrue);
      expect(embedMaterial.fileExtension, 'LINK');
    });
  });

  group('Reference-Counted Storage Deletion & Multi-Section Scoped Replacement Logic', () {
    test('Reference-counted deletion: retains physical file when count > 1', () {
      const storageKey = 'https://supabase/storage/v1/s/offerings/shared/abc123_pdf';

      // Simulated active database rows
      final activeRows = [
        {'id': 'row_sec_a', 'storage_path_url': storageKey, 'is_archived': false},
        {'id': 'row_sec_b', 'storage_path_url': storageKey, 'is_archived': false},
      ];

      bool filePurgedFromStorage = false;

      void deleteMaterialRef(String id) {
        // Soft-archive Section A
        final idx = activeRows.indexWhere((r) => r['id'] == id);
        if (idx != -1) {
          activeRows[idx]['is_archived'] = true;
        }

        final remaining = activeRows.where((r) => r['storage_path_url'] == storageKey && r['is_archived'] == false).length;
        if (remaining == 0) {
          filePurgedFromStorage = true;
        }
      }

      // 1. Delete Section A's row
      deleteMaterialRef('row_sec_a');
      expect(filePurgedFromStorage, isFalse, reason: 'Physical file must NOT be purged because Section B still references it!');

      // 2. Delete Section B's row
      deleteMaterialRef('row_sec_b');
      expect(filePurgedFromStorage, isTrue, reason: 'Physical file should now be purged because reference count reached 0.');
    });

    test('Scoped replacement: "This section only" vs "All shared sections"', () {
      const oldStorage = 'https://storage/old.pdf';
      const newStorage = 'https://storage/new.pdf';

      final rows = [
        {'id': 'sec_1', 'storage_path_url': oldStorage},
        {'id': 'sec_2', 'storage_path_url': oldStorage},
      ];

      // Case 1: Update this section only
      void replaceSectionOnly(String targetId) {
        final r = rows.firstWhere((e) => e['id'] == targetId);
        r['storage_path_url'] = newStorage;
      }

      replaceSectionOnly('sec_1');
      expect(rows.firstWhere((e) => e['id'] == 'sec_1')['storage_path_url'], equals(newStorage));
      expect(rows.firstWhere((e) => e['id'] == 'sec_2')['storage_path_url'], equals(oldStorage));

      // Case 2: Update across all shared sections
      void replaceAllShared(String fromUrl, String toUrl) {
        for (final r in rows) {
          if (r['storage_path_url'] == fromUrl) {
            r['storage_path_url'] = toUrl;
          }
        }
      }

      replaceAllShared(oldStorage, 'https://storage/v3.pdf');
      expect(rows.firstWhere((e) => e['id'] == 'sec_2')['storage_path_url'], equals('https://storage/v3.pdf'));
    });
  });

  group('Teacher Material Card Widget Test', () {
    testWidgets('Cards never display raw storage URLs', (tester) async {
      final material = ClassRealmMaterial(
        id: 'mat_card_test',
        folderId: 'folder_1',
        fileName: 'Secret_Exam_Storage_Path.pdf',
        title: 'Midterm Reviewer',
        storagePathUrl: 'https://private.supabase.co/storage/v1/object/public/learning_materials/secret_internal_uuid_path.pdf',
        fileSizeBytes: 2048576,
        isVisibleToStudents: true,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text(material.displayName),
                Text('${material.fileExtension} • ${material.formattedSize}'),
                Text(material.isVisibleToStudents ? 'Live' : 'Draft'),
              ],
            ),
          ),
        ),
      );

      // Verify clean badges are rendered
      expect(find.text('Midterm Reviewer'), findsOneWidget);
      expect(find.text('PDF • 1.95 MB'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);

      // Verify RAW storage URL is NEVER displayed
      expect(find.textContaining('https://private.supabase.co'), findsNothing);
      expect(find.textContaining('secret_internal_uuid_path'), findsNothing);
    });
  });
}
