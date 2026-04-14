import 'dart:io';
import 'package:flutter/material.dart';
import '../services/sticker_service.dart';
import '../../../core/models/sticker.dart';
import '../../../ui/skins/skin_service.dart';

class StickerManagerScreen extends StatefulWidget {
  const StickerManagerScreen({super.key});

  @override
  State<StickerManagerScreen> createState() => _StickerManagerScreenState();
}

class _StickerManagerScreenState extends State<StickerManagerScreen> {
  final StickerService _service = StickerService();
  List<Sticker> _stickers = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadStickers();
  }

  void _loadStickers() {
    setState(() {
      _stickers = _service.getAllStickers();
    });
  }

  Future<void> _addSticker() async {
    setState(() => _loading = true);
    final result = await _service.pickAndAddSticker();
    setState(() => _loading = false);
    
    if (result != null) {
      _loadStickers();
    }
  }

  Future<void> _deleteSticker(String id) async {
    await _service.deleteSticker(id);
    _loadStickers();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SkinService(),
      builder: (context, _) {
        final skin = SkinService().currentSkin;

        return Scaffold(
          backgroundColor: skin.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('貼圖管理 (Stickers)'),
            backgroundColor: skin.appBarBackgroundColor,
            foregroundColor: skin.appBarForegroundColor,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_photo_alternate_outlined),
                onPressed: _addSticker,
              ),
            ],
          ),
          body: _loading 
            ? const Center(child: CircularProgressIndicator())
            : _stickers.isEmpty
              ? _buildEmptyState(skin)
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _stickers.length,
                  itemBuilder: (context, index) {
                    final sticker = _stickers[index];
                    return _buildStickerTile(sticker);
                  },
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(dynamic skin) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sticky_note_2_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('尚無貼圖', style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('點擊右上角新增您的自定義貼圖', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addSticker,
            icon: const Icon(Icons.add),
            label: const Text('新增貼圖'),
            style: ElevatedButton.styleFrom(
              backgroundColor: skin.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerTile(Sticker sticker) {
    return FutureBuilder<String>(
      future: _service.getStickerAbsolutePath(sticker.fileName),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Container(color: Colors.grey[100]);
        
        return Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(snapshot.data!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: GestureDetector(
                onTap: () => _deleteSticker(sticker.id),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
