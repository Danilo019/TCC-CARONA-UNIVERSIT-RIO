// Serviço de notificações push usando Firebase Cloud Messaging
// Gerencia permissões, tokens FCM e notificações locais agendadas

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/ride.dart';
import '../models/user_preferences.dart';
import '../models/auth_user.dart';
import '../services/preferences_service.dart';

class NotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  static const _channelId = 'ride_updates_channel';
  static const _channelName = 'Atualizações de Carona';
  static const _channelDescription =
      'Alertas importantes sobre caronas e lembretes de saída';
  static const _newRidesTopic = 'new_rides';
  static const _reminderNotificationBaseId = 4000;
  static const _reminderLookAhead = Duration(days: 7);

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final PreferencesService _preferencesService = PreferencesService();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz.initializeTimeZones();
    try {
      final locationName = DateTime.now().timeZoneName;
      tz.setLocalLocation(tz.getLocation(locationName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(initializationSettings);

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    _initialized = true;
  }

  Future<void> applyPreferences(
    String userId,
    UserPreferences preferences,
  ) async {
    await initialize();

    if (preferences.receivePushNotifications) {
      final granted = await _ensurePushPermission();
      if (!granted) {
        throw Exception(
          'Permissão de notificações negada. Habilite nas configurações do sistema.',
        );
      }

      await FirebaseMessaging.instance.setAutoInitEnabled(true);

      final token = await _messaging.getToken();
      if (token != null) {
        await _addToken(userId, token);
      }

      if (preferences.alertNewRides) {
        await _messaging.subscribeToTopic(_newRidesTopic);
      } else {
        await _messaging.unsubscribeFromTopic(_newRidesTopic);
      }
    } else {
      await _messaging.setAutoInitEnabled(false);
      final token = await _messaging.getToken();
      if (token != null) {
        await _removeToken(userId, token);
        await _messaging.deleteToken();
      }
      await _messaging.unsubscribeFromTopic(_newRidesTopic);
    }

    if (preferences.remindUpcomingRide) {
      await refreshRideReminders(userId);
    } else {
      await cancelRideReminders();
    }
  }

  Future<void> refreshRideReminders(String userId) async {
    await initialize();

    final now = DateTime.now();
    final cutoff = now.add(_reminderLookAhead);

    final driverRides = await _fetchDriverRides(userId, now, cutoff);
    final passengerRides = await _fetchPassengerRides(userId, now, cutoff);

    final allRides = <Ride>{...driverRides, ...passengerRides}.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    await cancelRideReminders();

    for (final ride in allRides) {
      final reminderTime = ride.dateTime.subtract(const Duration(minutes: 15));
      if (reminderTime.isBefore(DateTime.now())) {
        continue;
      }

      final formattedTime =
          '${ride.dateTime.hour.toString().padLeft(2, '0')}:${ride.dateTime.minute.toString().padLeft(2, '0')}';

      await _scheduleNotification(
        id: _notificationIdFromRide(ride.id),
        title: 'Lembrete de carona',
        body:
            'Sua carona para ${ride.destination.address ?? 'o destino'} sai às $formattedTime. Prepare-se para partir!',
        dateTime: reminderTime,
      );
    }
  }

  Future<void> cancelRideReminders() async {
    await initialize();
    final platform = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (platform != null) {
      await platform.cancelAll();
    } else {
      await _localNotifications.cancelAll();
    }
  }

  Future<void> clearDeviceState(String? userId) async {
    if (userId == null) {
      return;
    }

    await initialize();
    final token = await _messaging.getToken();
    if (token != null) {
      await _removeToken(userId, token);
    }
    await _messaging.deleteToken();
    await cancelRideReminders();
    await _messaging.unsubscribeFromTopic(_newRidesTopic);
  }

  Future<void> refreshRemindersIfEnabled(String userId) async {
    try {
      final preferences = await _preferencesService.loadPreferences(userId);
      if (preferences.remindUpcomingRide) {
        await refreshRideReminders(userId);
      }
    } catch (error) {
      if (kDebugMode) {
        print('⚠ Não foi possível atualizar lembretes: $error');
      }
    }
  }

  Future<void> syncPreferencesForUser(AuthUser? user) async {
    if (user == null) {
      return;
    }

    try {
      final preferences = await _preferencesService.loadPreferences(user.uid);
      await applyPreferences(user.uid, preferences);
    } catch (error) {
      if (kDebugMode) {
        print('⚠ Falha ao sincronizar preferências de notificação: $error');
      }
    }
  }

  Future<bool> _ensurePushPermission() async {
    final settings = await _messaging.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      return true;
    }

    final requestResult = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      criticalAlert: false,
      provisional: true,
    );

    return requestResult.authorizationStatus ==
            AuthorizationStatus.authorized ||
        requestResult.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> _addToken(String userId, String token) {
    return _firestore.collection('users').doc(userId).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  Future<void> _removeToken(String userId, String token) {
    return _firestore.collection('users').doc(userId).set({
      'fcmTokens': FieldValue.arrayRemove([token]),
    }, SetOptions(merge: true));
  }

  Future<List<Ride>> _fetchDriverRides(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: userId)
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .where('status', isEqualTo: 'active')
          .get();

      return snapshot.docs.map((doc) => Ride.fromFirestore(doc)).toList();
    } catch (error) {
      if (kDebugMode) {
        print('⚠ Falha ao buscar caronas do motorista: $error');
      }
      return [];
    }
  }

  Future<List<Ride>> _fetchPassengerRides(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final requestSnapshot = await _firestore
          .collection('ride_requests')
          .where('passengerId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .get();

      if (requestSnapshot.docs.isEmpty) {
        return [];
      }

      final rideIds = requestSnapshot.docs
          .map((doc) => doc.data()['rideId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (rideIds.isEmpty) {
        return [];
      }

      final rides = <Ride>[];
      const batchSize = 10;
      for (var i = 0; i < rideIds.length; i += batchSize) {
        final chunk = rideIds.sublist(
          i,
          i + batchSize > rideIds.length ? rideIds.length : i + batchSize,
        );

        final snapshot = await _firestore
            .collection('rides')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in snapshot.docs) {
          final ride = Ride.fromFirestore(doc);
          if (ride.status == 'active' &&
              ride.dateTime.isAfter(start) &&
              ride.dateTime.isBefore(end)) {
            rides.add(ride);
          }
        }
      }

      return rides;
    } catch (error) {
      if (kDebugMode) {
        print('⚠ Falha ao buscar caronas aceitas para passageiro: $error');
      }
      return [];
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    final tzDateTime = tz.TZDateTime.from(dateTime, tz.local);
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
    );

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tzDateTime,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  int _notificationIdFromRide(String rideId) {
    final hash = rideId.hashCode & 0x7fffffff;
    return _reminderNotificationBaseId + (hash % 1000);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    _localNotifications.show(
      Random().nextInt(999999),
      notification.title,
      notification.body,
      const NotificationDetails(android: androidDetails),
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      print('Notificação aberta: ${message.data}');
    }
  }
}
