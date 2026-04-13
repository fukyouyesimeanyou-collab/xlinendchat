/*
 * contacts_screen.dart
 * 
 * 聯絡人管理頁面：顯示、添加、刪除 P2P 聯絡人。
 * Contacts management screen: display, add, and delete P2P contacts.
 */
import 'package:flutter/material.dart';
import '../../../core/models/contact.dart';
import '../../../core/storage/database_service.dart';
import '../../../ui/theme/line_colors.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  /*
   * 從 Hive 加密資料庫載入聯絡人 (Load contacts from encrypted Hive box)
   */
  void _loadContacts() {
    setState(() {
      _contacts = DatabaseService.contactsBox.values.toList();
    });
  }

  /*
   * 顯示添加聯絡人的對話框 (Show the add-contact dialog)
   */
  void _showAddContactDialog() {
    final nameController = TextEditingController();
    final keyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('新增聯絡人 (Add Contact)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /* 備注名稱輸入欄 (Display name input) */
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '備注名稱 (Display Name)',
                hintText: '輸入對方的名稱',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            /* 公鑰輸入欄 (Public key input) */
            TextField(
              controller: keyController,
              decoration: const InputDecoration(
                labelText: '連線代碼 / 公鑰 (Key / Code)',
                hintText: '貼上對方分享的代碼',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消 (Cancel)', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty || keyController.text.trim().isEmpty) return;

              /* 建立新的聯絡人物件並存入加密 Hive (Create new contact and persist) */
              final newContact = Contact(
                displayName: nameController.text.trim(),
                publicKeyBase64: keyController.text.trim(),
                addedAt: DateTime.now(),
                status: ContactStatus.pending,
              );
              await DatabaseService.contactsBox.add(newContact);
              
              if (context.mounted) {
                Navigator.pop(context);
                _loadContacts();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: LineColors.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('新增 (Add)'),
          ),
        ],
      ),
    );
  }

  /*
   * 刪除聯絡人 (Delete a contact with confirmation)
   */
  void _confirmDelete(Contact contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('刪除聯絡人？(Delete Contact?)'),
        content: Text('此操作將永久刪除「${contact.displayName}」。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              await contact.delete(); // HiveObject 直接刪除
              if (ctx.mounted) Navigator.pop(ctx);
              _loadContacts();
            },
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 狀態對應的圖標與顏色 (Map status to icon and color)
  Widget _buildStatusIcon(ContactStatus status) {
    switch (status) {
      case ContactStatus.active:
        return Container(
          width: 12, height: 12,
          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
        );
      case ContactStatus.connecting:
        return Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: Colors.orange[400], shape: BoxShape.circle),
        );
      case ContactStatus.pending:
        return Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey[400]!, width: 1.5),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('聯絡人 (Contacts)', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[200], height: 1),
        ),
      ),

      /* 空狀態 vs 聯絡人列表 (Empty state vs contacts list) */
      body: _contacts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 72, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('尚無聯絡人', style: TextStyle(fontSize: 18, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text('點擊右下角按鈕以添加', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                ],
              ),
            )
          : ListView.separated(
              itemCount: _contacts.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                return ListTile(
                  /* 頭像圓框 + 狀態指示點 (Avatar with status dot) */
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[200],
                        child: Text(
                          contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black54),
                        ),
                      ),
                      Positioned(
                        right: 0, bottom: 0,
                        child: _buildStatusIcon(contact.status),
                      ),
                    ],
                  ),
                  title: Text(contact.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    contact.shortFingerprint,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: 'monospace'),
                  ),
                  trailing: Text(
                    contact.status == ContactStatus.active ? '連線中' :
                    contact.status == ContactStatus.connecting ? '建立中' : '待連線',
                    style: TextStyle(
                      fontSize: 12,
                      color: contact.status == ContactStatus.active ? Colors.green :
                             contact.status == ContactStatus.connecting ? Colors.orange : Colors.grey,
                    ),
                  ),
                  /* 長壓顯示刪除選項 (Long-press for delete) */
                  onLongPress: () => _confirmDelete(contact),
                );
              },
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        backgroundColor: LineColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.person_add_outlined),
      ),
    );
  }
}
