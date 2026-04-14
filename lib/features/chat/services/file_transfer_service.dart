import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../../core/network/waku/p2p_provider.dart';
import '../../../core/storage/database_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FileTransferProgress {
  final String fileName;
  final int currentChunk;
  final int totalChunks;
  final bool isComplete;
  final String? error;

  FileTransferProgress({
    required this.fileName,
    required this.currentChunk,
    required this.totalChunks,
    this.isComplete = false,
    this.error,
  });

  double get percent => totalChunks > 0 ? currentChunk / totalChunks : 0;
}

class FileTransferService extends ChangeNotifier {
  final P2PProvider p2pProvider;
  final String remotePublicKey;

  // 用於追蹤傳輸進度 (Track progress)
  final _progressController = StreamController<FileTransferProgress>.broadcast();
  Stream<FileTransferProgress> get progressStream => _progressController.stream;

  // 接收暫存區 (Receiver cache: sessionId -> List of Chunks)
  final Map<String, List<Uint8List?>> _incomingChunks = {};
  final Map<String, int> _receivedCount = {};

  FileTransferService({
    required this.p2pProvider,
    required this.remotePublicKey,
  });

  // 用於等待 ACK (Wait for ACK)
  final Map<String, Completer<int>> _ackCompleters = {};

  /*
   * 發送檔案 (Send File)
   */
  Future<void> sendFile(File file) async {
    final fileName = p.basename(file.path);
    final sessionId = 'fs_${DateTime.now().millisecondsSinceEpoch}';
    final bytes = await file.readAsBytes();
    const chunkSize = 64 * 1024; // 64KB
    final totalChunks = (bytes.length / chunkSize).ceil();

    print('🚀 [FileTransfer] 開始發送檔案: $fileName ($totalChunks 分片)');

    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize > bytes.length) ? bytes.length : start + chunkSize;
      final chunkData = bytes.sublist(start, end);
      final base64Chunk = base64Encode(chunkData);

      final payload = '[FCHUNK:$sessionId:$i:$totalChunks:$fileName:$base64Chunk]';
      
      await p2pProvider.sendMessage(remotePublicKey, payload);
      
      _progressController.add(FileTransferProgress(
        fileName: fileName,
        currentChunk: i + 1,
        totalChunks: totalChunks,
      ));

      // 流量控制與穩定性：每 5 片等待一次 ACK (Wait for ACK every 5 chunks)
      if ((i + 1) % 5 == 0 && i < totalChunks - 1) {
        print('⏳ [FileTransfer] 等待分片 $i 的 ACK...');
        _ackCompleters[sessionId] = Completer<int>();
        try {
          await _ackCompleters[sessionId]!.future.timeout(const Duration(seconds: 10));
        } catch (_) {
          print('⚠️ [FileTransfer] ACK 逾時，嘗試繼續發送...');
        }
        _ackCompleters.remove(sessionId);
      }
    }

    _progressController.add(FileTransferProgress(
      fileName: fileName,
      currentChunk: totalChunks,
      totalChunks: totalChunks,
      isComplete: true,
    ));
    print('✅ [FileTransfer] 檔案發送完成: $fileName');
  }

  /*
   * 處理傳入的分片 (Handle incoming chunks)
   */
  Future<String?> handleIncomingChunk(String payload) async {
    try {
      final parts = payload.substring(8, payload.length - 1).split(':');
      if (parts.length < 5) return null;

      final sessionId = parts[0];
      final index = int.parse(parts[1]);
      final total = int.parse(parts[2]);
      final fileName = parts[3];
      final data = base64Decode(parts[4]);

      if (!_incomingChunks.containsKey(sessionId)) {
        _incomingChunks[sessionId] = List<Uint8List?>.filled(total, null);
        _receivedCount[sessionId] = 0;
        print('📦 [FileTransfer] 接收到新檔案傳輸請求: $fileName');
      }

      if (_incomingChunks[sessionId]![index] == null) {
        _incomingChunks[sessionId]![index] = data;
        _receivedCount[sessionId] = _receivedCount[sessionId]! + 1;
      }

      final count = _receivedCount[sessionId]!;
      _progressController.add(FileTransferProgress(
        fileName: fileName,
        currentChunk: count,
        totalChunks: total,
      ));

      // 每 5 片發送一次 ACK (Send ACK every 5 chunks)
      if (count % 5 == 0 || count == total) {
        await p2pProvider.sendMessage(remotePublicKey, '[FACK:$sessionId:$index]');
      }

      if (count == total) {
        return await _assembleFile(sessionId, fileName);
      }
    } catch (e) {
      print('❌ [FileTransfer] 處理分片失敗: $e');
    }
    return null;
  }

  /*
   * 處理傳入的 ACK (Handle incoming ACK)
   */
  void handleAck(String payload) {
    try {
      final parts = payload.substring(6, payload.length - 1).split(':');
      if (parts.length < 2) return;
      final sessionId = parts[0];
      final index = int.parse(parts[1]);
      
      if (_ackCompleters.containsKey(sessionId)) {
        _ackCompleters[sessionId]!.complete(index);
      }
    } catch (e) {
      print('❌ [FileTransfer] 處理 ACK 失敗: $e');
    }
  }

  Future<String> _assembleFile(String sessionId, String fileName) async {
    final chunks = _incomingChunks[sessionId]!;
    final downloadsDir = await getApplicationDocumentsDirectory();
    final saveDir = Directory(p.join(downloadsDir.path, 'downloads'));
    if (!await saveDir.exists()) await saveDir.create(recursive: true);

    final savePath = p.join(saveDir.path, fileName);
    final file = File(savePath);
    
    final raf = await file.open(mode: FileMode.write);
    for (final chunk in chunks) {
      if (chunk != null) await raf.writeFrom(chunk);
    }
    await raf.close();

    _incomingChunks.remove(sessionId);
    _receivedCount.remove(sessionId);
    
    print('🎉 [FileTransfer] 檔案組裝完成: $savePath');
    return savePath;
  }
}
