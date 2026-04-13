// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ratchet_state.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RatchetStateAdapter extends TypeAdapter<RatchetState> {
  @override
  final int typeId = 2;

  @override
  RatchetState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RatchetState(
      rootKeyBytes: (fields[0] as List?)?.cast<int>(),
      localDhPrivKeyBytes: (fields[1] as List?)?.cast<int>(),
      localDhPubKeyBytes: (fields[2] as List?)?.cast<int>(),
      remoteDhPubKeyBytes: (fields[3] as List?)?.cast<int>(),
      sendingChainKeyBytes: (fields[4] as List?)?.cast<int>(),
      sendingMessageNumber: fields[5] as int,
      receivingChainKeyBytes: (fields[6] as List?)?.cast<int>(),
      receivingMessageNumber: fields[7] as int,
      skippedMessageKeys: (fields[8] as Map).map((dynamic k, dynamic v) =>
          MapEntry(k as int, (v as List).cast<int>())),
    );
  }

  @override
  void write(BinaryWriter writer, RatchetState obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.rootKeyBytes)
      ..writeByte(1)
      ..write(obj.localDhPrivKeyBytes)
      ..writeByte(2)
      ..write(obj.localDhPubKeyBytes)
      ..writeByte(3)
      ..write(obj.remoteDhPubKeyBytes)
      ..writeByte(4)
      ..write(obj.sendingChainKeyBytes)
      ..writeByte(5)
      ..write(obj.sendingMessageNumber)
      ..writeByte(6)
      ..write(obj.receivingChainKeyBytes)
      ..writeByte(7)
      ..write(obj.receivingMessageNumber)
      ..writeByte(8)
      ..write(obj.skippedMessageKeys);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RatchetStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
