import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'submission.dart';

/// Submissions: photo upload, the validated RPC call, and per-PU history.
class SubmissionRepository {
  final SupabaseClient _c;
  SubmissionRepository(this._c);

  /// Uploads an EC 8A photo into the private bucket. Returns the storage
  /// object path to store on the submission.
  Future<String> uploadPhoto(String localPath, String objectName) async {
    await _c.storage.from('ec8a-photos').upload(
          objectName,
          File(localPath),
          fileOptions: const FileOptions(upsert: true),
        );
    return objectName;
  }

  /// Calls the validated, idempotent `submit_ec8a` RPC. Returns submission id.
  Future<String> submit(SubmissionPayload payload) async {
    final res = await _c.rpc('submit_ec8a', params: payload.toRpcJson());
    return res as String;
  }

  /// All entries for one polling unit (latest first) with their party votes.
  Future<List<SubmissionEntry>> entriesForPu(String puId) async {
    final rows = await _c
        .from('submissions')
        .select()
        .eq('polling_unit_id', puId)
        .order('created_at', ascending: false);
    if (rows.isEmpty) return const [];

    final ids = rows.map((r) => r['id'] as String).toList();
    final votes = await _c
        .from('submission_votes')
        .select('submission_id, votes, confidence, parties(abbr, name)')
        .inFilter('submission_id', ids);

    final bySub = <String, List<PartyVote>>{};
    for (final v in votes) {
      final p = v['parties'] as Map<String, dynamic>?;
      bySub.putIfAbsent(v['submission_id'] as String, () => []).add(
            PartyVote(
              abbr: (p?['abbr'] ?? '') as String,
              name: (p?['name'] ?? '') as String,
              votes: (v['votes'] ?? 0) as int,
              confidence: (v['confidence'] as num?)?.toDouble(),
            ),
          );
    }

    return rows
        .map((r) => SubmissionEntry.fromJson(
              r,
              bySub[r['id'] as String] ?? const [],
            ))
        .toList();
  }

  /// Signed URL for a stored EC 8A photo (bucket is private).
  Future<String> photoUrl(String objectPath) =>
      _c.storage.from('ec8a-photos').createSignedUrl(objectPath, 3600);
}
