/* 
 * 引入必要的套件：
 * 1. mobile_scanner: 提供高性能的跨平台相機二維碼掃描。
 * 2. invitation_service: 連線服務層，進行實體解碼。
 * 
 * Imports necessary packages:
 * 1. mobile_scanner: High-performance cross-platform QR code scanning.
 * 2. invitation_service: Connection service handling actual decoding.
 */
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../ui/theme/line_colors.dart';
import '../services/invitation_service.dart';
import '../../../core/identity/identity_manager.dart';
import 'chat_room_screen.dart';

/*
 * ScannerScreen 類別：
 * 提供雙軌介面：相機 QR 掃描與文字輸入框，讓使用者能透過任意方式建立連線。
 * 
 * ScannerScreen class:
 * Provides a dual-interface: Camera QR scanning and text input box, 
 * allowing the user to establish a connection in either way.
 */
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final TextEditingController _codeController = TextEditingController();
  final MobileScannerController _cameraController = MobileScannerController();
  late final InvitationService _invitationService;

  /* 追蹤是否正在處理連線中。 (Tracks if connection is in progress.) */
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // 初始化服務 (Initialize services)
    final identityManager = IdentityManager();
    _invitationService = InvitationService(identityManager);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  /* 
   * 處理透過鏡頭讀取到的 QR Code。
   * Handles QR Codes scanned via the camera.
   */
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return; // 防連按鎖 (Anti-spam lock)

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.startsWith('simplex:')) {
        await _establishConnection(isQr: true, payload: barcode.rawValue!);
        break;
      }
    }
  }

  /* 
   * 處理透過鍵盤手動輸入的短碼。
   * Handles short codes entered manually via the text field.
   */
  Future<void> _onManualCodeSubmit() async {
    final code = _codeController.text.trim();
    if (code.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('代碼長度錯誤，請輸入 10 位數短碼。\n(Invalid code length, must be 10 chars.)')),
      );
      return;
    }
    await _establishConnection(isQr: false, payload: code);
  }

  /* 
   * 收斂核心邏輯：呼叫解碼服務建立安全連線並導向。
   * Converges the core logic: calls decoding service to establish secure connection and navigates.
   */
  Future<void> _establishConnection({required bool isQr, required String payload}) async {
    /* 開啟載入遮罩 (Show loading overlay) */
    setState(() {
      _isProcessing = true;
    });

    try {
      /* 停止背景相機消耗資源 (Stop camera background processing) */
      _cameraController.stop();

      Map<String, String> remoteData;
      if (isQr) {
        remoteData = await _invitationService.processInvitationUri(payload);
      } else {
        remoteData = await _invitationService.decodeShortCodeForPake(payload);
      }

      if (remoteData.isEmpty || remoteData['key'] == null || remoteData['key']!.isEmpty) {
        throw Exception('無效的金鑰或解碼失敗 (Invalid key or decode failure)');
      }

      /* 連線成功，跳轉至聊天室並清空這個 Scanner。
         (Connection success, navigate to ChatRoom and close Scanner.) */
      if (mounted) {
        Navigator.pop(context); // 關閉掃描頁 (Close scanner)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ChatRoomScreen(userName: '新聯絡人 (New Contact)'),
          ),
        );
      }
    } catch (e) {
      /* 發生錯誤，恢復畫面狀態 (Error occurred, restore screen state) */
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _cameraController.start();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('連線失敗 (Connection Failed): $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('掃描或輸入 (Scan & Connect)', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      /* 
       * 使用 Stack 來疊加載入遮罩。
       * Use Stack to overlay the loading mask.
       */
      body: Stack(
        children: [
          _buildMainBody(),
          
          /* 全螢幕載入遮罩 (Full-screen Loading Overlay) */
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: LineColors.primaryGreen),
                    SizedBox(height: 24),
                    Text(
                      '正在建立安全連線...\n(Establishing Secure Connection...)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: 16, 
                        fontWeight: FontWeight.bold, 
                        height: 1.5,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainBody() {
    return Column(
      children: [
        /* 
         * 上半部：相機掃描區域
         * Top half: Camera scanning area
         */
        Expanded(
          flex: 5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              MobileScanner(
                controller: _cameraController,
                onDetect: _onDetect,
              ),
              /* 模擬準星框 (Simulated aiming frame) */
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: LineColors.primaryGreen, width: 3.0),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const Positioned(
                bottom: 24,
                child: Text(
                  '將 QR Code 放入框內\n(Place QR Code inside the frame)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, backgroundColor: Colors.black54, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        
        /* 
         * 下半部：手動輸入短碼區域
         * Bottom half: Manual short code entry area
         */
        Expanded(
          flex: 3,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Text(
                  '或輸入遠距連線短碼\n(Or enter remote short code)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        maxLength: 10,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _onManualCodeSubmit(),
                        decoration: InputDecoration(
                          hintText: 'ex: aBcD12#\$eF',
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: LineColors.primaryGreen, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _onManualCodeSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LineColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Icon(Icons.arrow_forward, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
