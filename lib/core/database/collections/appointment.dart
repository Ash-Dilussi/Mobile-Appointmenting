import 'package:hive/hive.dart';

part 'appointment.g.dart';

@HiveType(typeId: 2)
class Appointment extends HiveObject {
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
  late String status; // upcoming, confirmed, ongoing, done, cancelled

  @HiveField(6)
  String? notes;

  @HiveField(7)
  int? staffId;

  @HiveField(8)
  late DateTime createdAt;

  @HiveField(9)
  late DateTime updatedAt;

  @HiveField(10)
  late bool synced;

  Appointment();
}
