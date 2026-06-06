// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'leave_request.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LeaveRequestAdapter extends TypeAdapter<LeaveRequest> {
  @override
  final int typeId = 9;

  @override
  LeaveRequest read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LeaveRequest()
      ..id = fields[0] as String?
      ..institutionId = fields[1] as String
      ..userId = fields[2] as String
      ..userEmail = fields[3] as String
      ..userName = fields[4] as String
      ..requestedAt = fields[5] as DateTime
      ..status = fields[6] as String
      ..processedAt = fields[7] as DateTime?
      ..processedBy = fields[8] as String?;
  }

  @override
  void write(BinaryWriter writer, LeaveRequest obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.institutionId)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.userEmail)
      ..writeByte(4)
      ..write(obj.userName)
      ..writeByte(5)
      ..write(obj.requestedAt)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.processedAt)
      ..writeByte(8)
      ..write(obj.processedBy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaveRequestAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
