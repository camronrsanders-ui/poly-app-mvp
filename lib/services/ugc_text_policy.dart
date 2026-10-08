class UgcPolicyViolation implements Exception {
  const UgcPolicyViolation(this.userMessage);

  final String userMessage;

  @override
  String toString() => userMessage;
}

class UgcTextPolicy {
  UgcTextPolicy._();

  // Keep this filter deliberately narrow. Broad keyword/slur filters can block
  // identity, educational, survivor-support, and reclamation contexts. This
  // pre-submit layer targets only severe patterns that have a strong safety
  // signal; reporting + human moderation remain necessary for context.
  static final RegExp _directViolentThreat = RegExp(
    r"\b(?:i\s*(?:will|'ll)|i\s*(?:am|'m)\s+going\s+to)\s+(?:kill|rape|hurt)\s+(?:you|u)\b|\bkill\s+yourself\b",
    caseSensitive: false,
  );

  static final RegExp _sexualSolicitationOfMinor = RegExp(
    r'\b(?:sex|nudes?|naked|porn|explicit)\b.{0,24}\b(?:with|from|of)\b.{0,24}\b(?:minor|underage|child|kid)\b|\b(?:minor|underage|child|kid)\b.{0,24}\b(?:sex|nudes?|naked|porn|explicit)\b',
    caseSensitive: false,
  );

  static final RegExp _seekingMinor = RegExp(
    r'\b(?:looking\s+for|seeking|want\s+to\s+meet|dm\s+me\s+if)\b.{0,32}\b(?:minor|underage|child|kid)\b',
    caseSensitive: false,
  );

  static String? violationFor(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return null;

    if (_directViolentThreat.hasMatch(normalized)) {
      return 'This text appears to contain a direct threat and cannot be posted. If someone is threatening you, use Report instead.';
    }
    if (_sexualSolicitationOfMinor.hasMatch(normalized) ||
        _seekingMinor.hasMatch(normalized)) {
      return 'This text appears to involve prohibited sexual or dating content involving minors and cannot be posted.';
    }
    return null;
  }

  static void ensureAllowed(String value) {
    final violation = violationFor(value);
    if (violation != null) throw UgcPolicyViolation(violation);
  }

  static void ensureAllowedValues(Iterable<String> values) {
    for (final value in values) {
      ensureAllowed(value);
    }
  }
}
