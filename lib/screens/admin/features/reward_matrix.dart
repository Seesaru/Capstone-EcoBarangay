import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../functions/add_reward_matrix.dart';

class RewardMatrixScreen extends StatefulWidget {
  const RewardMatrixScreen({Key? key}) : super(key: key);

  @override
  State<RewardMatrixScreen> createState() => _RewardMatrixScreenState();
}

class _RewardMatrixScreenState extends State<RewardMatrixScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String _adminBarangay = '';
  List<Map<String, dynamic>> _rewardMatrix = [];
  String? _errorMessage;
  bool _showAddMatrix = false;

  // Updated color scheme to match admin dashboard
  final Color primaryColor = const Color(0xFF4CAF50); // Green primary
  final Color backgroundColor = Colors.grey.shade50; // Light gray background
  final Color cardColor = Colors.white;
  final Color textColor = Colors.grey.shade800;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No user is currently logged in';
        });
        return;
      }

      // Get admin data to get the barangay
      DocumentSnapshot adminDoc = await _firestore
          .collection('barangay_admins')
          .doc(currentUser.uid)
          .get();

      if (!adminDoc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Admin data not found';
        });
        return;
      }

      Map<String, dynamic> adminData = adminDoc.data() as Map<String, dynamic>;
      _adminBarangay = adminData['barangay'] ?? 'Unknown Barangay';

      // Load reward matrix for this barangay
      await _loadRewardMatrix();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading admin data: ${e.toString()}';
      });
    }
  }

  Future<void> _loadRewardMatrix() async {
    try {
      // Query reward_matrix collection for documents with this barangayId
      QuerySnapshot matrixSnap = await _firestore
          .collection('reward_matrix')
          .where('barangayId', isEqualTo: _adminBarangay)
          .orderBy('minKg', descending: false)
          .get();

      List<Map<String, dynamic>> matrix = [];
      for (var doc in matrixSnap.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Add document ID for later reference
        matrix.add(data);
      }

      setState(() {
        _rewardMatrix = matrix;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading reward matrix: ${e.toString()}';
      });
    }
  }

  Future<void> _addRewardEntry() async {
    setState(() {
      _showAddMatrix = true;
    });
  }

  Future<void> _deleteRewardEntry(String documentId) async {
    try {
      await _firestore.collection('reward_matrix').doc(documentId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reward matrix entry deleted'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadRewardMatrix(); // Reload the matrix
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting entry: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showAddMatrix) {
      return AddRewardMatrixScreen(
        barangayId: _adminBarangay,
        onBackPressed: () {
          setState(() {
            _showAddMatrix = false;
          });
          _loadRewardMatrix(); // Reload the matrix after going back
        },
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: primaryColor,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadAdminData,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reward Matrix',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage waste collection rewards for $_adminBarangay',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _addRewardEntry,
                icon: const Icon(Icons.add),
                label: const Text('Add Reward'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          if (_rewardMatrix.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No reward matrix entries found',
                    style: TextStyle(
                      fontSize: 18,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add rewards based on waste quantities',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _rewardMatrix.length,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  final reward = _rewardMatrix[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left side - Icon
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.eco,
                              color: primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Middle - Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${reward['minKg']} to ${reward['maxKg']} kg',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Points: ${reward['points']}',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                if (reward['description'] != null &&
                                    reward['description'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      reward['description'],
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Right side - Delete button
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.red.shade400,
                              size: 24,
                            ),
                            onPressed: () =>
                                _showDeleteConfirmation(reward['id']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(String documentId) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Reward Entry'),
          content: const Text(
              'Are you sure you want to delete this reward matrix entry?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteRewardEntry(documentId);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
