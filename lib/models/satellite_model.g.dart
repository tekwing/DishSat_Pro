// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'satellite_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransponderAdapter extends TypeAdapter<Transponder> {
  @override
  final int typeId = 0;

  @override
  Transponder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Transponder(
      frequency: fields[0] as String,
      polarity: fields[1] as String,
      symbolRate: fields[2] as String,
      modulation: fields[3] as String,
      isActive: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Transponder obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.frequency)
      ..writeByte(1)
      ..write(obj.polarity)
      ..writeByte(2)
      ..write(obj.symbolRate)
      ..writeByte(3)
      ..write(obj.modulation)
      ..writeByte(4)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransponderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SatelliteAdapter extends TypeAdapter<Satellite> {
  @override
  final int typeId = 1;

  @override
  Satellite read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Satellite(
      name: fields[0] as String,
      position: fields[1] as double,
      hemisphere: fields[2] as String,
      bands: (fields[3] as List).cast<String>(),
      transponderCount: fields[4] as int,
      lnbSkew: fields[5] as double,
      transponders: (fields[6] as List).cast<Transponder>(),
    );
  }

  @override
  void write(BinaryWriter writer, Satellite obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.position)
      ..writeByte(2)
      ..write(obj.hemisphere)
      ..writeByte(3)
      ..write(obj.bands)
      ..writeByte(4)
      ..write(obj.transponderCount)
      ..writeByte(5)
      ..write(obj.lnbSkew)
      ..writeByte(6)
      ..write(obj.transponders);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SatelliteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
