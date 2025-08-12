import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminAnnouncements extends StatefulWidget {
  final Function? onAddAnnouncementPressed;

  const AdminAnnouncements({
    Key? key,
    this.onAddAnnouncementPressed,
  }) : super(key: key);

  @override
  State<AdminAnnouncements> createState() => _AdminAnnouncements();
}

class _AdminAnnouncements extends State<AdminAnnouncements> {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State for loading and admin barangay
  bool _isLoading = true;
  String _adminBarangay = '';

  // Color scheme to match the admin dashboard
  final Color primaryColor = const Color(0xFF1E1E1E);
  final Color accentColor = const Color(0xFF4CAF50);
  final Color backgroundColor = Colors.grey.shade100;
  final Color cardColor = Colors.white;
  final Color textColor = Colors.grey.shade800;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  // Date filter options
  final List<String> _dateFilterOptions = [
    'This Week',
    'This Month',
    'All Time'
  ];
  String _selectedDateFilter = 'This Week';

  // Category data matching resident view
  List<Map<String, dynamic>> _categoryData = [
    {
      'name': 'All',
      'icon': FontAwesomeIcons.thList,
      'color': const Color(0xFF4CAF50),
    },
    {
      'name': 'Urgent',
      'icon': FontAwesomeIcons.exclamationCircle,
      'color': Colors.red,
    },
    {
      'name': 'General',
      'icon': FontAwesomeIcons.bullhorn,
      'color': Colors.blue,
    },
    {
      'name': 'Purok 1',
      'icon': FontAwesomeIcons.users,
      'color': Colors.amber,
    },
    {
      'name': 'Purok 2',
      'icon': FontAwesomeIcons.users,
      'color': Colors.green,
    },
    {
      'name': 'Purok 3',
      'icon': FontAwesomeIcons.users,
      'color': Colors.purple,
    },
    {
      'name': 'Purok 4',
      'icon': FontAwesomeIcons.users,
      'color': Colors.teal,
    },
    {
      'name': 'Purok 5',
      'icon': FontAwesomeIcons.users,
      'color': Colors.deepOrange,
    },
  ];

  // Maps for icons and colors based on category
  final Map<String, IconData> _categoryIcons = {
    'General': FontAwesomeIcons.bullhorn,
    'Waste Management': FontAwesomeIcons.recycle,
    'Event': FontAwesomeIcons.calendarAlt,
    'Warning': FontAwesomeIcons.exclamationTriangle,
    'Notice': FontAwesomeIcons.infoCircle,
    'Other': FontAwesomeIcons.thList,
  };

  final Map<String, Color> _categoryColors = {
    'General': Colors.blue,
    'Waste Management': Colors.green,
    'Event': Colors.purple,
    'Warning': Colors.orange,
    'Notice': Colors.teal,
    'Other': Colors.grey,
  };

  // Store announcements from Firestore
  List<Map<String, dynamic>> _announcements = [];

  @override
  void initState() {
    super.initState();
    _fetchAdminBarangay();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fetch the admin's barangay first
  Future<void> _fetchAdminBarangay() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        print('Current user found: ${currentUser.uid}');
        DocumentSnapshot adminDoc = await _firestore
            .collection('barangay_admins')
            .doc(currentUser.uid)
            .get();

        if (adminDoc.exists) {
          Map<String, dynamic> adminData =
              adminDoc.data() as Map<String, dynamic>;
          _adminBarangay = adminData['barangay'] ?? '';
          print('Admin barangay fetched: $_adminBarangay');

          // Now fetch announcements for this barangay
          await _fetchAnnouncements();
        } else {
          print('Admin doc does not exist for uid: ${currentUser.uid}');
        }
      } else {
        print('No current user found');
      }
    } catch (e) {
      print('Error fetching admin barangay: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fetch announcements from Firestore
  Future<void> _fetchAnnouncements() async {
    try {
      print('Fetching announcements for barangay: $_adminBarangay');
      // Use this simplified query that doesn't need a composite index
      QuerySnapshot querySnapshot =
          await _firestore.collection('announcements').get();

      print('Total announcements found: ${querySnapshot.docs.length}');

      List<Map<String, dynamic>> fetchedAnnouncements = [];
      Set<String> availablePuroks = {'General', 'Urgent'}; // Default categories

      // Add Purok 1-5 to ensure they're always in the filter
      for (int i = 1; i <= 5; i++) {
        availablePuroks.add('Purok $i');
      }

      // Filter and sort in code instead of in the query
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        print('Processing announcement: ${data['title']} for barangay: ${data['barangay']}');

        // Only include documents for this barangay
        if (data['barangay'] == _adminBarangay) {
          print('Announcement matches admin barangay');
          // Process the document as before...
          DateTime date;
          if (data['date'] is Timestamp) {
            date = (data['date'] as Timestamp).toDate();
          } else {
            date = DateTime.now(); // Fallback
          }

          IconData categoryIcon =
              _categoryIcons[data['category']] ?? FontAwesomeIcons.bullhorn;
          Color categoryColor =
              _categoryColors[data['category']] ?? Colors.blue;

          if (data.containsKey('categoryIcon')) {
            categoryIcon = IconData(
              data['categoryIcon'],
              fontFamily: 'FontAwesomeIcons',
              fontPackage: 'font_awesome_flutter',
            );
          }

          if (data.containsKey('categoryColor')) {
            categoryColor = Color(data['categoryColor']);
          }

          // Add purok to available puroks set
          final purok = data['purok'] ?? 'General';
          if (purok.toString().startsWith('Purok')) {
            availablePuroks.add(purok);
          }

          fetchedAnnouncements.add({
            'id': doc.id,
            'title': data['title'] ?? 'No Title',
            'content': data['content'] ?? 'No Content',
            'date': date,
            'author': data['author'] ?? 'Admin',
            'priority': data['priority'] ?? 'Medium',
            'imageUrl': data['imageUrl'],
            'category': data['category'] ?? 'General',
            'categoryIcon': categoryIcon,
            'categoryColor': categoryColor,
            'urgent': data['urgent'] ?? false,
            'purok': purok,
          });
        }
      }

      // Sort the announcements manually by date (newest first)
      fetchedAnnouncements.sort(
          (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      // Dynamically build category data based on available puroks
      List<Map<String, dynamic>> categoryData = [
        {
          'name': 'All',
          'icon': FontAwesomeIcons.thList,
          'color': const Color(0xFF4CAF50),
        },
        {
          'name': 'Urgent',
          'icon': FontAwesomeIcons.exclamationCircle,
          'color': Colors.red,
        },
        {
          'name': 'General',
          'icon': FontAwesomeIcons.bullhorn,
          'color': Colors.blue,
        },
      ];

      // Get sorted purok list (excluding 'General' and 'Urgent' which are already added)
      List<String> sortedPuroks = availablePuroks
          .where((p) => p != 'General' && p != 'Urgent')
          .toList();

      // Sort puroks numerically if possible
      sortedPuroks.sort((a, b) {
        try {
          int aNum = int.parse(a.replaceAll(RegExp(r'[^0-9]'), ''));
          int bNum = int.parse(b.replaceAll(RegExp(r'[^0-9]'), ''));
          return aNum.compareTo(bNum);
        } catch (e) {
          return a.compareTo(b);
        }
      });

      // Add purok categories
      int colorIndex = 0;
      List<Color> purokColors = [
        Colors.amber,
        Colors.green,
        Colors.purple,
        Colors.teal,
        Colors.deepOrange,
        Colors.indigo,
        Colors.pink,
        Colors.cyan,
        Colors.brown
      ];

      for (String purok in sortedPuroks) {
        categoryData.add({
          'name': purok,
          'icon': FontAwesomeIcons.users,
          'color': purokColors[colorIndex % purokColors.length],
        });
        colorIndex++;
      }

      setState(() {
        _announcements = fetchedAnnouncements;
        _categoryData = categoryData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching announcements: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Method to delete an announcement
  Future<void> _deleteAnnouncement(String id) async {
    try {
      await _firestore.collection('announcements').doc(id).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Announcement deleted successfully'),
          backgroundColor: accentColor,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Refresh announcements
      _fetchAnnouncements();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting announcement: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Filter announcements by date based on selected date filter
  bool _isInSelectedDateRange(DateTime date) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    switch (_selectedDateFilter) {
      case 'This Week':
        // Start of the week (Sunday)
        final DateTime startOfWeek =
            today.subtract(Duration(days: today.weekday % 7));
        return date.isAfter(startOfWeek.subtract(const Duration(days: 1)));
      case 'This Month':
        // Start of the month
        final DateTime startOfMonth = DateTime(today.year, today.month, 1);
        return date.isAfter(startOfMonth.subtract(const Duration(days: 1)));
      case 'All Time':
      default:
        return true;
    }
  }

  List<Map<String, dynamic>> get _filteredAnnouncements {
    List<Map<String, dynamic>> filtered = List.from(_announcements);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((announcement) =>
              announcement['title']
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              announcement['content']
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Apply category filter
    if (_selectedCategory != 'All') {
      if (_selectedCategory == 'Urgent') {
        filtered = filtered
            .where((announcement) => announcement['urgent'] == true)
            .toList();
      } else if (_selectedCategory == 'General') {
        filtered = filtered
            .where((announcement) => announcement['purok'] == 'General')
            .toList();
      } else if (_selectedCategory.startsWith('Purok')) {
        // Filter by Purok
        filtered = filtered
            .where((announcement) => announcement['purok'] == _selectedCategory)
            .toList();
      } else {
        // Filter by category
        filtered = filtered
            .where(
                (announcement) => announcement['category'] == _selectedCategory)
            .toList();
      }
    }

    // Apply date filter
    if (_selectedDateFilter != 'All Time') {
      filtered = filtered
          .where((announcement) =>
              _isInSelectedDateRange(announcement['date'] as DateTime))
          .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title, search bar, and add button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Announcements',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage and publish announcements for your barangay',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Date filter dropdown
                    Container(
                      height: 45,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDateFilter,
                          icon: const Icon(Icons.arrow_drop_down),
                          iconSize: 24,
                          elevation: 16,
                          style: TextStyle(color: textColor, fontSize: 14),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedDateFilter = newValue;
                              });
                            }
                          },
                          items: _dateFilterOptions
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(value),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Improved search bar with better alignment and styling
                    Container(
                      width: 250,
                      height: 45, // Match the height of the button
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            hintStyle: TextStyle(fontSize: 14),
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                            isCollapsed: true,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Add button with reload functionality
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.refresh),
                          onPressed: _fetchAnnouncements,
                          tooltip: 'Refresh announcements',
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 4),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (widget.onAddAnnouncementPressed != null) {
                              widget.onAddAnnouncementPressed!();
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Announcement'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
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
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Category filter chips
            Container(
              height: 70,
              padding: const EdgeInsets.all(8),
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
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categoryData.length,
                itemBuilder: (context, index) {
                  final category = _categoryData[index];
                  final isSelected = _selectedCategory == category['name'];

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category['name'] as String;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? category['color'] as Color
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: (category['color'] as Color)
                                      .withOpacity(0.4),
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
                            category['icon'] as IconData,
                            size: 16,
                            color: isSelected
                                ? Colors.white
                                : category['color'] as Color,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            category['name'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color:
                                  isSelected ? Colors.white : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Announcements statistics
            Row(
              children: [
                _buildStatCard(
                  title: 'Total Announcements',
                  value: _announcements.length.toString(),
                  icon: Icons.campaign,
                  color: Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  title: 'High Priority',
                  value: _announcements
                      .where((a) => a['priority'] == 'High')
                      .length
                      .toString(),
                  icon: Icons.priority_high,
                  color: Colors.red,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  title: 'This Week',
                  value: _announcements
                      .where((a) => a['date'].isAfter(
                          DateTime.now().subtract(const Duration(days: 7))))
                      .length
                      .toString(),
                  icon: Icons.date_range,
                  color: Colors.orange,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Announcements list with loading state
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _filteredAnnouncements.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: _filteredAnnouncements.length,
                          itemBuilder: (context, index) {
                            final announcement = _filteredAnnouncements[index];
                            final Color categoryColor =
                                announcement['categoryColor'] as Color;
                            final bool isUrgent =
                                announcement['urgent'] == true;
                            final IconData categoryIcon =
                                announcement['categoryIcon'] as IconData;

                            return Container(
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
                                border: Border.all(
                                  color: isUrgent
                                      ? Colors.red.withOpacity(0.3)
                                      : Colors.grey.shade200,
                                  width: isUrgent ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header with urgency banner if needed
                                  if (isUrgent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 16),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.red.shade700,
                                            Colors.redAccent
                                          ],
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(16),
                                          topRight: Radius.circular(16),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.white,
                                              size: 16),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'URGENT ANNOUNCEMENT',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.white.withOpacity(0.3),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              announcement['priority'],
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

                                  // Category and title section
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 16, 16, 8),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Category icon
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color:
                                                categoryColor.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: categoryColor
                                                  .withOpacity(0.3),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Icon(
                                            categoryIcon,
                                            color: categoryColor,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Title and date
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: categoryColor
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      border: Border.all(
                                                          color: categoryColor
                                                              .withOpacity(
                                                                  0.3)),
                                                    ),
                                                    child: Text(
                                                      announcement['purok']
                                                          .toString(),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: categoryColor,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[100],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      border: Border.all(
                                                        color:
                                                            Colors.grey[300]!,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      announcement['category']
                                                          .toString(),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.grey[800],
                                                      ),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[100],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .calendar_today_outlined,
                                                          size: 10,
                                                          color:
                                                              Colors.grey[700],
                                                        ),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          DateFormat(
                                                                  'MMM dd, yyyy')
                                                              .format(
                                                                  announcement[
                                                                      'date']),
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors
                                                                .grey[700],
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                announcement['title']
                                                    .toString(),
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

                                  // Content section
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 8, 16, 16),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey[200]!,
                                          width: 1.0,
                                        ),
                                      ),
                                      constraints:
                                          const BoxConstraints(maxHeight: 100),
                                      child: Text(
                                        announcement['content'].toString(),
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.5,
                                          color: Colors.grey.shade700,
                                        ),
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),

                                  // Author and actions section
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: accentColor.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color:
                                                  accentColor.withOpacity(0.3),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: CircleAvatar(
                                            backgroundColor:
                                                accentColor.withOpacity(0.1),
                                            radius: 16,
                                            child: Text(
                                              announcement['author']
                                                  .toString()[0]
                                                  .toUpperCase(),
                                              style: TextStyle(
                                                color: accentColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                announcement['author']
                                                    .toString(),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                "Admin",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.visibility,
                                                  color: Colors.blue),
                                              onPressed: () {
                                                // View details functionality
                                              },
                                              tooltip: 'View Details',
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.edit,
                                                  color: accentColor),
                                              onPressed: () {
                                                // Edit functionality
                                              },
                                              tooltip: 'Edit',
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.delete,
                                                  color: Colors.red),
                                              onPressed: () {
                                                // Show delete confirmation dialog
                                                showDialog(
                                                  context: context,
                                                  builder:
                                                      (BuildContext context) {
                                                    return AlertDialog(
                                                      title: const Text(
                                                          'Confirm Delete'),
                                                      content: const Text(
                                                          'Are you sure you want to delete this announcement?'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                      context)
                                                                  .pop(),
                                                          child: const Text(
                                                              'Cancel'),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed: () {
                                                            Navigator.of(
                                                                    context)
                                                                .pop();
                                                            _deleteAnnouncement(
                                                                announcement[
                                                                    'id']);
                                                          },
                                                          style: ElevatedButton
                                                              .styleFrom(
                                                            backgroundColor:
                                                                Colors.red,
                                                            foregroundColor:
                                                                Colors.white,
                                                          ),
                                                          child: const Text(
                                                              'Delete'),
                                                        ),
                                                      ],
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16),
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                              tooltip: 'Delete',
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: accentColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading announcements...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
              Icons.inbox_outlined,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No announcements found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _selectedCategory != 'All'
                  ? 'There are no announcements in this category'
                  : _searchQuery.isNotEmpty
                      ? 'Try a different search term'
                      : 'Try adding a new announcement',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _selectedCategory = 'All';
                _searchController.clear();
                _searchQuery = '';
              });
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reset Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red.shade600;
      case 'Medium':
        return Colors.orange.shade600;
      case 'Low':
        return Colors.blue.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
}
