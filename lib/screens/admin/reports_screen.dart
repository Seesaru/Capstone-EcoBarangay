import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Add ReportDetailDialog class
class ReportDetailDialog {
  static void show(BuildContext context, Map<String, dynamic> report,
      {bool isAdmin = false}) {
    final formatter = DateFormat('MMM dd, yyyy • h:mm a');
    final DateTime reportDate = report['date'] is Timestamp
        ? (report['date'] as Timestamp).toDate()
        : DateTime.now();
    final formattedDate = formatter.format(reportDate);

    // Calculate the screen size
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width * 0.85;
    final dialogHeight = screenSize.height * 0.8;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        insetPadding: EdgeInsets.symmetric(
          horizontal: screenSize.width * 0.075,
          vertical: screenSize.height * 0.1,
        ),
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(
            maxWidth: 800,
            maxHeight: dialogHeight,
            minHeight: 400,
            minWidth: 600,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Report header with category color
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getCategoryColorFromName(
                      report['category'] ?? 'General'),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Report Details',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Report content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and date
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report['title'] ?? 'No Title',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    report['category'] ?? 'General',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),

                            // Status chip
                            if (report['status'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColorForChip(
                                        report['status']),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    report['status'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),

                            // Location
                            if (report['location'] != null &&
                                report['location'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Colors.grey[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        report['location'].toString(),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Content divider
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Divider(color: Colors.grey[300]),
                            ),

                            // Main content
                            Text(
                              report['content'] ?? 'No content',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Image section
                      if (report['imageUrl'] != null &&
                          report['imageUrl'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image section title
                              Text(
                                "Attached Image",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Image container centered
                              Container(
                                width: double.infinity,
                                height:
                                    MediaQuery.of(context).size.height * 0.4,
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey[100],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: GestureDetector(
                                    onTap: () {
                                      // Show full-screen image viewer
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => Dialog(
                                          insetPadding: EdgeInsets.zero,
                                          child: Stack(
                                            alignment: Alignment.topRight,
                                            children: [
                                              InteractiveViewer(
                                                panEnabled: true,
                                                minScale: 0.5,
                                                maxScale: 4,
                                                child: Image.network(
                                                  report['imageUrl'],
                                                  fit: BoxFit.contain,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  loadingBuilder: (context,
                                                      child, loadingProgress) {
                                                    if (loadingProgress == null)
                                                      return child;
                                                    return Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                        value: loadingProgress
                                                                    .expectedTotalBytes !=
                                                                null
                                                            ? loadingProgress
                                                                    .cumulativeBytesLoaded /
                                                                loadingProgress
                                                                    .expectedTotalBytes!
                                                            : null,
                                                      ),
                                                    );
                                                  },
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Center(
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.error,
                                                              color: Colors.red,
                                                              size: 32),
                                                          const SizedBox(
                                                              height: 8),
                                                          Text(
                                                              'Failed to load image',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      600])),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: IconButton(
                                                  icon: const Icon(Icons.close,
                                                      color: Colors.white),
                                                  onPressed: () =>
                                                      Navigator.of(ctx).pop(),
                                                  style: IconButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.black54,
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    child: Hero(
                                      tag: 'report_image_${report['id']}',
                                      child: Image.network(
                                        report['imageUrl'],
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                  : null,
                                            ),
                                          );
                                        },
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.broken_image,
                                                    color: Colors.grey[400],
                                                    size: 40),
                                                const SizedBox(height: 8),
                                                Text('Image not available',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[600])),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Author info
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.grey[300],
                                radius: 24,
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    report['author'] != null
                                        ? report['author'].toString()
                                        : 'Anonymous',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    report['authorRole'] != null
                                        ? report['authorRole'].toString()
                                        : 'Resident',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              // User type badge
                              if (report['userType'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: report['userType'] == 'collector'
                                        ? const Color.fromARGB(255, 3, 144, 123)
                                            .withOpacity(0.1)
                                        : Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: report['userType'] == 'collector'
                                          ? const Color.fromARGB(
                                                  255, 3, 144, 123)
                                              .withOpacity(0.3)
                                          : Colors.orange.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    report['userType'] == 'collector'
                                        ? 'Collector'
                                        : 'Resident',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: report['userType'] == 'collector'
                                          ? const Color.fromARGB(
                                              255, 3, 144, 123)
                                          : Colors.orange,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Admin actions
              if (isAdmin)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Close dialog first
                            Navigator.of(context).pop();

                            // Show status update options
                            _showStatusUpdateBottomSheet(context, report['id']);
                          },
                          icon: const Icon(Icons.update),
                          label: const Text('Update Status'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to show status update bottom sheet
  static void _showStatusUpdateBottomSheet(
      BuildContext context, String reportId) {
    final _AdminReportsScreenState? adminState =
        context.findAncestorStateOfType<_AdminReportsScreenState>();

    if (adminState == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Update Report Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.check_circle_outline, color: Colors.green),
              title: const Text('Mark as Resolved'),
              onTap: () {
                Navigator.pop(context);
                adminState._updateReportStatus(reportId, 'Resolved');
              },
            ),
            ListTile(
              leading: const Icon(Icons.pending_actions, color: Colors.orange),
              title: const Text('Mark as In Progress'),
              onTap: () {
                Navigator.pop(context);
                adminState._updateReportStatus(reportId, 'In Progress');
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: Colors.red),
              title: const Text('Mark as Rejected'),
              onTap: () {
                Navigator.pop(context);
                adminState._updateReportStatus(reportId, 'Rejected');
              },
            ),
          ],
        ),
      ),
    );
  }

  static Color _getStatusColorForChip(String status) {
    switch (status) {
      case 'New':
        return Colors.blue;
      case 'In Progress':
        return Colors.orange;
      case 'Resolved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static Color _getCategoryColorFromName(String categoryName) {
    switch (categoryName) {
      case 'Infrastructure':
        return Colors.amber;
      case 'Sanitation':
        return Colors.green;
      case 'Flooding':
        return Colors.blue;
      case 'Animal Welfare':
        return Colors.brown;
      default:
        return const Color(0xFF4CAF50); // Default color
    }
  }
}

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedSortOption = 'Latest';
  int _selectedCategoryIndex = 0;

  // Admin color scheme to match dashboard
  final Color primaryColor = const Color(0xFF1E1E1E);
  final Color accentColor = const Color(0xFF4CAF50);
  final Color backgroundColor = Colors.grey.shade100;
  final Color cardColor = Colors.white;
  final Color textColor = Colors.grey.shade800;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Admin data
  String _adminBarangay = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];
  bool _isDisposed = false;

  // Category data
  final List<Map<String, dynamic>> _categoryData = [
    {
      'name': 'All',
      'icon': FontAwesomeIcons.listUl,
      'color': const Color(0xFF4CAF50),
    },
    {
      'name': 'Infrastructure',
      'icon': FontAwesomeIcons.road,
      'color': Colors.amber,
    },
    {
      'name': 'Sanitation',
      'icon': FontAwesomeIcons.trash,
      'color': Colors.green,
    },
    {
      'name': 'Flooding',
      'icon': FontAwesomeIcons.water,
      'color': Colors.blue,
    },
    {
      'name': 'Animal Welfare',
      'icon': FontAwesomeIcons.paw,
      'color': Colors.brown,
    },
  ];

  // Sort options
  final List<String> _sortOptions = [
    'Latest',
    'This Week',
    'This Month',
    'Oldest',
  ];

  @override
  void initState() {
    super.initState();
    _fetchAdminBarangay();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _isDisposed = true;
    super.dispose();
  }

  // Fetch the admin's barangay
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

          // Now fetch reports for this barangay
          await _fetchReports();
        }
      }
    } catch (e) {
      print('Error fetching admin barangay: ${e.toString()}');
      if (!_isDisposed) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Fetch reports from Firestore
  Future<void> _fetchReports() async {
    if (_adminBarangay.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Create a base query that only filters by barangay and orders by date
      // This avoids composite index requirements
      Query query = _firestore
          .collection('reports')
          .where('residentBarangay', isEqualTo: _adminBarangay)
          .orderBy('date', descending: _selectedSortOption != 'Oldest');

      // Execute the query
      QuerySnapshot querySnapshot = await query.get();

      List<Map<String, dynamic>> fetchedReports = [];

      // Get the current date for client-side filtering
      DateTime now = DateTime.now();
      DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      startOfWeek =
          DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      DateTime startOfMonth = DateTime(now.year, now.month, 1);

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Convert Timestamp to DateTime
        DateTime reportDate = DateTime.now();
        if (data['date'] is Timestamp) {
          reportDate = (data['date'] as Timestamp).toDate();
        }

        // Client-side category filtering
        if (_selectedCategoryIndex > 0) {
          String selectedCategory =
              _categoryData[_selectedCategoryIndex]['name'];
          if (data['category'] != selectedCategory) {
            continue; // Skip this document if category doesn't match
          }
        }

        // Client-side date filtering
        if (_selectedSortOption == 'This Week' &&
            reportDate.isBefore(startOfWeek)) {
          continue; // Skip if the report is from before this week
        } else if (_selectedSortOption == 'This Month' &&
            reportDate.isBefore(startOfMonth)) {
          continue; // Skip if the report is from before this month
        }

        // Client-side text search filtering
        if (_searchQuery.isNotEmpty) {
          String title = (data['title'] ?? '').toString().toLowerCase();
          String content = (data['content'] ?? '').toString().toLowerCase();
          String location = (data['location'] ?? '').toString().toLowerCase();
          String author = (data['author'] ?? '').toString().toLowerCase();

          if (!title.contains(_searchQuery.toLowerCase()) &&
              !content.contains(_searchQuery.toLowerCase()) &&
              !location.contains(_searchQuery.toLowerCase()) &&
              !author.contains(_searchQuery.toLowerCase())) {
            continue; // Skip this document if it doesn't match the search
          }
        }

        // Add this report to the list
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
          'imageUrl': data['imageUrl'] ?? '',
        });
      }

      if (!_isDisposed) {
        setState(() {
          _reports = fetchedReports;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching reports: $e');
      if (!_isDisposed) {
        setState(() {
          _isLoading = false;
        });

        // Show error message if still in context
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading reports: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdminReportHeader(),
          _buildFilterSection(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: accentColor))
                : _buildReportsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminReportHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Community Reports',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textColor),
              ),
              Text(
                'Manage and respond to reports',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Search Bar
          Container(
            width: 300,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                )
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(fontSize: 14),
                prefixIcon: Icon(
                  Icons.search,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _isLoading = true;
                });
                // Debounce the search query slightly to avoid too many fetches
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (_searchQuery == value) {
                    _fetchReports();
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Filter Section with Container
        Container(
          height: 70,
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categoryData.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 8 : 0,
                        right: 6,
                      ),
                      child: Center(
                        child: _buildCategoryTab(
                          _categoryData[index]['name'] as String,
                          _categoryData[index]['icon'] as IconData,
                          _categoryData[index]['color'] as Color,
                          _selectedCategoryIndex == index,
                          index,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Sorting Options (Without Container)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Text(
                'Sort by:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 12),
              ...List.generate(
                _sortOptions.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_sortOptions[index]),
                    selected: _selectedSortOption == _sortOptions[index],
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedSortOption = _sortOptions[index];
                          _isLoading = true;
                        });
                        _fetchReports();
                      }
                    },
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: accentColor,
                    labelStyle: TextStyle(
                      color: _selectedSortOption == _sortOptions[index]
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Active Filters Section
        _buildActiveFilters(),
      ],
    );
  }

  Widget _buildCategoryTab(
    String name,
    IconData icon,
    Color color,
    bool isSelected,
    int index,
  ) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategoryIndex = index;
          _isLoading = true;
        });
        _fetchReports();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilters() {
    final List<Widget> filterChips = [];

    // Add category filter
    if (_selectedCategoryIndex > 0) {
      filterChips.add(
        Chip(
          label: Text(
            'Category: ${_categoryData[_selectedCategoryIndex]['name']}',
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          backgroundColor:
              _categoryData[_selectedCategoryIndex]['color'] as Color,
          deleteIconColor: Colors.white,
          onDeleted: () {
            setState(() {
              _selectedCategoryIndex = 0;
              _isLoading = true;
            });
            _fetchReports();
          },
        ),
      );
    }

    // Add sort filter
    if (_selectedSortOption != 'Latest') {
      filterChips.add(
        Chip(
          label: Text(
            'Sort: $_selectedSortOption',
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          backgroundColor: accentColor,
          deleteIconColor: Colors.white,
          onDeleted: () {
            setState(() {
              _selectedSortOption = 'Latest';
              _isLoading = true;
            });
            _fetchReports();
          },
        ),
      );
    }

    // Add search filter
    if (_searchQuery.isNotEmpty) {
      filterChips.add(
        Chip(
          label: Text(
            'Search: $_searchQuery',
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          backgroundColor: Colors.blue,
          deleteIconColor: Colors.white,
          onDeleted: () {
            setState(() {
              _searchQuery = '';
              _searchController.clear();
              _isLoading = true;
            });
            _fetchReports();
          },
        ),
      );
    }

    if (filterChips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          const Text(
            'Active Filters: ',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          ...filterChips,
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedCategoryIndex = 0;
                _selectedSortOption = 'Latest';
                _searchQuery = '';
                _searchController.clear();
                _isLoading = true;
              });
              _fetchReports();
            },
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Clear All'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList() {
    // Placeholder for empty state
    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.report_off_outlined,
                size: 60,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No reports found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'There are no reports matching your current filters',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.0,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        return _buildReportCard(_reports[index]);
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'New':
        return Colors.blue;
      case 'In Progress':
        return Colors.orange;
      case 'Resolved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    for (var item in _categoryData) {
      if (item['name'] == category) {
        return item['icon'] as IconData;
      }
    }
    return FontAwesomeIcons.question;
  }

  Color _getCategoryColor(String category) {
    for (var item in _categoryData) {
      if (item['name'] == category) {
        return item['color'] as Color;
      }
    }
    return Colors.grey;
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final formatter = DateFormat('MMM dd, yyyy • h:mm a');
    final formattedDate = formatter.format(report['date'] as DateTime);

    final categoryColor = _getCategoryColor(report['category'] ?? 'All');
    final categoryIcon = _getCategoryIcon(report['category'] ?? 'All');
    final statusColor = _getStatusColor(report['status']);

    return GestureDetector(
      onTap: () {
        // Show the report detail dialog when a card is tapped
        ReportDetailDialog.show(context, report, isAdmin: true);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored header based on category
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: categoryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    categoryIcon,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    report['category'] ?? 'General',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  // Status chip if available
                  if (report['status'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        report['status'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Title and date section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Location info in badge
                            if (report['location'] != null &&
                                report['location'].toString().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 12,
                                      color: Colors.grey[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      report['location'].toString().length > 20
                                          ? '${report['location'].toString().substring(0, 20)}...'
                                          : report['location'].toString(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const Spacer(),
                            // Date
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Title
                        Text(
                          report['title'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                report['content'],
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.grey[700],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Author info and admin actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        radius: 16,
                        child: const Icon(
                          Icons.person,
                          color: Colors.grey,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report['author'] != null
                                  ? report['author'].toString()
                                  : 'Anonymous',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              report['authorRole'] != null
                                  ? report['authorRole'].toString()
                                  : 'Resident',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // User type badge
                      if (report['userType'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: report['userType'] == 'collector'
                                ? const Color.fromARGB(255, 3, 144, 123)
                                    .withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: report['userType'] == 'collector'
                                  ? const Color.fromARGB(255, 3, 144, 123)
                                      .withOpacity(0.3)
                                  : Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            report['userType'] == 'collector'
                                ? 'Collector'
                                : 'Resident',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: report['userType'] == 'collector'
                                  ? const Color.fromARGB(255, 3, 144, 123)
                                  : Colors.orange,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Admin action buttons
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildAdminActionButton(
                        icon: Icons.reply,
                        label: 'Respond',
                        onTap: () {
                          // Show response dialog
                          ReportDetailDialog.show(context, report,
                              isAdmin: true);
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildAdminActionButton(
                        icon: Icons.check_circle_outline,
                        label: 'Mark Resolved',
                        onTap: () {
                          _updateReportStatus(report['id'], 'Resolved');
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildAdminActionButton(
                        icon: Icons.more_horiz,
                        label: 'More',
                        onTap: () {
                          _showOptionsMenu(context, report['id'], report);
                        },
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

  Widget _buildAdminActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: Colors.black87,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Update the status of a report in Firestore
  void _updateReportStatus(String reportId, String newStatus) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Update the report status in Firestore
      await _firestore.collection('reports').doc(reportId).update({
        'status': newStatus,
        'lastUpdated': Timestamp.now(),
      });

      // Show success message
      if (!_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report marked as $newStatus'),
            backgroundColor: _getStatusColor(newStatus),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Refresh the reports list
      await _fetchReports();
    } catch (e) {
      print('Error updating report status: $e');
      if (!_isDisposed) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error updating report status'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showOptionsMenu(
      BuildContext context, String reportId, Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.check_circle_outline, color: Colors.green),
              title: const Text('Mark as Resolved'),
              onTap: () {
                Navigator.pop(context);
                _updateReportStatus(reportId, 'Resolved');
              },
            ),
            ListTile(
              leading: const Icon(Icons.pending_actions, color: Colors.orange),
              title: const Text('Mark as In Progress'),
              onTap: () {
                Navigator.pop(context);
                _updateReportStatus(reportId, 'In Progress');
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: Colors.red),
              title: const Text('Mark as Rejected'),
              onTap: () {
                Navigator.pop(context);
                _updateReportStatus(reportId, 'Rejected');
              },
            ),
            // Add a delete option
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.grey),
              title: const Text('Delete Report'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, reportId);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context, String reportId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text(
            'Are you sure you want to delete this report? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteReport(reportId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Delete a report from Firestore
  void _deleteReport(String reportId) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Delete the report from Firestore
      await _firestore.collection('reports').doc(reportId).delete();

      // Show success message
      if (!_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report deleted successfully'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Refresh the reports list
      await _fetchReports();
    } catch (e) {
      print('Error deleting report: $e');
      if (!_isDisposed) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error deleting report'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
