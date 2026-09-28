// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ibadah_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IbadahModelAdapter extends TypeAdapter<IbadahModel> {
  @override
  final int typeId = 1;

  @override
  IbadahModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IbadahModel(
      id: fields[0] as String,
      namaIbadah: fields[1] as String,
      isDefault: fields[2] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, IbadahModel obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.namaIbadah)
      ..writeByte(2)
      ..write(obj.isDefault);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IbadahModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
