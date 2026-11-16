import 'package:class_realm/models/academic_models.dart';

class ItemDifficultyStat {
  final int itemNumber;
  final String questionText;
  final int totalAttempts;
  final int correctCount;
  final QuestionType? questionType;

  const ItemDifficultyStat({
    required this.itemNumber,
    required this.questionText,
    required this.totalAttempts,
    required this.correctCount,
    this.questionType,
  });

  /// Difficulty Index P = R / T
  double get pIndex => totalAttempts > 0 ? correctCount / totalAttempts : 0.0;

  /// Classification based on DepEd assessment standards
  String get classification {
    if (totalAttempts == 0) return 'Pending Submissions';
    if (pIndex > 0.85) return 'Very Easy';
    if (pIndex > 0.75) return 'Easy';
    if (pIndex >= 0.25) return 'Moderate / Ideal';
    if (pIndex >= 0.15) return 'Difficult';
    return 'Very Difficult';
  }

  /// Readable category label
  String get categoryLabel {
    switch (questionType) {
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.trueFalse:
        return 'True or False';
      case QuestionType.identification:
        return 'Identification';
      case QuestionType.matching:
        return 'Matching Type';
      case null:
        return 'General Questions';
    }
  }

  /// Helper to parse string representation into QuestionType
  static QuestionType? parseQuestionType(dynamic val) {
    if (val == null) return null;
    if (val is QuestionType) return val;
    final s = val
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    if (s.contains('choice') || s == 'mc') return QuestionType.multipleChoice;
    if (s.contains('true') || s.contains('false') || s == 'tf') {
      return QuestionType.trueFalse;
    }
    if (s.contains('identif') || s == 'id') return QuestionType.identification;
    if (s.contains('match')) return QuestionType.matching;
    return null;
  }
}
