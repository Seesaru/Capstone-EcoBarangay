import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_ecobarangay/screens/others/reusable_widgets.dart';
import 'package:capstone_ecobarangay/screens/residents/resident_dashboard.dart/features/schedule/schedule_screen.dart';
import 'package:capstone_ecobarangay/screens/residents/resident_dashboard.dart/features/announcement/announcement_screen.dart';
import 'package:capstone_ecobarangay/screens/residents/resident_dashboard.dart/features/reports/reports_screen.dart';
import 'package:capstone_ecobarangay/screens/residents/resident_dashboard.dart/features/profile/profile_screen.dart';
import '../notifications/notification_screen.dart';

class ResidentHomeScreen extends StatefulWidget {
  const ResidentHomeScreen({super.key});

  @override
  State<ResidentHomeScreen> createState() => _ResidentHomeScreenState();
}

class _ResidentHomeScreenState extends State<ResidentHomeScreen> {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State variables
  bool _isLoading = true;
  String _residentName = '';
  String _residentBarangay = '';
  String _residentImageUrl = '';

  // For collections and announcements
  List<Map<String, dynamic>> _ongoingCollections = [];
  List<Map<String, dynamic>> _upcomingCollections = [];
  List<Map<String, dynamic>> _recentAnnouncements = [];

  // For quick stats
  int _upcomingSchedulesCount = 0;
  int _unreadAnnouncementsCount = 0;

  // Current date formatter
  final String _currentDate =
      DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _fetchResidentInfo();
  }

  Future<void> _fetchResidentInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot residentDoc =
            await _firestore.collection('resident').doc(currentUser.uid).get();

        if (residentDoc.exists) {
          Map<String, dynamic> userData =
              residentDoc.data() as Map<String, dynamic>;

          setState(() {
            _residentName = userData['fullName'] ?? "Resident";
            _residentBarangay = userData['barangay'] ?? '';
            _residentImageUrl = userData['profileImageUrl'] ?? '';
          });

          // Now fetch schedules and announcements
          await Future.wait([
            _fetchSchedules(),
            _fetchAnnouncements(),
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
      print('Error fetching resident info: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fetch schedules from Firestore based on resident's barangay
  Future<void> _fetchSchedules() async {
    if (_residentBarangay.isEmpty) {
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

      List<Map<String, dynamic>> ongoingSchedules = [];
      List<Map<String, dynamic>> upcomingSchedules = [];

      // Manual filtering for barangay match and future dates
      String normalizedResidentBarangay =
          _residentBarangay.trim().toLowerCase();

      for (var doc in allSchedules.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String scheduleBarangay =
            (data['barangay'] ?? '').toString().trim().toLowerCase();

        if (scheduleBarangay == normalizedResidentBarangay) {
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
          };

          // Categorize as ongoing (today) or upcoming (future)
          if (normalizedDate.year == today.year &&
              normalizedDate.month == today.month &&
              normalizedDate.day == today.day) {
            // Today's schedule
            schedule['date'] = 'Today, $timeString';
            ongoingSchedules.add(schedule);
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
      final limitedOngoingSchedules = ongoingSchedules.take(3).toList();
      final limitedUpcomingSchedules = upcomingSchedules.take(3).toList();

      setState(() {
        _ongoingCollections = limitedOngoingSchedules;
        _upcomingCollections = limitedUpcomingSchedules;
        _upcomingSchedulesCount =
            ongoingSchedules.length + upcomingSchedules.length;
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
    if (_residentBarangay.isEmpty) {
      return;
    }

    try {
      // Get announcements for this resident's barangay
      QuerySnapshot querySnapshot = await _firestore
          .collection('announcements')
          .orderBy('date', descending: true) // Get newest first
          .get();

      // Maps for category icons and colors
      final Map<String, IconData> categoryIcons = {
        'General': FontAwesomeIcons.bullhorn,
        'Waste Management': FontAwesomeIcons.recycle,
      };

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
        if (data['barangay'] == _residentBarangay) {
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
        _unreadAnnouncementsCount =
            announcements.length; // Using total as unread for now
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
              "Home",
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationScreen(),
                    ),
                  );
                },
              ),
              if (_unreadAnnouncementsCount > 0)
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
                      _unreadAnnouncementsCount.toString(),
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
                _fetchResidentInfo();
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
      onRefresh: _fetchResidentInfo,
      color: const Color.fromARGB(255, 3, 144, 123),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(),
            _buildStatsSection(),
            if (_ongoingCollections.isNotEmpty)
              _buildOngoingCollectionsSection(context),
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
      name: _residentName,
      barangay: _residentBarangay,
      imageUrl: _residentImageUrl,
      onProfilePressed: () {
        // Navigate to profile screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfileScreen(),
          ),
        );
      },
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          HomeStatCard(
            icon: FontAwesomeIcons.calendarCheck,
            value: '$_upcomingSchedulesCount',
            label: 'Upcoming\nCollections',
            color: const Color.fromARGB(255, 3, 144, 123),
          ),
          const SizedBox(width: 16),
          HomeStatCard(
            icon: FontAwesomeIcons.bullhorn,
            value: '$_unreadAnnouncementsCount',
            label: 'Unread\nAnnouncements',
            color: Colors.orange.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildOngoingCollectionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(
          title: 'Ongoing Collections',
          onViewAllPressed: () {
            // Navigate to schedule screen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ScheduleScreen()),
            );
          },
        ),
        Container(
          height: 120,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _ongoingCollections.length,
            itemBuilder: (context, index) {
              final collection = _ongoingCollections[index];
              return CollectionCard(
                type: collection['type'],
                date: collection['date'],
                icon: collection['icon'],
                color: collection['color'],
                onTap: () {
                  // Navigate to schedule details or schedule screen with filter
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ScheduleScreen()),
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
              MaterialPageRoute(builder: (context) => const ScheduleScreen()),
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
                        // Navigate to schedule details or schedule screen with filter
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ScheduleScreen()),
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
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AnnouncementsScreen()),
            );
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const AnnouncementsScreen()),
                        );
                      },
                      onReadMorePressed: () {
                        // Navigate to specific announcement details
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const AnnouncementsScreen()),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
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
        'title': 'Report Issue',
        'icon': FontAwesomeIcons.flag,
        'color': Colors.red.shade600,
        'onTap': () {
          // Navigate to report issue screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReportScreen()),
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
            MaterialPageRoute(builder: (context) => const ScheduleScreen()),
          );
        },
      },
      {
        'title': 'Waste Guide',
        'icon': FontAwesomeIcons.bookOpen,
        'color': Colors.amber.shade700,
        'onTap': () {
          // Navigate to waste guide screen
        },
      },
      {
        'title': 'Contact Us',
        'icon': FontAwesomeIcons.phone,
        'color': Colors.purple.shade600,
        'onTap': () {
          // Navigate to contact screen
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
