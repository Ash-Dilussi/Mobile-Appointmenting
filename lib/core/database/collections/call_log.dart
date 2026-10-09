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

  @HiveField(11)
  String? institutionId;

  @HiveField(12)
  String? handledByUserId;

  /// Identifies how this row entered Bookly without rewriting historical data.
  ///
  /// Rows written before this field existed deserialize as [originLegacy].
  @HiveField(13, defaultValue: originLegacy)
  String origin = originLegacy;

  static const String originLegacy = 'legacy';
  static const String originAppInitiated = 'app_initiated';

  CallLog();
}
