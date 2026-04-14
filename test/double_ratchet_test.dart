import 'package:flutter_test/flutter_test.dart';
import 'package:xlinendchat/core/encryption/double_ratchet_service.dart';

void main() {
  group('Double Ratchet Service Tests', () {
    late DoubleRatchetService alice;
    late DoubleRatchetService bob;
    late String alicePub;
    late String bobPub;

    setUp(() async {
      alice = DoubleRatchetService();
      await alice.generateIdentityKeys();
      alicePub = await alice.getMyPublicKey();

      bob = DoubleRatchetService();
      await bob.generateIdentityKeys();
      bobPub = await bob.getMyPublicKey();
    });

    test('Alice to Bob simple message', () async {
      String msg = "Hello from Alice!";
      String cipher = await alice.encryptE2E(msg, bobPub);
      String decoded = await bob.decryptE2E(cipher, alicePub);
      expect(decoded, msg);
    });

    test('Ping Pong interaction (DH Ratchet triggers)', () async {
      String msg1 = "Ping!";
      String c1 = await alice.encryptE2E(msg1, bobPub);
      String d1 = await bob.decryptE2E(c1, alicePub);
      expect(d1, msg1);

      String msg2 = "Pong!";
      String c2 = await bob.encryptE2E(msg2, alicePub);
      String d2 = await alice.decryptE2E(c2, bobPub);
      expect(d2, msg2);

      String msg3 = "Ping again!";
      String c3 = await alice.encryptE2E(msg3, bobPub);
      String d3 = await bob.decryptE2E(c3, alicePub);
      expect(d3, msg3);
    });

    test('Multiple messages in one direction (Symmetric key ratchet)', () async {
      String msg1 = "Message 1";
      String msg2 = "Message 2";
      String msg3 = "Message 3";

      String c1 = await alice.encryptE2E(msg1, bobPub);
      String c2 = await alice.encryptE2E(msg2, bobPub);
      String c3 = await alice.encryptE2E(msg3, bobPub);

      expect(await bob.decryptE2E(c1, alicePub), msg1);
      expect(await bob.decryptE2E(c2, alicePub), msg2);
      expect(await bob.decryptE2E(c3, alicePub), msg3);
    });

    test('Out of order message delivery (Skipped keys)', () async {
      String msg1 = "First";
      String msg2 = "Second";
      String msg3 = "Third";

      String c1 = await alice.encryptE2E(msg1, bobPub);
      String c2 = await alice.encryptE2E(msg2, bobPub);
      String c3 = await alice.encryptE2E(msg3, bobPub);

      // Decrypt 3 then 1 then 2 (out of order simulation)
      expect(await bob.decryptE2E(c3, alicePub), msg3);
      expect(await bob.decryptE2E(c1, alicePub), msg1);
      expect(await bob.decryptE2E(c2, alicePub), msg2);
    });
  });
}
