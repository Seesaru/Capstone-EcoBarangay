import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';

class NotifServices {
  static const String _appId = "836b9037-820a-4906-acf5-6d3e36d3899e";
  static const String _authKey =
      "Bearer os_v2_app_qnvzan4cbjeqnlhvnu7dnu4jtzf3qlglqv6uvuud66q6t2jhbptcwnj5xd2j7t4twwf7zkv4aaj56b4pb4zukvhrqe2keczer4hcx6y";
  static const String _onesignalUrl =
      "https://onesignal.com/api/v1/notifications";

  static Future<void> sendBarangayNotification({
    required String barangay,
    required String heading,
    required String content,
    String? bigPicture,
  }) async {
    print("Attempting to send notification to barangay: $barangay");

    // Get active devices count before sending (for debugging)
    await _getDevicesByBarangay(barangay);

    final Map<String, dynamic> notificationData = {
      "app_id": _appId,
      "filters": [
        {
          "field": "tag",
          "key": "barangay",
          "relation": "=",
          "value": barangay,
        }
      ],
      "headings": {"en": heading},
      "contents": {"en": content},
    };

    if (bigPicture != null) {
      notificationData["big_picture"] = bigPicture;
    }

    try {
      print("Sending request to OneSignal API...");
      print("Notification data: ${jsonEncode(notificationData)}");

      final response = await http.post(
        Uri.parse(_onesignalUrl),
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Authorization": _authKey,
        },
        body: jsonEncode(notificationData),
      );

      if (response.statusCode == 200) {
        print(
            "Barangay notification sent successfully to $barangay: ${response.body}");
      } else {
        print(
            "Failed to send barangay notification: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Exception sending barangay notification: $e");
    }
  }

  // Add this method to check active devices with barangay tag
  static Future<void> _getDevicesByBarangay(String barangay) async {
    // Local check of user tags (will only show for current device)
    try {
      final tags = await OneSignal.User.getTags();
      print("Current device tags: $tags");
    } catch (e) {
      print("Error getting local tags: $e");
    }

    try {
      // This is an API call to OneSignal's view devices endpoint
      final response = await http.get(
        Uri.parse("https://onesignal.com/api/v1/players?app_id=$_appId"),
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Authorization": _authKey,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Total devices registered: ${data['total_count']}");

        // Try to count devices with this barangay tag
        int barangayDevices = 0;
        if (data['players'] != null) {
          for (var player in data['players']) {
            if (player['tags'] != null &&
                player['tags']['barangay'] == barangay) {
              barangayDevices++;
            }
          }
        }

        print("Devices with barangay tag '$barangay': $barangayDevices");
      } else {
        print(
            "Failed to get devices: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Exception getting devices: $e");
    }
  }

  static Future<void> sendIndividualNotification({
    required String playerId,
    required String heading,
    required String content,
    String? bigPicture,
  }) async {
    final Map<String, dynamic> notificationData = {
      "app_id": _appId,
      "include_player_ids": [playerId],
      "headings": {"en": heading},
      "contents": {"en": content},
    };

    if (bigPicture != null) {
      notificationData["big_picture"] = bigPicture;
    }

    try {
      final response = await http.post(
        Uri.parse(_onesignalUrl),
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Authorization": _authKey,
        },
        body: jsonEncode(notificationData),
      );

      if (response.statusCode == 200) {
        print("Individual notification sent successfully: ${response.body}");
      } else {
        print("Failed to send individual notification: ${response.body}");
      }
    } catch (e) {
      print("Exception sending individual notification: $e");
    }
  }

  static Future<void> sendBroadcastNotification({
    required String heading,
    required String content,
    String? bigPicture,
  }) async {
    print("Sending broadcast notification to ALL users");

    final Map<String, dynamic> notificationData = {
      "app_id": _appId,
      "included_segments": [
        "Subscribed Users"
      ], // This targets all subscribed users
      "headings": {"en": heading},
      "contents": {"en": content},
    };

    if (bigPicture != null) {
      notificationData["big_picture"] = bigPicture;
    }

    try {
      final response = await http.post(
        Uri.parse(_onesignalUrl),
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Authorization": _authKey,
        },
        body: jsonEncode(notificationData),
      );

      print("Broadcast response status: ${response.statusCode}");
      print("Broadcast response body: ${response.body}");

      if (response.statusCode == 200) {
        print("Broadcast notification sent successfully!");
      } else {
        print("Failed to send broadcast notification!");
      }
    } catch (e) {
      print("Exception sending broadcast notification: $e");
    }
  }

  // NEW: Send scheduled notification to specific barangay
  static Future<void> sendScheduledBarangayNotification({
    required String barangay,
    required String heading,
    required String content,
    required DateTime scheduledTime,
    required String scheduleId,
    String? bigPicture,
  }) async {
    print(
        "Scheduling notification for barangay: $barangay at ${scheduledTime.toIso8601String()}");

    final Map<String, dynamic> notificationData = {
      "app_id": _appId,
      "filters": [
        {
          "field": "tag",
          "key": "barangay",
          "relation": "=",
          "value": barangay,
        }
      ],
      "headings": {"en": heading},
      "contents": {"en": content},
      "send_after":
          scheduledTime.toIso8601String(), // Schedule the notification
      "data": {
        "schedule_id": scheduleId,
        "barangay": barangay,
        "type": "scheduled_collection",
      },
    };

    if (bigPicture != null) {
      notificationData["big_picture"] = bigPicture;
    }

    try {
      print("Sending scheduled notification request to OneSignal API...");
      print("Notification data: ${jsonEncode(notificationData)}");

      final response = await http.post(
        Uri.parse(_onesignalUrl),
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Authorization": _authKey,
        },
        body: jsonEncode(notificationData),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print("Scheduled notification created successfully!");
        print("Notification ID: ${responseData['id']}");
        print("Scheduled for: ${responseData['send_after']}");
      } else {
        print(
            "Failed to schedule notification: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Exception scheduling notification: $e");
    }
  }

  // NEW: Send immediate notification with custom data for better handling
  static Future<void> sendBarangayNotificationWithData({
    required String barangay,
    required String heading,
    required String content,
    Map<String, dynamic>? additionalData,
    String? bigPicture,
  }) async {
    print("Sending notification with data to barangay: $barangay");

    final Map<String, dynamic> notificationData = {
      "app_id": _appId,
      "filters": [
        {
          "field": "tag",
          "key": "barangay",
          "relation": "=",
          "value": barangay,
        }
      ],
      "headings": {"en": heading},
      "contents": {"en": content},
      "data": additionalData ?? {},
    };

    if (bigPicture != null) {
      notificationData["big_picture"] = bigPicture;
    }

    try {
      print("Sending request to OneSignal API...");
      print("Notification data: ${jsonEncode(notificationData)}");

      final response = await http.post(
        Uri.parse(_onesignalUrl),
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Authorization": _authKey,
        },
        body: jsonEncode(notificationData),
      );

      if (response.statusCode == 200) {
        print(
            "Notification with data sent successfully to $barangay: ${response.body}");
      } else {
        print(
            "Failed to send notification with data: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Exception sending notification with data: $e");
    }
  }
}
