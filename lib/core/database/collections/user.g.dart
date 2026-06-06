// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 8;

  @override
  User read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return User()
      ..id = fields[0] as String
      ..institutionId = fields[1] as String?
      ..email = fields[2] as String
      ..name = fields[3] as String
      ..role = fields[4] as String
      ..createdAt = fields[5] as DateTime
      ..updatedAt = fields[6] as DateTime
      ..address = fields[7] as String?
      ..birthdate = fields[8] as DateTime?
      ..gender = fields[9] as String?
      ..phone = fields[10] as String?
      ..status = fields[11] as String?;
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.institutionId)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.role)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.address)
      ..writeByte(8)
      ..write(obj.birthdate)
      ..writeByte(9)
      ..write(obj.gender)
      ..writeByte(10)
      ..write(obj.phone)
      ..writeByte(11)
      ..write(obj.status);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
