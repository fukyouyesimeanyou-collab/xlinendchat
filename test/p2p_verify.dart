import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:xlinendchat/core/network/waku/p2p_provider.dart';
import 'package:xlinendchat/core/network/waku/waku_service.dart';
import 'package:xlinendchat/core/encryption/double_ratchet_service.dart';
import 'package:xlinendchat/core/identity/identity_manager.dart';

// Manual Mocks
class ManualMockWaku implements WakuService {
  final _events = StreamController<String>.broadcast();
  @override
  Stream<String> get events => _events.stream;
  
  Function(List<int>)? onPublish;

  @override
  Future<void> initialize({String configJson = "{}"}) async {}
  
  @override
  Future<void> start() async {}
  
  @override
  Future<void> relaySubscribe(String contentTopic) async {}

  @override
  Future<void> relayPublish(String contentTopic, List<int> payload, {int ms = 0}) async {
    onPublish?.call(payload);
  }
  
  void simulateIncoming(String json) => _events.add(json);

  @override
  bool isStarted() => true;

  @override
  Future<void> stop() async {
    await _events.close();
  }
}

class ManualMockIdentity extends IdentityManager {
  SimpleKeyPair? _mockKey;
  String? _mockPub;

  void setMockIdentity(SimpleKeyPair key, String pub) {
    _mockKey = key;
    _mockPub = pub;
  }

  @override
  SimpleKeyPair? get identityKeyPair => _mockKey;
  
  @override
  String? get identityPublicKey => _mockPub;

  @override
  Future<void> generateIdentityKeys() async {}
}

void main() async {
  print("--- Starting P2PProvider Integration Verification ---");

  final x25519 = X25519();
  final aliceKeyPair = await x25519.newKeyPair();
  final bobKeyPair = await x25519.newKeyPair();
  
  final alicePub = base64Encode((await aliceKeyPair.extractPublicKey()).bytes);
  final bobPub = base64Encode((await bobKeyPair.extractPublicKey()).bytes);

  final mockWakuAlice = ManualMockWaku();
  final mockWakuBob = ManualMockWaku();
  
  final mockIdAlice = ManualMockIdentity()..setMockIdentity(aliceKeyPair, alicePub);
  final mockIdBob = ManualMockIdentity()..setMockIdentity(bobKeyPair, bobPub);

  final alice = P2PProvider(
    wakuService: mockWakuAlice,
    cryptoService: DoubleRatchetService(),
    identityManager: mockIdAlice,
  );

  final bob = P2PProvider(
    wakuService: mockWakuBob,
    cryptoService: DoubleRatchetService(),
    identityManager: mockIdBob,
  );

  mockWakuAlice.onPublish = (payload) {
    final eventJson = jsonEncode({
      'type': 'message',
      'data': {
        'payload': base64Encode(payload),
        'contentTopic': P2PProvider.defaultTopic,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }
    });
    mockWakuBob.simulateIncoming(eventJson);
  };

  await alice.init();
  await bob.init();

  final completer = Completer<String>();
  bob.incomingMessages.listen((msg) {
    if (!completer.isCompleted) completer.complete(msg.text);
  });

  print("Alice sending message to Bob...");
  await alice.sendMessage(bobPub, "Hello Bob! This is an E2E encrypted P2P message.");

  try {
    final receivedText = await completer.future.timeout(Duration(seconds: 10));
    print("Bob received: $receivedText");

    if (receivedText == "Hello Bob! This is an E2E encrypted P2P message.") {
      print("✅ VERIFICATION SUCCESS: P2PProvider correctly orchestrates Waku and Double Ratchet.");
    } else {
      print("❌ VERIFICATION FAILED: Received text mismatch.");
    }
  } catch (e) {
    print("❌ VERIFICATION FAILED: Timeout waiting for message. $e");
  }
}
