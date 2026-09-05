/// Parses the QR code payload printed on newer INEC Form EC 8A sheets.
/// The QR encodes the results digitally, which is far more reliable than
/// handwriting OCR. The exact payload format is not publicly documented,
/// so this parser is deliberately tolerant:
///  * JSON payloads: keys are matched against the party catalog
///    (case-insensitive); unrecognized ALL-CAPS short keys are kept with
///    lower confidence as 'pending' parties.
///  * Plain-text payloads: `ABBR digits`, `ABBR=digits`, `ABBR:digits`
///    pairs are extracted.
/// Anything unrecognized stays visible in the raw text on the review
/// screen, where the agent confirms or corrects every value anyway.
library;

import 'dart:convert';

import 'ec8a_parser.dart';

class QrParseResult {
  final List<ParsedRow> rows;
  final String? puCode;
  final String raw;
  const QrParseResult({
    required this.rows,
    this.puCode,
    required this.raw,
  });
}

QrParseResult parseEc8aQr(String payload, Set<String> knownAbbrs) {
  final known = knownAbbrs.map((e) => e.toUpperCase()).toSet();
  final puMatch =
      RegExp(r'\b\d{1,2}/\d{1,2}/\d{1,2}/\d{2,4}\b').firstMatch(payload);
  final rows = <String, ParsedRow>{};

  void addRow(String abbr, int votes, double confidence, {String? name}) {
    // Same abbreviation appearing twice: last value wins.
    rows[abbr.toUpperCase()] = ParsedRow(
        abbr: abbr.toUpperCase(),
        fullName: name,
        votes: votes,
        confidence: confidence);
  }

  final trimmed = payload.trim();

  // ---- attempt 1: JSON payload -------------------------------------------
  if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
    try {
      final obj = jsonDecode(trimmed) as Map<String, dynamic>;
      obj.forEach((key, value) {
        final k = key.trim().toUpperCase();
        final v = value is int ? value : int.tryParse(value.toString().trim());
        if (v == null || v < 0) return;
        if (known.contains(k)) {
          addRow(k, v, 1.0);
        } else if (k.length >= 2 &&
            k.length <= 5 &&
            RegExp(r'^[A-Z]+$').hasMatch(k) &&
            !ec8aStopWords.contains(k)) {
          addRow(k, v, 0.6);
        }
      });
    } catch (_) {
      // not JSON after all - fall through to text parsing
    }
  }

  // ---- attempt 2: plain-text ABBR/number pairs ----------------------------
  if (rows.isEmpty) {
    final pairRe = RegExp(r'\b([A-Z]{1,5})\s*[:=\-]?\s*(\d{1,4})\b');
    for (final m in pairRe.allMatches(payload.toUpperCase())) {
      final abbr = m.group(1)!;
      final votes = int.tryParse(m.group(2)!);
      if (votes == null) continue;
      if (known.contains(abbr)) {
        addRow(abbr, votes, 1.0);
      } else if (abbr.length >= 2 && !ec8aStopWords.contains(abbr)) {
        addRow(abbr, votes, 0.6);
      }
    }
  }

  return QrParseResult(
    rows: rows.values.toList(),
    puCode: puMatch?.group(0),
    raw: payload,
  );
}
