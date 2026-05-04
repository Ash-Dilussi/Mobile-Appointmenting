import 'package:hive/hive.dart';

part 'appointment_service.g.dart';

@HiveType(typeId: 6)
class AppointmentService extends HiveObject {
  @HiveField(0)
  int? id;

  @HiveField(1)
  int? appointmentId;

  @HiveField(2)
  int? serviceId;

  @HiveField(3)
  double? priceOverride;

  @HiveField(4)
  String? notes;

  @HiveField(5)
  int? durationOverride;

  AppointmentService();
}
