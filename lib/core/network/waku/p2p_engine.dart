import 'dart:io';
import 'package:flutter/foundation.dart';
import 'waku_service.dart';
import 'p2p_provider.dart';
import 'pake_service.dart';
import '../../identity/identity_manager.dart';
import '../../encryption/double_ratchet_service.dart';

/// P2PEngine: 全局 Waku P2P 引擎管理器 (Singleton)
/// Global manager for the Waku P2P engine.
class P2PEngine extends ChangeNotifier {
  static final P2PEngine _instance = P2PEngine._internal();
  factory P2PEngine() => _instance;
  P2PEngine._internal();

  late final WakuService wakuService;
  late final P2PProvider p2pProvider;
  late final PakeService pakeService;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// 初始化全局引擎 (Initialize global engine)
  Future<void> init() async {
    if (_isInitialized) return;

    // 定位 libwaku 函式庫路徑 (Locate libwaku path)
    // 根據環境動態調整路徑 (Adjust path based on environment)
    String libPath = _getLibWakuPath();
    
    wakuService = WakuService(libPath);
    final cryptoService = DoubleRatchetService();
    final identityManager = IdentityManager();

    // 1. 初始化 Waku (Initialize Waku)
    await wakuService.initialize();
    
    // 2. 啟動 Waku 節點 (Start Waku node)
    await wakuService.start();

    // 3. 建立並初始化 PakeService
    pakeService = PakeService(wakuService);

    // 4. 建立並初始化 P2P 供應者 (Build and init P2P Provider)
    p2pProvider = P2PProvider(
      wakuService: wakuService,
      cryptoService: cryptoService,
      identityManager: identityManager,
    );
    await p2pProvider.init();

    _isInitialized = true;
    notifyListeners();
    print('✅ [P2PEngine] Global P2P Engine started successfully.');
  }

  String _getLibWakuPath() {
    if (kIsWeb) return '';
    
    // 優先檢查當前專案目錄下的路徑 (Check current project directory first)
    // 注意：在正式打包後，這裡需要根據不同 OS 調整讀取路徑
    if (Platform.isLinux || Platform.isMacOS) {
       return 'lib/core/network/waku/native/libwaku.so';
    }
    
    return 'libwaku.so';
  }

  @override
  void dispose() {
    wakuService.stop();
    super.dispose();
  }
}
