import 'package:flutter/material.dart';
import '../../profile/screens/profile_screen.dart';
import 'security_settings_screen.dart';
import 'lifecycle_settings_screen.dart';
import 'skin_gallery_screen.dart';
import '../../stickers/screens/sticker_manager_screen.dart';
import '../../../ui/skins/skin_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SkinService(),
      builder: (context, _) {
        final skin = SkinService().currentSkin;
        
        return Scaffold(
          backgroundColor: skin.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('設定 (Settings)', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: skin.appBarBackgroundColor,
            foregroundColor: skin.appBarForegroundColor,
            elevation: 0,
          ),
          body: ListView(
            children: [
              _buildSectionHeader('帳號與資料'),
              _buildListTile(
                context,
                icon: Icons.person_outline,
                title: '個人資料 (Profile)',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
              ),
              _buildSectionHeader('隱私與安全'),
              _buildListTile(
                context,
                icon: Icons.security_outlined,
                title: '安全設定 (Security)',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecuritySettingsScreen())),
              ),
              _buildListTile(
                context,
                icon: Icons.timer_outlined,
                title: '生命週期管理 (Lifecycle)',
                subtitle: '閱後即焚與暫存區配額',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LifecycleSettingsScreen())),
              ),
              _buildSectionHeader('介面自定義'),
              _buildListTile(
                context,
                icon: Icons.palette_outlined,
                title: '皮膚與外觀 (Skins)',
                subtitle: '切換 LINE / WhatsApp / Telegram 風格',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SkinGalleryScreen())),
              ),
              _buildSectionHeader('多媒體與素材'),
              _buildListTile(
                context,
                icon: Icons.sticky_note_2_outlined,
                title: '貼圖庫管理 (Stickers)',
                subtitle: '建立與管理您的自定義 WebP 貼圖',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StickerManagerScreen())),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, {required IconData icon, required String title, String? subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
