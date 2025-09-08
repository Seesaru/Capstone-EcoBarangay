import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Removed unused fl_chart import
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/pdf_service.dart';
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'features/ai_analytics_screen.dart';
import '../../widgets/analytics_widgets/index.dart';

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
  String? _selectedMonth; // Holds the selected month (e.g., 'Jul 2023')
  final List<String> _timeFilters = [
    'This Week',
    'This Month',
    'This Year',
    'All Time',
    'Select Month', // New option
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
  // Removed unused _modernColors

  // Add a new class variable to store monthly scan counts
  Map<String, int> _monthlyScansCount = {};

  // Add a new class variable to store daily scan counts
  Map<String, int> _dailyScansCount = {};

  // Add a new class variable to store daily collection weight (kg)
  Map<String, double> _dailyCollectionWeight = {};

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
      _dailyCollectionWeight = {}; // Reset daily collection weight
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

      // Get date range for filtering
      DateTime startDate = _getStartDate(_selectedTimeFilter);
      DateTime endDate = _getEndDate(_selectedTimeFilter);

      // Process scan data
      for (var doc in scansSnapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          // Skip if no timestamp
          if (data['timestamp'] == null) continue;

          DateTime scanDate = (data['timestamp'] as Timestamp).toDate();

          // Filter data based on selected time range
          if (scanDate.isBefore(startDate) || scanDate.isAfter(endDate)) {
            continue; // Skip data outside the selected time range
          }

          String rawWasteType = data['garbageType'] ?? 'General Waste';
          double weight = (data['garbageWeight'] ?? 0).toDouble();
          String purok = data['purok'] ?? 'Unknown';

          // Map the raw waste type to one of our standardized categories
          String standardizedWasteType = _standardizeWasteType(rawWasteType);

          // Update waste type data using standardized category
          _wasteTypeData[standardizedWasteType] =
              (_wasteTypeData[standardizedWasteType] ?? 0.0) + weight;

          // Update monthly data
          try {
            String monthKey = DateFormat('MMM yyyy').format(scanDate);
            _monthlyCollectionData[monthKey] =
                (_monthlyCollectionData[monthKey] ?? 0.0) + weight;
          } catch (e) {
            print('Error formatting monthly data date: $e');
          }

          // Update daily data
          try {
            String dayKey = DateFormat('MMM d, yyyy').format(scanDate);
            _dailyScansCount[dayKey] = (_dailyScansCount[dayKey] ?? 0) + 1;
            _dailyCollectionWeight[dayKey] =
                (_dailyCollectionWeight[dayKey] ?? 0.0) + weight;
          } catch (e) {
            print('Error formatting daily scan date: $e');
          }

          // Update monthly scan counts - count each document as one scan
          try {
            String monthKey = DateFormat('MMM yyyy').format(scanDate);
            _monthlyScansCount[monthKey] =
                (_monthlyScansCount[monthKey] ?? 0) + 1;
          } catch (e) {
            print('Error formatting monthly scan count date: $e');
          }

          // Update purok data
          _purokCollectionData[purok] =
              (_purokCollectionData[purok] ?? 0.0) + weight;

          // Update totals
          _totalWasteCollected += weight;
          _totalCollections++;

          // Check for warnings and penalties
          bool hasWarnings = false;
          bool hasPenalties = false;

          if (data['warnings'] != null && data['warnings'] is Map) {
            Map<String, dynamic> warnings =
                data['warnings'] as Map<String, dynamic>;
            hasWarnings = warnings.values.any((value) => value == true);
          }

          if (data['penalties'] != null && data['penalties'] is Map) {
            Map<String, dynamic> penalties =
                data['penalties'] as Map<String, dynamic>;
            hasPenalties = penalties.values.any((value) => value == true);
          }

          // Add to recent collections
          _recentCollections.add({
            'date': scanDate,
            'wasteType': standardizedWasteType,
            'weight': weight,
            'purok': purok,
            'residentName': data['residentName'] ?? 'Unknown',
            'warnings': data['warnings'] ?? {},
            'penalties': data['penalties'] ?? {},
            'hasWarnings': hasWarnings,
            'hasPenalties': hasPenalties,
          });
        } catch (e) {
          print('Error processing scan document: $e');
          continue; // Skip this document if there's an error
        }
      }

      // Sort recent collections by date and filter by selected time period
      _recentCollections.sort((a, b) => b['date'].compareTo(a['date']));

      // Filter recent collections based on selected time period
      DateTime filterStartDate = _getStartDate(_selectedTimeFilter);
      DateTime filterEndDate = _getEndDate(_selectedTimeFilter);

      _recentCollections = _recentCollections
          .where((collection) {
            DateTime collectionDate = collection['date'];
            return collectionDate
                    .isAfter(filterStartDate.subtract(Duration(days: 1))) &&
                collectionDate.isBefore(filterEndDate.add(Duration(days: 1)));
          })
          .take(10) // Show more collections since we're filtering by time
          .toList();

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
    try {
      final now = DateTime.now();
      if (timeFilter == 'Select Month' && _selectedMonth != null) {
        // Parse the selected month
        final dt = DateFormat('MMM yyyy').parse(_selectedMonth!);
        return DateTime(dt.year, dt.month, 1);
      }
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
    } catch (e) {
      print('Error in _getStartDate: $e');
      return DateTime.now()
          .subtract(Duration(days: 30)); // Fallback to last 30 days
    }
  }

  DateTime _getEndDate(String timeFilter) {
    try {
      final now = DateTime.now();
      if (timeFilter == 'Select Month' && _selectedMonth != null) {
        // Parse the selected month and get the last day of that month
        final dt = DateFormat('MMM yyyy').parse(_selectedMonth!);
        return DateTime(dt.year, dt.month + 1, 0); // Last day of the month
      }
      switch (timeFilter) {
        case 'This Week':
          return now.add(Duration(days: 7 - now.weekday));
        case 'This Month':
          return DateTime(
              now.year, now.month + 1, 0); // Last day of current month
        case 'This Year':
          return DateTime(now.year, 12, 31);
        case 'All Time':
          return now;
        default:
          return DateTime(now.year, now.month + 1, 0);
      }
    } catch (e) {
      print('Error in _getEndDate: $e');
      return DateTime.now(); // Fallback to current time
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
              AnalyticsHeader(
                adminBarangay: _adminBarangay,
                primaryColor: primaryColor,
                onRefresh: _loadAnalyticsData,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TimeFilter(
                    selectedTimeFilter: _selectedTimeFilter,
                    selectedMonth: _selectedMonth,
                    timeFilters: _timeFilters,
                    primaryColor: primaryColor,
                    textPrimaryColor: textPrimaryColor,
                    onTimeFilterChanged: (String newValue) {
                      setState(() {
                        _selectedTimeFilter = newValue;
                        _selectedMonth = null;
                      });
                      _loadAnalyticsData();
                    },
                    onMonthSelected: (String monthString) {
                      setState(() {
                        _selectedTimeFilter = 'Select Month';
                        _selectedMonth = monthString;
                      });
                      _loadAnalyticsData();
                    },
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AIAnalyticsScreen(
                                adminBarangay: _adminBarangay,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.psychology),
                        label: const Text('AI Analytics'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: secondaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                ],
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _selectedTimeFilter == 'Select Month' &&
                              _selectedMonth != null
                          ? 'Overview for ${DateFormat('MMMM yyyy').format(DateFormat('MMM yyyy').parse(_selectedMonth!))}'
                          : 'Overview for $_selectedTimeFilter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textPrimaryColor,
                      ),
                    ),
                  ),
                  OverviewCards(
                    totalWasteCollected: _totalWasteCollected,
                    totalCollections: _totalCollections,
                    totalWarnings: _recentCollections
                        .where((c) => c['hasWarnings'] == true)
                        .length,
                    totalPenalties: _recentCollections
                        .where((c) => c['hasPenalties'] == true)
                        .length,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    textSecondaryColor: textSecondaryColor,
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
                      key: _wasteTypeChartKey,
                      child: WasteTypeChart(
                        wasteTypeData: _wasteTypeData,
                        totalWasteCollected: _totalWasteCollected,
                        isLoading: _isLoading,
                        onRefresh: _loadAnalyticsData,
                        primaryColor: primaryColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: RepaintBoundary(
                      key: _purokDistributionChartKey,
                      child: PurokDistributionChart(
                        purokCollectionData: _purokCollectionData,
                        totalWasteCollected: _totalWasteCollected,
                        primaryColor: primaryColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Monthly Collection Chart - Full Width
              RepaintBoundary(
                key: _monthlyCollectionChartKey,
                child: MonthlyCollectionChart(
                  monthlyCollectionData: _monthlyCollectionData,
                  dailyScansCount: _dailyCollectionWeight,
                  selectedTimeFilter: _selectedTimeFilter,
                  selectedMonth: _selectedMonth,
                  isLoading: _isLoading,
                  onRefresh: _loadAnalyticsData,
                  primaryColor: primaryColor,
                  textSecondaryColor: textSecondaryColor,
                ),
              ),
              const SizedBox(height: 20),
              // Resident Scans Chart - Full Width
              RepaintBoundary(
                key: _residentScansChartKey,
                child: ResidentScansChart(
                  dailyScansCount: _dailyScansCount,
                  selectedTimeFilter: _selectedTimeFilter,
                  selectedMonth: _selectedMonth,
                  isLoading: _isLoading,
                  accentColor: accentColor,
                  textSecondaryColor: textSecondaryColor,
                ),
              ),
              const SizedBox(height: 20),
              RecentCollections(
                recentCollections: _recentCollections,
                selectedTimeFilter: _selectedTimeFilter,
                selectedMonth: _selectedMonth,
                primaryColor: primaryColor,
                textSecondaryColor: textSecondaryColor,
              ),
            ],
          ),
        ),
      ),
    );
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

  String _getWarningPenaltyText(Map<String, dynamic> collection) {
    List<String> details = [];

    if (collection['hasWarnings'] == true) {
      details.add('Warning');
    }
    if (collection['hasPenalties'] == true) {
      details.add('Penalty');
    }

    return details.join(', ');
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
    // Calculate warning and penalty counts
    int totalWarnings =
        _recentCollections.where((c) => c['hasWarnings'] == true).length;
    int totalPenalties =
        _recentCollections.where((c) => c['hasPenalties'] == true).length;

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
              child: pw.Text('Total Warnings'),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('$totalWarnings'),
            ),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Total Penalties'),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('$totalPenalties'),
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
                'Details',
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
                  child: pw.Text(
                    collection['hasWarnings'] == true ||
                            collection['hasPenalties'] == true
                        ? _getWarningPenaltyText(collection)
                        : '${collection['weight'].toStringAsFixed(1)} kg',
                  ),
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
