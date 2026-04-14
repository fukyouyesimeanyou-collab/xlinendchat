import 'package:flutter/material.dart';
import '../../../core/storage/storage_service.dart';

class LifecycleSettingsScreen extends StatefulWidget {
  const LifecycleSettingsScreen({super.key});

  @override
  State<LifecycleSettingsScreen> createState() => _LifecycleSettingsScreenState();
}

class _LifecycleSettingsScreenState extends State<LifecycleSettingsScreen> {
  bool _barEnabled = true;
  double _quotaMB = 1024.0;
  double _freeSpaceMB = 0;
  double _totalSpaceMB = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final free = await StorageService.getFreeSpace();
    final total = await StorageService.getTotalSpace();
    setState(() {
      _barEnabled = StorageService.isBarEnabled();
      _quotaMB = StorageService.getStorageQuota();
      _freeSpaceMB = free;
      _totalSpaceMB = total;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('生命週期與存儲 (Lifecycle)'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(),
          const SizedBox(height: 24),
          _buildBarSection(),
          const SizedBox(height: 24),
          _buildQuotaSection(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 0,
      color: Colors.blue.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.blue),
                SizedBox(width: 8),
                Text('隱私守則 (Privacy Rules)', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '• 所有檔案均以純 P2P 傳送，不經過任何伺服器。\n'
              '• 離線時無法傳送大檔案，確保實時在線安全。\n'
              '• 超過 24 小時未導出的檔案將自動粉碎。',
              style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('自動銷毀設定', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('全局閱後即焚 (Global BAR)'),
          subtitle: const Text('對所有對話預設啟動 24 小時讀後自動粉碎機制'),
          value: _barEnabled,
          activeColor: Colors.redAccent,
          onChanged: (val) async {
            await StorageService.setBarEnabled(val);
            setState(() => _barEnabled = val);
          },
        ),
      ],
    );
  }

  Widget _buildQuotaSection() {
    final usedPercent = (_quotaMB / _totalSpaceMB * 100).toStringAsFixed(1);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('磁碟配額管理 (Storage Quota)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('當前配額: ${(_quotaMB / 1024).toStringAsFixed(1)} GB', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('佔總空間 $usedPercent%', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        Slider(
          value: _quotaMB,
          min: 100, // 最小 100MB
          max: _totalSpaceMB > 10240 ? 10240 : _totalSpaceMB, // 最大 10GB 或總空間
          divisions: 100,
          label: '${(_quotaMB / 1024).toStringAsFixed(1)} GB',
          onChanged: (val) {
            setState(() => _quotaMB = val);
          },
          onChangeEnd: (val) async {
            await StorageService.setStorageQuota(val);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('100MB', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('可用剩餘: ${(_freeSpaceMB / 1024).toStringAsFixed(1)} GB', style: TextStyle(fontSize: 10, color: Colors.blue)),
              Text('10GB', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}
