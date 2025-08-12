import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_ecobarangay/screens/collector/features/collector_add_report.dart';
import 'package:capstone_ecobarangay/screens/collector/features/collector_report_detail_dialog.dart';

class CollectorReportScreen extends StatefulWidget {
  const CollectorReportScreen({Key? key}) : super(key: key);

  @override
  _CollectorReportScreenState createState() => _CollectorReportScreenState();
}

class _CollectorReportScreenState extends State<CollectorReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedTimeFilter =
      'This Week'; // Changed to 'This Week' as default to match announcement screen

  // Firebase reference
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<QuerySnapshot> _reportsStream;

  // Category data
  final List<Map<String, dynamic>> _categoryData = [
    {
      'name': 'All',
      'icon': FontAwesomeIcons.thList,
      'color': const Color.fromARGB(255, 3, 144, 123),
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

  // Time filter options - Updated to match the announcement screen
  final List<String> _timeFilters = [
    'All Time',
    'This Week',
    'This Month',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categoryData.length, vsync: this);
    _initReportsStream();
  }

  void _initReportsStream() {
    _reportsStream = _firestore
        .collection('reports')
        .orderBy('date', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<DocumentSnapshot> _filterReports(List<DocumentSnapshot> reports) {
    List<DocumentSnapshot> filtered = List.from(reports);

    // Apply time filter - Updated to match announcement screen logic
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

      filtered = filtered.where((report) {
        final reportDate = (report['date'] as Timestamp).toDate();
        return reportDate.isAfter(cutoffDate) ||
            reportDate.isAtSameMomentAs(cutoffDate);
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((report) =>
              report['title']
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              report['content']
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              report['location']
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Apply category filter
    if (_tabController.index > 0) {
      final categoryFilter =
          _categoryData[_tabController.index]['name'] as String;
      filtered = filtered
          .where((report) => report['category'] == categoryFilter)
          .toList();
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
                  hintText: "Search reports...",
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
                "Collection Reports",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize:
                        20, // Updated font size to match announcement screen
                    color: Colors.white),
              ),
        actions: [
          // Add report button
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CollectorAddReportScreen(),
                ),
              );
            },
          ),
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
              if (value == 'my_reports') {
                // Filter to show only current user's reports
                // This would need auth implementation
              } else if (value == 'refresh') {
                _initReportsStream();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'my_reports',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 18),
                    SizedBox(width: 8),
                    Text('My Reports'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh', // Changed from 'filter' to 'refresh'
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18), // Changed icon
                    SizedBox(width: 8),
                    Text('Refresh'), // Changed text
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 18),
                    SizedBox(width: 8),
                    Text('Report Settings'),
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
          _buildTimeFilterChip(), // Changed to use the new filter component
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // New time filter widget matching the announcement screen style
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

  Widget _buildBody() {
    return StreamBuilder<QuerySnapshot>(
      stream: _reportsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(isDataEmpty: true);
        }

        final reports = snapshot.data!.docs;
        final filteredReports = _filterReports(reports);

        if (filteredReports.isEmpty) {
          return _buildEmptyState(isNoResults: true);
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Refresh the stream
            setState(() {
              _initReportsStream();
            });
            return;
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredReports.length,
            itemBuilder: (context, index) {
              return _buildReportCard(filteredReports[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
      {bool isDataEmpty = false, bool isNoResults = false}) {
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
              isDataEmpty ? Icons.report_off_outlined : Icons.search_off,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isDataEmpty ? 'No reports found' : 'No matching reports',
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
                  ? 'There are no reports in this category'
                  : _selectedTimeFilter != 'All Time'
                      ? 'No reports for $_selectedTimeFilter'
                      : _searchQuery.isNotEmpty
                          ? 'Try a different search term'
                          : 'Be the first to report an issue in your community',
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
                _selectedTimeFilter = 'All Time';
              });
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reset Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 3, 144, 123),
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

  Widget _buildReportCard(DocumentSnapshot document) {
    final data = document.data() as Map<String, dynamic>;

    final formatter = DateFormat('MMM dd, yyyy • h:mm a');
    final formattedDate =
        formatter.format((data['date'] as Timestamp).toDate());

    // Map category to color and icon
    Color categoryColor = Colors.grey;
    IconData categoryIcon = Icons.report;

    // Find matching category from our category data
    for (var category in _categoryData) {
      if (category['name'] == data['category']) {
        categoryColor = category['color'] as Color;
        categoryIcon = category['icon'] as IconData;
        break;
      }
    }

    // Get status if available
    final String status = data['status'] as String? ?? 'New';
    final Color statusColor = _getStatusColor(status);

    return GestureDetector(
      onTap: () {
        // Show the report detail dialog when a card is tapped
        showCollectorReportDetailDialog(context, data);
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
                    data['category'].toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  // Status chip if available
                  if (data['status'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
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
                            if (data['location'] != null &&
                                data['location'].toString().isNotEmpty)
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
                                      data['location'].toString().length > 20
                                          ? '${data['location'].toString().substring(0, 20)}...'
                                          : data['location'].toString(),
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
                          data['title'].toString(),
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
                data['content'].toString(),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.grey[700],
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
                          data['author'].toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          data['authorRole'].toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // User type badge if available
                  if (data['userType'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: data['userType'] == 'collector'
                            ? const Color.fromARGB(255, 3, 144, 123)
                                .withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: data['userType'] == 'collector'
                              ? const Color.fromARGB(255, 3, 144, 123)
                                  .withOpacity(0.3)
                              : Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        data['userType'] == 'collector'
                            ? 'Collector'
                            : 'Resident',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: data['userType'] == 'collector'
                              ? const Color.fromARGB(255, 3, 144, 123)
                              : Colors.orange,
                        ),
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
}
