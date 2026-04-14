import 'package:hive/hive.dart';

part 'contact.g.dart';

/*
 * ContactStatus 枚舉：聯絡人的連線狀態。
 * ContactStatus enum: Connection status of a contact.
 */
@HiveType(typeId: 4)
enum ContactStatus {
  @HiveField(0)
  /* 尚未建立 P2P 連線 (Not yet connected via P2P) */
  pending,

  @HiveField(1)
  /* 已完成 PAKE 握手，連線建立中 (PAKE done, awaiting first message) */
  connecting,

  @HiveField(2)
  /* 連線已啟用，可正常收發訊息 (Active — messages flowing) */
  active,
}

/*
 * Contact 類別：表示一個已添加的 P2P 聯絡人。
 * typeId: 3 — 在 Hive 型別登錄表中的唯一識別碼。
 * 
 * Contact class: Represents an added P2P contact.
 * typeId: 3 — Unique ID in the Hive type registry.
 */
@HiveType(typeId: 3)
class Contact extends HiveObject {
  @HiveField(0)
  /* 使用者為對方設定的備注名稱 (User-defined display name for this contact) */
  String displayName;

  @HiveField(1)
  /* 對方的 X25519 Base64 公鑰 — 構成其唯一身分識別碼 (Remote X25519 public key in Base64) */
  final String publicKeyBase64;

  @HiveField(2)
  /* 最近一次連線所使用的短碼 (Short code used during last connection attempt) */
  String? lastShortCode;

  @HiveField(3)
  /* 首次添加的時間戳 (Timestamp when this contact was first added) */
  final DateTime addedAt;

  @HiveField(4)
  /* 聯絡人的連線狀態 (Current P2P connection status of this contact) */
  ContactStatus status;

  @HiveField(5)
  /* 最後一條訊息的預覽文字 (Preview of the last message for chat list display) */
  String lastMessagePreview;

  @HiveField(6)
  /* 最後訊息的時間戳 (Timestamp of the most recent message) */
  DateTime? lastMessageAt;

  @HiveField(7)
  /* 未讀訊息數量 (Unread message count) */
  int unreadCount;

  Contact({
    required this.displayName,
    required this.publicKeyBase64,
    this.lastShortCode,
    required this.addedAt,
    this.status = ContactStatus.pending,
    this.lastMessagePreview = '',
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isBarActive = false,
    this.barSessionExpiry,
  });

  /*
   * 從公鑰生成簡短的識別碼 (Generate short fingerprint from public key)
   */
  String get shortFingerprint {
    if (publicKeyBase64.length < 12) return publicKeyBase64;
    return '${publicKeyBase64.substring(0, 6)}...${publicKeyBase64.substring(publicKeyBase64.length - 6)}';
  }
}
