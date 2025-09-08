import 'package:capstone_ecobarangay/screens/admin/admin_analytics.dart';
import 'package:capstone_ecobarangay/screens/admin/announcement_screen.dart';
import 'package:capstone_ecobarangay/screens/admin/manage_collectors.dart';
import 'package:capstone_ecobarangay/screens/admin/reports_screen.dart';
import 'package:capstone_ecobarangay/screens/admin/schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' as ui;
import '../../services/authentication.dart';
import 'package:capstone_ecobarangay/screens/admin/manage_users.dart';
import 'package:capstone_ecobarangay/screens/admin/functions/add_announcement.dart';
import 'package:capstone_ecobarangay/screens/admin/functions/add_schedule.dart';
import 'package:capstone_ecobarangay/screens/others/reusable_widgets.dart';
import 'package:intl/intl.dart';
import 'package:capstone_ecobarangay/screens/admin/features/reward_matrix.dart';
import 'package:capstone_ecobarangay/screens/admin/user_logs_screen.dart';
import 'package:capstone_ecobarangay/screens/admin/penalty_list.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isAdmin = false;
  String _errorMessage = '';
  String _adminName = '';
  String _adminBarangay = '';
  int _selectedIndex = 0;
  bool _showAddAnnouncement = false;
  bool _showAddSchedule = false;

  // Updated color scheme - Clean with white sidebar
  final Color primaryColor = Colors.white; // White sidebar background
  final Color accentColor = const Color(0xFF4CAF50); // Green accent
  final Color backgroundColor = Colors.white;
  final Color textColor = Colors.grey.shade800;
  final Color sidebarTextColor = Colors.grey.shade800;
  final Color sidebarIconColor = Colors.grey.shade700;
  final Color sidebarHoverColor = Colors.grey.shade100;
  final Color sidebarSelectedColor =
      const Color(0xFF4CAF50); // Green for selected items
  final Color sidebarSelectedTextColor =
      Colors.white; // White text for selected items
  final Color sidebarBorderColor = Colors.grey.shade100; // Light border color

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      User? currentUser = _authService.currentUser;

      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _isAdmin = false;
          _errorMessage = 'No user is currently logged in';
        });
        _redirectToLogin();
        return;
      }

      // Check if user is an admin in Firestore
      DocumentSnapshot adminDoc = await _firestore
          .collection('barangay_admins')
          .doc(currentUser.uid)
          .get();

      if (!adminDoc.exists) {
        setState(() {
          _isLoading = false;
          _isAdmin = false;
          _errorMessage = 'This account does not have admin privileges';
        });
        _redirectToLogin();
        return;
      }

      // Get admin data
      Map<String, dynamic> adminData = adminDoc.data() as Map<String, dynamic>;

      // Check if admin role is correct
      if (adminData['role'] != 'admin') {
        setState(() {
          _isLoading = false;
          _isAdmin = false;
          _errorMessage = 'This account does not have admin privileges';
        });
        _redirectToLogin();
        return;
      }

      // Check if email is verified
      if (!currentUser.emailVerified && !(adminData['isVerified'] ?? false)) {
        setState(() {
          _isLoading = false;
          _isAdmin = false;
          _errorMessage =
              'Please verify your email before accessing the admin dashboard';
        });
        _redirectToLogin();
        return;
      }

      // Admin is verified, set admin data
      setState(() {
        _isLoading = false;
        _isAdmin = true;
        _adminName = adminData['fullName'] ?? 'Admin';
        _adminBarangay = adminData['barangay'] ?? 'Unknown Barangay';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isAdmin = false;
        _errorMessage = 'Error verifying admin status: ${e.toString()}';
      });
      _redirectToLogin();
    }
  }

  void _redirectToLogin() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/admin-login');
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut() async {
    try {
      // Show confirmation dialog
      bool confirm = await showLogoutConfirmationDialog(context);

      if (confirm) {
        await _authService.signOut();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/admin-login');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: ${e.toString()}')),
      );
    }
  }

  Widget _getSelectedScreen() {
    if (_selectedIndex == 1 && _showAddAnnouncement) {
      return AddAnnouncementScreen(
        onBackPressed: () {
          setState(() {
            _showAddAnnouncement = false;
          });
        },
        adminBarangay: _adminBarangay,
      );
    }

    if (_selectedIndex == 2 && _showAddSchedule) {
      return AddScheduleScreen(
        onBackPressed: () {
          setState(() {
            _showAddSchedule = false;
          });
        },
      );
    }

    switch (_selectedIndex) {
      case 0:
        return const DashboardHomeScreen();
      case 1:
        return AdminAnnouncements(
          onAddAnnouncementPressed: () {
            setState(() {
              _showAddAnnouncement = true;
            });
          },
        );
      case 2:
        return AdminSchedules(
          onAddSchedulePressed: () {
            setState(() {
              _showAddSchedule = true;
            });
          },
        );
      case 3:
        return const AdminReportsScreen();
      case 4:
        return ManageUsersScreen(adminBarangay: _adminBarangay);
      case 5:
        return ManageCollectorsScreen(adminBarangay: _adminBarangay);
      case 6:
        return const AdminAccessRolesScreen();
      case 7:
        return const RewardMatrixScreen();
      case 8:
        return const AdminUserMaintenanceScreen();
      case 9:
        return const AnalyticsScreen();
      case 10:
        return UserLogsScreen(adminBarangay: _adminBarangay);
      case 11:
        return PenaltyListScreen(adminBarangay: _adminBarangay);
      default:
        return const DashboardHomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: accentColor,
          ),
        ),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 24),
              Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Redirecting to login...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Define whether sidebar is extended or not
    bool isExtended = MediaQuery.of(context).size.width >= 1200;
    double sidebarWidth = isExtended ? 280 : 80;

    // Admin dashboard with upgraded sidebar navigation
    return Scaffold(
      body: Row(
        children: [
          // Custom scrollable sidebar
          Container(
            width: sidebarWidth,
            margin: const EdgeInsets.all(0),
            decoration: BoxDecoration(
              color: primaryColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 3,
                  blurRadius: 15,
                  offset: const Offset(5, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Admin profile section
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  width: double.infinity,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Enhanced admin avatar
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accentColor.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 38,
                          backgroundColor: accentColor.withOpacity(0.1),
                          child: Icon(
                            Icons.admin_panel_settings,
                            size: 40,
                            color: accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (isExtended)
                        Text(
                          _adminName,
                          style: TextStyle(
                            color: sidebarTextColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (isExtended)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _adminBarangay,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Container(
                        width: isExtended ? 220 : 60,
                        height: 1,
                        color: Colors.grey.withOpacity(0.1),
                      ),
                    ],
                  ),
                ),

                // Scrollable menu items
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        _buildNavItem(0, Icons.dashboard_outlined,
                            Icons.dashboard, 'Dashboard', isExtended),
                        _buildNavItem(1, Icons.campaign_outlined,
                            Icons.campaign, 'Announcements', isExtended),
                        _buildNavItem(2, Icons.calendar_today_outlined,
                            Icons.calendar_today, 'Schedules', isExtended),
                        _buildNavItem(3, Icons.description_outlined,
                            Icons.description, 'Reports', isExtended),
                        _buildNavItem(4, Icons.people_outline, Icons.people,
                            'Manage Users', isExtended),
                        _buildNavItem(5, Icons.person_add_outlined,
                            Icons.person_add, 'Manage Collectors', isExtended),
                        _buildNavItem(
                            6,
                            Icons.admin_panel_settings_outlined,
                            Icons.admin_panel_settings,
                            'Admin Access Roles',
                            isExtended),
                        _buildNavItem(7, Icons.emoji_events_outlined,
                            Icons.emoji_events, 'Reward Matrix', isExtended),
                        _buildNavItem(
                            8,
                            Icons.manage_accounts_outlined,
                            Icons.manage_accounts,
                            'Admin User Maintenance',
                            isExtended),
                        _buildNavItem(9, Icons.analytics_outlined,
                            Icons.analytics, 'Analytics', isExtended),
                        _buildNavItem(10, Icons.history_outlined, Icons.history,
                            'User Logs', isExtended),
                        _buildNavItem(11, Icons.warning_amber_outlined,
                            Icons.warning_amber, 'Penalty List', isExtended),
                      ],
                    ),
                  ),
                ),

                // Sign out button at the bottom
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isExtended ? 220 : 60,
                        height: 1,
                        color: Colors.grey.withOpacity(0.1),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isExtended ? 16.0 : 0,
                        ),
                        child: InkWell(
                          onTap: _signOut,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.withOpacity(0.1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.logout,
                                  color: sidebarIconColor,
                                  size: 20,
                                ),
                                if (isExtended) ...[
                                  const SizedBox(width: 12),
                                  Text(
                                    'Sign Out',
                                    style: TextStyle(
                                      color: sidebarTextColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main content area
          Expanded(
            child: _getSelectedScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData selectedIcon,
      String label, bool isExtended) {
    bool isSelected = _selectedIndex == index;

    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? sidebarSelectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? sidebarSelectedTextColor : sidebarIconColor,
              size: 22,
            ),
            if (isExtended) ...[
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color:
                      isSelected ? sidebarSelectedTextColor : sidebarTextColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  NavigationRailDestination _buildNavRailDestination(
      IconData icon, IconData selectedIcon, String label) {
    return NavigationRailDestination(
      icon: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Icon(icon, color: Colors.white70, size: 22),
      ),
      selectedIcon: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: accentColor.withOpacity(0.2),
        ),
        child: Icon(selectedIcon, color: accentColor, size: 22),
      ),
      label: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}

class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({Key? key}) : super(key: key);

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String _adminBarangay = '';

  // Date range for current week
  late DateTime _startOfWeek;
  late DateTime _endOfWeek;

  // Dashboard statistics
  int _totalUsersCount = 0;
  int _totalCollectorsCount = 0;
  int _schedulesCount = 0;
  int _announcementsCount = 0;
  int _reportsCount = 0;
  int _totalScannedUsers = 0;

  // Recent items
  List<Map<String, dynamic>> _upcomingSchedules = [];

  // Charts data
  Map<String, double> _wasteCollectionData = {};
  Map<String, double> _monthlyWasteData = {};
  List<Map<String, dynamic>> _scannedUsersData = [];

  @override
  void initState() {
    super.initState();
    _fetchAdminBarangay();
  }

  Future<void> _fetchAdminBarangay() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot adminDoc = await _firestore
            .collection('barangay_admins')
            .doc(currentUser.uid)
            .get();

        if (adminDoc.exists) {
          Map<String, dynamic> adminData =
              adminDoc.data() as Map<String, dynamic>;
          _adminBarangay = adminData['barangay'] ?? '';

          // Now load dashboard data with the correct barangay
          _loadDashboardData();
        }
      }
    } catch (e) {
      print('Error fetching admin barangay: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Calculate the current week dates once to ensure consistency across all data
      DateTime now = DateTime.now();
      _startOfWeek = now.subtract(Duration(days: now.weekday % 7));
      _startOfWeek =
          DateTime(_startOfWeek.year, _startOfWeek.month, _startOfWeek.day);
      _endOfWeek = _startOfWeek
          .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

      await Future.wait([
        _fetchUserStatistics(),
        _fetchAnnouncements(),
        _fetchSchedules(),
        _fetchReports(),
        _fetchWeeklyScansData(),
      ]);

      // Don't override with hardcoded data - use actual Firestore data
    } catch (e) {
      print('Error loading dashboard data: $e');
      // Set fallback data only if there's an error
      _setFallbackVisualizationData();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchUserStatistics() async {
    try {
      // Count total users (residents)
      QuerySnapshot userQuery = await _firestore.collection('resident').get();

      // Count total collectors
      QuerySnapshot collectorQuery =
          await _firestore.collection('collector').get();

      // Count total schedules
      QuerySnapshot scheduleQuery =
          await _firestore.collection('schedule').get();

      setState(() {
        _totalUsersCount = userQuery.size;
        _totalCollectorsCount = collectorQuery.size;
        _schedulesCount = scheduleQuery.size;
      });

      // Set some minimum values for demo/testing purposes
      if (_totalUsersCount == 0) _totalUsersCount = 25;
      if (_totalCollectorsCount == 0) _totalCollectorsCount = 8;
      if (_schedulesCount == 0) _schedulesCount = 12;
    } catch (e) {
      print('Error fetching user statistics: $e');
      // Set fallback values if there's an error
      _totalUsersCount = 25;
      _totalCollectorsCount = 8;
      _schedulesCount = 12;
    }
  }

  Future<void> _fetchAnnouncements() async {
    try {
      // Get all announcements first
      QuerySnapshot querySnapshot = await _firestore
          .collection('announcements')
          .orderBy('date', descending: true)
          .get();

      List<Map<String, dynamic>> fetchedAnnouncements = [];

      // Filter for the admin's barangay
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Only include documents for this barangay
        if (data['barangay'] == _adminBarangay) {
          DateTime date;
          if (data['date'] is Timestamp) {
            date = (data['date'] as Timestamp).toDate();
          } else {
            date = DateTime.now(); // Fallback
          }

          fetchedAnnouncements.add({
            'id': doc.id,
            'title': data['title'] ?? 'No Title',
            'date': date,
            'barangay': data['barangay'] ?? 'Unknown',
            'urgent': data['urgent'] ?? false,
            'category': data['category'] ?? 'General',
          });
        }
      }

      // Update announcement count
      setState(() {
      });
    } catch (e) {
      print('Error fetching announcements: $e');
    }
  }

  Future<void> _fetchSchedules() async {
    try {

      QuerySnapshot querySnapshot = await _firestore
          .collection('schedule')
          .orderBy('date', descending: false)
          .limit(5)
          .get();

      _upcomingSchedules = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        DateTime scheduleDate = (data['date'] as Timestamp).toDate();

        // Format time
        Map<String, dynamic> startTimeMap =
            data['startTime'] ?? {'hour': 0, 'minute': 0};
        String timeString = _formatTime(startTimeMap);

        return {
          'id': doc.id,
          'title': data['title'] ?? 'Waste Collection',
          'date': scheduleDate,
          'time': timeString,
          'wasteType': data['wasteType'] ?? 'General',
          'barangay': data['barangay'] ?? 'Unknown',
          'status': data['status'] ?? 'Scheduled',
        };
      }).toList();

      // Sort by date (earliest first)
      _upcomingSchedules.sort((a, b) {
        DateTime dateA = a['date'] as DateTime;
        DateTime dateB = b['date'] as DateTime;
        return dateA.compareTo(dateB);
      });
    } catch (e) {
      print('Error fetching schedules: $e');
    }
  }

  Future<void> _fetchReports() async {
    try {
      // Get reports from Firestore
      QuerySnapshot querySnapshot = await _firestore
          .collection('reports')
          .where('residentBarangay', isEqualTo: _adminBarangay)
          .orderBy('date', descending: true)
          .get();

      List<Map<String, dynamic>> fetchedReports = [];

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        DateTime reportDate = DateTime.now();
        if (data['date'] is Timestamp) {
          reportDate = (data['date'] as Timestamp).toDate();
        }

        fetchedReports.add({
          'id': doc.id,
          'title': data['title'] ?? 'No Title',
          'content': data['content'] ?? 'No content',
          'category': data['category'] ?? 'General',
          'location': data['location'],
          'date': reportDate,
          'author': data['author'],
          'authorId': data['authorId'],
          'authorRole': data['authorRole'] ?? 'Resident',
          'status': data['status'] ?? 'New',
          'userType': data['userType'],
          'isAnonymous': data['isAnonymous'] ?? false,
          'barangay': data['residentBarangay'] ?? _adminBarangay,
        });
      }

      setState(() {
        _reportsCount = fetchedReports.length;
      });
    } catch (e) {
      print('Error fetching reports: $e');
      // Set fallback values if there's an error
      _reportsCount = 0;
    }
  }

  Future<void> _fetchWeeklyScansData() async {
    try {
      // Get scans for current week only
      DateTime now = DateTime.now();
      _startOfWeek = now.subtract(Duration(days: now.weekday % 7));
      _startOfWeek =
          DateTime(_startOfWeek.year, _startOfWeek.month, _startOfWeek.day);
      _endOfWeek = _startOfWeek
          .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

      print(
          'Fetching scans from ${_startOfWeek.toString()} to ${_endOfWeek.toString()}');
      print('Admin Barangay: $_adminBarangay');

      // List to store all scan documents for this week
      List<QueryDocumentSnapshot> weeklyScans = [];

      // Try with compound query first
      QuerySnapshot scansSnapshot = await _firestore
          .collection('scans')
          .where('barangay', isEqualTo: _adminBarangay)
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(_startOfWeek))
          .where('timestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(_endOfWeek))
          .get();

      if (scansSnapshot.docs.isNotEmpty) {
        print('Found ${scansSnapshot.docs.length} scans using compound query');
        weeklyScans.addAll(scansSnapshot.docs);
      } else {
        // If compound query returns no results, try a simpler query and filter manually
        print('No results with compound query, trying simpler query...');
        scansSnapshot = await _firestore
            .collection('scans')
            .where('barangay', isEqualTo: _adminBarangay)
            .get();

        print(
            'Found ${scansSnapshot.docs.length} total scans (before date filtering)');

        // Manual date filtering
        for (var doc in scansSnapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          if (data['timestamp'] is Timestamp) {
            DateTime scanDate = (data['timestamp'] as Timestamp).toDate();
            if (scanDate.isAfter(_startOfWeek) &&
                scanDate.isBefore(_endOfWeek)) {
              weeklyScans.add(doc);
            }
          }
        }

        print(
            'After manual date filtering, found ${weeklyScans.length} scans for this week');
      }

      // Initialize data structures
      Map<String, double> wasteTypeData = {
        'Biodegradable': 0.0,
        'Non-biodegradable': 0.0,
        'Recyclable': 0.0,
        'General': 0.0,
      };

      Map<String, double> dailyWasteData = {};
      Map<String, int> dailyScanCounts = {};
      Set<String> uniqueUserIds = {};

      // Initialize data for all days of the week
      for (int i = 0; i < 7; i++) {
        DateTime day = _startOfWeek.add(Duration(days: i));
        String dayKey = '${day.day}/${day.month}';
        dailyWasteData[dayKey] = 0.0;
        dailyScanCounts[dayKey] = 0;
      }

      // Process each scan - use the weeklyScans list which contains properly filtered data
      print('\n--- PROCESSING INDIVIDUAL SCANS ---');
      for (var doc in weeklyScans) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Get scan basic data
        String rawWasteType = (data['garbageType'] ?? 'General').toString();
        double weight = (data['garbageWeight'] ?? 0).toDouble();

        // Log each scan for debugging
        print(
            '\nScan ID: ${doc.id}, Raw Type: "$rawWasteType", Weight: $weight kg');

        // Normalize waste type to handle different variations
        String wasteType = _normalizeWasteType(rawWasteType);

        // Track unique users
        if (data['residentId'] != null) {
          uniqueUserIds.add(data['residentId']);
        }

        // Update waste type totals
        if (wasteTypeData.containsKey(wasteType)) {
          double oldValue = wasteTypeData[wasteType] ?? 0.0;
          wasteTypeData[wasteType] = oldValue + weight;
          print(
              'Updated $wasteType: $oldValue kg -> ${wasteTypeData[wasteType]} kg');
        } else {
          // If not a standard category, add to General
          double oldValue = wasteTypeData['General'] ?? 0.0;
          wasteTypeData['General'] = oldValue + weight;
          print(
              'Added to General: $oldValue kg -> ${wasteTypeData['General']} kg');
        }

        // Update daily data
        if (data['timestamp'] is Timestamp) {
          DateTime scanDate = (data['timestamp'] as Timestamp).toDate();
          String dayKey = '${scanDate.day}/${scanDate.month}';

          print('Scan date: ${scanDate.toString()}, Day key: $dayKey');

          // Update daily waste amount
          dailyWasteData[dayKey] = (dailyWasteData[dayKey] ?? 0.0) + weight;

          // Update scan count
          dailyScanCounts[dayKey] = (dailyScanCounts[dayKey] ?? 0) + 1;
        }
      }

      // Log final waste type totals
      print('\n--- FINAL WASTE TOTALS ---');
      wasteTypeData.forEach((type, amount) {
        print('Total $type: $amount kg');
      });

      // Convert daily scan counts to list for chart
      List<Map<String, dynamic>> scannedData = [];
      dailyScanCounts.forEach((key, value) {
        scannedData.add({
          'date': key,
          'count': value,
        });
      });

      // Sort data by date
      scannedData.sort((a, b) => a['date'].compareTo(b['date']));

      // Update state with all data
      setState(() {
        _wasteCollectionData = wasteTypeData;
        _monthlyWasteData = dailyWasteData; // Reused for daily waste data
        _scannedUsersData = scannedData;
        _totalScannedUsers = uniqueUserIds.length;
      });
    } catch (e) {
      print('Error fetching weekly scans data: $e');
      print(e.toString());

      // Set fallback data
      _setFallbackVisualizationData();
    }
  }

  // Helper to normalize waste type names
  String _normalizeWasteType(String rawType) {
    String normalized = rawType.trim().toLowerCase();

    print('Normalizing waste type: "$rawType" -> normalized to: "$normalized"');

    // Check for non-biodegradable first (more specific matches take precedence)
    if (normalized.contains('non-bio') ||
        normalized.contains('non bio') ||
        normalized.contains('nonbio') ||
        normalized == 'non-biodegradable' ||
        normalized == 'nonbiodegradable' ||
        normalized == 'non' ||
        normalized.contains('plastic') ||
        normalized.contains('styro')) {
      print('  ✓ Categorized as: Non-biodegradable');
      return 'Non-biodegradable';
    }
    // Then check for biodegradable
    else if (normalized == 'biodegradable' ||
        normalized == 'bio' ||
        normalized.contains('food') ||
        normalized.contains('organic') ||
        normalized.contains('green') ||
        normalized.contains('vegetable') ||
        normalized.contains('fruit')) {
      print('  ✓ Categorized as: Biodegradable');
      return 'Biodegradable';
    }
    // Then recyclable
    else if (normalized.contains('recycl') ||
        normalized.contains('paper') ||
        normalized.contains('metal') ||
        normalized.contains('glass') ||
        normalized.contains('tin') ||
        normalized.contains('bottle') ||
        normalized.contains('cardboard')) {
      print('  ✓ Categorized as: Recyclable');
      return 'Recyclable';
    }
    // Default to general
    else {
      print('  ✓ Categorized as: General (no specific match)');
      return 'General';
    }
  }

  void _setFallbackVisualizationData() {
    // Minimal fallback data that clearly indicates it's not real data
    _wasteCollectionData = {
      'Biodegradable': 0.0,
      'Non-biodegradable': 0.0,
      'Recyclable': 0.0,
      'General': 0.0,
    };

    // Empty daily data
    Map<String, double> dailyData = {};
    List<Map<String, dynamic>> scannedData = [];

    // Create empty data structure for each day of the week
    for (int i = 0; i < 7; i++) {
      DateTime day = _startOfWeek.add(Duration(days: i));
      String dayKey = '${day.day}/${day.month}';
      dailyData[dayKey] = 0.0;
      scannedData.add({
        'date': dayKey,
        'count': 0,
      });
    }

    _monthlyWasteData = dailyData;
    _scannedUsersData = scannedData;
    _totalScannedUsers = 0;

    // Show a message that this is fallback data
    print(
        'WARNING: Using fallback visualization data (all zeros) because real data could not be loaded');
  }

  String _formatTime(Map<String, dynamic> timeMap) {
    int hour = timeMap['hour'] ?? 0;
    int minute = timeMap['minute'] ?? 0;

    int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    String period = hour >= 12 ? 'PM' : 'AM';

    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  String _formatScheduleDate(DateTime date) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime tomorrow = today.add(const Duration(days: 1));

    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return 'Today';
    } else if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return 'Tomorrow';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF4CAF50),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildMainContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF388E3C), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'EcoBarangay Waste Management',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadDashboardData,
                tooltip: 'Refresh Dashboard',
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormat('MMM d, yyyy').format(DateTime.now()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            const Color(0xFFF5F7FA), // Light gray background instead of white
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF212121),
            ),
          ),
          const SizedBox(height: 24),
          _buildStatisticsCards(),
          const SizedBox(height: 32),
          _buildDataVisualizationSection(),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Users',
          _totalUsersCount.toString(),
          Icons.people_outline,
          const Color(0xFF4CAF50),
        ),
        _buildStatCard(
          'Collectors',
          _totalCollectorsCount.toString(),
          Icons.person_add_outlined,
          const Color(0xFF2196F3),
        ),
        _buildStatCard(
          'Schedules',
          _schedulesCount.toString(),
          Icons.calendar_today_outlined,
          const Color(0xFFFF9800),
        ),
        _buildStatCard(
          'Announcements',
          _announcementsCount.toString(),
          Icons.campaign_outlined,
          const Color(0xFF9C27B0),
        ),
        _buildStatCard(
          'Reports',
          _reportsCount.toString(),
          Icons.report_problem_outlined,
          const Color(0xFFE53935),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: color,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataVisualizationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data Visualization',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: _buildWasteDistributionChart(),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: _buildScannedUsersChart(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildMonthlyWasteCollectionChart(),
      ],
    );
  }

  Widget _buildWasteDistributionChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'This Week\'s Waste Distribution',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.eco, size: 16, color: Color(0xFF4CAF50)),
                      SizedBox(width: 4),
                      Text(
                        'By Weight (kg)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: _wasteCollectionData.isEmpty
                  ? const Center(child: Text('No data available'))
                  : Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              double maxValue = _wasteCollectionData.values
                                  .reduce((a, b) => a > b ? a : b);
                              double barWidth = (constraints.maxWidth /
                                      _wasteCollectionData.length) -
                                  24;

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children:
                                    _wasteCollectionData.entries.map((entry) {
                                  // Calculate bar height based on max value
                                  double barHeight = (entry.value / maxValue) *
                                      constraints.maxHeight *
                                      0.7;

                                  Color barColor =
                                      _getWasteTypeColor(entry.key);

                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        entry.value.toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Container(
                                        width: barWidth,
                                        height: barHeight > 0 ? barHeight : 5,
                                        decoration: BoxDecoration(
                                          color: barColor,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(4),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: barColor.withOpacity(0.3),
                                              spreadRadius: 1,
                                              blurRadius: 3,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: barWidth + 10,
                                        child: Text(
                                          entry.key,
                                          style: const TextStyle(fontSize: 12),
                                          maxLines: 2,
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _wasteLegendItem('Biodegradable',
                                _getWasteTypeColor('Biodegradable')),
                            _wasteLegendItem('Non-biodegradable',
                                _getWasteTypeColor('Non-biodegradable')),
                            _wasteLegendItem(
                                'Recyclable', _getWasteTypeColor('Recyclable')),
                            _wasteLegendItem(
                                'General', _getWasteTypeColor('General')),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get consistent color for waste types
  Color _getWasteTypeColor(String wasteType) {
    switch (wasteType) {
      case 'Biodegradable':
        return const Color(0xFF4CAF50); // Green
      case 'Non-biodegradable':
        return const Color(0xFFE91E63); // Pink
      case 'Recyclable':
        return const Color(0xFF2196F3); // Blue
      case 'General':
        return const Color(0xFFFF9800); // Orange
      default:
        return const Color(0xFF9C27B0); // Purple
    }
  }

  Widget _wasteLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildScannedUsersChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'This Week\'s Scanned Users',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people,
                          size: 16, color: Color(0xFF2196F3)),
                      const SizedBox(width: 4),
                      Text(
                        'Total: $_totalScannedUsers',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: _scannedUsersData.isEmpty
                  ? const Center(child: Text('No data available'))
                  : Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              double maxValue = 0;
                              for (var item in _scannedUsersData) {
                                if (item['count'] > maxValue)
                                  maxValue = item['count'].toDouble();
                              }
                              maxValue = maxValue > 0 ? maxValue : 10;

                              return CustomPaint(
                                size: Size(constraints.maxWidth,
                                    constraints.maxHeight * 0.8),
                                painter: LineChartPainter(
                                  data: _scannedUsersData,
                                  maxValue: maxValue,
                                  lineColor: const Color(
                                      0xFFFF9800), // Orange accent color from analytics
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline,
                                size: 14, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              'Daily scan counts for this week',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyWasteCollectionChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'This Week\'s Waste Collection',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 16,
                        color:
                            Color(0xFF2E7D32)), // Match analytics primary color
                    SizedBox(width: 4),
                    Text(
                      'Daily Progress',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: _monthlyWasteData.isEmpty
                  ? const Center(child: Text('No data available'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Convert map to sorted list
                        List<Map<String, dynamic>> dailyData = [];
                        _monthlyWasteData.forEach((key, value) {
                          dailyData.add({
                            'day': key,
                            'amount': value,
                          });
                        });

                        // Sort by day
                        dailyData.sort((a, b) => a['day'].compareTo(b['day']));

                        double maxValue = 0;
                        for (var item in dailyData) {
                          if (item['amount'] > maxValue)
                            maxValue = item['amount'];
                        }
                        maxValue = maxValue > 0 ? maxValue : 10;

                        return CustomPaint(
                          size:
                              Size(constraints.maxWidth, constraints.maxHeight),
                          painter: BarChartPainter(
                            data: dailyData,
                            maxValue: maxValue,
                            barColor: const Color(
                                0xFF2E7D32), // Match analytics primary color
                            labelField: 'day',
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painters for Charts
class LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double maxValue;
  final Color lineColor;

  LineChartPainter({
    required this.data,
    required this.maxValue,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final Paint linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          lineColor.withOpacity(0.5),
          lineColor.withOpacity(0.1),
          lineColor.withOpacity(0.0),
        ],
        stops: const [0.1, 0.6, 0.9],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Paint pointStrokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final Paint pointFillPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final Paint gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final textStyle = TextStyle(
      color: Colors.grey[600],
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    final TextPainter textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );

    // Draw horizontal grid lines with dashed pattern
    for (int i = 0; i <= 5; i++) {
      double y = size.height - (i * size.height / 5);

      // Draw dashed line
      double dashWidth = 5, dashSpace = 5, startX = 0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, y),
          Offset(startX + dashWidth, y),
          gridPaint,
        );
        startX += dashWidth + dashSpace;
      }

      // Draw y-axis labels
      textPainter.text = TextSpan(
        text: (i * maxValue / 5).toStringAsFixed(0),
        style: textStyle,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width - 5, y - textPainter.height / 2),
      );
    }

    // Create path for the line and fill
    final Path path = Path();
    final Path fillPath = Path();

    // Use a smoother curve by adding control points
    List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      final x = i * (size.width / (data.length - 1));
      final y = size.height - (data[i]['count'] / maxValue * size.height);
      points.add(Offset(x, y));
    }

    // Start paths
    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);
      fillPath.moveTo(points[0].dx, size.height);
      fillPath.lineTo(points[0].dx, points[0].dy);
    }

    // Add curved segments
    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];

      // Calculate control points for a smoother curve
      final controlPointX = current.dx + (next.dx - current.dx) / 2;

      path.cubicTo(
          controlPointX, current.dy, controlPointX, next.dy, next.dx, next.dy);

      fillPath.cubicTo(
          controlPointX, current.dy, controlPointX, next.dy, next.dx, next.dy);
    }

    // Close fill path
    if (points.isNotEmpty) {
      fillPath.lineTo(points.last.dx, size.height);
      fillPath.close();
    }

    // Draw the fill and line
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Draw data points with white border
    for (int i = 0; i < data.length; i++) {
      final x = i * (size.width / (data.length - 1));
      final y = size.height - (data[i]['count'] / maxValue * size.height);

      // Draw outer white circle
      canvas.drawCircle(Offset(x, y), 5, pointStrokePaint);
      // Draw inner colored circle
      canvas.drawCircle(Offset(x, y), 3.5, pointFillPaint);
    }

    // Draw x-axis labels
    for (int i = 0; i < data.length; i++) {
      final x = i * (size.width / (data.length - 1));

      // Format date for display (assuming date is in format "dd/mm")
      String displayText = data[i]['date'].split('/')[0]; // Just the day

      textPainter.text = TextSpan(
        text: displayText,
        style: textStyle,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height + 5),
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class BarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double maxValue;
  final Color barColor;
  final String labelField;

  BarChartPainter({
    required this.data,
    required this.maxValue,
    required this.barColor,
    this.labelField = 'month',
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final Paint barPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          barColor,
          barColor.withOpacity(0.7),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Paint gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final textStyle = TextStyle(
      color: Colors.grey[600],
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    final TextPainter textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );

    // Draw horizontal grid lines with dashed pattern
    for (int i = 0; i <= 5; i++) {
      double y = size.height - (i * size.height / 5);

      // Draw dashed line
      double dashWidth = 5, dashSpace = 5, startX = 0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, y),
          Offset(startX + dashWidth, y),
          gridPaint,
        );
        startX += dashWidth + dashSpace;
      }

      // Draw y-axis labels
      textPainter.text = TextSpan(
        text: (i * maxValue / 5).toStringAsFixed(1),
        style: textStyle,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width - 5, y - textPainter.height / 2),
      );
    }

    // Draw bars with improved style
    final barWidth = (size.width / data.length) * 0.65; // Slightly thinner bars
    final spacing = (size.width / data.length) * 0.35;

    for (int i = 0; i < data.length; i++) {
      final x = i * (barWidth + spacing) + spacing / 2;
      final barHeight = (data[i]['amount'] / maxValue) *
          size.height *
          0.9; // Leave room for labels
      final y = size.height - barHeight;

      // Create rounded rectangle for bar
      final RRect roundedRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );

      // Draw bar shadow
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x + 1, y + 2, barWidth, barHeight),
          topLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
        ),
        Paint()
          ..color = Colors.black.withOpacity(0.1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      // Draw bar
      canvas.drawRRect(roundedRect, barPaint);

      // Draw value on top of bar with better styling
      final String valueText = data[i]['amount'].toStringAsFixed(1);
      textPainter.text = TextSpan(
        text: valueText,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();

      // Draw value background for better readability
      final textX = x + barWidth / 2 - textPainter.width / 2;
      final textY = y - textPainter.height - 6;

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(textX - 4, textY - 2, textPainter.width + 8,
              textPainter.height + 4),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
          bottomLeft: const Radius.circular(4),
          bottomRight: const Radius.circular(4),
        ),
        Paint()..color = Colors.white.withOpacity(0.8),
      );

      textPainter.paint(canvas, Offset(textX, textY));

      // Draw x-axis label with better styling
      textPainter.text = TextSpan(
        text: data[i][labelField],
        style: textStyle,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + barWidth / 2 - textPainter.width / 2, size.height + 5),
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description,
              size: 100,
              color: Colors.teal.shade200,
            ),
            const SizedBox(height: 24),
            const Text(
              'Reports',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'View and manage reports here',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminAccessRolesScreen extends StatelessWidget {
  const AdminAccessRolesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.admin_panel_settings,
              size: 100,
              color: Colors.blue.shade300,
            ),
            const SizedBox(height: 24),
            const Text(
              'Admin Access Roles',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Manage administrator access roles and permissions',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminUserMaintenanceScreen extends StatelessWidget {
  const AdminUserMaintenanceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.manage_accounts,
              size: 100,
              color: Colors.purple.shade300,
            ),
            const SizedBox(height: 24),
            const Text(
              'Admin User Maintenance',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add, edit, and manage administrator accounts',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
