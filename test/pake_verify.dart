import 'dart:async';
import 'dart:convert';
import 'package:xlinendchat/core/network/waku/pake_service.dart';
import 'package:xlinendchat/core/network/waku/waku_service.dart';

// Manual Mock Waku
class ManualMockWaku implements WakuService {
  final _events = StreamController<String>.broadcast();
  @override
  Stream<String> get events => _events.stream;
  
  // 模擬網路廣播 (Simulate network broadcast)
  static final List<ManualMockWaku> _instances = [];
  
  ManualMockWaku() { _instances.add(this); }

  @override
  Future<void> initialize({String configJson = "{}"}) async {}
  @override
  Future<void> start() async {}
  @override
  Future<void> relaySubscribe(String contentTopic) async {}
  
  @override
  Future<void> relayPublish(String contentTopic, List<int> payload, {int ms = 0}) async {
    final eventJson = jsonEncode({
      'type': 'message',
      'data': {
        'payload': base64Encode(payload),
        'contentTopic': contentTopic,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }
    });
    // 將訊息發送給所有「廣播中」的實例 (Send to all "broadcasting" instances)
    for (var instance in _instances) {
      if (instance != this) {
        instance._events.add(eventJson);
      }
    }
  }

  @override
  bool isStarted() => true;
  @override
  Future<void> stop() async {
    _instances.remove(this);
    await _events.close();
  }
}

void main() async {
  print("--- Starting PAKE Discovery Verification ---");

  final mockWakuAlice = ManualMockWaku();
  final mockWakuBob = ManualMockWaku();
  
  final alicePake = PakeService(mockWakuAlice);
  final bobPake = PakeService(mockWakuBob);
  
  const shortCode = "1234567890";
  const alicePub = "ALICE_IDENTITY_PUBLIC_KEY";
  const bobPub = "BOB_IDENTITY_PUBLIC_KEY";

  print("Alice starting to wait for peer with code: $shortCode");
  final aliceFuture = alicePake.waitForPeer(shortCode, alicePub);

  // 稍微延遲模擬 Bob 加入 (Delay slightly to simulate Bob joining)
  await Future.delayed(Duration(seconds: 1));

  print("Bob joining invitation with code: $shortCode");
  final bobFuture = bobPake.joinPeer(shortCode, bobPub);

  final results = await Future.wait([aliceFuture, bobFuture]);
  
  final aliceResult = results[0];
  final bobResult = results[1];

  if (aliceResult != null && bobResult != null) {
    print("✅ Alice received Bob's Pub: ${aliceResult['pub']}");
    print("✅ Bob received Alice's Pub: ${bobResult['pub']}");
    
    if (aliceResult['pub'] == bobPub && bobResult['pub'] == alicePub) {
      print("🎉 VERIFICATION SUCCESS: PAKE exchange completed correctly over Waku!");
    } else {
      print("❌ VERIFICATION FAILED: Public key mismatch.");
    }
  } else {
    print("❌ VERIFICATION FAILED: One or both parties timed out.");
  }
  
  await mockWakuAlice.stop();
  await mockWakuBob.stop();
}
