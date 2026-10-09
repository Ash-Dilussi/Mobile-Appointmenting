import 'package:hive/hive.dart';

import 'customer_note.dart';

part 'customer.g.dart';

@HiveType(typeId: 0)
class Customer extends HiveObject {
  @HiveField(0, defaultValue: null)
  int? id;

  @HiveField(1, defaultValue: '')
  String phoneNumber = '';

  @HiveField(2, defaultValue: '')
  String name = '';

  @HiveField(3, defaultValue: '')
  String? email;

  /// Deprecated free-text notes retained for backward-compatible Hive reads.
  /// New and edited notes are stored in [notes].
  @HiveField(4, defaultValue: '')
  String? legacyNotes;

  @HiveField(5, defaultValue: '')
  String? address;

  @HiveField(6, defaultValue: null)
  DateTime? createdAt;

  @HiveField(7, defaultValue: null)
  DateTime? updatedAt;

  @HiveField(8, defaultValue: false)
  bool synced = false;

  @HiveField(9, defaultValue: null)
  String? institutionId;

  @HiveField(10, defaultValue: null)
  DateTime? dob;

  @HiveField(11, defaultValue: <CustomerNote>[])
  List<CustomerNote> notes = <CustomerNote>[];

  /// City, kept deliberately separate from [address] (street-level detail).
  @HiveField(12, defaultValue: '')
  String? city;

  Customer();
}
