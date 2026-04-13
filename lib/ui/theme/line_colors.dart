/* 
 * 引入 Flutter 的 Material Design 庫，以獲得 Color 類別。
 * Imports the Flutter Material Design library to access the Color class.
 */
import 'package:flutter/material.dart';

/* 
 * LineColors 類別：
 * 集中管理整個應用的色彩配置。這樣的設計（稱為 Design System Tokens）
 * 讓我們在需要更換色調時，只需要修改這個檔案，而不必翻遍整個專案。
 * 
 * LineColors class:
 * Centrally manages the color configuration for the entire application. 
 * This design (known as Design System Tokens) allows us to change the app's 
 * theme by modifying just this file instead of searching through the entire project.
 */
class LineColors {
  /* 
   * LINE 標誌性的綠色。
   * The iconic LINE green color.
   */
  static const Color primaryGreen = Color(0xFF06C755);
  
  /* 
   * 較深一點的綠色，通常用於點擊效果或重點區域。
   * A darker shade of LINE green, typically used for press states or highlights.
   */
  static const Color darkGreen = Color(0xFF05B04A);
  
  /* 
   * 聊天室經典的灰藍色背景。
   * The classic LINE blue-ish grey background color for chat rooms.
   */
  static const Color chatBackground = Color(0xFF7494C0);
  
  /* 
   * 發送者（我）的對話氣泡顏色。
   * The message bubble color for the sender (me).
   */
  static const Color myBubble = Color(0xFFA9E38A);
  
  /* 
   * 接收者（別人）的對話氣泡顏色。
   * The message bubble color for others.
   */
  static const Color otherBubble = Color(0xFFFFFFFF);
  
  /* 
   * 標準的應用程式背景色（純白）。
   * Standard light background color (pure white).
   */
  static const Color background = Color(0xFFFFFFFF);
  
  /* 
   * 標示文字與邊線的灰色。
   * Grey colors used for secondary text and borders.
   */
  static const Color greyText = Color(0xFF8E8E93);
  static const Color border = Color(0xFFE5E5EA);
}
