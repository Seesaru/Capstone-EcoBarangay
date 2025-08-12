import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/pdf_service.dart';
import 'dart:typed_data';
import 'package:flutter/rendering.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String _adminBarangay = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  StreamSubscription<QuerySnapshot>? _scansSubscription;

  // Analytics data
  Map<String, double> _wasteTypeData = {};
  Map<String, double> _monthlyCollectionData = {};
  Map<String, double> _purokCollectionData = {};
  List<Map<String, dynamic>> _recentCollections = [];
  double _totalWasteCollected = 0;
  int _totalCollections = 0;

  // Time filter
  String _selectedTimeFilter = 'This Month';
  final List<String> _timeFilters = [
    'This Week',
    'This Month',
    'This Year',
    'All Time'
  ];

  // Color scheme
  final Color primaryColor = const Color(0xFF2E7D32);
  final Color secondaryColor = const Color(0xFF1976D2);
  final Color accentColor = const Color(0xFFFF9800);
  final Color backgroundColor = const Color(0xFFF5F7FA);
  final Color cardColor = Colors.white;
  final Color textPrimaryColor = const Color(0xFF1A1A1A);
  final Color textSecondaryColor = const Color(0xFF666666);

  // Modern chart colors
  final List<Color> _modernColors = const [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFF9800),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF3F51B5),
    Color(0xFF00BCD4),
    Color(0xFFFFEB3B),
  ];

  // Add a new class variable to store monthly scan counts
  Map<String, int> _monthlyScansCount = {};

  // Add a new class variable to store daily scan counts
  Map<String, int> _dailyScansCount = {};

  // Add these GlobalKeys to capture widget images
  final GlobalKey _wasteTypeChartKey = GlobalKey();
  final GlobalKey _purokDistributionChartKey = GlobalKey();
  final GlobalKey _monthlyCollectionChartKey = GlobalKey();
  final GlobalKey _residentScansChartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _fetchAdminBarangay();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scansSubscription?.cancel();
    super.dispose();
  }

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
          _setupScansListener();
          _animationController.forward();
        }
      }
    } catch (e) {
      print('Error fetching admin barangay: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupScansListener() {
    // Cancel any existing subscription
    _scansSubscription?.cancel();

    // Get date range based on selected time filter
    DateTime startDate = _getStartDate(_selectedTimeFilter);

    // Create a listener for real-time updates
    _scansSubscription = _firestore
        .collection('scans')
        .where('barangay', isEqualTo: _adminBarangay)
        .where('timestamp', isGreaterThanOrEqualTo: startDate)
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      _processScansData(snapshot);
    }, onError: (error) {
      print('Error listening to scans: $error');
      setState(() {
        _isLoading = false;
      });
    });
  }

  void _processScansData(QuerySnapshot scansSnapshot) {
    try {
      // Reset data with standardized waste types
      _wasteTypeData = {
        'Biodegradable': 0.0,
        'Non-Biodegradable': 0.0,
        'Recyclables': 0.0,
        'General Waste': 0.0,
      };
      _monthlyCollectionData = {};
      _purokCollectionData = {};
      _monthlyScansCount = {}; // Reset monthly scan counts
      _dailyScansCount = {}; // Reset daily scan counts
      _totalWasteCollected = 0;
      _totalCollections = 0;
      _recentCollections = [];

      // We don't need to collect unique waste types anymore since we have fixed categories
      _wasteTypeData = {
        'Biodegradable': 0.0,
        'Non-Biodegradable': 0.0,
        'Recyclables': 0.0,
        'General Waste': 0.0,
      };

      // Process scan data
      for (var doc in scansSnapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          // Skip if no timestamp
          if (data['timestamp'] == null) continue;

          DateTime scanDate = (data['timestamp'] as Timestamp).toDate();
          String rawWasteType = data['garbageType'] ?? 'General Waste';
          double weight = (data['garbageWeight'] ?? 0).toDouble();
          String purok = data['purok'] ?? 'Unknown';

          // Map the raw waste type to one of our standardized categories
          String standardizedWasteType = _standardizeWasteType(rawWasteType);

          // Update waste type data using standardized category
          _wasteTypeData[standardizedWasteType] =
              (_wasteTypeData[standardizedWasteType] ?? 0.0) + weight;

          // Update monthly data
          String monthKey = DateFormat('MMM yyyy').format(scanDate);
          _monthlyCollectionData[monthKey] =
              (_monthlyCollectionData[monthKey] ?? 0.0) + weight;

          // Update daily data
          String dayKey = DateFormat('MMM d, yyyy').format(scanDate);
          _dailyScansCount[dayKey] = (_dailyScansCount[dayKey] ?? 0) + 1;

          // Update monthly scan counts - count each document as one scan
          _monthlyScansCount[monthKey] =
              (_monthlyScansCount[monthKey] ?? 0) + 1;

          // Update purok data
          _purokCollectionData[purok] =
              (_purokCollectionData[purok] ?? 0.0) + weight;

          // Update totals
          _totalWasteCollected += weight;
          _totalCollections++;

          // Add to recent collections
          _recentCollections.add({
            'date': scanDate,
            'wasteType': standardizedWasteType,
            'weight': weight,
            'purok': purok,
            'residentName': data['residentName'] ?? 'Unknown',
          });
        } catch (e) {
          print('Error processing scan document: $e');
          continue; // Skip this document if there's an error
        }
      }

      // Sort recent collections by date
      _recentCollections.sort((a, b) => b['date'].compareTo(a['date']));
      _recentCollections = _recentCollections.take(5).toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error processing scans data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
    });

    // Update the listener with the new time filter
    _setupScansListener();
  }

  DateTime _getStartDate(String timeFilter) {
    final now = DateTime.now();
    switch (timeFilter) {
      case 'This Week':
        return now.subtract(Duration(days: now.weekday - 1));
      case 'This Month':
        return DateTime(now.year, now.month, 1);
      case 'This Year':
        return DateTime(now.year, 1, 1);
      case 'All Time':
        return DateTime(2000); // A long time ago
      default:
        return DateTime(now.year, now.month, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: backgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: primaryColor,
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              Text(
                'Loading Analytics...',
                style: TextStyle(
                  fontSize: 16,
                  color: textSecondaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: backgroundColor,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTimeFilter(),
                  ElevatedButton.icon(
                    onPressed: _generateAnalyticsReport,
                    icon: const Icon(Icons.download),
                    label: const Text('Download Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildOverviewCards(),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: RepaintBoundary(
                      key: _wasteTypeChartKey,
                      child: _buildWasteTypeChart(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: RepaintBoundary(
                      key: _purokDistributionChartKey,
                      child: _buildPurokDistributionChart(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: RepaintBoundary(
                      key: _monthlyCollectionChartKey,
                      child: _buildMonthlyCollectionChart(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: RepaintBoundary(
                      key: _residentScansChartKey,
                      child: _buildResidentScansLineGraph(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildRecentCollections(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Waste Collection Analytics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.white.withOpacity(0.9),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _adminBarangay,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildHeaderButton(
                icon: Icons.refresh,
                label: 'Refresh',
                onPressed: _loadAnalyticsData,
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Colors.white.withOpacity(0.9),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM d, yyyy').format(DateTime.now()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: Colors.white.withOpacity(0.9),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeFilter() {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month,
                  color: primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Time Period',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedTimeFilter,
                items: _timeFilters.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textPrimaryColor,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null && newValue != _selectedTimeFilter) {
                    setState(() {
                      _selectedTimeFilter = newValue;
                    });
                    _loadAnalyticsData();
                  }
                },
                underline: const SizedBox(),
                icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                dropdownColor: cardColor,
                focusColor: Colors.transparent,
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.8,
      children: [
        _buildOverviewCard(
          'Total Waste Collected',
          '${_totalWasteCollected.toStringAsFixed(1)} kg',
          Icons.delete_outline,
          primaryColor,
        ),
        _buildOverviewCard(
          'Total Collections',
          _totalCollections.toString(),
          Icons.calendar_today,
          secondaryColor,
        ),
        _buildOverviewCard(
          'Average per Collection',
          '${(_totalWasteCollected / (_totalCollections == 0 ? 1 : _totalCollections)).toStringAsFixed(1)} kg',
          Icons.analytics,
          accentColor,
        ),
      ],
    );
  }

  Widget _buildOverviewCard(
      String title, String value, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title details'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWasteTypeChart() {
    // Sort waste types and create a list of entries for consistent ordering
    final sortedWasteEntries = _wasteTypeData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Sort by value descending

    return Container(
      padding: const EdgeInsets.all(16),
      height: 400,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Waste Type Distribution',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_totalWasteCollected.toStringAsFixed(1)} kg total',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _loadAnalyticsData,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: secondaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.refresh,
                        color: secondaryColor,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: sortedWasteEntries.isEmpty ||
                    sortedWasteEntries.every((entry) => entry.value == 0)
                ? Center(
                    child: Text(
                      'No waste data available for the selected period',
                      style: TextStyle(
                        fontSize: 16,
                        color: textSecondaryColor,
                      ),
                    ),
                  )
                : AnimatedOpacity(
                    opacity: _isLoading ? 0.3 : 1.0,
                    duration: const Duration(milliseconds: 500),
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (sortedWasteEntries.first.value * 1.2).toDouble(),
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            tooltipBgColor: Colors.grey.shade800,
                            tooltipRoundedRadius: 8,
                            tooltipPadding: const EdgeInsets.all(12),
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              if (groupIndex >= sortedWasteEntries.length)
                                return null;
                              final entry = sortedWasteEntries[groupIndex];
                              return BarTooltipItem(
                                '${entry.key}\n${entry.value.toStringAsFixed(1)} kg',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= sortedWasteEntries.length)
                                  return const Text('');
                                final entry = sortedWasteEntries[value.toInt()];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${value.toInt()}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.withOpacity(0.15),
                              strokeWidth: 1,
                              dashArray: [6, 4],
                            );
                          },
                        ),
                        barGroups:
                            List.generate(sortedWasteEntries.length, (index) {
                          final entry = sortedWasteEntries[index];
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value,
                                color: _getWasteTypeColor(entry.key),
                                width: 24,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(6),
                                  topRight: Radius.circular(6),
                                ),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: (sortedWasteEntries.first.value * 1.2)
                                      .toDouble(),
                                  color: Colors.grey.withOpacity(0.05),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResidentScansLineGraph() {
    // Create data for resident scans per day based on ACTUAL scan counts
    final scanData = <FlSpot>[];

    // Get the date range based on the selected time filter
    DateTime startDate = _getStartDate(_selectedTimeFilter);
    DateTime endDate = DateTime.now();

    // Filter to only days with actual scan data
    List<MapEntry<String, int>> filteredScans =
        _dailyScansCount.entries.where((entry) => entry.value > 0).toList();

    // Sort the filtered scans by date
    filteredScans.sort((a, b) {
      DateTime dateA = DateFormat('MMM d, yyyy').parse(a.key);
      DateTime dateB = DateFormat('MMM d, yyyy').parse(b.key);
      return dateA.compareTo(dateB);
    });

    // Create spots only for days with actual scans
    for (int i = 0; i < filteredScans.length; i++) {
      final scans = filteredScans[i].value;
      scanData.add(FlSpot(i.toDouble(), scans.toDouble()));
    }

    // Format day labels for the x-axis - only for days with scans
    final dayLabels = filteredScans
        .map((entry) => DateFormat('MMM d')
            .format(DateFormat('MMM d, yyyy').parse(entry.key)))
        .toList();

    // Get total scans for display
    int totalScans =
        _dailyScansCount.values.fold(0, (sum, count) => sum + count);

    return Container(
      padding: const EdgeInsets.all(16),
      height: 400, // Fixed height to match other charts
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daily Resident Scans',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 14,
                      color: accentColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Total: $totalScans',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: scanData.isEmpty
                ? Center(
                    child: Text(
                      'No data available for the selected period',
                      style: TextStyle(
                        fontSize: 16,
                        color: textSecondaryColor,
                      ),
                    ),
                  )
                : CustomPaint(
                    size: Size(double.infinity, double.infinity),
                    painter: AnalyticsLineChartPainter(
                      data: scanData,
                      labels: dayLabels,
                      maxValue: scanData.isEmpty
                          ? 10
                          : (scanData
                                  .map((spot) => spot.y)
                                  .reduce((a, b) => a > b ? a : b) *
                              1.2),
                      lineColor: accentColor,
                      showTooltip: true,
                      tooltipUnit: 'scans',
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyCollectionChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 400, // Fixed height to match other charts
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Monthly Collection Trends',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.date_range,
                          size: 14,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedTimeFilter,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _loadAnalyticsData,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: secondaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.refresh,
                        color: secondaryColor,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _monthlyCollectionData.isEmpty
                ? Center(
                    child: Text(
                      'No monthly data available for the selected period',
                      style: TextStyle(
                        fontSize: 16,
                        color: textSecondaryColor,
                      ),
                    ),
                  )
                : AnimatedOpacity(
                    opacity: _isLoading ? 0.3 : 1.0,
                    duration: const Duration(milliseconds: 500),
                    child: LineChart(
                      LineChartData(
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            tooltipBgColor: Colors.grey.shade800,
                            tooltipRoundedRadius: 10,
                            tooltipPadding: const EdgeInsets.all(12),
                            tooltipMargin: 8,
                            getTooltipItems: (List<LineBarSpot> touchedSpots) {
                              return touchedSpots.map((spot) {
                                final monthIndex = spot.x.toInt();
                                final months =
                                    _monthlyCollectionData.keys.toList()
                                      ..sort((a, b) {
                                        // Sort months chronologically
                                        DateTime dateA =
                                            DateFormat('MMM yyyy').parse(a);
                                        DateTime dateB =
                                            DateFormat('MMM yyyy').parse(b);
                                        return dateA.compareTo(dateB);
                                      });
                                if (monthIndex >= 0 &&
                                    monthIndex < months.length) {
                                  return LineTooltipItem(
                                    '${months[monthIndex]}',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    children: [
                                      TextSpan(
                                        text:
                                            '\n${spot.y.toStringAsFixed(1)} kg',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontWeight: FontWeight.normal,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return LineTooltipItem('', const TextStyle());
                              }).toList();
                            },
                          ),
                          handleBuiltInTouches: true,
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.withOpacity(0.15),
                              strokeWidth: 1,
                              dashArray: [6, 4],
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                // Sort months chronologically
                                final sortedMonths =
                                    _monthlyCollectionData.keys.toList()
                                      ..sort((a, b) {
                                        DateTime dateA =
                                            DateFormat('MMM yyyy').parse(a);
                                        DateTime dateB =
                                            DateFormat('MMM yyyy').parse(b);
                                        return dateA.compareTo(dateB);
                                      });

                                if (value.toInt() >= sortedMonths.length) {
                                  return const Text('');
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    sortedMonths[value.toInt()],
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${value.toInt()}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.withOpacity(0.2),
                              width: 1,
                            ),
                            left: BorderSide(
                              color: Colors.grey.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: () {
                              // Sort months chronologically
                              final sortedMonths =
                                  _monthlyCollectionData.keys.toList()
                                    ..sort((a, b) {
                                      DateTime dateA =
                                          DateFormat('MMM yyyy').parse(a);
                                      DateTime dateB =
                                          DateFormat('MMM yyyy').parse(b);
                                      return dateA.compareTo(dateB);
                                    });

                              // Create spots with sorted months
                              return sortedMonths
                                  .map((month) => FlSpot(
                                      sortedMonths.indexOf(month).toDouble(),
                                      _monthlyCollectionData[month] ?? 0))
                                  .toList();
                            }(),
                            isCurved: true,
                            curveSmoothness: 0.4,
                            color: primaryColor,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 5,
                                  color: primaryColor,
                                  strokeWidth: 3,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor.withOpacity(0.5),
                                  primaryColor.withOpacity(0.2),
                                  primaryColor.withOpacity(0.05),
                                ],
                                stops: const [0.1, 0.5, 0.9],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            shadow: Shadow(
                              blurRadius: 8,
                              color: primaryColor.withOpacity(0.3),
                              offset: const Offset(0, 4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurokDistributionChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 400,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Collection by Purok',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_purokCollectionData.length} Puroks',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _purokCollectionData.isEmpty
                ? Center(
                    child: Text(
                      'No purok data available for the selected period',
                      style: TextStyle(
                        fontSize: 16,
                        color: textSecondaryColor,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                sections:
                                    _purokCollectionData.entries.map((entry) {
                                  final index = _purokCollectionData.keys
                                      .toList()
                                      .indexOf(entry.key);
                                  final color = _modernColors[
                                      index % _modernColors.length];

                                  // Calculate percentage for this purok
                                  final percentage = (entry.value /
                                      _totalWasteCollected *
                                      100);

                                  // Always show labels for our standardized categories
                                  final shouldShowLabel = true;

                                  return PieChartSectionData(
                                    value: entry.value,
                                    title: shouldShowLabel
                                        ? '${percentage.toInt()}%'
                                        : '',
                                    color: color,
                                    radius: 100,
                                    titleStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    titlePositionPercentageOffset: 0.6,
                                    badgeWidget: null,
                                    badgePositionPercentageOffset: 0,
                                  );
                                }).toList(),
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                startDegreeOffset: -90,
                                pieTouchData: PieTouchData(
                                  touchCallback:
                                      (FlTouchEvent event, pieTouchResponse) {
                                    // We could implement touch response here if needed
                                  },
                                  enabled: true,
                                ),
                              ),
                            ),
                            // Center info
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_totalWasteCollected.toStringAsFixed(1)} kg',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        flex: 2,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _purokCollectionData.length,
                          itemBuilder: (context, index) {
                            final entries = _purokCollectionData.entries
                                .toList()
                              ..sort((a, b) => b.value.compareTo(
                                  a.value)); // Sort by value descending

                            final entry = entries[index];
                            final color = _modernColors[_purokCollectionData
                                    .keys
                                    .toList()
                                    .indexOf(entry.key) %
                                _modernColors.length];
                            final percentage =
                                (entry.value / _totalWasteCollected * 100)
                                    .toStringAsFixed(1);
                            final weight = entry.value.toStringAsFixed(1);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              height: 36,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Purok name
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      entry.key,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                  // Percentage
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '$percentage%',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                  // Weight
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '$weight kg',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: textSecondaryColor,
                                      ),
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
        ],
      ),
    );
  }

  Widget _buildRecentCollections() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.history,
                    color: primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Collections',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                ],
              ),
              Text(
                '${_recentCollections.length} Collections',
                style: TextStyle(
                  fontSize: 14,
                  color: textSecondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            constraints:
                const BoxConstraints(maxHeight: 300), // Set maximum height
            child: ListView.builder(
              shrinkWrap: true,
              physics:
                  const AlwaysScrollableScrollPhysics(), // Make it scrollable
              itemCount: _recentCollections.length,
              itemBuilder: (context, index) {
                final collection = _recentCollections[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getWasteTypeColor(collection['wasteType'])
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getWasteTypeIcon(collection['wasteType']),
                          color: _getWasteTypeColor(collection['wasteType']),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              collection['residentName'],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${collection['purok']} • ${DateFormat('MMM d, yyyy').format(collection['date'])}',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getWasteTypeColor(collection['wasteType'])
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${collection['weight'].toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _getWasteTypeColor(collection['wasteType']),
                          ),
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
    );
  }

  Color _getRandomColor(String seed) {
    return _modernColors[seed.hashCode % _modernColors.length];
  }

  Color _getWasteTypeColor(String wasteType) {
    switch (wasteType) {
      case 'Biodegradable':
        return Colors.green;
      case 'Non-Biodegradable':
        return Colors.orange;
      case 'Recyclables':
        return Colors.teal;
      case 'General Waste':
        return Colors.blue;
      default:
        // Map any legacy or different labels to the closest standardized category color
        final lowerCase = wasteType.toLowerCase();
        if (lowerCase.contains('bio')) return Colors.green;
        if (lowerCase.contains('non') || lowerCase.contains('non-bio'))
          return Colors.orange;
        if (lowerCase.contains('recycl')) return Colors.teal;
        return Colors.blue; // Default to General Waste color
    }
  }

  IconData _getWasteTypeIcon(String wasteType) {
    switch (wasteType) {
      case 'Biodegradable':
        return Icons.compost;
      case 'Non-Biodegradable':
        return Icons.delete;
      case 'Recyclables':
        return Icons.recycling;
      case 'General Waste':
        return Icons.delete_sweep;
      default:
        // Map any legacy or different labels to the closest standardized category icon
        final lowerCase = wasteType.toLowerCase();
        if (lowerCase.contains('bio')) return Icons.compost;
        if (lowerCase.contains('non') || lowerCase.contains('non-bio'))
          return Icons.delete;
        if (lowerCase.contains('recycl')) return Icons.recycling;
        return Icons.delete_sweep; // Default to General Waste icon
    }
  }

  String _standardizeWasteType(String rawWasteType) {
    final lowerCase = rawWasteType.toLowerCase();
    if (lowerCase.contains('bio') && !lowerCase.contains('non'))
      return 'Biodegradable';
    if (lowerCase.contains('non') || lowerCase.contains('non-bio'))
      return 'Non-Biodegradable';
    if (lowerCase.contains('recycl')) return 'Recyclables';
    return 'General Waste';
  }

  Future<void> _generateAnalyticsReport() async {
    try {
      // Show loading dialog instead of setting state
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  const SizedBox(width: 20),
                  const Text('Generating report...'),
                ],
              ),
            ),
          );
        },
      );

      // Create a PDF document
      final pdf = pw.Document();

      // Add title page with summary
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'Waste Collection Analytics Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Report Details',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('Barangay: $_adminBarangay'),
                      pw.Text('Period: $_selectedTimeFilter'),
                      pw.Text(
                          'Generated on: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}'),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Summary Statistics',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildPdfSummaryTable(),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Waste Type Distribution',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildPdfWasteTypeTable(),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Collection by Purok',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildPdfPurokTable(),
              ],
            );
          },
        ),
      );

      // Add monthly trends page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'Monthly Collection Trends',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildPdfMonthlyCollectionTable(),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Recent Collections',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildPdfRecentCollectionsTable(),
              ],
            );
          },
        ),
      );

      // Generate and download the PDF
      await _generateAndDownloadAnalyticsPDF();
    } catch (e) {
      // Close the loading dialog if there's an error
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate report: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<Uint8List?> _captureWidget(GlobalKey key) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error capturing widget: $e');
      return null;
    }
  }

  pw.Widget _buildPdfSummaryTable() {
    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Metric',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Value',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Total Waste Collected'),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('${_totalWasteCollected.toStringAsFixed(1)} kg'),
            ),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Total Collections'),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('$_totalCollections'),
            ),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Average per Collection'),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                '${(_totalWasteCollected / (_totalCollections == 0 ? 1 : _totalCollections)).toStringAsFixed(1)} kg',
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfRecentCollectionsTable() {
    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Date',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Resident',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Purok',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Waste Type',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Weight',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
        ..._recentCollections.map((collection) => pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    DateFormat('MMM d, yyyy').format(collection['date']),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(collection['residentName']),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(collection['purok']),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(collection['wasteType']),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child:
                      pw.Text('${collection['weight'].toStringAsFixed(1)} kg'),
                ),
              ],
            )),
      ],
    );
  }

  pw.Widget _buildPdfWasteTypeTable() {
    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Waste Type',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Amount (kg)',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
        ..._wasteTypeData.entries
            .map((entry) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(entry.key),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(entry.value.toStringAsFixed(1)),
                    ),
                  ],
                ))
            .toList(),
      ],
    );
  }

  pw.Widget _buildPdfPurokTable() {
    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Purok',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Amount (kg)',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
        ..._purokCollectionData.entries
            .map((entry) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(entry.key),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(entry.value.toStringAsFixed(1)),
                    ),
                  ],
                ))
            .toList(),
      ],
    );
  }

  pw.Widget _buildPdfMonthlyCollectionTable() {
    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Month',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Amount (kg)',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
        ..._monthlyCollectionData.entries
            .map((entry) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(entry.key),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(entry.value.toStringAsFixed(1)),
                    ),
                  ],
                ))
            .toList(),
      ],
    );
  }

  Future<void> _generateAndDownloadAnalyticsPDF() async {
    try {
      // Create a new PDF document
      final pdf = pw.Document();

      // Add first page with summary
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Report Details',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('Barangay: $_adminBarangay'),
                      pw.Text('Period: $_selectedTimeFilter'),
                      pw.Text(
                          'Generated on: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}'),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Summary Statistics',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildPdfSummaryTable(),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Waste Type Distribution',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildPdfWasteTypeTable(),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Collection by Purok',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildPdfPurokTable(),
              ],
            );
          },
        ),
      );

      // Add monthly trends page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'Monthly Collection Trends',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildPdfMonthlyCollectionTable(),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Recent Collections',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildPdfRecentCollectionsTable(),
              ],
            );
          },
        ),
      );

      // Generate the PDF bytes
      final bytes = await pdf.save();

      if (kIsWeb) {
        await PdfService.downloadPdf(
          bytes,
          "analytics_report_${DateTime.now().toString().split('.')[0].replaceAll(':', '-')}.pdf",
        );
      } else {
        // For mobile, show a message that this feature is web-only
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF download is only available on the web version'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      Navigator.of(context).pop(); // Close loading dialog
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Custom painter for line charts that matches the dashboard design
class AnalyticsLineChartPainter extends CustomPainter {
  final List<FlSpot> data;
  final List<String> labels;
  final double maxValue;
  final Color lineColor;
  final bool showTooltip;
  final String tooltipUnit;

  AnalyticsLineChartPainter({
    required this.data,
    required this.labels,
    required this.maxValue,
    required this.lineColor,
    this.showTooltip = false,
    this.tooltipUnit = '',
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final Paint linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          lineColor.withOpacity(0.5),
          lineColor.withOpacity(0.2),
          lineColor.withOpacity(0.05),
        ],
        stops: const [0.1, 0.5, 0.9],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Paint pointStrokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final Paint pointFillPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final Paint gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final textStyle = TextStyle(
      color: Colors.grey[600],
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    final TextPainter textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );

    // Draw horizontal grid lines with dashed pattern
    for (int i = 0; i <= 5; i++) {
      double y = size.height - (i * size.height / 5);

      // Draw dashed line
      double dashWidth = 5, dashSpace = 5, startX = 0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, y),
          Offset(startX + dashWidth, y),
          gridPaint,
        );
        startX += dashWidth + dashSpace;
      }

      // Draw y-axis labels
      textPainter.text = TextSpan(
        text: (i * maxValue / 5).toStringAsFixed(0),
        style: textStyle,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width - 5, y - textPainter.height / 2),
      );
    }

    // Create path for the line and fill
    final Path path = Path();
    final Path fillPath = Path();

    // Use a smoother curve by adding control points
    List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      final x = i * (size.width / (data.length > 1 ? data.length - 1 : 1));
      final y = size.height - (data[i].y / maxValue * size.height);
      points.add(Offset(x, y));
    }

    // Start paths
    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);
      fillPath.moveTo(points[0].dx, size.height);
      fillPath.lineTo(points[0].dx, points[0].dy);
    }

    // Special case for single data point
    if (points.length == 1) {
      // Draw a horizontal line for a single point
      path.lineTo(size.width, points[0].dy);
      fillPath.lineTo(size.width, points[0].dy);
      fillPath.lineTo(size.width, size.height);
      fillPath.close();
    } else {
      // Add curved segments for multiple points
      for (int i = 0; i < points.length - 1; i++) {
        final current = points[i];
        final next = points[i + 1];

        // Calculate control points for a smoother curve
        final controlPointX = current.dx + (next.dx - current.dx) / 2;

        path.cubicTo(controlPointX, current.dy, controlPointX, next.dy, next.dx,
            next.dy);

        fillPath.cubicTo(controlPointX, current.dy, controlPointX, next.dy,
            next.dx, next.dy);
      }

      // Close fill path
      if (points.isNotEmpty) {
        fillPath.lineTo(points.last.dx, size.height);
        fillPath.close();
      }
    }

    // Draw the fill and line
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Draw data points with white border
    for (int i = 0; i < data.length; i++) {
      final x = i * (size.width / (data.length > 1 ? data.length - 1 : 1));
      final y = size.height - (data[i].y / maxValue * size.height);

      // Draw outer white circle
      canvas.drawCircle(Offset(x, y), 5, pointStrokePaint);
      // Draw inner colored circle
      canvas.drawCircle(Offset(x, y), 3.5, pointFillPaint);

      // Draw tooltip for selected points (optional)
      if (showTooltip && i == data.length - 1) {
        // Draw tooltip for the last point
        _drawTooltip(canvas, Offset(x, y), data[i].y.toInt().toString(),
            tooltipUnit, textPainter);
      }
    }

    // Draw x-axis labels
    for (int i = 0; i < data.length; i++) {
      final x = i * (size.width / (data.length > 1 ? data.length - 1 : 1));

      // Skip labels if there are too many data points
      // For daily data, only show every nth label depending on how many days we have
      int skipFactor = 1;
      if (labels.length > 7 && labels.length <= 14)
        skipFactor = 2;
      else if (labels.length > 14 && labels.length <= 30)
        skipFactor = 3;
      else if (labels.length > 30)
        skipFactor = 7; // For more than a month, show weekly labels

      if (i % skipFactor != 0 && i != labels.length - 1) continue;

      textPainter.text = TextSpan(
        text: labels[i],
        style: textStyle,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height + 5),
      );
    }
  }

  void _drawTooltip(Canvas canvas, Offset position, String value, String unit,
      TextPainter textPainter) {
    final tooltipText = '$value $unit';
    textPainter.text = TextSpan(
      text: tooltipText,
      style: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();

    final tooltipWidth = textPainter.width + 16;
    final tooltipHeight = textPainter.height + 8;
    final tooltipRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(position.dx, position.dy - 25),
        width: tooltipWidth,
        height: tooltipHeight,
      ),
      const Radius.circular(8),
    );

    // Draw tooltip background
    canvas.drawRRect(
      tooltipRect,
      Paint()..color = Colors.grey.shade800,
    );

    // Draw tooltip text
    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - 25 - textPainter.height / 2,
      ),
    );

    // Draw tooltip pointer
    final path = Path()
      ..moveTo(position.dx, position.dy - 10)
      ..lineTo(position.dx - 6, position.dy - 16)
      ..lineTo(position.dx + 6, position.dy - 16)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.grey.shade800);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
