import 'package:ec8a_scanner/features/scan/ec8a_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseEc8aText', () {
    const known = {'NDC', 'APC', 'PDP', 'LP', 'NNPP'};

    test('extracts party rows, votes = last number on the line', () {
      const text = '''
INEC FORM EC8A
STATE: FEDERAL REPUBLIC OF NIGERIA
POLLING UNIT: KABUSA I
REGISTERED VOTERS 1450
ACCREDITED VOTERS 310
APC All Progressives Congress 87
NDC Nigeria Democratic Congress 152
PDP Peoples Democratic Party 43
LP Labour Party 9
TOTAL VOTES CAST 291
''';
      final r = parseEc8aText(text, known);
      final ndc = r.rows.firstWhere((x) => x.abbr == 'NDC');
      expect(ndc.votes, 152);
      expect(ndc.fullName, contains('Nigeria Democratic Congress'));
      expect(r.rows.length, 4);
      expect(r.totalVotesCast, 291);
      expect(r.accreditedVoters, 310);
      expect(r.registeredVoters, 1450);
      expect(r.sumMismatch, isFalse);
    });

    test('header lines are not party rows', () {
      const text = 'TOTAL VOTES CAST 10\nREGISTERED VOTERS 55\n';
      final r = parseEc8aText(text, known);
      expect(r.rows, isEmpty);
    });

    test('unknown party with a number becomes a pending row', () {
      const text = 'XYZ New Party Example 21\n';
      final r = parseEc8aText(text, known);
      expect(r.rows.single.abbr, 'XYZ');
      expect(r.rows.single.votes, 21);
      expect(r.rows.single.confidence, lessThan(1));
    });

    test('sum mismatch is detected', () {
      const text = 'APC Party 10\nNDC Party 20\nTOTAL VOTES CAST 35\n';
      final r = parseEc8aText(text, known);
      expect(r.sumOfPartyVotes, 30);
      expect(r.sumMismatch, isTrue);
    });

    test('rows without readable votes are unresolved', () {
      const text = 'APC All Progressives Congress\n';
      final r = parseEc8aText(text, known);
      expect(r.rows.single.votes, isNull);
      expect(r.unresolvedRows.length, 1);
    });

    test('blank and junk lines are skipped safely', () {
      final r = parseEc8aText('', known);
      expect(r.rows, isEmpty);
      expect(r.sumOfPartyVotes, isNull);
    });
  });
}
