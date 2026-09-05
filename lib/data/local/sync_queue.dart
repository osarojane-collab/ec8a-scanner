import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// A submission queued while offline.
class PendingItem {
  final String clientUid;
  final Map<String, dynamic> payload; // submit_ec8a RPC json
  final String? photoPath; // local file, uploaded before the RPC
  final DateTime createdAt;
  PendingItem({
    required this.clientUid,
    required this.payload,
    this.photoPath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'client_uid': clientUid,
        'payload': payload,
        if (photoPath != null) 'photo_path': photoPath,
        'created_at': createdAt.toIso8601String(),
      };

  factory PendingItem.fromJson(Map<String, dynamic> j) => PendingItem(
        clientUid: j['client_uid'] as String,
        payload: Map<String, dynamic>.from(j['payload'] as Map),
        photoPath: j['photo_path'] as String?,
        createdAt: j['created_at'] == null
            ? null
            : DateTime.parse(j['created_at'] as String),
      );
}

/// Crash-safe file-backed queue: writes a temp file then atomically renames
/// it over the old one. Safe offline retries are guaranteed end-to-end by
/// the `client_uid` idempotency of the submit_ec8a RPC.
class SyncQueue {
  final File file;
  SyncQueue(this.file);

  Future<List<PendingItem>> load() async {
    if (!await file.exists()) return [];
    try {
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PendingItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      // Corrupted -> start clean; server-side idempotency covers any replays.
      return [];
    }
  }

  Future<void> _save(List<PendingItem> items) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      jsonEncode(items.map((e) => e.toJson()).toList()),
      flush: true,
    );
    await tmp.rename(file.path);
  }

  Future<void> enqueue(PendingItem item) async {
    final items = await load()
      ..removeWhere((e) => e.clientUid == item.clientUid);
    items.add(item);
    await _save(items);
  }

  Future<void> remove(String clientUid) async {
    final items = await load()
      ..removeWhere((e) => e.clientUid == clientUid);
    await _save(items);
  }
}

/// Flushes the queue to Supabase when connectivity returns. Per item:
/// 1. upload photo (if the local file still exists)
/// 2. call submit_ec8a (idempotent on client_uid)
/// 3. remove from queue
/// Failing items stay queued for the next attempt.
class SyncService {
  final SupabaseClient client;
  final SyncQueue queue;
  SyncService(this.client, this.queue);

  Future<int> flush() async {
    final items = await queue.load();
    var synced = 0;
    for (final item in items) {
      try {
        final payload = Map<String, dynamic>.of(item.payload);
        if (item.photoPath != null && await File(item.photoPath!).exists()) {
          final objectPath = (payload['photo_path'] as String?) ??
              'sync/${item.clientUid}.jpg';
          await client.storage.from('ec8a-photos').upload(
                objectPath,
                File(item.photoPath!),
                fileOptions: const FileOptions(upsert: true),
              );
          payload['photo_path'] = objectPath;
        }
        await client.rpc('submit_ec8a', params: payload);
        await queue.remove(item.clientUid);
        synced++;
      } catch (_) {
        // network/validation failure - retry later
      }
    }
    return synced;
  }
}
