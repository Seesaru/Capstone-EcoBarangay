import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'onesignal_notif.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

          // Send the notification to the barangay
          await NotifServices.sendBarangayNotification(
            barangay: barangay,
            heading: 'Waste Collection Today!',
            content: notificationContent.trim(),
          );
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
      // Query today's schedules
      final scheduleSnapshot = await _firestore
          .collection('schedule')
          .where('date', isEqualTo: Timestamp.fromDate(today))
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

            await NotifServices.sendBarangayNotification(
              barangay: barangay,
              heading: 'Upcoming Waste Collection!',
              content:
                  '$wasteType waste collection in ${timeUntilCollection.inMinutes} minutes!\nTime: $timeStr\nLocation: $location',
            );

            // Mark this schedule as notified
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

  // Method to check schedules periodically
  static void startScheduleNotificationCheck() {
    print('Starting schedule notification service...');

    // Check immediately when started
    checkAndNotifyTodaySchedules();

    // Check every 5 minutes
    Stream.periodic(const Duration(minutes: 5)).listen((_) {
      print('Periodic check triggered');
      checkAndNotifyTodaySchedules();
    });
  }
}
