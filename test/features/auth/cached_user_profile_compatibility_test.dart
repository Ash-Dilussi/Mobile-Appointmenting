// ignore_for_file: implementation_imports

import 'dart:io';
import 'dart:isolate';

import 'package:bookly/features/auth/data/models/cached_user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _LegacyCachedUserProfile {
  const _LegacyCachedUserProfile();
}

class _LegacyCachedUserProfileAdapter
    extends TypeAdapter<_LegacyCachedUserProfile> {
  @override
  int get typeId => 11;

  @override
  _LegacyCachedUserProfile read(BinaryReader reader) =>
      throw UnsupportedError('This adapter is write-only for the fixture.');

  @override
  void write(BinaryWriter writer, _LegacyCachedUserProfile value) {
    final fields = <int, Object?>{
      0: 'legacy-officer',
      1: 'officer@bookly.test',
      2: 'Legacy Officer',
      3: null,
      4: 'officer',
      5: 'institution-1',
      6: false,
      7: DateTime(2026, 9, 1).millisecondsSinceEpoch,
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
  test('legacy cached auth bytes default the password prompt to false',
      () async {
    final directory = await Directory.systemTemp.createTemp(
      'cached_auth_adapter_compatibility_',
    );

    await Isolate.run(() async {
      Hive.init(directory.path);
      Hive.registerAdapter<_LegacyCachedUserProfile>(
        _LegacyCachedUserProfileAdapter(),
      );
      final legacyBox =
          await Hive.openBox<_LegacyCachedUserProfile>('legacy_auth_cache');
      await legacyBox.put('current_user', const _LegacyCachedUserProfile());
      await Hive.close();
    });

    Hive.init(directory.path);
    Hive.registerAdapter(CachedUserProfileAdapter());
    final currentBox =
        await Hive.openBox<CachedUserProfile>('legacy_auth_cache');

    try {
      final restored = currentBox.get('current_user');
      expect(restored, isNotNull);
      expect(restored!.shouldPromptPasswordChange, isFalse);
      expect(restored.toAuthUser().shouldPromptPasswordChange, isFalse);
    } finally {
      await Hive.close();
      await Hive.deleteFromDisk();
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    }
  });
}
