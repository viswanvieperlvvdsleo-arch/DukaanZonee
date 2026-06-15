import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dukaan_zone_flutter/dukaan.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<AppNotification>> _notificationsFuture;
  StreamSubscription<LiveEvent>? _liveSub;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = appNotificationService.list();
    liveSocketService.connect();
    _liveSub = liveSocketService.events.listen((event) {
      if (event.type == 'notification.created' ||
          event.type == 'payment.scan.started') {
        _reload();
        if (!mounted) return;
        final text = event.type == 'payment.scan.started'
            ? '${event.payload['userName'] ?? 'Customer'} scanned your shop QR'
            : event.payload['body']?.toString() ?? 'New notification';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
        );
      }
    });
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _notificationsFuture = appNotificationService.list();
    });
    await _notificationsFuture;
  }

  Future<void> _markAllAsRead() async {
    await appNotificationService.markAllRead();
    await _reload();
  }

  Future<void> _clearAll() async {
    await appNotificationService.clearAll();
    await _reload();
  }

  Future<void> _removeNotification(String id) async {
    await appNotificationService.remove(id);
    await _reload();
  }

  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead) return;
    await appNotificationService.markRead(notification.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<List<AppNotification>>(
          future: _notificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _NotificationEmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load notifications',
                subtitle: 'Check login and backend server.',
                action: _reload,
              );
            }

            final notifications = snapshot.data ?? const <AppNotification>[];
            if (notifications.isEmpty) {
              return const _NotificationEmptyState(
                icon: Icons.notifications_off_outlined,
                title: 'All caught up!',
                subtitle: 'New follower and shop alerts will appear here.',
              );
            }

            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                itemCount: notifications.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Expanded(
                            child: Text(
                              'Notifications',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: ink,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _markAllAsRead,
                            child: const Text('Mark read'),
                          ),
                          IconButton(
                            onPressed: _clearAll,
                            icon: const Icon(Icons.delete_sweep_outlined),
                            color: Colors.redAccent,
                            tooltip: 'Clear all',
                          ),
                        ],
                      ),
                    );
                  }

                  final item = notifications[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Dismissible(
                      key: Key(item.id),
                      direction: DismissDirection.horizontal,
                      onDismissed: (_) => _removeNotification(item.id),
                      background: _dismissBackground(false),
                      secondaryBackground: _dismissBackground(true),
                      child: _NotificationCard(
                        notification: item,
                        onTap: () => _markRead(item),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _dismissBackground(bool secondary) {
    return Container(
      alignment: secondary ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.redAccent),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isFollow = notification.type == 'shop_followed';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.isRead
              ? const Color(0xFFF7F9FC)
              : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: notification.isRead
                ? const Color(0xFFE5EAF1)
                : primary.withValues(alpha: .24),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: isFollow
                  ? const Icon(Icons.person_add_alt_1, color: primary)
                  : const Icon(Icons.notifications_none, color: primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: success,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if ((notification.body ?? '').isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      notification.body!,
                      style: const TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    _timeAgo(notification.createdAt),
                    style: const TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function()? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: muted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontWeight: FontWeight.w600),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: action,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _timeAgo(DateTime? value) {
  if (value == null) return 'Just now';
  final diff = DateTime.now().difference(value.toLocal());
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
  if (diff.inHours < 24) return '${diff.inHours} hours ago';
  if (diff.inDays == 1) return 'Yesterday';
  return '${diff.inDays} days ago';
}
