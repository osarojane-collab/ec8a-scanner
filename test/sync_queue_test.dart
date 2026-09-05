import 'dart:io';

import 'package:ec8a_scanner/data/local/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('syncq_test');
  });
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('enqueue + load round-trips items', () async {
    final q = SyncQueue(File('${dir.path}/q.json'));
    await q.enqueue(PendingItem(clientUid: 'a', payload: {'x': 1}));
    final items = await q.load();
    expect(items.single.clientUid, 'a');
    expect(items.single.payload['x'], 1);
  });

  test('remove deletes only the matching item', () async {
    final q = SyncQueue(File('${dir.path}/q.json'));
    await q.enqueue(PendingItem(clientUid: 'a', payload: {}));
    await q.enqueue(PendingItem(clientUid: 'b', payload: {}));
    await q.remove('a');
    final items = await q.load();
    expect(items.map((e) => e.clientUid), ['b']);
  });

  test('re-enqueue with same clientUid replaces (idempotent)', () async {
    final q = SyncQueue(File('${dir.path}/q.json'));
    await q.enqueue(PendingItem(clientUid: 'a', payload: {'v': 1}));
    await q.enqueue(PendingItem(clientUid: 'a', payload: {'v': 2}));
    final items = await q.load();
    expect(items.length, 1);
    expect(items.single.payload['v'], 2);
  });

  test('missing queue file loads empty', () async {
    final q = SyncQueue(File('${dir.path}/missing.json'));
    expect(await q.load(), isEmpty);
  });

  test('photoPath round-trips', () async {
    final q = SyncQueue(File('${dir.path}/q.json'));
    await q.enqueue(
      PendingItem(clientUid: 'a', payload: {}, photoPath: 'C:/tmp/x.jpg'),
    );
    expect((await q.load()).single.photoPath, 'C:/tmp/x.jpg');
  });

  test('corrupted queue file loads empty (crash-safe)', () async {
    final f = File('${dir.path}/q.json');
    await f.writeAsString('{ not valid json !!');
    final q = SyncQueue(f);
    expect(await q.load(), isEmpty);
  });
}
