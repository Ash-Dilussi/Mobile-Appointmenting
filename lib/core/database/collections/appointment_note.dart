import 'package:hive/hive.dart';

part 'appointment_note.g.dart';

/// A structured, appointment-level note embedded in an [Appointment].
///
/// Notes do not belong to their own Hive box. Their UUID keeps list-item
/// identity stable while a note is edited in memory or synchronized later.
@HiveType(typeId: 12)
class AppointmentNote {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime updatedAt;

  const AppointmentNote({
    required this.id,
    required this.title,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  AppointmentNote copyWith({
    String? title,
    String? description,
    bool clearDescription = false,
    DateTime? updatedAt,
  }) {
    return AppointmentNote(
      id: id,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
