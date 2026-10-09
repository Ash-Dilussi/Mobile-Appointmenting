import 'package:hive/hive.dart';

import 'appointment_note.dart';

part 'appointment.g.dart';

@HiveType(typeId: 2)
class Appointment extends HiveObject {
  static const String statusUpcoming = 'upcoming';
  static const String statusConfirmed = 'confirmed';
  static const String statusOngoing = 'ongoing';
  static const String statusDone = 'done';
  static const String statusCancelled = 'cancelled';
  static const String statusNoShow = 'no_show';

  @HiveField(0)
  int? id;

  @HiveField(1)
  int? customerId;

  @HiveField(2)
  int? serviceId;

  @HiveField(3)
  late DateTime startTime;

  @HiveField(4)
  late DateTime endTime;

  @HiveField(5)
  late String status;

  @HiveField(6)

  /// Deprecated storage-only field for pre-structured-note records.
  ///
  /// Keep this field index intact for Hive compatibility. Product surfaces do
  /// not display or auto-convert it because no user-authored title exists.
  String? legacyNotes;

  @HiveField(7)
  int? staffId;

  @HiveField(8)
  int? stationId;

  @HiveField(9)
  late DateTime createdAt;

  @HiveField(10)
  late DateTime updatedAt;

  @HiveField(11)
  late bool synced;

  @HiveField(12)
  String? institutionId;

  @HiveField(13)
  String? handledByUserId;

  @HiveField(14)
  String? googleEventId;

  @HiveField(15, defaultValue: false)
  bool syncWithGoogle = false;

  /// Structured notes created with the current appointment-notes editor.
  ///
  /// The empty default keeps appointments written by older app versions
  /// readable without converting or exposing their legacy free-text note.
  @HiveField(16, defaultValue: <AppointmentNote>[])
  List<AppointmentNote> notes = <AppointmentNote>[];

  Appointment();
}
