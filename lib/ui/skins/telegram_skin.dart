import 'package:flutter/material.dart';
import 'skin_specification.dart';

class TelegramSkin extends AppSkin {
  @override
  String get name => 'Telegram';

  @override
  Color get scaffoldBackgroundColor => Colors.white;

  @override
  Color get appBarBackgroundColor => const Color(0xFF517da2);

  @override
  Color get appBarForegroundColor => Colors.white;

  @override
  Color get primaryColor => const Color(0xFF24A1DE);

  @override
  Color get chatBackgroundColor => const Color(0xFFdfe6eb);

  @override
  Color get unreadBadgeColor => const Color(0xFF24A1DE);

  @override
  Color get unreadBadgeTextColor => Colors.white;

  @override
  Color get dividerColor => const Color(0xFFF2F2F2);

  @override
  Color get tabBarSelectedColor => const Color(0xFF24A1DE);

  @override
  Color get tabBarUnselectedColor => Colors.grey;

  @override
  Color get myBubbleColor => const Color(0xFFeffdde);

  @override
  Color get otherBubbleColor => Colors.white;

  @override
  Color get myTextColor => Colors.black87;

  @override
  Color get otherTextColor => Colors.black87;

  @override
  BorderRadius getBubbleBorderRadius(bool isMe) {
    // Telegram bubbles are generally very rounded.
    return BorderRadius.circular(16);
  }

  @override
  Color get inputBarColor => Colors.white;

  @override
  Color get inputFieldColor => const Color(0xFFF2F2F2);

  @override
  BorderRadius get inputFieldBorderRadius => BorderRadius.circular(20);

  @override
  Widget buildSendButton({required VoidCallback onPressed, required Color color}) {
    return IconButton(
      icon: const Icon(Icons.send_rounded, color: Color(0xFF24A1DE), size: 28),
      onPressed: onPressed,
    );
  }

  @override
  Color get statusIconColor => const Color(0xFFa0b2c3);

  @override
  Color get readStatusColor => const Color(0xFF24A1DE);
}
