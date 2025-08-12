import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../announcement/announcement_detail_dialog.dart';
import '../schedule/schedule_detail_dialog.dart';

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
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  Future<void> _fetchUserInfo() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
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
      // Fetch announcements
      QuerySnapshot announcementSnapshot = await _firestore
          .collection('announcements')
          .where('barangay', isEqualTo: _userBarangay)
          .orderBy('date', descending: true)
          .get();

      // Fetch schedules
      QuerySnapshot scheduleSnapshot = await _firestore
          .collection('schedule')
          .where('barangay', isEqualTo: _userBarangay)
          .orderBy('date', descending: true)
          .get();

      List<Map<String, dynamic>> notifications = [];

      // Process announcements
      for (var doc in announcementSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        DateTime date = (data['date'] as Timestamp).toDate();

        notifications.add({
          'id': doc.id,
          'type': 'announcement',
          'title': data['title'] ?? 'No Title',
          'content': data['content'] ?? 'No Content',
          'date': date,
          'urgent': data['urgent'] ?? false,
          'category': data['category'] ?? 'General',
          'icon': data['urgent'] ?? false
              ? FontAwesomeIcons.exclamationCircle
              : FontAwesomeIcons.bullhorn,
          'color': data['urgent'] ?? false ? Colors.red : Colors.blue,
        });
      }

      // Process schedules
      for (var doc in scheduleSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        DateTime date = (data['date'] as Timestamp).toDate();
        Map<String, dynamic> startTime =
            data['startTime'] as Map<String, dynamic>;

        DateTime scheduleTime = DateTime(
          date.year,
          date.month,
          date.day,
          startTime['hour'] as int,
          startTime['minute'] as int,
        );

        notifications.add({
          'id': doc.id,
          'type': 'schedule',
          'title': '${data['wasteType']} Waste Collection',
          'content': 'Location: ${data['location']}',
          'date': scheduleTime,
          'wasteType': data['wasteType'],
          'location': data['location'],
          'icon': FontAwesomeIcons.truck,
          'color': Colors.green,
        });
      }

      // Sort all notifications by date
      notifications.sort(
          (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      setState(() {
        _notifications = notifications;
      });
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  Future<void> _onNotificationTap(Map<String, dynamic> notification) async {
    try {
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

          // Add required fields for the dialog
          final scheduleData = {
            ...data,
            'id': doc.id,
            'date': (data['date'] as Timestamp).toDate(),
            'icon': FontAwesomeIcons.truck,
            'color': Colors.green,
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
      }
    } catch (e) {
      print('Error showing notification detail: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
      body: _notifications.isEmpty
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
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  final DateTime date = notification['date'] as DateTime;
                  final bool isToday =
                      DateTime.now().difference(date).inDays == 0;
                  final bool isYesterday =
                      DateTime.now().difference(date).inDays == 1;

                  String dateStr;
                  if (isToday) {
                    dateStr = 'Today ${DateFormat('h:mm a').format(date)}';
                  } else if (isYesterday) {
                    dateStr = 'Yesterday ${DateFormat('h:mm a').format(date)}';
                  } else {
                    dateStr = DateFormat('MMM d, h:mm a').format(date);
                  }

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: notification['color'],
                        child: Icon(
                          notification['icon'],
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        notification['title'],
                        style: TextStyle(
                          fontWeight: notification['urgent'] == true
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notification['content']),
                          const SizedBox(height: 4),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _onNotificationTap(notification),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
