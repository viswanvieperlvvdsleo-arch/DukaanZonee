import 'dart:async';
import 'package:dukaan_zone_flutter/services/api_service.dart';

/// Represents a single media item tracked locally and queued for server sync.
class MediaItem {
  final String mediaId;       // UUID generated client-side for dedup
  final String type;          // 'image' | 'video' | 'pdf' | 'voice'
  final String localPath;     // Device filesystem path (or mock path for UI)
  String? serverUrl;          // Filled after upload
  String? serverId;           // DB row id after upload
  String uploadStatus;        // 'pending' | 'uploaded' | 'failed'
  final int sizeBytes;
  final DateTime createdAt;
  final int? durationSeconds; // Audio/video only
  String? thumbnail;          // Video only
  String? chatId;             // Which chat this belongs to
  String? chatName;
  String? scope;
  String? shopId;
  String? shopName;
  String? shopCategory;
  String? shopBlock;
  String? participantId;
  String? participantName;
  String? participantAvatarUrl;
  bool deletedFromDevice;

  MediaItem({
    required this.mediaId,
    required this.type,
    required this.localPath,
    this.serverUrl,
    this.serverId,
    this.uploadStatus = 'pending',
    required this.sizeBytes,
    DateTime? createdAt,
    this.durationSeconds,
    this.thumbnail,
    this.chatId,
    this.chatName,
    this.scope,
    this.shopId,
    this.shopName,
    this.shopCategory,
    this.shopBlock,
    this.participantId,
    this.participantName,
    this.participantAvatarUrl,
    this.deletedFromDevice = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'type': type,
        'localPath': localPath,
        'serverUrl': serverUrl,
        'serverId': serverId,
        'uploadStatus': uploadStatus,
        'sizeBytes': sizeBytes,
        'createdAt': createdAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'thumbnail': thumbnail,
        'chatId': chatId,
        'chatName': chatName,
        'scope': scope,
        'shopId': shopId,
        'shopName': shopName,
        'shopCategory': shopCategory,
        'shopBlock': shopBlock,
        'participantId': participantId,
        'participantName': participantName,
        'participantAvatarUrl': participantAvatarUrl,
        'deletedFromDevice': deletedFromDevice,
      };
}

/// Manages local media tracking with server-sync stubs.
/// All TODO comments mark exact integration points for backend.
class MediaService {
  static final MediaService _instance = MediaService._internal();
  factory MediaService() => _instance;
  MediaService._internal();

  final List<MediaItem> _items = [];
  final _changeController = StreamController<List<MediaItem>>.broadcast();

  Stream<List<MediaItem>> get onChanged => _changeController.stream;

  List<MediaItem> get all => List.unmodifiable(_items.where((i) => !i.deletedFromDevice).toList());

  List<MediaItem> byType(String type) =>
      _items.where((i) => i.type == type && !i.deletedFromDevice).toList();

  int get totalBytes =>
      _items.where((i) => !i.deletedFromDevice).fold(0, (sum, i) => sum + i.sizeBytes);

  int bytesByType(String type) => _items
      .where((i) => i.type == type && !i.deletedFromDevice)
      .fold(0, (sum, i) => sum + i.sizeBytes);

  Future<List<MediaItem>> loadFromServer() async {
    final data = await apiClient.getJson('/api/chats/media-storage');
    final items = (data['media'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) => _fromServer(Map<String, dynamic>.from(raw)))
        .toList();
    _items
      ..clear()
      ..addAll(items);
    _changeController.add(all);
    return all;
  }

  /// Save a new media item locally and queue for server upload.
  Future<MediaItem> saveToLocal({
    required String type,
    required String localPath,
    required int sizeBytes,
    int? durationSeconds,
    String? thumbnail,
    String? chatId,
    String? chatName,
  }) async {
    final item = MediaItem(
      mediaId: 'mid-${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      localPath: localPath,
      sizeBytes: sizeBytes,
      durationSeconds: durationSeconds,
      thumbnail: thumbnail,
      chatId: chatId,
      chatName: chatName,
      uploadStatus: 'pending',
    );
    _items.add(item);
    _changeController.add(all);
    _queueUpload(item); // fire-and-forget
    return item;
  }

  /// Remove item from device. Logs deletion for server sync.
  Future<void> deleteFromLocal(String mediaId) async {
    final idx = _items.indexWhere((i) => i.mediaId == mediaId);
    if (idx == -1) return;
    final serverMessageId = _items[idx].serverId;
    if (serverMessageId != null && serverMessageId.isNotEmpty) {
      await apiClient.deleteJson('/api/chats/media-storage/$serverMessageId');
    }
    _items[idx].deletedFromDevice = true;
    _changeController.add(all);
  }

  /// Clear all locally-deleted items from the in-memory list.
  void purgeDeleted() {
    _items.removeWhere((i) => i.deletedFromDevice);
    _changeController.add(all);
  }

  MediaItem _fromServer(Map<String, dynamic> raw) {
    final shop = Map<String, dynamic>.from(raw['shop'] as Map? ?? {});
    final participant = Map<String, dynamic>.from(
      raw['participant'] as Map? ?? {},
    );
    final type = raw['type']?.toString() ?? 'image';
    final messageId = raw['messageId']?.toString() ?? '';
    final name = raw['name']?.toString() ?? '$type-$messageId';
    return MediaItem(
      mediaId: messageId.isNotEmpty ? messageId : 'media-$name',
      type: type,
      localPath: name,
      serverUrl: raw['url']?.toString(),
      serverId: messageId,
      uploadStatus: 'uploaded',
      sizeBytes: _asInt(raw['sizeBytes']),
      createdAt: DateTime.tryParse(raw['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      durationSeconds: _asNullableInt(raw['durationSeconds']),
      chatId: raw['roomId']?.toString(),
      chatName: raw['chatName']?.toString(),
      scope: raw['scope']?.toString(),
      shopId: shop['id']?.toString(),
      shopName: shop['name']?.toString(),
      shopCategory: shop['category']?.toString(),
      shopBlock: shop['block']?.toString(),
      participantId: participant['id']?.toString(),
      participantName: participant['name']?.toString(),
      participantAvatarUrl: participant['avatarUrl']?.toString(),
    );
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _asNullableInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  Future<void> _queueUpload(MediaItem item) async {
    // TODO: Upload file at item.localPath to server
    // On success: item.serverUrl = response.url; item.serverId = response.id;
    //             item.uploadStatus = 'uploaded';
    // On failure: item.uploadStatus = 'failed'; schedule retry
    await Future.delayed(const Duration(seconds: 2));
    item.uploadStatus = 'uploaded';
    item.serverUrl = 'https://cdn.dukaanzone.com/media/${item.mediaId}';
    _changeController.add(all);
  }

}
