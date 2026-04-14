import 'package:flutter/material.dart';
import 'skin_specification.dart';
import '../theme/line_colors.dart';

/*
 * LineSkin 類別：
 * 實作 LINE 風格的視覺規範。
 * 
 * LineSkin class:
 * Implements the LINE-style visual specification.
 */
class LineSkin extends AppSkin {
  @override
  String get name => 'LINE-Like';

  @override
  Color get scaffoldBackgroundColor => LineColors.background;

  @override
  Color get appBarBackgroundColor => Colors.white;

  @override
  Color get appBarForegroundColor => Colors.black;

  @override
  Color get primaryColor => LineColors.primaryGreen;

  @override
  Color get chatBackgroundColor => LineColors.chatBackground;

  @override
  Color get unreadBadgeColor => LineColors.primaryGreen;

  @override
  Color get unreadBadgeTextColor => Colors.white;

  @override
  Color get dividerColor => Colors.grey[200]!;

  @override
  Color get tabBarSelectedColor => LineColors.primaryGreen;

  @override
  Color get tabBarUnselectedColor => Colors.grey;

  @override
  Color get myBubbleColor => LineColors.myBubble;

  @override
  Color get otherBubbleColor => LineColors.otherBubble;

  @override
  Color get myTextColor => Colors.black87;

  @override
  Color get otherTextColor => Colors.black87;

  @override
  BorderRadius getBubbleBorderRadius(bool isMe) {
    return BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 0),
      bottomRight: Radius.circular(isMe ? 0 : 16),
    );
  }

  @override
  Color get inputBarColor => Colors.white;

  @override
  Color get inputFieldColor => Colors.grey[100]!;

  @override
  BorderRadius get inputFieldBorderRadius => BorderRadius.circular(24);

  @override
  Widget buildSendButton({required VoidCallback onPressed, required Color color}) {
    return IconButton(
      icon: Icon(Icons.send, color: color),
      onPressed: onPressed,
    );
  }

  @override
  Color get statusIconColor => Colors.grey;

  @override
  Color get readStatusColor => Colors.blue; // LINE 的「已讀」通常是文字，這裡先用雙勾藍色表示
}
