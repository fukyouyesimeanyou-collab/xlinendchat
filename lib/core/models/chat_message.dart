import 'package:hive/hive.dart';

part 'chat_message.g.dart';

/*
 * MessageStatus 枚舉：訊息的傳送狀態。
 * MessageStatus enum: The delivery status of a message.
 */
@HiveType(typeId: 5)
enum MessageStatus {
  @HiveField(0)
  /* 正在發送中 (Currently being sent) */
  sending,

  @HiveField(1)
  /* 已送達伺服器/中繼站 (Delivered to server/relay) */
  sent,

  @HiveField(2)
  /* 對方設備已收到 (Received by remote device) */
  delivered,

  @HiveField(3)
  /* 對方已讀 (Read by remote user) */
  read,
}

/*
 * ChatMessage 類別 (強型別 B 方案)：
 * 使用 Hive 產生器來自動管理序列化。
 * 
 * ChatMessage class (Option B):
 * Uses Hive generator for automated serialization.
 */
@HiveType(typeId: 1)
class ChatMessage extends HiveObject {
  @HiveField(0)
  final String text;

  @HiveField(1)
  final bool isMe;

  @HiveField(2)
  final String time;

  @HiveField(3)
  /* 訊息傳送狀態 (Message delivery status) */
  MessageStatus status;

  ChatMessage({
    required this.text,
    required this.isMe,
    required this.time,
    this.status = MessageStatus.sent,
  });
}

