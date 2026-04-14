import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/storage/database_service.dart';
import '../../../ui/skins/skin_service.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  double _barDurationHours = 24.0;
  bool _screenshotNotifyEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final savedHours = DatabaseService.vaultBox.get('bar_default_duration_hours', defaultValue: 24.0);
    final savedScreenshot = DatabaseService.vaultBox.get('screenshot_notify_enabled', defaultValue: false);
    
    setState(() {
      _barDurationHours = (savedHours as num).toDouble();
      _screenshotNotifyEnabled = savedScreenshot as bool;
    });
  }

  Future<void> _saveBarSettings(double value) async {
    setState(() => _barDurationHours = value);
    await DatabaseService.vaultBox.put('bar_default_duration_hours', value);
  }

  Future<void> _toggleScreenshotNotify(bool value) async {
    if (value) {
      // 請求權限 (Request permissions)
      final status = await Permission.photos.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要媒體庫權限以偵測截圖操作 (Requires media permission to detect screenshots)')),
          );
        }
        return;
      }
    }
    
    setState(() => _screenshotNotifyEnabled = value);
    await DatabaseService.vaultBox.put('screenshot_notify_enabled', value);
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
            title: const Text('安全設定 (Security)'),
            backgroundColor: skin.appBarBackgroundColor,
            foregroundColor: skin.appBarForegroundColor,
            elevation: 0,
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '閱後即焚 (BAR) 全域時限',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '設定開啟 BAR 模式後的對話續航時間。時間一到，雙方對話紀錄將自動銷毀。',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    '${_barDurationHours.toInt()} 小時',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: skin.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Slider(
                  value: _barDurationHours,
                  min: 1,
                  max: 24,
                  divisions: 23,
                  activeColor: skin.primaryColor,
                  label: '${_barDurationHours.toInt()} 小時',
                  onChanged: _saveBarSettings,
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1 小時', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('24 小時 (最高限制)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 48),
                const Divider(),
                const SizedBox(height: 24),
                const Text(
                  '截圖偵測通知 (Beta)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('開啟偵測通知', style: TextStyle(fontSize: 15)),
                  subtitle: const Text('偵測到對方截圖時立即通知並詢問是否銷毀對話。', style: TextStyle(fontSize: 12)),
                  value: _screenshotNotifyEnabled,
                  activeColor: skin.primaryColor,
                  onChanged: _toggleScreenshotNotify,
                  contentPadding: EdgeInsets.zero,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[100]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red[400]),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '注意：BAR 倒數計時將在 App 背景或關閉時持續執行。',
                          style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
