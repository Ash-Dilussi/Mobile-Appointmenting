// ignore_for_file: implementation_imports

import 'dart:io';
import 'dart:isolate';

import 'package:bookly/core/database/collections/collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _LegacyInstitution {
  const _LegacyInstitution();
}

class _LegacyInstitutionAdapter extends TypeAdapter<_LegacyInstitution> {
  @override
  int get typeId => 7;

  @override
  _LegacyInstitution read(BinaryReader reader) =>
      throw UnsupportedError('This adapter is write-only for the fixture.');

  @override
  void write(BinaryWriter writer, _LegacyInstitution value) {
    final now = DateTime(2026, 9, 1);
    final fields = <int, Object?>{
      0: 'legacy-business',
      1: 'Legacy Business',
      2: 'solarOrange',
      3: null,
      4: now,
      5: now,
      6: 'owner-1',
      7: null,
      8: null,
      9: null,
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
  test('legacy institution bytes preserve unknown staff history', () async {
    final directory = await Directory.systemTemp.createTemp(
      'institution_adapter_compatibility_',
    );
    await Isolate.run(() async {
      Hive.init(directory.path);
      Hive.registerAdapter<_LegacyInstitution>(_LegacyInstitutionAdapter());
      final box = await Hive.openBox<_LegacyInstitution>('institutions');
      await box.put('legacy-business', const _LegacyInstitution());
      await Hive.close();
    });

    Hive.init(directory.path);
    Hive.registerAdapter(InstitutionAdapter());
    final box = await Hive.openBox<Institution>('institutions');
    try {
      final restored = box.get('legacy-business');
      expect(restored, isNotNull);
      expect(restored!.name, 'Legacy Business');
      expect(restored.hasEverHadAdditionalStaff, isNull);
    } finally {
      await Hive.close();
      await Hive.deleteFromDisk();
      if (directory.existsSync()) await directory.delete(recursive: true);
    }
  });
}
