import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Removed unused firebase_auth import
import 'package:intl/intl.dart';

class PenaltyListScreen extends StatefulWidget {
  final String adminBarangay;

  const PenaltyListScreen({
    Key? key,
    required this.adminBarangay,
  }) : super(key: key);

  @override
  State<PenaltyListScreen> createState() => _PenaltyListScreenState();
}

class _PenaltyListScreenState extends State<PenaltyListScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Removed unused _auth
  late TabController _tabController;

  // State variables
  bool _isLoading = true;
  List<Map<String, dynamic>> _penaltyScans = [];
  List<Map<String, dynamic>> _filteredPenaltyScans = [];
  // Holds scans after applying date filter only; used as base for search/type filters
  List<Map<String, dynamic>> _dateFilteredPenaltyScans = [];

  // Filters
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';

  // Time period filter (copied logic from analytics)
  String _selectedTimeFilter = 'This Week';
  String? _selectedMonth; // e.g., 'Jul 2025'
  final List<String> _timeFilters = [
    'This Week',
    'This Month',
    'This Year',
    'All Time',
    'Select Month',
  ];

  // Quick filter toggles
  final TextEditingController _searchController = TextEditingController();
  bool _showWarnings = true;
  bool _showPenalties = true;

  // Sort option (kept internal, controlled by dropdown removal)
  String _selectedSortOption = 'Latest';

  // Statistics
  int _totalWarnings = 0;
  int _totalPenalties = 0;
  int _totalScans = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchPenaltyScans();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPenaltyScans() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch scans that have warnings or penalties
      final QuerySnapshot scansSnapshot = await _firestore
          .collection('scans')
          .where('barangay', isEqualTo: widget.adminBarangay)
          .orderBy('timestamp', descending: true)
          .limit(100) // Limit to recent 100 scans for performance
          .get();

      List<Map<String, dynamic>> penaltyScans = [];

      for (var doc in scansSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Check if scan has warnings or penalties
        bool hasWarnings = false;
        bool hasPenalties = false;

        // Check warnings
        if (data['warnings'] != null && data['warnings'] is Map) {
          Map<String, dynamic> warnings =
              data['warnings'] as Map<String, dynamic>;
          hasWarnings = warnings.values.any((value) => value == true);
        }

        // Check penalties
        if (data['penalties'] != null && data['penalties'] is Map) {
          Map<String, dynamic> penalties =
              data['penalties'] as Map<String, dynamic>;
          hasPenalties = penalties.values.any((value) => value == true);
        }

        // Only include scans with warnings or penalties
        if (hasWarnings || hasPenalties) {
          // Add scan data with warning/penalty flags
          penaltyScans.add({
            'id': doc.id,
            ...data,
            'hasWarnings': hasWarnings,
            'hasPenalties': hasPenalties,
            'timestampFormatted':
                data['timestamp'] != null && data['timestamp'] is Timestamp
                    ? (data['timestamp'] as Timestamp).toDate().toString()
                    : 'Unknown',
          });
        }
      }

      setState(() {
        _penaltyScans = penaltyScans;
        _filteredPenaltyScans = penaltyScans;
        _isLoading = false;
      });

      // Calculate statistics
      _calculateStatistics();

      // Apply initial date filter
      _applyDateFilter();
    } catch (e) {
      print('Error fetching penalty scans: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyDateFilter() {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    if (_selectedTimeFilter == 'Select Month' && _selectedMonth != null) {
      final dt = DateFormat('MMM yyyy').parse(_selectedMonth!);
      startDate = DateTime(dt.year, dt.month, 1);
      endDate = DateTime(dt.year, dt.month + 1, 0, 23, 59, 59);
    } else {
      switch (_selectedTimeFilter) {
        case 'This Week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        case 'This Year':
          startDate = DateTime(now.year, 1, 1);
          endDate = DateTime(now.year, 12, 31, 23, 59, 59);
          break;
        case 'All Time':
          _filteredPenaltyScans = _penaltyScans;
          _applySearchAndTypeFilter();
          return;
        default:
          startDate = now.subtract(Duration(days: now.weekday - 1));
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      }
    }

    _dateFilteredPenaltyScans = _penaltyScans.where((scan) {
      if (scan['timestamp'] == null) return false;
      final DateTime scanDate = (scan['timestamp'] as Timestamp).toDate();
      return scanDate.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
          scanDate.isBefore(endDate.add(const Duration(seconds: 1)));
    }).toList();

    _applySearchAndTypeFilter();
  }

  void _applySearchAndTypeFilter() {
    // Always start from the date-filtered list so search updates correctly
    List<Map<String, dynamic>> filtered = _selectedTimeFilter == 'All Time'
        ? List<Map<String, dynamic>>.from(_penaltyScans)
        : List<Map<String, dynamic>>.from(_dateFilteredPenaltyScans);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((scan) {
        String residentName =
            (scan['residentName'] ?? '').toString().toLowerCase();
        String collectorName =
            (scan['collectorName'] ?? '').toString().toLowerCase();
        String garbageType =
            (scan['garbageType'] ?? '').toString().toLowerCase();

        return residentName.contains(_searchQuery.toLowerCase()) ||
            collectorName.contains(_searchQuery.toLowerCase()) ||
            garbageType.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Removed type filter dropdown; quick filters below handle this

    // Apply quick toggle filters
    filtered = filtered.where((scan) {
      final bool hasW = scan['hasWarnings'] == true;
      final bool hasP = scan['hasPenalties'] == true;
      if (!_showWarnings && hasW) return false;
      if (!_showPenalties && hasP) return false;
      return true;
    }).toList();

    // Apply sorting
    filtered = _sortScans(filtered);

    setState(() {
      _filteredPenaltyScans = filtered;
    });

    // Recalculate statistics based on filtered results
    _calculateStatistics(filtered);
  }

  void _calculateStatistics([List<Map<String, dynamic>>? scansToAnalyze]) {
    final scans = scansToAnalyze ?? _penaltyScans;
    _totalScans = scans.length;
    _totalWarnings = scans.where((scan) => scan['hasWarnings'] == true).length;
    _totalPenalties =
        scans.where((scan) => scan['hasPenalties'] == true).length;
  }

  void _exportPenaltyData() {
    // For now, just show a snackbar indicating export functionality
    // In a real implementation, you could export to CSV or PDF
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export functionality coming soon!'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  List<Map<String, dynamic>> _sortScans(List<Map<String, dynamic>> scans) {
    switch (_selectedSortOption) {
      case 'Latest':
        scans.sort((a, b) {
          if (a['timestamp'] == null || b['timestamp'] == null) return 0;
          return (b['timestamp'] as Timestamp)
              .compareTo(a['timestamp'] as Timestamp);
        });
        break;
      case 'Oldest':
        scans.sort((a, b) {
          if (a['timestamp'] == null || b['timestamp'] == null) return 0;
          return (a['timestamp'] as Timestamp)
              .compareTo(b['timestamp'] as Timestamp);
        });
        break;
      case 'Resident Name (A-Z)':
        scans.sort((a, b) {
          String nameA = (a['residentName'] ?? '').toString().toLowerCase();
          String nameB = (b['residentName'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);
        });
        break;
      case 'Resident Name (Z-A)':
        scans.sort((a, b) {
          String nameA = (a['residentName'] ?? '').toString().toLowerCase();
          String nameB = (b['residentName'] ?? '').toString().toLowerCase();
          return nameB.compareTo(nameA);
        });
        break;
      case 'Collector Name (A-Z)':
        scans.sort((a, b) {
          String nameA = (a['collectorName'] ?? '').toString().toLowerCase();
          String nameB = (b['collectorName'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);
        });
        break;
      case 'Collector Name (Z-A)':
        scans.sort((a, b) {
          String nameA = (a['collectorName'] ?? '').toString().toLowerCase();
          String nameB = (b['collectorName'] ?? '').toString().toLowerCase();
          return nameB.compareTo(nameA);
        });
        break;
    }
    return scans;
  }

  void _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 7)),
              end: DateTime.now(),
            ),
    );

    if (picked != null) {
      setState(() {
        _selectedTimeFilter = 'Select Month';
        _selectedMonth = DateFormat('MMM yyyy').format(picked.start);
      });
      _applyDateFilter();
    }
  }

  Widget _buildFilterChip(
      String label, bool value, Function(bool?) onChanged, Color color) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: value ? color : Colors.grey.shade700,
        fontWeight: value ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(
        color: value ? color : Colors.grey.shade400,
        width: value ? 2 : 1,
      ),
    );
  }

  Widget _buildScanCard(Map<String, dynamic> scan) {
    // Determine if warnings/penalties exist (derived from lists below)
    final DateTime scanDate = scan['timestamp'] != null
        ? (scan['timestamp'] as Timestamp).toDate()
        : DateTime.now();

    // Collect warning and penalty detail labels
    List<String> warnings = [];
    List<String> penalties = [];

    if (scan['warnings'] != null && scan['warnings'] is Map) {
      final Map<String, dynamic> warningsData =
          scan['warnings'] as Map<String, dynamic>;
      if (warningsData['failedToContribute'] == true) {
        warnings.add('Failed to Contribute');
      }
    }

    if (scan['penalties'] != null && scan['penalties'] is Map) {
      final Map<String, dynamic> penaltiesData =
          scan['penalties'] as Map<String, dynamic>;
      if (penaltiesData['notSegregated'] == true) {
        penalties.add('Not Segregated');
      }
      if (penaltiesData['noContributions'] == true) {
        penalties.add('No Contributions');
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Name and date
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scan['residentName'] ?? 'Unknown Resident',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scanned by: ${scan['collectorName'] ?? 'Unknown'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('MMM dd, yyyy').format(scanDate),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm').format(scanDate),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Location
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${scan['purok'] ?? ''}, ${scan['barangay'] ?? ''}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 12),

            // Warning and penalty types
            if (warnings.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: Colors.orange.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'Warnings',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: warnings
                    .map((warning) => Chip(
                          label: Text(warning),
                          backgroundColor: Colors.orange.shade600,
                          side: BorderSide(color: Colors.orange.shade600),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],
            if (penalties.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.block, size: 18, color: Colors.red.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'Penalties',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: penalties
                    .map((penalty) => Chip(
                          label: Text(penalty),
                          backgroundColor: Colors.red.shade600,
                          side: BorderSide(color: Colors.red.shade600),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
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
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and description (announcement-style)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Penalty List',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Review and manage warnings and penalties for your barangay',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          // Filter section
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Removed large search bar
                const SizedBox(height: 12),

                // Top controls row: quick filters (left) + time period and search (right)
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Quick filters on the left
                    Row(
                      children: [
                        Text(
                          'Quick Filters:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Warnings'),
                          selected: _showWarnings,
                          onSelected: (val) {
                            setState(() => _showWarnings = val);
                            _applySearchAndTypeFilter();
                          },
                          selectedColor: Colors.orange.shade600,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: _showWarnings ? Colors.white : Colors.orange,
                            fontWeight: _showWarnings
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.orange.shade300),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Penalties'),
                          selected: _showPenalties,
                          onSelected: (val) {
                            setState(() => _showPenalties = val);
                            _applySearchAndTypeFilter();
                          },
                          selectedColor: Colors.red.shade600,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: _showPenalties ? Colors.white : Colors.red,
                            fontWeight: _showPenalties
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.red.shade300),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Time period control (analytics-style)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month,
                              color: const Color(0xFF4CAF50), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Time Period',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(width: 24),
                          DropdownButton<String>(
                            value: _selectedTimeFilter,
                            items: _timeFilters.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) async {
                              if (newValue == null) return;
                              if (newValue == 'Select Month') {
                                final now = DateTime.now();
                                DateTime? picked = await showDialog<DateTime>(
                                  context: context,
                                  builder: (context) {
                                    int selectedYear = now.year;
                                    int selectedMonth = now.month;
                                    return StatefulBuilder(
                                      builder: (context, setStateDialog) {
                                        return AlertDialog(
                                          title: const Text('Select Month'),
                                          content: SizedBox(
                                            height: 120,
                                            child: Column(
                                              children: [
                                                DropdownButton<int>(
                                                  value: selectedMonth,
                                                  items: List.generate(
                                                          12, (i) => i + 1)
                                                      .map((month) =>
                                                          DropdownMenuItem(
                                                            value: month,
                                                            child: Text(DateFormat(
                                                                    'MMMM')
                                                                .format(DateTime(
                                                                    0, month))),
                                                          ))
                                                      .toList(),
                                                  onChanged: (int? month) {
                                                    if (month != null) {
                                                      setStateDialog(() {
                                                        selectedMonth = month;
                                                      });
                                                    }
                                                  },
                                                ),
                                                DropdownButton<int>(
                                                  value: selectedYear,
                                                  items: List.generate(
                                                          10,
                                                          (i) =>
                                                              now.year - 5 + i)
                                                      .map((year) =>
                                                          DropdownMenuItem(
                                                            value: year,
                                                            child: Text(year
                                                                .toString()),
                                                          ))
                                                      .toList(),
                                                  onChanged: (int? year) {
                                                    if (year != null) {
                                                      setStateDialog(() {
                                                        selectedYear = year;
                                                      });
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop(
                                                    DateTime(selectedYear,
                                                        selectedMonth));
                                              },
                                              child: const Text('OK'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setState(() {
                                    _selectedTimeFilter = 'Select Month';
                                    _selectedMonth =
                                        DateFormat('MMM yyyy').format(picked);
                                  });
                                  _applyDateFilter();
                                }
                              } else {
                                setState(() {
                                  _selectedTimeFilter = newValue;
                                  _selectedMonth = null;
                                });
                                _applyDateFilter();
                              }
                            },
                            underline: const SizedBox(),
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Color(0xFF4CAF50)),
                            dropdownColor: Colors.white,
                            isDense: true,
                          ),
                          if (_selectedTimeFilter == 'Select Month' &&
                              _selectedMonth != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF4CAF50).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_month,
                                      color: Color(0xFF4CAF50), size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    _selectedMonth!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF4CAF50),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Compact search beside time period (right-aligned)
                    Container(
                      width: 250,
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                                    icon: const Icon(Icons.clear, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                      _applySearchAndTypeFilter();
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
                            _applySearchAndTypeFilter();
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // Remove custom range UI (handled by Select Month dialog)
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Statistics section (schedule-style)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.assignment,
                              color: Colors.blue, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _totalScans.toString(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            Text(
                              'Total Scans',
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
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.warning,
                              color: Colors.orange, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _totalWarnings.toString(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            Text(
                              'Warnings',
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
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.block, color: Colors.red, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _totalPenalties.toString(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            Text(
                              'Penalties',
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
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Results count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  '${_filteredPenaltyScans.length} scans found',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (_filteredPenaltyScans.isNotEmpty)
                  Text(
                    'Total: ${_penaltyScans.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Color.fromARGB(255, 3, 144, 123),
                        ),
                        SizedBox(height: 16),
                        Text('Loading penalty scans...'),
                      ],
                    ),
                  )
                : _filteredPenaltyScans.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.warning_amber_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No penalty scans found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your filters or date range',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _filteredPenaltyScans.length,
                        itemBuilder: (context, index) {
                          return _buildScanCard(_filteredPenaltyScans[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
