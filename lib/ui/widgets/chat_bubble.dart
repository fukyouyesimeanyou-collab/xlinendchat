/*
 * chat_bubble.dart (已升級版)
 * 
 * 包含訊息傳送狀態指示器：
 * sending → 旋轉小圈  sent → 單勾  delivered → 雙勾  read → 藍色雙勾
 * 
 * Includes message delivery status indicators:
 * sending → spinner  sent → single tick  delivered → double tick  read → blue double tick
 */
import 'package:flutter/material.dart';
import '../theme/line_colors.dart';
import '../../core/models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;
  /* 訊息傳送狀態 (Message delivery status) — 只有我方顯示 */
  final MessageStatus status;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.time,
    this.status = MessageStatus.sent,
  });

  /*
   * 根據 MessageStatus 渲染對應的狀態圖標
   * Render the appropriate status icon based on MessageStatus.
   */
  Widget _buildStatusIcon() {
    if (!isMe) return const SizedBox.shrink(); // 只有我方顯示狀態
    switch (status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 12, height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey),
        );
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 14, color: Colors.grey);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: Colors.grey);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 14, color: Colors.blue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          /* 我方訊息：時間 + 狀態圖標在左 (My messages: time + status icon on the left) */
          if (isMe) ...[
            _buildStatusIcon(),
            const SizedBox(width: 4),
            Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(width: 4),
          ],

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? LineColors.myBubble : LineColors.otherBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(text, style: const TextStyle(fontSize: 16, color: Colors.black)),
            ),
          ),

          /* 對方訊息：時間在右 (Their messages: time on the right) */
          if (!isMe) ...[
            const SizedBox(width: 4),
            Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}
