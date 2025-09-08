import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'onesignal_notif.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class ScheduleNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check for today's schedules and send notifications
  static Future<void> checkAndNotifyTodaySchedules() async {
    try {
      print('Checking for today\'s schedules...');
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      print('Current time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)}');

      // Get today's date as string for tracking notifications
      final String todayStr = DateFormat('yyyy-MM-dd').format(today);

      // Check if we've already sent notifications for today
      final bool alreadyNotified = prefs.getBool('notified_$todayStr') ?? false;
      print('Already sent today\'s notifications: $alreadyNotified');

      if (!alreadyNotified) {
        print('Querying Firestore for today\'s schedules...');
        // Query schedules for today
        final scheduleSnapshot = await _firestore
            .collection('schedule')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
            .where('date',
                isLessThan:
                    Timestamp.fromDate(today.add(const Duration(days: 1))))
            .get();

        print('Found ${scheduleSnapshot.docs.length} schedules for today');

        // Group schedules by barangay to send consolidated notifications
        final Map<String, List<QueryDocumentSnapshot>> schedulesByBarangay = {};

        for (var doc in scheduleSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final barangay = data['barangay'] as String;

          if (!schedulesByBarangay.containsKey(barangay)) {
            schedulesByBarangay[barangay] = [];
          }
          schedulesByBarangay[barangay]!.add(doc);
        }

        print('Grouped schedules by ${schedulesByBarangay.length} barangays');

        // Send notifications for each barangay
        for (var entry in schedulesByBarangay.entries) {
          final barangay = entry.key;
          final schedules = entry.value;

          print('Processing schedules for barangay: $barangay');

          // Create a consolidated message for all collections in this barangay
          String notificationContent = 'Today\'s waste collection schedule:\n';

          // Sort schedules by time
          schedules.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['startTime']
                as Map<String, dynamic>;
            final bTime = (b.data() as Map<String, dynamic>)['startTime']
                as Map<String, dynamic>;
            final aHour = aTime['hour'] as int;
            final bHour = bTime['hour'] as int;
            if (aHour != bHour) return aHour.compareTo(bHour);
            return (aTime['minute'] as int).compareTo(bTime['minute'] as int);
          });

          for (var schedule in schedules) {
            final data = schedule.data() as Map<String, dynamic>;
            final startTime = data['startTime'] as Map<String, dynamic>;
            final time = DateTime(
              now.year,
              now.month,
              now.day,
              startTime['hour'] as int,
              startTime['minute'] as int,
            );
            final wasteType = data['wasteType'] as String;
            final location = data['location'] as String;

            final timeStr = DateFormat('h:mm a').format(time);
            notificationContent +=
                '• $wasteType waste at $timeStr - $location\n';

            print('Added schedule: $wasteType at $timeStr');
          }

          print('Sending notification to barangay: $barangay');
          print('Notification content: $notificationContent');

          // Idempotency: Use a Firestore lock so only the first client sends
          final String lockDocId = 'daily_${todayStr}_$barangay';
          final DocumentReference lockRef =
              _firestore.collection('notification_locks').doc(lockDocId);

          await _firestore.runTransaction((txn) async {
            final snap = await txn.get(lockRef);
            if (snap.exists) {
              print(
                  'Daily notification already sent for $barangay on $todayStr');
              return;
            }

            // Create lock
            txn.set(lockRef, {
              'type': 'daily_schedule',
              'barangay': barangay,
              'date': todayStr,
              'created_at': FieldValue.serverTimestamp(),
            });

            // Send the notification to the barangay with data for better handling
            return NotifServices.sendBarangayNotificationWithData(
              barangay: barangay,
              heading: 'Waste Collection Today!',
              content: notificationContent.trim(),
              additionalData: {
                'type': 'daily_schedule',
                'barangay': barangay,
                'date': todayStr,
              },
              // Deterministic id so OneSignal dedupes if multiple requests race
              externalId: 'daily_${todayStr}_$barangay',
            );
          });
        }

        // Mark as notified for today
        await prefs.setBool('notified_$todayStr', true);
        print('Marked notifications as sent for today');
      }

      // Check for upcoming collections in the next hour
      await _checkUpcomingCollections();
    } catch (e) {
      print('Error checking and sending schedule notifications: $e');
    }
  }

  // Check for collections happening soon
  static Future<void> _checkUpcomingCollections() async {
    try {
      print('Checking for upcoming collections...');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final prefs = await SharedPreferences.getInstance();

      print('Querying Firestore for today\'s schedules (upcoming check)...');
      // Query today's schedules using the same range as above for consistency
      final scheduleSnapshot = await _firestore
          .collection('schedule')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .where('date',
              isLessThan:
                  Timestamp.fromDate(today.add(const Duration(days: 1))))
          .get();

      print('Found ${scheduleSnapshot.docs.length} schedules to check');

      for (var doc in scheduleSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final startTime = data['startTime'] as Map<String, dynamic>;
        final collectionTime = DateTime(
          now.year,
          now.month,
          now.day,
          startTime['hour'] as int,
          startTime['minute'] as int,
        );

        // Calculate time until collection
        final timeUntilCollection = collectionTime.difference(now);

        print(
            'Schedule at ${DateFormat('HH:mm').format(collectionTime)}, time until collection: ${timeUntilCollection.inMinutes} minutes');

        // If collection is within the next hour and we haven't notified yet
        if (timeUntilCollection.inMinutes > 0 &&
            timeUntilCollection.inMinutes <= 60) {
          final String scheduleId = doc.id;
          final String notifKey = 'upcoming_${scheduleId}';
          final bool alreadyNotified = prefs.getBool(notifKey) ?? false;

          print(
              'Schedule $scheduleId is within next hour, already notified: $alreadyNotified');

          if (!alreadyNotified) {
            final barangay = data['barangay'] as String;
            final wasteType = data['wasteType'] as String;
            final location = data['location'] as String;
            final timeStr = DateFormat('h:mm a').format(collectionTime);

            print(
                'Sending upcoming notification for $wasteType collection in ${timeUntilCollection.inMinutes} minutes');

            // Firestore lock to prevent duplicate upcoming notifications
            final String lockDocId = 'upcoming_${scheduleId}';
            final DocumentReference lockRef =
                _firestore.collection('notification_locks').doc(lockDocId);

            await _firestore.runTransaction((txn) async {
              final snap = await txn.get(lockRef);
              if (snap.exists) {
                print('Upcoming notification already sent for $scheduleId');
                return;
              }

              txn.set(lockRef, {
                'type': 'upcoming_collection',
                'schedule_id': scheduleId,
                'created_at': FieldValue.serverTimestamp(),
              });

              await NotifServices.sendBarangayNotificationWithData(
                barangay: barangay,
                heading: 'Upcoming Waste Collection!',
                content:
                    '$wasteType waste collection in ${timeUntilCollection.inMinutes} minutes!\nTime: $timeStr\nLocation: $location',
                additionalData: {
                  'type': 'upcoming_collection',
                  'schedule_id': scheduleId,
                  'barangay': barangay,
                  'waste_type': wasteType,
                  'location': location,
                  'time': timeStr,
                  'minutes_until': timeUntilCollection.inMinutes,
                },
                externalId: 'upcoming_${scheduleId}',
              );
            });

            // Mark this schedule as notified on this device
            await prefs.setBool(notifKey, true);
            print(
                'Marked upcoming notification as sent for schedule $scheduleId');
          }
        }
      }
    } catch (e) {
      print('Error checking upcoming collections: $e');
    }
  }

  // NEW: Schedule notifications for future dates using OneSignal's scheduled notifications
  static Future<void> scheduleFutureNotifications() async {
    try {
      print('Scheduling future notifications...');
      final now = DateTime.now();

      // Get schedules for the next 7 days
      final futureDate = now.add(const Duration(days: 7));

      final scheduleSnapshot = await _firestore
          .collection('schedule')
          .where('date', isGreaterThan: Timestamp.fromDate(now))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(futureDate))
          .get();

      print(
          'Found ${scheduleSnapshot.docs.length} future schedules to process');

      for (var doc in scheduleSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final scheduleDate = (data['date'] as Timestamp).toDate();
        final startTime = data['startTime'] as Map<String, dynamic>;
        final barangay = data['barangay'] as String;
        final wasteType = data['wasteType'] as String;
        final location = data['location'] as String;

        // Create the scheduled time (day before at 6 PM)
        final notificationTime = DateTime(
          scheduleDate.year,
          scheduleDate.month,
          scheduleDate.day - 1, // Day before
          18, // 6 PM
          0, // 0 minutes
        );

        // Only schedule if the notification time is in the future
        if (notificationTime.isAfter(now)) {
          print(
              'Scheduling notification for $wasteType on ${DateFormat('yyyy-MM-dd').format(scheduleDate)} at ${DateFormat('yyyy-MM-dd HH:mm').format(notificationTime)}');

          await _scheduleOneSignalNotification(
            barangay: barangay,
            heading: 'Waste Collection Tomorrow!',
            content:
                '$wasteType waste collection tomorrow at ${DateFormat('h:mm a').format(DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day, startTime['hour'], startTime['minute']))} - $location',
            scheduledTime: notificationTime,
            scheduleId: doc.id,
          );
        }
      }
    } catch (e) {
      print('Error scheduling future notifications: $e');
    }
  }

  // NEW: Schedule a notification using OneSignal's API
  static Future<void> _scheduleOneSignalNotification({
    required String barangay,
    required String heading,
    required String content,
    required DateTime scheduledTime,
    required String scheduleId,
  }) async {
    try {
      // Use OneSignal's REST API to schedule notifications
      await NotifServices.sendScheduledBarangayNotification(
        barangay: barangay,
        heading: heading,
        content: content,
        scheduledTime: scheduledTime,
        scheduleId: scheduleId,
      );
    } catch (e) {
      print('Error scheduling OneSignal notification: $e');
    }
  }

  // NEW: Method to handle background notification when app is closed
  static void handleBackgroundNotification(OSNotification notification) {
    print('Received background notification: ${notification.title}');
    print('Notification body: ${notification.body}');
    print('Notification data: ${notification.additionalData}');

    // You can add custom logic here to handle the notification
    // For example, navigate to a specific screen when notification is tapped
  }

  // Method to check schedules periodically
  static void startScheduleNotificationCheck() {
    print('Starting schedule notification service...');

    // Check immediately when started
    checkAndNotifyTodaySchedules();

    // Schedule future notifications
    scheduleFutureNotifications();

    // Check every 5 minutes
    Stream.periodic(const Duration(minutes: 5)).listen((_) {
      print('Periodic check triggered');
      checkAndNotifyTodaySchedules();
    });
  }

  // NEW: Test function to verify background notifications are working
  static Future<void> testBackgroundNotification() async {
    try {
      print('Testing background notification...');

      // Send a test notification that should appear even when app is closed
      await NotifServices.sendBarangayNotificationWithData(
        barangay: 'Test Barangay', // Replace with actual barangay for testing
        heading: 'Test Background Notification',
        content:
            'This is a test notification to verify background notifications are working!',
        additionalData: {
          'type': 'test_notification',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      print('Test notification sent successfully!');
    } catch (e) {
      print('Error sending test notification: $e');
    }
  }

  // NEW: Test scheduled notification
  static Future<void> testScheduledNotification() async {
    try {
      print('Testing scheduled notification...');

      // Schedule a notification for 1 minute from now
      final scheduledTime = DateTime.now().add(const Duration(minutes: 1));

      await NotifServices.sendScheduledBarangayNotification(
        barangay: 'Test Barangay', // Replace with actual barangay for testing
        heading: 'Test Scheduled Notification',
        content: 'This is a test scheduled notification!',
        scheduledTime: scheduledTime,
        scheduleId: 'test_schedule_${DateTime.now().millisecondsSinceEpoch}',
      );

      print(
          'Test scheduled notification created for: ${scheduledTime.toIso8601String()}');
    } catch (e) {
      print('Error scheduling test notification: $e');
    }
  }
}
