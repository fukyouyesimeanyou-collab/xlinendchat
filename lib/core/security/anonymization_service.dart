import 'dart:io';
import 'dart:math';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AnonymizationService {
  static final AnonymizationService _instance = AnonymizationService._internal();
  factory AnonymizationService() => _instance;
  AnonymizationService._internal();

  /*
   * 洗滌檔案 (Sanitize File)
   * 1. 如果是圖片，重新編碼並去 EXIF。
   * 2. 如果是其他，進行隨機命名。
   */
  Future<File?> sanitizeFile(File originalFile) async {
    try {
      final ext = p.extension(originalFile.path).toLowerCase();
      final tempDir = await getTemporaryDirectory();
      final sanitizedDir = Directory(p.join(tempDir.path, 'sanitized'));
      
      if (!await sanitizedDir.exists()) {
        await sanitizedDir.create(recursive: true);
      }

      // 生成隨機檔名 (Generate random filename)
      final randomName = _generateRandomName() + _getBestExtension(ext);
      final targetPath = p.join(sanitizedDir.path, randomName);

      if (_isImage(ext)) {
        // 圖片：重新編碼以去除所有元數據 (Image: Re-encode to strip metadata)
        print('🛡️ [Sanitizer] 偵測到圖片，開始進行元數據清洗...');
        final result = await FlutterImageCompress.compressAndGetFile(
          originalFile.path,
          targetPath,
          quality: 85,
          format: _getCompressFormat(ext),
        );
        if (result != null) {
          print('✅ [Sanitizer] 圖片洗滌完成: $randomName');
          return File(result.path);
        }
      } else {
        // 其他檔案：僅進行檔名隨機化 (Other files: Randomize filename only)
        // 注意：這無法抹除檔案內部的元數據 (e.g. PDF Author)，但能隱藏 context。
        print('🛡️ [Sanitizer] 偵測到一般檔案，執行名義匿名化...');
        final sanitizedFile = await originalFile.copy(targetPath);
        print('✅ [Sanitizer] 檔案已匿名化命名為: $randomName');
        return sanitizedFile;
      }
    } catch (e) {
      print('❌ [Sanitizer] 洗滌失敗 Error: $e');
    }
    return null;
  }

  String _generateRandomName() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    return 'xf_' + Iterable.generate(12, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  bool _isImage(String ext) {
    return ['.jpg', '.jpeg', '.png', '.webp', '.heic'].contains(ext);
  }

  String _getBestExtension(String originalExt) {
    if (_isImage(originalExt)) return '.webp'; // 統一轉為 webp 以確保去 EXIF
    return originalExt.isEmpty ? '.bin' : originalExt;
  }

  CompressFormat _getCompressFormat(String ext) {
    return CompressFormat.webp;
  }

  /*
   * 清理暫存區 (Clear sanitized cache)
   */
  Future<void> clearCache() async {
    final tempDir = await getTemporaryDirectory();
    final sanitizedDir = Directory(p.join(tempDir.path, 'sanitized'));
    if (await sanitizedDir.exists()) {
      await sanitizedDir.delete(recursive: true);
    }
  }
}
