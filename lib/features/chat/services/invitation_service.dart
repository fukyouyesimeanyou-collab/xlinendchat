import 'dart:math';
import '../../../core/identity/identity_manager.dart';
import '../../../core/network/waku/pake_service.dart';

class InvitationService {
  final IdentityManager identityManager;
  final PakeService pakeService;
  
  InvitationService({required this.identityManager, required this.pakeService});

  /// 建立新的 P2P 邀請 (包括 xline: 連結與 10 位數短碼)
  /// Generates a new P2P invitation bundle using xline: scheme.
  Future<Map<String, String>> generateInvitationBundle() async {
    final myPub = identityManager.identityPublicKey ?? '';
    final shortCode = _createSafeShortCode();
    
    // 生成邀請連結 (Generate invite link)
    // 格式：xline:p2p/invite?pub=<MyPubKey>
    final fullLink = 'xline:p2p/invite?pub=$myPub';
    
    // 非同步啟動 PAKE 監聽，這通常會在 UI 層被呼叫以等待對應 (PAKE listener started separately in UI)
    
    return {
      'fullLink': fullLink,
      'shortCode': shortCode,
    };
  }

  /// 進入 PAKE 監聽模式，等待對方使用短碼加入
  /// Enters PAKE monitoring mode, waiting for a peer to join using the shortcode.
  Future<Map<String, String>?> startWaitingForPeer(String shortCode) async {
    final myPub = identityManager.identityPublicKey ?? '';
    return await pakeService.waitForPeer(shortCode, myPub);
  }

  /// 產生 10 位數高強度安全短碼 (Generates 10-char secure code)
  String _createSafeShortCode() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(10, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// 處理並解碼 xline: URI
  /// Processes and decodes the xline: URI.
  Future<Map<String, String>> processInvitationUri(String link) async {
    try {
      final uri = Uri.parse(link.replaceFirst('xline:', 'http:'));
      final pub = uri.queryParameters['pub'] ?? '';
      
      return {
        'key': pub,
        'type': 'direct_p2p',
      };
    } catch (e) {
      return {};
    }
  }

  /// PAKE 與對方握手：輸入短碼後並進行 P2P 交換
  /// PAKE Handshake: Joins a peer's invitation using the 10-char shortcode.
  Future<Map<String, String>?> decodeShortCodeForPake(String shortCode) async {
    final myPub = identityManager.identityPublicKey ?? '';
    final result = await pakeService.joinPeer(shortCode, myPub);
    
    if (result != null) {
      return {
        'key': result['pub']!,
        'name': result['name']!,
      };
    }
    return null;
  }
}
