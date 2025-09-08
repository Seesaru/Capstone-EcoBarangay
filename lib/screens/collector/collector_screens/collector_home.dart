import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_ecobarangay/screens/others/reusable_widgets.dart';
import 'package:capstone_ecobarangay/screens/residents/resident_dashboard.dart/features/announcement/announcement_screen.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:capstone_ecobarangay/screens/collector/features/collector_scan.dart';
import 'package:capstone_ecobarangay/screens/collector/features/collector_scan_history.dart';
import 'package:capstone_ecobarangay/screens/collector/collector_screens/collector_schedule.dart';
import 'package:capstone_ecobarangay/screens/collector/collector_screens/collector_profile.dart';
import '../features/collector_notification_screen.dart';
import 'package:capstone_ecobarangay/services/notification_service.dart';
import 'dart:async';

class CollectorHomeScreen extends StatefulWidget {
  const CollectorHomeScreen({super.key});

  @override
  State<CollectorHomeScreen> createState() => _CollectorHomeScreenState();
}

class _CollectorHomeScreenState extends State<CollectorHomeScreen> {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State variables
  bool _isLoading = true;
  String _collectorName = '';
  String _collectorBarangay = '';
  String _collectorImageUrl = '';

  // For collections and announcements
  List<Map<String, dynamic>> _todayCollections = [];
  List<Map<String, dynamic>> _upcomingCollections = [];
  List<Map<String, dynamic>> _recentAnnouncements = [];

  // For quick stats
  int _todaySchedulesCount = 0;
  int _totalScansCount = 0;
  int _totalWasteCollectedKg = 0;
  int _unreadNotificationsCount = 0;
  StreamSubscription<QuerySnapshot>? _notifSub;

  // Current date formatter
  final String _currentDate =
      DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _fetchCollectorInfo();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchCollectorInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot collectorDoc =
            await _firestore.collection('collector').doc(currentUser.uid).get();

        if (collectorDoc.exists) {
          Map<String, dynamic> userData =
              collectorDoc.data() as Map<String, dynamic>;

          setState(() {
            _collectorName = userData['fullName'] ?? "Collector";
            _collectorBarangay = userData['barangay'] ?? '';
            _collectorImageUrl = userData['profileImageUrl'] ?? '';
          });

          // Set up OneSignal tags for collector
          _setupOneSignalTags(currentUser.uid, _collectorBarangay);

          // Now fetch schedules and announcements
          _startRealtimeNotificationListener();
          await Future.wait([
            _fetchSchedules(),
            _fetchAnnouncements(),
            _fetchCollectionStats(),
          ]);

          setState(() {
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
      print('Error fetching collector info: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Set up OneSignal tags for the collector
  Future<void> _setupOneSignalTags(String userId, String barangay) async {
    try {
      if (barangay.isNotEmpty) {
        // Log in to OneSignal with the user's ID
        await OneSignal.login(userId);
        print('OneSignal: Logged in collector with ID: $userId');

        // Add tags for targeting notifications
        await OneSignal.User.addTags(
            {'barangay': barangay, 'user_type': 'collector'});
        print('OneSignal: Tagged collector with barangay: $barangay');

        // Get current tags for verification
        final tags = await OneSignal.User.getTags();
        print('OneSignal: Current tags: $tags');
      }
    } catch (e) {
      print('Error setting up OneSignal tags: ${e.toString()}');
    }
  }

  // Fetch collection statistics
  Future<void> _fetchCollectionStats() async {
    if (_collectorBarangay.isEmpty || _auth.currentUser == null) {
      return;
    }

    try {
      // Get current collector ID
      final String currentCollectorId = _auth.currentUser!.uid;

      // Get total scans count
      final scansCount = await _firestore
          .collection('scans')
          .where('collectorId', isEqualTo: currentCollectorId)
          .count()
          .get();

      _totalScansCount = scansCount.count ?? 0;

      // Get all scans to calculate total waste collected
      final scansSnapshot = await _firestore
          .collection('scans')
          .where('collectorId', isEqualTo: currentCollectorId)
          .get();

      double totalWaste = 0.0;
      for (var doc in scansSnapshot.docs) {
        final data = doc.data();
        if (data['garbageWeight'] != null) {
          if (data['garbageWeight'] is int) {
            totalWaste += (data['garbageWeight'] as int).toDouble();
          } else {
            totalWaste += (data['garbageWeight'] as double);
          }
        }
      }

      setState(() {
        _todaySchedulesCount = _todayCollections.length;
        _totalWasteCollectedKg =
            totalWaste.round(); // Convert to int for display
      });
    } catch (e) {
      print('Error fetching collection stats: ${e.toString()}');
    }
  }

  // Fetch schedules from Firestore based on collector's barangay
  Future<void> _fetchSchedules() async {
    if (_collectorBarangay.isEmpty) {
      return;
    }

    try {
      // Get current date for filtering upcoming schedules
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);
      final DateTime tomorrow = today.add(const Duration(days: 1));

      // Get schedules for this barangay
      QuerySnapshot allSchedules = await _firestore
          .collection('schedule')
          .orderBy('date', descending: false) // Get earliest first
          .get();

      // Map for waste type icons and colors
      final Map<String, IconData> wasteIcons = {
        'Biodegradable': FontAwesomeIcons.leaf,
        'Non-biodegradable': FontAwesomeIcons.trash,
        'Recyclable': FontAwesomeIcons.recycle,
        'General': FontAwesomeIcons.dumpster,
      };

      final Map<String, Color> wasteColors = {
        'Biodegradable': Colors.green.shade600,
        'Non-biodegradable': Colors.orange.shade600,
        'Recyclable': Colors.teal.shade600,
        'General': Colors.blue.shade600,
      };

      List<Map<String, dynamic>> todaySchedules = [];
      List<Map<String, dynamic>> upcomingSchedules = [];

      // Manual filtering for barangay match and future dates
      String normalizedCollectorBarangay =
          _collectorBarangay.trim().toLowerCase();

      for (var doc in allSchedules.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String scheduleBarangay =
            (data['barangay'] ?? '').toString().trim().toLowerCase();

        if (scheduleBarangay == normalizedCollectorBarangay) {
          // Get date from timestamp and normalize
          DateTime date = (data['date'] as Timestamp).toDate();
          DateTime normalizedDate = DateTime(date.year, date.month, date.day);

          // Format time
          Map<String, dynamic> startTimeMap =
              data['startTime'] ?? {'hour': 0, 'minute': 0};
          Map<String, dynamic> endTimeMap =
              data['endTime'] ?? {'hour': 0, 'minute': 0};

          // Format time string
          String timeString =
              '${_formatTime(startTimeMap)} - ${_formatTime(endTimeMap)}';

          // Get waste type and determine icon and color
          String wasteType = data['wasteType'] ?? 'General';
          IconData icon = wasteIcons[wasteType] ?? FontAwesomeIcons.dumpster;
          Color color = wasteColors[wasteType] ?? Colors.purple.shade600;

          // Create the schedule data
          Map<String, dynamic> schedule = {
            'id': doc.id,
            'type': wasteType,
            'date': timeString, // Only time for today's schedules
            'icon': icon,
            'color': color,
            'rawDate': normalizedDate,
            'status': data['status'] ?? 'Scheduled',
            'title': data['title'] ?? 'Waste Collection',
            'purok': data['purok'] ?? 'All Puroks',
          };

          // Categorize as today or upcoming
          if (normalizedDate.year == today.year &&
              normalizedDate.month == today.month &&
              normalizedDate.day == today.day) {
            // Today's schedule
            schedule['date'] = 'Today, $timeString';
            todaySchedules.add(schedule);
          } else if (normalizedDate.isAfter(today)) {
            // Upcoming schedule (tomorrow or later)
            if (normalizedDate.year == tomorrow.year &&
                normalizedDate.month == tomorrow.month &&
                normalizedDate.day == tomorrow.day) {
              schedule['date'] = 'Tomorrow, $timeString';
            } else {
              schedule['date'] =
                  '${DateFormat('MMM d').format(normalizedDate)}, $timeString';
            }
            upcomingSchedules.add(schedule);
          }
        }
      }

      // Sort by date (earliest first)
      upcomingSchedules.sort((a, b) {
        DateTime dateA = a['rawDate'] as DateTime;
        DateTime dateB = b['rawDate'] as DateTime;
        return dateA.compareTo(dateB);
      });

      // Take only up to 3 for each category
      final limitedTodaySchedules = todaySchedules.take(3).toList();
      final limitedUpcomingSchedules = upcomingSchedules.take(3).toList();

      setState(() {
        _todayCollections = limitedTodaySchedules;
        _upcomingCollections = limitedUpcomingSchedules;
        _todaySchedulesCount = todaySchedules.length;
      });
    } catch (e) {
      print('Error fetching schedules: ${e.toString()}');
    }
  }

  // Format time from map to string
  String _formatTime(Map<String, dynamic> timeMap) {
    int hour = timeMap['hour'] ?? 0;
    int minute = timeMap['minute'] ?? 0;

    int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    String period = hour >= 12 ? 'PM' : 'AM';

    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  // Fetch announcements from Firestore
  Future<void> _fetchAnnouncements() async {
    if (_collectorBarangay.isEmpty) {
      return;
    }

    try {
      // Get announcements for this collector's barangay
      QuerySnapshot querySnapshot = await _firestore
          .collection('announcements')
          .orderBy('date', descending: true) // Get newest first
          .get();

      // Maps for category colors
      final Map<String, Color> categoryColors = {
        'General': Colors.blue,
        'Waste Management': Colors.green,
        'Event': Colors.purple,
        'Warning': Colors.orange,
        'Notice': Colors.teal,
        'Other': Colors.grey,
      };

      List<Map<String, dynamic>> announcements = [];

      // Filter for this barangay
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Only include documents for this barangay
        if (data['barangay'] == _collectorBarangay) {
          // Process timestamp to DateTime
          DateTime date;
          if (data['date'] is Timestamp) {
            date = (data['date'] as Timestamp).toDate();
          } else {
            date = DateTime.now(); // Fallback
          }

          // Format date for display
          String displayDate = DateFormat('MMMM d, yyyy').format(date);

          // Get category color
          Color categoryColor = categoryColors[data['category']] ?? Colors.blue;

          announcements.add({
            'id': doc.id,
            'title': data['title'] ?? 'No Title',
            'date': displayDate,
            'urgent': data['urgent'] ?? false,
            'color': categoryColor,
            'content': data['content'] ?? 'No Content',
          });
        }
      }

      // Take only the first 3 for display
      final limitedAnnouncements = announcements.take(3).toList();

      setState(() {
        _recentAnnouncements = limitedAnnouncements;
      });
    } catch (e) {
      print('Error fetching announcements: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color.fromARGB(255, 3, 144, 123),
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Collector Home",
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
                onPressed: () async {
                  // Clear notification count when opening notification screen
                  User? currentUser = _auth.currentUser;
                  if (currentUser != null) {
                    await NotificationService.clearNotificationCount(
                        currentUser.uid);
                    setState(() {
                      _unreadNotificationsCount = 0;
                    });
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CollectorNotificationScreen(),
                    ),
                  ).then((_) {
                    if (mounted) setState(() {});
                  });
                },
              ),
              if (_unreadNotificationsCount > 0)
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
                      _unreadNotificationsCount.toString(),
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
                _fetchCollectorInfo();
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
      body: _isLoading ? _buildLoadingState() : _buildHomeContent(context),
    );
  }

  void _startRealtimeNotificationListener() {
    _notifSub?.cancel();

    final String barangay = _collectorBarangay;
    final String? userId = _auth.currentUser?.uid;
    if (barangay.isEmpty || userId == null) return;

    _notifSub = _firestore
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .where('barangay', isEqualTo: barangay)
        .snapshots()
        .listen((snapshot) {
      int count = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String? targetUserId = data['targetUserId'];
        final List<dynamic> readBy =
            (data['readByUserIds'] as List<dynamic>?) ?? const [];
        final bool isForThisUser =
            targetUserId == null || targetUserId == userId;
        final bool alreadyReadByUser = readBy.contains(userId);
        if (isForThisUser && !alreadyReadByUser) {
          count++;
        }
      }
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = count;
        });
      }
    }, onError: (e) {
      print('Realtime notif listener error: $e');
    });
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

  Widget _buildHomeContent(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchCollectorInfo,
      color: const Color.fromARGB(255, 3, 144, 123),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(),
            _buildStatsSection(),
            if (_todayCollections.isNotEmpty)
              _buildTodayCollectionsSection(context),
            _buildUpcomingCollectionsSection(context),
            _buildAnnouncementsSection(context),
            _buildQuickActionsSection(context),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return WelcomeCard(
      name: _collectorName,
      barangay: _collectorBarangay,
      imageUrl: _collectorImageUrl,
      onProfilePressed: () {
        // Navigate to profile screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CollectorProfileScreen(),
          ),
        );
      },
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: HomeStatCard(
                  icon: FontAwesomeIcons.calendarDay,
                  value: '$_todaySchedulesCount',
                  label: 'Today\'s\nCollections',
                  color: const Color.fromARGB(255, 3, 144, 123),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: HomeStatCard(
                  icon: FontAwesomeIcons.calendarCheck,
                  value: '${_upcomingCollections.length}',
                  label: 'Upcoming\nCollections',
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: HomeStatCard(
                  icon: FontAwesomeIcons.dumpster,
                  value: '$_totalWasteCollectedKg',
                  label: 'Waste\nCollected (kg)',
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: HomeStatCard(
                  icon: FontAwesomeIcons.qrcode,
                  value: '$_totalScansCount',
                  label: 'Total\nScans',
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCollectionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(
          title: 'Today\'s Collections',
          onViewAllPressed: () {
            // Navigate to schedule screen
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CollectorScheduleScreen()),
            );
          },
        ),
        Container(
          height: 120,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _todayCollections.length,
            itemBuilder: (context, index) {
              final collection = _todayCollections[index];
              return CollectionCard(
                type: collection['type'],
                date: collection['date'],
                icon: collection['icon'],
                color: collection['color'],
                onTap: () {
                  // Navigate to collection details
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CollectorScheduleScreen()),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingCollectionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(
          title: 'Upcoming Collections',
          onViewAllPressed: () {
            // Navigate to schedule screen
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CollectorScheduleScreen()),
            );
          },
        ),
        Container(
          height: 120,
          margin: const EdgeInsets.only(bottom: 8),
          child: _upcomingCollections.isEmpty
              ? _buildEmptyCollectionsState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _upcomingCollections.length,
                  itemBuilder: (context, index) {
                    final collection = _upcomingCollections[index];
                    return CollectionCard(
                      type: collection['type'],
                      date: collection['date'],
                      icon: collection['icon'],
                      color: collection['color'],
                      onTap: () {
                        // Navigate to collection details
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const CollectorScheduleScreen()),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyCollectionsState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.calendarXmark,
              size: 30,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 10),
            Text(
              'No upcoming collections',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(
          title: 'Recent Announcements',
          onViewAllPressed: () {
            // Navigate to announcements screen
            _navigateToAnnouncementsScreen(context);
          },
        ),
        Container(
          height: 150,
          margin: const EdgeInsets.only(bottom: 8),
          child: _recentAnnouncements.isEmpty
              ? _buildEmptyAnnouncementsState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _recentAnnouncements.length,
                  itemBuilder: (context, index) {
                    final announcement = _recentAnnouncements[index];
                    return AnnouncementCard(
                      title: announcement['title'],
                      date: announcement['date'],
                      urgent: announcement['urgent'],
                      color: announcement['color'],
                      onTap: () {
                        // Navigate to the full announcement screen
                        _navigateToAnnouncementsScreen(context);
                      },
                      onReadMorePressed: () {
                        // Navigate to specific announcement details
                        _navigateToAnnouncementsScreen(context);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Custom navigation method for announcements that handles collector-specific requirements
  void _navigateToAnnouncementsScreen(BuildContext context) {
    // Check if collector has a barangay assigned
    if (_collectorBarangay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Your account does not have a barangay assigned. Please contact admin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Pass collector's barangay to announcement screen to avoid "user profile not found" error
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnnouncementsScreen(
          isCollector: true,
          collectorBarangay: _collectorBarangay,
        ),
      ),
    );
  }

  Widget _buildEmptyAnnouncementsState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.bullhorn,
              size: 28,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 10),
            Text(
              'No announcements yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    List<Map<String, dynamic>> actions = [
      {
        'title': 'Start Collection',
        'icon': FontAwesomeIcons.truckLoading,
        'color': Colors.green.shade600,
        'onTap': () {
          // Navigate to scan screen
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const CollectorScanScreen()),
          );
        },
      },
      {
        'title': 'View Schedule',
        'icon': FontAwesomeIcons.calendar,
        'color': Colors.teal.shade600,
        'onTap': () {
          // Navigate to schedule screen
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const CollectorScheduleScreen()),
          );
        },
      },
      {
        'title': 'Collection History',
        'icon': FontAwesomeIcons.history,
        'color': Colors.amber.shade700,
        'onTap': () {
          // Navigate to collection history screen
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const CollectorScanHistoryScreen()),
          );
        },
      },
      {
        'title': 'Contact Admin',
        'icon': FontAwesomeIcons.phone,
        'color': Colors.purple.shade600,
        'onTap': () {
          // Show dialog with contact information
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Contact Admin'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'For assistance, please contact your barangay admin:'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.phone,
                          color: Colors.purple.shade600, size: 20),
                      const SizedBox(width: 8),
                      const Text('Phone: 09123456789'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.email,
                          color: Colors.purple.shade600, size: 20),
                      const SizedBox(width: 8),
                      const Text('Email: admin@ecobarangay.com'),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(
          title: 'Quick Actions',
          onViewAllPressed: null, // No view all for quick actions
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return QuickActionButton(
                title: action['title'],
                icon: action['icon'],
                color: action['color'],
                onTap: action['onTap'],
              );
            },
          ),
        ),
      ],
    );
  }
}
