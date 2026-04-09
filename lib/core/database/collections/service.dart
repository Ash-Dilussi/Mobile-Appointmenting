import 'package:hive/hive.dart';

part 'service.g.dart';

@HiveType(typeId: 1)
class Service extends HiveObject {
  @HiveField(0)
  int? id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late int defaultDurationMinutes;

  @HiveField(3)
  late double cost;

  @HiveField(4)
  String? description;

  @HiveField(5)
  late DateTime createdAt;

  @HiveField(6)
  late DateTime updatedAt;

  @HiveField(7)
  late bool synced;

  Service();
}
