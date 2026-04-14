import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import '../waku/waku_service.dart';
import '../../encryption/crypto_utils.dart';

/// PakeService: 基於 Waku 的去中心化聯絡人發現機制 (PAKE-like)
/// Decentralized contact discovery over Waku using short codes.
class PakeService {
  final WakuService wakuService;
  final String _topicPrefix = '/xlinendchat/v1/pake/';
  final _sha256 = Sha256();

  PakeService(this.wakuService);

  /// 根據短碼生成特定的 Waku 主題 (Derive a Waku topic from the short code)
  Future<String> _deriveTopic(String shortCode) async {
    final hash = await _sha256.hash(utf8.encode(shortCode));
    return '$_topicPrefix${base64Url.encode(hash.bytes).substring(0, 16)}';
  }

  /// 根據短碼生成臨時對稱密鑰 (Derive an ephemeral symmetric key from the short code)
  Future<SecretKey> _deriveKey(String shortCode) async {
    final hash = await _sha256.hash(utf8.encode('XLINE_PAKE_SALT_$shortCode'));
    return SecretKey(hash.bytes);
  }

  /// 啟動邀請等待 (Alice 的視角)：發布公鑰並等待對方回應
  /// Alice: Publish public key to derived topic and wait for Bob's response.
  Future<Map<String, String>?> waitForPeer(String shortCode, String myPubKey, {Duration timeout = const Duration(minutes: 5)}) async {
    final topic = await _deriveTopic(shortCode);
    final key = await _deriveKey(shortCode);
    
    // 訂閱該主題以監聽回應 (Subscribe to listen for response)
    await wakuService.relaySubscribe(topic);
    
    final payload = {
      'role': 'alice',
      'pub': myPubKey,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    final encryptedData = await CryptoUtils.encryptAead(key, utf8.encode(jsonEncode(payload)), []);
    
    // 定期廣播我的存在 (Periodically broadcast Alice's presence for the duration)
    final timer = Timer.periodic(const Duration(seconds: 10), (t) async {
      await wakuService.relayPublish(topic, encryptedData);
    });
    
    final completer = Completer<Map<String, String>?>();
    StreamSubscription? sub;

    sub = wakuService.events.listen((eventJson) async {
      try {
        final event = jsonDecode(eventJson);
        if (event['type'] == 'message' && event['data']['contentTopic'] == topic) {
          final rawPayload = base64Decode(event['data']['payload']);
          final decryptedBytes = await CryptoUtils.decryptAead(key, rawPayload, []);
          final data = jsonDecode(utf8.decode(decryptedBytes));
          
          if (data['role'] == 'bob') {
            print('✅ [PakeService] Received Bob\'s response!');
            completer.complete({
              'pub': data['pub'] as String,
              'name': data['name'] ?? 'New Contact',
            });
          }
        }
      } catch (e) {
        // Ignore decryption failures (e.g., noise or wrong code messages)
      }
    });

    try {
      final result = await completer.future.timeout(timeout);
      return result;
    } catch (_) {
      return null;
    } finally {
      timer.cancel();
      sub?.cancel();
    }
  }

  /// 回應邀請 (Bob 的視角)：進入主題，取得 Alice 公鑰並回覆自己的
  /// Bob: Join the derived topic, get Alice's public key, and send back his own.
  Future<Map<String, String>?> joinPeer(String shortCode, String myPubKey) async {
    final topic = await _deriveTopic(shortCode);
    final key = await _deriveKey(shortCode);

    await wakuService.relaySubscribe(topic);
    
    final completer = Completer<Map<String, String>?>();
    StreamSubscription? sub;

    sub = wakuService.events.listen((eventJson) async {
      try {
        final event = jsonDecode(eventJson);
        if (event['type'] == 'message' && event['data']['contentTopic'] == topic) {
          final rawPayload = base64Decode(event['data']['payload']);
          final decryptedBytes = await CryptoUtils.decryptAead(key, rawPayload, []);
          final data = jsonDecode(utf8.decode(decryptedBytes));
          
          if (data['role'] == 'alice' && !completer.isCompleted) {
            final alicePub = data['pub'] as String;
            
            // 回覆 Bob 的資訊 (Reply with Bob's info)
            final reply = {
              'role': 'bob',
              'pub': myPubKey,
              'name': 'Bob (Scanner)', // 實際應傳入真正的名稱
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            };
            final encryptedReply = await CryptoUtils.encryptAead(key, utf8.encode(jsonEncode(reply)), []);
            await wakuService.relayPublish(topic, encryptedReply);
            
            completer.complete({
              'pub': alicePub,
              'name': 'Alice (Inviter)',
            });
          }
        }
      } catch (e) {
        // ...
      }
    });

    try {
      final result = await completer.future.timeout(const Duration(seconds: 30));
      return result;
    } catch (_) {
      return null;
    } finally {
      sub?.cancel();
    }
  }
}
