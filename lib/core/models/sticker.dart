/*
 * sticker.dart
 * 
 * 貼圖資料模型。
 * Sticker data model.
 */
class Sticker {
  final String id;
  final String fileName; // 僅儲存檔名，路徑動態生成以相容 iOS (Store filename only for iOS compatibility)
  final DateTime addedAt;

  Sticker({
    required this.id,
    required this.fileName,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory Sticker.fromMap(Map<dynamic, dynamic> map) {
    return Sticker(
      id: map['id'] as String,
      fileName: map['fileName'] as String,
      addedAt: DateTime.parse(map['addedAt'] as String),
    );
  }
}
