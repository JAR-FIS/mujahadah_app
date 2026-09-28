// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'program_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProgramModelAdapter extends TypeAdapter<ProgramModel> {
  @override
  final int typeId = 2;

  @override
  ProgramModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProgramModel(
      id: fields[0] as String,
      namaIbadah: fields[1] as String,
      targetHari: fields[2] as int,
      hariBerjalan: fields[3] as int,
      tglMulai: fields[4] as DateTime,
      tglTerakhirCheckin: fields[5] as DateTime?,
      jamPengingat: fields[6] as String,
      status: fields[7] as String,
      alasanGagal: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProgramModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.namaIbadah)
      ..writeByte(2)
      ..write(obj.targetHari)
      ..writeByte(3)
      ..write(obj.hariBerjalan)
      ..writeByte(4)
      ..write(obj.tglMulai)
      ..writeByte(5)
      ..write(obj.tglTerakhirCheckin)
      ..writeByte(6)
      ..write(obj.jamPengingat)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.alasanGagal);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgramModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
