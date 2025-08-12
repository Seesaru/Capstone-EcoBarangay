import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capstone_ecobarangay/screens/admin/functions/add_schedule.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminSchedules extends StatefulWidget {
  final Function? onAddSchedulePressed;

  const AdminSchedules({
    Key? key,
    this.onAddSchedulePressed,
  }) : super(key: key);

  @override
  State<AdminSchedules> createState() => _AdminSchedules();
}

class _AdminSchedules extends State<AdminSchedules> {
  // Color scheme to match the admin announcement dashboard
  final Color primaryColor = const Color(0xFF1E1E1E);
  final Color accentColor = const Color(0xFF4CAF50);
  final Color backgroundColor = Colors.grey.shade100;
  final Color cardColor = Colors.white;
  final Color textColor = Colors.grey.shade800;

  // Add variables to store admin's barangay
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _adminBarangay = '';
  bool _isLoading = true;

  // Filter options
  String? _selectedWasteType;
  String? _selectedStatus;
  DateTime? _selectedDate;

  // Add new variables for month filter
  DateTime? _selectedMonthYear;

  // Add getter for available months
  Future<List<DateTime>> _getAvailableMonths() async {
    final schedules = await _getSchedulesStream().first;
    Set<DateTime> months = {};
    for (var schedule in schedules) {
      final date = schedule.date;
      months.add(DateTime(date.year, date.month));
    }
    var sortedMonths = months.toList()..sort((a, b) => b.compareTo(a));
    return sortedMonths;
  }

  // Add the grouping method
  Map<String, List<WasteCollectionSchedule>> _groupSchedulesByMonth(
      List<WasteCollectionSchedule> schedules) {
    Map<String, List<WasteCollectionSchedule>> grouped = {};

    for (var schedule in schedules) {
      String monthKey = DateFormat('MMMM yyyy').format(schedule.date);
      if (!grouped.containsKey(monthKey)) {
        grouped[monthKey] = [];
      }
      grouped[monthKey]!.add(schedule);
    }

    // Sort the months in descending order (newest first)
    var sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        DateTime dateA = DateFormat('MMMM yyyy').parse(a);
        DateTime dateB = DateFormat('MMMM yyyy').parse(b);
        return dateB.compareTo(dateA);
      });

    // Create a new map with sorted keys
    Map<String, List<WasteCollectionSchedule>> sortedGrouped = {};
    for (var key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
    }

    return sortedGrouped;
  }

  @override
  void initState() {
    super.initState();
    _fetchAdminBarangay();
  }

  // Add method to fetch admin's barangay
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
          setState(() {
            _adminBarangay = adminData['barangay'] ?? '';
            _isLoading = false;
          });
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
      print('Error fetching admin barangay: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Modify the stream to use the admin's barangay without prioritizing today
  Stream<List<WasteCollectionSchedule>> _getSchedulesStream() {
    return FirebaseFirestore.instance
        .collection('schedule')
        .where('barangay', isEqualTo: _adminBarangay)
        .snapshots()
        .map((snapshot) {
      List<WasteCollectionSchedule> schedules = snapshot.docs.map((doc) {
        // Convert Firestore document to WasteCollectionSchedule
        Map<String, dynamic> data = doc.data();

        // Extract start and end time maps from Firestore
        Map<String, dynamic> startTimeMap = data['startTime'];
        Map<String, dynamic> endTimeMap = data['endTime'];

        // Use the admin's barangay as default location if not specified
        String locationText = data['location'] ?? 'No location specified';
        if (locationText == 'No location specified' &&
            _adminBarangay.isNotEmpty) {
          locationText = 'Barangay $_adminBarangay';
        }

        return WasteCollectionSchedule(
          id: doc.id,
          title: data['title'] ?? 'Untitled Schedule',
          description: data['description'] ?? '',
          date: (data['date'] as Timestamp).toDate(),
          startTime: TimeOfDay(
            hour: startTimeMap['hour'] ?? 8,
            minute: startTimeMap['minute'] ?? 0,
          ),
          endTime: TimeOfDay(
            hour: endTimeMap['hour'] ?? 10,
            minute: endTimeMap['minute'] ?? 0,
          ),
          wasteType: data['wasteType'] ?? 'General',
          location: locationText,
          adminId: data['adminId'] ?? '',
          adminName: data['adminName'] ?? 'Unknown',
          status: data['status'] ?? 'Scheduled',
        );
      }).toList();

      // Sort schedules by date (newest first)
      schedules.sort((a, b) => b.date.compareTo(a.date));

      return schedules;
    });
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
            // Header with title and add button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Waste Collection Schedules',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage and schedule waste collection for your barangay',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (widget.onAddSchedulePressed != null) {
                      widget.onAddSchedulePressed!();
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AddScheduleScreen(),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Schedule'),
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

            const SizedBox(height: 24),

            // Filter section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Month Filter
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 45,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: StreamBuilder<List<DateTime>>(
                            stream: Stream.fromFuture(_getAvailableMonths()),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              List<DateTime> months = snapshot.data!;

                              return DropdownButtonFormField<DateTime>(
                                value: _selectedMonthYear,
                                items: [
                                  DropdownMenuItem<DateTime>(
                                    value: null,
                                    child: Text('All Months'),
                                  ),
                                  ...months.map((date) {
                                    return DropdownMenuItem<DateTime>(
                                      value: date,
                                      child: Text(
                                          DateFormat('MMMM yyyy').format(date)),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (DateTime? value) {
                                  setState(() => _selectedMonthYear = value);
                                },
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  prefixIcon: Icon(Icons.calendar_month,
                                      size: 16, color: Colors.grey.shade600),
                                  hintText: 'Select Month',
                                  hintStyle: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                icon: Icon(Icons.arrow_drop_down,
                                    color: Colors.grey.shade600),
                                dropdownColor: cardColor,
                                isDense: true,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Existing Waste Type Filter
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 45,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedWasteType,
                            items: [
                              'All',
                              'General',
                              'Biodegradable',
                              'Non-biodegradable',
                            ].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value == 'All' ? null : value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? value) {
                              setState(() => _selectedWasteType = value);
                            },
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              prefixIcon: Icon(Icons.recycling,
                                  size: 16, color: Colors.grey.shade600),
                              hintText: 'Waste Type',
                              hintStyle: TextStyle(
                                  fontSize: 14, color: Colors.grey.shade600),
                              contentPadding: EdgeInsets.zero,
                            ),
                            icon: Icon(Icons.arrow_drop_down,
                                color: Colors.grey.shade600),
                            dropdownColor: cardColor,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Status Filter
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 45,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedStatus,
                            items: [
                              'All',
                              'Scheduled',
                              'Completed',
                              'Cancelled'
                            ].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value == 'All' ? null : value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? value) {
                              setState(() => _selectedStatus = value);
                            },
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              prefixIcon: Icon(Icons.flag,
                                  size: 16, color: Colors.grey.shade600),
                              hintText: 'Status',
                              hintStyle: TextStyle(
                                  fontSize: 14, color: Colors.grey.shade600),
                              contentPadding: EdgeInsets.zero,
                            ),
                            icon: Icon(Icons.arrow_drop_down,
                                color: Colors.grey.shade600),
                            dropdownColor: cardColor,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Date Filter
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate ?? DateTime.now(),
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 365)),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme:
                                        ColorScheme.light(primary: accentColor),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedDate = picked;
                              });
                            }
                          },
                          child: Container(
                            height: 45,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedDate == null
                                        ? 'Collection Date'
                                        : DateFormat('MMM dd, yyyy')
                                            .format(_selectedDate!),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _selectedDate == null
                                          ? Colors.grey.shade600
                                          : textColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_selectedDate != null)
                                  IconButton(
                                    icon: Icon(Icons.close,
                                        size: 16, color: Colors.grey.shade600),
                                    onPressed: () => setState(() {
                                      _selectedDate = null;
                                    }),
                                    splashRadius: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Replace static statistics with StreamBuilder
            StreamBuilder<List<WasteCollectionSchedule>>(
                stream: _getSchedulesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Row(
                      children: List.generate(
                          3,
                          (index) => Expanded(
                                child: Container(
                                  height: 80,
                                  margin: EdgeInsets.only(
                                      right: index < 2 ? 16 : 0),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                ),
                              )),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  List<WasteCollectionSchedule> schedules = snapshot.data ?? [];

                  // Get the current date with time set to midnight for accurate comparison
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final endOfWeek = today.add(const Duration(days: 7));

                  return Row(
                    children: [
                      _buildStatCard(
                        title: 'Total Schedules',
                        value: schedules.length.toString(),
                        icon: Icons.event,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        title: 'This Week',
                        value: schedules
                            .where((s) {
                              // Convert schedule date to midnight for proper comparison
                              final scheduleDate = DateTime(
                                s.date.year,
                                s.date.month,
                                s.date.day,
                              );
                              return scheduleDate.isAfter(today
                                      .subtract(const Duration(days: 1))) &&
                                  scheduleDate.isBefore(endOfWeek);
                            })
                            .length
                            .toString(),
                        icon: Icons.date_range,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        title: 'Completed',
                        value: schedules
                            .where((s) => s.status == 'Completed')
                            .length
                            .toString(),
                        icon: Icons.task_alt,
                        color: Colors.green,
                      ),
                    ],
                  );
                }),

            const SizedBox(height: 24),

            // Replace static schedule list with StreamBuilder
            Expanded(
              child: StreamBuilder<List<WasteCollectionSchedule>>(
                  stream: _getSchedulesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }

                    List<WasteCollectionSchedule> schedules =
                        snapshot.data ?? [];
                    List<WasteCollectionSchedule> filteredSchedules =
                        _filterSchedules(schedules);

                    if (filteredSchedules.isEmpty) {
                      return _buildEmptyState();
                    }

                    // Group schedules by month
                    final groupedSchedules =
                        _groupSchedulesByMonth(filteredSchedules);

                    return ListView.builder(
                      itemCount: groupedSchedules.length *
                          2, // Multiply by 2 to account for headers
                      itemBuilder: (context, index) {
                        // If index is even, it's a header
                        if (index.isEven) {
                          final monthKey =
                              groupedSchedules.keys.elementAt(index ~/ 2);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: accentColor.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_month,
                                        size: 18,
                                        color: accentColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        monthKey,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: accentColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    '${groupedSchedules[monthKey]!.length} schedules',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          // If index is odd, it's a schedule card
                          final monthKey =
                              groupedSchedules.keys.elementAt(index ~/ 2);
                          final monthSchedules = groupedSchedules[monthKey]!;
                          final scheduleIndex = (index - 1) ~/ 2;

                          if (scheduleIndex < monthSchedules.length) {
                            return _buildScheduleCard(
                                monthSchedules[scheduleIndex]);
                          }
                          return const SizedBox.shrink();
                        }
                      },
                    );
                  }),
            ),
          ],
        ),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
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

  Widget _buildScheduleCard(WasteCollectionSchedule schedule) {
    // Determine card accent color and icon based on waste type
    Color cardAccent;
    IconData wasteIcon;

    switch (schedule.wasteType) {
      case 'Biodegradable':
        cardAccent = Colors.green.shade600;
        wasteIcon = Icons.compost;
        break;
      case 'Non-biodegradable':
        cardAccent = Colors.orange.shade600;
        wasteIcon = Icons.delete;
        break;
      case 'Recyclable':
        cardAccent = Colors.teal.shade600;
        wasteIcon = Icons.recycling;
        break;
      case 'General':
        cardAccent = Colors.blue.shade600;
        wasteIcon = Icons.delete_sweep;
        break;
      default:
        cardAccent = Colors.blue.shade600;
        wasteIcon = Icons.delete;
    }

    // Status indicator color
    Color statusColor = _getStatusColor(schedule.status);
    bool isCompleted = schedule.status == 'Completed';
    bool isCancelled = schedule.status == 'Cancelled';

    // Determine location text - use barangay if no specific location
    String locationText = schedule.location;
    if (locationText == 'No location specified' && _adminBarangay.isNotEmpty) {
      locationText = 'Barangay $_adminBarangay';
    }

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
                            cardAccent.withOpacity(0.8),
                            cardAccent.withOpacity(0.6)
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
                  _getStatusIcon(schedule.status),
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  schedule.status.toUpperCase(),
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
                    schedule.wasteType,
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

          // Schedule title and location
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardAccent, // Use solid color for better visibility
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
                        schedule.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors
                              .black87, // Darker text for better readability
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
                            color: cardAccent,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              locationText,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors
                                    .black87, // Darker text for readability
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

          // Enhanced date and time containers with better readability
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
                    color: cardAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cardAccent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cardAccent,
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
                                .format(schedule.date),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  Colors.black87, // Dark text for readability
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
                    color: cardAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cardAccent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cardAccent,
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
                            '${_formatTimeOfDay(schedule.startTime)} - ${_formatTimeOfDay(schedule.endTime)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  Colors.black87, // Dark text for readability
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

          // Action buttons with improved styling
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isCompleted && !isCancelled)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markAsComplete(schedule),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Mark Complete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                if (!isCompleted && !isCancelled) const SizedBox(width: 12),

                // Edit button
                Container(
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.edit, color: accentColor, size: 22),
                    onPressed: () {
                      // Edit functionality
                      _editSchedule(schedule);
                    },
                    tooltip: 'Edit Schedule',
                  ),
                ),
                const SizedBox(width: 8),

                // Delete button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 22),
                    onPressed: () => _confirmDelete(context, schedule),
                    tooltip: 'Delete Schedule',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Method to handle marking schedule as complete
  void _markAsComplete(WasteCollectionSchedule schedule) {
    FirebaseFirestore.instance
        .collection('schedule')
        .doc(schedule.id)
        .update({'status': 'Completed'}).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Schedule marked as completed'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  // Method to confirm and handle deletion
  Future<void> _confirmDelete(
      BuildContext context, WasteCollectionSchedule schedule) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Schedule'),
          content: Text('Are you sure you want to delete "${schedule.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('schedule')
                    .doc(schedule.id)
                    .delete()
                    .then((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Schedule deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.of(context).pop();
                }).catchError((error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  Navigator.of(context).pop();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        );
      },
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Completed':
        return Icons.check_circle;
      case 'Cancelled':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  List<WasteCollectionSchedule> _filterSchedules(
      List<WasteCollectionSchedule> schedules) {
    return schedules.where((schedule) {
      // Apply month filter
      if (_selectedMonthYear != null) {
        final scheduleDate = DateTime(schedule.date.year, schedule.date.month);
        final filterDate =
            DateTime(_selectedMonthYear!.year, _selectedMonthYear!.month);
        if (scheduleDate != filterDate) {
          return false;
        }
      }

      // Apply waste type filter
      if (_selectedWasteType != null &&
          schedule.wasteType != _selectedWasteType) {
        return false;
      }

      // Apply status filter
      if (_selectedStatus != null && schedule.status != _selectedStatus) {
        return false;
      }

      // Apply specific date filter
      if (_selectedDate != null) {
        final scheduleDate = DateTime(
          schedule.date.year,
          schedule.date.month,
          schedule.date.day,
        );
        final filterDate = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
        );

        if (scheduleDate != filterDate) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  String _formatTimeOfDay(TimeOfDay timeOfDay) {
    final hour = timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod;
    final minute = timeOfDay.minute.toString().padLeft(2, '0');
    final period = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // Method to handle editing a schedule
  void _editSchedule(WasteCollectionSchedule schedule) {
    // Check if this is part of a recurring schedule
    if (schedule.id.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('schedule')
          .doc(schedule.id)
          .get()
          .then((doc) {
        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          bool isRecurring = data['isRecurring'] == true;
          String? recurringGroupId = data['recurringGroupId'];

          if (isRecurring && recurringGroupId != null) {
            // Show a dialog asking if they want to edit just this occurrence or the entire series
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Edit Schedule'),
                  content: const Text(
                      'This is part of a recurring schedule. Would you like to edit just this occurrence or all occurrences in the series?'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _editSingleSchedule(schedule);
                      },
                      child: const Text('Edit This Occurrence'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _editRecurringSchedules(schedule, recurringGroupId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Edit All Occurrences'),
                    ),
                  ],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                );
              },
            );
          } else {
            // Not recurring, just edit this schedule
            _editSingleSchedule(schedule);
          }
        }
      });
    } else {
      // Just edit this schedule
      _editSingleSchedule(schedule);
    }
  }

  // Edit a single schedule
  void _editSingleSchedule(WasteCollectionSchedule schedule) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddScheduleScreen(
          isEditing: true,
          scheduleId: schedule.id,
          onBackPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  // Edit all recurring schedules in a group
  void _editRecurringSchedules(
      WasteCollectionSchedule schedule, String recurringGroupId) {
    // Find the recurring master document
    FirebaseFirestore.instance
        .collection('schedule')
        .where('recurringGroupId', isEqualTo: recurringGroupId)
        .where('isRecurringMaster', isEqualTo: true)
        .limit(1)
        .get()
        .then((querySnapshot) {
      if (querySnapshot.docs.isNotEmpty) {
        String masterId = querySnapshot.docs.first.id;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AddScheduleScreen(
              isEditing: true,
              scheduleId: masterId,
              recurringGroupId: recurringGroupId,
              onBackPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
      } else {
        // If no master document is found, just edit this one
        _editSingleSchedule(schedule);
      }
    });
  }

  // Add this method to build the empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No schedules found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or add a new schedule',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

// Model class for waste collection schedule
class WasteCollectionSchedule {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String wasteType;
  final String location;
  final String adminId;
  final String adminName;
  final String status;

  WasteCollectionSchedule({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.wasteType,
    required this.location,
    required this.adminId,
    required this.adminName,
    required this.status,
  });
}
