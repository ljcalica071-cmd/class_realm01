import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:class_realm/core/config/env_config.dart';

class GeminiService {
  static final GeminiService instance = GeminiService._internal();
  GeminiService._internal();

  GenerativeModel? _model;

  void init() {
    final apiKey = EnvConfig.geminiApiKey;
    if (apiKey.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-1.5-pro',
        apiKey: apiKey,
      );
    }
  }

  Future<String?> generateLessonPlan({
    required String subject,
    required String topic,
    required String gradeLevel,
    required String duration,
  }) async {
    if (_model == null) {
      init();
    }
    
    if (_model == null) {
      return "Error: Gemini API Key not configured in .env file.";
    }

    final prompt = '''
You are an expert master teacher from the Department of Education (DepEd) Philippines.
Your task is to generate a highly professional and structured lesson plan following the strict iLAW Format.

Subject: $subject
Grade Level: $gradeLevel
Topic: $topic
Time Duration: $duration

Please generate the lesson plan strictly in the following structure using Markdown:

**I. Intended Learning Outcomes (Mga Layunin)**
[Provide 3 clear and measurable learning objectives based on Bloom's Taxonomy]

**II. Learning Content (Paksang Aralin)**
[Provide the topic overview, key concepts to be discussed, and materials needed]

**III. Assessment / Activities (Pagtataya)**
[Provide a short activity or formative assessment to evaluate the students' understanding of the topic]

**IV. Work / Learning Experiences (Pamamaraan)**
[Provide a step-by-step procedure: Introduction, Motivation, Discussion, Application, and Generalization]

Do not include any other introductory text, just return the lesson plan directly.
''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text;
    } catch (e) {
      return "Error generating lesson plan: \$e";
    }
  }
}
