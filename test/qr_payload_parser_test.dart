import 'package:ec8a_scanner/features/scan/qr_payload_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseEc8aQr', () {
    const known = {'NDC', 'APC', 'PDP', 'LP', 'NNPP'};

    test('parses JSON payloads against the party catalog', () {
      const payload =
          '{"PU":"25/06/01/001","APC":87,"NDC":152,"TOTAL":291}';
      final r = parseEc8aQr(payload, known);
      expect(r.puCode, '25/06/01/001');
      expect(r.rows.length, 2); // TOTAL is filtered as a stopword
      final ndc = r.rows.firstWhere((x) => x.abbr == 'NDC');
      expect(ndc.votes, 152);
      expect(ndc.confidence, 1.0);
    });

    test('parses plain-text ABBR:number pairs', () {
      const payload = 'PU 25/06/01/002 APC:87 NDC=152 LP 9';
      final r = parseEc8aQr(payload, known);
      expect(r.puCode, '25/06/01/002');
      expect(r.rows.length, 3);
      expect(r.rows.map((x) => x.abbr), containsAll(['APC', 'NDC', 'LP']));
    });

    test('unknown short keys become pending rows with low confidence', () {
      const payload = '{"XYZ":21,"NDC":50}';
      final r = parseEc8aQr(payload, known);
      final xyz = r.rows.firstWhere((x) => x.abbr == 'XYZ');
      expect(xyz.votes, 21);
      expect(xyz.confidence, lessThan(1));
      expect(r.rows.firstWhere((x) => x.abbr == 'NDC').confidence, 1.0);
    });

    test('PU label itself is not mistaken for a party', () {
      const payload = 'PU 1234 APC 87';
      final r = parseEc8aQr(payload, known);
      expect(r.rows.map((x) => x.abbr), ['APC']);
    });

    test('duplicate abbreviations: last value wins', () {
      const payload = 'NDC 10 NDC 20';
      final r = parseEc8aQr(payload, known);
      expect(r.rows.single.abbr, 'NDC');
      expect(r.rows.single.votes, 20);
    });

    test('garbage payloads yield no rows', () {
      final r = parseEc8aQr('hello world 1234567890', known);
      expect(r.rows, isEmpty);
    });

    test('malformed JSON falls back to text parsing', () {
      const payload = '{"APC": broken NDC 55';
      final r = parseEc8aQr(payload, known);
      expect(r.rows.firstWhere((x) => x.abbr == 'NDC').votes, 55);
    });
  });
}
