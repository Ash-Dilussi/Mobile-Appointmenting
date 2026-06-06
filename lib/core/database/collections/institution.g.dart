// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'institution.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InstitutionAdapter extends TypeAdapter<Institution> {
  @override
  final int typeId = 7;

  @override
  Institution read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Institution()
      ..id = fields[0] as String
      ..name = fields[1] as String
      ..themePreset = fields[2] as String
      ..logoAsset = fields[3] as String?
      ..createdAt = fields[4] as DateTime
      ..updatedAt = fields[5] as DateTime
      ..ownerId = fields[6] as String
      ..address = fields[7] as String?
      ..phone = fields[8] as String?
      ..email = fields[9] as String?;
  }

  @override
  void write(BinaryWriter writer, Institution obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.themePreset)
      ..writeByte(3)
      ..write(obj.logoAsset)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.ownerId)
      ..writeByte(7)
      ..write(obj.address)
      ..writeByte(8)
      ..write(obj.phone)
      ..writeByte(9)
      ..write(obj.email);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstitutionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
