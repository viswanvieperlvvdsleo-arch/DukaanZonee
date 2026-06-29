import 'dart:async';

import 'package:dukaan_zone_flutter/services/api_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationPayload {
  PushNotificationPayload({
    required this.title,
    required this.body,
    this.category,
    required this.data,
  });

  final String title;
  final String body;
  final String? category;
  final Map<String, dynamic> data;
}

@pragma('vm:entry-point')
Future<void> dukaanZoneFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase may already be initialized by the background isolate.
  }
}

class HardwareNotificationService {
  HardwareNotificationService._();

  static final HardwareNotificationService instance =
      HardwareNotificationService._();

  static const _channelId = 'dukaanzone_alerts';
  static const _channelName = 'DukaanZone alerts';

  final ValueNotifier<List<PushNotificationPayload>> receivedNotifications =
      ValueNotifier([]);
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;
  bool _localNotificationsReady = false;
  String? _fcmToken;
  String? _accountType;
  String? _accountId;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(
        dukaanZoneFirebaseMessagingBackgroundHandler,
      );
      await _initLocalNotifications();
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      _fcmToken = await FirebaseMessaging.instance.getToken();
      await _registerCurrentToken();

      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen((token) {
            _fcmToken = token;
            unawaited(_registerCurrentToken());
          });

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_rememberRemoteMessage);

      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _rememberRemoteMessage(initialMessage);
      }

      _initialized = true;
    } catch (error) {
      debugPrint('FCM disabled until Firebase config is added: $error');
    }
  }

  Future<void> bindAccount({
    required String accountType,
    required String accountId,
  }) async {
    _accountType = accountType;
    _accountId = accountId;
    if (!_initialized) {
      await init();
    } else {
      await _registerCurrentToken();
    }
  }

  Future<void> unregister() async {
    final token = _fcmToken;
    _accountType = null;
    _accountId = null;
    if (kIsWeb || token == null || token.isEmpty) return;
    try {
      await apiClient.deleteJsonWithResponse('/api/push/register');
    } catch (error) {
      debugPrint('Push token unregister failed: $error');
    }
  }

  Future<void> simulateIncomingHardwarePush({
    required String title,
    required String body,
    String? category,
  }) async {
    final payload = PushNotificationPayload(
      title: title,
      body: body,
      category: category,
      data: {'category': category ?? ''},
    );
    _storePayload(payload);
    await _showLocalNotification(payload);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final payload = _payloadFromRemoteMessage(message);
    _storePayload(payload);
    unawaited(_showLocalNotification(payload));
  }

  void _rememberRemoteMessage(RemoteMessage message) {
    _storePayload(_payloadFromRemoteMessage(message));
  }

  PushNotificationPayload _payloadFromRemoteMessage(RemoteMessage message) {
    final notification = message.notification;
    return PushNotificationPayload(
      title:
          notification?.title ??
          message.data['title']?.toString() ??
          'DukaanZone',
      body: notification?.body ?? message.data['body']?.toString() ?? '',
      category: message.data['category']?.toString(),
      data: Map<String, dynamic>.from(message.data),
    );
  }

  void _storePayload(PushNotificationPayload payload) {
    receivedNotifications.value = [payload, ...receivedNotifications.value];
  }

  Future<void> _registerCurrentToken() async {
    final token = _fcmToken;
    final accountType = _accountType;
    final accountId = _accountId;
    if (kIsWeb ||
        token == null ||
        token.isEmpty ||
        accountType == null ||
        accountId == null ||
        accountId.isEmpty) {
      return;
    }

    try {
      await apiClient.postJson('/api/push/register', {
        'token': token,
        'platform': defaultTargetPlatform.name,
        'deviceId': 'flutter-${defaultTargetPlatform.name}',
      });
    } catch (error) {
      debugPrint('Push token register failed: $error');
    }
  }

  Future<void> _initLocalNotifications() async {
    if (_localNotificationsReady) return;

    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initializationSettings = InitializationSettings(android: android);
    await _localNotifications.initialize(settings: initializationSettings);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Realtime DukaanZone notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _localNotificationsReady = true;
  }

  Future<void> _showLocalNotification(PushNotificationPayload payload) async {
    if (kIsWeb) return;
    await _initLocalNotifications();
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Realtime DukaanZone notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/launcher_icon',
    );
    const details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: payload.title,
      body: payload.body,
      notificationDetails: details,
      payload: payload.data.toString(),
    );
  }

  void dispose() {
    unawaited(_tokenRefreshSubscription?.cancel());
  }
}

final hardwareNotificationService = HardwareNotificationService.instance;
