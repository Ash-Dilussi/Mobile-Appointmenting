// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CallLogAdapter extends TypeAdapter<CallLog> {
  @override
  final int typeId = 3;

  @override
  CallLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CallLog()
      ..id = fields[0] as int?
      ..phoneNumber = fields[1] as String
      ..timestamp = fields[2] as DateTime
      ..direction = fields[3] as String
      ..durationSeconds = fields[4] as int
      ..linkedAppointmentId = fields[5] as int?
      ..customerId = fields[6] as int?
      ..isMissed = fields[7] as bool
      ..followedUp = fields[8] as bool
      ..createdAt = fields[9] as DateTime
      ..synced = fields[10] as bool;
  }

  @override
  void write(BinaryWriter writer, CallLog obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.phoneNumber)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.direction)
      ..writeByte(4)
      ..write(obj.durationSeconds)
      ..writeByte(5)
      ..write(obj.linkedAppointmentId)
      ..writeByte(6)
      ..write(obj.customerId)
      ..writeByte(7)
      ..write(obj.isMissed)
      ..writeByte(8)
      ..write(obj.followedUp)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.synced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
