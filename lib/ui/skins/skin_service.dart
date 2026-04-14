import 'package:flutter/material.dart';
import 'skin_specification.dart';
import 'line_skin.dart';
import 'whatsapp_skin.dart';
import 'telegram_skin.dart';
import '../storage/database_service.dart';

/*
 * SkinService 類別：
 * 管理全域皮膚狀態，負責切換與持久化。
 * 
 * SkinService class:
 * Manages global skin state, handles switching and persistence.
 */
class SkinService extends ChangeNotifier {
  static final SkinService _instance = SkinService._internal();
  factory SkinService() => _instance;
  SkinService._internal();

  AppSkin _currentSkin = LineSkin();
  AppSkin get currentSkin => _currentSkin;

  // 切換皮膚 (Switch Skin)
  void setSkin(AppSkin newSkin) {
    if (_currentSkin.name == newSkin.name) return;
    _currentSkin = newSkin;
    notifyListeners();
    _persistSkin(newSkin.name);
  }

  // 將選擇存入 Hive (Persist to Hive)
  void _persistSkin(String skinName) async {
    await DatabaseService.vaultBox.put('active_skin_name', skinName);
  }

  // 從 Hive 恢復 (Restore from Hive)
  void loadPersistedSkin() {
    final name = DatabaseService.vaultBox.get('active_skin_name', defaultValue: 'LINE');
    _currentSkin = _getSkinByName(name);
    notifyListeners();
  }

  AppSkin _getSkinByName(String name) {
    switch (name) {
      case 'WhatsApp':
        return WhatsAppSkin();
      case 'Telegram':
        return TelegramSkin();
      case 'LINE':
      default:
        return LineSkin();
    }
  }

  List<AppSkin> get allSkins => [
    LineSkin(),
    WhatsAppSkin(),
    TelegramSkin(),
  ];
}
