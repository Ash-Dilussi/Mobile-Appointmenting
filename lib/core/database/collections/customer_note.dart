import 'package:hive/hive.dart';

part 'customer_note.g.dart';

/// A structured note embedded in a [Customer].
///
/// Customer notes intentionally remain a separate domain type from appointment
/// notes even though both share the same shape.
@HiveType(typeId: 13)
class CustomerNote {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime updatedAt;

  const CustomerNote({
    required this.id,
    required this.title,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  CustomerNote copyWith({
    String? title,
    String? description,
    bool clearDescription = false,
    DateTime? updatedAt,
  }) {
    return CustomerNote(
      id: id,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
