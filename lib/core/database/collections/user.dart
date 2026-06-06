import 'package:hive/hive.dart';

part 'user.g.dart';

@HiveType(typeId: 8)
class User extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  String? institutionId;

  @HiveField(2)
  late String email;

  @HiveField(3)
  late String name;

  @HiveField(4)
  late String role; // 'owner' or 'officer'

  @HiveField(5)
  late DateTime createdAt;

  @HiveField(6)
  late DateTime updatedAt;

  @HiveField(7)
  String? address;

  @HiveField(8)
  DateTime? birthdate;

  @HiveField(9)
  String? gender; // 'male', 'female', 'other'

  @HiveField(10)
  String? phone;

  @HiveField(11)
  String? status; // 'active', 'pending_leave'

  User();
}