/*
 * profile_screen.dart
 * 
 * 個人資料頁面：顯示本機公鑰指紋、設定顯示名稱，以及連結到邀請介面。
 * Profile screen: displays local public key fingerprint, lets user set display name,
 * and provides a link to the Invitation screen.
 */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/identity/identity_manager.dart';
import '../../../core/storage/database_service.dart';
import '../../chat/screens/invitation_screen.dart';
import '../../chat/services/invitation_service.dart';
import '../../../ui/theme/line_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final IdentityManager _identityManager = IdentityManager();
  final TextEditingController _nameController = TextEditingController();
  String? _publicKeyBase64;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    /* 從加密 Vault 或生成新的身分金鑰 (Load or generate identity) */
    await _identityManager.generateIdentityKeys();

    /* 從 settings box 讀取顯示名稱 (Read display name from settings box) */
    final savedName = DatabaseService.vaultBox.get('profile_display_name', defaultValue: '');

    setState(() {
      _publicKeyBase64 = _identityManager.identityPublicKey;
      _nameController.text = savedName as String;
      _isLoading = false;
    });
  }

  Future<void> _saveName() async {
    setState(() => _isSaving = true);
    await DatabaseService.vaultBox.put('profile_display_name', _nameController.text.trim());
    setState(() => _isSaving = false);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('名稱已儲存 (Name saved)'),
          backgroundColor: Colors.black87,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /*
   * 取得公鑰的簡短指紋顯示 (Compute short fingerprint for display)
   */
  String get _shortFingerprint {
    if (_publicKeyBase64 == null || _publicKeyBase64!.length < 16) return '—';
    final key = _publicKeyBase64!;
    return '${key.substring(0, 8)} ... ${key.substring(key.length - 8)}';
  }

  /*
   * 複製完整公鑰到剪貼簿 (Copy full public key to clipboard)
   */
  void _copyKey() {
    if (_publicKeyBase64 == null) return;
    Clipboard.setData(ClipboardData(text: _publicKeyBase64!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('公鑰已複製 (Public key copied)'),
        backgroundColor: Colors.black87,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('我的資料 (My Profile)', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[200], height: 1),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /* 頭像區域 (Avatar area) */
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.grey[200],
                    child: Text(
                      _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black54),
                    ),
                  ),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: LineColors.primaryGreen,
                    child: const Icon(Icons.edit, size: 16, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            /* 顯示名稱設定 (Display name setting) */
            const Text('顯示名稱 (Display Name)', style: TextStyle(fontSize: 12, color: Colors.grey, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: '輸入您的顯示名稱',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    onSubmitted: (_) => _saveName(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveName,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('儲存'),
                ),
              ],
            ),
            const SizedBox(height: 32),

            /* 公鑰指紋顯示 (Public key fingerprint) */
            const Text('我的身分公鑰 (My Identity Key)', style: TextStyle(fontSize: 12, color: Colors.grey, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey[50],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _shortFingerprint,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14, letterSpacing: 1),
                    ),
                  ),
                  GestureDetector(
                    onTap: _copyKey,
                    child: Icon(Icons.copy_outlined, size: 20, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '這是您唯一的端到端加密身分識別碼。分享給對方以建立安全連線。',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
            const SizedBox(height: 40),

            /* 邀請連結按鈕 (Invitation link button) */
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final inviteService = InvitationService(_identityManager);
                  final bundle = await inviteService.generateInvitationBundle();

                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InvitationScreen(
                          invitationLink: bundle['fullLink']!,
                          shortCode: bundle['shortCode']!,
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.share_outlined),
                label: const Text('產生連線邀請碼 (Generate Invite)', style: TextStyle(fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
