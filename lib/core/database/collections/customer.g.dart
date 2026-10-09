// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomerAdapter extends TypeAdapter<Customer> {
  @override
  final int typeId = 0;

  @override
  Customer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Customer()
      ..id = fields[0] as int?
      ..phoneNumber = fields[1] == null ? '' : fields[1] as String
      ..name = fields[2] == null ? '' : fields[2] as String
      ..email = fields[3] == null ? '' : fields[3] as String?
      ..legacyNotes = fields[4] == null ? '' : fields[4] as String?
      ..address = fields[5] == null ? '' : fields[5] as String?
      ..createdAt = fields[6] as DateTime?
      ..updatedAt = fields[7] as DateTime?
      ..synced = fields[8] == null ? false : fields[8] as bool
      ..institutionId = fields[9] as String?
      ..dob = fields[10] as DateTime?
      ..notes =
          fields[11] == null ? [] : (fields[11] as List).cast<CustomerNote>()
      ..city = fields[12] == null ? '' : fields[12] as String?;
  }

  @override
  void write(BinaryWriter writer, Customer obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.phoneNumber)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.email)
      ..writeByte(4)
      ..write(obj.legacyNotes)
      ..writeByte(5)
      ..write(obj.address)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.synced)
      ..writeByte(9)
      ..write(obj.institutionId)
      ..writeByte(10)
      ..write(obj.dob)
      ..writeByte(11)
      ..write(obj.notes)
      ..writeByte(12)
      ..write(obj.city);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
