// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'failure_record_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FailureRecordModelAdapter extends TypeAdapter<FailureRecordModel> {
  @override
  final int typeId = 4;

  @override
  FailureRecordModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FailureRecordModel(
      id: fields[0] as String,
      programId: fields[1] as String,
      missedDayKey: fields[2] as String,
      reasonCode: fields[3] as String,
      reasonLabelSnapshot: fields[4] as String,
      note: fields[5] as String?,
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FailureRecordModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.programId)
      ..writeByte(2)
      ..write(obj.missedDayKey)
      ..writeByte(3)
      ..write(obj.reasonCode)
      ..writeByte(4)
      ..write(obj.reasonLabelSnapshot)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FailureRecordModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
