// ignore_for_file: implementation_imports

import 'dart:io';
import 'dart:isolate';

import 'package:bookly/core/database/collections/collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _LegacyCustomer {
  final int id;
  final String? phoneNumber;
  final String? name;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? synced;

  const _LegacyCustomer({
    required this.id,
    required this.phoneNumber,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.synced = false,
  });
}

class _LegacyCustomerAdapter extends TypeAdapter<_LegacyCustomer> {
  @override
  int get typeId => 0;

  @override
  _LegacyCustomer read(BinaryReader reader) =>
      throw UnsupportedError('This adapter is write-only for the fixture.');

  @override
  void write(BinaryWriter writer, _LegacyCustomer customer) {
    final fields = <int, Object?>{
      0: customer.id,
      if (customer.phoneNumber != null) 1: customer.phoneNumber,
      if (customer.name != null) 2: customer.name,
      if (customer.createdAt != null) 6: customer.createdAt,
      if (customer.updatedAt != null) 7: customer.updatedAt,
      if (customer.synced != null) 8: customer.synced,
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
  test('legacy customer bytes default dob, notes, and city safely', () async {
    final directory = await Directory.systemTemp.createTemp(
      'customer_adapter_compatibility_',
    );
    final timestamp = DateTime(2026, 9, 7);
    await Isolate.run(() async {
      Hive.init(directory.path);
      Hive.registerAdapter<_LegacyCustomer>(_LegacyCustomerAdapter());
      final legacyBox = await Hive.openBox<_LegacyCustomer>('legacy_customers');
      await legacyBox.put(
        7,
        _LegacyCustomer(
          id: 7,
          phoneNumber: '0712345678',
          name: 'Legacy Customer',
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
      await legacyBox.put(
        8,
        const _LegacyCustomer(
          id: 8,
          phoneNumber: null,
          name: null,
          createdAt: null,
          updatedAt: null,
          synced: null,
        ),
      );
      await Hive.close();
    });

    Hive.init(directory.path);
    Hive.registerAdapter(CustomerNoteAdapter());
    Hive.registerAdapter(CustomerAdapter());
    final currentBox = await Hive.openBox<Customer>('legacy_customers');

    try {
      final restored = currentBox.get(7);
      expect(restored, isNotNull);
      expect(restored!.dob, isNull);
      expect(restored.notes, isEmpty);
      expect(restored.city, isEmpty);

      final sparse = currentBox.get(8);
      expect(sparse, isNotNull);
      expect(sparse!.name, isEmpty);
      expect(sparse.phoneNumber, isEmpty);
      expect(sparse.email, isEmpty);
      expect(sparse.address, isEmpty);
      expect(sparse.city, isEmpty);
      expect(sparse.createdAt, isNull);
      expect(sparse.updatedAt, isNull);
      expect(sparse.synced, isFalse);
    } finally {
      await Hive.close();
      await Hive.deleteFromDisk();
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    }
  });
}
