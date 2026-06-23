import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dukaan_zone_flutter/dukaan.dart';
import 'package:dukaan_zone_flutter/ui/pages/shared/chat_scroll_cues.dart';
import 'package:dukaan_zone_flutter/ui/pages/shared/chat_typing_wave.dart';
import 'package:dukaan_zone_flutter/ui/pages/shared/chat_voice_note_player.dart';

// ─────────────────────────────────────────────────────────────
//  Message Status Color System (shared across all chat pages)
//   • sent_offline → grey (queued, no network)
//   • sending      → grey animated (in transit)
//   • sent_online  → blue (delivered)
//   • seen         → DukaanZone logo green (#10B981)
// ─────────────────────────────────────────────────────────────
Color _bubbleColorForStatus(String status, bool isSent) {
  if (!isSent) return const Color(0xFFF1F4F9); // received — always light grey
  if (status == 'sent_offline' || status == 'sending') {
    return const Color(0xFFBBD7F4);
  }
  if (status == 'seen') return primary;
  switch (status) {
    case 'sent_offline':
      return const Color(0xFF546E7A); // dark grey — queued
    case 'sending':
      return const Color(0xFF90CAF9); // light blue — in transit
    case 'sent_online':
      return const Color(0xFF2196F3); // blue — delivered
    case 'seen':
      return const Color(0xFF3B5998); // deep blue-grey — seen
    default:
      return primary;
  }
}

// ─────────────────────────────────────────────────────────────
//  SELLER CHAT (Payments) — Contact List
// ─────────────────────────────────────────────────────────────
class SellerChatPage extends StatefulWidget {
  const SellerChatPage({super.key});

  @override
  State<SellerChatPage> createState() => _SellerChatPageState();
}

class _SellerChatPageState extends State<SellerChatPage> {
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<LiveEvent>? _liveSub;
  String _searchQuery = '';
  bool _loadingRooms = true;
  bool _searchingAccounts = false;
  String? _roomsError;
  Timer? _searchDebounce;

  final List<Map<String, dynamic>> _neighbors = [];
  final List<Map<String, dynamic>> _accountResults = [];

  @override
  void initState() {
    super.initState();
    liveSocketService.connect();
    _liveSub = liveSocketService.events.listen(_handleLiveEvent);
    _loadRooms();
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleLiveEvent(LiveEvent event) {
    if (event.type == 'chat.receipt' || event.type == 'presence.update') {
      _loadRooms();
      return;
    }
    if (event.type != 'chat.message' ||
        event.payload['scope'] != 'shop_payment') {
      return;
    }
    final sender = Map<String, dynamic>.from(
      event.payload['sender'] as Map? ?? {},
    );
    final text = event.payload['text']?.toString() ?? '';
    final roomId = event.payload['roomId']?.toString();
    final userId = sender['id']?.toString();
    if (text.isEmpty || roomId == null || !mounted) return;
    final isMine = sender['id'] == authService.currentUser.value?.id;

    if (isMine) {
      setState(() {
        final index = _neighbors.indexWhere((n) => n['roomId'] == roomId);
        if (index == -1) return;
        final existing = Map<String, dynamic>.from(_neighbors.removeAt(index));
        existing['lastMessage'] = text;
        existing['time'] = 'Now';
        existing['unread'] = false;
        _neighbors.insert(0, existing);
      });
      return;
    }

    final contact = <String, dynamic>{
      'name': sender['name']?.toString() ?? 'Customer',
      'email': '',
      'block': 'Live buyer',
      'phone': '',
      'upi': '',
      'avatarColor': primary,
      'lastMessage': text,
      'time': 'Now',
      'unread': true,
      'unseenCount': 1,
      'roomId': roomId,
      'userId': userId,
      'isOnline': userId != null && liveSocketService.isUserOnline(userId),
    };

    setState(() {
      final index = _neighbors.indexWhere(
        (n) =>
            n['roomId'] == roomId || (userId != null && n['userId'] == userId),
      );
      if (index == -1) {
        _neighbors.insert(0, contact);
        return;
      }
      final existing = Map<String, dynamic>.from(_neighbors.removeAt(index));
      existing.addAll(contact);
      _neighbors.insert(0, existing);
    });
  }

  String _roomTime(DateTime? value) {
    if (value == null) return 'Now';
    final now = DateTime.now();
    if (value.year == now.year &&
        value.month == now.month &&
        value.day == now.day) {
      final hour = value.hour == 0
          ? 12
          : (value.hour > 12 ? value.hour - 12 : value.hour);
      return '$hour:${value.minute.toString().padLeft(2, '0')} ${value.hour >= 12 ? 'PM' : 'AM'}';
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
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  Map<String, dynamic> _contactFromRoom(ChatRoomRecord room) {
    final name = room.customerName?.trim().isNotEmpty == true
        ? room.customerName!
        : 'Customer';
    return {
      'name': name,
      'email': room.customerEmail ?? '',
      'block': room.shopName == null ? 'Live buyer' : 'From ${room.shopName}',
      'phone': room.customerPhone ?? '',
      'upi': '',
      'avatarColor': primary,
      'avatarUrl': room.customerAvatarUrl,
      'lastMessage': room.lastMessage,
      'time': _roomTime(room.updatedAt),
      'unread': room.unreadCount > 0,
      'unseenCount': room.unreadCount,
      'roomId': room.roomId,
      'userId': room.customerId,
      'shopId': room.shopId,
      'isOnline': room.customerOnline,
    };
  }

  Map<String, dynamic> _contactFromAccount(Map<String, dynamic> account) {
    final userId = account['id']?.toString() ?? '';
    final name = account['name']?.toString() ?? 'Customer';
    return {
      'name': name,
      'email': account['email']?.toString() ?? '',
      'block': 'DukaanZone user',
      'phone': account['phone']?.toString() ?? '',
      'upi': '',
      'avatarColor': primary,
      'avatarUrl': account['avatarUrl']?.toString(),
      'lastMessage': 'Tap to start chat',
      'time': 'New',
      'unread': false,
      'unseenCount': 0,
      'roomId': account['roomId']?.toString(),
      'userId': userId,
      'shopId': account['shopId']?.toString(),
      'isOnline': liveSocketService.isUserOnline(userId),
    };
  }

  void _queueSearch(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      _loadAccountResults(value);
    });
  }

  Future<void> _loadAccountResults(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (mounted) {
        setState(_accountResults.clear);
      }
      return;
    }
    setState(() => _searchingAccounts = true);
    try {
      final encoded = Uri.encodeQueryComponent(trimmed);
      final data = await apiClient.getJson(
        '/api/seller/customers/search?q=$encoded',
      );
      final accounts = (data['customers'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) => _contactFromAccount(Map<String, dynamic>.from(raw)))
          .toList();
      if (!mounted) return;
      setState(() {
        _accountResults
          ..clear()
          ..addAll(accounts);
      });
    } finally {
      if (mounted) setState(() => _searchingAccounts = false);
    }
  }

  Future<void> _loadRooms() async {
    setState(() {
      _loadingRooms = true;
      _roomsError = null;
    });
    try {
      final rooms = await chatHistoryService.listRooms();
      if (!mounted) return;
      setState(() {
        _neighbors
          ..clear()
          ..addAll(rooms.map(_contactFromRoom));
        _loadingRooms = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _roomsError = 'Could not load backend chats.';
        _loadingRooms = false;
      });
    }
  }

  void _showContactOptions(BuildContext context, Map<String, dynamic> n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFEBEE),
                child: Icon(Icons.delete_sweep_rounded, color: Colors.red),
              ),
              title: const Text(
                'Delete Chat',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.red,
                ),
              ),
              subtitle: const Text(
                'Clear all messages with this contact',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final roomId = n['roomId']?.toString() ?? '';
                if (roomId.isNotEmpty) {
                  await chatHistoryService.hideRoom(roomId);
                }
                if (!mounted) return;
                setState(() {
                  _neighbors.removeWhere(
                    (item) =>
                        item['roomId'] == n['roomId'] ||
                        (roomId.isEmpty && item['userId'] == n['userId']),
                  );
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Chat with ${n['name']} hidden for you'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: primary,
                  ),
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF3F4F6),
                child: Icon(Icons.cancel_outlined, color: muted),
              ),
              title: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w700, color: muted),
              ),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAvatarFullScreen(BuildContext context, Map<String, dynamic> n) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (n['avatarColor'] as Color).withOpacity(0.2),
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Center(
                child: Text(
                  n['name'][0],
                  style: TextStyle(
                    color: n['avatarColor'] as Color,
                    fontSize: 80,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.cancel, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Positioned(
              bottom: -40,
              child: Text(
                n['name'],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeMatches = _neighbors.where((n) {
      final name = n['name'].toString().toLowerCase();
      final phone = n['phone'].toString();
      final upi = n['upi'].toString().toLowerCase();
      final email = n['email'].toString().toLowerCase();
      final userId = n['userId']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          phone.contains(query) ||
          upi.contains(query) ||
          email.contains(query) ||
          userId.contains(query);
    }).toList();
    final activeUserIds = activeMatches
        .map((contact) => contact['userId']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final filtered = [
      ...activeMatches,
      if (_searchQuery.trim().isNotEmpty)
        ..._accountResults.where(
          (account) => !activeUserIds.contains(account['userId']?.toString()),
        ),
    ];

    return Scaffold(
      backgroundColor: bg,
      body: AppPage(
        maxWidth: 800,
        children: [
          const PageTitle(
            'Hub Chat & Payments',
            'Connect with local buyers and clear supplier UPI dues.',
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: shadowSm,
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _queueSearch,
              decoration: InputDecoration(
                icon: const Icon(Icons.search, color: primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: muted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _accountResults.clear();
                          });
                        },
                      )
                    : null,
                hintText: 'Enter buyer name, phone, or any UPI ID...',
                border: InputBorder.none,
                hintStyle: const TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          if (_searchingAccounts)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),

          if (_searchQuery.contains('@') ||
              (double.tryParse(_searchQuery) != null &&
                  _searchQuery.length >= 10))
            _buildCustomUpiPayCard(context, _searchQuery),

          const Kicker('ACTIVE CUSTOMER & SUPPLIER DIALOGUES'),
          const SizedBox(height: 12),

          if (_loadingRooms)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 42),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_roomsError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: muted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _roomsError!,
                      style: const TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _loadRooms,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 48,
                      color: muted.withOpacity(0.4),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No matching contacts found.',
                      style: TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final n = filtered[index];
                return _buildContactTile(context, n);
              },
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCustomUpiPayCard(BuildContext context, String input) {
    final isUpi = input.contains('@');
    final title = isUpi ? 'Pay to UPI ID' : 'Pay to Phone Number';
    final target = isUpi ? input : '$input@upi';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary.withOpacity(0.08), Colors.purple.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: primary.withOpacity(0.15),
            radius: 24,
            child: const Icon(Icons.send_to_mobile, color: primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: ink,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  target,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              push(
                context,
                SellerChatRoomPage(
                  contact: {
                    'name': isUpi ? input.split('@').first : 'Direct UPI Payee',
                    'upi': target,
                    'phone': isUpi ? 'Custom ID' : input,
                    'avatarColor': Colors.deepOrange,
                  },
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              elevation: 0,
            ),
            child: const Text(
              'Pay Now',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(BuildContext context, Map<String, dynamic> n) {
    final unseenCount = n['unseenCount'] as int? ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadowSm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            setState(() {
              n['unread'] = false;
              n['unseenCount'] = 0;
            });
            await push(context, SellerChatRoomPage(contact: n));
            if (mounted) _loadRooms();
          },
          onLongPress: () => _showContactOptions(context, n),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Row(
              children: [
                // Tappable avatar → full-screen
                GestureDetector(
                  onTap: () => _showAvatarFullScreen(context, n),
                  child: Stack(
                    children: [
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: ClipOval(
                          child: ProductImageView(
                            imageUrl: n['avatarUrl']?.toString(),
                            fallbackIcon: Icons.person_outline_rounded,
                            fallbackIconSize: 24,
                            fallbackColor: n['avatarColor'] as Color,
                          ),
                        ),
                      ),
                      if (n['isOnline'] == true)
                        Positioned(
                          right: 1,
                          bottom: 1,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              n['name'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: ink,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (unseenCount > 0) ...[
                            const SizedBox(width: 6),
                            _UnreadBadge(count: unseenCount),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n['lastMessage'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: n['unread'] == true ? ink : muted,
                          fontWeight: n['unread'] == true
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        n['time'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: n['unread'] == true ? primary : muted,
                          fontSize: 11,
                          fontWeight: n['unread'] == true
                              ? FontWeight.w900
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SELLER CHAT ROOM (Payments)
// ─────────────────────────────────────────────────────────────
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class SellerChatRoomPage extends StatefulWidget {
  const SellerChatRoomPage({
    super.key,
    required this.contact,
    this.highlightMediaId,
  });
  final Map<String, dynamic> contact;
  final String? highlightMediaId;

  @override
  State<SellerChatRoomPage> createState() => _SellerChatRoomPageState();
}

class _SellerChatRoomPageState extends State<SellerChatRoomPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _mediaService = MediaService();
  StreamSubscription<LiveEvent>? _liveSub;
  Timer? _typingIdleTimer;
  Timer? _peerTypingTimer;
  String? _lastLiveCustomerId;
  String? _lastLiveRoomId;
  bool _peerTyping = false;

  final List<Map<String, dynamic>> _messages = [];
  final Set<Map<String, dynamic>> _selectedMessages = {};
  Map<String, dynamic>? _selectedMessageForOptions;
  Map<String, dynamic>? _replyContextMessage;
  double? _emojiPopupX;
  double? _emojiPopupY;
  bool _showJumpToBottom = false;
  int _newMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _lastLiveCustomerId = widget.contact['userId']?.toString();
    _lastLiveRoomId = widget.contact['roomId']?.toString();
    _controller.addListener(_handleTypingChanged);
    _scrollController.addListener(_handleScrollPositionChanged);
    liveSocketService.connect();
    _liveSub = liveSocketService.events.listen(_handleLiveEvent);
    _loadChatHistory();
  }

  void _receiveSimulatedCustomerMessage(String text) {
    final msgId = 'msg-in-${DateTime.now().millisecondsSinceEpoch}';
    final timeStr = _timeNow();

    setState(() {
      _messages.add({
        'id': msgId,
        'message': text,
        'time': timeStr,
        'isSent': false,
        'type': 'text',
        'status': 'sent_online', // Delivered but unseen (blue status)
      });
    });
    _scrollToBottom();

    // Check if Auto-Reply is enabled for Customer (userEnabled in globalAutoReplyConfig)
    final config = globalAutoReplyConfig.value;
    if (config['userEnabled'] == true) {
      final replyText =
          config['userCustom'] != null &&
              config['userCustom'].toString().isNotEmpty
          ? config['userCustom'].toString()
          : config['userPreset'].toString();

      // Trigger auto reply after a small delay
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        final replyMsgId = 'msg-auto-${DateTime.now().millisecondsSinceEpoch}';
        setState(() {
          _messages.add({
            'id': replyMsgId,
            'message': '[Auto-Reply] $replyText',
            'time': timeStr,
            'isSent': true,
            'type': 'text',
            'status': 'sent_online', // Sent online, not yet seen
          });
        });
        _scrollToBottom();
      });
    }
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _typingIdleTimer?.cancel();
    _peerTypingTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        final offset = _scrollController.position.maxScrollExtent;
        if (animated) {
          _scrollController.animateTo(
            offset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(offset);
        }
      }
    });
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= 140;
  }

  void _handleScrollPositionChanged() {
    if (!_scrollController.hasClients || !mounted) return;
    final shouldShow = !_isNearBottom;
    if (shouldShow == _showJumpToBottom &&
        (shouldShow || _newMessageCount == 0)) {
      return;
    }
    setState(() {
      _showJumpToBottom = shouldShow;
      if (!shouldShow) _newMessageCount = 0;
    });
  }

  void _jumpToLatestMessages() {
    if (mounted) {
      setState(() {
        _showJumpToBottom = false;
        _newMessageCount = 0;
      });
    }
    _scrollToBottom();
  }

  void _handleIncomingMessagePlacement() {
    if (_isNearBottom) {
      _scrollToBottom();
      return;
    }
    if (!mounted) return;
    setState(() {
      _showJumpToBottom = true;
      _newMessageCount++;
    });
  }

  void _scrollToInitialMediaTarget() {
    final targetId = widget.highlightMediaId;
    if (targetId == null || targetId.isEmpty) {
      _scrollToBottom(animated: false);
      return;
    }
    final index = _messages.indexWhere(
      (message) => message['id']?.toString() == targetId,
    );
    if (index == -1 || _messages.length <= 1) {
      _scrollToBottom(animated: false);
      return;
    }
    Future.delayed(const Duration(milliseconds: 160), () {
      if (!_scrollController.hasClients) return;
      final fraction = index / (_messages.length - 1);
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent * fraction,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  bool _isHighlightedMedia(Map<String, dynamic> message) {
    final targetId = widget.highlightMediaId;
    return targetId != null &&
        targetId.isNotEmpty &&
        message['id']?.toString() == targetId;
  }

  void _simulateDelivery(String msgId) {
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m['id'] == msgId);
        if (idx != -1) _messages[idx]['status'] = 'sent_online';
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == msgId);
          if (idx != -1) _messages[idx]['status'] = 'seen';
        });
      });
    });
  }

  String _formatChatTime(DateTime? value) {
    final n = value ?? DateTime.now();
    final hour = n.hour == 0 ? 12 : (n.hour > 12 ? n.hour - 12 : n.hour);
    return '$hour:${n.minute.toString().padLeft(2, '0')} ${n.hour >= 12 ? 'PM' : 'AM'}';
  }

  bool get _peerOnline {
    final userId = _lastLiveCustomerId ?? widget.contact['userId']?.toString();
    return userId != null && liveSocketService.isUserOnline(userId);
  }

  String get _peerStatusLabel {
    return _peerOnline ? 'Active Now' : 'Offline';
  }

  List<String> _candidateRoomIds() {
    final ids = <String>[];
    void add(String? value) {
      if (value != null && value.isNotEmpty && !ids.contains(value)) {
        ids.add(value);
      }
    }

    final shopId = widget.contact['shopId']?.toString();
    final userId = _lastLiveCustomerId ?? widget.contact['userId']?.toString();
    if (shopId != null &&
        shopId.isNotEmpty &&
        userId != null &&
        userId.isNotEmpty) {
      add('shop:$shopId:user:$userId');
    }
    add(_lastLiveRoomId ?? widget.contact['roomId']?.toString());
    if (shopId != null && shopId.isNotEmpty) {
      add('shop:$shopId');
    }
    return ids;
  }

  void _handleTypingChanged() {
    final roomId = _lastLiveRoomId ?? widget.contact['roomId']?.toString();
    if (roomId == null || roomId.isEmpty) return;
    final isTyping = _controller.text.trim().isNotEmpty;
    liveSocketService.sendChatTyping(
      roomId: roomId,
      scope: 'shop_payment',
      shopId: widget.contact['shopId']?.toString(),
      targetUserId: _lastLiveCustomerId ?? widget.contact['userId']?.toString(),
      isTyping: isTyping,
    );
    _typingIdleTimer?.cancel();
    if (!isTyping) return;
    _typingIdleTimer = Timer(const Duration(milliseconds: 1200), () {
      liveSocketService.sendChatTyping(
        roomId: roomId,
        scope: 'shop_payment',
        shopId: widget.contact['shopId']?.toString(),
        targetUserId:
            _lastLiveCustomerId ?? widget.contact['userId']?.toString(),
        isTyping: false,
      );
    });
  }

  Map<String, dynamic> _messageFromRecord(ChatMessageRecord record) {
    final type = record.deletedAt != null ? 'deleted' : record.type;
    final mediaName = record.mediaName;
    final text = record.text.isNotEmpty
        ? record.text
        : _mediaLabel(type, mediaName);
    return {
      'id': record.id,
      'message': text,
      'time': _formatChatTime(record.createdAt),
      'isSent': record.isMine,
      'type': type,
      'status': record.isMine ? record.deliveryStatus : 'seen',
      'mediaPath': record.mediaUrl,
      'mediaName': mediaName,
      'mediaMime': record.mediaMime,
      'duration': record.mediaDurationSeconds,
      'reaction': record.reaction,
    };
  }

  Future<void> _loadChatHistory() async {
    String? firstReachableRoomId;
    for (final roomId in _candidateRoomIds()) {
      try {
        final records = await chatHistoryService.listRoomMessages(roomId);
        if (!mounted) return;
        firstReachableRoomId ??= roomId;
        if (records.isEmpty) continue;
        setState(() {
          _lastLiveRoomId = roomId;
          final existingIds = _messages.map((m) => m['id']?.toString()).toSet();
          for (final record in records) {
            if (existingIds.add(record.id)) {
              _messages.add(_messageFromRecord(record));
            }
          }
        });
        _scrollToInitialMediaTarget();
        liveSocketService.sendChatRead(roomId);
        return;
      } catch (_) {
        // Try the next known room key shape.
      }
    }
    if (mounted && firstReachableRoomId != null) {
      setState(() => _lastLiveRoomId = firstReachableRoomId);
    }
  }

  void _sendTypingStopped() {
    final roomId = _lastLiveRoomId ?? widget.contact['roomId']?.toString();
    if (roomId == null || roomId.isEmpty) return;
    liveSocketService.sendChatTyping(
      roomId: roomId,
      scope: 'shop_payment',
      shopId: widget.contact['shopId']?.toString(),
      targetUserId: _lastLiveCustomerId ?? widget.contact['userId']?.toString(),
      isTyping: false,
    );
  }

  void _setPeerTyping(bool isTyping) {
    _peerTypingTimer?.cancel();
    if (!mounted) return;
    if (_peerTyping != isTyping) {
      setState(() => _peerTyping = isTyping);
    }
    if (isTyping) {
      _peerTypingTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted && _peerTyping) setState(() => _peerTyping = false);
      });
    }
  }

  void _sendMessage(
    String text, {
    String type = 'text',
    String? mediaPath,
    Map<String, dynamic>? extra,
  }) {
    if (text.isEmpty && mediaPath == null) return;
    final id = 'msg-${DateTime.now().millisecondsSinceEpoch}';
    final timeStr = _timeNow();
    setState(() {
      for (final m in _messages) {
        if (m['isSent'] == false) {
          m['status'] = 'seen';
        }
      }
      _messages.add({
        'id': id,
        'message': text,
        'time': timeStr,
        'isSent': true,
        'type': type,
        'status': 'sending',
        'mediaPath': mediaPath,
        'replyTo': _replyContextMessage?['message'],
        if (extra != null) ...extra,
      });
      _replyContextMessage = null;
    });
    _controller.clear();
    _sendTypingStopped();
    _jumpToLatestMessages();
    liveSocketService.sendChatMessage(
      id: id,
      roomId:
          _lastLiveRoomId ??
          widget.contact['roomId']?.toString() ??
          'shop:seller',
      scope: 'shop_payment',
      targetUserId: _lastLiveCustomerId ?? widget.contact['userId']?.toString(),
      text: text,
      type: type,
      mediaUrl: mediaPath,
      mediaName: extra?['mediaName']?.toString(),
      mediaMime: extra?['mediaMime']?.toString(),
      mediaSizeBytes: extra?['mediaSizeBytes'] as int?,
      mediaDurationSeconds:
          extra?['mediaDurationSeconds'] as int? ?? extra?['duration'] as int?,
    );
  }

  void _handleLiveEvent(LiveEvent event) {
    if (event.type == 'chat.receipt') {
      _applyReceipt(event);
      return;
    }
    if (event.type == 'chat.deleted') {
      final roomId = _lastLiveRoomId ?? widget.contact['roomId']?.toString();
      if (event.payload['roomId'] == roomId) {
        _markMessageDeleted(event.payload['id']?.toString());
      }
      return;
    }
    if (event.type == 'chat.reacted') {
      final roomId = _lastLiveRoomId ?? widget.contact['roomId']?.toString();
      if (event.payload['roomId'] == roomId) {
        _applyReaction(
          event.payload['id']?.toString(),
          event.payload['reaction']?.toString(),
        );
      }
      return;
    }
    if (event.type == 'presence.update') {
      final userId = event.payload['userId']?.toString();
      final peerId =
          _lastLiveCustomerId ?? widget.contact['userId']?.toString();
      if (userId == peerId && mounted) setState(() {});
      return;
    }
    if (event.type == 'chat.typing') {
      final roomId = _lastLiveRoomId ?? widget.contact['roomId']?.toString();
      final sender = Map<String, dynamic>.from(
        event.payload['sender'] as Map? ?? {},
      );
      if (event.payload['roomId'] != roomId ||
          sender['id'] == authService.currentUser.value?.id) {
        return;
      }
      final isTyping = event.payload['isTyping'] != false;
      _setPeerTyping(isTyping);
      return;
    }
    if (event.type != 'chat.message' ||
        event.payload['scope'] != 'shop_payment') {
      return;
    }
    final currentRoomId =
        _lastLiveRoomId ?? widget.contact['roomId']?.toString();
    if (event.payload['roomId'] != currentRoomId) return;
    final sender = Map<String, dynamic>.from(
      event.payload['sender'] as Map? ?? {},
    );
    if (sender['id'] == authService.currentUser.value?.id) return;
    final text = event.payload['text']?.toString() ?? '';
    final type = event.payload['type']?.toString() ?? 'text';
    final mediaUrl = event.payload['mediaUrl']?.toString();
    if (text.isEmpty && (mediaUrl == null || type == 'text')) return;
    if (!mounted) return;
    _lastLiveCustomerId = sender['id']?.toString();
    _lastLiveRoomId = event.payload['roomId']?.toString();
    final id =
        event.payload['id']?.toString() ??
        'live-${DateTime.now().millisecondsSinceEpoch}';
    if (_messages.any((m) => m['id'] == id)) return;
    final mediaName = event.payload['mediaName']?.toString();
    setState(() {
      _messages.add({
        'id': id,
        'message': text.isNotEmpty ? text : _mediaLabel(type, mediaName),
        'time': _timeNow(),
        'isSent': false,
        'type': type,
        'status': 'sent_online',
        'mediaPath': mediaUrl,
        'mediaName': mediaName,
        'mediaMime': event.payload['mediaMime']?.toString(),
        'duration': event.payload['mediaDurationSeconds'] as int?,
        'reaction': event.payload['reaction']?.toString(),
      });
    });
    _handleIncomingMessagePlacement();
    if (_lastLiveRoomId != null) {
      liveSocketService.sendChatRead(_lastLiveRoomId!);
    }
  }

  void _applyReceipt(LiveEvent event) {
    final roomId = _lastLiveRoomId ?? widget.contact['roomId']?.toString();
    if (roomId == null || event.payload['roomId'] != roomId || !mounted) return;
    final status = event.payload['status']?.toString();
    if (status == null) return;
    final id = event.payload['id']?.toString();
    setState(() {
      if (status == 'seen') {
        for (final message in _messages) {
          if (message['isSent'] == true && _canReceiveReceipt(message)) {
            message['status'] = 'seen';
          }
        }
        return;
      }
      if (id == null) {
        for (final message in _messages) {
          if (message['isSent'] == true &&
              _canReceiveReceipt(message) &&
              message['status'] != 'seen') {
            message['status'] = status;
          }
        }
        return;
      }
      final index = _messages.indexWhere((message) => message['id'] == id);
      if (index != -1) {
        _messages[index]['status'] = status;
      }
    });
  }

  void _showBankSelection(String amountStr) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Business Account',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Paying $amountStr via UPI to ${widget.contact['name']}',
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 24),
            ListTile(
              onTap: () {
                Navigator.pop(ctx);
                _proceedToPin(amountStr, 'ICICI Merchant Pro');
              },
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance, color: Colors.blue),
              ),
              title: const Text(
                'ICICI Bank (Merchant Pro)',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('**** 9876'),
              trailing: const Icon(Icons.check_circle, color: primary),
            ),
            ListTile(
              onTap: () {
                Navigator.pop(ctx);
                _proceedToPin(amountStr, 'HDFC Business');
              },
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance, color: Colors.green),
              ),
              title: const Text(
                'HDFC Bank (Business Account)',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('**** 4321'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _openQuickPayFromChat() {
    final amountController = TextEditingController();
    final upi = widget.contact['upi']?.toString().trim();
    final phone = widget.contact['phone']?.toString().trim();
    final targetLabel = (upi != null && upi.isNotEmpty)
        ? upi
        : (phone != null && phone.isNotEmpty ? phone : 'linked payment method');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Start Payment',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Pay ${widget.contact['name']} via $targetLabel',
              style: const TextStyle(color: muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Amount',
                hintText: 'Enter rupees',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final value = amountController.text.trim();
                  if (double.tryParse(value) == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Enter a valid payment amount.'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  _showBankSelection('₹$value');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text(
                  'Continue to Pay',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(amountController.dispose);
  }

  void _proceedToPin(String amountStr, String accountName) {
    push(
      context,
      PinEntryPage(
        amount: amountStr,
        orderId: 'TXN-${DateTime.now().millisecond}',
      ),
    ).then((success) {
      if (success == true) {
        final numericVal =
            double.tryParse(
              amountStr.replaceAll('₹', '').replaceAll(',', ''),
            ) ??
            0.0;
        globalSellerTodayRevenue.value =
            (globalSellerTodayRevenue.value - numericVal).clamp(0.0, 999999.0);
        final id = 'pay-${DateTime.now().millisecondsSinceEpoch}';
        setState(() {
          for (final m in _messages) {
            if (m['isSent'] == false) {
              m['status'] = 'seen';
            }
          }
          _messages.add({
            'id': id,
            'amount': amountStr,
            'status': 'PAID',
            'time': _timeNow(),
            'isSent': true,
            'type': 'payment',
            'items': 'DukaanZone UPI Instant Payout ($accountName)',
          });
        });
        _scrollToBottom();
      }
    });
  }

  void _triggerDeleteOptions(Map<String, dynamic> msg) {
    final bool isSentByUs = msg['isSent'] == true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Message?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          if (isSentByUs)
            TextButton(
              child: const Text(
                'Delete for Everyone',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _deleteForEveryone(msg);
              },
            ),
          TextButton(
            child: const Text('Delete for Me', style: TextStyle(color: muted)),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _messages.removeWhere((item) => item['id'] == msg['id']);
              });
            },
          ),
        ],
      ),
    );
  }

  bool _canReceiveReceipt(Map<String, dynamic> message) {
    final type = message['type']?.toString();
    return type != 'deleted' && type != 'payment' && type != 'payment_done';
  }

  String _mediaLabel(String type, String? mediaName) {
    if (type == 'image') return mediaName ?? 'Image';
    if (type == 'video') return mediaName ?? 'Video';
    if (type == 'pdf') return mediaName ?? 'Document';
    if (type == 'voice') return mediaName ?? 'Voice note';
    if (type == 'deleted') return 'This message was deleted';
    return '';
  }

  void _deleteForEveryone(Map<String, dynamic> msg) {
    final roomId =
        _lastLiveRoomId ??
        widget.contact['roomId']?.toString() ??
        'shop:seller';
    liveSocketService.sendChatDelete(
      roomId: roomId,
      messageId: msg['id']?.toString() ?? '',
    );
    setState(() => _applyDeletedState(msg));
  }

  void _markMessageDeleted(String? messageId) {
    if (messageId == null || !mounted) return;
    setState(() {
      final index = _messages.indexWhere((item) => item['id'] == messageId);
      if (index != -1) _applyDeletedState(_messages[index]);
    });
  }

  void _applyReaction(String? messageId, String? reaction) {
    if (messageId == null || !mounted) return;
    setState(() {
      final index = _messages.indexWhere((item) => item['id'] == messageId);
      if (index != -1) _messages[index]['reaction'] = reaction;
    });
  }

  void _applyDeletedState(Map<String, dynamic> msg) {
    msg['message'] = 'This message was deleted';
    msg['type'] = 'deleted';
    msg['mediaPath'] = null;
    msg['mediaName'] = null;
    msg['mediaMime'] = null;
    msg['reaction'] = null;
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final doubleVal = double.tryParse(text);
    if (doubleVal != null) {
      _showBankSelection('₹$text');
    } else {
      _sendMessage(text);
    }
  }

  Future<void> _showForwardDialog(List<Map<String, dynamic>> messages) async {
    final rooms = await chatHistoryService.listRooms();
    if (!mounted) return;
    final currentRoom =
        _lastLiveRoomId ?? widget.contact['roomId']?.toString() ?? '';
    final targets = rooms.where((room) => room.roomId != currentRoom).toList();
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final filtered = targets.where((room) {
              final label =
                  '${room.customerName ?? ''} ${room.shopName ?? ''} ${room.roomId}'
                      .toLowerCase();
              return label.contains(query.toLowerCase());
            }).toList();
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                messages.length > 1
                    ? 'Forward ${messages.length} messages'
                    : 'Forward message',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (value) => setDialogState(() => query = value),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search chats or accounts',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (targets.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'No chats yet.',
                          style: TextStyle(
                            color: muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'No accounts match search.',
                          style: TextStyle(
                            color: muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 240,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final room = filtered[index];
                            final title =
                                room.customerName ??
                                room.shopName ??
                                room.roomId;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: primary.withOpacity(.10),
                                child: const Icon(
                                  Icons.person_outline_rounded,
                                  color: primary,
                                ),
                              ),
                              title: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(room.lastMessage),
                              trailing: const Icon(
                                Icons.send_rounded,
                                color: primary,
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                _forwardMessages(messages, room);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _forwardMessages(
    List<Map<String, dynamic>> messages,
    ChatRoomRecord room,
  ) {
    for (final msg in messages) {
      final type = msg['type']?.toString() ?? 'text';
      if (type == 'deleted' || type == 'payment' || type == 'payment_done') {
        continue;
      }
      final forwardedId = 'fwd-${DateTime.now().microsecondsSinceEpoch}';
      liveSocketService.sendChatMessage(
        id: forwardedId,
        roomId: room.roomId,
        scope: room.scope,
        shopId: room.shopId,
        targetUserId: room.customerId,
        text: msg['message']?.toString() ?? '',
        type: type,
        mediaUrl: msg['mediaPath']?.toString(),
        mediaName: msg['mediaName']?.toString(),
        mediaMime: msg['mediaMime']?.toString(),
        mediaDurationSeconds: msg['duration'] as int?,
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          messages.length == 1
              ? 'Message forwarded.'
              : '${messages.length} messages forwarded.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _timeNow() {
    final n = DateTime.now();
    return '${n.hour}:${n.minute.toString().padLeft(2, '0')} ${n.hour >= 12 ? 'PM' : 'AM'}';
  }

  void _showAvatarFullScreen() {
    final n = widget.contact;
    push(
      context,
      ChatContactInfoPage(
        title: n['name']?.toString() ?? 'Customer',
        subtitle: n['block']?.toString() ?? 'Customer',
        phone: n['phone']?.toString(),
        avatarUrl: n['avatarUrl']?.toString(),
        fallbackColor: n['avatarColor'] as Color,
        fallbackIcon: Icons.person_outline_rounded,
        messages: _messages,
        roomId:
            _lastLiveRoomId ??
            widget.contact['roomId']?.toString() ??
            'shop:seller',
        scope: 'shop_payment',
        targetUserId:
            _lastLiveCustomerId ?? widget.contact['userId']?.toString(),
      ),
    );
    if (mounted) return;
    final mediaItems = _messages
        .where(
          (item) =>
              ['image', 'video', 'pdf', 'voice'].contains(item['type']) &&
              item['mediaPath'] != null,
        )
        .toList();
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: _ChatProfilePreview(
          title: n['name']?.toString() ?? 'Customer',
          subtitle: n['phone']?.toString().isNotEmpty == true
              ? n['phone']?.toString() ?? ''
              : n['email']?.toString() ?? '',
          imageUrl: n['avatarUrl']?.toString(),
          fallbackColor: n['avatarColor'] as Color,
          fallbackIcon: Icons.person_outline_rounded,
          mediaItems: mediaItems,
        ),
      ),
    );
  }

  void _startHeaderCall(String kind) {
    final id = 'call-${DateTime.now().millisecondsSinceEpoch}';
    liveSocketService.sendCallStart(
      id: id,
      roomId:
          _lastLiveRoomId ??
          widget.contact['roomId']?.toString() ??
          'shop:seller',
      scope: 'shop_payment',
      kind: kind,
      targetUserId: _lastLiveCustomerId ?? widget.contact['userId']?.toString(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${kind == 'video' ? 'Video' : 'Voice'} call request sent to ${widget.contact['name']}.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.contact['avatarColor'] as Color;
    final bool isSelectionModeActive = _selectedMessages.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: isSelectionModeActive
          ? AppBar(
              backgroundColor: primary,
              elevation: 4,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _selectedMessages.clear();
                    _selectedMessageForOptions = null;
                  });
                },
              ),
              title: Text(
                '${_selectedMessages.length} Selected',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.forward_rounded, color: Colors.white),
                  tooltip: 'Forward',
                  onPressed: () {
                    final selected = List<Map<String, dynamic>>.from(
                      _selectedMessages,
                    );
                    setState(() {
                      _selectedMessages.clear();
                      _selectedMessageForOptions = null;
                    });
                    _showForwardDialog(selected);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  onPressed: () {
                    final bool anySentByUs = _selectedMessages.any(
                      (m) => m['isSent'] == true,
                    );

                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: Text(
                          _selectedMessages.length > 1
                              ? 'Delete ${_selectedMessages.length} Messages?'
                              : 'Delete Message?',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        actions: [
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                          if (anySentByUs)
                            TextButton(
                              child: const Text(
                                'Delete for Everyone',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                final selected =
                                    List<Map<String, dynamic>>.from(
                                      _selectedMessages,
                                    );
                                final roomId =
                                    _lastLiveRoomId ??
                                    widget.contact['roomId']?.toString() ??
                                    'shop:seller';
                                setState(() {
                                  for (final msg in selected) {
                                    if (msg['isSent'] == true) {
                                      _applyDeletedState(msg);
                                    } else {
                                      _messages.removeWhere(
                                        (item) => item['id'] == msg['id'],
                                      );
                                    }
                                  }
                                  _selectedMessages.clear();
                                  _selectedMessageForOptions = null;
                                });
                                for (final msg in selected) {
                                  if (msg['isSent'] == true) {
                                    liveSocketService.sendChatDelete(
                                      roomId: roomId,
                                      messageId: msg['id']?.toString() ?? '',
                                    );
                                  }
                                }
                              },
                            ),
                          TextButton(
                            child: const Text(
                              'Delete for Me',
                              style: TextStyle(color: muted),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() {
                                final idsToRemove = _selectedMessages
                                    .map((m) => m['id'])
                                    .toSet();
                                _messages.removeWhere(
                                  (item) => idsToRemove.contains(item['id']),
                                );
                                _selectedMessages.clear();
                                _selectedMessageForOptions = null;
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            )
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.white,
              leadingWidth: 40,
              title: Row(
                children: [
                  GestureDetector(
                    onTap: _showAvatarFullScreen,
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: ClipOval(
                        child: ProductImageView(
                          imageUrl: widget.contact['avatarUrl']?.toString(),
                          fallbackIcon: Icons.person_outline_rounded,
                          fallbackIconSize: 18,
                          fallbackColor: color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _showAvatarFullScreen,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.contact['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: ink,
                            ),
                          ),
                          Text(
                            'UPI: ${widget.contact['upi'] ?? 'N/A'} • $_peerStatusLabel',
                            style: const TextStyle(
                              fontSize: 11,
                              color: muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.phone_outlined, color: primary),
                  onPressed: () => _startHeaderCall('voice'),
                ),
                IconButton(
                  icon: const Icon(Icons.videocam_outlined, color: primary),
                  onPressed: () => _startHeaderCall('video'),
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final item = _messages[index];
                    final isSelected = _selectedMessages.contains(item);
                    final normalizedType = item['type'] == 'payment_done'
                        ? 'payment'
                        : item['type'];

                    if (normalizedType == 'payment') {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _PaymentBubble(
                          amount: item['amount'],
                          status: item['status'],
                          time: item['time'],
                          isSent: item['isSent'],
                          items: item['items'],
                        ),
                      );
                    }

                    return GestureDetector(
                      onLongPressStart: (details) {
                        setState(() {
                          _emojiPopupY = details.globalPosition.dy;
                          _emojiPopupX = details.globalPosition.dx;
                          if (_selectedMessages.isNotEmpty) {
                            if (isSelected)
                              _selectedMessages.remove(item);
                            else
                              _selectedMessages.add(item);
                          } else {
                            _selectedMessages.add(item);
                            _selectedMessageForOptions = item;
                          }
                        });
                      },
                      onTap: () {
                        if (_selectedMessages.isNotEmpty) {
                          setState(() {
                            if (isSelected)
                              _selectedMessages.remove(item);
                            else
                              _selectedMessages.add(item);
                          });
                        }
                      },
                      child: Container(
                        color: isSelected
                            ? primary.withOpacity(0.1)
                            : Colors.transparent,
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Dismissible(
                          key: Key(item['id'].toString()),
                          direction: DismissDirection.horizontal,
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 24),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.delete_rounded,
                              color: Colors.redAccent,
                              size: 26,
                            ),
                          ),
                          secondaryBackground: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.reply_rounded,
                              color: Colors.blueAccent,
                              size: 26,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              _triggerDeleteOptions(item);
                            } else if (direction ==
                                DismissDirection.endToStart) {
                              setState(() {
                                _replyContextMessage = item;
                              });
                            }
                            return false;
                          },
                          child: _PayChatBubble(
                            message: item['message'] ?? '',
                            time: item['time'],
                            isSent: item['isSent'],
                            status: item['status'] ?? 'seen',
                            type: item['type'] ?? 'text',
                            highlight: _isHighlightedMedia(item),
                            mediaPath: item['mediaPath'],
                            duration: item['duration'],
                            replyTo: item['replyTo'],
                            reaction: item['reaction'],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              ChatTypingWaveCue(visible: _peerTyping, color: primary),

              if (_replyContextMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      const Icon(Icons.reply, color: primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _replyContextMessage!['message'] ?? 'Media',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: muted),
                        onPressed: () =>
                            setState(() => _replyContextMessage = null),
                      ),
                    ],
                  ),
                ),
              MediaInputBar(
                controller: _controller,
                hintText: 'Enter amount to Pay or type message...',
                onSend: _handleSend,
                onPayTap: _openQuickPayFromChat,
                onMediaSent: (type, path, extraData) {
                  final text =
                      extraData?['caption'] ??
                      (type == 'voice'
                          ? '🎙 Voice Note'
                          : type == 'pdf'
                          ? '📄 Document'
                          : type == 'video'
                          ? '🎥 Video'
                          : '📷 Image');
                  _sendMessage(
                    text,
                    type: type,
                    mediaPath: path,
                    extra: extraData,
                  );
                  // Save to MediaService
                  _mediaService.saveToLocal(
                    type: type,
                    localPath: path,
                    sizeBytes: extraData?['sizeBytes'] ?? 100000,
                    durationSeconds: extraData?['duration'],
                    chatId: widget.contact['name'],
                    chatName: widget.contact['name'],
                  );
                },
              ),
            ],
          ),
          ChatScrollCues(
            showJumpButton: _showJumpToBottom,
            newMessageCount: _newMessageCount,
            onJumpToLatest: _jumpToLatestMessages,
            color: primary,
          ),
          if (_selectedMessageForOptions != null)
            Positioned(
              top: (_emojiPopupY != null
                  ? (_emojiPopupY! - 85).clamp(
                      100.0,
                      MediaQuery.of(context).size.height - 200,
                    )
                  : 250.0),
              left: _selectedMessageForOptions!['isSent'] == true ? null : 32.0,
              right: _selectedMessageForOptions!['isSent'] == true
                  ? 32.0
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        final messageId = _selectedMessageForOptions!['id']
                            ?.toString();
                        liveSocketService.sendChatReaction(
                          roomId:
                              _lastLiveRoomId ??
                              widget.contact['roomId']?.toString() ??
                              'shop:seller',
                          messageId: messageId ?? '',
                          reaction: emoji,
                        );
                        setState(() {
                          _selectedMessageForOptions!['reaction'] = emoji;
                          _selectedMessageForOptions = null;
                          _selectedMessages.clear();
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          emoji,
                          style: const TextStyle(
                            fontSize: 26,
                            fontFamilyFallback: [
                              'Apple Color Emoji',
                              'Segoe UI Emoji',
                              'Noto Color Emoji',
                              'Android Emoji',
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Shared Chat Bubble (payment chat pages)
// ─────────────────────────────────────────────────────────────
class _ChatProfilePreview extends StatelessWidget {
  const _ChatProfilePreview({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.fallbackColor,
    required this.fallbackIcon,
    required this.mediaItems,
  });

  final String title;
  final String subtitle;
  final String? imageUrl;
  final Color fallbackColor;
  final IconData fallbackIcon;
  final List<Map<String, dynamic>> mediaItems;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            ClipOval(
              child: SizedBox(
                width: 132,
                height: 132,
                child: ProductImageView(
                  imageUrl: imageUrl,
                  fallbackIcon: fallbackIcon,
                  fallbackIconSize: 44,
                  fallbackColor: fallbackColor,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ink,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 22),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Shared media',
                style: TextStyle(
                  color: ink.withOpacity(.86),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (mediaItems.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 18),
                child: Text(
                  'No shared media yet',
                  style: TextStyle(color: muted, fontWeight: FontWeight.w700),
                ),
              )
            else
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: mediaItems.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final item = mediaItems[index];
                    final type = item['type']?.toString() ?? 'image';
                    final path = item['mediaPath']?.toString();
                    return GestureDetector(
                      onTap: () => _showChatMediaPreview(
                        context,
                        type: type,
                        mediaPath: path,
                        title: item['message']?.toString() ?? type,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 84,
                          height: 84,
                          child: type == 'image'
                              ? ProductImageView(
                                  imageUrl: path,
                                  fallbackIcon: Icons.image_outlined,
                                )
                              : ColoredBox(
                                  color: const Color(0xFFF1F4F9),
                                  child: Icon(
                                    _mediaIcon(type),
                                    color: primary,
                                    size: 30,
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void _showChatMediaPreview(
  BuildContext context, {
  required String type,
  required String? mediaPath,
  required String title,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(14),
      child: Stack(
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 720,
                  maxHeight: 640,
                ),
                color: Colors.white,
                child: type == 'image'
                    ? ProductImageView(
                        imageUrl: mediaPath,
                        fallbackIcon: Icons.image_not_supported_outlined,
                      )
                    : Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_mediaIcon(type), color: primary, size: 54),
                            const SizedBox(height: 12),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: ink,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              type.toUpperCase(),
                              style: const TextStyle(
                                color: muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: IconButton.filled(
              onPressed: () => openMediaDownload(
                context,
                mediaPath: mediaPath,
                title: title,
              ),
              icon: const Icon(Icons.download_rounded),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filled(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    ),
  );
}

IconData _mediaIcon(String type) {
  return switch (type) {
    'video' => Icons.play_circle_outline_rounded,
    'pdf' => Icons.picture_as_pdf_rounded,
    'voice' => Icons.mic_rounded,
    _ => Icons.image_outlined,
  };
}

class _PayChatBubble extends StatelessWidget {
  const _PayChatBubble({
    required this.message,
    required this.time,
    required this.isSent,
    required this.status,
    required this.type,
    this.highlight = false,
    this.mediaPath,
    this.duration,
    this.replyTo,
    this.reaction,
  });
  final String message;
  final String time;
  final bool isSent;
  final String status;
  final String type;
  final String? mediaPath;
  final bool highlight;
  final int? duration;
  final String? replyTo;
  final String? reaction;

  @override
  Widget build(BuildContext context) {
    final bool isDeleted = type == 'deleted';
    final bgColor = isDeleted
        ? Colors.grey.shade100
        : _bubbleColorForStatus(status, isSent);
    final textColor = isDeleted ? muted : (isSent ? Colors.white : ink);

    Widget content;
    if (isDeleted) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            message,
            style: TextStyle(
              color: muted,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: const TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    } else if (type == 'image' && mediaPath != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () => _showChatMediaPreview(
              context,
              type: type,
              mediaPath: mediaPath,
              title: message.isEmpty ? 'Image' : message,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 180,
                height: 160,
                child: ProductImageView(
                  imageUrl: mediaPath,
                  fallbackIcon: Icons.image_rounded,
                  fallbackIconSize: 44,
                ),
              ),
            ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(
              color: isSent ? Colors.white70 : muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    } else if (type == 'voice') {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatVoiceNotePlayer(
            audioUrl: mediaPath,
            durationSeconds: duration,
            isSent: isSent,
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(
              color: isSent ? Colors.white70 : muted,
              fontSize: 10,
            ),
          ),
        ],
      );
    } else if (type == 'pdf') {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.picture_as_pdf_rounded,
            color: isSent ? Colors.white : Colors.red,
            size: 32,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  time,
                  style: TextStyle(
                    color: isSent ? Colors.white70 : muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (type == 'video') {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 180,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(
                Icons.play_circle_filled_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(
              color: isSent ? Colors.white70 : muted,
              fontSize: 10,
            ),
          ),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            message,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(
              color: isSent ? Colors.white70 : muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return BlinkingTargetHighlight(
      enabled: highlight,
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 260),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomRight: isSent ? const Radius.circular(4) : null,
                  bottomLeft: !isSent ? const Radius.circular(4) : null,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (replyTo != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSent
                            ? Colors.white12
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Reply: $replyTo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSent ? Colors.white70 : muted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  content,
                ],
              ),
            ),
          ),
          if (reaction != null)
            Positioned(
              bottom: -8,
              right: isSent ? 12 : null,
              left: isSent ? null : 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  reaction!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamilyFallback: [
                      'Apple Color Emoji',
                      'Segoe UI Emoji',
                      'Noto Color Emoji',
                      'Android Emoji',
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Payment Bubble (unchanged, no delete)
// ─────────────────────────────────────────────────────────────
class _PaymentBubble extends StatelessWidget {
  const _PaymentBubble({
    required this.amount,
    required this.status,
    required this.time,
    required this.isSent,
    required this.items,
  });
  final String amount, status, time, items;
  final bool isSent;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isSent ? const Radius.circular(4) : null,
            bottomLeft: !isSent ? const Radius.circular(4) : null,
          ),
          border: Border.all(color: Colors.green.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_upward_rounded,
                    size: 16,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.check_circle, size: 14, color: Colors.green),
                const SizedBox(width: 6),
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.green,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 10,
                    color: muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    builder: (ctx) => Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'UPI Transaction Ledger',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.account_balance_wallet,
                              color: Colors.green,
                            ),
                            title: const Text(
                              'Purpose / Account',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              items,
                              style: const TextStyle(color: muted),
                            ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.tag, color: primary),
                            title: const Text(
                              'Transaction Reference',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              'TXN-${DateTime.now().millisecondsSinceEpoch}',
                              style: const TextStyle(color: muted),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: BorderSide(color: Colors.green.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'View Ledger Receipt',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
