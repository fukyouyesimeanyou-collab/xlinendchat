import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'crypto_utils.dart';

const int maxSkip = 1000;

class MessageHeader {
  final SimplePublicKey dh;
  final int pn;
  final int n;

  MessageHeader(this.dh, this.pn, this.n);

  Future<List<int>> encode() async {
    final dhBytes = dh.bytes;
    // Simplified binary header encoding for demo. 
    // In production, use Protocol Buffers or explicit binary packing.
    final headerStr = '${base64.encode(dhBytes)}:$pn:$n';
    return utf8.encode(headerStr);
  }

  static Future<MessageHeader> decode(List<int> bytes) async {
    final headerStr = utf8.decode(bytes);
    final parts = headerStr.split(':');
    final dhBytes = base64.decode(parts[0]);
    final dh = SimplePublicKey(dhBytes, type: KeyPairType.x25519);
    final pn = int.parse(parts[1]);
    final n = int.parse(parts[2]);
    return MessageHeader(dh, pn, n);
  }
}

class RatchetState {
  SimpleKeyPair? dhs;       // DH Ratchet key pair (sender)
  SimplePublicKey? dhr;     // DH Ratchet public key (receiver)
  SecretKey rk;             // 32-byte Root Key
  SecretKey? cks;           // 32-byte Chain Key for sending
  SecretKey? ckr;           // 32-byte Chain Key for receiving
  int ns = 0;               // Message number for sending
  int nr = 0;               // Message number for receiving
  int pn = 0;               // Number of messages in previous sending chain
  
  // Dictionary of skipped message keys, indexed by ratchet public key and message number.
  final Map<String, SecretKey> mkSkipped = {};

  RatchetState(this.rk);

  /// Convert internal state to Hive model for persistence
  Future<dynamic> toHiveState() async {
    final Map<String, List<int>> skippedBytes = {};
    for (var entry in mkSkipped.entries) {
      skippedBytes[entry.key] = await entry.value.extractBytes();
    }

    // Import this from our model file later or use a generic mapping
    // For now, let's assume we use the RatchetState from models
    final localDhPriv = dhs != null ? await dhs!.extract() : null;
    final localDhPub = dhs != null ? (await dhs!.extractPublicKey()).bytes : null;

    return {
      'rootKeyBytes': await rk.extractBytes(),
      'localDhPrivKeyBytes': localDhPriv != null ? localDhPriv.bytes : null,
      'localDhPubKeyBytes': localDhPub,
      'remoteDhPubKeyBytes': dhr?.bytes,
      'sendingChainKeyBytes': cks != null ? await cks!.extractBytes() : null,
      'sendingMessageNumber': ns,
      'receivingChainKeyBytes': ckr != null ? await ckr!.extractBytes() : null,
      'receivingMessageNumber': nr,
      'skippedMessageKeys': skippedBytes,
    };
  }

  /// Restore internal state from bytes
  static Future<RatchetState> fromBytes({
    required List<int> rk,
    List<int>? localDhPriv,
    List<int>? localDhPub,
    List<int>? remoteDhPub,
    List<int>? cks,
    int? ns,
    List<int>? ckr,
    int? nr,
    Map<String, List<int>>? skipped,
  }) async {
    final state = RatchetState(SecretKey(rk));
    if (localDhPriv != null && localDhPub != null) {
      state.dhs = SimpleKeyPairData(
        localDhPriv,
        publicKey: SimplePublicKey(localDhPub, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
    }
    if (remoteDhPub != null) {
      state.dhr = SimplePublicKey(remoteDhPub, type: KeyPairType.x25519);
    }
    if (cks != null) state.cks = SecretKey(cks);
    if (ns != null) state.ns = ns;
    if (ckr != null) state.ckr = SecretKey(ckr);
    if (nr != null) state.nr = nr;
    if (skipped != null) {
      skipped.forEach((k, v) => state.mkSkipped[k] = SecretKey(v));
    }
    return state;
  }
}

class DoubleRatchet {
  /// Initialize Alice's state (Bob's public key is known)
  static Future<RatchetState> ratchetInitAlice(SecretKey sk, SimplePublicKey bobDhPubKey) async {
    final state = RatchetState(sk);
    state.dhs = await CryptoUtils.generateKeyPair();
    state.dhr = bobDhPubKey;
    
    // DH Ratchet step using initial keys
    final dhOut = await CryptoUtils.dh(state.dhs!, state.dhr!);
    final keys = await CryptoUtils.kdfRk(state.rk, dhOut);
    state.rk = keys[0];
    state.cks = keys[1];
    
    return state;
  }

  /// Initialize Bob's state (Alice has his public key, Bob only has the shared secret and his keypair)
  static Future<RatchetState> ratchetInitBob(SecretKey sk, SimpleKeyPair bobDhKeyPair) async {
    final state = RatchetState(sk);
    state.dhs = bobDhKeyPair;
    // dhr is not known until Alice sends her first message header
    return state;
  }

  static Future<List<int>> ratchetEncrypt(RatchetState state, List<int> plaintext, List<int> ad) async {
    if (state.cks == null) {
      throw Exception("Cannot encrypt: sending chain key is null. (Bob hasn't received Alice's first message?)");
    }

    final keys = await CryptoUtils.kdfCk(state.cks!);
    state.cks = keys[0];
    final mk = keys[1];

    final header = MessageHeader(await state.dhs!.extractPublicKey(), state.pn, state.ns);
    state.ns += 1;

    // AD = AD || Encode(header)
    final headerBytes = await header.encode();
    final combinedAd = List<int>.from(ad)..addAll(headerBytes);

    final ciphertext = await CryptoUtils.encryptAead(mk, plaintext, combinedAd);
    
    // Wire payload = Header Length (2 bytes) + Header + Ciphertext
    // For simplicity, we just concatenate them. Decrypt will expect exactly this.
    final payload = <int>[];
    payload.add(headerBytes.length >> 8);
    payload.add(headerBytes.length & 0xFF);
    payload.addAll(headerBytes);
    payload.addAll(ciphertext);

    return payload;
  }

  static Future<List<int>> ratchetDecrypt(RatchetState state, List<int> headerCipherPayload, List<int> ad) async {
    // 1. Decode payload structure
    if (headerCipherPayload.length < 2) throw Exception("Payload too small");
    final headerLen = (headerCipherPayload[0] << 8) | headerCipherPayload[1];
    if (headerCipherPayload.length < 2 + headerLen) throw Exception("Invalid header length");
    
    final headerBytes = headerCipherPayload.sublist(2, 2 + headerLen);
    final ciphertext = headerCipherPayload.sublist(2 + headerLen);
    final header = await MessageHeader.decode(headerBytes);

    // 2. Try skipped keys first
    final plaintext = await trySkippedMessageKeys(state, header, ciphertext, ad, headerBytes);
    if (plaintext != null) {
      return plaintext; // Decrypted using a skipped key
    }

    // 3. New public key means DH ratchet step is needed
    final incomingDhPubBytes = header.dh.bytes;
    if (state.dhr != null) {
        final currentDhPubBytes = state.dhr!.bytes;
        if (_bytesEqual(incomingDhPubBytes, currentDhPubBytes) == false) {
          await skipMessageKeys(state, header.pn);
          await dhRatchet(state, header);
        }
    } else {
        // Bob's first reception
        await dhRatchet(state, header);
    }

    // 4. Skip keys in current receiving chain
    await skipMessageKeys(state, header.n);

    // 5. Derive Message Key and decrypt
    final keys = await CryptoUtils.kdfCk(state.ckr!);
    state.ckr = keys[0];
    final mk = keys[1];
    state.nr += 1;

    final combinedAd = List<int>.from(ad)..addAll(headerBytes);
    return await CryptoUtils.decryptAead(mk, ciphertext, combinedAd);
  }

  static Future<void> dhRatchet(RatchetState state, MessageHeader header) async {
    state.pn = state.ns;
    state.ns = 0;
    state.nr = 0;
    state.dhr = header.dh;

    // Receiving part of DH ratchet
    final dhOutR = await CryptoUtils.dh(state.dhs!, state.dhr!);
    var keys = await CryptoUtils.kdfRk(state.rk, dhOutR);
    state.rk = keys[0];
    state.ckr = keys[1];

    // Sending part of DH ratchet
    state.dhs = await CryptoUtils.generateKeyPair();
    final dhOutS = await CryptoUtils.dh(state.dhs!, state.dhr!);
    keys = await CryptoUtils.kdfRk(state.rk, dhOutS);
    state.rk = keys[0];
    state.cks = keys[1];
  }

  static Future<void> skipMessageKeys(RatchetState state, int until) async {
    if (state.nr + maxSkip < until) {
      throw Exception("Too many skipped messages, possible attack or extreme lag.");
    }

    if (state.ckr != null) {
      while (state.nr < until) {
        final keys = await CryptoUtils.kdfCk(state.ckr!);
        state.ckr = keys[0];
        final mk = keys[1];
        
        final dhrBytes = base64.encode(state.dhr!.bytes);
        state.mkSkipped['$dhrBytes:${state.nr}'] = mk;
        state.nr += 1;
      }
    }
  }

  static Future<List<int>?> trySkippedMessageKeys(RatchetState state, MessageHeader header, List<int> ciphertext, List<int> ad, List<int> headerBytes) async {
    final dhrBytes = base64.encode(header.dh.bytes);
    final keyStr = '$dhrBytes:${header.n}';
    
    if (state.mkSkipped.containsKey(keyStr)) {
      final mk = state.mkSkipped[keyStr]!;
      state.mkSkipped.remove(keyStr);
      final combinedAd = List<int>.from(ad)..addAll(headerBytes);
      return await CryptoUtils.decryptAead(mk, ciphertext, combinedAd);
    }
    return null;
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
    }
    return true;
  }
}
