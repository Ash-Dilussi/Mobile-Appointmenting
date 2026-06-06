import 'package:hive/hive.dart';

part 'institution.g.dart';

@HiveType(typeId: 7)
class Institution extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late String themePreset; // e.g., 'default', 'blue', 'green'

  @HiveField(3)
  String? logoAsset;

  @HiveField(4)
  late DateTime createdAt;

  @HiveField(5)
  late DateTime updatedAt;

  @HiveField(6)
  late String ownerId;

  @HiveField(7)
  String? address;

  @HiveField(8)
  String? phone;

  @HiveField(9)
  String? email;

  Institution();
}
