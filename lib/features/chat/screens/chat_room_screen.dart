/* 
 * 引入必要的 UI 元件：
 * 1. theme/line_colors.dart: 聊天室特有的背景色與按鈕色。
 * 2. widgets/chat_bubble.dart: 渲染每一則訊息的氣泡元件。
 * 3. 匯入新增的 ChatMessageService 處理狀態。
 * 
 * Imports necessary UI components:
 * 1. theme/line_colors.dart: Background and button colors for the chat room.
 * 2. widgets/chat_bubble.dart: Renders the bubble component for each message.
 * 3. Import ChatMessageService for state management.
 */
import 'dart:async';
import 'package:flutter/material.dart';
import '../../ui/skins/skin_service.dart';
import '../../../ui/widgets/chat_bubble.dart';
import '../services/chat_message_service.dart';
import '../../../core/network/waku/p2p_engine.dart';
import '../../../core/models/contact.dart';
import '../../../core/storage/database_service.dart';
import 'package:screenshot_callback/screenshot_callback.dart';
import '../../stickers/widgets/sticker_picker_panel.dart';
import '../../stickers/services/sticker_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class ChatRoomScreen extends StatefulWidget {
  final Contact contact;
  const ChatRoomScreen({super.key, required this.contact});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _controller = TextEditingController();
  late ChatMessageService _messageService;
  bool _isInit = false;
  
  Timer? _barTimer;
  String _timerText = "00:00:00";
  ScreenshotCallback? _screenshotCallback;
  bool _isLocalScreenshotDetected = false;
  bool _showStickerPicker = false;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    // 獲取全局 P2P 引擎 (Get global P2P engine)
    final engine = P2PEngine();
    
    // 如果尚未初始化，進行初始化 (雖然 main.dart 應該已經做過了)
    if (!engine.isInitialized) {
      await engine.init();
    }
    
    _messageService = ChatMessageService(
      p2pProvider: engine.p2pProvider,
      identityManager: engine.p2pProvider.identityManager,
      remotePublicKey: widget.contact.publicKeyBase64,
    );

    _messageService.addListener(_onServiceUpdate);
    _messageService.markAsRead();
    _startBarTimerIfNeeded();
    _initScreenshotDetection();

    setState(() {
      _isInit = true;
    });
  }

  void _onServiceUpdate() {
    if (_messageService.isScreenshotWarningActive) {
      _showScreenshotDecisionDialog();
    }
  }

  void _initScreenshotDetection() {
    final enabled = DatabaseService.vaultBox.get('screenshot_notify_enabled', defaultValue: false);
    if (enabled) {
      _screenshotCallback = ScreenshotCallback();
      _screenshotCallback!.addListener(() {
        print('📸 [Local] 偵測到截圖！發送信號中...');
        _messageService.sendScreenshotSignal();
        setState(() => _isLocalScreenshotDetected = true);
        // 本地也顯示系統訊息 (Optional: show local system msg)
      });
    }
  }

  void _startBarTimerIfNeeded() {
    if (widget.contact.isBarActive && widget.contact.barSessionExpiry != null) {
      _barTimer?.cancel();
      _barTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final now = DateTime.now();
        final diff = widget.contact.barSessionExpiry!.difference(now);
        
        if (diff.isNegative) {
          timer.cancel();
          _onBarExpired();
        } else {
          setState(() {
            _timerText = _formatDuration(diff);
          });
        }
      });
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = twoDigits(d.inHours);
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  void _onBarExpired() async {
    // 24小時時限到，不彈警告，直接執行銷毀並關閉 (Expired: No warning, direct shred)
    await _messageService.leaveChat(sendSignal: true);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _handleManualLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('離開對話？'),
        content: const Text('離開對話後本對話內容將全部徹底刪除，且無法恢復。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('確定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _messageService.leaveChat(sendSignal: true);
      if (mounted) Navigator.pop(context);
    }
  }

  void _showScreenshotDecisionDialog() {
    // 確保只彈出一次 (Ensure only one dialog)
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ 截圖警告 (Security Alert)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('偵測到對方執行了截圖操作。這可能違反您的隱私設定。\n\n是否立即離開並銷毀所有對話內容？'),
        actions: [
          TextButton(
            onPressed: () {
              _messageService.dismissScreenshotWarning();
              Navigator.pop(context);
            }, 
            child: const Text('取消 (Ignore)'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _messageService.leaveChat(sendSignal: true);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('立刻銷毀並離開 (Shred & Exit)'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _barTimer?.cancel();
    _screenshotCallback?.dispose();
    if (_isInit) {
      _messageService.removeListener(_onServiceUpdate);
      _messageService.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    
    _messageService.sendMessage(text);
    _controller.clear();
  }

  void _sendSticker(String stickerPath) {
    _messageService.sendLocalSticker(stickerPath);
    setState(() => _showStickerPicker = false);
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      await _messageService.sendFile(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    /* 監聽皮膚服務 (Listen to SkinService) */
    return AnimatedBuilder(
      animation: SkinService(),
      builder: (context, _) {
        final skin = SkinService().currentSkin;

        if (!_isInit) {
          return Scaffold(
            backgroundColor: skin.chatBackgroundColor,
            appBar: AppBar(
              title: Text(widget.contact.displayName),
              backgroundColor: skin.appBarBackgroundColor,
              foregroundColor: skin.appBarForegroundColor,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: skin.chatBackgroundColor,
          appBar: AppBar(
            title: Text(widget.contact.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: skin.appBarBackgroundColor,
            foregroundColor: skin.appBarForegroundColor,
            elevation: 0,
            bottom: (_messageService.isScreenshotWarningActive || _isLocalScreenshotDetected)
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(40),
                  child: Container(
                    width: double.infinity,
                    color: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Center(
                      child: Text(
                        '⚠️ 偵測到違規截圖操作！內容已受威脅',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                )
              : null,
            leading: widget.contact.isBarActive 
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextButton(
                    onPressed: _handleManualLeave,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text('離開對話', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                )
              : const BackButton(),
            leadingWidth: widget.contact.isBarActive ? 80 : null,
            actions: [
              if (widget.contact.isBarActive)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(
                      _timerText,
                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ),
                )
              else ...[
                IconButton(icon: const Icon(Icons.search), onPressed: () {}),
                IconButton(icon: const Icon(Icons.phone_outlined), onPressed: () {}),
                IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
              ],
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: _messageService,
                  builder: (context, child) {
                    final messages = _messageService.messages;
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return ChatBubble(
                          text: msg.text,
                          isMe: msg.isMe,
                          time: msg.time,
                          status: msg.status,
                          stickerPath: msg.stickerPath,
                        );
                      },
                    );
                  },
                ),
              ),
              
              /* 底端輸入欄位 (Bottom Input Bar) */
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                color: skin.inputBarColor,
                child: SafeArea(
                  child: Row(
                    children: [
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.grey), 
                          onPressed: _pickAndSendFile
                        ),
                       IconButton(
                         icon: Icon(
                           _showStickerPicker ? Icons.keyboard : Icons.sentiment_satisfied_alt_outlined, 
                           color: Colors.grey
                         ), 
                         onPressed: () {
                           setState(() {
                             _showStickerPicker = !_showStickerPicker;
                             if (_showStickerPicker) {
                               FocusScope.of(context).unfocus();
                             }
                           });
                         }
                       ),
                       IconButton(icon: const Icon(Icons.camera_alt_outlined, color: Colors.grey), onPressed: () {}),
                       IconButton(icon: const Icon(Icons.photo_outlined, color: Colors.grey), onPressed: () {}),
                       Expanded(
                         child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 12),
                           decoration: BoxDecoration(
                             color: skin.inputFieldColor,
                             borderRadius: skin.inputFieldBorderRadius,
                           ),
                           child: TextField(
                             controller: _controller,
                             decoration: const InputDecoration(
                               hintText: 'Aa',
                               border: InputBorder.none,
                               hintStyle: TextStyle(color: Colors.grey),
                             ),
                           ),
                         ),
                       ),
                       skin.buildSendButton(
                         onPressed: _sendMessage,
                         color: skin.primaryColor,
                       ),
                    ],
                  ),
                ),
              ),
              if (_showStickerPicker)
                StickerPickerPanel(
                  onStickerSelected: (sticker) async {
                    final fullPath = await StickerService().getStickerAbsolutePath(sticker.fileName);
                    _sendSticker(fullPath);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
