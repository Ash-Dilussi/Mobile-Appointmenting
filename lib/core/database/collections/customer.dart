import 'package:hive/hive.dart';

part 'customer.g.dart';

@HiveType(typeId: 0)
class Customer extends HiveObject {
  @HiveField(0)
  int? id;

  @HiveField(1)
  late String phoneNumber;

  @HiveField(2)
  late String name;

  @HiveField(3)
  String? email;

  @HiveField(4)
  String? notes;

  @HiveField(5)
  late DateTime createdAt;

  @HiveField(6)
  late DateTime updatedAt;

  @HiveField(7)
  late bool synced;

  Customer();
}
