import 'package:flutter/material.dart';

/*
 * AppSkin 抽象類別：
 * 定義所有皮膚必須提供的視覺規範。透過此介面，後端邏輯與前端樣式得以徹底解耦。
 * 
 * AppSkin abstract class:
 * Defines visual specifications that all skins must provide. 
 * Decouples backend logic from frontend styles.
 */
abstract class AppSkin {
  String get name;

  // 1. 全局配色 (Global Colors)
  Color get scaffoldBackgroundColor;
  Color get appBarBackgroundColor;
  Color get appBarForegroundColor;
  Color get primaryColor;

  // 2. 聊天室背景 (Chat Room Background)
  Color get chatBackgroundColor;

  // 3. 訊息列表規範 (Message List Specs)
  Color get unreadBadgeColor;
  Color get unreadBadgeTextColor;
  Color get dividerColor;

  // 4. 底部導覽規範 (Bottom Navigation Specs)
  Color get tabBarSelectedColor;
  Color get tabBarUnselectedColor;

  // 5. 訊息氣泡規範 (Message Bubble Specs)
  Color get myBubbleColor;
  Color get otherBubbleColor;
  Color get myTextColor;
  Color get otherTextColor;
  BorderRadius getBubbleBorderRadius(bool isMe);

  // 4. 輸入欄規範 (Input Bar Specs)
  Color get inputBarColor;
  Color get inputFieldColor;
  BorderRadius get inputFieldBorderRadius;
  Widget buildSendButton({required VoidCallback onPressed, required Color color});

  // 5. 狀態圖標規範 (Status Icon Specs)
  Color get statusIconColor;
  Color get readStatusColor;
}
