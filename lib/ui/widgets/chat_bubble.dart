/*
 * chat_bubble.dart (已升級版)
 * 
 * 包含訊息傳送狀態指示器：
 * sending → 旋轉小圈  sent → 單勾  delivered → 雙勾  read → 藍色雙勾
 * 
 * Includes message delivery status indicators:
 * sending → spinner  sent → single tick  delivered → double tick  read → blue double tick
 */
import 'dart:io';
import 'package:flutter/material.dart';
import '../skins/skin_service.dart';
import '../../core/models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;
  /* 訊息傳送狀態 (Message delivery status) — 只有我方顯示 */
  final MessageStatus status;
  final String? stickerPath;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.time,
    this.status = MessageStatus.sent,
    this.stickerPath,
  });

  /*
   * 根據 MessageStatus 渲染對應的狀態圖標
   * Render the appropriate status icon based on MessageStatus.
   */
  Widget _buildStatusIcon() {
    if (!isMe) return const SizedBox.shrink(); // 只有我方顯示狀態
    final skin = SkinService().currentSkin;
    
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12, height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: skin.statusIconColor),
        );
      case MessageStatus.sent:
        return Icon(Icons.check, size: 14, color: skin.statusIconColor);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: skin.statusIconColor);
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 14, color: skin.readStatusColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = SkinService().currentSkin;
    
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
            Text(time, style: TextStyle(fontSize: 10, color: skin.statusIconColor)),
            const SizedBox(width: 4),
          ],

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? skin.myBubbleColor : skin.otherBubbleColor,
                borderRadius: skin.getBubbleBorderRadius(isMe),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: stickerPath != null
                ? ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150, maxHeight: 150),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(stickerPath!), fit: BoxFit.contain),
                    ),
                  )
                : Text(text, style: TextStyle(fontSize: 16, color: isMe ? skin.myTextColor : skin.otherTextColor)),
            ),
          ),

          /* 對方訊息：時間在右 (Their messages: time on the right) */
          if (!isMe) ...[
            const SizedBox(width: 4),
            Text(time, style: TextStyle(fontSize: 10, color: skin.statusIconColor)),
          ],
        ],
      ),
    );
  }
}
