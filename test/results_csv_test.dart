import 'package:ec8a_scanner/data/models.dart';
import 'package:ec8a_scanner/features/export/results_csv.dart';
import 'package:flutter_test/flutter_test.dart';

Party _p(String id, String abbr) => Party(
    id: id, abbr: abbr, name: abbr, color: '#000000', status: 'confirmed');

void main() {
  test('builds the matrix with home party first and proper escaping', () {
    const rows = [
      PuRollupRow(
        puId: 'pu1',
        puCode: '25/06/01/001',
        puName: 'Kabusa, I',
        state: 'FCT',
        lga: 'Municipal',
        ward: 'Kabusa',
        latestSubmissionId: 's1',
        latestTeamId: 't1',
        latestAt: null,
        sheetTotalVotesCast: 291,
        accreditedVoters: 310,
        entriesCount: 2,
        duplicateFlag: true,
        crossChecked: true,
        conflictFlag: false,
      ),
    ];
    const votes = [
      LatestVoteRow(
          puId: 'pu1',
          submissionId: 's1',
          partyId: 'p2',
          abbr: 'APC',
          name: 'APC',
          votes: 87),
      LatestVoteRow(
          puId: 'pu1',
          submissionId: 's1',
          partyId: 'p1',
          abbr: 'NDC',
          name: 'NDC',
          votes: 152),
    ];
    final csv = buildResultsCsv(
      rows: rows,
      votes: votes,
      parties: [_p('p1', 'NDC'), _p('p2', 'APC')],
      homePartyAbbr: 'NDC',
    );

    final lines = csv.trim().split('\n');
    expect(lines, hasLength(2));
    expect(
      lines.first,
      'pu_code,pu_name,ward,lga,state,entries,duplicate_flag,'
      'cross_checked,conflict_flag,total_votes_cast,accredited_voters,'
      'latest_at,NDC,APC',
    );
    expect(lines.last, contains('"Kabusa, I"')); // comma escaped
    expect(lines.last, contains(',291,310,')); // sheet totals included
    expect(lines.last, contains(',2,true,true,false,')); // audit flags
    expect(lines.last, endsWith(',152,87')); // NDC first, then APC
  });

  test('PU with no vote for a party renders an empty cell', () {
    const rows = [
      PuRollupRow(
        puId: 'pu1',
        puCode: '25/06/01/002',
        puName: 'Kabusa II',
        state: 'FCT',
        lga: 'Municipal',
        ward: 'Kabusa',
        latestSubmissionId: 's9',
        latestTeamId: 't1',
        latestAt: null,
        sheetTotalVotesCast: null,
        accreditedVoters: null,
        entriesCount: 1,
        duplicateFlag: false,
        crossChecked: false,
        conflictFlag: false,
      ),
    ];
    const votes = [
      LatestVoteRow(
          puId: 'pu1',
          submissionId: 's9',
          partyId: 'p1',
          abbr: 'NDC',
          name: 'NDC',
          votes: 5),
    ];
    final csv = buildResultsCsv(
      rows: rows,
      votes: votes,
      parties: [_p('p1', 'NDC'), _p('p2', 'APC')],
      homePartyAbbr: null,
    );
    expect(csv.trim().split('\n').last, endsWith(',5,'));
  });

  test('csvEscape quotes fields with commas, quotes and newlines', () {
    expect(csvEscape('plain'), 'plain');
    expect(csvEscape('a,b'), '"a,b"');
    expect(csvEscape('say "hi"'), '"say ""hi"""');
    expect(csvEscape(null), '');
  });
}
