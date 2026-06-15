import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class AdminUserProfilePage extends StatefulWidget {
  const AdminUserProfilePage({super.key, required this.user});
  final AdminUserEntry user;

  @override
  State<AdminUserProfilePage> createState() => _AdminUserProfilePageState();
}

class _AdminUserProfilePageState extends State<AdminUserProfilePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _searches = const [];
  List<Map<String, dynamic>> _payments = const [];
  List<Map<String, dynamic>> _chats = const [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadActivity();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadActivity() async {
    if (widget.user.id.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'This prototype account is not linked to backend data.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await apiClient.getJson(
        '/api/admin/accounts/${widget.user.id}/activity',
      );
      if (!mounted) return;
      setState(() {
        _searches = (data['searches'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();
        _payments = (data['payments'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();
        _chats = (data['chats'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openChat(Map<String, dynamic> room) async {
    final roomId = room['roomId']?.toString();
    if (roomId == null || roomId.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AdminChatSheet(roomId: roomId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? bgDark : bgLight,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF131926) : Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.user.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadActivity,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _Header(user: widget.user),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorPadding: const EdgeInsets.all(4),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: muted,
              labelStyle: const TextStyle(fontWeight: FontWeight.w900),
              tabs: const [
                Tab(text: 'Searches'),
                Tab(text: 'Payments'),
                Tab(text: 'Chats'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const PageSkeleton(cardCount: 5)
                : _error != null
                ? _EmptyPanel(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load account activity',
                    subtitle: _error!,
                  )
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _SearchList(searches: _searches),
                      _PaymentList(payments: _payments),
                      _ChatList(chats: _chats, onOpen: _openChat),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});
  final AdminUserEntry user;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: shadowSm,
      ),
      child: Row(
        children: [
          Stack(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: ClipOval(
                  child: ProductImageView(
                    imageUrl: user.profilePic,
                    fallbackIcon: Icons.person,
                    fallbackColor: primary,
                  ),
                ),
              ),
              if (user.isOnline)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  user.phone.isEmpty ? 'No phone saved' : user.phone,
                  style: const TextStyle(color: muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                user.spend,
                style: const TextStyle(
                  color: success,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const Text(
                'Spend',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchList extends StatelessWidget {
  const _SearchList({required this.searches});
  final List<Map<String, dynamic>> searches;

  @override
  Widget build(BuildContext context) {
    if (searches.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.search_off_outlined,
        title: 'No search history yet',
        subtitle: 'New product and shop searches will appear here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: searches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final search = searches[index];
        return _ActivityTile(
          icon: Icons.search,
          title: search['query']?.toString() ?? 'Search',
          subtitle: '${search['surface'] ?? 'search'} - ${_formatDate(search['createdAt'])}',
        );
      },
    );
  }
}

class _PaymentList extends StatelessWidget {
  const _PaymentList({required this.payments});
  final List<Map<String, dynamic>> payments;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.receipt_long_outlined,
        title: 'No payments yet',
        subtitle: 'Gateway and offline scan payments will appear here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: payments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final payment = payments[index];
        final cents = payment['grossCents'] as int? ?? 0;
        return _ActivityTile(
          icon: Icons.account_balance_wallet_outlined,
          title: _formatRupees(cents),
          subtitle:
              '${payment['shopName'] ?? 'Shop'} - ${payment['status'] ?? 'payment'} - ${_formatDate(payment['createdAt'])}',
        );
      },
    );
  }
}

class _ChatList extends StatelessWidget {
  const _ChatList({required this.chats, required this.onOpen});
  final List<Map<String, dynamic>> chats;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    if (chats.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.forum_outlined,
        title: 'No chats yet',
        subtitle: 'User and seller conversations will appear here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: chats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final chat = chats[index];
        return _ActivityTile(
          icon: Icons.chat_bubble_outline,
          imageUrl: chat['avatarUrl']?.toString(),
          title: chat['title']?.toString() ?? 'Chat',
          subtitle:
              '${chat['lastMessage'] ?? 'Message'} - ${_formatDate(chat['updatedAt'])}',
          trailing: const Icon(Icons.chevron_right, color: muted),
          onTap: () => onOpen(chat),
        );
      },
    );
  }
}

class AdminChatSheet extends StatefulWidget {
  const AdminChatSheet({super.key, required this.roomId});
  final String roomId;

  @override
  State<AdminChatSheet> createState() => _AdminChatSheetState();
}

class _AdminChatSheetState extends State<AdminChatSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _room;
  List<Map<String, dynamic>> _messages = const [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final encoded = Uri.encodeComponent(widget.roomId);
      final data = await apiClient.getJson('/api/admin/chats/$encoded/messages');
      if (!mounted) return;
      setState(() {
        _room = Map<String, dynamic>.from(data['room'] as Map? ?? {});
        _messages = (data['messages'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      maxChildSize: 0.96,
      builder: (context, scrollController) => Container(
        color: bgLight,
        child: Column(
          children: [
            _AdminChatHeader(
              room: _room,
              roomId: widget.roomId,
              onRefresh: _loadMessages,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _EmptyPanel(
                      icon: Icons.cloud_off_outlined,
                      title: 'Could not load chat',
                      subtitle: _error!,
                    )
                  : _messages.isEmpty
                  ? const _EmptyPanel(
                      icon: Icons.forum_outlined,
                      title: 'No messages in this room',
                      subtitle: 'Messages will appear here when users chat.',
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                      itemCount: _messages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _AdminChatBubble(message: _messages[index]);
                      },
                    ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: const Text(
                'Admin audit view only. Calls, video, and message sending are disabled.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminChatHeader extends StatelessWidget {
  const _AdminChatHeader({
    required this.room,
    required this.roomId,
    required this.onRefresh,
  });

  final Map<String, dynamic>? room;
  final String roomId;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final participants = (room?['participants'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList();
    final primaryParticipant = participants.isNotEmpty
        ? participants.first
        : <String, dynamic>{};
    final title = room?['title']?.toString().trim().isNotEmpty == true
        ? room!['title'].toString()
        : roomId;
    final subtitle = participants.isEmpty
        ? 'Backend chat audit'
        : participants
            .map((participant) => participant['role']?.toString() ?? 'account')
            .toSet()
            .join(' + ');

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: shadowSm,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: ink),
            ),
            Stack(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: ClipOval(
                    child: ProductImageView(
                      imageUrl: primaryParticipant['avatarUrl']?.toString(),
                      fallbackIcon: Icons.forum_outlined,
                      fallbackColor: primary,
                    ),
                  ),
                ),
                if (primaryParticipant['isOnline'] == true)
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, color: ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminChatBubble extends StatelessWidget {
  const _AdminChatBubble({required this.message});

  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final sender = Map<String, dynamic>.from(message['sender'] as Map? ?? {});
    final role = sender['role']?.toString() ?? 'account';
    final deleted = message['deletedAt'] != null;
    final alignRight = role == 'seller' || role == 'admin';
    final bubbleColor = deleted
        ? const Color(0xFFFFF7ED)
        : alignRight
            ? primary
            : const Color(0xFFF1F5F9);
    final textColor = alignRight && !deleted ? Colors.white : ink;
    final senderColor = alignRight && !deleted ? Colors.white70 : muted;

    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(alignRight ? 18 : 4),
              bottomRight: Radius.circular(alignRight ? 4 : 18),
            ),
            border: deleted
                ? Border.all(color: Colors.orange.withOpacity(0.35))
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${sender['name'] ?? 'Sender'} - $role',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: senderColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              _AdminMessageBody(message: message, textColor: textColor),
              if (message['reaction'] != null &&
                  message['reaction'].toString().trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Reaction: ${message['reaction']}',
                  style: TextStyle(
                    color: textColor.withOpacity(0.8),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
              if (deleted) ...[
                const SizedBox(height: 8),
                Text(
                  'Deleted for everyone at ${_formatDate(message['deletedAt'])}. Admin copy preserved.',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _formatDate(message['createdAt']),
                  style: TextStyle(
                    color: textColor.withOpacity(0.72),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminMessageBody extends StatelessWidget {
  const _AdminMessageBody({required this.message, required this.textColor});

  final Map<String, dynamic> message;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final type = message['type']?.toString() ?? 'text';
    final text = message['text']?.toString().trim() ?? '';
    final mediaUrl = message['mediaUrl']?.toString();
    final mediaName = message['mediaName']?.toString();

    if (type == 'image' && mediaUrl != null && mediaUrl.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _showAdminMediaPreview(context, mediaUrl, mediaName),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 220,
                height: 160,
                child: ProductImageView(
                  imageUrl: mediaUrl,
                  fallbackIcon: Icons.image_outlined,
                  fallbackColor: primary,
                ),
              ),
            ),
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              text,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
            ),
          ] else if (mediaName != null && mediaName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              mediaName,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
            ),
          ],
        ],
      );
    }

    if (type != 'text') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_adminMediaIcon(type), color: textColor, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              mediaName?.isNotEmpty == true ? mediaName! : _adminMediaLabel(type),
              style: TextStyle(color: textColor, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      );
    }

    return Text(
      text.isEmpty ? 'Message' : text,
      style: TextStyle(color: textColor, fontWeight: FontWeight.w900),
    );
  }
}

void _showAdminMediaPreview(
  BuildContext context,
  String mediaUrl,
  String? mediaName,
) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(18),
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: ProductImageView(
                imageUrl: mediaUrl,
                fallbackIcon: Icons.image_outlined,
                fallbackColor: primary,
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    mediaName ?? 'Media preview',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

IconData _adminMediaIcon(String type) {
  switch (type) {
    case 'video':
      return Icons.videocam_outlined;
    case 'pdf':
    case 'document':
      return Icons.picture_as_pdf_outlined;
    case 'voice':
    case 'audio':
      return Icons.mic_none_outlined;
    case 'deleted':
      return Icons.delete_outline;
    default:
      return Icons.attach_file;
  }
}

String _adminMediaLabel(String type) {
  switch (type) {
    case 'video':
      return 'Video';
    case 'pdf':
    case 'document':
      return 'Document';
    case 'voice':
    case 'audio':
      return 'Voice note';
    case 'deleted':
      return 'Deleted message';
    default:
      return 'Attachment';
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      tileColor: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: SizedBox(
        width: 42,
        height: 42,
        child: ClipOval(
          child: ProductImageView(
            imageUrl: imageUrl,
            fallbackIcon: icon,
            fallbackColor: primary,
          ),
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: muted, fontWeight: FontWeight.w600),
      ),
      trailing: trailing,
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: muted.withOpacity(0.45), size: 46),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatRupees(int cents) {
  final rupees = cents / 100;
  return 'Rs ${rupees.toStringAsFixed(cents % 100 == 0 ? 0 : 2)}';
}

String _formatDate(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return 'Now';
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    return '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
