import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialised = false;

  static Future<void> init() async {
    if (_initialised) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialised = true;
  }

  static Future<void> showDisruptionAlert({
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'aegis_disruption', 'Disruption Alerts',
        channelDescription: 'Real-time disruption alerts from Aegis',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true, presentBadge: true, presentSound: true,
      ),
    );
    await _plugin.show(0, title, body, details);
  }

  static Future<void> showPayoutNotification({
    required double amount,
    required String trigger,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'aegis_payout', 'Payout Notifications',
        channelDescription: 'Aegis payout confirmations',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true, presentBadge: true, presentSound: true,
      ),
    );
    await _plugin.show(
      1,
      '₹${amount.toInt()} credited to your UPI',
      'Payout for $trigger disruption has been processed.',
      details,
    );
  }

  static Future<void> showClaimHeld(String reason) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'aegis_claim', 'Claim Updates',
        channelDescription: 'Claim status updates from Aegis',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true),
    );
    await _plugin.show(
      2, 'Claim under review', reason, details,
    );
  }
}

class Color {
  final int value;
  const Color(this.value);
}
