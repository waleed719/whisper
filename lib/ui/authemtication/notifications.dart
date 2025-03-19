import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:platform/platform.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../screens/individual_chat_screen.dart';
// import 'package:googleapis_auth/auth_io.dart' as auth;
import 'dart:convert';

class Notifications {
  // Global key for navigation
  static final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();

  // Getter for the navigation key
  static GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  // Flutter local notifications plugin
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static const String _fcmEndpoint =
      'https://fcm.googleapis.com/v1/projects/whisper-204ee/messages:send';

  // Initialize Firebase and request permissions for notifications
  static Future<void> initialize() async {
    await Firebase.initializeApp();

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) {
        final String? payload = notificationResponse.payload;
        if (payload != null) {
          final Map<String, dynamic> data = jsonDecode(payload);
          BuildContext? context = _navigatorKey.currentState?.overlay?.context;
          if (context != null) {
            _handleMessageClick(RemoteMessage(data: data), context);
          }
        }
      },
    );

    // Request permissions for notifications
    await _requestPermissions();

    // Setup Firebase Cloud Messaging (FCM)
    await _setupFCM();

    // Background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Request notification permissions on iOS
  static Future<void> _requestPermissions() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    // NotificationSettings settings =
    await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    //   // print('Notification permission granted');
    // } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    //   // print('Provisional permission granted');
    // } else {
    //   // print('Notification permission declined');
    // }
  }

  // Setup Firebase Cloud Messaging (FCM)
  static Future<void> _setupFCM() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      _sendTokenToBackend(token);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen(_sendTokenToBackend);

    // Configure foreground notification presentation options
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    if (Platform.operatingSystemValues.toString() == 'android') {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
      );

      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // Handle incoming messages while the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // Handle notification clicks when the app is in the background or terminated
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      BuildContext? context = _navigatorKey.currentState?.overlay?.context;
      if (context != null) {
        _handleMessageClick(message, context);
      }
    });

    // Check if the app was opened from a notification
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(Duration(seconds: 1), () {
        BuildContext? context = _navigatorKey.currentState?.overlay?.context;
        if (context != null) {
          _handleMessageClick(initialMessage, context);
        }
      });
    }
  }

  // Send the FCM token to the backend server
  static Future<void> _sendTokenToBackend(String token) async {
    try {
      // final response =
      await http.post(
        Uri.parse(_fcmEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fcmToken': token}),
      );
      // if (response.statusCode == 200) {
      //   // print('Token sent to backend successfully');
      // } else {
      //   // print('Failed to send token to backend');
      // }
    } catch (e) {
      // print('Error sending token to backend: $e');
    }
  }

  // Show local notifications in the foreground
  static void _showLocalNotification(RemoteMessage message) {
    if (message.notification == null) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    _flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification!.title,
      message.notification!.body,
      platformDetails,
      payload: jsonEncode(message.data),
    );
  }

  // Handle notification click (navigate to the appropriate screen)
  static void _handleMessageClick(RemoteMessage message, BuildContext context) {
    if (message.data['type'] == 'chat') {
      String chatId = message.data['chatId'] ?? '';
      String recipientEmail = message.data['recipientEmail'] ?? '';

      if (chatId.isNotEmpty && recipientEmail.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => IndividualChatScreen(
              chatID: chatId,
              recipientEmail: recipientEmail,
            ),
          ),
        );
      }
    }
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  Notifications._showLocalNotification(message);
}
