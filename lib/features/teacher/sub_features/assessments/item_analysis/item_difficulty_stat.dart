class ItemDifficultyStat {
  final int itemNumber;
  final String questionText;
  final int totalAttempts;
  final int correctCount;

  const ItemDifficultyStat({
    required this.itemNumber,
    required this.questionText,
    required this.totalAttempts,
    required this.correctCount,
  });

  /// Difficulty Index P = R / T
  double get pIndex => totalAttempts > 0 ? correctCount / totalAttempts : 0.0;

  /// Classification based on DepEd assessment standards
  String get classification {
    if (pIndex > 0.85) return 'Very Easy';
    if (pIndex > 0.75) return 'Easy';
    if (pIndex >= 0.25) return 'Moderate / Ideal';
    if (pIndex >= 0.15) return 'Difficult';
    return 'Very Difficult';
  }
}
