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

  /// `false` means the business is known to have always had only its owner.
  /// `true` is permanent once any Officer has been provisioned. `null` keeps
  /// legacy businesses conservative because their earlier staff history is
  /// unknown.
  @HiveField(10, defaultValue: null)
  bool? hasEverHadAdditionalStaff;

  Institution();
}
