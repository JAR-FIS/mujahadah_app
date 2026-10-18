// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'program_v2_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProgramV2ModelAdapter extends TypeAdapter<ProgramV2Model> {
  @override
  final int typeId = 6;

  @override
  ProgramV2Model read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProgramV2Model(
      id: fields[0] as String,
      ibadahId: fields[1] as String,
      ibadahNameSnapshot: fields[2] as String,
      targetDays: fields[3] as int,
      startDayKey: fields[4] as String,
      status: fields[5] as String,
      reminderTime: fields[6] as String?,
      restartedFromProgramId: fields[7] as String?,
      recipientNameSnapshot: fields[8] as String?,
      createdAt: fields[9] as DateTime,
      updatedAt: fields[10] as DateTime,
      finalizedAt: fields[11] as DateTime?,
      pendingMissedDayKey: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProgramV2Model obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.ibadahId)
      ..writeByte(2)
      ..write(obj.ibadahNameSnapshot)
      ..writeByte(3)
      ..write(obj.targetDays)
      ..writeByte(4)
      ..write(obj.startDayKey)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.reminderTime)
      ..writeByte(7)
      ..write(obj.restartedFromProgramId)
      ..writeByte(8)
      ..write(obj.recipientNameSnapshot)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.finalizedAt)
      ..writeByte(12)
      ..write(obj.pendingMissedDayKey);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgramV2ModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
