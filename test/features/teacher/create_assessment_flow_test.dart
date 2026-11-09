import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/core/services/gemini_service.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/create_assessment_flow.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/services/lecture_document_extractor.dart';

class _FakeGeminiService implements GeminiService {
  int? lastMcqCount;
  int? lastTfCount;
  int? lastIdentificationCount;
  AssessmentDifficulty? lastDifficulty;
  AssessmentFocus? lastFocus;
  String? lastDocumentFileName;

  @override
  Future<GeminiAssessmentGenerationResult> generateAssessmentQuestions({
    required String subject,
    required String assessmentTitle,
    required String assessmentTypeLabel,
    required String assessmentSlotLabel,
    required AssessmentDifficulty difficulty,
    required AssessmentFocus focus,
    required int mcqCount,
    required int tfCount,
    required int identificationCount,
    required String documentFileName,
    required String extractedDocumentText,
    Uint8List? rawFileBytes,
    String? fileMimeType,
  }) async {
    lastMcqCount = mcqCount;
    lastTfCount = tfCount;
    lastIdentificationCount = identificationCount;
    lastDifficulty = difficulty;
    lastFocus = focus;
    lastDocumentFileName = documentFileName;

    return GeminiAssessmentGenerationResult.success(
      usedKeySlot: 1,
      multipleChoice: List.generate(
        mcqCount,
        (i) => GeneratedMcqItem(
          statement: 'Generated MCQ Question ${i + 1} from $documentFileName?',
          choices: const [
            'Mitochondria',
            'Ribosome',
            'Golgi Apparatus',
            'Endoplasmic Reticulum',
          ],
          correctAnswer: 'A',
          sourceExcerpt: 'Slide ${i + 1}: Mitochondria is the powerhouse of the cell.',
        ),
      ),
      trueFalse: List.generate(
        tfCount,
        (i) => GeneratedTfItem(
          statement: 'Generated True/False Statement ${i + 1} from lecture.',
          correctAnswer: i.isEven ? 'True' : 'False',
          sourceExcerpt: 'Slide ${i + 1}: Cellular respiration occurs in ATP synthesis.',
        ),
      ),
      identification: List.generate(
        identificationCount,
        (i) => GeneratedIdentificationItem(
          statement:
              'It is the membrane-bound organelle responsible for generating ATP energy in eukaryotic cells (${i + 1}).',
          correctAnswer: 'Mitochondria',
          sourceExcerpt: 'Slide ${i + 1}: Mitochondria generates ATP energy.',
        ),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Uint8List _buildSamplePptxBytes() {
  final archive = Archive();
  const slide1Xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:txBody>
          <a:p><a:r><a:t>Cellular Biology: Organelles and Functions</a:t></a:r></a:p>
          <a:p><a:r><a:t>Mitochondria is the powerhouse of the eukaryotic cell that produces ATP.</a:t></a:r></a:p>
          <a:p><a:r><a:t>Ribosomes synthesize proteins from mRNA templates during translation.</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';
  final slideBytes = utf8.encode(slide1Xml);
  archive.addFile(ArchiveFile('ppt/slides/slide1.xml', slideBytes.length, slideBytes));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  group('AppValidators — AI Lecture File & Question Builder Rules', () {
    test('validates allowed lecture extensions (.pdf, .ppt, .pptx, .doc, .docx) and 15 MB limit', () {
      expect(
        AppValidators.validateAiLectureFile(
          fileName: 'lecture_notes.pdf',
          fileSizeBytes: 2 * 1024 * 1024,
        ),
        isNull,
      );
      expect(
        AppValidators.validateAiLectureFile(
          fileName: 'module_1.pptx',
          fileSizeBytes: 5 * 1024 * 1024,
        ),
        isNull,
      );
      expect(
        AppValidators.validateAiLectureFile(
          fileName: 'legacy_slides.ppt',
          fileSizeBytes: 1024 * 100,
        ),
        isNull,
      );
      expect(
        AppValidators.validateAiLectureFile(
          fileName: 'syllabus.docx',
          fileSizeBytes: 1024 * 200,
        ),
        isNull,
      );
      expect(
        AppValidators.validateAiLectureFile(
          fileName: 'handout.doc',
          fileSizeBytes: 1024 * 150,
        ),
        isNull,
      );

      // Disallowed extensions
      expect(
        AppValidators.validateAiLectureFile(
          fileName: 'handout.txt',
          fileSizeBytes: 1024 * 100,
        ),
        contains('Only PDF (.pdf), PowerPoint (.ppt, .pptx), and Word (.doc, .docx)'),
      );

      // Filename exceeds 50 characters
      expect(
        AppValidators.validateAiLectureFile(
          fileName: 'a_very_long_lecture_presentation_filename_that_exceeds_fifty_characters_limit.pptx',
          fileSizeBytes: 1024 * 100,
        ),
        contains('exceeds the 50-character limit'),
      );

      // Exceeds 15 MB
      expect(
        AppValidators.validateAiLectureFile(
          fileName: 'huge_deck.pptx',
          fileSizeBytes: 16 * 1024 * 1024,
        ),
        contains('exceeds the 15 MB limit'),
      );

      // Empty file
      expect(
        AppValidators.validateAiLectureFile(
          fileName: 'empty.pdf',
          fileSizeBytes: 0,
        ),
        contains('empty'),
      );
    });

    test('validates Identification answer key as short term/phrase (2-50 chars)', () {
      expect(AppValidators.validateIdentificationAnswerKey(''), isNotNull);
      expect(AppValidators.validateIdentificationAnswerKey('A'), contains('at least 2'));
      expect(AppValidators.validateIdentificationAnswerKey('ATP'), isNull);
      expect(AppValidators.validateIdentificationAnswerKey('Mitochondria'), isNull);
      expect(
        AppValidators.validateIdentificationAnswerKey('A' * 51),
        contains('short term or phrase (2 to 50 characters max)'),
      );
    });

    test('validates MCQ choices allowing 1-char choices and rejecting duplicates', () {
      expect(
        AppValidators.validateMcqChoices(['5', '10', '15', '20']),
        isNull,
      );
      expect(
        AppValidators.validateMcqChoices(['Mitosis', 'Meiosis', 'mitosis', 'Fission']),
        contains('Duplicate choices are not allowed'),
      );
      expect(
        AppValidators.validateMcqChoices(['Choice A', '', 'Choice C', 'Choice D']),
        contains('Choice B cannot be empty'),
      );
    });
  });

  group('LectureDocumentExtractor & GeminiService Grounded Parsing', () {
    test('extracts slide text accurately from .pptx archive in memory', () {
      final pptxBytes = _buildSamplePptxBytes();
      final doc = LectureDocumentExtractor.extract(
        fileName: 'cell_biology.pptx',
        bytes: pptxBytes,
      );

      expect(doc.extension, 'pptx');
      expect(doc.isPowerPoint, isTrue);
      expect(doc.extractedText, contains('Mitochondria is the powerhouse'));
      expect(doc.extractedText, contains('Ribosomes synthesize proteins'));
    });

    test('parses grounded AI JSON response and sanitizes duplicate choices / ID answers', () {
      const rawJson = '''
      {
        "insufficientContent": false,
        "multipleChoice": [
          {
            "statement": "Which organelle produces ATP?",
            "choices": ["Mitochondria", "mitochondria", "Ribosome", "Nucleus"],
            "correctAnswer": "A",
            "sourceExcerpt": "Slide 1"
          }
        ],
        "trueFalse": [],
        "identification": [
          {
            "statement": "It synthesizes proteins from mRNA templates.",
            "correctAnswer": "Ribosome",
            "sourceExcerpt": "Slide 1"
          }
        ]
      }
      ''';

      final parsed = GeminiService.parseAssessmentQuestionsResponse(
        rawJson,
        mcqCount: 1,
        tfCount: 0,
        identificationCount: 1,
      );

      expect(parsed.multipleChoice.length, 1);
      expect(
        AppValidators.validateMcqChoices(parsed.multipleChoice.first.choices),
        isNull,
      );
      expect(parsed.identification.length, 1);
      expect(parsed.identification.first.correctAnswer, 'Ribosome');
    });
  });

  group('CreateAssessmentFlowDialog In-Person & AI Question Generator', () {
    testWidgets('shows Set Date * when switching to In-Person mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateAssessmentFlowDialog(
              onAssessmentCreated: () {},
              initialIsExam: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Scheduled Date *'), findsOneWidget);
      expect(find.text('Question Distributions (3 Types)'), findsOneWidget);
      expect(
        find.text('View Complete Anti-Cheating & Exam Taking Guidelines'),
        findsOneWidget,
      );
      expect(find.text('Continue'), findsOneWidget);

      await tester.tap(find.text('In-Person (Manual Record)'));
      await tester.pump();

      expect(find.text('Set Date *'), findsOneWidget);
      expect(find.text('Date Administered *'), findsNothing);
      expect(find.text('Question Distributions (3 Types)'), findsNothing);
      expect(
        find.text('View Complete Anti-Cheating & Exam Taking Guidelines'),
        findsNothing,
      );
      expect(find.text('Publish Examination'), findsOneWidget);
    });

    testWidgets(
      'supports Identification-only (MCQ=0, TF=0) AI generation and auto-fills Step 2 Question Builder',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeGemini = _FakeGeminiService();
        final sampleDoc = LectureDocumentExtractor.extract(
          fileName: 'cell_biology.pptx',
          bytes: _buildSamplePptxBytes(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CreateAssessmentFlowDialog(
                onAssessmentCreated: () {},
                initialIsExam: false,
                geminiService: fakeGemini,
                initialLectureDocument: sampleDoc,
              ),
            ),
          ),
        );
        await tester.pump();

        // Verify AI Question Generator section is displayed with uploaded lecture file
        expect(
          find.text('AI Question Generator (Optional)'),
          findsOneWidget,
        );
        expect(find.text('cell_biology.pptx'), findsOneWidget);

        // Select Hard difficulty and Critical Thinking focus
        await tester.ensureVisible(find.text('Hard'));
        await tester.tap(find.text('Hard'));
        await tester.pump();

        await tester.ensureVisible(find.text('Critical Thinking'));
        await tester.tap(find.text('Critical Thinking'));
        await tester.pump();

        // Set MCQ = 0, TF = 0, Identification = 2 (Flexible Question Counts)
        final idRow = find.ancestor(
          of: find.text('Identification'),
          matching: find.byType(Row),
        );
        final idTextField = find.descendant(
          of: idRow.first,
          matching: find.byType(TextField),
        );
        await tester.ensureVisible(idTextField);
        await tester.enterText(idTextField, '2');
        await tester.pump();

        expect(find.text('Total Items: 2 / 100'), findsOneWidget);

        // Tap Generate Quiz Questions with AI
        final generateBtn = find.text('Generate Quiz Questions with AI');
        await tester.ensureVisible(generateBtn);
        await tester.tap(generateBtn);
        await tester.pumpAndSettle();

        // Verify GeminiService received exact parameters
        expect(fakeGemini.lastMcqCount, 0);
        expect(fakeGemini.lastTfCount, 0);
        expect(fakeGemini.lastIdentificationCount, 2);
        expect(fakeGemini.lastDifficulty, AssessmentDifficulty.hard);
        expect(fakeGemini.lastFocus, AssessmentFocus.criticalThinking);

        // Verify transition to Step 2 Question Builder with auto-filled Identification questions
        expect(find.text('Question 1 of 2'), findsOneWidget);
        expect(find.text('IDENTIFICATION'), findsOneWidget);
        expect(
          find.textContaining('Document Grounding: Slide 1: Mitochondria generates ATP energy.'),
          findsOneWidget,
        );
        expect(find.widgetWithText(TextField, 'Mitochondria'), findsOneWidget);

        // Verify inline error if teacher enters a 1-char answer key and clicks Next Question
        await tester.enterText(find.widgetWithText(TextField, 'Mitochondria'), 'A');
        await tester.pump();
        await tester.tap(find.text('Next Question'));
        await tester.pump();

        expect(
          find.textContaining('at least 2 characters'),
          findsOneWidget,
        );
      },
    );
  });
}
