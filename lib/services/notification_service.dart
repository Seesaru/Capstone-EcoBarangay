import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Creates a notification record in the notifications collection
  /// This provides a centralized way to track all system notifications
  static Future<void> createNotification({
    required String type,
    required String title,
    required String content,
    required String barangay,
    String? targetUserId,
    String? targetPurok,
    Map<String, dynamic>? additionalData,
    bool isUrgent = false,
    String? sourceId,
    String? sourceType,
  }) async {
    try {
      // Get current user info
      User? currentUser = _auth.currentUser;
      String authorId = currentUser?.uid ?? 'system';
      String authorName = 'System';
      String authorType = 'system';

      if (currentUser != null) {
        // Try to get user details from different collections
        try {
          // Check if admin
          DocumentSnapshot adminDoc = await _firestore
              .collection('barangay_admins')
              .doc(currentUser.uid)
              .get();

          if (adminDoc.exists) {
            Map<String, dynamic> adminData =
                adminDoc.data() as Map<String, dynamic>;
            authorName = adminData['fullName'] ?? 'Admin';
            authorType = 'admin';
          } else {
            // Check if collector
            DocumentSnapshot collectorDoc = await _firestore
                .collection('collectors')
                .doc(currentUser.uid)
                .get();

            if (collectorDoc.exists) {
              Map<String, dynamic> collectorData =
                  collectorDoc.data() as Map<String, dynamic>;
              authorName = collectorData['fullName'] ?? 'Collector';
              authorType = 'collector';
            } else {
              // Check if resident
              DocumentSnapshot residentDoc = await _firestore
                  .collection('resident')
                  .doc(currentUser.uid)
                  .get();

              if (residentDoc.exists) {
                Map<String, dynamic> residentData =
                    residentDoc.data() as Map<String, dynamic>;
                authorName = residentData['fullName'] ?? 'Resident';
                authorType = 'resident';
              }
            }
          }
        } catch (e) {
          print('Error getting user details: $e');
        }
      }

      // Create notification data
      Map<String, dynamic> notificationData = {
        'type':
            type, // 'announcement', 'schedule', 'penalty', 'scanned', 'system'
        'title': title,
        'content': content,
        'barangay': barangay,
        'targetUserId':
            targetUserId, // null for broadcast, user ID for specific user
        'targetPurok':
            targetPurok, // null for broadcast, purok for area-specific
        'authorId': authorId,
        'authorName': authorName,
        'authorType': authorType,
        'isUrgent': isUrgent,
        'sourceId':
            sourceId, // ID of the original document (announcement, schedule, etc.)
        'sourceType': sourceType, // Type of the source document
        'additionalData': additionalData ?? {},
        'isRead': false,
        // Per-user read receipts; do not rely on global isRead for broadcasts
        'readByUserIds': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': DateTime.now(),
      };

      // Add to notifications collection
      await _firestore.collection('notifications').add(notificationData);

      print('Notification created successfully: $type - $title');
    } catch (e) {
      print('Error creating notification: $e');
      // Don't throw error to avoid breaking the main functionality
    }
  }

  /// Creates an announcement notification
  static Future<void> createAnnouncementNotification({
    required String announcementId,
    required String title,
    required String content,
    required String barangay,
    String? targetPurok,
    bool isUrgent = false,
    String category = 'General',
    String priority = 'Medium',
  }) async {
    await createNotification(
      type: 'announcement',
      title: title,
      content: content,
      barangay: barangay,
      targetPurok: targetPurok,
      isUrgent: isUrgent,
      sourceId: announcementId,
      sourceType: 'announcement',
      additionalData: {
        'category': category,
        'priority': priority,
        'categoryIcon': _getCategoryIcon(category),
        'categoryColor': _getCategoryColor(category),
      },
    );
  }

  /// Creates a schedule notification
  static Future<void> createScheduleNotification({
    required String scheduleId,
    required String title,
    required String content,
    required String barangay,
    required DateTime date,
    required Map<String, dynamic> startTime,
    required Map<String, dynamic> endTime,
    required String wasteType,
    required String location,
    bool isRecurring = false,
    String? recurringGroupId,
  }) async {
    await createNotification(
      type: 'schedule',
      title: title,
      content: content,
      barangay: barangay,
      sourceId: scheduleId,
      sourceType: 'schedule',
      additionalData: {
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'wasteType': wasteType,
        'location': location,
        'isRecurring': isRecurring,
        'recurringGroupId': recurringGroupId,
        'scheduleTime': DateTime(
          date.year,
          date.month,
          date.day,
          startTime['hour'] ?? 8,
          startTime['minute'] ?? 0,
        ),
      },
    );
  }

  /// Creates a penalty notification for a specific resident
  static Future<void> createPenaltyNotification({
    required String scanId,
    required String residentId,
    required String residentName,
    required String barangay,
    required String purok,
    required List<String> warnings,
    required List<String> penalties,
    required String garbageType,
    double garbageWeight = 0,
    int pointsAwarded = 0,
  }) async {
    String title = penalties.isNotEmpty ? 'Penalty Applied' : 'Warning Issued';
    String content = penalties.isNotEmpty
        ? 'Penalties: ${penalties.join(', ')}'
        : 'Warnings: ${warnings.join(', ')}';

    await createNotification(
      type: 'penalty',
      title: title,
      content: content,
      barangay: barangay,
      targetUserId: residentId,
      targetPurok: purok,
      sourceId: scanId,
      sourceType: 'scan',
      additionalData: {
        'residentName': residentName,
        'warnings': warnings,
        'penalties': penalties,
        'garbageType': garbageType,
        'garbageWeight': garbageWeight,
        'pointsAwarded': pointsAwarded,
        'hasWarnings': warnings.isNotEmpty,
        'hasPenalties': penalties.isNotEmpty,
      },
    );
  }

  /// Creates a successful scan notification for a resident
  static Future<void> createScannedNotification({
    required String scanId,
    required String residentId,
    required String residentName,
    required String barangay,
    required String purok,
    required String garbageType,
    double garbageWeight = 0,
    int pointsAwarded = 0,
  }) async {
    await createNotification(
      type: 'scanned',
      title: 'Waste Collection Completed',
      content: '$garbageType waste collected',
      barangay: barangay,
      targetUserId: residentId,
      targetPurok: purok,
      sourceId: scanId,
      sourceType: 'scan',
      additionalData: {
        'residentName': residentName,
        'garbageType': garbageType,
        'garbageWeight': garbageWeight,
        'pointsAwarded': pointsAwarded,
      },
    );
  }

  /// Creates a system notification (for admin actions, system updates, etc.)
  static Future<void> createSystemNotification({
    required String title,
    required String content,
    required String barangay,
    String? targetUserId,
    String? targetPurok,
    Map<String, dynamic>? additionalData,
    bool isUrgent = false,
  }) async {
    await createNotification(
      type: 'system',
      title: title,
      content: content,
      barangay: barangay,
      targetUserId: targetUserId,
      targetPurok: targetPurok,
      additionalData: additionalData,
      isUrgent: isUrgent,
      sourceType: 'system',
    );
  }

  /// Marks a notification as read for a specific user
  static Future<void> markNotificationAsRead({
    required String notificationId,
    required String userId,
  }) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        // Do not flip global isRead; track per-user read state instead
        'readAt': FieldValue.serverTimestamp(),
        'readBy': userId,
        'readByUserIds': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Gets unread notification count for a user
  static Future<int> getUnreadNotificationCount({
    required String userId,
    String? barangay,
  }) async {
    try {
      // Simplified query to avoid index requirements
      Query query = _firestore
          .collection('notifications')
          .where('isRead', isEqualTo: false);

      // Add barangay filter if provided
      if (barangay != null) {
        query = query.where('barangay', isEqualTo: barangay);
      }

      QuerySnapshot snapshot = await query.get();

      // Filter user-specific notifications in memory instead of in query
      int count = 0;
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String? targetUserId = data['targetUserId'];
        final List<dynamic> readBy =
            (data['readByUserIds'] as List<dynamic>?) ?? const [];

        // Count if it's a broadcast notification or specific to this user
        final bool isForThisUser =
            targetUserId == null || targetUserId == userId;
        final bool alreadyReadByUser = readBy.contains(userId);
        if (isForThisUser && !alreadyReadByUser) {
          count++;
        }
      }

      return count;
    } catch (e) {
      print('Error getting unread notification count: $e');
      return 0;
    }
  }

  /// Clears notification count by marking all notifications as read for a user
  static Future<void> clearNotificationCount(String userId) async {
    try {
      // Get all unread notifications for this user
      QuerySnapshot snapshot = await _firestore
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      // Batch update to mark all relevant notifications as read
      WriteBatch batch = _firestore.batch();
      int batchCount = 0;

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String? targetUserId = data['targetUserId'];
        final List<dynamic> readBy =
            (data['readByUserIds'] as List<dynamic>?) ?? const [];

        // Mark as read if it's a broadcast notification or specific to this user
        if ((targetUserId == null || targetUserId == userId) &&
            !readBy.contains(userId)) {
          batch.update(doc.reference, {
            // Do not flip global isRead; append per-user receipt only
            'readAt': FieldValue.serverTimestamp(),
            'readBy': userId,
            'readByUserIds': FieldValue.arrayUnion([userId]),
          });
          batchCount++;

          // Firestore batch limit is 500 operations
          if (batchCount >= 500) {
            await batch.commit();
            batch = _firestore.batch();
            batchCount = 0;
          }
        }
      }

      // Commit any remaining operations
      if (batchCount > 0) {
        await batch.commit();
      }

      print('Cleared notification count for user: $userId');
    } catch (e) {
      print('Error clearing notification count: $e');
    }
  }

  /// Helper method to get category icon
  static String _getCategoryIcon(String category) {
    final Map<String, String> categoryIcons = {
      'General': 'bullhorn',
      'Waste Management': 'recycle',
      'Event': 'calendar-alt',
      'Warning': 'exclamation-triangle',
      'Notice': 'info-circle',
      'Other': 'th-list',
    };
    return categoryIcons[category] ?? 'bullhorn';
  }

  /// Helper method to get category color
  static int _getCategoryColor(String category) {
    final Map<String, int> categoryColors = {
      'General': 0xFF2196F3, // Blue
      'Waste Management': 0xFF4CAF50, // Green
      'Event': 0xFF9C27B0, // Purple
      'Warning': 0xFFFF9800, // Orange
      'Notice': 0xFF009688, // Teal
      'Other': 0xFF9E9E9E, // Grey
    };
    return categoryColors[category] ?? 0xFF2196F3;
  }
}
