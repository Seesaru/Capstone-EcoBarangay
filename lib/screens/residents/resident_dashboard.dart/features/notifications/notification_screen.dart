import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../announcement/announcement_detail_dialog.dart';
import '../schedule/schedule_detail_dialog.dart';
import 'package:capstone_ecobarangay/services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  String _userBarangay = '';
  String _userId = '';
  Map<String, List<Map<String, dynamic>>> _groupedNotifications = {};
  List<String> _orderedGroupKeys = []; // Add this to maintain proper order

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
    _clearNotificationCount();
  }

  Future<void> _clearNotificationCount() async {
    try {
      // Clear the notification count when user enters the screen
      await NotificationService.clearNotificationCount(_userId);
    } catch (e) {
      print('Error clearing notification count: $e');
    }
  }

  Future<void> _fetchUserInfo() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        setState(() {
          _userId = currentUser.uid;
        });

        DocumentSnapshot userDoc =
            await _firestore.collection('resident').doc(currentUser.uid).get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          setState(() {
            _userBarangay = userData['barangay'] ?? '';
          });
          await _fetchNotifications();
        }
      }
    } catch (e) {
      print('Error fetching user info: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchNotifications() async {
    if (_userBarangay.isEmpty) return;

    try {
      List<Map<String, dynamic>> notifications = [];
      Set<String> processedScanIds =
          {}; // Track processed scan IDs to prevent duplicates

      // Process centralized notifications (non-scan notifications)
      QuerySnapshot allNotificationsSnapshot =
          await _firestore.collection('notifications').limit(100).get();

      List<DocumentSnapshot> relevantNotifications = [];
      for (var doc in allNotificationsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Check if this notification is relevant for this user
        bool isRelevant = false;

        // Check if it's user-specific
        if (data['targetUserId'] == _userId) {
          isRelevant = true;
        }
        // Check if it's a broadcast notification for this barangay
        else if (data['targetUserId'] == null &&
            data['barangay'] == _userBarangay) {
          isRelevant = true;
        }
        // Check if it's a purok-specific notification
        else if (data['targetPurok'] != null) {
          try {
            DocumentSnapshot userDoc =
                await _firestore.collection('resident').doc(_userId).get();
            if (userDoc.exists) {
              Map<String, dynamic> userData =
                  userDoc.data() as Map<String, dynamic>;
              String userPurok = userData['purok'] ?? '';

              if (data['targetPurok'] == userPurok ||
                  data['targetPurok'] == 'General') {
                isRelevant = true;
              }
            }
          } catch (e) {
            print('Error checking user purok: $e');
          }
        }

        if (isRelevant) {
          relevantNotifications.add(doc);
        }
      }

      // Sort by timestamp in memory
      relevantNotifications.sort((a, b) {
        Map<String, dynamic> dataA = a.data() as Map<String, dynamic>;
        Map<String, dynamic> dataB = b.data() as Map<String, dynamic>;
        Timestamp? timestampA = dataA['timestamp'];
        Timestamp? timestampB = dataB['timestamp'];

        if (timestampA == null && timestampB == null) return 0;
        if (timestampA == null) return 1;
        if (timestampB == null) return -1;

        return timestampB.compareTo(timestampA);
      });

      if (relevantNotifications.length > 20) {
        relevantNotifications = relevantNotifications.take(20).toList();
      }

      // Process centralized notifications (only non-scan related ones)
      for (var doc in relevantNotifications) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Skip scan-related notifications - these will be handled separately
        // Check if it's a scan-related notification by type or sourceType
        if (data['type'] == 'scan' ||
            data['type'] == 'scanned' ||
            data['type'] == 'penalty' ||
            data['sourceType'] == 'scan' ||
            data['garbageType'] != null ||
            data['garbageWeight'] != null ||
            data['pointsAwarded'] != null ||
            data['warnings'] != null ||
            data['penalties'] != null) {
          continue;
        }

        // Skip if this notification is for a scan we've already processed
        if (data['sourceId'] != null &&
            processedScanIds.contains(data['sourceId'])) {
          continue;
        }

        DateTime date = (data['timestamp'] as Timestamp).toDate();

        // Add generic notification from centralized collection
        final bool isUrgent =
            (data['urgent'] == true) || (data['isUrgent'] == true);
        
        // Get additional schedule data if it's a schedule notification
        DateTime? collectionDate;
        String? wasteType;
        String? collectionTime;
        
        if (data['type']?.toLowerCase() == 'schedule') {
          // Try to get collection data from the original schedule document
          try {
            DocumentSnapshot scheduleDoc = await _firestore
                .collection('schedule')
                .doc(data['sourceId'] ?? doc.id)
                .get();
            
            if (scheduleDoc.exists) {
              Map<String, dynamic> scheduleData = scheduleDoc.data() as Map<String, dynamic>;
              collectionDate = scheduleData['date'] != null 
                  ? (scheduleData['date'] as Timestamp).toDate() 
                  : null;
              wasteType = scheduleData['wasteType'] ?? scheduleData['garbageType'];
              collectionTime = scheduleData['time'];
            }
          } catch (e) {
            print('Error fetching schedule details: $e');
          }
          
          // Fallback to notification data
          collectionDate ??= data['collectionDate'] != null 
              ? (data['collectionDate'] as Timestamp).toDate() 
              : null;
          wasteType ??= data['wasteType'] ?? data['garbageType'];
          collectionTime ??= data['collectionTime'];
        }

        notifications.add({
          'id': data['sourceId'] ?? doc.id,
          'type': data['type'] ?? 'general',
          'title': data['title'] ?? 'Notification',
          'content': data['type']?.toLowerCase() == 'schedule' 
              ? _getScheduleContent(wasteType, collectionDate, collectionTime)
              : (data['message'] ?? data['content'] ?? ''),
          'date': date,
          'collectionDate': collectionDate,
          'wasteType': wasteType,
          'collectionTime': collectionTime,
          'icon': _getIconForNotificationType(data['type']),
          'color': (data['type']?.toLowerCase() == 'announcement' && isUrgent)
              ? Colors.red
              : _getColorForNotificationType(data['type'], data),
          'badgeColor':
              (data['type']?.toLowerCase() == 'announcement' && isUrgent)
                  ? Colors.red
                  : _getColorForNotificationType(data['type'], data),
          'badgeText': _getBadgeTextForNotification(data),
          'urgent': isUrgent,
          'source': 'notifications',
          'sourceId': doc.id,
        });
      }

      // Fetch user-specific scans to create scan notifications
      QuerySnapshot userScansSnapshot = await _firestore
          .collection('scans')
          .where('residentId', isEqualTo: _userId)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      // Process user's scans
      for (var doc in userScansSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        DateTime date = (data['timestamp'] as Timestamp).toDate();

        // Skip if we've already processed this scan ID
        if (processedScanIds.contains(doc.id)) {
          continue;
        }
        processedScanIds.add(doc.id);

        // Check for warnings and penalties
        bool hasWarnings = false;
        bool hasPenalties = false;
        List<String> warnings = [];
        List<String> penalties = [];

        if (data['warnings'] != null && data['warnings'] is Map) {
          Map<String, dynamic> warningsData =
              data['warnings'] as Map<String, dynamic>;
          if (warningsData['failedToContribute'] == true) {
            hasWarnings = true;
            warnings.add('Failed to Contribute');
          }
        }

        if (data['penalties'] != null && data['penalties'] is Map) {
          Map<String, dynamic> penaltiesData =
              data['penalties'] as Map<String, dynamic>;
          if (penaltiesData['notSegregated'] == true) {
            hasPenalties = true;
            penalties.add('Not Segregated');
          }
          if (penaltiesData['noContributions'] == true) {
            hasPenalties = true;
            penalties.add('No Contributions');
          }
        }

        if (hasWarnings || hasPenalties) {
          // Penalty notification
          notifications.add({
            'id': doc.id,
            'type': 'penalty',
            'title': hasPenalties ? 'Penalty Applied' : 'Warning Issued',
            'content': hasPenalties
                ? 'Penalties: ${penalties.join(', ')}'
                : 'Warnings: ${warnings.join(', ')}',
            'date': date,
            'warnings': warnings,
            'penalties': penalties,
            'hasWarnings': hasWarnings,
            'hasPenalties': hasPenalties,
            'icon': hasPenalties
                ? FontAwesomeIcons.exclamationTriangle
                : FontAwesomeIcons.warning,
            'color': hasPenalties ? Colors.red : Colors.orange,
            'badgeColor': hasPenalties ? Colors.red : Colors.orange,
            'badgeText': hasPenalties ? 'PENALTY' : 'WARNING',
            'garbageType': data['garbageType'] ?? 'Unknown',
            'garbageWeight': data['garbageWeight'] ?? 0,
            'pointsAwarded': data['pointsAwarded'] ?? 0,
            'source': 'scans',
          });
        } else {
          // Successful scan notification (only for this user's scans)
          notifications.add({
            'id': doc.id,
            'type': 'scanned',
            'title': 'Waste Collection Completed',
            'content': '${data['garbageType'] ?? 'Unknown'} waste collected',
            'date': date,
            'garbageType': data['garbageType'] ?? 'Unknown',
            'garbageWeight': data['garbageWeight'] ?? 0,
            'pointsAwarded': data['pointsAwarded'] ?? 0,
            'icon': FontAwesomeIcons.checkCircle,
            'color': Colors.green,
            'badgeColor': Colors.green,
            'badgeText': 'SCANNED',
            'source': 'scans',
          });
        }
      }

      // Sort all notifications by date (most recent first)
      notifications.sort(
          (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      // Group notifications by date
      _groupNotificationsByDate(notifications);

      setState(() {});
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  String _getScheduleContent(String? wasteType, DateTime? collectionDate, String? collectionTime) {
    String type = wasteType ?? 'Waste';
    
    if (collectionDate != null) {
      String dateStr = DateFormat('MMM d, yyyy').format(collectionDate);
      if (collectionTime != null && collectionTime.isNotEmpty) {
        return '$type collection scheduled for $dateStr at $collectionTime';
      } else {
        String timeStr = DateFormat('h:mm a').format(collectionDate);
        return '$type collection scheduled for $dateStr at $timeStr';
      }
    } else if (collectionTime != null && collectionTime.isNotEmpty) {
      return '$type collection scheduled at $collectionTime';
    } else {
      return '$type collection has been scheduled';
    }
  }

  void _groupNotificationsByDate(List<Map<String, dynamic>> notifications) {
    _groupedNotifications.clear();
    _orderedGroupKeys.clear();

    // Define the desired order of groups
    final List<String> groupOrder = [
      'Today',
      'Yesterday',
      'This Week',
      'This Month',
      'Earlier'
    ];

    // First, group notifications
    for (var notification in notifications) {
      DateTime date = notification['date'] as DateTime;
      String groupKey = _getDateGroupKey(date);

      if (!_groupedNotifications.containsKey(groupKey)) {
        _groupedNotifications[groupKey] = [];
      }
      _groupedNotifications[groupKey]!.add(notification);
    }

    // Create ordered keys based on the predefined order and which groups actually have notifications
    for (String groupKey in groupOrder) {
      if (_groupedNotifications.containsKey(groupKey) &&
          _groupedNotifications[groupKey]!.isNotEmpty) {
        _orderedGroupKeys.add(groupKey);
      }
    }
  }

  String _getDateGroupKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Calculate this week's start (Monday)
    final daysFromMonday = now.weekday - 1;
    final thisWeekStart = today.subtract(Duration(days: daysFromMonday));

    // Calculate this month's start
    final thisMonthStart = DateTime(now.year, now.month, 1);

    final notificationDate = DateTime(date.year, date.month, date.day);

    if (notificationDate == today) {
      return 'Today';
    } else if (notificationDate == yesterday) {
      return 'Yesterday';
    } else if (notificationDate
            .isAfter(thisWeekStart.subtract(const Duration(days: 1))) &&
        notificationDate.isBefore(today)) {
      return 'This Week';
    } else if (notificationDate
            .isAfter(thisMonthStart.subtract(const Duration(days: 1))) &&
        notificationDate.isBefore(thisWeekStart)) {
      return 'This Month';
    } else {
      return 'Earlier';
    }
  }

  // Helper methods for generic notifications
  IconData _getIconForNotificationType(String? type) {
    switch (type?.toLowerCase()) {
      case 'announcement':
        return FontAwesomeIcons.bullhorn;
      case 'schedule':
        return FontAwesomeIcons.truck;
      case 'penalty':
        return FontAwesomeIcons.exclamationTriangle;
      case 'warning':
        return FontAwesomeIcons.warning;
      case 'scan':
      case 'scanned':
        return FontAwesomeIcons.checkCircle;
      case 'urgent':
        return FontAwesomeIcons.exclamationCircle;
      default:
        return FontAwesomeIcons.bell;
    }
  }

  Color _getColorForNotificationType(String? type, Map<String, dynamic>? data) {
    // Check if it's an urgent announcement first
    if (type?.toLowerCase() == 'announcement' &&
        data != null &&
        (data['urgent'] == true || data['isUrgent'] == true)) {
      return Colors.red;
    }

    switch (type?.toLowerCase()) {
      case 'announcement':
        return Colors.blue;
      case 'schedule':
        return Colors.green;
      case 'penalty':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'scan':
      case 'scanned':
        return Colors.green;
      case 'urgent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getBadgeTextForNotification(Map<String, dynamic> data) {
    String type = data['type'] ?? 'general';

    // Check if it's an urgent announcement
    if (type.toLowerCase() == 'announcement' &&
        (data['urgent'] == true || data['isUrgent'] == true)) {
      return 'URGENT';
    }

    // Return the type in uppercase for other cases
    return type.toUpperCase();
  }

  Future<void> _onNotificationTap(Map<String, dynamic> notification) async {
    try {
      // Mark notification as read if it's from the centralized collection
      if (notification['source'] == 'notifications' &&
          notification['sourceId'] != null) {
        await NotificationService.markNotificationAsRead(
          notificationId: notification['sourceId'],
          userId: _userId,
        );
      }

      if (notification['type'] == 'announcement') {
        // Fetch complete announcement data
        DocumentSnapshot doc = await _firestore
            .collection('announcements')
            .doc(notification['id'])
            .get();

        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          // Add required fields for the dialog
          final announcementData = {
            ...data,
            'id': doc.id,
            'date': (data['date'] as Timestamp).toDate(),
            'categoryIcon': data['categoryIcon'] ?? FontAwesomeIcons.bullhorn,
            'categoryColor': data['urgent'] == true ? Colors.red : Colors.blue,
          };

          if (mounted) {
            await showDialog(
              context: context,
              builder: (context) => AnnouncementDetailDialog(
                announcement: announcementData,
              ),
            );
          }
        }
      } else if (notification['type'] == 'schedule') {
        // Fetch complete schedule data
        DocumentSnapshot doc = await _firestore
            .collection('schedule')
            .doc(notification['id'])
            .get();

        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          // Add required fields for the dialog with proper date handling
          final scheduleData = {
            ...data,
            'id': doc.id,
            // Use the actual collection date from the schedule document
            'date': (data['date'] as Timestamp).toDate(),
            'icon': FontAwesomeIcons.truck,
            'color': Colors.green,
            'wasteType': data['wasteType'] ?? data['garbageType'] ?? 'General Waste',
            'time': data['time'],
          };

          if (mounted) {
            await showDialog(
              context: context,
              builder: (context) => ScheduleDetailDialog(
                schedule: scheduleData,
              ),
            );
          }
        }
      } else if (notification['type'] == 'penalty' ||
          notification['type'] == 'scanned') {
        // Show scan detail dialog
        _showScanDetailDialog(notification);
      }
    } catch (e) {
      print('Error showing notification detail: $e');
    }
  }

  void _showScanDetailDialog(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              notification['icon'],
              color: notification['color'],
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                notification['title'],
                style: const TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date: ${DateFormat('MMM d, yyyy h:mm a').format(notification['date'])}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text('Waste Type: ${notification['garbageType']}'),
            if (notification['garbageWeight'] > 0)
              Text('Weight: ${notification['garbageWeight']} kg'),
            if (notification['pointsAwarded'] > 0)
              Text('Points Awarded: ${notification['pointsAwarded']}'),
            if (notification['type'] == 'penalty') ...[
              const SizedBox(height: 12),
              if (notification['warnings'] != null &&
                  notification['warnings'].isNotEmpty) ...[
                Text(
                  'Warnings:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
                ...notification['warnings'].map((warning) => Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text('• $warning'),
                    )),
              ],
              if (notification['penalties'] != null &&
                  notification['penalties'].isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Penalties:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                ...notification['penalties'].map((penalty) => Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text('• $penalty'),
                    )),
              ],
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final DateTime date = notification['date'] as DateTime;
    final String timeStr = DateFormat('h:mm a').format(date);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onNotificationTap(notification),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Color indicator and icon (reduced size)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: notification['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: notification['color'].withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    notification['icon'],
                    color: notification['color'],
                    size: 16,
                  ),
                ),

                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and time
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification['title'],
                              style: TextStyle(
                                fontWeight: notification['urgent'] == true
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 14,
                                color: Colors.grey[900],
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Content
                      Text(
                        notification['content'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Additional info for specific notification types
                      if (notification['type'] == 'schedule') ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            notification['collectionDate'] != null
                                ? '${notification['wasteType'] ?? 'Waste'} - ${DateFormat('MMM d, yyyy').format(notification['collectionDate'])}'
                                : '${notification['wasteType'] ?? 'Waste'} Collection',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ] else if (notification['type'] == 'scanned') ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (notification['garbageWeight'] > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${notification['garbageWeight']} kg',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (notification['pointsAwarded'] > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '+${notification['pointsAwarded']} pts',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ] else if (notification['type'] == 'penalty') ...[
                        const SizedBox(height: 6),
                        if (notification['warnings'] != null &&
                            notification['warnings'].isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Warnings: ${notification['warnings'].join(', ')}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                        ],
                        if (notification['penalties'] != null &&
                            notification['penalties'].isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Penalties: ${notification['penalties'].join(', ')}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: notification['badgeColor'],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    notification['badgeText'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateGroupHeader(String groupKey) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        groupKey,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color.fromARGB(255, 3, 144, 123),
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 20,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotifications,
            color: Colors.white,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_groupedNotifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FontAwesomeIcons.bell,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  child: ListView.builder(
                    itemCount: _orderedGroupKeys.length * 2,
                    itemBuilder: (context, index) {
                      final groupIndex = index ~/ 2;
                      final isHeader = index % 2 == 0;
                      final groupKey = _orderedGroupKeys[groupIndex];
                      final notifications = _groupedNotifications[groupKey]!;

                      if (isHeader) {
                        return _buildDateGroupHeader(groupKey);
                      } else {
                        return Column(
                          children: notifications
                              .map((notification) =>
                                  _buildNotificationCard(notification))
                              .toList(),
                        );
                      }
                    },
                  ),
                )),
    );
  }
}