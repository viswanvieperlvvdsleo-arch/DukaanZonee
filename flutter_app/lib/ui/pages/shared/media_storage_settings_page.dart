import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dukaan_zone_flutter/dukaan.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';


/// Storage Management Settings Screen.
/// Shows all media sent/received in DukaanZone chats.
/// Users can delete items from device storage here.
/// Server sync stubs are in MediaService — ready for backend wiring.
class MediaStorageSettingsPage extends StatefulWidget {
  const MediaStorageSettingsPage({super.key});

  @override
  State<MediaStorageSettingsPage> createState() => _MediaStorageSettingsPageState();
}

class _MediaStorageSettingsPageState extends State<MediaStorageSettingsPage>
    with SingleTickerProviderStateMixin {
  final _mediaService = MediaService();
  late TabController _tabController;
  StreamSubscription<List<MediaItem>>? _mediaSub;
  bool _isLoading = true;
  String? _error;

  final List<String> _types = ['All', 'Images', 'Videos', 'Voice', 'Docs'];
  final List<String> _typeKeys = ['all', 'image', 'video', 'voice', 'pdf'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _types.length, vsync: this);
    _mediaSub = _mediaService.onChanged.listen((_) {
      if (mounted) setState(() {});
    });
    _loadMedia();
  }

  @override
  void dispose() {
    _mediaSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMedia() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _mediaService.loadFromServer();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<MediaItem> _itemsForTab(int index) {
    final key = _typeKeys[index];
    if (key == 'all') return _mediaService.all.toList();
    return _mediaService.byType(key);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'image': return Icons.image_rounded;
      case 'video': return Icons.videocam_rounded;
      case 'voice': return Icons.mic_rounded;
      case 'pdf': return Icons.picture_as_pdf_rounded;
      default: return Icons.attach_file_rounded;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'image': return Colors.blue;
      case 'video': return Colors.deepPurple;
      case 'voice': return Colors.orange;
      case 'pdf': return Colors.red;
      default: return Colors.grey;
    }
  }

  Future<void> _deleteItem(MediaItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete from Device?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          'This will free up ${_formatBytes(item.sizeBytes)} on your device.\n\n'
          'The file will remain on DukaanZone servers so other chat members can still access it.',
          style: const TextStyle(color: muted, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _mediaService.deleteFromLocal(item.mediaId);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${_formatBytes(item.sizeBytes)} from device'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _openMediaChat(MediaItem item) {
    final roomId = item.chatId ?? '';
    if (roomId.isEmpty) return;
    final role = authService.currentRole.value;

    if (roomId.startsWith('b2b:')) {
      push(
        context,
        B2BChatRoomPage(
          highlightMediaId: item.serverId ?? item.mediaId,
          merchant: {
            'name': item.chatName ?? roomId.substring('b2b:'.length),
            'owner': 'B2B chat',
            'specialty': 'Media from storage',
            'avatarColor': primary,
          },
        ),
      );
      return;
    }

    if (role == Role.seller) {
      push(
        context,
        SellerChatRoomPage(
          highlightMediaId: item.serverId ?? item.mediaId,
          contact: {
            'name': item.participantName ?? item.chatName ?? 'Customer',
            'roomId': roomId,
            'userId': item.participantId,
            'shopId': item.shopId,
            'avatarColor': primary,
            'avatarUrl': item.participantAvatarUrl,
            'block': item.shopName == null ? 'Chat media' : 'From ${item.shopName}',
            'lastMessage': item.localPath,
            'time': 'Media',
            'unread': false,
            'unseenCount': 0,
          },
        ),
      );
      return;
    }

    final shop = Shop(
      item.shopName ?? item.chatName ?? 'Shop',
      item.shopBlock ?? '',
      item.shopCategory ?? 'Local shop',
      '0.0',
      '0',
      const LatLng(0, 0),
      id: item.shopId ?? roomId.replaceFirst('shop:', ''),
    );
    push(
      context,
      ShopPaymentChatPage(
        shop: shop,
        color: primary,
        highlightMediaId: item.serverId ?? item.mediaId,
      ),
    );
  }

  Future<void> _clearCategory(String typeKey) async {
    final items = typeKey == 'all' ? _mediaService.all : _mediaService.byType(typeKey);
    if (items.isEmpty) return;
    final totalSize = items.fold(0, (s, i) => s + i.sizeBytes);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          'This will delete ${items.length} item(s) — ${_formatBytes(totalSize)} — from your device.\n\n'
          'Files stay on DukaanZone servers.',
          style: const TextStyle(color: muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      for (final item in items) {
        await _mediaService.deleteFromLocal(item.mediaId);
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cleared ${_formatBytes(totalSize)} from device'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalBytes = _mediaService.totalBytes;
    final imageBytes = _mediaService.bytesByType('image');
    final videoBytes = _mediaService.bytesByType('video');
    final voiceBytes = _mediaService.bytesByType('voice');
    final pdfBytes = _mediaService.bytesByType('pdf');

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text('Storage Management', style: TextStyle(fontWeight: FontWeight.w900, color: ink, fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            indicatorColor: primary,
            labelColor: primary,
            unselectedLabelColor: muted,
            tabs: _types.map((t) => Tab(text: t)).toList(),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(),
          if (_error != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Could not load backend media. $_error',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(onPressed: _loadMedia, child: const Text('Retry')),
                ],
              ),
            ),
          // Storage Summary Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Media Storage', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  _formatBytes(totalBytes),
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _StoragePill(icon: Icons.image_rounded, label: 'Images', bytes: imageBytes, color: Colors.blue, formatBytes: _formatBytes),
                    const SizedBox(width: 8),
                    _StoragePill(icon: Icons.videocam_rounded, label: 'Videos', bytes: videoBytes, color: Colors.deepPurple, formatBytes: _formatBytes),
                    const SizedBox(width: 8),
                    _StoragePill(icon: Icons.mic_rounded, label: 'Voice', bytes: voiceBytes, color: Colors.orange, formatBytes: _formatBytes),
                    const SizedBox(width: 8),
                    _StoragePill(icon: Icons.picture_as_pdf_rounded, label: 'Docs', bytes: pdfBytes, color: Colors.red, formatBytes: _formatBytes),
                  ],
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: List.generate(_types.length, (tabIdx) {
                final typeKey = _typeKeys[tabIdx];
                final items = _itemsForTab(tabIdx);
                return Column(
                  children: [
                    if (items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${items.length} item(s)', style: const TextStyle(color: muted, fontWeight: FontWeight.w700, fontSize: 13)),
                            TextButton.icon(
                              onPressed: () => _clearCategory(typeKey),
                              icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: Colors.red),
                              label: const Text('Clear All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: items.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.folder_open_rounded, size: 56, color: muted.withOpacity(0.3)),
                                  const SizedBox(height: 12),
                                  const Text('No media stored', style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: items.length,
                              itemBuilder: (context, idx) {
                                final item = items[idx];
                                return _MediaStorageTile(
                                  item: item,
                                  typeIcon: _typeIcon(item.type),
                                  typeColor: _typeColor(item.type),
                                  formatBytes: _formatBytes,
                                  formatDuration: _formatDuration,
                                  onOpen: () => _openMediaChat(item),
                                  onDelete: () => _deleteItem(item),
                                );
                              },
                            ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoragePill extends StatelessWidget {
  const _StoragePill({
    required this.icon,
    required this.label,
    required this.bytes,
    required this.color,
    required this.formatBytes,
  });
  final IconData icon;
  final String label;
  final int bytes;
  final Color color;
  final String Function(int) formatBytes;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(height: 4),
            Text(formatBytes(bytes), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _MediaStorageTile extends StatelessWidget {
  const _MediaStorageTile({
    required this.item,
    required this.typeIcon,
    required this.typeColor,
    required this.formatBytes,
    required this.formatDuration,
    required this.onOpen,
    required this.onDelete,
  });
  final MediaItem item;
  final IconData typeIcon;
  final Color typeColor;
  final String Function(int) formatBytes;
  final String Function(int?) formatDuration;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = item.createdAt;
    final dateStr = '${date.day}/${date.month}/${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: shadowSm,
      ),
      child: ListTile(
        onTap: onOpen,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(typeIcon, color: typeColor, size: 22),
        ),
        title: Text(
          item.localPath.split('/').last,
          style: const TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${formatBytes(item.sizeBytes)}${item.durationSeconds != null ? ' • ${formatDuration(item.durationSeconds)}' : ''} • $dateStr',
              style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            if (item.chatName != null)
              Text(
                'from: ${item.chatName}',
                style: TextStyle(color: primary.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w700),
              ),
            Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.uploadStatus == 'uploaded' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.uploadStatus == 'uploaded' ? 'Server synced' : 'Syncing',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: item.uploadStatus == 'uploaded' ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
          onPressed: onDelete,
          tooltip: 'Delete from device',
        ),
      ),
    );
  }
}
