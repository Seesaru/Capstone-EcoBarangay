import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/collector_schedule_detail_dialog.dart';

class CollectorScheduleScreen extends StatefulWidget {
  const CollectorScheduleScreen({Key? key}) : super(key: key);

  @override
  _CollectorScheduleScreenState createState() =>
      _CollectorScheduleScreenState();
}

class _CollectorScheduleScreenState extends State<CollectorScheduleScreen>
    with SingleTickerProviderStateMixin {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late TabController _tabController;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State for loading and collector's barangay
  bool _isLoading = true;
  String _collectorBarangay = '';

  // Map to store events from Firebase
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  // Updated category data with waste type categories
  final List<Map<String, dynamic>> _categoryData = [
    {
      'name': 'All',
      'icon': FontAwesomeIcons.thList,
      'color': const Color.fromARGB(255, 3, 144, 123),
    },
    {
      'name': 'General',
      'icon': FontAwesomeIcons.dumpster,
      'color': Colors.blue.shade600,
    },
    {
      'name': 'Biodegradable',
      'icon': FontAwesomeIcons.leaf,
      'color': Colors.green.shade600,
    },
    {
      'name': 'Non-biodegradable',
      'icon': FontAwesomeIcons.trash,
      'color': Colors.orange.shade600,
    },
    {
      'name': 'Recyclable',
      'icon': FontAwesomeIcons.recycle,
      'color': Colors.teal.shade600,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categoryData.length, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    // Fetch collector's barangay and schedules from Firebase
    _fetchCollectorBarangay();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Fetch collector's barangay from Firebase
  Future<void> _fetchCollectorBarangay() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Get user data from collector collection
        DocumentSnapshot collectorDoc =
            await _firestore.collection('collector').doc(currentUser.uid).get();

        if (collectorDoc.exists) {
          Map<String, dynamic> userData =
              collectorDoc.data() as Map<String, dynamic>;

          setState(() {
            _collectorBarangay = userData['barangay'] ?? '';
          });

          // After getting the barangay, fetch schedules
          await _fetchSchedules();
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fetch schedules from Firebase based on collector's barangay
  Future<void> _fetchSchedules() async {
    if (_collectorBarangay.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      List<QueryDocumentSnapshot> matchingDocs = [];
      QuerySnapshot allSchedules = await _firestore
          .collection('schedule')
          .orderBy('date', descending: false)
          .get();

      // Manual filtering to ignore case differences and trim spaces
      String normalizedCollectorBarangay =
          _collectorBarangay.trim().toLowerCase();
      for (var doc in allSchedules.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String scheduleBarangay =
            (data['barangay'] ?? '').toString().trim().toLowerCase();

        if (scheduleBarangay == normalizedCollectorBarangay) {
          matchingDocs.add(doc);
        }
      }

      // Initialize new events map
      Map<DateTime, List<Map<String, dynamic>>> newEvents = {};

      // Process each schedule document
      for (var doc in matchingDocs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Get date from timestamp and normalize to remove time component
        DateTime date = (data['date'] as Timestamp).toDate();
        DateTime normalizedDate = DateTime(date.year, date.month, date.day);

        // Extract start and end time maps
        Map<String, dynamic> startTimeMap =
            data['startTime'] ?? {'hour': 0, 'minute': 0};
        Map<String, dynamic> endTimeMap =
            data['endTime'] ?? {'hour': 0, 'minute': 0};

        // Format time string
        String timeString =
            '${_formatTime(startTimeMap)} - ${_formatTime(endTimeMap)}';

        // Get waste type and determine icon and color
        String wasteType = data['wasteType'] ?? 'General';
        IconData icon;
        Color color;

        switch (wasteType) {
          case 'Biodegradable':
            icon = FontAwesomeIcons.leaf;
            color = Colors.green.shade600;
            break;
          case 'Non-biodegradable':
            icon = FontAwesomeIcons.trash;
            color = Colors.orange.shade600;
            break;
          case 'Recyclable':
            icon = FontAwesomeIcons.recycle;
            color = Colors.teal.shade600;
            break;
          case 'General':
          default:
            icon = FontAwesomeIcons.dumpster;
            color = Colors.blue.shade600;
            break;
        }

        // Create event object
        Map<String, dynamic> event = {
          'id': doc.id,
          'title': data['title'] ?? 'Untitled Schedule',
          'description': data['description'] ?? '',
          'time': timeString,
          'date': normalizedDate,
          'location': data['location'] ?? 'Barangay $_collectorBarangay',
          'category': 'Waste Collection',
          'wasteType': wasteType,
          'icon': icon,
          'color': color,
          'status': data['status'] ?? 'Scheduled',
          'startTimeMap': startTimeMap,
          'endTimeMap': endTimeMap,
        };

        // Add event to date in events map
        if (newEvents[normalizedDate] == null) {
          newEvents[normalizedDate] = [];
        }
        newEvents[normalizedDate]!.add(event);
      }

      setState(() {
        _events = newEvents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
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

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    // Format date to compare only year, month, and day
    final formattedDay = DateTime(day.year, day.month, day.day);

    // Get events for the selected day
    List<Map<String, dynamic>> dayEvents = _events[formattedDay] ?? [];

    // Apply search filter if provided
    if (_searchQuery.isNotEmpty) {
      dayEvents = dayEvents
          .where((event) =>
              event['title']
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              event['description']
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              event['location']
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Apply category filter if selected
    if (_tabController.index > 0) {
      final categoryFilter =
          _categoryData[_tabController.index]['name'] as String;
      dayEvents = dayEvents
          .where((event) => event['wasteType'] == categoryFilter)
          .toList();
    }

    return dayEvents;
  }

  // Method to check if a day has events
  bool _hasSchedules(DateTime day) {
    final formattedDay = DateTime(day.year, day.month, day.day);
    final schedules = _events[formattedDay] ?? [];

    if (_tabController.index > 0) {
      final categoryFilter =
          _categoryData[_tabController.index]['name'] as String;
      return schedules.any((event) => event['wasteType'] == categoryFilter);
    }

    return schedules.isNotEmpty;
  }

  // Method to update schedule status
  Future<void> _updateScheduleStatus(
      String scheduleId, String newStatus) async {
    try {
      await _firestore.collection('schedule').doc(scheduleId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _auth.currentUser?.uid
      });

      // Refresh schedules after update
      await _fetchSchedules();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Schedule marked as $newStatus'),
          backgroundColor: newStatus == 'Completed'
              ? Colors.green
              : newStatus == 'Cancelled'
                  ? Colors.red
                  : Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update schedule: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
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
        title: _isSearching
            ? Container(
                margin: const EdgeInsets.only(right: 80),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search schedules...",
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
                ),
              )
            : const Text(
                "Collection Schedule",
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
          _buildPopupMenu(),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : Column(
              children: [
                _buildCategorySelector(),
                _buildCalendar(),
                Expanded(
                  child: _buildSchedulesList(),
                ),
              ],
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
            'Loading schedules...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
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

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
      child: TableCalendar(
        firstDay: DateTime.utc(2023, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDay, day);
        },
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        calendarStyle: CalendarStyle(
          markerDecoration: BoxDecoration(
            color: const Color.fromARGB(255, 3, 144, 123),
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: const Color.fromARGB(255, 3, 144, 123).withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: const Color.fromARGB(255, 3, 144, 123),
            shape: BoxShape.circle,
          ),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonDecoration: BoxDecoration(
            color: const Color.fromARGB(255, 3, 144, 123).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          formatButtonTextStyle: TextStyle(
            color: const Color.fromARGB(255, 3, 144, 123),
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left,
            color: const Color.fromARGB(255, 3, 144, 123),
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            color: const Color.fromARGB(255, 3, 144, 123),
          ),
        ),
        eventLoader: (day) {
          // Format date to compare only year, month, and day
          final formattedDay = DateTime(day.year, day.month, day.day);

          // Get all schedules for this day
          final schedules = _events[formattedDay] ?? [];

          // Filter schedules by category if needed
          if (_tabController.index > 0) {
            final categoryFilter =
                _categoryData[_tabController.index]['name'] as String;
            return schedules
                .where((schedule) => schedule['wasteType'] == categoryFilter)
                .toList();
          }

          return schedules;
        },
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return null;

            // Get the active color based on tab controller
            Color markerColor = const Color.fromARGB(255, 3, 144, 123);
            if (_tabController.index > 0) {
              markerColor =
                  _categoryData[_tabController.index]['color'] as Color;
            }

            return Positioned(
              bottom: 1,
              right: 1,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: markerColor,
                ),
                width: 8,
                height: 8,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSchedulesList() {
    final schedules = _getEventsForDay(_selectedDay);

    // If no schedules for the selected day, show empty state instead of all schedules
    if (schedules.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        final schedule = schedules[index];
        return _buildScheduleCard(schedule);
      },
    );
  }

  Widget _buildEmptyState() {
    // Check if selected day is today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay =
        DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final bool isToday = selectedDay.isAtSameMomentAs(today);

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
              Icons.delete_outline,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No waste collection scheduled',
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
              _collectorBarangay.isEmpty
                  ? 'Unable to determine your barangay. Please update your profile.'
                  : _tabController.index > 0
                      ? 'No ${_categoryData[_tabController.index]['name']} waste collection scheduled'
                      : _searchQuery.isNotEmpty
                          ? 'Try a different search term'
                          : isToday
                              ? 'No collection scheduled for today'
                              : 'No collection scheduled for this day',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ),
          if (_tabController.index > 0 || _searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: ElevatedButton.icon(
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
                  backgroundColor: const Color.fromARGB(255, 3, 144, 123),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (_collectorBarangay.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  _fetchCollectorBarangay();
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 3, 144, 123),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    // Determine status indicator
    bool isCompleted = schedule['status'] == 'Completed';
    bool isCancelled = schedule['status'] == 'Cancelled';

    // Get the color and icon from the schedule
    Color scheduleColor = schedule['color'] as Color;
    IconData wasteIcon = schedule['icon'] as IconData;
    String wasteType = schedule['wasteType'] as String;

    return GestureDetector(
      onTap: () async {
        // Show schedule detail dialog
        bool? updated =
            await showCollectorScheduleDetailDialog(context, schedule);

        // If dialog returns true (meaning the schedule status was updated), refresh schedules
        if (updated == true) {
          _fetchSchedules();
        }
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
            // Status header - use gradient for completed/cancelled
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isCompleted
                      ? [Colors.green.shade700, Colors.green.shade500]
                      : isCancelled
                          ? [Colors.red.shade700, Colors.red.shade500]
                          : [
                              scheduleColor.withOpacity(0.8),
                              scheduleColor.withOpacity(0.6)
                            ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCompleted
                        ? Icons.check_circle
                        : isCancelled
                            ? Icons.cancel
                            : Icons.schedule,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    schedule['status'].toString().toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      wasteType,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Collection title and location
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Waste type icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheduleColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      wasteIcon,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Title and location
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schedule['title'] as String,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            decoration: isCompleted || isCancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: scheduleColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                schedule['location'] as String,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Date and time details
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Heading for date and time
                  Text(
                    "SCHEDULE DETAILS",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Date container with improved readability
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: scheduleColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: scheduleColor,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: scheduleColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Collection Date",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('EEEE, MMMM d, yyyy')
                                  .format(schedule['date'] as DateTime),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Time container with improved readability
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: scheduleColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: scheduleColor,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: scheduleColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.access_time,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Collection Time",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              schedule['time'] as String,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.shade200,
            ),

            // Action buttons for collector
            // Only show action buttons if the schedule is not completed or cancelled
            if (!isCompleted && !isCancelled)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: _buildCollectorActionButton(
                    FontAwesomeIcons.check,
                    'Mark Complete',
                    Colors.green.shade600,
                    () => _updateScheduleStatus(schedule['id'], 'Completed'),
                  ),
                ),
              ),

            // For completed or cancelled schedules, show a different action bar
            if (isCompleted || isCancelled)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: _buildCollectorActionButton(
                    FontAwesomeIcons.arrowRotateLeft,
                    'Reactivate',
                    Colors.blue.shade600,
                    () => _updateScheduleStatus(schedule['id'], 'Scheduled'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectorActionButton(
      IconData icon, String label, Color color, VoidCallback onPressed) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 14,
        color: color,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: color.withOpacity(0.1),
      ),
    );
  }

  // Popup menu for additional options
  PopupMenuButton<String> _buildPopupMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert,
        color: Colors.white,
      ),
      onSelected: (value) {
        if (value == 'refresh') {
          _fetchCollectorBarangay();
        } else if (value == 'add_schedule') {
          // Navigate to add schedule screen
          // This would be implemented based on your navigation setup
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'add_schedule',
          child: Row(
            children: [
              Icon(Icons.add_circle, size: 18),
              SizedBox(width: 8),
              Text('Add Schedule'),
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
              Text('Settings'),
            ],
          ),
        ),
      ],
    );
  }
}
