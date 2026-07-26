// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call_log_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CallLogEntryAdapter extends TypeAdapter<CallLogEntry> {
  @override
  final int typeId = 10;

  @override
  CallLogEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CallLogEntry()
      ..id = fields[0] as String
      ..phoneNumber = fields[1] as String
      ..customerId = fields[2] as int?
      ..customerName = fields[3] as String?
      ..callType = fields[4] as String
      ..startTime = fields[5] as DateTime
      ..endTime = fields[6] as DateTime?
      ..durationSeconds = fields[7] as int
      ..state = fields[8] as String;
  }

  @override
  void write(BinaryWriter writer, CallLogEntry obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.phoneNumber)
      ..writeByte(2)
      ..write(obj.customerId)
      ..writeByte(3)
      ..write(obj.customerName)
      ..writeByte(4)
      ..write(obj.callType)
      ..writeByte(5)
      ..write(obj.startTime)
      ..writeByte(6)
      ..write(obj.endTime)
      ..writeByte(7)
      ..write(obj.durationSeconds)
      ..writeByte(8)
      ..write(obj.state);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallLogEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
