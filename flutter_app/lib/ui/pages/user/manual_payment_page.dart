import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';
import 'package:dukaan_zone_flutter/ui/pages/shared/chat_scroll_cues.dart';
import 'package:dukaan_zone_flutter/ui/pages/shared/chat_typing_wave.dart';
import 'package:dukaan_zone_flutter/ui/pages/shared/chat_voice_note_player.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────
//  Message Status Color System
// ─────────────────────────────────────────────────────────────
Color _bubbleColorForStatus(String status, bool isSent) {
  if (!isSent) return const Color(0xFFF1F4F9);
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
//  USER PAYMENT — Shop List Page
// ─────────────────────────────────────────────────────────────
class ShopPaymentPage extends StatefulWidget {
  const ShopPaymentPage({super.key});

  @override
  State<ShopPaymentPage> createState() => _ShopPaymentPageState();
}

class _ShopPaymentPageState extends State<ShopPaymentPage> {
  // Track which shops have been removed from recents (by name)
  final Set<String> _hiddenFromRecents = {};
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<LiveEvent>? _liveSub;
  List<ChatRoomRecord> _recentRooms = const [];
  List<CompletedPayment> _history = const [];
  List<Shop> _backendShops = const [];
  bool _loading = true;
  String _query = '';
  String? _error;
  String? _debugError;

  @override
  void initState() {
    super.initState();
    liveSocketService.connect();
    _liveSub = liveSocketService.events.listen(_handleLiveEvent);
    _loadBackendData();
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleLiveEvent(LiveEvent event) {
    if ((event.type == 'chat.message' &&
            event.payload['scope'] == 'shop_payment') ||
        event.type == 'chat.receipt' ||
        event.type == 'presence.update') {
      _loadBackendData(showLoader: false);
    }
  }

  Future<void> _loadBackendData({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    List<ChatRoomRecord>? rooms;
    List<Shop>? shops;
    List<CompletedPayment>? history;

    try {
      rooms = await chatHistoryService.listRooms();
    } catch (_) {
      // Recent chats should not block shop discovery.
    }

    try {
      history = await paymentSessionService.history();
    } catch (_) {
      // History should not block shop discovery.
    }

    try {
      shops = await shopProfileService.listShops(query: _query);
    } catch (e, stack) {
      debugPrint('listShops error: $e\n$stack');
      _debugError = e.toString();
    }

    if (!mounted) return;
    setState(() {
      if (rooms != null) _recentRooms = rooms;
      if (shops != null) _backendShops = shops;
      if (history != null) _history = history;
      _loading = false;
      _error = rooms == null && shops == null
          ? 'Could not reach DukaanZone backend. $_debugError'
          : shops == null
          ? 'Could not load backend shops. $_debugError'
          : null;
    });
  }

  Shop _shopForRoom(ChatRoomRecord room) {
    final match = _backendShops.where(
      (shop) =>
          (room.shopId != null && shop.id == room.shopId) ||
          shop.name == room.shopName,
    );
    if (match.isNotEmpty) return match.first;
    return Shop(
      room.shopName ?? 'Shop',
      room.shopBlock ?? '',
      room.shopCategory ?? 'Live shop',
      '',
      '',
      const LatLng(0, 0),
      id: room.shopId,
      avatarUrl: room.shopAvatarUrl,
      sellerId: room.shopSellerId,
    );
  }

  ChatRoomRecord? _roomForShop(Shop shop) {
    for (final room in _recentRooms) {
      final sameId = shop.id != null && room.shopId == shop.id;
      final sameName =
          room.shopName != null &&
          room.shopName!.trim().toLowerCase() == shop.name.trim().toLowerCase();
      if (sameId || sameName) return room;
    }
    return null;
  }

  bool _isOwnShop(Shop shop) {
    final user = authService.currentUser.value;
    if (user == null) return false;
    final sameSellerId = shop.sellerId != null && shop.sellerId == user.id;
    final sameTestName =
        shop.name.trim().toLowerCase() == user.name.trim().toLowerCase();
    return sameSellerId || sameTestName;
  }

  Future<void> _openShopChat(Shop shop, Color color) async {
    await push(context, ShopPaymentChatPage(shop: shop, color: color));
    if (mounted) {
      _loadBackendData(showLoader: false);
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

  void _showShopOptions(
    BuildContext context,
    Shop shop, {
    ChatRoomRecord? room,
  }) {
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
                child: Icon(
                  Icons.remove_circle_outline_rounded,
                  color: Colors.red,
                ),
              ),
              title: const Text(
                'Remove from Recents',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.red,
                ),
              ),
              subtitle: const Text(
                'Hide this shop from your recents list',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                if (room != null) {
                  await chatHistoryService.hideRoom(room.roomId);
                }
                if (!mounted) return;
                setState(() => _hiddenFromRecents.add(shop.name));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${shop.name} hidden from your recents'),
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

  void _showAvatarFullScreen(BuildContext context, Shop shop, Color color) {
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
                color: color.withOpacity(0.2),
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Center(
                child: Text(
                  shop.name[0],
                  style: TextStyle(
                    color: color,
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
                shop.name,
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
    // Calculate most frequent shops from history
    final paymentCounts = <String, int>{};
    for (final p in _history) {
      if (p.shopName.isEmpty) continue;
      paymentCounts[p.shopName] = (paymentCounts[p.shopName] ?? 0) + 1;
    }
    final sortedShopNames = paymentCounts.keys.toList()
      ..sort((a, b) => paymentCounts[b]!.compareTo(paymentCounts[a]!));
    
    final frequentShops = <Shop>[];
    for (final name in sortedShopNames) {
      if (_hiddenFromRecents.contains(name)) continue;
      final match = _backendShops.where((s) => s.name.trim().toLowerCase() == name.trim().toLowerCase());
      if (match.isNotEmpty && !_isOwnShop(match.first)) {
        frequentShops.add(match.first);
      } else {
        // Find if we have a room for it to get the avatar
        final roomMatch = _recentRooms.where((r) => r.shopName?.trim().toLowerCase() == name.trim().toLowerCase());
        if (roomMatch.isNotEmpty && !_isOwnShop(_shopForRoom(roomMatch.first))) {
          frequentShops.add(_shopForRoom(roomMatch.first));
        }
      }
      if (frequentShops.length >= 4) break;
    }

    final lowerQuery = _query.toLowerCase();
    final visibleByIdentity = <String, Shop>{};
    for (final shop in _query.isEmpty ? const <Shop>[] : _backendShops) {
      if (_isOwnShop(shop)) continue;
      final matches =
          shop.name.toLowerCase().contains(lowerQuery) ||
          shop.type.toLowerCase().contains(lowerQuery) ||
          shop.block.toLowerCase().contains(lowerQuery) ||
          (shop.id ?? '').toLowerCase().contains(lowerQuery) ||
          (shop.upiId ?? '').toLowerCase().contains(lowerQuery) ||
          (shop.address ?? '').toLowerCase().contains(lowerQuery);
      if (!matches) continue;
      final key =
          '${shop.name.toLowerCase()}|${shop.type.toLowerCase()}|${shop.block.toLowerCase()}';
      visibleByIdentity.putIfAbsent(key, () => shop);
    }
    final visibleShops = visibleByIdentity.values.toList();
    final allShops =
        (_query.isEmpty ? _backendShops : visibleShops)
            .where((shop) => !_isOwnShop(shop))
            .toList()
          ..sort((a, b) {
            final aRoom = _roomForShop(a);
            final bRoom = _roomForShop(b);
            final aTime = aRoom?.updatedAt;
            final bTime = bRoom?.updatedAt;
            if (aTime != null && bTime != null) return bTime.compareTo(aTime);
            if (aTime != null) return -1;
            if (bTime != null) return 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

    return Scaffold(
      backgroundColor: Colors.white,
      body: AppPage(
        maxWidth: 800,
        children: [
          const PageTitle('Pay Shop', 'Scan or select a nearby shop.'),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F8),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFEFF2F5)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _query = value.trim());
                _loadBackendData(showLoader: false);
              },
              decoration: InputDecoration(
                icon: const Icon(Icons.search, color: muted),
                hintText: 'Search shops by name or ID',
                border: InputBorder.none,
                hintStyle: const TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w600,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                          _loadBackendData(showLoader: false);
                        },
                        icon: const Icon(Icons.clear, color: muted),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 32),
          const Kicker('FREQUENT SHOPS'),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (frequentShops.isNotEmpty)
            SizedBox(
              height: 126,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: frequentShops.length,
                itemBuilder: (context, i) {
                  final shop = frequentShops[i];
                  final room = _roomForShop(shop);
                  final color = [
                    Colors.blue,
                    Colors.purple,
                    Colors.green,
                  ][i % 3];
                  return RepaintBoundary(
                    child: GestureDetector(
                      onLongPress: () =>
                          _showShopOptions(context, shop, room: room),
                      child: _RecentShopTile(
                        shop: shop,
                        color: color,
                        room: room,
                        timeLabel: room != null ? _roomTime(room.updatedAt) : '',
                        onTap: () => _openShopChat(shop, color),
                        onAvatarTap: () =>
                            _showAvatarFullScreen(context, shop, color),
                      ),
                    ),
                  );
                },
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No recent shops',
                style: TextStyle(color: muted, fontWeight: FontWeight.w600),
              ),
            ),

          const SizedBox(height: 24),
          Kicker(_query.isEmpty ? 'ALL SHOPS' : 'SEARCH RESULTS'),
          const SizedBox(height: 12),
          if (!_loading && allShops.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                _error ??
                    (_query.isEmpty
                        ? 'No backend shops found yet.'
                        : 'No shops match this search.'),
                style: const TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            for (final shop in allShops)
              RepaintBoundary(
                child: _ShopListTile(
                  shop: shop,
                  room: _roomForShop(shop),
                  onTap: () => _openShopChat(shop, Colors.blue),
                ),
              ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _shopRowTime(DateTime? value) {
    if (value == null) return '';
    final now = DateTime.now();
    if (value.year == now.year &&
        value.month == now.month &&
        value.day == now.day) {
      final hour = value.hour == 0
          ? 12
          : (value.hour > 12 ? value.hour - 12 : value.hour);
      return '$hour:${value.minute.toString().padLeft(2, '0')} ${value.hour >= 12 ? 'PM' : 'AM'}';
    }
    return '${value.day}/${value.month}/${value.year}';
  }
}

class _RecentShopTile extends StatelessWidget {
  const _RecentShopTile({
    required this.shop,
    required this.color,
    required this.room,
    required this.timeLabel,
    required this.onTap,
    required this.onAvatarTap,
  });
  final Shop shop;
  final Color color;
  final ChatRoomRecord? room;
  final String timeLabel;
  final VoidCallback onTap;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            onLongPress: onAvatarTap,
            borderRadius: BorderRadius.circular(32),
            child: SizedBox(
              width: 68,
              height: 68,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ClipOval(
                      child: ProductImageView(
                        imageUrl: shop.avatarUrl ?? room?.shopAvatarUrl,
                        fallbackIcon: Icons.storefront_outlined,
                        fallbackIconSize: 28,
                        fallbackColor: color,
                      ),
                    ),
                  ),
                  if (room?.shopSellerOnline == true)
                    Positioned(
                      right: 1,
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
                  if ((room?.unreadCount ?? 0) > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: _UnreadBadge(count: room!.unreadCount),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 92,
            child: Column(
              children: [
                Text(
                  shop.name.split(' ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: ink,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  room?.lastMessage ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: (room?.unreadCount ?? 0) > 0 ? ink : muted,
                    fontSize: 10,
                    fontWeight: (room?.unreadCount ?? 0) > 0
                        ? FontWeight.w900
                        : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return SizedBox.square(
      dimension: 22,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopListTile extends StatelessWidget {
  const _ShopListTile({required this.shop, required this.onTap, this.room});
  final Shop shop;
  final VoidCallback onTap;
  final ChatRoomRecord? room;

  @override
  Widget build(BuildContext context) {
    final preview = room?.lastMessage.trim();
    final hasPreview = preview != null && preview.isNotEmpty;
    final unreadCount = room?.unreadCount ?? 0;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: ProductImageView(
                  imageUrl: shop.avatarUrl,
                  fallbackIcon: Icons.storefront_outlined,
                  fallbackIconSize: 22,
                  fallbackColor: primary,
                ),
              ),
            ),
            if (room?.shopSellerOnline == true)
              Positioned(
                right: 0,
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
            if (unreadCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: _UnreadBadge(count: unreadCount),
              ),
          ],
        ),
      ),
      title: Text(
        shop.name,
        style: const TextStyle(fontWeight: FontWeight.w900, color: ink),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasPreview ? preview! : '${shop.type} • ${shop.block}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: unreadCount > 0 ? ink : muted,
              fontWeight: unreadCount > 0 ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
          if (hasPreview && room?.updatedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _shopRowTime(room!.updatedAt),
                style: const TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      trailing: unreadCount > 0 ? _UnreadBadge(count: unreadCount) : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────
String _shopRowTime(DateTime? value) {
  if (value == null) return '';
  final now = DateTime.now();
  if (value.year == now.year &&
      value.month == now.month &&
      value.day == now.day) {
    final hour = value.hour == 0
        ? 12
        : (value.hour > 12 ? value.hour - 12 : value.hour);
    return '$hour:${value.minute.toString().padLeft(2, '0')} ${value.hour >= 12 ? 'PM' : 'AM'}';
  }
  return '${value.day}/${value.month}/${value.year}';
}

//  USER SHOP PAYMENT CHAT ROOM
// ─────────────────────────────────────────────────────────────
class ShopPaymentChatPage extends StatefulWidget {
  const ShopPaymentChatPage({
    super.key,
    required this.shop,
    required this.color,
    this.prefilledAmount,
    this.prefilledItems,
    this.completedPayment,
    this.highlightMediaId,
  });
  final Shop shop;
  final Color color;
  final double? prefilledAmount;
  final List<Map<String, dynamic>>? prefilledItems;
  final CompletedPayment? completedPayment;
  final String? highlightMediaId;

  @override
  State<ShopPaymentChatPage> createState() => _ShopPaymentChatPageState();
}

class _ShopPaymentChatPageState extends State<ShopPaymentChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _mediaService = MediaService();
  StreamSubscription<LiveEvent>? _liveSub;
  Timer? _typingIdleTimer;
  Timer? _peerTypingTimer;

  final List<Map<String, dynamic>> _history = [];
  /*
    {
      'amount': '₹120',
      'status': 'PAID',
      'time': '9:25 AM',
      'date': 'Today',
      'isSent': true,
      'type': 'payment',
      'items': 'Samosa Platter, Tea',
      'id': 'p0',
    },
  */
  final Set<Map<String, dynamic>> _selectedMessages = {};
  Map<String, dynamic>? _selectedMessageForOptions;
  Map<String, dynamic>? _replyContextMessage;
  double? _emojiPopupX;
  double? _emojiPopupY;
  bool _loadingHistory = true;
  bool _peerTyping = false;
  bool _showJumpToBottom = false;
  int _newMessageCount = 0;

  @override
  void initState() {
    super.initState();
    final payment = widget.completedPayment;
    if (payment != null) {
      _history.add(_paymentMessageFromCompleted(payment));
    } else if (widget.prefilledAmount != null && widget.prefilledAmount! > 0) {
      _controller.text = widget.prefilledAmount!.toStringAsFixed(2);
    }
    _controller.addListener(_handleTypingChanged);
    _scrollController.addListener(_handleScrollPositionChanged);
    liveSocketService.connect();
    _liveSub = liveSocketService.events.listen(_handleLiveEvent);
    _loadChatHistory();
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
    final index = _history.indexWhere(
      (message) => message['id']?.toString() == targetId,
    );
    if (index == -1 || _history.length <= 1) {
      _scrollToBottom(animated: false);
      return;
    }
    Future.delayed(const Duration(milliseconds: 160), () {
      if (!_scrollController.hasClients) return;
      final fraction = index / (_history.length - 1);
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
        final idx = _history.indexWhere((m) => m['id'] == msgId);
        if (idx != -1) _history[idx]['status'] = 'sent_online';
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() {
          final idx = _history.indexWhere((m) => m['id'] == msgId);
          if (idx != -1) _history[idx]['status'] = 'seen';
        });
      });
    });
  }

  String _timeNow() {
    final n = DateTime.now();
    return '${n.hour}:${n.minute.toString().padLeft(2, '0')} ${n.hour >= 12 ? 'PM' : 'AM'}';
  }

  String get _liveRoomId {
    final shopKey = widget.shop.id ?? widget.shop.name;
    final userId = authService.currentUser.value?.id;
    if (userId != null && userId.isNotEmpty) {
      return 'shop:$shopKey:user:$userId';
    }
    return 'shop:$shopKey';
  }

  List<String> _candidateRoomIds() {
    final ids = <String>[];
    void add(String? value) {
      if (value != null && value.isNotEmpty && !ids.contains(value)) {
        ids.add(value);
      }
    }

    final shopKey = widget.shop.id ?? widget.shop.name;
    final userId = authService.currentUser.value?.id;
    add(_liveRoomId);
    if (userId != null && userId.isNotEmpty) {
      add('shop:$shopKey:user:$userId');
    }
    add('shop:$shopKey');
    return ids;
  }

  String get _shopStatusLabel {
    return 'Live shop';
  }

  void _handleTypingChanged() {
    final isTyping = _controller.text.trim().isNotEmpty;
    liveSocketService.sendChatTyping(
      roomId: _liveRoomId,
      scope: 'shop_payment',
      shopId: widget.shop.id,
      isTyping: isTyping,
    );
    _typingIdleTimer?.cancel();
    if (!isTyping) return;
    _typingIdleTimer = Timer(const Duration(milliseconds: 1200), () {
      liveSocketService.sendChatTyping(
        roomId: _liveRoomId,
        scope: 'shop_payment',
        shopId: widget.shop.id,
        isTyping: false,
      );
    });
  }

  Map<String, dynamic> _paymentMessageFromCompleted(CompletedPayment payment) {
    final created = payment.createdAt;
    return {
      'id': payment.id,
      'amount': payment.amountLabel,
      'status': 'PAID',
      'time': _formatChatTime(created),
      'date': 'Today',
      'isSent': true,
      'type': 'payment',
      'items': payment.itemsLabel,
    };
  }

  String _formatChatTime(DateTime? value) {
    final n = (value ?? DateTime.now()).toLocal();
    final hour = n.hour == 0 ? 12 : (n.hour > 12 ? n.hour - 12 : n.hour);
    return '$hour:${n.minute.toString().padLeft(2, '0')} ${n.hour >= 12 ? 'PM' : 'AM'}';
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
      'date': 'Today',
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
    var loaded = false;
    for (final roomId in _candidateRoomIds()) {
      try {
        final records = await chatHistoryService.listRoomMessages(roomId);
        if (!mounted) return;
        if (records.isEmpty) continue;
        setState(() {
          _loadingHistory = false;
          final existingIds = _history.map((m) => m['id']?.toString()).toSet();
          for (final record in records) {
            if (existingIds.add(record.id)) {
              _history.add(_messageFromRecord(record));
            }
          }
        });
        _scrollToInitialMediaTarget();
        liveSocketService.sendChatRead(roomId);
        loaded = true;
        break;
      } catch (_) {
        // Try the next known room key shape.
      }
    }
    if (!loaded && mounted) {
      setState(() => _loadingHistory = false);
    }
  }

  void _sendTypingStopped() {
    liveSocketService.sendChatTyping(
      roomId: _liveRoomId,
      scope: 'shop_payment',
      shopId: widget.shop.id,
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
    setState(() {
      _history.add({
        'id': id,
        'message': text,
        'time': _timeNow(),
        'date': 'Today',
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
      roomId: _liveRoomId,
      scope: 'shop_payment',
      shopId: widget.shop.id,
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
    // Build the full set of roomIds this conversation could appear under
    final candidateRooms = _candidateRoomIds().toSet();
    final eventRoom = event.payload['roomId']?.toString();
    final roomMatches = eventRoom != null && candidateRooms.contains(eventRoom);

    if (event.type == 'chat.deleted') {
      if (roomMatches) {
        _markMessageDeleted(event.payload['id']?.toString());
      }
      return;
    }
    if (event.type == 'chat.reacted') {
      if (roomMatches) {
        _applyReaction(
          event.payload['id']?.toString(),
          event.payload['reaction']?.toString(),
        );
      }
      return;
    }
    if (event.type == 'presence.update') {
      return;
    }
    if (event.type == 'chat.typing') {
      final sender = Map<String, dynamic>.from(
        event.payload['sender'] as Map? ?? {},
      );
      if (!roomMatches ||
          sender['id'] == authService.currentUser.value?.id) {
        return;
      }
      final isTyping = event.payload['isTyping'] != false;
      _setPeerTyping(isTyping);
      return;
    }
    if (event.type != 'chat.message' ||
        event.payload['scope'] != 'shop_payment' ||
        !roomMatches) {
      return;
    }
    final sender = Map<String, dynamic>.from(
      event.payload['sender'] as Map? ?? {},
    );
    if (sender['id'] == authService.currentUser.value?.id) return;
    final text = event.payload['text']?.toString() ?? '';
    final type = event.payload['type']?.toString() ?? 'text';
    final mediaUrl = event.payload['mediaUrl']?.toString();
    if (text.isEmpty && (mediaUrl == null || type == 'text')) return;
    if (!mounted) return;
    final id =
        event.payload['id']?.toString() ??
        'live-${DateTime.now().millisecondsSinceEpoch}';
    if (_history.any((m) => m['id'] == id)) return;
    final mediaName = event.payload['mediaName']?.toString();
    setState(() {
      _history.add({
        'id': id,
        'message': text.isNotEmpty ? text : _mediaLabel(type, mediaName),
        'time': _timeNow(),
        'date': 'Today',
        'isSent': false,
        'type': type,
        'status': 'seen',
        'mediaPath': mediaUrl,
        'mediaName': mediaName,
        'mediaMime': event.payload['mediaMime']?.toString(),
        'duration': event.payload['mediaDurationSeconds'] as int?,
        'reaction': event.payload['reaction']?.toString(),
      });
    });
    _handleIncomingMessagePlacement();
    liveSocketService.sendChatRead(_liveRoomId);
  }

  void _applyReceipt(LiveEvent event) {
    if (event.payload['roomId'] != _liveRoomId || !mounted) return;
    final status = event.payload['status']?.toString();
    if (status == null) return;
    final id = event.payload['id']?.toString();
    setState(() {
      if (status == 'seen') {
        for (final message in _history) {
          if (message['isSent'] == true && _canReceiveReceipt(message)) {
            message['status'] = 'seen';
          }
        }
        return;
      }
      if (id == null) {
        for (final message in _history) {
          if (message['isSent'] == true &&
              _canReceiveReceipt(message) &&
              message['status'] != 'seen') {
            message['status'] = status;
          }
        }
        return;
      }
      final index = _history.indexWhere((message) => message['id'] == id);
      if (index != -1) {
        _history[index]['status'] = status;
      }
    });
  }

  Future<void> _processRealPayment(double amount) async {
    try {
      final payment = await paymentSessionService.completeCheckout(
        shop: widget.shop,
        amount: amount,
        selectedItems: widget.prefilledItems ?? [],
        provider: 'razorpay',
      );
      if (!mounted) return;

      final itemsLabel = payment.itemsLabel;
      final newTx = {
        'merchant': payment.shopName,
        'date': 'Today, ${_timeNow()}',
        'amount': payment.amountLabel,
        'items': itemsLabel,
        'icon': Icons.storefront_outlined,
      };
      
      globalPaymentHistory.value = [newTx, ...globalPaymentHistory.value];
      
      final id = 'pay-${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _history.add({
          'id': id,
          'amount': payment.amountLabel,
          'status': 'PAID',
          'time': _timeNow(),
          'date': 'Today',
          'isSent': true,
          'type': 'payment',
          'items': itemsLabel,
        });
        _newMessageCount++;
        _showJumpToBottom = true;
      });
      _controller.clear();
      _scrollToBottom();
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: $e')),
      );
    }
  }

  void _openQuickPayFromChat() {
    final amountController = TextEditingController();
    final targetLabel = widget.shop.upiId?.trim().isNotEmpty == true
        ? widget.shop.upiId!.trim()
        : (widget.shop.phone?.trim().isNotEmpty == true
              ? widget.shop.phone!.trim()
              : 'linked payment method');

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
              'Pay ${widget.shop.name} via $targetLabel',
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
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Enter a valid payment amount.'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  _processRealPayment(amount);
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
                _history.removeWhere((item) => item['id'] == msg['id']);
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
    if (type == 'call_log') return mediaName ?? '';
    if (type == 'deleted') return 'This message was deleted';
    return '';
  }

  void _deleteForEveryone(Map<String, dynamic> msg) {
    liveSocketService.sendChatDelete(
      roomId: _liveRoomId,
      messageId: msg['id']?.toString() ?? '',
    );
    setState(() => _applyDeletedState(msg));
  }

  void _markMessageDeleted(String? messageId) {
    if (messageId == null || !mounted) return;
    setState(() {
      final index = _history.indexWhere((item) => item['id'] == messageId);
      if (index != -1) _applyDeletedState(_history[index]);
    });
  }

  void _applyReaction(String? messageId, String? reaction) {
    if (messageId == null || !mounted) return;
    setState(() {
      final index = _history.indexWhere((item) => item['id'] == messageId);
      if (index != -1) _history[index]['reaction'] = reaction;
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
    if (_controller.text.isEmpty) return;
    final text = _controller.text;
    final isNumber = double.tryParse(text) != null;
    if (isNumber) {
      _showBankSelection('₹$text');
    } else {
      _sendMessage(text);
    }
  }

  Future<void> _showForwardDialog(List<Map<String, dynamic>> messages) async {
    final rooms = await chatHistoryService.listRooms();
    if (!mounted) return;
    final currentRoom = _liveRoomId;
    final targets = rooms.where((room) => room.roomId != currentRoom).toList();
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final filtered = targets.where((room) {
              final label = (room.shopName ?? room.roomId).toLowerCase();
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
                            final title = room.shopName ?? room.roomId;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: primary.withOpacity(.10),
                                child: const Icon(
                                  Icons.storefront_outlined,
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
      final text = msg['message']?.toString() ?? '';
      final forwardedId = 'fwd-${DateTime.now().microsecondsSinceEpoch}';
      liveSocketService.sendChatMessage(
        id: forwardedId,
        roomId: room.roomId,
        scope: room.scope,
        shopId: room.shopId,
        targetUserId: room.customerId,
        text: text,
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

  void _showAvatarFullScreen() {
    push(
      context,
      ChatContactInfoPage(
        title: widget.shop.name,
        subtitle: '${widget.shop.type} • ${widget.shop.block}',
        phone: widget.shop.upiId,
        avatarUrl: widget.shop.avatarUrl,
        fallbackColor: widget.color,
        fallbackIcon: Icons.storefront_outlined,
        messages: _history,
        roomId: _liveRoomId,
        scope: 'shop_payment',
        shopId: widget.shop.id,
      ),
    );
    if (mounted) return;
    final mediaItems = _history
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
          title: widget.shop.name,
          subtitle: '${widget.shop.type} • ${widget.shop.block}',
          imageUrl: widget.shop.avatarUrl,
          fallbackColor: widget.color,
          fallbackIcon: Icons.storefront_outlined,
          mediaItems: mediaItems,
        ),
      ),
    );
  }

  void _startHeaderCall(String kind) async {
    final phone = widget.shop.phone?.trim() ?? '0000000000';
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

  @override
  Widget build(BuildContext context) {
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
                                setState(() {
                                  for (final msg in selected) {
                                    if (msg['isSent'] == true) {
                                      _applyDeletedState(msg);
                                    } else {
                                      _history.removeWhere(
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
                                _history.removeWhere(
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
                          imageUrl: widget.shop.avatarUrl,
                          fallbackIcon: Icons.storefront_outlined,
                          fallbackIconSize: 18,
                          fallbackColor: widget.color,
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
                            widget.shop.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: ink,
                            ),
                          ),
                          Text(
                            '${widget.shop.type} • $_shopStatusLabel',
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
                  onPressed: () => _startHeaderCall('voice'),
                  icon: const Icon(Icons.phone_outlined, size: 22),
                ),
                IconButton(
                  onPressed: () => _startHeaderCall('video'),
                  icon: const Icon(Icons.videocam_outlined, size: 22),
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
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  itemCount: _loadingHistory || _history.isEmpty
                      ? 1
                      : _history.length,
                  cacheExtent: 400,
                  itemBuilder: (context, index) {
                    if (_loadingHistory) {
                      return const SizedBox(
                        height: 320,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (_history.isEmpty) {
                      return _EmptyChatState(shopName: widget.shop.name);
                    }
                    final item = _history[index];
                    final bool showDate =
                        index == 0 ||
                        _history[index]['date'] != _history[index - 1]['date'];
                    final isSelected = _selectedMessages.contains(item);
                    final normalizedType = item['type'] == 'payment_done'
                        ? 'payment'
                        : item['type'];

                    Widget messageWidget;
                    if (normalizedType == 'payment') {
                      messageWidget = _UserPaymentBubble(
                        amount: item['amount'],
                        status: item['status'],
                        time: item['time'],
                        isSent: item['isSent'],
                        items: item['items'],
                      );
                    } else {
                      messageWidget = GestureDetector(
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
                            child: _UserChatBubble(
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
                    }

                    return Column(
                      children: [
                        if (showDate)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              item['date'],
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        messageWidget,
                        const SizedBox(height: 16),
                      ],
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
                hintText: 'Enter amount or message',
                onSend: _handleSend,
                onPayTap: _openQuickPayFromChat,
                onMediaSent: (type, path, extra) {
                  final text =
                      extra?['caption'] ??
                      (type == 'voice'
                          ? '🎙 Voice Note'
                          : type == 'pdf'
                          ? '📄 Document'
                          : type == 'video'
                          ? '🎥 Video'
                          : '📷 Image');
                  _sendMessage(text, type: type, mediaPath: path, extra: extra);
                  _mediaService.saveToLocal(
                    type: type,
                    localPath: path,
                    sizeBytes: extra?['sizeBytes'] ?? 100000,
                    durationSeconds: extra?['duration'],
                    chatId: widget.shop.name,
                    chatName: widget.shop.name,
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

// ─────────────────────────────────────────────────────────────
//  User Chat Bubble (status-based colors)
// ─────────────────────────────────────────────────────────────
class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({required this.shopName});

  final String shopName;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.forum_outlined,
                  color: primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No messages with $shopName yet',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Send a message to start the real backend chat.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

class _UserChatBubble extends StatelessWidget {
  const _UserChatBubble({
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
  final String message, time, status, type;
  final bool isSent;
  final bool highlight;
  final String? mediaPath;
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
            style: const TextStyle(
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
    } else if (type == 'image') {
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
                height: 140,
                child: ProductImageView(
                  imageUrl: mediaPath,
                  fallbackIcon: Icons.image_rounded,
                  fallbackIconSize: 44,
                ),
              ),
            ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(message, style: TextStyle(color: textColor, fontSize: 12)),
          ],
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
            size: 30,
          ),
          const SizedBox(width: 8),
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
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
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
              constraints: const BoxConstraints(maxWidth: 240),
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
//  User Payment Bubble (no delete option on payment messages)
// ─────────────────────────────────────────────────────────────
class _UserPaymentBubble extends StatelessWidget {
  const _UserPaymentBubble({
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
    final bgColor = isSent ? const Color(0xFFEDE7F6) : const Color(0xFFF1F4F9);
    final statusColor = status == 'PAID' ? Colors.green : Colors.blue;

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isSent ? const Radius.circular(4) : null,
            bottomLeft: !isSent ? const Radius.circular(4) : null,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .03),
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
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check_circle, size: 14, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey.shade600,
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
                            'Transaction Details',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.receipt_long,
                              color: primary,
                            ),
                            title: const Text(
                              'Items Paid For',
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
                              'Transaction ID',
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
                  foregroundColor: primary,
                  side: BorderSide(color: primary.withValues(alpha: .3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'View Details',
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
