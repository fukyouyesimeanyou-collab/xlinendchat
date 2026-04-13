import 'package:hive/hive.dart';

part 'ratchet_state.g.dart';

/*
 * RatchetState 類別：
 * 用於持久化雙棘輪演算法的內部狀態，確保 App 重啟後加密通道不中斷。
 * 
 * RatchetState class:
 * Persists the internal state of the Double Ratchet algorithm, 
 * ensuring the encrypted channel remains continuous after App restarts.
 */
@HiveType(typeId: 2)
class RatchetState extends HiveObject {
  @HiveField(0)
  /* 根金鑰 (Root Key bytes) */
  final List<int>? rootKeyBytes;

  @HiveField(1)
  /* 我方當前 DH 私鑰 (Local DH Private Key bytes) */
  final List<int>? localDhPrivKeyBytes;

  @HiveField(2)
  /* 我方當前 DH 公鑰 (Local DH Public Key bytes) */
  final List<int>? localDhPubKeyBytes;

  @HiveField(3)
  /* 對方當前 DH 公鑰 (Remote DH Public Key bytes) */
  final List<int>? remoteDhPubKeyBytes;

  @HiveField(4)
  /* 發送鏈金鑰 (Sending Chain Key bytes) */
  final List<int>? sendingChainKeyBytes;

  @HiveField(5)
  /* 發送訊息序號 (Sending Message Number) */
  final int sendingMessageNumber;

  @HiveField(6)
  /* 接收鏈金鑰 (Receiving Chain Key bytes) */
  final List<int>? receivingChainKeyBytes;

  @HiveField(7)
  /* 接收訊息序號 (Receiving Message Number) */
  final int receivingMessageNumber;

  @HiveField(8)
  /* 略過的訊息金鑰 (Skipped Message Keys: Map<Index, KeyBytes>) */
  final Map<int, List<int>> skippedMessageKeys;

  RatchetState({
    this.rootKeyBytes,
    this.localDhPrivKeyBytes,
    this.localDhPubKeyBytes,
    this.remoteDhPubKeyBytes,
    this.sendingChainKeyBytes,
    this.sendingMessageNumber = 0,
    this.receivingChainKeyBytes,
    this.receivingMessageNumber = 0,
    this.skippedMessageKeys = const {},
  });
}
