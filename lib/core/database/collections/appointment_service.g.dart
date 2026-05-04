// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appointment_service.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppointmentServiceAdapter extends TypeAdapter<AppointmentService> {
  @override
  final int typeId = 6;

  @override
  AppointmentService read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppointmentService()
      ..id = fields[0] as int?
      ..appointmentId = fields[1] as int?
      ..serviceId = fields[2] as int?
      ..priceOverride = fields[3] as double?
      ..notes = fields[4] as String?
      ..durationOverride = fields[5] as int?;
  }

  @override
  void write(BinaryWriter writer, AppointmentService obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.appointmentId)
      ..writeByte(2)
      ..write(obj.serviceId)
      ..writeByte(3)
      ..write(obj.priceOverride)
      ..writeByte(4)
      ..write(obj.notes)
      ..writeByte(5)
      ..write(obj.durationOverride);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppointmentServiceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
