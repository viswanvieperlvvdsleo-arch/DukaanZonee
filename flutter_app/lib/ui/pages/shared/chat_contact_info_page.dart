import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class ChatContactInfoPage extends StatefulWidget {
  const ChatContactInfoPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.roomId,
    required this.scope,
    this.phone,
    this.avatarUrl,
    this.fallbackIcon = Icons.person_outline_rounded,
    this.fallbackColor = primary,
    this.messages = const [],
    this.shopId,
    this.targetUserId,
    this.onSearchClick,
  });

  final String title;
  final String subtitle;
  final String roomId;
  final String scope;
  final String? phone;
  final String? avatarUrl;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final List<Map<String, dynamic>> messages;
  final String? shopId;
  final String? targetUserId;
  final VoidCallback? onSearchClick;

  @override
  State<ChatContactInfoPage> createState() => _ChatContactInfoPageState();
}

class _ChatContactInfoPageState extends State<ChatContactInfoPage> {
  StreamSubscription<LiveEvent>? _liveSub;
  String? _activeCallId;
  String? _callStatus;

  @override
  void initState() {
    super.initState();
    liveSocketService.connect();
    _liveSub = liveSocketService.events.listen(_handleLiveEvent);
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }

  void _handleLiveEvent(LiveEvent event) {
    if (!event.type.startsWith('call.')) return;
    if (event.payload['roomId'] != widget.roomId) return;
    final id = event.payload['id']?.toString();
    if (_activeCallId != null && id != _activeCallId) return;
    if (!mounted) return;
    setState(() {
      _activeCallId = id ?? _activeCallId;
      _callStatus = event.payload['status']?.toString() ?? _callStatus;
    });
  }

  List<Map<String, dynamic>> get _mediaItems {
    return widget.messages.where((item) {
      final type = item['type']?.toString() ?? 'text';
      return ['image', 'photo', 'video', 'pdf', 'file', 'voice'].contains(type);
    }).toList();
  }

  int get _linkCount {
    return widget.messages.where((item) {
      final text = item['message']?.toString() ?? '';
      return text.contains('http://') ||
          text.contains('https://') ||
          text.contains('www.');
    }).length;
  }

  void _startCall(String kind) {
    final id = 'call-${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _activeCallId = id;
      _callStatus = 'ringing';
    });
    liveSocketService.sendCallStart(
      id: id,
      roomId: widget.roomId,
      scope: widget.scope,
      kind: kind,
      shopId: widget.shopId,
      targetUserId: widget.targetUserId,
    );
    _showCallSheet(kind);
  }

  void _endCall(String status) {
    final id = _activeCallId;
    if (id != null) {
      liveSocketService.sendCallEnd(id: id, status: status);
    }
    if (!mounted) return;
    setState(() {
      _callStatus = status;
      _activeCallId = null;
    });
  }

  void _showCallSheet(String kind) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 22),
                ClipOval(
                  child: SizedBox(
                    width: 86,
                    height: 86,
                    child: ProductImageView(
                      imageUrl: widget.avatarUrl,
                      fallbackIcon: widget.fallbackIcon,
                      fallbackColor: widget.fallbackColor,
                      fallbackIconSize: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${kind == 'video' ? 'Video' : 'Voice'} call - ${_callStatus ?? 'ringing'}',
                  style: const TextStyle(
                    color: muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _endCall('missed');
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.call_missed_rounded),
                        label: const Text('Missed'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _endCall('ended');
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.call_end_rounded),
                        label: const Text('End'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final cardColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E293B)
        : Colors.white;
    final textPrimary = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : ink;
    final border = Theme.of(context).brightness == Brightness.dark
        ? Colors.white10
        : const Color(0xFFE2E8F0);
    final mediaTotal = _mediaItems.length + _linkCount;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Contact info',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: textPrimary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile is managed in settings.'),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            children: [
              ClipOval(
                child: Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    color: widget.fallbackColor.withOpacity(.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.fallbackColor.withOpacity(.35),
                      width: 3,
                    ),
                  ),
                  child: ProductImageView(
                    imageUrl: widget.avatarUrl,
                    fallbackIcon: widget.fallbackIcon,
                    fallbackColor: widget.fallbackColor,
                    fallbackIconSize: 46,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if ((widget.phone ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.phone!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: _ContactActionButton(
                      icon: Icons.phone_outlined,
                      label: 'Voice',
                      cardColor: cardColor,
                      onTap: () => _startCall('voice'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ContactActionButton(
                      icon: Icons.videocam_outlined,
                      label: 'Video',
                      cardColor: cardColor,
                      onTap: () => _startCall('video'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ContactActionButton(
                      icon: Icons.search_rounded,
                      label: 'Search',
                      cardColor: cardColor,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onSearchClick?.call();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _InfoCard(
                cardColor: cardColor,
                border: border,
                child: Column(
                  children: [
                    _InfoTile(
                      icon: Icons.perm_media_outlined,
                      title: 'Media, links and docs',
                      trailingText: '$mediaTotal',
                      textColor: textPrimary,
                      onTap: () => push(
                        context,
                        B2BMediaDocsLinksPage(
                          merchant: {'name': widget.title},
                          messages: widget.messages,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 94,
                      child: mediaTotal == 0
                          ? const Center(
                              child: Text(
                                'No media, links, or docs shared.',
                                style: TextStyle(
                                  color: muted,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                              itemCount: _mediaItems.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final item = _mediaItems[index];
                                final type =
                                    item['type']?.toString() ?? 'image';
                                final path =
                                    item['mediaPath']?.toString() ??
                                    item['attachmentPath']?.toString();
                                return _MediaThumb(type: type, path: path);
                              },
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                cardColor: cardColor,
                border: border,
                child: Column(
                  children: [
                    _InfoTile(
                      icon: Icons.star_border_rounded,
                      title: 'Starred messages',
                      textColor: textPrimary,
                      onTap: () {},
                    ),
                    Divider(height: 1, color: border),
                    _InfoTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notification settings',
                      textColor: textPrimary,
                      onTap: () {},
                    ),
                    Divider(height: 1, color: border),
                    _InfoTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Encryption',
                      subtitle:
                          'Messages and calls are routed through DukaanZone secure realtime channels.',
                      textColor: textPrimary,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMediaSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Media, links and docs',
                style: TextStyle(
                  color: ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              if (_mediaItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Center(
                    child: Text(
                      'No shared media yet',
                      style: TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  itemCount: _mediaItems.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) {
                    final item = _mediaItems[index];
                    return _MediaThumb(
                      type: item['type']?.toString() ?? 'image',
                      path:
                          item['mediaPath']?.toString() ??
                          item['attachmentPath']?.toString(),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactActionButton extends StatelessWidget {
  const _ContactActionButton({
    required this.icon,
    required this.label,
    required this.cardColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color cardColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF10B981), size: 25),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(color: ink, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.cardColor,
    required this.border,
    required this.child,
  });

  final Color cardColor;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.textColor,
    this.subtitle,
    this.trailingText,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Color textColor;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: muted),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(color: muted, fontWeight: FontWeight.w600),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText!,
              style: const TextStyle(color: muted, fontWeight: FontWeight.w900),
            ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: muted),
        ],
      ),
    );
  }
}

class _MediaThumb extends StatelessWidget {
  const _MediaThumb({required this.type, required this.path});

  final String type;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final normalized = type == 'photo' ? 'image' : type;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        color: const Color(0xFFF1F4F9),
        child: normalized == 'image'
            ? ProductImageView(
                imageUrl: path,
                fallbackIcon: Icons.image_outlined,
              )
            : Icon(_iconFor(normalized), color: primary, size: 30),
      ),
    );
  }

  IconData _iconFor(String type) {
    return switch (type) {
      'video' => Icons.play_circle_outline_rounded,
      'pdf' || 'file' => Icons.picture_as_pdf_rounded,
      'voice' => Icons.mic_rounded,
      _ => Icons.insert_drive_file_outlined,
    };
  }
}
