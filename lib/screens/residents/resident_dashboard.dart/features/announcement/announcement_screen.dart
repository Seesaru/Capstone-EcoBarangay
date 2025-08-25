import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'announcement_detail_dialog.dart';

class AnnouncementsScreen extends StatefulWidget {
  final bool isCollector;
  final String collectorBarangay;

  const AnnouncementsScreen({
    Key? key,
    this.isCollector = false,
    this.collectorBarangay = '',
  }) : super(key: key);

  @override
  _AnnouncementsScreenState createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State for loading and resident's barangay
  bool _isLoading = true;
  String _residentBarangay = '';

  // Store announcements from Firestore
  List<Map<String, dynamic>> _announcements = [];

  // Time filter options
  final List<String> _timeFilters = ['All Time', 'This Week', 'This Month'];
  String _selectedTimeFilter = 'This Week'; // Default filter is 'This Week'

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

  // Updated category data with General and Community (Purok) categories
  List<Map<String, dynamic>> _categoryData = [
    {
      'name': 'All',
      'icon': FontAwesomeIcons.thList,
      'color': const Color.fromARGB(255, 3, 144, 123),
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

  // Add a list to store available puroks dynamically
  List<String> _availablePuroks = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categoryData.length, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _fetchResidentBarangay();
  }

  // Update tab controller when category data changes
  void _updateTabController() {
    if (_tabController.length != _categoryData.length) {
      // Dispose the old controller
      _tabController.dispose();

      // Create a new controller with the updated length
      _tabController = TabController(length: _categoryData.length, vsync: this);
      _tabController.addListener(() {
        setState(() {});
      });

      // Reset to first tab if the current index is out of bounds
      if (_tabController.index >= _categoryData.length) {
        _tabController.index = 0;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Dynamically load all unique puroks from resident collection
  Future<void> _loadAvailablePuroks() async {
    try {
      print('Loading available puroks for barangay: $_residentBarangay');
      final QuerySnapshot snapshot = await _firestore
          .collection('resident')
          .where('barangay', isEqualTo: _residentBarangay)
          .get();

      // Extract all puroks and remove duplicates
      final Set<String> puroks = {};
      for (var doc in snapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        final purok = userData['purok']?.toString();
        if (purok != null && purok.isNotEmpty) {
          puroks.add(purok);
        }
      }

      // Sort puroks numerically if possible
      final sortedPuroks = puroks.toList()
        ..sort((a, b) {
          // Try to parse as numbers for natural sorting
          try {
            // Extract numbers from the purok strings
            int aNum = int.parse(a.replaceAll(RegExp(r'[^0-9]'), ''));
            int bNum = int.parse(b.replaceAll(RegExp(r'[^0-9]'), ''));
            return aNum.compareTo(bNum);
          } catch (e) {
            // Fall back to string comparison if not parseable
            return a.compareTo(b);
          }
        });

      // Build category data with dynamic puroks
      List<Map<String, dynamic>> categoryData = [
        {
          'name': 'All',
          'icon': FontAwesomeIcons.thList,
          'color': const Color.fromARGB(255, 3, 144, 123),
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

      // Add purok categories from the dynamically loaded puroks
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
          'name': _formatPurokDisplay(purok),
          'icon': FontAwesomeIcons.users,
          'color': purokColors[colorIndex % purokColors.length],
        });
        colorIndex++;
      }

      setState(() {
        _availablePuroks = sortedPuroks;
        _categoryData = categoryData;
      });

      // Update tab controller if needed
      _updateTabController();

      print('Available puroks loaded: $_availablePuroks');
    } catch (e) {
      print('Error loading puroks: $e');
    }
  }

  // Helper function to format purok display
  String _formatPurokDisplay(String purok) {
    // If purok already starts with "Purok", return as is
    if (purok.toLowerCase().startsWith('purok')) {
      return purok;
    }
    // Otherwise, add "Purok" prefix
    return 'Purok $purok';
  }

  // Fetch the resident's barangay first
  Future<void> _fetchResidentBarangay() async {
    try {
      // If this is a collector, use the provided barangay
      if (widget.isCollector && widget.collectorBarangay.isNotEmpty) {
        setState(() {
          _residentBarangay = widget.collectorBarangay;
        });

        // Now fetch announcements and load available puroks for this barangay
        await Future.wait([
          _fetchAnnouncements(),
          _loadAvailablePuroks(),
        ]);
        return;
      }

      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Use the correct collection name: 'resident' (singular) instead of 'residents' (plural)
        DocumentSnapshot residentDoc =
            await _firestore.collection('resident').doc(currentUser.uid).get();

        if (residentDoc.exists) {
          Map<String, dynamic> residentData =
              residentDoc.data() as Map<String, dynamic>;
          _residentBarangay = residentData['barangay'] ?? '';

          // Now fetch announcements and load available puroks for this barangay
          await Future.wait([
            _fetchAnnouncements(),
            _loadAvailablePuroks(),
          ]);
        } else {
          // Handle case where resident document doesn't exist
          setState(() {
            _isLoading = false;
          });

          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'User profile not found. Please complete your profile first.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Handle case where user is not authenticated
        setState(() {
          _isLoading = false;
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You need to be logged in to view announcements.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error fetching resident barangay: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });

      // Show error message with the actual error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fetch announcements from Firestore
  Future<void> _fetchAnnouncements() async {
    try {
      // Get announcements for this resident's barangay
      QuerySnapshot querySnapshot =
          await _firestore.collection('announcements').get();

      List<Map<String, dynamic>> fetchedAnnouncements = [];

      // Filter and process in code
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

          // Get category icon and color
          IconData categoryIcon =
              _categoryIcons[data['category']] ?? FontAwesomeIcons.bullhorn;
          Color categoryColor =
              _categoryColors[data['category']] ?? Colors.blue;

          fetchedAnnouncements.add({
            'id': doc.id,
            'title': data['title'] ?? 'No Title',
            'content': data['content'] ?? 'No Content',
            'date': date,
            'author': data['author'] ?? 'Admin',
            'authorRole': data['authorRole'] ?? 'Barangay Official',
            'authorAvatar': data['authorAvatar'],
            'category': data['category'] ?? 'General',
            'categoryIcon': categoryIcon,
            'categoryColor': categoryColor,
            'urgent': data['urgent'] ?? false,
            'purok': data['purok'] ?? 'General',
            'imageUrl': data['imageUrl'],
          });
        }
      }

      // Sort announcements by date (newest first)
      fetchedAnnouncements.sort(
          (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      setState(() {
        _announcements = fetchedAnnouncements;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching announcements: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });
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

    // Apply time filter
    if (_selectedTimeFilter != 'All Time') {
      DateTime now = DateTime.now();
      DateTime cutoffDate;

      switch (_selectedTimeFilter) {
        case 'This Week':
          // Go back to the most recent Sunday (or 7 days if you prefer)
          cutoffDate = now.subtract(Duration(days: now.weekday % 7));
          cutoffDate =
              DateTime(cutoffDate.year, cutoffDate.month, cutoffDate.day);
          break;
        case 'This Month':
          cutoffDate = DateTime(now.year, now.month, 1);
          break;
        default:
          cutoffDate = DateTime(1900); // Very old date to include everything
      }

      filtered = filtered
          .where((announcement) =>
              (announcement['date'] as DateTime).isAfter(cutoffDate) ||
              (announcement['date'] as DateTime).isAtSameMomentAs(cutoffDate))
          .toList();
    }

    // Apply category filter
    if (_tabController.index > 0) {
      final categoryFilter =
          _categoryData[_tabController.index]['name'] as String;
      if (categoryFilter == 'Urgent') {
        filtered = filtered
            .where((announcement) => announcement['urgent'] == true)
            .toList();
      } else if (categoryFilter == 'General') {
        filtered = filtered
            .where((announcement) => announcement['purok'] == 'General')
            .toList();
      } else {
        // Filter by Purok (match both 'Purok X' and 'X')
        String purokNumber = categoryFilter.replaceAll('Purok ', '').trim();
        filtered = filtered.where((announcement) {
          String announcementPurok = announcement['purok'].toString().trim();
          return announcementPurok == purokNumber ||
              announcementPurok == categoryFilter;
        }).toList();
      }
    }

    return filtered;
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
        title: _isSearching
            ? TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search announcements...",
                  hintStyle: const TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : const Text(
                "Announcements",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.white),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: Colors.white,
            ),
            onSelected: (value) {
              if (value == 'refresh') {
                _fetchAnnouncements();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all, size: 18),
                    SizedBox(width: 8),
                    Text('Mark All as Read'),
                  ],
                ),
              ),
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
                    Text('Notification Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategorySelector(),
          _buildTimeFilterChip(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      height: 70,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
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
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicator: const BoxDecoration(),
              indicatorSize: TabBarIndicatorSize.label,
              indicatorPadding: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.only(left: 8, right: 6),
              tabAlignment: TabAlignment.start,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[600],
              dividerColor: Colors.transparent,
              onTap: (index) {
                setState(() {});
              },
              tabs: List.generate(
                _categoryData.length,
                (index) => _buildCategoryTab(
                  _categoryData[index]['name'] as String,
                  _categoryData[index]['icon'] as IconData,
                  _categoryData[index]['color'] as Color,
                  _tabController.index == index,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(
      String name, IconData icon, Color color, bool isSelected) {
    return Tab(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[100],
          borderRadius: BorderRadius.circular(30),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFilterChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const SizedBox(width: 4),
            const Text(
              'Time Filter: ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            for (String filter in _timeFilters)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                    filter,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _selectedTimeFilter == filter
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: _selectedTimeFilter == filter
                          ? Colors.white
                          : Colors.grey[700],
                    ),
                  ),
                  selected: _selectedTimeFilter == filter,
                  showCheckmark: false,
                  selectedColor: const Color.fromARGB(255, 3, 144, 123),
                  backgroundColor: Colors.grey[200],
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  visualDensity: VisualDensity.compact,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedTimeFilter = filter;
                      });
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    final filtered = _filteredAnnouncements;

    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchAnnouncements();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          return _buildAdvancedAnnouncementCard(filtered[index]);
        },
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
              _tabController.index > 0
                  ? 'There are no announcements in this category'
                  : _searchQuery.isNotEmpty
                      ? 'Try a different search term'
                      : 'Check back later for updates from your barangay',
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
                _tabController.animateTo(0);
                _searchController.clear();
                _searchQuery = '';
              });
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reset Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color.fromARGB(255, 3, 144, 123),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedAnnouncementCard(Map<String, dynamic> announcement) {
    final formatter = DateFormat('MMM dd, yyyy • h:mm a');
    final formattedDate = formatter.format(announcement['date']);
    final isUrgent = announcement['urgent'] == true;
    final Color categoryColor = announcement['categoryColor'] as Color;
    final IconData categoryIcon = announcement['categoryIcon'] as IconData;

    return GestureDetector(
      onTap: () {
        // Show the announcement detail dialog when card is tapped
        showAnnouncementDetailDialog(context, announcement);
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
            // Header with urgency banner if needed
            if (isUrgent)
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade700, Colors.redAccent],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 16),
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
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'IMPORTANT',
                        style: TextStyle(
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: categoryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: categoryColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                _formatPurokDisplay(
                                    announcement['purok'].toString()),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: categoryColor,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          announcement['title'].toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                announcement['content'].toString(),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Author info
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    radius: 16,
                    child: Icon(
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
                          announcement['author'].toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          announcement['authorRole'].toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
