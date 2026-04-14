import 'package:flutter/material.dart';
import '../../../ui/skins/skin_service.dart';
import '../../../ui/skins/skin_specification.dart';

class SkinGalleryScreen extends StatelessWidget {
  const SkinGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SkinService(),
      builder: (context, _) {
        final currentSkin = SkinService().currentSkin;
        final allSkins = SkinService().allSkins;

        return Scaffold(
          backgroundColor: currentSkin.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('皮膚外觀 (Skins)'),
            backgroundColor: currentSkin.appBarBackgroundColor,
            foregroundColor: currentSkin.appBarForegroundColor,
            elevation: 0,
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: allSkins.length,
            itemBuilder: (context, index) {
              final skin = allSkins[index];
              final isSelected = skin.name == currentSkin.name;

              return _buildSkinCard(context, skin, isSelected);
            },
          ),
        );
      },
    );
  }

  Widget _buildSkinCard(BuildContext context, AppSkin skin, bool isSelected) {
    return GestureDetector(
      onTap: () => SkinService().setSkin(skin),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isSelected 
            ? Border.all(color: skin.primaryColor, width: 3) 
            : Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 預覽頂部 (AppBar Preview)
            Container(
              height: 50,
              color: skin.appBarBackgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.menu, color: skin.appBarForegroundColor, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    skin.name,
                    style: TextStyle(
                      color: skin.appBarForegroundColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Icon(Icons.check_circle, color: skin.appBarForegroundColor),
                ],
              ),
            ),
            // 預覽內容 (Content Preview)
            Container(
              height: 100,
              color: skin.chatBackgroundColor,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildMockBubble(skin, "這是 ${skin.name} 風格的訊息", isMe: false),
                  const SizedBox(height: 8),
                  _buildMockBubble(skin, "完美還原操作感！", isMe: true),
                ],
              ),
            ),
            // 底部描述
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    '${skin.name} 風格介面',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  Text(
                    isSelected ? '目前套用中' : '點擊切換',
                    style: TextStyle(
                      color: isSelected ? skin.primaryColor : Colors.grey,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockBubble(AppSkin skin, String text, {required bool isMe}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isMe ? skin.myBubbleColor : skin.otherBubbleColor,
          borderRadius: skin.getBubbleBorderRadius(isMe),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: isMe ? skin.myTextColor : skin.otherTextColor,
          ),
        ),
      ),
    );
  }
}
