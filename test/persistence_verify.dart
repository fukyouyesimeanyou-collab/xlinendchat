import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:xlinendchat/core/encryption/double_ratchet_service.dart';
import 'package:xlinendchat/core/identity/identity_manager.dart';
import 'package:xlinendchat/core/storage/database_service.dart';
import 'package:xlinendchat/core/models/chat_message.dart';
import 'package:xlinendchat/core/models/ratchet_state.dart';
import 'package:xlinendchat/core/models/contact.dart';

// Manual Mock Waku
import 'pake_verify.dart'; 

void main() async {
  print("--- Starting Persistence & Session Recovery Verification ---");

  // 1. Setup Mock Database (local directory)
  Hive.init('.');
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ChatMessageAdapter());
    Hive.registerAdapter(MessageStatusAdapter());
    Hive.registerAdapter(RatchetStateAdapter());
    Hive.registerAdapter(ContactAdapter());
    Hive.registerAdapter(ContactStatusAdapter());
  }

  // Open boxes
  DatabaseService.ratchetBox = await Hive.openBox<RatchetState>('ratchet_test');
  DatabaseService.chatHistoryBox = await Hive.openBox<ChatMessage>('history_test');

  final x25519 = X25519();
  final aliceIdKey = await x25519.newKeyPair();
  final bobIdKey = await x25519.newKeyPair();
  
  final bobPub = base64Encode((await bobIdKey.extractPublicKey()).bytes);

  // 2. Initial Session: Alice sends first message
  print("\n[Step 1] Initial Session Start...");
  final aliceService1 = DoubleRatchetService();
  aliceService1.setIdentityKeyPair(aliceIdKey);
  
  final encrypted1 = await aliceService1.encryptE2E("Message 1: Syncing ratchet...", bobPub);
  print("Alice: Sent Message 1. Cipher length: ${encrypted1.length}");

  // Verify state is saved in Hive
  final savedState1 = DatabaseService.ratchetBox.get(bobPub);
  if (savedState1 == null) throw Exception("❌ State NOT saved to Hive!");
  print("✅ [Persistence] Ratchet state 1 saved to Hive.");

  // 3. Bob receives Alice's first message
  final bobService = DoubleRatchetService();
  bobService.setIdentityKeyPair(bobIdKey);
  final decrypted1 = await bobService.decryptE2E(encrypted1, base64Encode((await aliceIdKey.extractPublicKey()).bytes));
  print("Bob: Received '$decrypted1'");

  // 4. Session Recovery: Alice "restarts" and sends segunda message
  print("\n[Step 2] Simulated Restart & Recovery...");
  
  // Create a TOTALLY NEW service instance (simulating app restart)
  final aliceService2 = DoubleRatchetService();
  aliceService2.setIdentityKeyPair(aliceIdKey);

  // Note: DoubleRatchetService.encryptE2E will automatically load from DatabaseService.ratchetBox
  final encrypted2 = await aliceService2.encryptE2E("Message 2: Recovered session!", bobPub);
  print("Alice (after restart): Sent Message 2.");

  // 5. Bob receives Alice's recovered message
  final alicePub = base64Encode((await aliceIdKey.extractPublicKey()).bytes);
  final decrypted2 = await bobService.decryptE2E(encrypted2, alicePub);
  print("Bob: Received '$decrypted2'");

  if (decrypted2 == "Message 2: Recovered session!") {
    print("\n🎉 PERSISTENCE SUCCESS: Session correctly recovered from Hive and ratchet continued smoothly.");
  } else {
    print("\n❌ PERSISTENCE FAILED: Session desynchronized after restart.");
  }

  await Hive.deleteFromDisk();
}
