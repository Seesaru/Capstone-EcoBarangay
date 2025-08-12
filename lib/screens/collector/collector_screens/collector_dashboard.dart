import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:capstone_ecobarangay/screens/collector/collector_screens/collector_home.dart';
import 'package:capstone_ecobarangay/screens/collector/collector_screens/collector_schedule.dart';
import 'package:capstone_ecobarangay/screens/collector/collector_screens/collector_announcements.dart';
import 'package:capstone_ecobarangay/screens/collector/collector_screens/collector_profile.dart';
import 'package:capstone_ecobarangay/screens/collector/collector_screens/collector_reports.dart';
import 'package:capstone_ecobarangay/screens/collector/features/collector_scan.dart';

class CollectorDashboardScreen extends StatefulWidget {
  const CollectorDashboardScreen({super.key});

  @override
  _CollectorDashboardScreenState createState() =>
      _CollectorDashboardScreenState();
}

class _CollectorDashboardScreenState extends State<CollectorDashboardScreen> {
  int _currentIndex = 0;

  // List of screens for collector dashboard
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const CollectorHomeScreen(),
      const CollectorAnnouncementsScreen(),
      const CollectorScheduleScreen(),
      const CollectorReportScreen(),
      const CollectorProfileScreen(),
    ];
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      // Regular bottom navigation bar with 5 items
      bottomNavigationBar: SizedBox(
        height: 70.0, // Increased height for better visibility
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color.fromARGB(255, 3, 144, 123),
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.bullhorn),
              label: 'Announcements',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.calendarCheck),
              label: 'Schedule',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.chartBar),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.userAlt),
              label: 'Profile',
            ),
          ],
          iconSize: 25.0,
          selectedFontSize: 12.0,
          unselectedFontSize: 10.0,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          backgroundColor: Colors.white,
          elevation: 5.0,
        ),
      ),
      // Floating action button for scanning
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const CollectorScanScreen()),
          );
        },
        backgroundColor: const Color.fromARGB(255, 3, 144, 123),
        elevation: 8.0,
        child: const Icon(
          FontAwesomeIcons.qrcode,
          size: 25,
          color: Colors.white,
        ),
      ),
    );
  }
}
