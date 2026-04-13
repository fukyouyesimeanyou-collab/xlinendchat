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
import 'ui/theme/line_colors.dart';
import 'core/identity/identity_manager.dart';
import 'core/security/secure_window_manager.dart';
import 'core/security/volume_key_interceptor.dart';
import 'core/storage/database_service.dart';

/* 
 * main() 是整個 Flutter 程式的入口點 (Entry Point)。
 * 因為涉及非同步操作（初始化資料庫），所以標記為 async。
 * 
 * main() is the entry point of the Flutter application. 
 * Marked as async because it involves asynchronous operations like 
 * database initialization.
 */
void main() async {
  /* 
   * 確保 Flutter 引擎初始化完成。
   * Ensures the Flutter binding is initialized before running the app.
   */
  WidgetsFlutterBinding.ensureInitialized();
  
  /* 
   * 啟用防截圖保護。 (Enable anti-screenshot protection.)
   */
  await SecureWindowManager.enableProtection();
  
  /* 
   * 初始化具有硬體安全保護的 DatabaseService (Hive + SecureStorage)
   * Initializes the hardware-secured DatabaseService.
   */
  await DatabaseService.initialize();
  
  /* 
   * 初始化身分管理與硬體自毀監聽。
   * Initialize custom identity and hardware self-destruct listeners.
   */
  final identityManager = IdentityManager();
  VolumeKeyInterceptor.startListening(identityManager);
  
  /* 啟動 UI 根元件。 (Launch the root UI component.) */
  runApp(const LineChatApp());
}

/* 
 * LineChatApp 類別：
 * 這是應用程式的最上層元件，定義了應用的主題、標題與導向。
 * 
 * LineChatApp class:
 * The top-level widget of the application, defining themes, titles, and routing.
 */
class LineChatApp extends StatelessWidget {
  const LineChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LINE P2P Clone',
      /* 關閉開發模式的紅色橫條。 (Hides the debug banner.) */
      debugShowCheckedModeBanner: false,
      /* 
       * 定義應用程式的全局主題。
       * Defines the global application theme.
       */
      theme: ThemeData(
        primaryColor: LineColors.primaryGreen,
        scaffoldBackgroundColor: LineColors.background,
        /* 使用 Google Fonts 提升介面質感。 (Uses Google Fonts for better aesthetics.) */
        textTheme: GoogleFonts.notoSansTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: LineColors.primaryGreen,
          primary: LineColors.primaryGreen,
        ),
      ),
      /* 設定應用的第一個顯示頁面為聊天列表。 (Sets the initial screen to the Chat List.) */
      home: const ChatListScreen(),
    );
  }
}
