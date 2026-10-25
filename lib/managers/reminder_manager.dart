import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/daily_hunt.dart';
import 'save_manager.dart';

/// The Daily Hunt reminder: one notification an evening, for a hunt the
/// player has not played yet.
///
/// Scheduled a few days ahead and rebuilt every time the game opens, rather
/// than set to repeat forever. A player who plays sees no reminder for a day
/// they already played; a player who stops opening the game hears from it
/// [daysAhead] more times and then not again, which is the difference
/// between a reminder and nagging.
class ReminderManager {
  ReminderManager(this._save, {FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final SaveManager _save;
  final FlutterLocalNotificationsPlugin _plugin;

  /// Evenings ahead that carry a reminder.
  static const daysAhead = 3;

  /// The local hour a reminder arrives: after school and work, before bed.
  static const hour = 18;

  static const _channelId = 'daily_hunt';
  static const _firstId = 100;

  bool _ready = false;

  /// Android only for now: there is no iPhone build to test the iOS side on.
  bool get supported => !kIsWeb && Platform.isAndroid;

  Future<void> _init() async {
    if (_ready || !supported) {
      return;
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_findo'),
      ),
    );
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Asks Android 13 and later for permission to notify. True when the
  /// reminder can be shown.
  Future<bool> requestPermission() async {
    if (!supported) {
      return false;
    }
    try {
      await _init();
      await _save.markReminderAsked();
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (error) {
      _log('permission not asked: $error');
      return false;
    }
  }

  /// Turns the reminder on or off from Settings.
  Future<bool> setEnabled(
    bool value, {
    required String title,
    required String body,
  }) async {
    await _save.setDailyReminder(value);
    if (!value) {
      await _cancel();
      return false;
    }
    final allowed = await requestPermission();
    await reschedule(title: title, body: body);
    return allowed;
  }

  /// The evenings, from [now], that should carry a reminder.
  ///
  /// Today's is left out once it is past the hour, or once today's hunt has
  /// been played.
  @visibleForTesting
  static List<DateTime> evenings(DateTime now, {required bool playedToday}) {
    final out = <DateTime>[];
    for (var day = 0; out.length < daysAhead; day++) {
      final evening = DateTime(now.year, now.month, now.day + day, hour);
      if (day == 0 && (playedToday || !evening.isAfter(now))) {
        continue;
      }
      out.add(evening);
    }
    return out;
  }

  /// Rebuilds the reminders from scratch. Called when the game opens and when
  /// a hunt is played.
  Future<void> reschedule({required String title, required String body}) async {
    if (!supported) {
      return;
    }
    try {
      await _cancel();
      if (!_save.dailyReminder) {
        return;
      }
      final enabled = await _android?.areNotificationsEnabled() ?? false;
      if (!enabled) {
        return;
      }
      final now = DateTime.now();
      final played = _save.dailyStarted(DailyHunt.pacificDay(now));
      final times = evenings(now, playedToday: played);
      for (var i = 0; i < times.length; i++) {
        await _plugin.zonedSchedule(
          id: _firstId + i,
          // UTC, worked out from the phone's own clock now: the reminders are
          // rebuilt on every launch, so a change of clocks corrects itself.
          scheduledDate: tz.TZDateTime.from(times[i].toUtc(), tz.UTC),
          title: title,
          body: body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              'Daily Hunt',
              channelDescription: 'A reminder when a new Daily Hunt is waiting',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
          ),
          // Inexact: a reminder a few minutes late is fine, and exact alarms
          // need a permission Play reviews by hand.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (error) {
      _log('reminders not scheduled: $error');
    }
  }

  Future<void> _cancel() async {
    if (!supported) {
      return;
    }
    try {
      await _init();
      for (var i = 0; i < daysAhead; i++) {
        await _plugin.cancel(id: _firstId + i);
      }
    } catch (error) {
      _log('reminders not cancelled: $error');
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[reminder] $message');
    }
  }
}
