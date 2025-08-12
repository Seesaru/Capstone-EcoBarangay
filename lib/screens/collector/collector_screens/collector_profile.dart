import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:capstone_ecobarangay/screens/others/reusable_widgets.dart';
import 'package:capstone_ecobarangay/services/collector_auth.dart';
import 'package:capstone_ecobarangay/screens/collector/features/collector_edit_profile.dart';
import 'package:capstone_ecobarangay/screens/collector/features/collector_scan_history.dart';

class CollectorProfileScreen extends StatefulWidget {
  const CollectorProfileScreen({super.key});

  @override
  State<CollectorProfileScreen> createState() => _CollectorProfileScreenState();
}

class _CollectorProfileScreenState extends State<CollectorProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectorAuthService _collectorAuthService = CollectorAuthService();

  bool _isLoading = true;
  String _fullName = '';
  String _email = '';
  String _barangay = '';
  String _profileImageUrl = '';
  int _scansCompleted = 0;

  @override
  void initState() {
    super.initState();
    _fetchCollectorProfile();
  }

  Future<void> _fetchCollectorProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('collector').doc(currentUser.uid).get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;

          // Get the actual scan count from Firestore
          final scansCount = await _firestore
              .collection('scans')
              .where('collectorId', isEqualTo: currentUser.uid)
              .count()
              .get();

          setState(() {
            _fullName = userData['fullName'] ?? 'Collector';
            _email = userData['email'] ?? currentUser.email ?? '';
            _barangay = userData['barangay'] ?? '';
            _profileImageUrl = userData['profileImageUrl'] ?? '';
            _scansCompleted = scansCount.count ?? 0;
          });
        }
      }
    } catch (e) {
      print('Error fetching profile: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _logout() async {
    bool confirmLogout = await showSlideUpLogoutConfirmation(context);

    if (confirmLogout) {
      await _collectorAuthService.signOut();

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  void _editProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CollectorEditProfileScreen(
          currentFullName: _fullName,
          currentEmail: _email,
          currentBarangay: _barangay,
          currentProfileImageUrl: _profileImageUrl,
        ),
      ),
    ).then((result) {
      // Refresh profile if changes were made
      if (result == true) {
        _fetchCollectorProfile();
      }
    });
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
        title: const Text(
          "Collector Profile",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: const Color.fromARGB(255, 3, 144, 123),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile header with avatar
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Stack(
                          children: [
                            // Avatar
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color.fromARGB(255, 3, 144, 123),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: _profileImageUrl.isNotEmpty
                                    ? NetworkImage(_profileImageUrl)
                                    : null,
                                child: _profileImageUrl.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.grey,
                                      )
                                    : null,
                              ),
                            ),
                            // Edit button
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _editProfile,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color.fromARGB(255, 3, 144, 123),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 3, 144, 123)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                FontAwesomeIcons.truckLoading,
                                size: 14,
                                color: Color.fromARGB(255, 3, 144, 123),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Collector - Barangay $_barangay',
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 3, 144, 123),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Collector Stats Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          offset: const Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Collector Stats',
                          accentColor: Color.fromARGB(255, 3, 144, 123),
                        ),
                        const SizedBox(height: 16),
                        _buildStatItem(
                          icon: FontAwesomeIcons.check,
                          title: 'Scans Completed',
                          value: '$_scansCompleted',
                        ),
                        const Divider(),
                        _buildStatItem(
                          icon: FontAwesomeIcons.calendarCheck,
                          title: 'Active Since',
                          value: 'April 2023',
                        ),
                        const Divider(),
                        // View Scan History Button
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CollectorScanHistoryScreen(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Icon(
                                  FontAwesomeIcons.history,
                                  color: const Color.fromARGB(255, 3, 144, 123),
                                  size: 20,
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Text(
                                    'View Scan History',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.grey.shade400,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // App Info Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          offset: const Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'App Info',
                          accentColor: Color.fromARGB(255, 3, 144, 123),
                        ),
                        const SizedBox(height: 16),
                        _buildAppInfoItem(
                          icon: Icons.description_outlined,
                          title: 'Terms of Service',
                          onTap: () {
                            // Navigate to terms of service
                          },
                        ),
                        const Divider(),
                        _buildAppInfoItem(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Policy',
                          onTap: () {
                            // Navigate to privacy policy
                          },
                        ),
                        const Divider(),
                        _buildAppInfoItem(
                          icon: Icons.info_outline,
                          title: 'About Us',
                          onTap: () {
                            // Navigate to about us
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Contact & Support Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          offset: const Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Contact & Support',
                          accentColor: Color.fromARGB(255, 3, 144, 123),
                        ),
                        const SizedBox(height: 16),
                        _buildAppInfoItem(
                          icon: Icons.support_agent,
                          title: 'Contact Support',
                          onTap: () {
                            // Navigate to contact support
                          },
                        ),
                        const Divider(),
                        _buildAppInfoItem(
                          icon: Icons.help_outline,
                          title: 'FAQs',
                          onTap: () {
                            // Navigate to FAQs
                          },
                        ),
                        const Divider(),
                        _buildAppInfoItem(
                          icon: Icons.feedback_outlined,
                          title: 'Send Feedback',
                          onTap: () {
                            // Navigate to feedback form
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Logout Button
                  Center(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout),
                        label: const Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color.fromARGB(255, 3, 144, 123),
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 3, 144, 123),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfoItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color.fromARGB(255, 3, 144, 123),
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
