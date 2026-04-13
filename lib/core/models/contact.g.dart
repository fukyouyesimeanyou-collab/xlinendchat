// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ContactAdapter extends TypeAdapter<Contact> {
  @override
  final int typeId = 3;

  @override
  Contact read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Contact(
      displayName: fields[0] as String,
      publicKeyBase64: fields[1] as String,
      lastShortCode: fields[2] as String?,
      addedAt: fields[3] as DateTime,
      status: fields[4] as ContactStatus,
      lastMessagePreview: fields[5] as String,
      lastMessageAt: fields[6] as DateTime?,
      unreadCount: fields[7] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Contact obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.displayName)
      ..writeByte(1)
      ..write(obj.publicKeyBase64)
      ..writeByte(2)
      ..write(obj.lastShortCode)
      ..writeByte(3)
      ..write(obj.addedAt)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.lastMessagePreview)
      ..writeByte(6)
      ..write(obj.lastMessageAt)
      ..writeByte(7)
      ..write(obj.unreadCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ContactStatusAdapter extends TypeAdapter<ContactStatus> {
  @override
  final int typeId = 4;

  @override
  ContactStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ContactStatus.pending;
      case 1:
        return ContactStatus.connecting;
      case 2:
        return ContactStatus.active;
      default:
        return ContactStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, ContactStatus obj) {
    switch (obj) {
      case ContactStatus.pending:
        writer.writeByte(0);
        break;
      case ContactStatus.connecting:
        writer.writeByte(1);
        break;
      case ContactStatus.active:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
