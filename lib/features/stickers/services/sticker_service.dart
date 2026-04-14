import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/storage/database_service.dart';
import '../../../core/models/sticker.dart';

class StickerService {
  static final StickerService _instance = StickerService._internal();
  factory StickerService() => _instance;
  StickerService._internal();

  final ImagePicker _picker = ImagePicker();

  /*
   * 取得貼圖儲存目錄 (Get sticker storage directory)
   */
  Future<Directory> get _stickerDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final stickerPath = p.join(appDir.path, 'stickers');
    final dir = Directory(stickerPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /*
   * 取得貼圖的完整路徑 (Get absolute path for a sticker filename)
   */
  Future<String> getStickerAbsolutePath(String fileName) async {
    final dir = await _stickerDir;
    return p.join(dir.path, fileName);
  }

  /*
   * 從相簿選取照片並轉換為貼圖 (Pick photo and convert to sticker)
   */
  Future<Sticker?> pickAndAddSticker() async {
    try {
      // 1. 選取圖片 (Pick image)
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return null;

      // 2. 準備路徑 (Prepare paths)
      final dir = await _stickerDir;
      final fileName = 'sticker_${DateTime.now().millisecondsSinceEpoch}.webp';
      final targetPath = p.join(dir.path, fileName);

      // 3. 壓縮並轉換為 WebP (Compress and convert to WebP)
      // 目標：WebP 格式，品質 80% 通常能壓到 100-200KB
      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        image.path,
        targetPath,
        format: CompressFormat.webp,
        quality: 80,
      );

      if (result == null) return null;

      // 4. 儲存至 Hive (Save to Hive)
      final sticker = Sticker(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: fileName,
        addedAt: DateTime.now(),
      );

      await DatabaseService.stickersBox.put(sticker.id, sticker.toMap());
      
      print('✨ [StickerService] 貼圖建立成功: $fileName');
      return sticker;
    } catch (e) {
      print('❌ [StickerService] 建立貼圖失敗: $e');
      return null;
    }
  }

  /*
   * 取得所有貼圖列表 (Get all stickers)
   */
  List<Sticker> getAllStickers() {
    return DatabaseService.stickersBox.values
        .map((m) => Sticker.fromMap(m as Map))
        .toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  /*
   * 刪除貼圖 (Delete sticker)
   */
  Future<void> deleteSticker(String id) async {
    final data = DatabaseService.stickersBox.get(id);
    if (data != null) {
      final sticker = Sticker.fromMap(data as Map);
      final file = File(await getStickerAbsolutePath(sticker.fileName));
      if (await file.exists()) {
        await file.delete();
      }
      await DatabaseService.stickersBox.delete(id);
      print('🗑️ [StickerService] 貼圖已刪除: ${sticker.fileName}');
    }
  }
}
