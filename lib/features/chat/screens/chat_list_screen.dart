/*
 * chat_list_screen.dart (已升級版)
 * 
 * 從靜態假資料升級為動態讀取聯絡人資料庫 (contactsBox)。
 * 包含「空狀態」頁面，並接入底部導覽至 ContactsScreen/ProfileScreen。
 * 
 * Upgraded from static mock data to dynamically loading from contactsBox.
 * Includes an "empty state" view and bottom nav to Contacts/Profile screens.
 */
import 'package:flutter/material.dart';
import '../../../core/identity/identity_manager.dart';
import '../../../core/models/contact.dart';
import '../../../core/storage/database_service.dart';
import '../../../ui/skins/skin_service.dart';
import '../../chat/services/invitation_service.dart';
import '../../contacts/screens/contacts_screen.dart';
import '../../settings/screens/settings_screen.dart';
import 'chat_room_screen.dart';
import 'invitation_screen.dart';
import 'scanner_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  int _selectedIndex = 1; // 預設選中「聊天」tab (Default to Chat tab)
  List<Contact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  /*
   * 從資料庫加載聯絡人並依最後訊息時間排序
   * Load contacts from DB, sorted by last message timestamp.
   */
  void _loadContacts() {
    final list = DatabaseService.contactsBox.values.toList();
    // 排序：有最後訊息的排前面，再依時間降冪 (Sort by lastMessageAt descending)
    list.sort((a, b) {
      if (a.lastMessageAt == null && b.lastMessageAt == null) return 0;
      if (a.lastMessageAt == null) return 1;
      if (b.lastMessageAt == null) return -1;
      return b.lastMessageAt!.compareTo(a.lastMessageAt!);
    });
    setState(() => _contacts = list);
  }

  /*
   * 底部 Tab 切換 (Bottom tab navigation)
   */
  void _onTabSelected(int index) {
    if (index == 0) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactsScreen()))
          .then((_) => _loadContacts()); // 返回後刷新列表
    } else if (index == 4) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  /*
   * 格式化最後訊息時間顯示 (Format last message time for display)
   */
  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(dt).inDays == 1) {
      return '昨天';
    }
    return '${dt.month}/${dt.day}';
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
            title: Text('聊天 (Chats)', style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: skin.appBarBackgroundColor,
            foregroundColor: skin.appBarForegroundColor,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: skin.dividerColor, height: 1),
            ),
            actions: [
              /* 掃描 QR Code (Scan QR code) */
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen())),
              ),
              /* 顯示我的邀請碼 (Show my invitation code) */
              IconButton(
                icon: const Icon(Icons.link),
                onPressed: () async {
                  final idManager = IdentityManager();
                  await idManager.generateIdentityKeys();
                  final bundle = await InvitationService(idManager).generateInvitationBundle();
                  if (context.mounted) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => InvitationScreen(
                        invitationLink: bundle['fullLink']!,
                        shortCode: bundle['shortCode']!,
                      ),
                    ));
                  }
                },
              ),
              IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
            ],
          ),

          body: _contacts.isEmpty
              /* ── 空狀態頁面 (Empty state) ── */
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[200]),
                      const SizedBox(height: 16),
                      Text('還沒有對話', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey[400])),
                      const SizedBox(height: 8),
                      Text('前往「聯絡人」添加對方以開始安全通訊', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ContactsScreen()),
                        ).then((_) => _loadContacts()),
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text('前往聯絡人 (Go to Contacts)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.black),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                )

              /* ── 聯絡人聊天列表 (Contact chat list) ── */
              : ListView.separated(
                  itemCount: _contacts.length,
                  separatorBuilder: (_, __) => Divider(height: 1, indent: 80, color: skin.dividerColor),
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey[200],
                        child: Text(
                          contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black54),
                        ),
                      ),
                      title: Text(contact.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        contact.lastMessagePreview.isNotEmpty ? contact.lastMessagePreview : '點此開始安全對話',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_formatTime(contact.lastMessageAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          if (contact.unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: skin.unreadBadgeColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                contact.unreadCount > 99 ? '99+' : '${contact.unreadCount}',
                                style: TextStyle(color: skin.unreadBadgeTextColor, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChatRoomScreen(userName: contact.displayName)),
                        ).then((_) => _loadContacts());
                      },
                    );
                  },
                ),

          /* ── 底部導覽列 (Bottom Navigation Bar) ── */
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            selectedItemColor: skin.tabBarSelectedColor,
            unselectedItemColor: skin.tabBarUnselectedColor,
            currentIndex: _selectedIndex,
            onTap: _onTabSelected,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.people_outlined), label: '聯絡人'),
              BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: '聊天'),
              BottomNavigationBarItem(icon: Icon(Icons.video_call_outlined), label: '貼文串'),
              BottomNavigationBarItem(icon: Icon(Icons.newspaper_outlined), label: 'TODAY'),
              BottomNavigationBarItem(icon: Icon(Icons.account_circle_outlined), label: '我'),
            ],
          ),
        );
      },
    );
  }
}
