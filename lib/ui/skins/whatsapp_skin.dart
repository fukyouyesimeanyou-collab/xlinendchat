import 'package:flutter/material.dart';
import 'skin_specification.dart';

class WhatsAppSkin extends AppSkin {
  @override
  String get name => 'WhatsApp';

  @override
  Color get scaffoldBackgroundColor => const Color(0xFFF0F2F5);

  @override
  Color get appBarBackgroundColor => const Color(0xFF075E54);

  @override
  Color get appBarForegroundColor => Colors.white;

  @override
  Color get primaryColor => const Color(0xFF25D366);

  @override
  Color get chatBackgroundColor => const Color(0xFFE5DDD5);

  @override
  Color get unreadBadgeColor => const Color(0xFF25D366);

  @override
  Color get unreadBadgeTextColor => Colors.white;

  @override
  Color get dividerColor => const Color(0xFFE1E1E1);

  @override
  Color get tabBarSelectedColor => const Color(0xFF075E54);

  @override
  Color get tabBarUnselectedColor => Colors.grey;

  @override
  Color get myBubbleColor => const Color(0xFFDCF8C6);

  @override
  Color get otherBubbleColor => Colors.white;

  @override
  Color get myTextColor => Colors.black87;

  @override
  Color get otherTextColor => Colors.black87;

  @override
  BorderRadius getBubbleBorderRadius(bool isMe) {
    return BorderRadius.only(
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
      bottomRight: isMe ? Radius.zero : const Radius.circular(12),
    );
  }

  @override
  Color get inputBarColor => const Color(0xFFF0F0F0);

  @override
  Color get inputFieldColor => Colors.white;

  @override
  BorderRadius get inputFieldBorderRadius => BorderRadius.circular(24);

  @override
  Widget buildSendButton({required VoidCallback onPressed, required Color color}) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF075E54),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.send, color: Colors.white, size: 20),
        onPressed: onPressed,
      ),
    );
  }

  @override
  Color get statusIconColor => Colors.grey;

  @override
  Color get readStatusColor => const Color(0xFF34B7F1);
}
