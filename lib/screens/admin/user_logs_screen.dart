import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class UserLogsScreen extends StatefulWidget {
  final String adminBarangay;

  const UserLogsScreen({
    Key? key,
    required this.adminBarangay,
  }) : super(key: key);

  @override
  State<UserLogsScreen> createState() => _UserLogsScreenState();
}

class _UserLogsScreenState extends State<UserLogsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  // State variables
  bool _isLoading = true;

  // Logs data
  List<Map<String, dynamic>> _residentLogs = [];
  List<Map<String, dynamic>> _collectorLogs = [];

  // Filtered logs
  List<Map<String, dynamic>> _filteredResidentLogs = [];
  List<Map<String, dynamic>> _filteredCollectorLogs = [];

  // Filter options
  DateTime? _startDate;
  DateTime? _endDate;
  String _actionFilter = 'All';
  String _userFilter = '';

  // Action type options for filtering
  final List<String> _actionTypes = ['All', 'login', 'logout'];

  // Quick filter options
  bool _showLoginOnly = false;
  bool _showLogoutOnly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchUserLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch resident logs from Firestore
      await _fetchResidentLogs();

      // Fetch collector logs from Firestore (if you have a separate collection)
      // or create mock collector logs for now
      await _fetchCollectorLogs();

      // Initially, filtered logs are the same as all logs
      _filteredResidentLogs = [..._residentLogs];
      _filteredCollectorLogs = [..._collectorLogs];
    } catch (e) {
      print('Error fetching logs: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchResidentLogs() async {
    try {
      // Fetch resident logs from resident_logs collection in Firestore
      // Filter by barangay if applicable
      QuerySnapshot logsSnapshot;

      try {
        logsSnapshot = await _firestore
            .collection('resident_logs')
            .where('barangay', isEqualTo: widget.adminBarangay)
            .orderBy('timestamp', descending: true)
            .limit(100) // Limit to prevent loading too many logs
            .get();
      } catch (error) {
        // Handle specific Firestore index error
        if (error.toString().contains('The query requires an index')) {
          print('Firestore index required: $error');
          // Return minimal logs without filtering by barangay to avoid index error
          // or try a simpler query
          try {
            logsSnapshot = await _firestore
                .collection('resident_logs')
                .orderBy('timestamp', descending: true)
                .limit(20)
                .get();
          } catch (fallbackError) {
            print('Error with fallback query: $fallbackError');
            _residentLogs = [];
            return;
          }
        } else {
          rethrow;
        }
      }

      List<Map<String, dynamic>> fetchedLogs = [];

      for (var doc in logsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Convert Firestore timestamp to DateTime
        DateTime timestamp;
        if (data['timestamp'] is Timestamp) {
          timestamp = (data['timestamp'] as Timestamp).toDate();
        } else {
          timestamp = DateTime.now(); // Fallback if timestamp is missing
        }

        // Extract device info
        String deviceInfo = 'Unknown Device';
        if (data['deviceInfo'] is Map) {
          Map<String, dynamic> deviceData =
              data['deviceInfo'] as Map<String, dynamic>;
          deviceInfo = deviceData['platform'] ?? 'Unknown Platform';
        }

        // Format the action display name with proper capitalization
        String action = data['action'] ?? 'unknown';
        action = action.toString().toLowerCase();

        // Get user name from various possible fields
        String userName = 'Unknown User';
        if (data['fullName'] != null &&
            data['fullName'].toString().isNotEmpty) {
          userName = data['fullName'];
        } else if (data['name'] != null && data['name'].toString().isNotEmpty) {
          userName = data['name'];
        } else if (data['firstName'] != null && data['lastName'] != null) {
          userName = '${data['firstName']} ${data['lastName']}';
        } else if (data['email'] != null) {
          userName = data['email'];
        }

        // Build a more detailed log entry
        fetchedLogs.add({
          'id': doc.id,
          'userId': data['userId'] ?? 'unknown',
          'userName': userName,
          'userType': 'Resident',
          'action': action,
          'timestamp': timestamp,
          'details': _getActionDetails(action, data),
          'ipAddress': data['ipAddress'] ?? 'Unknown IP',
          'deviceInfo': deviceInfo,
          'status': data['status'] ?? 'unknown',
          'barangay': data['barangay'] ?? 'Unknown Barangay',
        });
      }

      _residentLogs = fetchedLogs;
    } catch (e) {
      print('Error fetching resident logs: $e');
      _residentLogs = []; // Empty list in case of error
    }
  }

  Future<void> _fetchCollectorLogs() async {
    try {
      // First try to fetch from collector_logs if it exists
      try {
        QuerySnapshot collectorLogsSnapshot;

        try {
          collectorLogsSnapshot = await _firestore
              .collection('collector_logs')
              .where('barangay', isEqualTo: widget.adminBarangay)
              .orderBy('timestamp', descending: true)
              .limit(100)
              .get();
        } catch (error) {
          // Handle specific Firestore index error
          if (error.toString().contains('The query requires an index')) {
            print('Firestore index required for collector_logs: $error');
            // Try a simpler query without barangay filter
            try {
              collectorLogsSnapshot = await _firestore
                  .collection('collector_logs')
                  .orderBy('timestamp', descending: true)
                  .limit(20)
                  .get();
            } catch (fallbackError) {
              print('Error with fallback collector query: $fallbackError');
              // Continue to use mock data
              throw Exception('Index required and fallback failed');
            }
          } else {
            rethrow;
          }
        }

        if (collectorLogsSnapshot.docs.isNotEmpty) {
          List<Map<String, dynamic>> fetchedLogs = [];

          for (var doc in collectorLogsSnapshot.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

            // Convert Firestore timestamp to DateTime
            DateTime timestamp;
            if (data['timestamp'] is Timestamp) {
              timestamp = (data['timestamp'] as Timestamp).toDate();
            } else {
              timestamp = DateTime.now();
            }

            // Extract device info
            String deviceInfo = 'Unknown Device';
            if (data['deviceInfo'] is Map) {
              Map<String, dynamic> deviceData =
                  data['deviceInfo'] as Map<String, dynamic>;
              deviceInfo = deviceData['platform'] ?? 'Unknown Platform';
            }

            // Format the action
            String action = data['action'] ?? 'unknown';
            action = action.toString().toLowerCase();

            // Get collector ID (use only collectorId, not userId)
            String collectorId = data['collectorId'] ?? 'unknown';

            // Get collector name from various possible fields
            String collectorName = 'Unknown Collector';
            if (data['fullName'] != null &&
                data['fullName'].toString().isNotEmpty) {
              collectorName = data['fullName'];
            } else if (data['name'] != null &&
                data['name'].toString().isNotEmpty) {
              collectorName = data['name'];
            } else if (data['firstName'] != null && data['lastName'] != null) {
              collectorName = '${data['firstName']} ${data['lastName']}';
            } else if (data['email'] != null) {
              collectorName = data['email'];
            }

            fetchedLogs.add({
              'id': doc.id,
              'userId': collectorId, // Use only collectorId
              'userName': collectorName,
              'userType': 'Collector',
              'action': action,
              'timestamp': timestamp,
              'details': _getActionDetails(action, data),
              'ipAddress': data['ipAddress'] ?? 'Unknown IP',
              'deviceInfo': deviceInfo,
              'status': data['status'] ?? 'unknown',
              'barangay': data['barangay'] ?? 'Unknown Barangay',
            });
          }

          _collectorLogs = fetchedLogs;
          return;
        }
      } catch (e) {
        print('Error fetching from collector_logs: $e');
        // Continue to generate mock collector logs if collection doesn't exist or index error
      }

      // If we couldn't fetch real collector logs, generate mock data
      // In a production app, you would create a collector_logs collection
      _generateMockCollectorLogs();
    } catch (e) {
      print('Error in collector logs function: $e');
      _generateMockCollectorLogs(); // Fallback to mock data
    }
  }

  // Generate mock data for collector logs (temporary)
  void _generateMockCollectorLogs() {
    final List<String> collectors = [
      'Carlos Bautista',
      'Diego Soriano',
      'Manuel Flores',
      'Roberto Garcia',
      'Santiago Torres'
    ];

    final List<String> actions = [
      'login',
      'logout',
      'collection_completed',
      'profile_update',
      'account_created',
      'route_changed'
    ];

    List<Map<String, dynamic>> logs = [];

    // Generate 25 random logs
    for (int i = 0; i < 25; i++) {
      final randomCollector = collectors[i % collectors.length];
      final randomAction = actions[i % actions.length];

      logs.add({
        'id': 'col-log-$i',
        'userId': 'col-${200 + i}',
        'userName': randomCollector,
        'userType': 'Collector',
        'action': randomAction,
        'timestamp': DateTime.now().subtract(Duration(hours: i * 4)),
        'details': 'Performed $randomAction action',
        'ipAddress': '192.168.${i % 255}.${(i * 7) % 255}',
        'deviceInfo': i % 2 == 0 ? 'Android Device' : 'iOS Device',
        'barangay': widget.adminBarangay,
        'status': 'success',
      });
    }

    // Sort by timestamp (newest first)
    logs.sort((a, b) =>
        (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    _collectorLogs = logs;
  }

  // Helper function to create detailed log message based on action
  String _getActionDetails(String action, Map<String, dynamic> data) {
    switch (action.toLowerCase()) {
      case 'login':
        return 'User logged in successfully';
      case 'logout':
        return 'User logged out';
      case 'profile_update':
        return 'User updated their profile information';
      case 'report_created':
        return 'User submitted a new report';
      case 'collection_completed':
        return 'Collector completed a waste collection';
      case 'rewards_claimed':
        return 'User claimed rewards';
      case 'password_reset':
        return 'User requested a password reset';
      case 'account_created':
        return 'New user account was created';
      case 'route_changed':
        return 'Collector route was updated';
      default:
        return data['details'] ?? 'Activity recorded';
    }
  }

  // Apply filters to logs
  void _applyFilters() {
    setState(() {
      // Apply quick filters if enabled, otherwise use selected action filter
      String effectiveActionFilter = _actionFilter;
      if (_showLoginOnly) {
        effectiveActionFilter = 'login';
      } else if (_showLogoutOnly) {
        effectiveActionFilter = 'logout';
      }

      _filteredResidentLogs = _residentLogs.where((log) {
        // Filter by date range
        bool dateMatch = true;
        if (_startDate != null) {
          dateMatch =
              dateMatch && (log['timestamp'] as DateTime).isAfter(_startDate!);
        }
        if (_endDate != null) {
          // Add one day to include the end date fully
          final endDatePlusOne = _endDate!.add(const Duration(days: 1));
          dateMatch = dateMatch &&
              (log['timestamp'] as DateTime).isBefore(endDatePlusOne);
        }

        // Filter by action type
        bool actionMatch = effectiveActionFilter == 'All' ||
            log['action'] == effectiveActionFilter.toLowerCase();

        // Filter by user name or email
        bool userMatch = _userFilter.isEmpty ||
            log['userName']
                .toString()
                .toLowerCase()
                .contains(_userFilter.toLowerCase());

        return dateMatch && actionMatch && userMatch;
      }).toList();

      _filteredCollectorLogs = _collectorLogs.where((log) {
        // Filter by date range
        bool dateMatch = true;
        if (_startDate != null) {
          dateMatch =
              dateMatch && (log['timestamp'] as DateTime).isAfter(_startDate!);
        }
        if (_endDate != null) {
          // Add one day to include the end date fully
          final endDatePlusOne = _endDate!.add(const Duration(days: 1));
          dateMatch = dateMatch &&
              (log['timestamp'] as DateTime).isBefore(endDatePlusOne);
        }

        // Filter by action type
        bool actionMatch = effectiveActionFilter == 'All' ||
            log['action'] == effectiveActionFilter.toLowerCase();

        // Filter by user name
        bool userMatch = _userFilter.isEmpty ||
            log['userName']
                .toString()
                .toLowerCase()
                .contains(_userFilter.toLowerCase());

        return dateMatch && actionMatch && userMatch;
      }).toList();
    });
  }

  // Reset all filters
  void _resetFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _actionFilter = 'All';
      _userFilter = '';
      _showLoginOnly = false;
      _showLogoutOnly = false;

      // Reset filtered logs
      _filteredResidentLogs = [..._residentLogs];
      _filteredCollectorLogs = [..._collectorLogs];
    });
  }

  // Toggle login filter
  void _toggleLoginFilter() {
    setState(() {
      _showLoginOnly = !_showLoginOnly;
      if (_showLoginOnly) {
        _showLogoutOnly = false;
        _actionFilter = 'All'; // Reset action filter
      }
      _applyFilters();
    });
  }

  // Toggle logout filter
  void _toggleLogoutFilter() {
    setState(() {
      _showLogoutOnly = !_showLogoutOnly;
      if (_showLogoutOnly) {
        _showLoginOnly = false;
        _actionFilter = 'All'; // Reset action filter
      }
      _applyFilters();
    });
  }

  // Format action name for display (capitalize first letter of each word)
  String _formatActionName(String action) {
    if (action.isEmpty) return '';

    List<String> words = action.split('_');
    for (var i = 0; i < words.length; i++) {
      if (words[i].isNotEmpty) {
        words[i] = words[i][0].toUpperCase() + words[i].substring(1);
      }
    }
    return words.join(' ');
  }

  // Select date range with date picker
  Future<void> _selectDateRange(BuildContext context) async {
    final initialDateRange = DateTimeRange(
      start: _startDate ?? DateTime.now().subtract(const Duration(days: 7)),
      end: _endDate ?? DateTime.now(),
    );

    final newDateRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF388E3C),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (newDateRange != null) {
      setState(() {
        _startDate = newDateRange.start;
        _endDate = newDateRange.end;
      });

      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
                : _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history,
                color: const Color(0xFF4CAF50),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'User Activity Logs',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF4CAF50)),
                onPressed: _fetchUserLogs,
                tooltip: 'Refresh Logs',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Track user activity across your barangay: ${widget.adminBarangay}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF4CAF50),
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: const Color(0xFF4CAF50),
            indicatorWeight: 3,
            tabs: const [
              Tab(
                icon: Icon(Icons.people),
                text: 'RESIDENTS',
              ),
              Tab(
                icon: Icon(Icons.work),
                text: 'COLLECTORS',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    // Display formatted action types in dropdown
    List<DropdownMenuItem<String>> actionItems =
        _actionTypes.map((String action) {
      return DropdownMenuItem<String>(
        value: action,
        child: Text(action == 'All' ? 'All Actions' : _formatActionName(action),
            style: const TextStyle(fontSize: 13)),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Filters:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 16),

              // Date Range Button
              InkWell(
                onTap: () => _selectDateRange(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.date_range,
                          size: 18, color: Color(0xFF4CAF50)),
                      const SizedBox(width: 8),
                      Text(
                        (_startDate == null || _endDate == null)
                            ? 'Select Date Range'
                            : '${DateFormat('MM/dd/yy').format(_startDate!)} - ${DateFormat('MM/dd/yy').format(_endDate!)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Action Type Dropdown
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _actionFilter,
                    icon: const Icon(Icons.arrow_drop_down,
                        color: Color(0xFF4CAF50)),
                    items: actionItems,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _actionFilter = newValue;
                        });
                        _applyFilters();
                      }
                    },
                  ),
                ),
              ),

              const Spacer(),

              Text(
                'Total: ${_tabController.index == 0 ? _filteredResidentLogs.length : _filteredCollectorLogs.length} logs',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(width: 16),

              // Reset Filters Button
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Reset'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // User Search Field
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by user name or email...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF4CAF50)),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (value) {
              setState(() {
                _userFilter = value;
              });
              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        // Residents Tab
        _filteredResidentLogs.isEmpty
            ? _buildEmptyState('No resident logs found', Icons.people)
            : _buildLogsList(_filteredResidentLogs),

        // Collectors Tab
        _filteredCollectorLogs.isEmpty
            ? _buildEmptyState('No collector logs found', Icons.work)
            : _buildLogsList(_filteredCollectorLogs),
      ],
    );
  }

  Widget _buildLogsList(List<Map<String, dynamic>> logs) {
    return Container(
      color: Colors.grey.shade50,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: logs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final log = logs[index];
          return _buildLogItem(log);
        },
      ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    IconData actionIcon;
    Color actionColor;

    // Determine icon and color based on action type
    switch (log['action']) {
      case 'login':
        actionIcon = Icons.login;
        actionColor = Colors.blue;
        break;
      case 'logout':
        actionIcon = Icons.logout;
        actionColor = Colors.orange;
        break;
      case 'profile_update':
        actionIcon = Icons.person;
        actionColor = Colors.purple;
        break;
      case 'report_created':
        actionIcon = Icons.report;
        actionColor = Colors.red;
        break;
      case 'collection_completed':
        actionIcon = Icons.check_circle;
        actionColor = Colors.green;
        break;
      case 'rewards_claimed':
        actionIcon = Icons.card_giftcard;
        actionColor = Colors.amber;
        break;
      case 'account_created':
        actionIcon = Icons.person_add;
        actionColor = Colors.teal;
        break;
      case 'password_reset':
        actionIcon = Icons.lock_reset;
        actionColor = Colors.indigo;
        break;
      case 'route_changed':
        actionIcon = Icons.route;
        actionColor = Colors.brown;
        break;
      default:
        actionIcon = Icons.info;
        actionColor = Colors.grey;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: actionColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    actionIcon,
                    color: actionColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatActionName(log['action']),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            log['userName'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: log['userType'] == 'Resident'
                                  ? const Color(0xFF4CAF50).withOpacity(0.1)
                                  : const Color(0xFF1976D2).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              log['userType'],
                              style: TextStyle(
                                fontSize: 11,
                                color: log['userType'] == 'Resident'
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFF1976D2),
                              ),
                            ),
                          ),
                          if (log['status'] == 'failed') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Failed',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('MM/dd/yy, hh:mm a').format(log['timestamp']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log['details'],
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.devices,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        log['deviceInfo'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (log['ipAddress'] != null &&
                          log['ipAddress'] != 'Unknown IP') ...[
                        Icon(
                          Icons.wifi,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          log['ipAddress'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
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

  Widget _buildEmptyState(String message, IconData icon) {
    String displayMessage = message;
    bool showIndexHelp = false;

    // If logs are empty due to index error, show helpful message
    if (message.contains('No resident logs found') &&
        _residentLogs.isEmpty &&
        !_isLoading) {
      try {
        _firestore
            .collection('resident_logs')
            .where('barangay', isEqualTo: widget.adminBarangay)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();
      } catch (e) {
        if (e.toString().contains('The query requires an index')) {
          displayMessage = 'Firestore index needs to be created';
          showIndexHelp = true;
        }
      }
    }

    // Check for collector logs index error
    if (message.contains('No collector logs found') &&
        _collectorLogs.isEmpty &&
        !_isLoading) {
      try {
        _firestore
            .collection('collector_logs')
            .where('barangay', isEqualTo: widget.adminBarangay)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();
      } catch (e) {
        if (e.toString().contains('The query requires an index')) {
          displayMessage = 'Firestore index needs to be created';
          showIndexHelp = true;
        }
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              showIndexHelp ? Icons.build : icon,
              size: 48,
              color: showIndexHelp ? Colors.orange : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayMessage,
            style: TextStyle(
              fontSize: 16,
              color: showIndexHelp ? Colors.orange : Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (showIndexHelp) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text(
                    'The app needs a Firestore index for this query. Please check the console for a direct link to create it, or create it manually in the Firebase Console.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message.contains('resident')
                        ? 'Collection: resident_logs\nFields to index: "barangay" (Ascending) and "timestamp" (Descending)'
                        : 'Collection: collector_logs\nFields to index: "barangay" (Ascending) and "timestamp" (Descending)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_startDate != null ||
              _endDate != null ||
              _actionFilter != 'All' ||
              _userFilter.isNotEmpty)
            TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.filter_alt_off, size: 18),
              label: const Text('Clear Filters'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4CAF50),
              ),
            ),
        ],
      ),
    );
  }
}
