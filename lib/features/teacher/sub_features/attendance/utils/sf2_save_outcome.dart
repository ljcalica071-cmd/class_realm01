class Sf2SaveOutcome {
  final bool saved;
  final bool cancelled;
  final bool copiedToClipboard;
  final String? locationLabel;

  const Sf2SaveOutcome({
    required this.saved,
    this.cancelled = false,
    this.copiedToClipboard = false,
    this.locationLabel,
  });
}
