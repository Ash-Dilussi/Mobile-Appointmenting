import 'package:hive/hive.dart';

part 'call_log.g.dart';

@HiveType(typeId: 3)
class CallLog extends HiveObject {
  @HiveField(0)
  int? id;

  @HiveField(1)
  late String phoneNumber;

  @HiveField(2)
  late DateTime timestamp;

  @HiveField(3)
  late String direction; // incoming, outgoing, missed

  @HiveField(4)
  late int durationSeconds;

  @HiveField(5)
  int? linkedAppointmentId;

  @HiveField(6)
  int? customerId;

  @HiveField(7)
  late bool isMissed;

  @HiveField(8)
  late bool followedUp;

  @HiveField(9)
  late DateTime createdAt;

  @HiveField(10)
  late bool synced;

  CallLog();
}
