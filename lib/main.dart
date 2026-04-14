/* 
 * 引入應用程式啟動所需的各項核心套件：
 * 1. google_fonts: 提供現代化的字體樣式。
 * 2. hive_flutter: 提供高性能的本地儲存支援，用於 P2P 訊息。
 * 3. 各個頁面與核心邏輯模組。
 * 
 * Imports core packages required for application startup:
 * 1. google_fonts: Provides modern typography.
 * 2. hive_flutter: Provides high-performance local storage for P2P messages.
 * 3. Screens and core logic modules.
 */
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/chat/screens/chat_list_screen.dart';
import 'ui/skins/skin_service.dart';
import 'core/identity/identity_manager.dart';
import 'core/security/secure_window_manager.dart';
import 'core/security/volume_key_interceptor.dart';
import 'core/storage/database_service.dart';
import 'core/network/waku/p2p_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  /* 載入皮膚設定 (Load skin settings) */
  SkinService().loadPersistedSkin();

  /* 啟用防截圖保護 (Enable anti-screenshot protection) */
  await SecureWindowManager.enableProtection();
  
  /* 
   * 初始化具有硬體安全保護的 DatabaseService (Hive + SecureStorage)
   * Initializes the hardware-secured DatabaseService.
   */
  await DatabaseService.initialize();
  
  /* 
   * 初始化 P2P 引擎 (啟動 Waku 與加密層)
   * Initialize P2P Engine (Start Waku and Encryption layer)
   */
  final p2pEngine = P2PEngine();
  await p2pEngine.init();

  /* 
   * 初始化身分管理與硬體自毀監聽。
   * Initialize custom identity and hardware self-destruct listeners.
   */
  final identityManager = p2pEngine.p2pProvider.identityManager;
  VolumeKeyInterceptor.startListening(identityManager);
  
  /* 啟動 UI 根元件。 (Launch the root UI component.) */
  runApp(const LineChatApp());
}

/* 
 * LineChatApp 類別：
 * 應用程式根元件，現在會監聽 SkinService 的變更。
 */
class LineChatApp extends StatelessWidget {
  const LineChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SkinService(),
      builder: (context, _) {
        final skin = SkinService().currentSkin;
        
        return MaterialApp(
          title: 'XLinendChat',
          /* 關閉開發模式的紅色橫條。 (Hides the debug banner.) */
          debugShowCheckedModeBanner: false,
          /* 
           * 定義應用程式的全局主題，從當前 Skin 提取。
           * Defines the global application theme derived from current skin.
           */
          theme: ThemeData(
            primaryColor: skin.primaryColor,
            scaffoldBackgroundColor: skin.scaffoldBackgroundColor,
            textTheme: GoogleFonts.notoSansTextTheme(),
            appBarTheme: AppBarTheme(
              backgroundColor: skin.appBarBackgroundColor,
              foregroundColor: skin.appBarForegroundColor,
              elevation: 0,
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: skin.primaryColor,
              primary: skin.primaryColor,
            ),
          ),
          /* 設定應用的第一個顯示頁面為聊天列表。 (Sets the initial screen to the Chat List.) */
          home: const ChatListScreen(),
        );
      },
    );
  }
}
