import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dukaan_zone_flutter/dukaan.dart';
import 'b2b_contact_info_page.dart';
import '../../../services/network_service.dart';
import '../shared/media_input_bar.dart';
import '../shared/chat_scroll_cues.dart';
import '../shared/chat_typing_wave.dart';
import 'package:url_launcher/url_launcher.dart';
import '../shared/chat_voice_note_player.dart';

class B2BChatPage extends StatefulWidget {
  const B2BChatPage({super.key});

  @override
  State<B2BChatPage> createState() => _B2BChatPageState();
}

class _B2BChatPageState extends State<B2BChatPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _loadingRooms = false;
  bool _searchingPartners = false;
  Timer? _searchDebounce;
  StreamSubscription<LiveEvent>? _liveSub;

  final List<Map<String, dynamic>> _merchants = [];
  final List<Map<String, dynamic>> _partnerResults = [];

  @override
  void initState() {
    super.initState();
    liveSocketService.connect();
    _liveSub = liveSocketService.events.listen(_handleListLiveEvent);
    _loadB2BRooms();
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleListLiveEvent(LiveEvent event) {
    if ((event.type == 'chat.message' && event.payload['scope'] == 'b2b') ||
        event.type == 'chat.receipt' ||
        event.type == 'presence.update') {
      _loadB2BRooms();
    }
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

  Map<String, dynamic> _merchantFromRoom(ChatRoomRecord room) {
    final name = room.customerName?.trim().isNotEmpty == true
        ? room.customerName!
        : _fallbackB2BRoomName(room.roomId);
    return {
      'name': name,
      'owner': room.customerEmail ?? 'Live B2B Room',
      'specialty': 'Backend connected seller chat',
      'roomId': room.roomId,
      'sellerId': room.customerId,
      'avatarColor': Colors.indigoAccent,
      'avatarUrl': room.customerAvatarUrl,
      'lastMessage': room.lastMessage,
      'time': _roomTime(room.updatedAt),
      'updatedAt': room.updatedAt,
      'unread': room.unreadCount > 0,
      'unseenCount': room.unreadCount,
      'hasRoom': true,
      'hasOfflineSeen': false,
      'isOnline': room.customerOnline,
      'isGroup':
          name.toLowerCase().contains('guild') ||
          name.toLowerCase().contains('group'),
      'description': 'Messages in this room are saved to DukaanZone backend.',
    };
  }

  Map<String, dynamic> _merchantFromPartner(Map<String, dynamic> partner) {
    final name = partner['name']?.toString() ?? 'Shop';
    final category = partner['category']?.toString() ?? 'Local shop';
    final block = partner['block']?.toString() ?? '';
    final sellerId = partner['sellerId']?.toString() ?? '';
    final palette = [
      Colors.indigoAccent,
      Colors.teal,
      Colors.deepOrange,
      Colors.blueGrey,
      Colors.green,
    ];
    final color = palette[name.hashCode.abs() % palette.length];
    return {
      'name': name,
      'owner': partner['owner']?.toString() ?? 'Seller account',
      'specialty': block.isEmpty ? category : '$category - $block',
      'roomId': _b2BRoomIdFor(sellerId, name),
      'sellerId': sellerId,
      'avatarColor': color,
      'avatarUrl': partner['avatarUrl']?.toString(),
      'lastMessage': 'Tap to start B2B chat',
      'time': 'New',
      'updatedAt': null,
      'unread': false,
      'unseenCount': 0,
      'hasRoom': false,
      'hasOfflineSeen': false,
      'isOnline': liveSocketService.isUserOnline(sellerId),
      'isGroup': false,
      'description': 'Seller account from DukaanZone backend.',
    };
  }

  String _fallbackB2BRoomName(String roomId) {
    if (!roomId.startsWith('b2b:')) return roomId;
    final parts = roomId.split(':');
    if (parts.length == 3) return 'Seller chat';
    return roomId.substring('b2b:'.length);
  }

  String _merchantIdentityKey(Map<String, dynamic> merchant) {
    final sellerId = merchant['sellerId']?.toString() ?? '';
    if (sellerId.isNotEmpty) return sellerId;
    final roomId = merchant['roomId']?.toString() ?? '';
    if (roomId.isNotEmpty) return roomId;
    return merchant['name'].toString().trim().toLowerCase();
  }

  String _b2BRoomIdFor(String sellerId, String fallbackName) {
    final myId = authService.currentUser.value?.id ?? '';
    if (myId.isNotEmpty && sellerId.isNotEmpty) {
      final ids = [myId, sellerId]..sort();
      return 'b2b:${ids[0]}:${ids[1]}';
    }
    return 'b2b:$fallbackName';
  }

  void _queueSearch(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      _loadPartnerResults(value);
    });
  }

  Future<void> _loadPartnerResults(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (mounted) setState(_partnerResults.clear);
      return;
    }
    setState(() => _searchingPartners = true);
    try {
      final encoded = Uri.encodeQueryComponent(trimmed);
      final data = await apiClient.getJson(
        '/api/seller/b2b/partners?q=$encoded',
      );
      final partners = (data['partners'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) => _merchantFromPartner(Map<String, dynamic>.from(raw)))
          .toList();
      if (!mounted) return;
      setState(() {
        _partnerResults
          ..clear()
          ..addAll(partners);
      });
    } catch (_) {
      if (!mounted) return;
      setState(_partnerResults.clear);
    } finally {
      if (mounted) setState(() => _searchingPartners = false);
    }
  }

  Future<void> _loadB2BRooms() async {
    setState(() => _loadingRooms = true);
    try {
      final rooms = await chatHistoryService.listRooms(scope: 'b2b');
      if (!mounted) return;
      final mapped = rooms.map(_merchantFromRoom).toList()
        ..sort((a, b) => _merchantSortTime(b).compareTo(_merchantSortTime(a)));
      setState(() {
        _merchants
          ..clear()
          ..addAll(mapped);
      });
    } finally {
      if (mounted) setState(() => _loadingRooms = false);
    }
  }

  DateTime _merchantSortTime(Map<String, dynamic> merchant) {
    final updatedAt = merchant['updatedAt'];
    if (updatedAt is DateTime) return updatedAt;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    final activeMatches = _merchants.where((m) {
      final name = m['name'].toString().toLowerCase();
      final owner = m['owner'].toString().toLowerCase();
      final specialty = m['specialty'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          owner.contains(query) ||
          specialty.contains(query);
    }).toList();
    final activeKeys = activeMatches.map(_merchantIdentityKey).toSet();
    final filtered =
        [
          ...activeMatches,
          if (_searchQuery.trim().isNotEmpty)
            ..._partnerResults.where(
              (partner) => !activeKeys.contains(_merchantIdentityKey(partner)),
            ),
        ]..sort((a, b) {
          final aHasRoom = (a['hasRoom'] as bool?) ?? false;
          final bHasRoom = (b['hasRoom'] as bool?) ?? false;
          if (aHasRoom != bHasRoom) return bHasRoom ? 1 : -1;
          return _merchantSortTime(b).compareTo(_merchantSortTime(a));
        });
    final showLoadingPlaceholder =
        filtered.isEmpty && (_loadingRooms || _searchingPartners);
    final showEmptyPlaceholder =
        filtered.isEmpty && !_loadingRooms && !_searchingPartners;

    return Scaffold(
      backgroundColor: bg,
      body: AppPage(
        maxWidth: 800,
        children: [
          const SizedBox(height: 16),

          // Search / Partner ID input
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
                            _partnerResults.clear();
                          });
                        },
                      )
                    : null,
                hintText: 'Search merchant partners by name, specialty...',
                border: InputBorder.none,
                hintStyle: const TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Create B2B Collab Group Card
          GestureDetector(
            onTap: () async {
              final newGroup = await push<Map<String, dynamic>>(
                context,
                const B2BCreateGroupPage(),
              );
              if (newGroup != null) {
                setState(() {
                  _merchants.insert(0, {
                    ...newGroup,
                    'roomId': 'b2b:${newGroup['name']}',
                    'lastMessage': 'Group created: ${newGroup['description']}',
                    'time': 'Just now',
                    'unread': false,
                  });
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: const Icon(Icons.group_add, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create B2B Collab Group',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Form wholesale guilds & direct borrowing networks',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white70),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Kicker('ACTIVE B2B DIALOGUES'),
          const SizedBox(height: 12),

          if (_loadingRooms)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_searchingPartners)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),

          if (showLoadingPlaceholder)
            const _B2BListPlaceholder(message: 'Loading B2B partners...')
          else if (showEmptyPlaceholder)
            _B2BListPlaceholder(
              message: _searchQuery.trim().isEmpty
                  ? 'No B2B chats yet.'
                  : 'No accounts match search.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final m = filtered[index];
                return _buildMerchantTile(context, m);
              },
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showMerchantOptions(BuildContext context, Map<String, dynamic> m) {
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: (m['avatarColor'] as Color).withOpacity(
                      0.15,
                    ),
                    child: Text(
                      m['name'][0],
                      style: TextStyle(
                        color: m['avatarColor'] as Color,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    m['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: ink,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
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
                'Clear all messages in this dialogue',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final roomId = m['roomId']?.toString() ?? 'b2b:${m['name']}';
                await chatHistoryService.hideRoom(roomId);
                if (!mounted) return;
                setState(() {
                  _merchants.removeWhere(
                    (item) =>
                        item['roomId'] == roomId || item['name'] == m['name'],
                  );
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Chat with ${m['name']} hidden for you'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: primary,
                  ),
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF3CD),
                child: Icon(Icons.person_remove_outlined, color: Colors.orange),
              ),
              title: const Text(
                'Delete Contact',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.orange,
                ),
              ),
              subtitle: const Text(
                'Remove this merchant from your B2B network',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              onTap: () {
                Navigator.pop(ctx);
                // TODO: DELETE /api/b2b/contacts/:merchantId
                setState(
                  () => _merchants.removeWhere((x) => x['name'] == m['name']),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${m['name']} removed from contacts'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.orange.shade700,
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

  void _showAvatarFullScreen(BuildContext context, Map<String, dynamic> m) {
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
                color: (m['avatarColor'] as Color).withOpacity(0.2),
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Center(
                child: Text(
                  m['name'][0],
                  style: TextStyle(
                    color: m['avatarColor'] as Color,
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
              bottom: -44,
              child: Text(
                m['name'],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantTile(BuildContext context, Map<String, dynamic> m) {
    final int unseenCount = m['unseenCount'] ?? 0;
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
              m['unread'] = false;
              m['unseenCount'] = 0;
              m['hasOfflineSeen'] = false;
            });
            await push(context, B2BChatRoomPage(merchant: m));
            if (mounted) _loadB2BRooms();
          },
          onLongPress: () => _showMerchantOptions(context, m),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Row(
              children: [
                // Tappable avatar → full-screen photo viewer
                GestureDetector(
                  onTap: () => _showAvatarFullScreen(context, m),
                  child: Stack(
                    children: [
                      B2BBreathingAvatar(
                        hasGlow: m['hasOfflineSeen'] == true,
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: ClipOval(
                            child: ProductImageView(
                              imageUrl: m['avatarUrl']?.toString(),
                              fallbackIcon: Icons.storefront_outlined,
                              fallbackIconSize: 24,
                              fallbackColor: m['avatarColor'] as Color,
                            ),
                          ),
                        ),
                      ),
                      if (m['isOnline'] == true)
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
                              m['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: ink,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unseenCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$unseenCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m['lastMessage'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: m['unread'] == true ? ink : muted,
                          fontWeight: m['unread'] == true
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        m['time'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: m['unread'] == true ? primary : muted,
                          fontSize: 11,
                          fontWeight: m['unread'] == true
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

class B2BChatRoomPage extends StatefulWidget {
  const B2BChatRoomPage({
    super.key,
    required this.merchant,
    this.highlightMediaId,
  });
  final Map<String, dynamic> merchant;
  final String? highlightMediaId;

  @override
  State<B2BChatRoomPage> createState() => _B2BChatRoomPageState();
}

class _B2BListPlaceholder extends StatelessWidget {
  const _B2BListPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          children: [
            Icon(
              Icons.handshake_outlined,
              size: 48,
              color: muted.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _B2BChatRoomPageState extends State<B2BChatRoomPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _mediaService = MediaService();

  // Advanced Messaging List
  final List<Map<String, dynamic>> _messages = [];
  StreamSubscription<LiveEvent>? _liveSub;

  // Advanced Features State
  Map<String, dynamic>? _replyContextMessage;

  // WhatsApp Style Multi-Selection & Floating Reactions State
  Map<String, dynamic>? _selectedMessageForOptions;
  final Set<Map<String, dynamic>> _selectedMessages = {};
  double? _emojiPopupY;
  double? _emojiPopupX;

  // In-Chat Message Search State
  bool _isSearching = false;
  String _chatSearchQuery = '';
  final FocusNode _searchFocusNode = FocusNode();

  // Real-time B2B Network Status
  final _networkService = NetworkService();
  StreamSubscription<bool>? _networkSub;
  Timer? _typingIdleTimer;
  Timer? _peerTypingTimer;
  bool _isOnline = true;
  bool _justCameOnline = false; // shows "Welcome back" banner briefly
  bool _peerTyping = false;
  String? _activeRoomId;
  bool _showJumpToBottom = false;
  int _newMessageCount = 0;

  @override
  void initState() {
    super.initState();
    // Start real network monitoring
    _networkService.start();
    _isOnline = _networkService.isOnline;
    _networkSub = _networkService.onStatusChange.listen((online) {
      if (!mounted) return;
      setState(() {
        _isOnline = online;
        if (online) {
          _justCameOnline = true;
          // Sync any queued offline messages
          for (final msg in _messages) {
            if (msg['status'] == 'sent_offline' && msg['isSent'] == true) {
              msg['status'] = 'sending';
              final msgId = msg['id'];
              Future.delayed(const Duration(milliseconds: 1500), () {
                if (!mounted) return;
                setState(() {
                  final idx = _messages.indexWhere((m) => m['id'] == msgId);
                  if (idx != -1 && _messages[idx]['status'] == 'sending') {
                    _messages[idx]['status'] = 'sent_online';
                  }
                });
              });
            }
          }
          // Hide "Welcome back" banner after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (!mounted) return;
            setState(() => _justCameOnline = false);
          });
        }
      });
    });
    liveSocketService.connect();
    _controller.addListener(_handleTypingChanged);
    _scrollController.addListener(_handleScrollPositionChanged);
    _liveSub = liveSocketService.events.listen(_handleLiveEvent);
    _loadChatHistory();
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _networkSub?.cancel();
    _typingIdleTimer?.cancel();
    _peerTypingTimer?.cancel();
    _networkService.stop();
    _controller.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleLiveEvent(LiveEvent event) {
    if (event.type == 'presence.update') {
      final userId = event.payload['userId']?.toString();
      if (userId == _targetSellerId && mounted) setState(() {});
      return;
    }
    if (event.type == 'chat.typing') {
      final sender = Map<String, dynamic>.from(
        event.payload['sender'] as Map? ?? {},
      );
      if (event.payload['roomId'] != _liveRoomId ||
          sender['id'] == authService.currentUser.value?.id) {
        return;
      }
      final isTyping = event.payload['isTyping'] != false;
      _setPeerTyping(isTyping);
      return;
    }
    if (event.type == 'chat.receipt' &&
        event.payload['roomId'] == _liveRoomId) {
      final status = event.payload['status']?.toString();
      if (status == null || !mounted) return;
      final receiptMessageId = event.payload['id']?.toString();
      setState(() {
        for (final message in _messages) {
          if (message['isSent'] != true ||
              message['type'] == 'deleted' ||
              message['type'] == 'payment_done')
            continue;
          if (receiptMessageId != null &&
              receiptMessageId.isNotEmpty &&
              message['id']?.toString() != receiptMessageId)
            continue;
          final currentStatus = message['status']?.toString();
          if (currentStatus == 'seen' && status != 'seen') continue;
          if (status == 'sent_online' &&
              currentStatus != 'sending' &&
              currentStatus != 'sent_offline')
            continue;
          message['status'] = status;
        }
      });
      return;
    }
    if (event.type == 'chat.deleted' &&
        event.payload['roomId'] == _liveRoomId) {
      _markMessageDeleted(event.payload['id']?.toString());
      return;
    }
    if (event.type == 'chat.reacted' &&
        event.payload['roomId'] == _liveRoomId) {
      _applyReaction(
        event.payload['id']?.toString(),
        event.payload['reaction']?.toString(),
      );
      return;
    }
    if (event.type != 'chat.message') return;
    if (event.payload['scope'] != 'b2b') return;

    final roomId = _liveRoomId;
    if (event.payload['roomId'] != roomId) return;

    final sender = Map<String, dynamic>.from(
      event.payload['sender'] as Map? ?? {},
    );

    final text = event.payload['text']?.toString().trim() ?? '';
    final type = event.payload['type']?.toString() ?? 'text';
    final mediaUrl = event.payload['mediaUrl']?.toString();
    final mediaName = event.payload['mediaName']?.toString();
    if (text.isEmpty && (mediaUrl == null || type == 'text')) return;
    if (!mounted) return;
    final id =
        event.payload['id']?.toString() ??
        'live-${DateTime.now().millisecondsSinceEpoch}';
    if (_messages.any((message) => message['id'] == id)) return;

    final sentAt = DateTime.tryParse(
      event.payload['createdAt']?.toString() ?? '',
    );
    final time = sentAt ?? DateTime.now();
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';

    setState(() {
      _messages.add({
        'id': id,
        'message': text.isNotEmpty ? text : _mediaLabel(type, mediaName),
        'time': '$hour:${time.minute.toString().padLeft(2, '0')} $period',
        'isSent': false,
        'type': type,
        'status': 'sent_online',
        'senderName': sender['name']?.toString(),
        'attachmentPath': mediaUrl,
        'mediaName': mediaName,
        'mediaMime': event.payload['mediaMime']?.toString(),
        'duration': event.payload['mediaDurationSeconds'] as int?,
        'reaction': event.payload['reaction']?.toString(),
      });
    });
    _handleIncomingMessagePlacement();
  }

  String? get _targetSellerId {
    final value = widget.merchant['sellerId']?.toString();
    return value == null || value.isEmpty ? null : value;
  }

  String get _defaultRoomId {
    final explicitRoom = widget.merchant['roomId']?.toString();
    final myId = authService.currentUser.value?.id ?? '';
    final targetId = _targetSellerId;
    if (myId.isNotEmpty && targetId != null) {
      final ids = [myId, targetId]..sort();
      return 'b2b:${ids[0]}:${ids[1]}';
    }
    if (explicitRoom != null && explicitRoom.isNotEmpty) return explicitRoom;
    return 'b2b:${widget.merchant['name']}';
  }

  String get _liveRoomId => _activeRoomId ?? _defaultRoomId;

  bool get _peerOnline {
    final targetId = _targetSellerId;
    return targetId != null && liveSocketService.isUserOnline(targetId);
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

    add(_defaultRoomId);
    add(widget.merchant['roomId']?.toString());
    final targetId = _targetSellerId;
    final myId = authService.currentUser.value?.id ?? '';
    if (myId.isNotEmpty && targetId != null) {
      final pair = [myId, targetId]..sort();
      add('b2b:${pair[0]}:${pair[1]}');
    }
    add('b2b:${widget.merchant['name']}');
    return ids;
  }

  void _handleTypingChanged() {
    final isTyping = _controller.text.trim().isNotEmpty;
    liveSocketService.sendChatTyping(
      roomId: _liveRoomId,
      scope: 'b2b',
      targetUserId: _targetSellerId,
      isTyping: isTyping,
    );
    _typingIdleTimer?.cancel();
    if (!isTyping) return;
    _typingIdleTimer = Timer(const Duration(milliseconds: 1200), () {
      liveSocketService.sendChatTyping(
        roomId: _liveRoomId,
        scope: 'b2b',
        targetUserId: _targetSellerId,
        isTyping: false,
      );
    });
  }

  void _sendTypingStopped() {
    liveSocketService.sendChatTyping(
      roomId: _liveRoomId,
      scope: 'b2b',
      targetUserId: _targetSellerId,
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

  String _formatChatTime(DateTime? value) {
    final time = (value ?? DateTime.now()).toLocal();
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
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
      'status': record.isMine
          ? (record.readAt != null
                ? 'seen'
                : record.deliveredAt != null
                ? 'sent_online'
                : record.deliveryStatus)
          : 'sent_online',
      'senderName': record.senderName,
      'attachmentPath': record.mediaUrl,
      'mediaName': mediaName,
      'mediaMime': record.mediaMime,
      'duration': record.mediaDurationSeconds,
      'reaction': record.reaction,
    };
  }

  Future<void> _loadChatHistory() async {
    var foundMessages = false;
    for (final roomId in _candidateRoomIds()) {
      try {
        final records = await chatHistoryService.listRoomMessages(roomId);
        if (!mounted) return;
        if (records.isEmpty) continue;
        setState(() {
          _activeRoomId = roomId;
          _messages
            ..clear()
            ..addAll(records.map(_messageFromRecord));
        });
        _scrollToInitialMediaTarget();
        liveSocketService.sendChatRead(roomId);
        foundMessages = true;
        return;
      } catch (_) {
        // Try the next known room key shape.
      }
    }
    if (!foundMessages && mounted) {
      setState(() => _messages.clear());
    }
  }

  void _scrollToBottom({bool animated = true}) {
    Future.delayed(const Duration(milliseconds: 150), () {
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

  void _showB2BPaymentSheet(BuildContext context) {
    final amountCtrl = TextEditingController();
    String selectedBank = 'SBI Bank'; // Default seller business account
    String enteredPin = '';
    bool isProcessing = false;
    bool showPinScreen = false;
    String errorMessage = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          void onKey(String val) {
            if (isProcessing) return;
            setModalState(() {
              errorMessage = '';
              if (val == '<') {
                if (enteredPin.isNotEmpty)
                  enteredPin = enteredPin.substring(0, enteredPin.length - 1);
              } else if (enteredPin.length < 4) {
                enteredPin += val;
                if (enteredPin.length == 4) {
                  isProcessing = true;
                  final double amt =
                      double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  final currentBalance =
                      globalBankBalances.value[selectedBank] ?? 0.0;

                  if (amt <= 0) {
                    isProcessing = false;
                    enteredPin = '';
                    errorMessage = 'Please enter a valid amount';
                    return;
                  }

                  if (currentBalance < amt) {
                    isProcessing = false;
                    enteredPin = '';
                    errorMessage = 'Insufficient bank balance';
                    return;
                  }

                  // Execute payment simulation
                  Future.delayed(const Duration(milliseconds: 1200), () {
                    isProcessing = false;

                    // Deduct from sender's balance
                    final map = Map<String, double>.from(
                      globalBankBalances.value,
                    );
                    map[selectedBank] = currentBalance - amt;
                    globalBankBalances.value = map;

                    // Play Cash Register chime
                    final oldTone = soundService.selectedTone.value;
                    soundService.selectedTone.value = 'Cash Register';
                    soundService.playSelectedTone().then((_) {
                      soundService.selectedTone.value = oldTone;
                    });

                    // Play TTS sound confirmation for receiver
                    soundService.speak(
                      "Payment of rupees ${amt.toStringAsFixed(0)} received successfully.",
                    );

                    // Log transaction to globalPaymentHistory
                    final currentTx = List<Map<String, dynamic>>.from(
                      globalPaymentHistory.value,
                    );
                    currentTx.insert(0, {
                      'merchant': widget.merchant['name'],
                      'date':
                          'Today, ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')} ${DateTime.now().hour >= 12 ? 'PM' : 'AM'}',
                      'amount': '-₹${amt.toStringAsFixed(2)}',
                      'items': 'B2B Bank Transfer',
                      'icon': Icons.swap_horiz_rounded,
                    });
                    globalPaymentHistory.value = currentTx;

                    Navigator.pop(ctx); // Close PIN sheet

                    // Send B2B confirmation message block
                    _handleSend(
                      customMessage:
                          'Paid ₹${amt.toStringAsFixed(2)} from $selectedBank via B2B Transfer.',
                      type: 'payment_done',
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Transferred ₹${amt.toStringAsFixed(2)} to ${widget.merchant['name']} successfully!',
                        ),
                        backgroundColor: success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  });
                }
              }
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 24,
              right: 24,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (!showPinScreen) ...[
                  Text(
                    'B2B Transfer to ${widget.merchant['name']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Deduct instantly from your business bank balance.',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      labelText: 'Enter Amount to Send',
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: primary, width: 2),
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Select Source Bank Account',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedBank,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    items: globalBankBalances.value.keys.map((bank) {
                      final balance = globalBankBalances.value[bank] ?? 0.0;
                      return DropdownMenuItem<String>(
                        value: bank,
                        child: Text(
                          '$bank (Bal: ₹${balance.toStringAsFixed(0)})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedBank = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  if (errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        errorMessage,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),

                  ElevatedButton(
                    onPressed: () {
                      final double amt =
                          double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                      if (amt <= 0) {
                        setModalState(() {
                          errorMessage = 'Please enter a valid amount';
                        });
                        return;
                      }
                      final currentBalance =
                          globalBankBalances.value[selectedBank] ?? 0.0;
                      if (currentBalance < amt) {
                        setModalState(() {
                          errorMessage = 'Insufficient bank balance';
                        });
                        return;
                      }
                      setModalState(() {
                        showPinScreen = true;
                        errorMessage = '';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Proceed to Pay',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Enter UPI PIN for $selectedBank',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paying ₹${double.tryParse(amountCtrl.text.trim())?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(color: muted, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (idx) {
                      final hasChar = idx < enteredPin.length;
                      return Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasChar ? primary : Colors.grey.shade300,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  if (errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Center(
                        child: Text(
                          errorMessage,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (isProcessing)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      childAspectRatio: 1.8,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        for (int i = 1; i <= 9; i++)
                          TextButton(
                            onPressed: () => onKey(i.toString()),
                            child: Text(
                              i.toString(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                          ),
                        const SizedBox(),
                        TextButton(
                          onPressed: () => onKey('0'),
                          child: const Text(
                            '0',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => onKey('<'),
                          icon: const Icon(
                            Icons.backspace_outlined,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleSend({
    String? customMessage,
    String type = 'text',
    String? attachmentPath,
    Map<String, dynamic>? extra,
  }) {
    final text = customMessage ?? _controller.text.trim();
    if (text.isEmpty && attachmentPath == null) return;

    final msgId = 'msg-${DateTime.now().millisecondsSinceEpoch}';
    final timeStr =
        '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')} ${DateTime.now().hour >= 12 ? 'PM' : 'AM'}';

    setState(() {
      for (final m in _messages) {
        if (m['isSent'] == false) {
          m['status'] = 'seen';
        }
      }
      _messages.add({
        'id': msgId,
        'message': text,
        'time': timeStr,
        'isSent': true,
        'type': type,
        'attachmentPath': attachmentPath,
        'mediaName': extra?['mediaName'],
        'mediaMime': extra?['mediaMime'],
        'duration': extra?['mediaDurationSeconds'] ?? extra?['duration'],
        'status': _isOnline ? 'sending' : 'sent_offline',
        'replyTo': _replyContextMessage != null
            ? _replyContextMessage!['message']
            : null,
      });
      _replyContextMessage = null;
    });

    if (customMessage == null) {
      _controller.clear();
    }
    _sendTypingStopped();
    _jumpToLatestMessages();

    // Delivery may be confirmed by the backend receipt; this fallback only
    // prevents a stuck spinner if that receipt arrives late.
    if (_isOnline) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == msgId);
          if (idx != -1 && _messages[idx]['status'] == 'sending') {
            _messages[idx]['status'] = 'sent_online';
          }
        });
      });
    }

    liveSocketService.sendChatMessage(
      id: msgId,
      roomId: _liveRoomId,
      scope: 'b2b',
      targetUserId: _targetSellerId,
      text: text,
      type: type,
      mediaUrl: attachmentPath,
      mediaName: extra?['mediaName']?.toString(),
      mediaMime: extra?['mediaMime']?.toString(),
      mediaSizeBytes: extra?['mediaSizeBytes'] as int?,
      mediaDurationSeconds:
          extra?['mediaDurationSeconds'] as int? ?? extra?['duration'] as int?,
    );
  }

  void _handleSendImage({
    required String customMessage,
    required String photoUrl,
    required Map<String, dynamic> params,
  }) {
    final msgId = 'msg-${DateTime.now().millisecondsSinceEpoch}';
    final timeStr =
        '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')} ${DateTime.now().hour >= 12 ? 'PM' : 'AM'}';

    setState(() {
      for (final m in _messages) {
        if (m['isSent'] == false) {
          m['status'] = 'seen';
        }
      }
      _messages.add({
        'id': msgId,
        'message': customMessage,
        'time': timeStr,
        'isSent': true,
        'type': 'photo',
        'attachmentPath': photoUrl,
        'editorParams': params,
        'status': _isOnline ? 'sending' : 'sent_offline',
        'replyTo': _replyContextMessage != null
            ? _replyContextMessage!['message']
            : null,
      });
      _replyContextMessage = null;
    });

    _jumpToLatestMessages();

    if (_isOnline) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == msgId);
          if (idx != -1 && _messages[idx]['status'] == 'sending') {
            _messages[idx]['status'] = 'sent_online';
          }
        });
      });
    }

    liveSocketService.sendChatMessage(
      id: msgId,
      roomId: _liveRoomId,
      scope: 'b2b',
      targetUserId: _targetSellerId,
      text: customMessage,
      type: 'image',
      mediaUrl: photoUrl,
      mediaName: params['mediaName']?.toString() ?? 'image.jpg',
      mediaMime: params['mediaMime']?.toString() ?? 'image/jpeg',
      mediaSizeBytes: params['mediaSizeBytes'] as int?,
    );
  }

  // Removed manual _toggleNetworkMode — replaced by real NetworkService

  Future<void> _showForwardDialog(List<Map<String, dynamic>> messages) async {
    final rooms = await chatHistoryService.listRooms(scope: 'b2b');
    if (!mounted) return;
    final targets = rooms.where((room) => room.roomId != _liveRoomId).toList();
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final filtered = targets.where((room) {
              final name = room.customerName?.isNotEmpty == true
                  ? room.customerName!
                  : (room.roomId.startsWith('b2b:')
                        ? room.roomId.substring('b2b:'.length)
                        : room.roomId);
              return name.toLowerCase().contains(query.toLowerCase());
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
                        hintText: 'Search B2B chats',
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
                            final name = room.customerName?.isNotEmpty == true
                                ? room.customerName!
                                : (room.roomId.startsWith('b2b:')
                                      ? room.roomId.substring('b2b:'.length)
                                      : room.roomId);
                            return ListTile(
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(room.lastMessage),
                              trailing: const Icon(Icons.send, color: primary),
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
      if (type == 'deleted' || type == 'payment_done') continue;
      final forwardedId = 'fwd-${DateTime.now().microsecondsSinceEpoch}';
      liveSocketService.sendChatMessage(
        id: forwardedId,
        roomId: room.roomId,
        scope: 'b2b',
        targetUserId: room.customerId,
        text: msg['message']?.toString() ?? '',
        type: type,
        mediaUrl: msg['attachmentPath']?.toString(),
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

  // ----------------------------------------------------
  // Swipe to Delete Dialog Trigger (LTR Swipe)
  // ----------------------------------------------------
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
                liveSocketService.sendChatDelete(
                  roomId: _liveRoomId,
                  messageId: msg['id']?.toString() ?? '',
                );
                setState(() => _applyDeletedState(msg));
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
    msg['attachmentPath'] = null;
    msg['mediaName'] = null;
    msg['mediaMime'] = null;
    msg['reaction'] = null;
  }

  String _mediaLabel(String type, String? mediaName) {
    if (type == 'image' || type == 'photo') return mediaName ?? 'Image';
    if (type == 'video') return mediaName ?? 'Video';
    if (type == 'pdf' || type == 'file') return mediaName ?? 'Document';
    if (type == 'voice') return mediaName ?? 'Voice note';
    if (type == 'deleted') return 'This message was deleted';
    return '';
  }

  // ----------------------------------------------------
  // Group Message Info Popup
  // ----------------------------------------------------
  void _showMessageInfo(Map<String, dynamic> msg) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        final bool isGroup = widget.merchant['isGroup'] == true;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Message Info',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: ink,
                ),
              ),
              const SizedBox(height: 16),
              // Message Preview card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F4F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg['message'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          msg['time'] ?? '',
                          style: const TextStyle(
                            fontSize: 10,
                            color: muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (isGroup) ...[
                const Text(
                  'READ BY (SEEN)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: primary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                _buildInfoMemberRow(
                  name: 'Gupta Organic Mart',
                  avatarColor: Colors.indigo,
                  statusText: 'Read at 10:52 AM',
                  isSeen: true,
                ),
                const SizedBox(height: 8),
                _buildInfoMemberRow(
                  name: 'Verma Grocery Depot',
                  avatarColor: Colors.teal,
                  statusText: 'Read at 10:55 AM',
                  isSeen: true,
                ),
                const SizedBox(height: 18),
                const Text(
                  'DELIVERED TO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: muted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                _buildInfoMemberRow(
                  name: 'Sharma Supermarket',
                  avatarColor: Colors.deepOrange,
                  statusText: 'Delivered at 10:50 AM',
                  isSeen: false,
                ),
              ] else ...[
                const Text(
                  'STATUS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: primary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                _buildInfoMemberRow(
                  name: widget.merchant['name'] ?? 'Partner',
                  avatarColor: widget.merchant['avatarColor'] ?? Colors.indigo,
                  statusText: msg['status'] == 'seen'
                      ? 'Read at ${msg['time']}'
                      : msg['status'] == 'sent_online'
                      ? 'Delivered at ${msg['time']}'
                      : 'Sent offline',
                  isSeen: msg['status'] == 'seen',
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoMemberRow({
    required String name,
    required Color avatarColor,
    required String statusText,
    required bool isSeen,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: avatarColor.withOpacity(0.15),
          child: Text(
            name[0],
            style: TextStyle(
              color: avatarColor,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                statusText,
                style: const TextStyle(
                  fontSize: 11,
                  color: muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.done_all,
          size: 16,
          color: isSeen ? primary : Colors.grey.shade400,
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // Interactive Voice, Video, and Attachments functions
  // ----------------------------------------------------
  void _startAudioVideoCall(bool isVideo) async {
    final phone = widget.merchant['phone']?.toString().trim() ?? '0000000000';
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the dialer.')),
        );
      }
    }
  }

  void _negotiateInventory() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Request Inventory Share',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Borrow stock instantly from ${widget.merchant['name']}',
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shopping_bag, color: primary),
                ),
                title: const Text(
                  'Fuji Apples (Surplus)',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Gupta Organic Mart • 20kg Available'),
                trailing: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handleSend(
                      customMessage:
                          'B2B STOCK REQUEST: Requested 5kg Fuji Apples. Direct settlement via DukaanZone Payout.',
                      type: 'special',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('B2B Inventory Borrow request sent!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Request 5kg'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.merchant['avatarColor'] as Color;
    final bool isSelectionModeActive = _selectedMessages.isNotEmpty;

    final bool isGroup = widget.merchant['isGroup'] == true;
    final bool sendMessagesOnlyAdmins =
        isGroup &&
        (widget.merchant['permissions']?['sendMessagesOnlyAdmins'] == true);
    final bool isUserAdmin = isGroup
        ? (widget.merchant['members'] as List<dynamic>?)?.any(
                (m) => m['name'] == 'You' && m['isAdmin'] == true,
              ) ??
              true
        : true;
    final bool isSendingLocked =
        isGroup && sendMessagesOnlyAdmins && !isUserAdmin;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,

      // WhatsApp Style Swap AppBar
      appBar: isSelectionModeActive
          ? AppBar(
              backgroundColor: primary, // DukaanZone Brand Primary Color
              elevation: 4,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() {
                  _selectedMessages.clear();
                  _selectedMessageForOptions = null;
                }),
              ),
              title: Text(
                '${_selectedMessages.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              actions: [
                if (_selectedMessages.length == 1)
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                    tooltip: 'Message Info',
                    onPressed: () {
                      _showMessageInfo(_selectedMessages.first);
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.reply_rounded, color: Colors.white),
                  tooltip: 'Reply',
                  onPressed: () {
                    if (_selectedMessages.isNotEmpty) {
                      setState(() {
                        _replyContextMessage = _selectedMessages.first;
                        _selectedMessages.clear();
                        _selectedMessageForOptions = null;
                      });
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.star_outline, color: Colors.white),
                  tooltip: 'Star Message',
                  onPressed: () {
                    setState(() {
                      _selectedMessages.clear();
                      _selectedMessageForOptions = null;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Messages starred!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_rounded, color: Colors.white),
                  tooltip: 'Delete Message',
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
                                      roomId: _liveRoomId,
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
                IconButton(
                  icon: const Icon(Icons.forward_rounded, color: Colors.white),
                  tooltip: 'Forward',
                  onPressed: () {
                    if (_selectedMessages.isNotEmpty) {
                      final msgs = _selectedMessages.toList();
                      setState(() {
                        _selectedMessages.clear();
                        _selectedMessageForOptions = null;
                      });
                      _showForwardDialog(msgs);
                    }
                  },
                ),
              ],
            )
          : _isSearching
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 1,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: ink),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _chatSearchQuery = '';
                  });
                },
              ),
              title: TextField(
                focusNode: _searchFocusNode,
                autofocus: true,
                onChanged: (val) {
                  setState(() {
                    _chatSearchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  border: InputBorder.none,
                  hintStyle: const TextStyle(
                    color: muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  suffixIcon: _chatSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: muted, size: 18),
                          onPressed: () {
                            setState(() {
                              _chatSearchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
                style: const TextStyle(
                  color: ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.white,
              leadingWidth: 40,
              title: GestureDetector(
                onTap: () {
                  push(
                    context,
                    B2BContactInfoPage(
                      merchant: widget.merchant,
                      messages: _messages,
                      onSearchClick: () {
                        setState(() {
                          _isSearching = true;
                        });
                        _searchFocusNode.requestFocus();
                      },
                      onStartVoiceCall: () => _startAudioVideoCall(false),
                      onStartVideoCall: () => _startAudioVideoCall(true),
                      isGroup: widget.merchant['isGroup'] == true,
                      groupData: widget.merchant,
                    ),
                  );
                },
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: ClipOval(
                        child: ProductImageView(
                          imageUrl: widget.merchant['avatarUrl']?.toString(),
                          fallbackIcon: Icons.storefront_outlined,
                          fallbackIconSize: 18,
                          fallbackColor: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.merchant['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: ink,
                            ),
                          ),
                          Text(
                            widget.merchant['isGroup'] == true
                                ? 'Group • ${widget.merchant['members']?.length ?? 4} participants'
                                : '${widget.merchant['owner']} • $_peerStatusLabel',
                            style: const TextStyle(
                              fontSize: 11,
                              color: muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (widget.merchant['isGroup'] == true)
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: primary),
                    tooltip: 'Group Details',
                    onPressed: () {
                      push(
                        context,
                        B2BContactInfoPage(
                          merchant: widget.merchant,
                          messages: _messages,
                          onSearchClick: () {
                            setState(() {
                              _isSearching = true;
                            });
                            _searchFocusNode.requestFocus();
                          },
                          onStartVoiceCall: () => _startAudioVideoCall(false),
                          onStartVideoCall: () => _startAudioVideoCall(true),
                          isGroup: true,
                          groupData: widget.merchant,
                        ),
                      );
                    },
                  ),
                if (widget.merchant['isGroup'] != true)
                  IconButton(
                    icon: const Icon(Icons.payment_outlined, color: primary),
                    tooltip: 'Pay Partner',
                    onPressed: () => _showB2BPaymentSheet(context),
                  ),
                IconButton(
                  icon: const Icon(Icons.videocam_outlined, color: primary),
                  onPressed: () => _startAudioVideoCall(true),
                ),
                IconButton(
                  icon: const Icon(Icons.phone_outlined, color: primary),
                  onPressed: () => _startAudioVideoCall(false),
                ),
                IconButton(
                  icon: const Icon(Icons.search, color: primary),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                    _searchFocusNode.requestFocus();
                  },
                ),
              ],
            ),

      body: Stack(
        children: [
          Column(
            children: [
              // 1. Real Network Status Banner
              _B2BNetworkBanner(
                isOnline: _isOnline,
                justCameOnline: _justCameOnline,
              ),

              // 2. Chat History
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_selectedMessages.isNotEmpty) {
                      setState(() {
                        _selectedMessages.clear();
                        _selectedMessageForOptions = null;
                      });
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: _messages.isEmpty
                      ? const _B2BEmptyChatState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(20),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final bool isSelected = _selectedMessages.contains(
                              msg,
                            );

                            final double opacity = _selectedMessages.isNotEmpty
                                ? (isSelected ? 1.0 : 0.35)
                                : 1.0;

                            return GestureDetector(
                              onTap: () {
                                if (_selectedMessages.isNotEmpty) {
                                  setState(() {
                                    _selectedMessageForOptions =
                                        null; // Close emoji tray on selecting another message
                                    if (isSelected) {
                                      _selectedMessages.remove(msg);
                                    } else {
                                      _selectedMessages.add(msg);
                                    }
                                  });
                                }
                              },
                              onLongPressStart: (details) {
                                setState(() {
                                  _emojiPopupY = details.globalPosition.dy;
                                  _emojiPopupX = details.globalPosition.dx;
                                  if (_selectedMessages.isNotEmpty) {
                                    if (isSelected) {
                                      _selectedMessages.remove(msg);
                                    } else {
                                      _selectedMessages.add(msg);
                                    }
                                  } else {
                                    _selectedMessages.add(msg);
                                    _selectedMessageForOptions = msg;
                                  }
                                });
                              },
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: opacity,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  color: isSelected
                                      ? primary.withOpacity(0.1)
                                      : Colors.transparent,
                                  alignment: msg['isSent'] == true
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Dismissible(
                                    key: Key(msg['id'].toString()),
                                    direction: DismissDirection.horizontal,
                                    background: Container(
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.only(left: 24),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withOpacity(
                                          0.15,
                                        ),
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
                                        color: Colors.blueAccent.withOpacity(
                                          0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.reply_rounded,
                                        color: Colors.blueAccent,
                                        size: 26,
                                      ),
                                    ),
                                    confirmDismiss: (direction) async {
                                      if (direction ==
                                          DismissDirection.startToEnd) {
                                        // Swipe LTR -> Delete
                                        _triggerDeleteOptions(msg);
                                      } else if (direction ==
                                          DismissDirection.endToStart) {
                                        // Swipe RTL -> Reply
                                        setState(() {
                                          _replyContextMessage = msg;
                                        });
                                      }
                                      return false; // Snaps back beautifully!
                                    },
                                    child: _B2BBubble(
                                      message: msg['message'],
                                      time: msg['time'],
                                      isSent: msg['isSent'] == true,
                                      type: msg['type'] ?? 'text',
                                      reaction: msg['reaction'],
                                      replyTo: msg['replyTo'],
                                      status: msg['status'] ?? 'seen',
                                      triggerSeenGlow:
                                          msg['triggerSeenGlow'] == true,
                                      highlight: _isHighlightedMedia(msg),
                                      editorParams: msg['editorParams'],
                                      attachmentPath: msg['attachmentPath'],
                                      duration: msg['duration'] as int?,
                                      highlightQuery: _isSearching
                                          ? _chatSearchQuery
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),

              ChatTypingWaveCue(visible: _peerTyping, color: primary),

              // Reply Context
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
                          _replyContextMessage!['message'],
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

              // 3. Media Input Bar
              isSendingLocked
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade100),
                        ),
                      ),
                      child: const Text(
                        'Only admins can send messages',
                        style: TextStyle(
                          color: muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : MediaInputBar(
                      controller: _controller,
                      hintText: 'Type B2B message...',
                      onSend: () => _handleSend(),
                      onMediaSent: (type, path, extra) {
                        _handleSend(
                          customMessage: extra?['caption']?.toString() ?? '',
                          type: type,
                          attachmentPath: path,
                          extra: extra,
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
                          roomId: _liveRoomId,
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

class _B2BEmptyChatState extends StatelessWidget {
  const _B2BEmptyChatState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: primary.withOpacity(.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.handshake_outlined,
                color: primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No B2B messages yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Send a message to create this room in the backend.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _B2BBubble extends StatefulWidget {
  const _B2BBubble({
    super.key,
    required this.message,
    required this.time,
    required this.isSent,
    this.reaction,
    required this.type,
    this.replyTo,
    this.highlightQuery,
    required this.status,
    required this.triggerSeenGlow,
    this.highlight = false,
    this.editorParams,
    this.attachmentPath,
    this.duration,
  });

  final String message;
  final String time;
  final bool isSent;
  final String? reaction;
  final String type;
  final String? replyTo;
  final String? highlightQuery;
  final String status;
  final bool triggerSeenGlow;
  final bool highlight;
  final Map<String, dynamic>? editorParams;
  final String? attachmentPath;
  final int? duration;

  @override
  State<_B2BBubble> createState() => _B2BBubbleState();
}

class _B2BBubbleState extends State<_B2BBubble> with TickerProviderStateMixin {
  AnimationController? _breathingController;
  Animation<double>? _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _breathingAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _breathingController!, curve: Curves.easeInOut),
    );

    if (widget.status == 'sending') {
      _breathingController!.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _B2BBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == 'sending') {
      if (!_breathingController!.isAnimating) {
        _breathingController!.repeat(reverse: true);
      }
    } else {
      _breathingController!.stop();
    }
  }

  @override
  void dispose() {
    _breathingController?.dispose();
    super.dispose();
  }

  Widget _buildMessageText(String text, TextStyle baseStyle, String? query) {
    if (query == null ||
        query.isEmpty ||
        !text.toLowerCase().contains(query.toLowerCase())) {
      return Text(text, style: baseStyle);
    }
    final List<TextSpan> spans = [];
    final String lowercaseText = text.toLowerCase();
    final String lowercaseQuery = query.toLowerCase();

    int start = 0;
    while (true) {
      final int index = lowercaseText.indexOf(lowercaseQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: const TextStyle(
            backgroundColor: Colors.amberAccent,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      start = index + query.length;
    }
    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
    );
  }

  // Tick marks removed — status communicated via bubble color instead.
  // Color system: grey=offline/queued, blue=sent/delivered, logo-green=seen.

  @override
  Widget build(BuildContext context) {
    final bool isDeleted = widget.type == 'deleted';
    final bool isSpecial = widget.type == 'special';

    // Status-based bubble color (replaces blue tick system)
    Color bubbleColor;
    if (!widget.isSent) {
      bubbleColor = const Color(0xFFF1F4F9); // received
    } else if (isSpecial) {
      bubbleColor = Colors.deepPurple.withOpacity(0.08);
    } else if (isDeleted) {
      bubbleColor = Colors.grey.shade100;
    } else {
      switch (widget.status) {
        case 'sent_offline':
          bubbleColor = const Color(0xFFB0BEC5); // grey — queued
          break;
        case 'sending':
          bubbleColor = const Color(0xFF90CAF9); // light blue — in transit
          break;
        case 'sent_online':
          bubbleColor = const Color(0xFF2196F3); // blue — delivered
          break;
        case 'seen':
          bubbleColor = primary; // brand blue — seen
          break;
        default:
          bubbleColor = primary;
      }
    }

    Color textColor = widget.isSent ? Colors.white : ink;
    TextStyle textStyle = const TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
    );

    if (isSpecial) {
      bubbleColor = Colors.deepPurple.withOpacity(0.08);
      textColor = Colors.deepPurple.shade900;
      textStyle = const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800);
    } else if (isDeleted) {
      bubbleColor = Colors.grey.shade100;
      textColor = muted;
      textStyle = const TextStyle(
        fontSize: 13,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
      );
    }

    final borderRadius = BorderRadius.circular(20).copyWith(
      bottomRight: widget.isSent ? const Radius.circular(4) : null,
      bottomLeft: !widget.isSent ? const Radius.circular(4) : null,
    );

    Widget bubbleBody = Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: borderRadius,
          child: AnimatedBuilder(
            animation: _breathingAnimation!,
            builder: (context, child) {
              // bubbleColor already encodes status; animate opacity slightly while sending
              Color finalColor = bubbleColor;
              if (widget.status == 'sending' && widget.isSent) {
                finalColor = bubbleColor.withOpacity(
                  0.6 + (_breathingAnimation!.value * 0.4),
                );
              }
              return Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                color: finalColor,
                child: child,
              );
            },
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Render Threaded Reply Attachment Inside Bubble
                  if (widget.replyTo != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isSent
                            ? Colors.white12
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Reply: ${widget.replyTo}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.isSent ? Colors.white70 : muted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // Special Attachment Type Rendering
                  if (widget.type == 'file' || widget.type == 'pdf')
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.insert_drive_file, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (widget.type == 'payment_done')
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: widget.isSent
                            ? Colors.black.withOpacity(0.2)
                            : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.isSent
                              ? Colors.white30
                              : const Color(0xFF10B981).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: widget.isSent
                                    ? Colors.white
                                    : const Color(0xFF10B981),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'B2B Transfer',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.message,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if ((widget.type == 'photo' || widget.type == 'image') &&
                      widget.attachmentPath != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 180,
                            width: double.infinity,
                            color: Colors.indigo.shade50,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final double cropScale =
                                    widget.editorParams?['cropScale']
                                        ?.toDouble() ??
                                    1.0;
                                final double rotation =
                                    widget.editorParams?['rotation']
                                        ?.toDouble() ??
                                    0.0;
                                final double brightness =
                                    widget.editorParams?['brightness']
                                        ?.toDouble() ??
                                    1.0;
                                final String activeFilter =
                                    widget.editorParams?['activeFilter']
                                        ?.toString() ??
                                    'None';

                                final bool canFilter =
                                    widget.attachmentPath!.startsWith('http') ||
                                    widget.attachmentPath!.startsWith(
                                      'data:image',
                                    ) ||
                                    !kIsWeb;

                                return ColorFiltered(
                                  colorFilter: _getColorFilter(activeFilter),
                                  child: ColorFiltered(
                                    colorFilter: ColorFilter.matrix([
                                      brightness,
                                      0,
                                      0,
                                      0,
                                      0,
                                      0,
                                      brightness,
                                      0,
                                      0,
                                      0,
                                      0,
                                      0,
                                      brightness,
                                      0,
                                      0,
                                      0,
                                      0,
                                      0,
                                      1,
                                      0,
                                    ]),
                                    child: Transform.rotate(
                                      angle: rotation,
                                      child: Transform.scale(
                                        scale: cropScale,
                                        child: canFilter
                                            ? ProductImageView(
                                                imageUrl: widget.attachmentPath,
                                                fallbackIcon:
                                                    Icons.image_outlined,
                                                defaultFit: BoxFit.cover,
                                              )
                                            : const Icon(
                                                Icons.image_outlined,
                                                color: muted,
                                                size: 48,
                                              ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        if (widget.message.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            widget.message,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    )
                  else if (widget.type == 'video' &&
                      widget.attachmentPath != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 180,
                            width: double.infinity,
                            color: Colors.black87,
                            child: const Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                color: Colors.white,
                                size: 64,
                              ),
                            ),
                          ),
                        ),
                        if (widget.message.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            widget.message,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    )
                  else if (widget.type == 'voice')
                    ChatVoiceNotePlayer(
                      audioUrl: widget.attachmentPath,
                      durationSeconds: widget.duration,
                      isSent: widget.isSent,
                    )
                  else
                    _buildMessageText(
                      widget.message,
                      textStyle.copyWith(color: textColor),
                      widget.highlightQuery,
                    ),

                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        widget.time,
                        style: TextStyle(
                          color: widget.isSent ? Colors.white70 : muted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Status shown via bubble color — no tick marks
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Reaction Badge Overlay (WhatsApp style bottom-right)
        if (widget.reaction != null)
          Positioned(
            bottom: -8,
            right: widget.isSent ? null : 12,
            left: widget.isSent ? 12 : null,
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
                widget.reaction!,
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
    );

    return BlinkingTargetHighlight(
      enabled: widget.highlight,
      borderRadius: BorderRadius.circular(24),
      child: bubbleBody,
    );
  }
}

class _B2BNetworkBanner extends StatefulWidget {
  final bool isOnline;
  final bool justCameOnline;

  const _B2BNetworkBanner({
    required this.isOnline,
    required this.justCameOnline,
  });

  @override
  State<_B2BNetworkBanner> createState() => _B2BNetworkBannerState();
}

class _B2BNetworkBannerState extends State<_B2BNetworkBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(_B2BNetworkBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  /// Only pulse when offline. Stop when online/hidden.
  void _syncAnimation() {
    final shouldPulse = !widget.isOnline;
    if (shouldPulse) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showBanner = !widget.isOnline || widget.justCameOnline;
    final bool isOffline = !widget.isOnline;
    final Color bgColor = isOffline
        ? const Color(0xFFEF4444)
        : const Color(0xFF10B981);
    final String text = isOffline
        ? 'Turn on your network to use B2B Chat'
        : '🎉 Welcome back! B2B Network Online';

    // Use AnimatedContainer that collapses to height:0 — keeps the widget
    // permanently in the tree so mouse_tracker stays consistent.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      height: showBanner ? 36 : 0,
      width: double.infinity,
      color: bgColor,
      clipBehavior: Clip.hardEdge,
      child: showBanner
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isOffline)
                  FadeTransition(
                    opacity: _pulseAnimation,
                    child: Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Flexible(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}

class B2BBreathingAvatar extends StatefulWidget {
  const B2BBreathingAvatar({
    super.key,
    required this.child,
    required this.hasGlow,
  });
  final Widget child;
  final bool hasGlow;

  @override
  State<B2BBreathingAvatar> createState() => _B2BBreathingAvatarState();
}

class _B2BBreathingAvatarState extends State<B2BBreathingAvatar>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _glowAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.hasGlow) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat(reverse: true);
      _glowAnimation = Tween<double>(
        begin: 2.0,
        end: 10.0,
      ).animate(CurvedAnimation(parent: _controller!, curve: Curves.easeInOut));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.hasGlow) return widget.child;

    return AnimatedBuilder(
      animation: _glowAnimation!,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.6),
                blurRadius: _glowAnimation!.value,
                spreadRadius: _glowAnimation!.value / 3,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

ColorFilter _getColorFilter(String filterName) {
  switch (filterName) {
    case 'Monochrome':
      return const ColorFilter.matrix([
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.0,
        0.0,
        0.0,
        1,
        0,
      ]);
    case 'Sepia':
      return const ColorFilter.matrix([
        0.393,
        0.769,
        0.189,
        0,
        0,
        0.349,
        0.686,
        0.168,
        0,
        0,
        0.272,
        0.534,
        0.131,
        0,
        0,
        0.0,
        0.0,
        0.0,
        1,
        0,
      ]);
    case 'Emerald Teal':
      return const ColorFilter.matrix([
        0.1,
        0.5,
        0.1,
        0,
        0,
        0.2,
        0.8,
        0.2,
        0,
        0,
        0.3,
        0.6,
        0.9,
        0,
        0,
        0.0,
        0.0,
        0.0,
        1,
        0,
      ]);
    default:
      return const ColorFilter.matrix([
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]);
  }
}
