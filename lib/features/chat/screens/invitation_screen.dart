/* 
 * 引入必要的 UI 套件：
 * 1. qr_flutter: 用於將網址字串轉換並顯示為 QR Code 圖片。
 * 2. share_plus: 調用系統原生的分享介面（例如傳送至 LINE, WhatsApp 或簡訊）。
 * 3. dart:async: 用於 Timer 控制。
 */
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/* 
 * InvitationScreen 類別：
 * 顯示使用者自己的邀請資訊頁面。採用極簡專業風格並帶有 5 分鐘嚴格失效機制。
 * 
 * InvitationScreen class:
 * Displays the user's personal invitation page. Uses a minimalist professional style 
 * and features a strict 5-minute expiration mechanism.
 */
class InvitationScreen extends StatefulWidget {
  final String invitationLink;
  final String shortCode;

  const InvitationScreen({
    super.key, 
    required this.invitationLink, 
    required this.shortCode
  });

  @override
  State<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends State<InvitationScreen> {
  // 5 分鐘 = 300 秒 (5 minutes = 300 seconds)
  int _remainingSeconds = 300;
  Timer? _countdownTimer;

  bool get _isExpired => _remainingSeconds <= 0;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _startPakeListener();
  }

  void _startPakeListener() async {
    final engine = P2PEngine();
    final invitationService = InvitationService(
      identityManager: engine.p2pProvider.identityManager,
      pakeService: engine.pakeService,
    );

    // 啟動 PAKE 監聽 (Start PAKE listener)
    final peer = await invitationService.startWaitingForPeer(widget.shortCode);
    
    if (peer != null && mounted) {
      // 發現同伴！ (Peer found!)
      _countdownTimer?.cancel();
      
      // 這裡理論上應該將 peer 加入資料庫 (In reality, we should add peer to DB here)
      // 但為了展示，我們直接導向聊天室 (For demo, we just navigate to chat)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已連接到 ${peer['name']}！ (Connected to ${peer['name']}!)')),
      );
      
      Navigator.pop(context); // 關閉邀請頁
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    /* 定義全域極簡黑灰色系 (Define minimalist grayscale theme) */
    final primaryColor = _isExpired ? Colors.grey[400]! : Colors.black87;
    final accentColor = _isExpired ? Colors.grey[300]! : Colors.black;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('安全代碼交換 (Key Exchange)', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1.0)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey[300], height: 1.0),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              /* 狀態顯示：倒數計時或已失效 (State Display: Countdown or Expired) */
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: _isExpired ? Colors.red[300]! : Colors.black87, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                  color: _isExpired ? Colors.red[50] : Colors.transparent,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isExpired ? Icons.lock_clock : Icons.timer_outlined,
                      size: 20,
                      color: _isExpired ? Colors.red[700] : Colors.black87,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isExpired ? '代碼已失效 (EXPIRED)' : '${_formatDuration(_remainingSeconds)} 有效性倒數 (VALIDITY)',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _isExpired ? Colors.red[700] : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              
              /* QR Code 顯示區 (極簡無陰影，外加方框指引) */
              /* QR Code Area (Minimalist without shadows, with framing guides) */
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Opacity(
                  opacity: _isExpired ? 0.2 : 1.0,
                  child: QrImageView(
                    data: widget.invitationLink,
                    version: QrVersions.auto,
                    size: 220.0,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: _isExpired ? Colors.grey[300] : Colors.black87,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: _isExpired ? Colors.grey[300] : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),

              /* 10位短碼顯示區 (10-Digit Short Code Area) */
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '手動輸入驗證碼 (Manual Verification Code)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              title: const Text('安全政策 (Security Policy)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                              content: const Text(
                                '為防止連線遭攔截與重放攻擊，所有產出之代碼：\n\n'
                                '• 嚴格限制於產出後 5 分鐘內使用。\n'
                                '• 對方成功認證後立即抹除作廢。\n\n'
                                '即使代碼外洩，仍需您的設備進行本地金鑰驗證。',
                                style: TextStyle(height: 1.6, fontSize: 14),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('了解 (Acknowledge)', style: TextStyle(color: Colors.black)),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  /* 若過期則無法全選複製 (If expired, disable selection copying) */
                  _isExpired
                      ? Text(
                          '— — — — —  — — — — —',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[300]),
                        )
                      : SelectableText(
                          widget.shortCode,
                          style: TextStyle(
                            fontSize: 32, 
                            fontWeight: FontWeight.w600, 
                            letterSpacing: 4.0,
                            fontFamily: 'monospace',
                            color: accentColor,
                          ),
                        ),
                ],
              ),
              const SizedBox(height: 64),
              
              /* 分享按鈕 (Share Button) */
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isExpired ? null : () {
                    final shareText = 'P2P 加密連線請求 (Secure Connection Request)\n\n'
                                      '連線代碼 (Code): ${widget.shortCode}\n'
                                      '備用網址 (Link): ${widget.invitationLink}\n\n'
                                      '此代碼將於 5 分鐘後自動失效。';
                    Share.share(shareText);
                  },
                  icon: const Icon(Icons.share, size: 20),
                  label: Text(_isExpired ? '代碼已過期 (Link Expired)' : '傳送代碼 (Share Code)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[200],
                    disabledForegroundColor: Colors.grey[500],
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), // 極簡方角 (Minimalist square corners)
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
