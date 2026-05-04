import 'package:hive/hive.dart';

part 'service_station.g.dart';

@HiveType(typeId: 5)
class ServiceStation extends HiveObject {
  @HiveField(0)
  int? id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  String? address;

  @HiveField(3)
  String? phone;

  @HiveField(4)
  String? description;

  @HiveField(5)
  late DateTime createdAt;

  @HiveField(6)
  late DateTime updatedAt;

  @HiveField(7)
  late bool synced;

  ServiceStation();
}
