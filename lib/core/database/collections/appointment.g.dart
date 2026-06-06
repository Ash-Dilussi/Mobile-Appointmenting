// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appointment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppointmentAdapter extends TypeAdapter<Appointment> {
  @override
  final int typeId = 2;

  @override
  Appointment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Appointment()
      ..id = fields[0] as int?
      ..customerId = fields[1] as int?
      ..serviceId = fields[2] as int?
      ..startTime = fields[3] as DateTime
      ..endTime = fields[4] as DateTime
      ..status = fields[5] as String
      ..notes = fields[6] as String?
      ..staffId = fields[7] as int?
      ..stationId = fields[8] as int?
      ..createdAt = fields[9] as DateTime
      ..updatedAt = fields[10] as DateTime
      ..synced = fields[11] as bool
      ..institutionId = fields[12] as String?
      ..handledByUserId = fields[13] as String?
      ..googleEventId = fields[14] as String?
      ..syncWithGoogle = fields[15] as bool;
  }

  @override
  void write(BinaryWriter writer, Appointment obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.customerId)
      ..writeByte(2)
      ..write(obj.serviceId)
      ..writeByte(3)
      ..write(obj.startTime)
      ..writeByte(4)
      ..write(obj.endTime)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.staffId)
      ..writeByte(8)
      ..write(obj.stationId)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.synced)
      ..writeByte(12)
      ..write(obj.institutionId)
      ..writeByte(13)
      ..write(obj.handledByUserId)
      ..writeByte(14)
      ..write(obj.googleEventId)
      ..writeByte(15)
      ..write(obj.syncWithGoogle);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppointmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
