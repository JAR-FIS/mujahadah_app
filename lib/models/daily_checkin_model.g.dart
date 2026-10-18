// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_checkin_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyCheckInModelAdapter extends TypeAdapter<DailyCheckInModel> {
  @override
  final int typeId = 3;

  @override
  DailyCheckInModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyCheckInModel(
      id: fields[0] as String,
      programId: fields[1] as String,
      dayKey: fields[2] as String,
      checkedAt: fields[3] as DateTime,
      createdAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DailyCheckInModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.programId)
      ..writeByte(2)
      ..write(obj.dayKey)
      ..writeByte(3)
      ..write(obj.checkedAt)
      ..writeByte(4)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyCheckInModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
