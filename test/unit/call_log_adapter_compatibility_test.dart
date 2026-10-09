// ignore_for_file: implementation_imports

import 'dart:io';
import 'dart:isolate';

import 'package:bookly/core/database/collections/collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _LegacyCallLog {
  const _LegacyCallLog();
}

class _LegacyCallLogAdapter extends TypeAdapter<_LegacyCallLog> {
  @override
  int get typeId => 3;

  @override
  _LegacyCallLog read(BinaryReader reader) =>
      throw UnsupportedError('This adapter is write-only for the fixture.');

  @override
  void write(BinaryWriter writer, _LegacyCallLog value) {
    final timestamp = DateTime(2026, 1, 2, 9, 30);
    final fields = <int, Object?>{
      0: 7,
      1: '0712345678',
      2: timestamp,
      3: 'outgoing',
      4: 42,
      5: null,
      6: 11,
      7: false,
      8: false,
      9: timestamp,
      10: false,
      11: 'test-inst',
      12: 'test-user',
    };
    writer.writeByte(fields.length);
    for (final entry in fields.entries) {
      writer
        ..writeByte(entry.key)
        ..write(entry.value);
    }
  }
}

void main() {
  test('legacy call-log bytes default origin safely', () async {
    final directory = await Directory.systemTemp.createTemp(
      'call_log_adapter_compatibility_',
    );

    await Isolate.run(() async {
      Hive.init(directory.path);
      Hive.registerAdapter<_LegacyCallLog>(_LegacyCallLogAdapter());
      final legacyBox = await Hive.openBox<_LegacyCallLog>('legacy_call_logs');
      await legacyBox.put(7, const _LegacyCallLog());
      await Hive.close();
    });

    Hive.init(directory.path);
    Hive.registerAdapter(CallLogAdapter());
    final currentBox = await Hive.openBox<CallLog>('legacy_call_logs');

    try {
      final restored = currentBox.get(7);
      expect(restored, isNotNull);
      expect(restored!.customerId, 11);
      expect(restored.handledByUserId, 'test-user');
      expect(restored.origin, CallLog.originLegacy);
    } finally {
      await Hive.close();
      await Hive.deleteFromDisk();
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    }
  });
}
