import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResidentScanHistoryScreen extends StatefulWidget {
  const ResidentScanHistoryScreen({super.key});

  @override
  State<ResidentScanHistoryScreen> createState() =>
      _ResidentScanHistoryScreenState();
}

class _ResidentScanHistoryScreenState extends State<ResidentScanHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _scanHistory = [];
  List<String> _scanDates = [];
  Map<String, List<Map<String, dynamic>>> _groupedScans = {};
  bool _isLoading = true;
  int _totalScans = 0;
  String? _errorMessage;

  // Filtering
  String _selectedMonth = 'All';
  List<String> _availableMonths = ['All'];
  Map<String, List<Map<String, dynamic>>> _filteredGroupedScans = {};
  List<String> _filteredScanDates = [];

  @override
  void initState() {
    super.initState();
    _loadScanHistory();
  }

  // Get current resident ID
  String? get currentResidentId => _auth.currentUser?.uid;

  Future<void> _loadScanHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (currentResidentId == null) {
        setState(() {
          _errorMessage = "No resident logged in";
          _isLoading = false;
        });
        return;
      }

      // Get scans from Firestore where resident was scanned
      final scansSnapshot = await _firestore
          .collection('scans')
          .where('residentId', isEqualTo: currentResidentId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      List<Map<String, dynamic>> scansData = [];
      for (var doc in scansSnapshot.docs) {
        Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        scansData.add(data);
      }

      // Get total scans count
      final scansCount = await _firestore
          .collection('scans')
          .where('residentId', isEqualTo: currentResidentId)
          .count()
          .get();

      _totalScans = scansCount.count ?? scansData.length;

      // Group scans by date
      Map<String, List<Map<String, dynamic>>> groupedScans = {};
      List<String> scanDates = [];
      Set<String> availableMonths = {'All'};

      for (var scan in scansData) {
        String date = _formatDate(scan['timestamp']);
        if (!groupedScans.containsKey(date)) {
          groupedScans[date] = [];
          scanDates.add(date);
        }
        groupedScans[date]!.add(scan);

        // Extract month for filtering
        try {
          DateTime dateTime = DateTime.parse(date);
          String monthYear = DateFormat('MMMM yyyy').format(dateTime);
          availableMonths.add(monthYear);
        } catch (e) {
          print('Error parsing date for month: $e');
        }
      }

      setState(() {
        _scanHistory = scansData;
        _groupedScans = groupedScans;
        _scanDates = scanDates;
        _availableMonths = availableMonths.toList()..sort();
        _applyFilter(_selectedMonth);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load scan history: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFilter(String month) {
    setState(() {
      _selectedMonth = month;

      if (month == 'All') {
        _filteredGroupedScans = _groupedScans;
        _filteredScanDates = _scanDates;
      } else {
        _filteredGroupedScans = {};
        _filteredScanDates = [];

        for (String date in _scanDates) {
          try {
            DateTime dateTime = DateTime.parse(date);
            String monthYear = DateFormat('MMMM yyyy').format(dateTime);

            if (monthYear == month) {
              _filteredGroupedScans[date] = _groupedScans[date]!;
              _filteredScanDates.add(date);
            }
          } catch (e) {
            print('Error filtering date: $e');
          }
        }
      }
    });
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) {
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
    }

    try {
      if (timestamp is Timestamp) {
        final dateTime = timestamp.toDate();
        return DateFormat('yyyy-MM-dd').format(dateTime);
      } else if (timestamp.runtimeType.toString().contains('Timestamp')) {
        final dateTime = timestamp.toDate();
        return DateFormat('yyyy-MM-dd').format(dateTime);
      } else if (timestamp is String && timestamp.contains('T')) {
        return DateFormat('yyyy-MM-dd').format(DateTime.parse(timestamp));
      }
    } catch (e) {
      print('Error formatting date: $e');
    }

    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Scan History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 3, 144, 123),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadScanHistory,
            color: Colors.white,
          ),
        ],
      ),
      body: _errorMessage != null
          ? _buildErrorView()
          : Column(
              children: [
                _buildSummaryCard(),
                _buildFilterSection(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                          color: Color.fromARGB(255, 3, 144, 123),
                        ))
                      : _scanHistory.isEmpty
                          ? _buildEmptyHistoryView()
                          : RefreshIndicator(
                              onRefresh: _loadScanHistory,
                              color: const Color.fromARGB(255, 3, 144, 123),
                              child: _buildScanHistoryList(),
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          const Text(
            'Filter by: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMonth,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                  items: _availableMonths
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      _applyFilter(newValue);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Scan History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 3, 144, 123),
                foregroundColor: Colors.white,
              ),
              onPressed: _loadScanHistory,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanHistoryList() {
    return ListView.builder(
      itemCount: _filteredScanDates.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final date = _filteredScanDates[index];
        final scansForDate = _filteredGroupedScans[date] ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                _formatDateHeader(date),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color.fromARGB(255, 3, 144, 123),
                ),
              ),
            ),
            ...scansForDate.map((scan) => _buildScanCard(scan)).toList(),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  String _formatDateHeader(String date) {
    try {
      final DateTime dateTime = DateTime.parse(date);
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);

      if (dateTime.year == now.year &&
          dateTime.month == now.month &&
          dateTime.day == now.day) {
        return 'Today';
      } else if (dateTime.year == yesterday.year &&
          dateTime.month == yesterday.month &&
          dateTime.day == yesterday.day) {
        return 'Yesterday';
      } else {
        return DateFormat('EEEE, MMMM d, yyyy').format(dateTime);
      }
    } catch (e) {
      return date;
    }
  }

  Widget _buildEmptyHistoryView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.qr_code_scanner,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No scan history yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Your scan history will appear here when collectors scan your QR code.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: const Color.fromARGB(255, 3, 144, 123),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Top section - Total Scans
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.qr_code_scanner,
                    color: Color.fromARGB(255, 3, 144, 123),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Times Scanned',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _isLoading ? '...' : '$_totalScans',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white30, height: 24),
            // Bottom section - Stats
            LayoutBuilder(builder: (context, constraints) {
              // Determine if we need to use a vertical layout or horizontal layout
              bool useVerticalLayout = constraints.maxWidth < 300;

              if (useVerticalLayout) {
                // Vertical layout for narrow screens
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatisticItem(
                      'Total Points Earned',
                      _isLoading ? '...' : '${_calculateTotalPoints()} pts',
                      Icons.stars,
                    ),
                    const SizedBox(height: 12),
                    _buildStatisticItem(
                      'Total Waste Contributed',
                      _isLoading ? '...' : '${_calculateTotalWaste()} kg',
                      Icons.delete_outline,
                    ),
                  ],
                );
              } else {
                // Horizontal layout for wider screens
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: _buildStatisticItem(
                        'Total Points',
                        _isLoading ? '...' : '${_calculateTotalPoints()} pts',
                        Icons.stars,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: _buildStatisticItem(
                        'Total Waste',
                        _isLoading ? '...' : '${_calculateTotalWaste()} kg',
                        Icons.delete_outline,
                      ),
                    ),
                  ],
                );
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticItem(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white70,
          size: 18,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }

  int _calculateTotalPoints() {
    int total = 0;
    for (var scan in _scanHistory) {
      total += (scan['pointsAwarded'] ?? 0) as int;
    }
    return total;
  }

  double _calculateTotalWaste() {
    double total = 0;
    for (var scan in _scanHistory) {
      if (scan['garbageWeight'] != null) {
        if (scan['garbageWeight'] is int) {
          total += (scan['garbageWeight'] as int).toDouble();
        } else {
          total += (scan['garbageWeight'] as double);
        }
      }
    }
    return double.parse(total.toStringAsFixed(2));
  }

  Widget _buildScanCard(Map<String, dynamic> scan) {
    final String collectorName = scan['collectorName'] ?? 'Unknown Collector';
    final int points = scan['pointsAwarded'] ?? 0;
    final String formattedTime = _formatScanTime(scan['timestamp']);
    final String garbageType = scan['garbageType'] ?? 'Not specified';
    final String formattedDate = _formatCardDate(scan['timestamp']);

    // Handle potential garbage weight type issues
    double garbageWeight = 0.0;
    if (scan['garbageWeight'] != null) {
      if (scan['garbageWeight'] is int) {
        garbageWeight = (scan['garbageWeight'] as int).toDouble();
      } else {
        garbageWeight = (scan['garbageWeight'] as double);
      }
    }

    final String collectorBarangay =
        scan['collectorBarangay'] ?? scan['barangay'] ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emphasized header showing "Scanned by: Collector Name"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 3, 144, 123),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Scanned by: ',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        TextSpan(
                          text: collectorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Date and time section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  formattedTime,
                  style: const TextStyle(
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Points earned
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.stars,
                  color: Colors.amber,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '$points points earned',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

          // Divider
          const Divider(height: 1),

          // Expandable details section
          ExpansionTile(
            title: const Text(
              'View Details',
              style: TextStyle(
                fontSize: 14,
                color: Color.fromARGB(255, 3, 144, 123),
              ),
            ),
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow('Waste Type', garbageType),
                    _buildDetailRow(
                        'Weight', '${garbageWeight.toStringAsFixed(2)} kg'),
                    _buildDetailRow('Collector Barangay', collectorBarangay),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCardDate(dynamic timestamp) {
    if (timestamp == null) {
      return DateFormat('MMMM d, yyyy').format(DateTime.now());
    }

    try {
      if (timestamp is Timestamp) {
        final dateTime = timestamp.toDate();
        return DateFormat('MMMM d, yyyy').format(dateTime);
      } else if (timestamp.runtimeType.toString().contains('Timestamp')) {
        final dateTime = timestamp.toDate();
        return DateFormat('MMMM d, yyyy').format(dateTime);
      } else if (timestamp is String && timestamp.contains('T')) {
        return DateFormat('MMMM d, yyyy').format(DateTime.parse(timestamp));
      }
    } catch (e) {
      print('Error formatting card date: $e');
    }

    return DateFormat('MMMM d, yyyy').format(DateTime.now());
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  String _formatScanTime(dynamic timestamp) {
    if (timestamp == null) {
      return DateFormat('h:mm a').format(DateTime.now());
    }

    try {
      if (timestamp is Timestamp) {
        final dateTime = timestamp.toDate();
        return DateFormat('h:mm a').format(dateTime);
      } else if (timestamp.runtimeType.toString().contains('Timestamp')) {
        final dateTime = timestamp.toDate();
        return DateFormat('h:mm a').format(dateTime);
      } else if (timestamp is String && timestamp.contains('T')) {
        return DateFormat('h:mm a').format(DateTime.parse(timestamp));
      }
    } catch (e) {
      print('Error formatting scan time: $e');
    }

    return DateFormat('h:mm a').format(DateTime.now());
  }
}
