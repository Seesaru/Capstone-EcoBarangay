import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_ecobarangay/screens/residents/resident_dashboard.dart/features/announcement/announcement_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State variables
  bool _isLoading = true;
  String _userName = '';
  String _userBarangay = '';

  // For notifications count
  int _unreadAnnouncementsCount = 0;
  int _upcomingSchedulesCount = 0;
  int _totalNotificationCount = 0;

  // Current date formatter
  final String _currentDate =
      DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  Future<void> _fetchUserInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('resident').doc(currentUser.uid).get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;

          setState(() {
            _userName = userData['fullName'] ?? "User";
            _userBarangay = userData['barangay'] ?? '';
          });

          // Now fetch announcements and schedules for notifications
          await Future.wait([
            _fetchAnnouncements(),
            _fetchSchedules(),
          ]);

          setState(() {
            _totalNotificationCount =
                _unreadAnnouncementsCount + _upcomingSchedulesCount;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching user info: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fetch announcements from Firestore
  Future<void> _fetchAnnouncements() async {
    if (_userBarangay.isEmpty) {
      return;
    }

    try {
      // Get announcements for this user's barangay
      QuerySnapshot querySnapshot = await _firestore
          .collection('announcements')
          .orderBy('date', descending: true) // Get newest first
          .get();

      List<Map<String, dynamic>> announcements = [];

      // Filter for this barangay
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Only include documents for this barangay
        if (data['barangay'] == _userBarangay) {
          announcements.add({
            'id': doc.id,
          });
        }
      }

      setState(() {
        _unreadAnnouncementsCount =
            announcements.length; // Using total as unread for now
      });
    } catch (e) {
      print('Error fetching announcements: ${e.toString()}');
    }
  }

  // Fetch schedules from Firestore
  Future<void> _fetchSchedules() async {
    if (_userBarangay.isEmpty) {
      return;
    }

    try {
      // Get current date for filtering upcoming schedules
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);

      // Get schedules for this barangay
      QuerySnapshot allSchedules = await _firestore
          .collection('schedule')
          .orderBy('date', descending: false) // Get earliest first
          .get();

      int upcomingCount = 0;

      // Manual filtering for barangay match and future dates
      String normalizedUserBarangay = _userBarangay.trim().toLowerCase();

      for (var doc in allSchedules.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String scheduleBarangay =
            (data['barangay'] ?? '').toString().trim().toLowerCase();

        if (scheduleBarangay == normalizedUserBarangay) {
          // Get date from timestamp and normalize
          DateTime date = (data['date'] as Timestamp).toDate();
          DateTime normalizedDate = DateTime(date.year, date.month, date.day);

          // Count upcoming schedules
          if (normalizedDate.isAfter(today) ||
              (normalizedDate.year == today.year &&
                  normalizedDate.month == today.month &&
                  normalizedDate.day == today.day)) {
            upcomingCount++;
          }
        }
      }

      setState(() {
        _upcomingSchedulesCount = upcomingCount;
      });
    } catch (e) {
      print('Error fetching schedules: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color.fromARGB(255, 3, 144, 123),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Home Screen",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
            Text(
              _currentDate,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications,
                  color: Colors.white,
                ),
                onPressed: () {
                  // Navigate to announcements screen
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AnnouncementsScreen()));
                },
              ),
              if (_totalNotificationCount > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _totalNotificationCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: Colors.white,
            ),
            onSelected: (value) {
              if (value == 'refresh') {
                _fetchUserInfo();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 18),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome, $_userName',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'You have $_totalNotificationCount unread notifications',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (_unreadAnnouncementsCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        '$_unreadAnnouncementsCount new announcements',
                        style:
                            const TextStyle(fontSize: 14, color: Colors.blue),
                      ),
                    ),
                  if (_upcomingSchedulesCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        '$_upcomingSchedulesCount upcoming schedules',
                        style:
                            const TextStyle(fontSize: 14, color: Colors.green),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: const Color.fromARGB(255, 3, 144, 123),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
