import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:capstone_ecobarangay/screens/others/reusable_widgets.dart';
import 'package:capstone_ecobarangay/services/authentication.dart';
import 'package:capstone_ecobarangay/screens/residents/resident_dashboard.dart/features/profile/edit_profile.dart';
import 'package:capstone_ecobarangay/screens/residents/resident_dashboard.dart/features/profile/resident_scan_history.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  String _fullName = '';
  String _email = '';
  String _barangay = '';
  String _profileImageUrl = '';
  int _rewardPoints = 0;
  int _warnings = 0;
  int _penalties = 0;
  String _qrCodeData = '';
  StreamSubscription? _pointsSubscription;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _pointsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Get initial data
        DocumentSnapshot userDoc =
            await _firestore.collection('resident').doc(currentUser.uid).get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;

          setState(() {
            _fullName = userData['fullName'] ?? 'Resident';
            _email = userData['email'] ?? currentUser.email ?? '';
            _barangay = userData['barangay'] ?? '';
            _profileImageUrl = userData['profileImageUrl'] ?? '';

            // Get QR code data
            _qrCodeData = userData['qrCodeData'] ?? currentUser.uid;

            // Check both fields for points (for backward compatibility)
            _rewardPoints = userData['points'] ?? userData['rewardPoints'] ?? 0;

            // Get warnings and penalties (default to 0 if not found)
            _warnings = userData['warnings'] ?? 0;
            _penalties = userData['penalties'] ?? 0;
          });

          // Set up real-time listener for points updates
          _pointsSubscription = _firestore
              .collection('resident')
              .doc(currentUser.uid)
              .snapshots()
              .listen((documentSnapshot) {
            if (documentSnapshot.exists) {
              Map<String, dynamic> data =
                  documentSnapshot.data() as Map<String, dynamic>;
              setState(() {
                // Check both fields for points (for backward compatibility)
                _rewardPoints = data['points'] ?? data['rewardPoints'] ?? 0;
                _warnings = data['warnings'] ?? 0;
                _penalties = data['penalties'] ?? 0;
              });
            }
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
      try {
        // Get current user ID before logging out
        final String userId = _auth.currentUser?.uid ?? '';

        // Log the logout event if we have a valid user ID
        if (userId.isNotEmpty) {
          await _authService.logResidentLogout(userId);
        }

        // Sign out
        await _auth.signOut();

        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } catch (e) {
        print('Error during logout: ${e.toString()}');
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error logging out. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _editProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          currentFullName: _fullName,
          currentEmail: _email,
          currentBarangay: _barangay,
          currentProfileImageUrl: _profileImageUrl,
        ),
      ),
    ).then((result) {
      // Refresh profile if changes were made
      if (result == true) {
        _fetchUserProfile();
      }
    });
  }

  void _showPointsDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            // Set a constraints to avoid overflow
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Points & Status',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 25),
                // Points display
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  decoration: BoxDecoration(
                    color:
                        const Color.fromARGB(255, 3, 144, 123).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        FontAwesomeIcons.coins,
                        color: Colors.amber,
                        size: 24,
                      ),
                      const SizedBox(width: 15),
                      Text(
                        '$_rewardPoints',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 3, 144, 123),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'points',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color.fromARGB(255, 3, 144, 123),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                // Warnings
                _buildStatusItem(
                  icon: Icons.warning_amber_rounded,
                  title: 'Warnings',
                  count: _warnings,
                  color: Colors.orange,
                ),
                const SizedBox(height: 15),
                // Penalties
                _buildStatusItem(
                  icon: Icons.gavel_rounded,
                  title: 'Penalties',
                  count: _penalties,
                  color: Colors.red,
                ),
                const SizedBox(height: 25),
                // Information text
                Text(
                  'Engage in eco-friendly activities to earn points. Avoid violations to prevent warnings and penalties.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQRCode() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: Container(
          padding: const EdgeInsets.all(24.0),
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your QR Code',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 3, 144, 123),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Show this to waste collectors',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color.fromARGB(255, 3, 144, 123),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: QrImageView(
                    data: _qrCodeData,
                    version: QrVersions.auto,
                    size: 240.0,
                    padding: const EdgeInsets.all(0),
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color.fromARGB(255, 3, 144, 123),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _fullName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                'Barangay $_barangay',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: 260,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 3, 144, 123),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
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
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        title: const Text(
          "Profile",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        actions: [
          // Points indicator (now clickable)
          GestureDetector(
            onTap: _showPointsDetails,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    FontAwesomeIcons.coins,
                    color: Colors.amber,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_rewardPoints pts',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
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
                          child: Text(
                            'Barangay $_barangay',
                            style: const TextStyle(
                              color: Color.fromARGB(255, 3, 144, 123),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // My Activity Section
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
                          title: 'My Activity',
                          accentColor: Color.fromARGB(255, 3, 144, 123),
                        ),
                        const SizedBox(height: 16),
                        _buildAppInfoItem(
                          icon: Icons.qr_code_scanner,
                          title: 'View Scan History',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ResidentScanHistoryScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        _buildAppInfoItem(
                          icon: Icons.qr_code,
                          title: 'Show My QR Code',
                          onTap: _showQRCode,
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
