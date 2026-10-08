import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/orders/order_chat_screen.dart';
import '../../firebase_options.dart';
import '../api/api_client.dart';
import '../calls/call_manager.dart';

/// Arifa (push notifications) kupitia Firebase Cloud Messaging
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  /// Inaruhusu kufungua chat kutoka kwenye arifa, popote app ilipo
  static final navigatorKey = GlobalKey<NavigatorState>();

  static const _channel = AndroidNotificationChannel(
    'designbora_default',
    'DesignBora',
    description: 'Arifa za oda, malipo na ujumbe',
    importance: Importance.high,
  );

  final _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _token;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    if (!_supported || _initialized) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null) {
            _openFromData(jsonDecode(payload) as Map<String, dynamic>);
          }
        },
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);

      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _openFromData(message.data),
      );
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _token = token;
        _sendToken(token);
      });
      WidgetsBinding.instance.addObserver(CallManager.instance);
      _initialized = true;
    } catch (e) {
      debugPrint('Arifa hazikuwashwa: $e');
    }
  }

  /// Baada ya login: omba ruhusa ya arifa na usajili simu hii kwenye backend
  Future<void> registerDevice() async {
    CallManager.instance.startListening();
    if (!_initialized) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      _token = token;
      await _sendToken(token);

      // App ilifunguliwa kwa kubonyeza arifa ikiwa imefungwa kabisa
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        Future.delayed(
          const Duration(milliseconds: 1500),
          () => _openFromData(initial.data),
        );
      }
    } catch (e) {
      debugPrint('Usajili wa arifa umeshindwa: $e');
    }
  }

  /// Logout: simu hii isipokee arifa za mtumiaji huyu tena
  Future<void> unregisterDevice() async {
    CallManager.instance.stopListening();
    final token = _token;
    if (!_initialized || token == null) return;
    try {
      await ApiClient().dio.delete('/devices', data: {'token': token});
    } catch (_) {
      // Si muhimu - token itafutwa yenyewe ikikufa
    }
  }

  Future<void> _sendToken(String token) async {
    try {
      await ApiClient().dio.post(
        '/devices',
        data: {'token': token, 'platform': 'android'},
      );
    } catch (e) {
      debugPrint('Token ya arifa haikutumwa: $e');
    }
  }

  /// App ikiwa wazi, Android haionyeshi arifa yenyewe - tunaionyesha sisi
  void _showForeground(RemoteMessage message) {
    if (_isIncomingCall(message.data, message.notification?.title)) {
      CallManager.instance.checkIncoming(); // fungua skrini ya simu
      return;
    }
    final notification = message.notification;
    if (notification == null) return;
    _local.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  bool _isIncomingCall(Map<String, dynamic> data, String? title) =>
      data['type'] == 'INCOMING_CALL' || (title ?? '').contains('anakupigia');

  void _openFromData(Map<String, dynamic> data) {
    if (_isIncomingCall(data, null)) {
      CallManager.instance.checkIncoming(); // kutoka arifa
      return;
    }
    final orderId = int.tryParse('${data['orderId'] ?? ''}');
    final navigator = navigatorKey.currentState;
    if (orderId == null || navigator == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => OrderChatScreen(
          orderId: orderId,
          designerName: '${data['otherName'] ?? 'DesignBora'}',
          serviceTitle: '${data['serviceTitle'] ?? 'Oda #$orderId'}',
        ),
      ),
    );
  }
}
