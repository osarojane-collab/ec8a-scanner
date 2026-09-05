/// Pure-Dart parser: turns ML Kit text output for an EC 8A photo into
/// structured per-party votes. Heuristics (v1):
///  * The form prints each party row as: `<ABBR> <Full Name> ... <votes>`
///  * A line starting with a KNOWN abbreviation is a party row.
///  * Votes are the LAST standalone integer on the line (rightmost column).
///  * Unknown ALL-CAPS abbreviations followed by a number are kept with low
///    confidence - newly registered parties are auto-added as 'pending'.
///  * Header numbers are parsed by label regexes where legible.
/// The review screen always shows the photo next to these values, so the
/// agent confirms/corrects before submission.
library;

class ParsedRow {
  final String abbr;
  final String? fullName;
  final int? votes;
  final double confidence;
  const ParsedRow({
    required this.abbr,
    this.fullName,
    this.votes,
    required this.confidence,
  });
}

class Ec8aParseResult {
  final List<ParsedRow> rows;
  final int? registeredVoters;
  final int? accreditedVoters;
  final int? totalVotesCast;
  final int? rejectedBallots;
  const Ec8aParseResult({
    required this.rows,
    this.registeredVoters,
    this.accreditedVoters,
    this.totalVotesCast,
    this.rejectedBallots,
  });

  int? get sumOfPartyVotes {
    var sum = 0;
    var hasAny = false;
    for (final r in rows) {
      final v = r.votes;
      if (v == null) continue;
      hasAny = true;
      sum += v;
    }
    return hasAny ? sum : null;
  }

  /// True when the sheet's printed total disagrees with the extracted rows.
  bool get sumMismatch =>
      totalVotesCast != null &&
      sumOfPartyVotes != null &&
      sumOfPartyVotes != totalVotesCast;

  /// Rows whose votes could not be read (need manual entry).
  List<ParsedRow> get unresolvedRows =>
      rows.where((r) => r.votes == null).toList();
}

/// Shared list of common words that appear on INEC result sheets but are
/// NOT political party abbreviations. Used by both the OCR text parser and
/// the QR payload parser to avoid false party rows.
const Set<String> ec8aStopWords = {
  'STATE', 'FEDERAL', 'REPUBLIC', 'ELECTION', 'ELECTIONS', 'GENERAL',
  'PRESIDENTIAL', 'GOVERNORSHIP', 'POLLING', 'UNIT', 'UNITS', 'PU',
  'RESULTS', 'RESULT', 'SHEET', 'WARD', 'LGA', 'REGISTERED', 'ACCREDITED',
  'VOTERS', 'VOTER', 'TOTAL', 'VOTES', 'CAST', 'BALLOT', 'BALLOTS',
  'PAPER', 'PAPERS', 'ISSUED', 'UNUSED', 'USED', 'SPOILT', 'SPOILED',
  'REJECTED', 'REJECT', 'SIGNATURE', 'SIGNATURES', 'SIGNED', 'NAME',
  'NAMES', 'DATE', 'TIME', 'SERIAL', 'NUMBER', 'AGENT', 'AGENTS',
  'OFFICIAL', 'OFFICIALS', 'INEC', 'FORM', 'EC8A', 'EC', 'SCORE',
  'SCORES', 'PARTY', 'PARTIES', 'NO', 'AND', 'OF', 'THE', 'COLLATION',
  'CENTRE', 'TYPE',
};

int? _extractIntAfter(String upperLine, List<String> labels) {
  for (final label in labels) {
    final i = upperLine.indexOf(label);
    if (i < 0) continue;
    final m = RegExp(r'(\d{1,6})').firstMatch(upperLine.substring(i + label.length));
    if (m != null) return int.tryParse(m.group(1)!);
  }
  return null;
}

String? _fullName(String rest) {
  final cleaned = rest
      .replaceAll(RegExp(r'[^A-Za-z .\-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) return null;
  final words =
      cleaned.split(' ').where((w) => w.length > 1).take(6).join(' ');
  return words.isEmpty ? null : words;
}

Ec8aParseResult parseEc8aText(String text, Set<String> knownAbbrs) {
  final known = knownAbbrs.map((e) => e.toUpperCase()).toSet();
  final rows = <ParsedRow>[];
  int? reg, accred, total, rejected;

  for (final rawLine in text.split(RegExp(r'\r?\n'))) {
    final line = rawLine.replaceAll(RegExp(r'\u00A0'), ' ').trim();
    if (line.length < 2) continue;
    final upper = line.toUpperCase();

    total ??= _extractIntAfter(
        upper, ['TOTAL VOTES CAST', 'TOTAL VOTE CAST', 'VOTES CAST']);
    accred ??= _extractIntAfter(
        upper, ['ACCREDITED VOTERS', 'NO OF ACCREDITED', 'ACCREDITED']);
    rejected ??=
        _extractIntAfter(upper, ['REJECTED BALLOT', 'REJECTED', 'REJECT']);
    reg ??= _extractIntAfter(upper, ['REGISTERED VOTERS', 'REGISTERED']);

    final m = RegExp(r'^([A-Z]{1,5})\b').firstMatch(upper);
    if (m == null) continue;
    final abbr = m.group(1)!;
    final rest = line.substring(m.end);
    final nums = RegExp(r'\d{1,4}').allMatches(rest).toList();
    final lastNum = nums.isEmpty ? null : int.tryParse(nums.last.group(0)!);

    if (known.contains(abbr)) {
      rows.add(ParsedRow(
        abbr: abbr,
        fullName: _fullName(rest),
        votes: lastNum,
        confidence: lastNum == null ? 0.4 : 1.0,
      ));
    } else if (abbr.length >= 2 &&
        !ec8aStopWords.contains(abbr) &&
        lastNum != null) {
      // Unknown party printed on the form -> pending, needs confirmation.
      rows.add(ParsedRow(
        abbr: abbr,
        fullName: _fullName(rest),
        votes: lastNum,
        confidence: 0.5,
      ));
    }
  }

  return Ec8aParseResult(
    rows: rows,
    registeredVoters: reg,
    accreditedVoters: accred,
    totalVotesCast: total,
    rejectedBallots: rejected,
  );
}
