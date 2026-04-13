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
import 'package:flutter/material.dart';
import '../../../ui/theme/line_colors.dart';
import '../../../ui/widgets/chat_bubble.dart';
import '../services/chat_message_service.dart';
import '../../../core/network/smp_client.dart';
import '../../../core/encryption/e2ee_service.dart';
import '../../../core/identity/identity_manager.dart';

/* 
 * ChatRoomScreen 類別：
 * 具體的聊天對話頁面。
 * 
 * ChatRoomScreen class:
 * The detailed chat conversation page.
 */
class ChatRoomScreen extends StatefulWidget {
  /* 顯示目前對話對象的名字。 (The name of the person you are chatting with.) */
  final String userName;
  const ChatRoomScreen({super.key, required this.userName});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _controller = TextEditingController();
  late ChatMessageService _messageService;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    /*
     * 為了展示 UI 與加密通訊的綁定，我們在此暫時初始化這些服務。
     * 在未來的架構中，這些服務將會被依賴注入 (DI) 或狀態管理庫提供。
     * 
     * For demonstrating the UI binding to encrypted comms, we temporarily initialize
     * these services here. In the future architecture, they will be provided by DI.
     */
    
    final identityManager = IdentityManager();
    await identityManager.generateIdentityKeys();
    
    final smpClient = SmpClientV9();
    await smpClient.connect(SmpClientV9.defaultRelay, "mock_fp");
    
    final e2eCipher = E2EeService(identityManager);
    
    // 產生一把模擬的對方公鑰，讓 ECDH 能夠運作
    // Generate a mock remote public key so ECDH can function
    final mockRemoteManager = IdentityManager();
    await mockRemoteManager.generateIdentityKeys();
    
    _messageService = ChatMessageService(
      smpClient: smpClient,
      e2eCipher: e2eCipher,
      identityManager: identityManager,
      remotePublicKey: mockRemoteManager.identityPublicKey!,
      senderQueueId: "sender_queue_123",
    );

    setState(() {
      _isInit = true;
    });
  }

  @override
  void dispose() {
    if (_isInit) _messageService.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    
    _messageService.sendMessage(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) {
      return Scaffold(
        backgroundColor: LineColors.chatBackground,
        appBar: AppBar(title: Text(widget.userName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      /* 聊天室專屬的藍灰色背景。 (The signature blue-grey background for chat rooms.) */
      backgroundColor: LineColors.chatBackground,
      appBar: AppBar(
        title: Text(widget.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.phone_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          /* 用 Expanded 讓訊息列表佔滿剩餘空間，監聽並渲染服務中的對話列表。 */
          /* Expands the message list to fill available space, listen and render from service. */
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
                    );
                  },
                );
              },
            ),
          ),
          
          /* 底端輸入欄位 (Bottom Input Bar) */
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                   IconButton(icon: const Icon(Icons.add, color: Colors.grey), onPressed: () {}),
                   IconButton(icon: const Icon(Icons.camera_alt_outlined, color: Colors.grey), onPressed: () {}),
                   IconButton(icon: const Icon(Icons.photo_outlined, color: Colors.grey), onPressed: () {}),
                   Expanded(
                     child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 12),
                       decoration: BoxDecoration(
                         color: Colors.grey[100],
                         borderRadius: BorderRadius.circular(24),
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
                   IconButton(
                     icon: Icon(Icons.send, color: LineColors.primaryGreen),
                     onPressed: _sendMessage,
                   ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
