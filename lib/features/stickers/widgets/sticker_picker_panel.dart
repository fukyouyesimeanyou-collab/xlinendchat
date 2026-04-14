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
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: stickers.length,
        itemBuilder: (context, index) {
          final sticker = stickers[index];
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
      ),
    );
  }
}
