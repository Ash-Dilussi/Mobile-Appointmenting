import 'package:hive/hive.dart';

part 'leave_request.g.dart';

@HiveType(typeId: 9)
class LeaveRequest extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  late String institutionId;

  @HiveField(2)
  late String userId; // operator requesting to leave

  @HiveField(3)
  late String userEmail;

  @HiveField(4)
  late String userName;

  @HiveField(5)
  late DateTime requestedAt;

  @HiveField(6)
  late String status; // 'pending', 'approved', 'rejected'

  @HiveField(7)
  DateTime? processedAt;

  @HiveField(8)
  String? processedBy; // owner who processed

  LeaveRequest();
}
