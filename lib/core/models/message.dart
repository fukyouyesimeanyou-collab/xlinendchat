/* 
 * 引入 Hive 資料庫庫。
 * Hive 是一個專為 Flutter 設計的極速關鍵值 (Key-Value) 資料庫。
 * 
 * Imports the Hive database library.
 * Hive is a lightweight and blazing fast key-value database built for Flutter.
 */
import 'package:hive/hive.dart';

/* 
 * 這一行告訴 Dart 編譯器，這個檔案的一部分是由程式碼生成器產生的。
 * This line tells the Dart compiler that part of this file is generated 
 * by the code generator.
 */
part 'message.g.dart';

/* 
 * @HiveType: 告知 Hive 這個類別是一個可儲存的資料模型。
 * typeId: 這是該類別的唯一識別碼，不可重複。
 * 
 * @HiveType: Informs Hive that this class is a storable data model.
 * typeId: A unique identifier for this class within the Hive box.
 */
@HiveType(typeId: 0)
class Message extends HiveObject {
  /* 
   * @HiveField: 標記每個屬性的序號，以後若要修改欄位，必須維持這個序號。
   * @HiveField: Marks the index for each property; these indices must remain 
   * consistent even if the class structure changes later.
   */

  @HiveField(0)
  /* 訊息內容 (The text content of the message) */
  final String text;

  @HiveField(1)
  /* 是否是由我發送的 (Whether the message was sent by me) */
  final bool isMe;

  @HiveField(2)
  /* 訊息時間戳 (Timestamp of the message) */
  final DateTime timestamp;

  @HiveField(3)
  /* 發送者的身分公鑰 (Sender's Identity Public Key) */
  final String senderId;

  @HiveField(4)
  /* 所屬的 SimpleX 隊列 ID (The SMP Queue ID this message belongs to) */
  final String queueId;

  /* 
   * 初始化建構子。
   * Default constructor for initialization.
   */
  Message({
    required this.text,
    required this.isMe,
    required this.timestamp,
    required this.senderId,
    required this.queueId,
  });
}
