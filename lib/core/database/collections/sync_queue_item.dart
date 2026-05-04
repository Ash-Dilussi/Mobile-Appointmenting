import 'package:hive/hive.dart';

part 'sync_queue_item.g.dart';

@HiveType(typeId: 4)
class SyncQueueItem extends HiveObject {
  @HiveField(0)
  int? id;

  @HiveField(1)
  late String entityType;

  @HiveField(2)
  late int recordId;

  @HiveField(3)
  late String operation; // insert, update, delete

  @HiveField(4)
  late String payload; // JSON payload

  @HiveField(5)
  late DateTime createdAt;

  @HiveField(6)
  late int retryCount;

  @HiveField(7)
  String? lastError;

  SyncQueueItem();
}
