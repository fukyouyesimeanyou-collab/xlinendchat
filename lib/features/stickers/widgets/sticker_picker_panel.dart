import 'dart:io';
import 'package:flutter/material.dart';
import '../services/sticker_service.dart';
import '../../../core/models/sticker.dart';

class StickerPickerPanel extends StatelessWidget {
  final Function(Sticker) onStickerSelected;

  const StickerPickerPanel({
    super.key,
    required this.onStickerSelected,
  });

  @override
  Widget build(BuildContext context) {
    final service = StickerService();
    final stickers = service.getAllStickers();

    if (stickers.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text('尚無貼圖 (No Stickers)', style: TextStyle(color: Colors.grey)),
      );
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      child: StatefulBuilder(
        builder: (context, setPanelState) {
          final currentStickers = service.getAllStickers();
          
          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: currentStickers.length + 1, // +1 for the "Add" button
            itemBuilder: (context, index) {
              if (index == 0) {
                // 添加按鈕 (Add Button)
                return InkWell(
                  onTap: () async {
                    final newSticker = await service.pickAndAddSticker();
                    if (newSticker != null) {
                      setPanelState(() {}); // Refresh panel
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.add_photo_alternate_outlined, color: Colors.grey[400]),
                  ),
                );
              }

              final sticker = currentStickers[index - 1];
              return FutureBuilder<String>(
                future: service.getStickerAbsolutePath(sticker.fileName),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Container(color: Colors.grey[100]);
                  
                  return InkWell(
                    onTap: () => onStickerSelected(sticker),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(
                        File(snapshot.data!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              );
            },
          );
        }
      ),
    );
  }
}
