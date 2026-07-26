import 'package:hive/hive.dart';

part 'call_log_entry.g.dart';

@HiveType(typeId: 10)
class CallLogEntry extends HiveObject {
  @HiveField(0)
  late String id; // UUID, generated on creation

  @HiveField(1)
  late String phoneNumber; // Raw number as received from channel

  @HiveField(2)
  int? customerId; // Hive key of matched Customer; null if unknown

  @HiveField(3)
  String? customerName; // Denormalized for fast list rendering

  @HiveField(4)
  late String callType; // 'incoming' | 'outgoing' | 'missed'

  @HiveField(5)
  late DateTime startTime;

  @HiveField(6)
  DateTime? endTime;

  @HiveField(7)
  int durationSeconds = 0; // 0 until call ends; computed from end-start

  @HiveField(8)
  late String state; // 'ringing' | 'ongoing' | 'completed' | 'missed'

  CallLogEntry();

  CallLogEntry.create({
    required this.id,
    required this.phoneNumber,
    this.customerId,
    this.customerName,
    required this.callType,
    required this.startTime,
    this.endTime,
    this.durationSeconds = 0,
    required this.state,
  });
}

/// Helper class for CallLogEntry box operations
class CallLogBox {
  static const String boxName = 'call_log_entries';
}
