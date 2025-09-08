import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:capstone_ecobarangay/services/collector_scan_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class CollectorScanScreen extends StatefulWidget {
  const CollectorScanScreen({super.key});

  @override
  State<CollectorScanScreen> createState() => _CollectorScanScreenState();
}

class _CollectorScanScreenState extends State<CollectorScanScreen>
    with TickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController();
  final CollectorScanService _scanService = CollectorScanService();
  bool _isScanning = true;
  bool _isProcessing = false;
  bool _isSubmitting = false;
  String _scanResult = '';
  String _errorDetails = '';
  bool _isSuccess = false;
  bool _isFlashlightOn = false;
  String _userName = '';
  int _pointsAwarded = 0;
  String _residentBarangay = '';
  String _residentPurok = '';
  String _residentId = '';
  String _selectedGarbageType = 'General Waste';
  bool _hasScheduleToday =
      true; // New flag to track if there's a schedule today
  final TextEditingController _weightController = TextEditingController();
  int _estimatedPoints = 0;
  String _collectorBarangay = '';
  String _weightRangeInfo = ''; // Information about the weight range

  // Warning and penalty flags
  bool _hasFailedToContribute = false; // Warning flag
  bool _hasNotSegregated = false; // Penalty flag
  bool _hasNoContributions = false; // Penalty flag

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _animation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // List of garbage types with color information
  final List<Map<String, dynamic>> _garbageTypes = [
    {
      'name': 'General Waste',
      'color': Colors.blue.shade600,
      'icon': FontAwesomeIcons.dumpster,
    },
    {
      'name': 'Biodegradable',
      'color': Colors.green.shade600,
      'icon': FontAwesomeIcons.leaf,
    },
    {
      'name': 'Non-Biodegradable',
      'color': Colors.orange.shade600,
      'icon': FontAwesomeIcons.trash,
    },
    {
      'name': 'Recycables',
      'color': Colors.teal.shade600,
      'icon': FontAwesomeIcons.recycle,
    },
    {
      'name': 'No Schedule For Today',
      'color': Colors.red.shade600,
      'icon': FontAwesomeIcons.ban,
    },
  ];

  // Add variables for scan debouncing and stability check
  DateTime? _lastScanTime;
  final int _minimumScanInterval = 2000; // 2 seconds in milliseconds
  String? _lastScannedCode;
  Timer? _stabilityTimer;
  String? _pendingCode;
  int _stableFrameCount = 0;
  final int _requiredStableFrames = 10; // Number of stable frames required
  final int _stabilityCheckInterval = 100; // Check every 100ms

  @override
  void initState() {
    super.initState();

    // Setup animation for scanner overlay
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.linear,
      ),
    );

    // Setup slide-up animation for results
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: const Offset(0, 0.05),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    // Make the animation repeat
    _animationController.repeat(reverse: true);

    // Add listener to weight controller to update estimated points
    _weightController.addListener(_updateEstimatedPoints);
  }

  @override
  void dispose() {
    _stabilityTimer?.cancel();
    _animationController.dispose();
    _slideController.dispose();
    _scannerController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _toggleFlashlight() async {
    await _scannerController.toggleTorch();
    setState(() {
      _isFlashlightOn = !_isFlashlightOn;
    });
  }

  // Calculate estimated points based on weight input
  void _updateEstimatedPoints() async {
    final String weightText = _weightController.text.trim();
    if (weightText.isEmpty) {
      setState(() {
        _estimatedPoints = 0;
        _weightRangeInfo = '';
      });
      return;
    }

    // Parse weight and calculate points
    double? weight = double.tryParse(weightText);
    if (weight != null && weight > 0) {
      // Show loading indicator while calculating
      setState(() {
        _estimatedPoints = -1; // Use -1 to indicate loading state
        _weightRangeInfo = '';
      });

      try {
        // Get collector's barangay - use resident's barangay as fallback
        String? collectorId = _scanService.currentCollectorId;
        String collectorBarangay = _residentBarangay; // Default fallback

        if (collectorId != null) {
          try {
            final collectorDoc = await FirebaseFirestore.instance
                .collection('collector')
                .doc(collectorId)
                .get();

            if (collectorDoc.exists) {
              final collectorData =
                  collectorDoc.data() as Map<String, dynamic>?;
              if (collectorData != null && collectorData['barangay'] != null) {
                collectorBarangay = collectorData['barangay'];
                print(
                    'Using collector barangay for matrix: $collectorBarangay');
              } else {
                print(
                    'Collector data missing barangay, using resident barangay: $_residentBarangay');
              }
            } else {
              print(
                  'Collector document not found, using resident barangay: $_residentBarangay');
            }
          } catch (e) {
            print('Error getting collector data: $e');
          }
        } else {
          print(
              'No collector ID available, using resident barangay: $_residentBarangay');
        }

        // Get the reward matrix to find the matching range
        final matrixSnap = await FirebaseFirestore.instance
            .collection('reward_matrix')
            .where('barangayId', isEqualTo: collectorBarangay)
            .orderBy('minKg', descending: false)
            .get();

        String weightRangeText = '';
        int points = 0;
        bool foundMatch = false;

        if (matrixSnap.docs.isNotEmpty) {
          print('Found ${matrixSnap.docs.length} reward matrix entries');

          // Debug: Print all matrix entries
          for (var doc in matrixSnap.docs) {
            Map<String, dynamic> data = doc.data();
            print(
                'Matrix entry: minKg=${data['minKg']}, maxKg=${data['maxKg']}, points=${data['points']}');
          }

          // Find the matching weight range in the matrix
          for (var doc in matrixSnap.docs) {
            Map<String, dynamic> data = doc.data();
            double minKg = 0;
            double maxKg = double.infinity;

            try {
              if (data['minKg'] != null) {
                minKg = (data['minKg'] is int)
                    ? (data['minKg'] as int).toDouble()
                    : (data['minKg'] is double)
                        ? data['minKg'] as double
                        : double.tryParse(data['minKg'].toString()) ?? 0;
              }

              if (data['maxKg'] != null) {
                if (data['maxKg'] is int) {
                  maxKg = (data['maxKg'] as int).toDouble();
                } else if (data['maxKg'] is double) {
                  maxKg = data['maxKg'] as double;
                } else {
                  double? parsedMax = double.tryParse(data['maxKg'].toString());
                  if (parsedMax != null) {
                    maxKg = parsedMax;
                  }
                }
              }

              print('Checking if weight $weight is in range: $minKg-$maxKg kg');

              if (weight >= minKg && weight <= maxKg) {
                if (data['points'] != null) {
                  if (data['points'] is int) {
                    points = data['points'] as int;
                  } else if (data['points'] is double) {
                    points = (data['points'] as double).round();
                  } else {
                    points = int.tryParse(data['points'].toString()) ?? 0;
                  }
                }

                // Set the weight range text
                weightRangeText =
                    '${minKg.toStringAsFixed(1)} to ${maxKg == double.infinity ? '∞' : maxKg.toStringAsFixed(1)} kg = $points points';
                print(
                    'MATCH FOUND: $weight kg is in range $minKg-$maxKg kg = $points points');
                foundMatch = true;
                break;
              }
            } catch (e) {
              print('Error parsing matrix values: $e');
            }
          }
        }

        // If no specific range found, indicate no matching range
        if (!foundMatch) {
          points = 0; // No points if no range matches
          weightRangeText = 'No matching weight range in reward matrix';
          print('No matching weight range found for $weight kg');
        }

        setState(() {
          _estimatedPoints = points;
          _collectorBarangay = collectorBarangay;
          _weightRangeInfo = weightRangeText;
        });
      } catch (e) {
        print('Error calculating points from matrix: $e');
        setState(() {
          _estimatedPoints = 0;
          _collectorBarangay = 'Error';
          _weightRangeInfo = 'Error: Could not calculate points';
        });
      }
    } else {
      setState(() {
        _estimatedPoints = 0;
        _weightRangeInfo = '';
      });
    }
  }

  // Get color for selected waste type
  Color getWasteTypeColor(String wasteType) {
    final wasteTypeData = _garbageTypes.firstWhere(
      (element) => element['name'] == wasteType,
      orElse: () => {'color': Colors.blue.shade600},
    );
    return wasteTypeData['color'] as Color;
  }

  // Get icon for selected waste type
  IconData getWasteTypeIcon(String wasteType) {
    final wasteTypeData = _garbageTypes.firstWhere(
      (element) => element['name'] == wasteType,
      orElse: () => {'icon': FontAwesomeIcons.dumpster},
    );
    return wasteTypeData['icon'] as IconData;
  }

  Future<void> _processQrCode(String data) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _isScanning = false;
      _scanResult = 'Processing QR code...';
      _errorDetails = '';
    });

    try {
      print('Processing QR code data: $data');
      // Use the collector scan service to process the QR code
      final result = await _scanService.processQrScan(data);

      setState(() {
        _isSuccess = result['success'];
        _scanResult = result['message'];

        if (_isSuccess) {
          _userName = result['userName'] ?? '';
          _pointsAwarded = result['points'] ?? 0;
          _residentBarangay = result['barangay'] ?? '';
          _residentPurok = result['purok'] ?? '';
          _residentId = result['residentId'] ?? '';
          _hasScheduleToday = result['hasScheduleToday'] ?? true;

          // If there's a scheduled waste type for today, auto-select it
          if (result['scheduledWasteType'] != null) {
            _selectedGarbageType = result['scheduledWasteType'];
            print('Auto-selected waste type: $_selectedGarbageType');
          }

          // Run the slide-up animation after successful scan
          _slideController.forward();
        }
      });
    } catch (e) {
      print('Error in scan screen: $e');
      setState(() {
        _scanResult = 'Error processing scan';
        _errorDetails = e.toString();
        _isSuccess = false;
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _resetScanner() {
    _stabilityTimer?.cancel();
    _pendingCode = null;
    _stableFrameCount = 0;
    _slideController.reverse().then((_) {
      setState(() {
        _isScanning = true;
        _scanResult = '';
        _errorDetails = '';
        _userName = '';
        _pointsAwarded = 0;
        _residentBarangay = '';
        _residentPurok = '';
        _residentId = '';
        _weightController.clear();
        _selectedGarbageType = 'General Waste';
        _estimatedPoints = 0;
        _weightRangeInfo = '';
        _isSubmitting = false;
        _hasScheduleToday = true;
        _lastScanTime = null;
        _lastScannedCode = null;
        // Reset warning and penalty flags
        _hasFailedToContribute = false;
        _hasNotSegregated = false;
        _hasNoContributions = false;
      });
    });
  }

  Future<void> _viewScanHistory() async {
    Navigator.pushNamed(context, '/collector/scan-history');
  }

  // Submit scan data to Firestore
  Future<void> _submitScan() async {
    // Don't proceed if there's no schedule for today
    if (!_hasScheduleToday || _selectedGarbageType == 'No Schedule For Today') {
      return; // Simply return without showing redundant error message
    }

    // Check if any warning or penalty is checked
    bool hasWarningsOrPenalties =
        _hasFailedToContribute || _hasNotSegregated || _hasNoContributions;

    // Validate weight input only if no warnings or penalties are checked
    if (!hasWarningsOrPenalties) {
      // Validate weight input
      final String weightText = _weightController.text.trim();
      if (weightText.isEmpty) {
        setState(() {
          _errorDetails = 'Please enter the garbage weight';
        });
        return;
      }

      // Parse weight and validate
      double? weight = double.tryParse(weightText);
      if (weight == null || weight <= 0) {
        setState(() {
          _errorDetails = 'Please enter a valid garbage weight';
        });
        return;
      }
    }

    // Validate if we have a resident ID
    if (_residentId.isEmpty) {
      setState(() {
        _errorDetails = 'Resident information is missing. Please scan again.';
      });
      return;
    }

    // Clear error and show loading state
    setState(() {
      _errorDetails = '';
      _isSubmitting = true;
    });

    try {
      // Get current time

      // Get weight (0 if warnings/penalties are checked)
      double weight = 0;
      if (!hasWarningsOrPenalties) {
        weight = double.tryParse(_weightController.text.trim()) ?? 0;
      }

      // Submit the scan
      final result = await _scanService.submitScan(
        residentId: _residentId,
        residentName: _userName,
        garbageType: _selectedGarbageType,
        garbageWeight: weight,
        barangay: _residentBarangay,
        purok: _residentPurok,
        hasFailedToContribute: _hasFailedToContribute,
        hasNotSegregated: _hasNotSegregated,
        hasNoContributions: _hasNoContributions,
      );

      if (result['success']) {
        // Get the points awarded from the result
        final pointsAwarded = result['pointsAwarded'] ?? 0;

        // Check if any warnings or penalties were applied
        bool hasWarningsOrPenalties =
            _hasFailedToContribute || _hasNotSegregated || _hasNoContributions;

        setState(() {
          _scanResult = 'Scan submitted successfully!';
          _pointsAwarded =
              pointsAwarded; // Update to show points awarded from this scan
          _isSubmitting = false;
        });

        // Show different dialog based on whether warnings/penalties were applied
        if (hasWarningsOrPenalties) {
          // Show warning/penalty dialog
          _showWarningPenaltyDialog(result);
        } else {
          // Show regular success dialog
          _showSuccessDialog(result, weight);
        }
      } else if (result['alreadyScanned'] == true) {
        // Show duplicate scan error but without setting error details
        setState(() {
          _scanResult = 'Duplicate Scan Detected';
          _errorDetails = ''; // Clear error details to avoid red message
          _isSubmitting = false;
        });

        // Show alert dialog for already scanned case
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 28),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Already Scanned Today',
                    style: TextStyle(fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result['message'] ??
                        'This resident has already been scanned today for this type of waste.',
                    style: TextStyle(fontSize: 15),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'To prevent duplicate points:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 8),
                        // Break bulleted list into separate Text widgets for better wrapping
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(fontSize: 13)),
                            Expanded(
                              child: Text(
                                'Each resident can only be scanned once per day for each type of waste',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(fontSize: 13)),
                            Expanded(
                              child: Text(
                                'Try scanning another resident',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(fontSize: 13)),
                            Expanded(
                              child: Text(
                                'Or scan this resident for a different waste type if applicable',
                                style: TextStyle(fontSize: 13),
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
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 3, 144, 123),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _resetScanner(); // Reset scanner to try again
                    },
                    child: Text('Scan Again'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('Close'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      } else {
        setState(() {
          _scanResult = 'Failed to submit scan';
          _errorDetails = result['message'] ?? 'Unknown error occurred';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _scanResult = 'Error submitting scan';
        _errorDetails = e.toString();
        _isSubmitting = false;
      });
    }
  }

  // Show success dialog for regular scans (no warnings/penalties)
  void _showSuccessDialog(Map<String, dynamic> result, double weight) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text('Success!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scan submitted'),
            SizedBox(height: 8),
            Text('Resident: $_userName'),
            Row(
              children: [
                Icon(
                  getWasteTypeIcon(_selectedGarbageType),
                  size: 14,
                  color: getWasteTypeColor(_selectedGarbageType),
                ),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Type: $_selectedGarbageType',
                    style: TextStyle(
                      color: getWasteTypeColor(_selectedGarbageType),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text('Weight: $weight kg'),
            SizedBox(height: 12),

            // Points breakdown section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.amber.shade200,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Points',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Previous:'),
                      Text(
                        '${result['previousPoints']}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Earned:'),
                      Text(
                        '+${result['pointsAwarded']}',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total:'),
                      Text(
                        '${result['newTotalPoints']}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (result['pointsCalculation'] != null &&
                      result['pointsCalculation']['fromRewardMatrix'] !=
                          null) ...[
                    SizedBox(height: 8),
                    Text(
                      'Using ${result['pointsCalculation']['collectorBarangay']} matrix',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromARGB(255, 3, 144, 123),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(
                      context, '/collector/scan-history');
                },
                child: Text('View History'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Close'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Show warning/penalty dialog
  void _showWarningPenaltyDialog(Map<String, dynamic> result) {
    // Build list of applied warnings and penalties
    List<String> appliedWarnings = [];
    List<String> appliedPenalties = [];

    if (_hasFailedToContribute) {
      appliedWarnings.add('Failed to Contribute');
    }
    if (_hasNotSegregated) {
      appliedPenalties.add('Not Segregated');
    }
    if (_hasNoContributions) {
      appliedPenalties.add('No Contributions');
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Warning/Penalty Applied',
                style: TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resident: $_userName',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  getWasteTypeIcon(_selectedGarbageType),
                  size: 14,
                  color: getWasteTypeColor(_selectedGarbageType),
                ),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Type: $_selectedGarbageType',
                    style: TextStyle(
                      color: getWasteTypeColor(_selectedGarbageType),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Compact warnings/penalties display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.shade200,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Applied warnings/penalties summary
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orange, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Applied:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),

                  // Show applied items in a compact list
                  if (appliedWarnings.isNotEmpty) ...[
                    ...appliedWarnings.map((warning) => Padding(
                          padding: EdgeInsets.only(left: 22, top: 2),
                          child: Row(
                            children: [
                              Icon(Icons.warning,
                                  size: 12, color: Colors.orange),
                              SizedBox(width: 6),
                              Text(
                                warning,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700),
                              ),
                            ],
                          ),
                        )),
                  ],

                  if (appliedPenalties.isNotEmpty) ...[
                    ...appliedPenalties.map((penalty) => Padding(
                          padding: EdgeInsets.only(left: 22, top: 2),
                          child: Row(
                            children: [
                              Icon(Icons.block, size: 12, color: Colors.red),
                              SizedBox(width: 6),
                              Text(
                                penalty,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.red.shade700),
                              ),
                            ],
                          ),
                        )),
                  ],

                  Divider(height: 12),

                  // Compact totals display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Warnings:',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${result['newTotalWarnings']}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Penalties:',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${result['newTotalPenalties']}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 8),

            // Compact info note
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: Colors.grey.shade600),
                  SizedBox(width: 6),
                  Text(
                    'No points awarded',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromARGB(255, 3, 144, 123),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(
                      context, '/collector/scan-history');
                },
                child: Text('View History'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Close'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to build count rows more compactly
  Widget _buildCountRow(String label, String value, bool isBold,
      [Color? color, double? fontSize]) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize ?? 13,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize ?? 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Add this new method to handle QR code detection with stability check
  void _handleQrCodeDetection(String code) {
    // Don't process the same code twice in a row
    if (code == _lastScannedCode) {
      return;
    }

    // Get current time
    final now = DateTime.now();

    // Check if we need to enforce the minimum scan interval
    if (_lastScanTime != null) {
      final timeSinceLastScan = now.difference(_lastScanTime!).inMilliseconds;
      if (timeSinceLastScan < _minimumScanInterval) {
        return;
      }
    }

    // If this is a new code or first detection
    if (_pendingCode != code) {
      // Reset stability check for new code
      _pendingCode = code;
      _stableFrameCount = 0;
      _stabilityTimer?.cancel();

      // Start stability check timer
      _stabilityTimer = Timer.periodic(
          Duration(milliseconds: _stabilityCheckInterval), (timer) {
        if (_pendingCode == code) {
          _stableFrameCount++;

          // Show progress to user
          if (_stableFrameCount == 1) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Hold still...'),
                duration: Duration(milliseconds: 500),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            );
          }

          // If we have enough stable frames, process the code
          if (_stableFrameCount >= _requiredStableFrames) {
            timer.cancel();
            _lastScannedCode = code;
            _lastScanTime = now;
            _processQrCode(code);
          }
        } else {
          // Code changed, reset stability check
          timer.cancel();
          _stableFrameCount = 0;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the app bar height plus safe area to adjust positioning
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double appBarHeight = AppBar().preferredSize.height + statusBarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      // Add resizeToAvoidBottomInset: false to prevent scaffold from resizing when keyboard appears
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text(
          'Scan QR Code',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromARGB(220, 3, 144, 123),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFlashlightOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: _toggleFlashlight,
          ),
          IconButton(
            icon: const Icon(
              Icons.history,
              color: Colors.white,
            ),
            onPressed: _viewScanHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isScanning
                ? Stack(
                    children: [
                      // QR Scanner - Modified to position it at the very top
                      Positioned.fill(
                        child: MobileScanner(
                          controller: _scannerController,
                          onDetect: (capture) {
                            final List<Barcode> barcodes = capture.barcodes;
                            if (barcodes.isNotEmpty && _isScanning) {
                              final String code = barcodes.first.rawValue ?? '';
                              if (code.isNotEmpty) {
                                // Add debounce logic
                                _handleQrCodeDetection(code);
                              }
                            }
                          },
                        ),
                      ),

                      // Scanner overlay with animation
                      Center(
                        child: Container(
                          width: 260,
                          height: 260,
                          margin: const EdgeInsets.only(top: 40),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withOpacity(0.6),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color.fromARGB(255, 3, 144, 123)
                                    .withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Corners of the scan area
                              Positioned(
                                top: -3,
                                left: -3,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: const Color.fromARGB(
                                            255, 3, 144, 123),
                                        width: 4,
                                      ),
                                      left: BorderSide(
                                        color: const Color.fromARGB(
                                            255, 3, 144, 123),
                                        width: 4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -3,
                                right: -3,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: const Color.fromARGB(
                                            255, 3, 144, 123),
                                        width: 4,
                                      ),
                                      right: BorderSide(
                                        color: const Color.fromARGB(
                                            255, 3, 144, 123),
                                        width: 4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -3,
                                left: -3,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: const Color.fromARGB(
                                            255, 3, 144, 123),
                                        width: 4,
                                      ),
                                      left: BorderSide(
                                        color: const Color.fromARGB(
                                            255, 3, 144, 123),
                                        width: 4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -3,
                                right: -3,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: const Color.fromARGB(
                                            255, 3, 144, 123),
                                        width: 4,
                                      ),
                                      right: BorderSide(
                                        color: const Color.fromARGB(
                                            255, 3, 144, 123),
                                        width: 4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Animated scan line
                              AnimatedBuilder(
                                animation: _animationController,
                                builder: (context, child) {
                                  return Positioned(
                                    top: _animation.value * 220,
                                    left: 12,
                                    right: 12,
                                    child: Container(
                                      height: 2,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            const Color.fromARGB(
                                                    255, 3, 144, 123)
                                                .withOpacity(0.3),
                                            const Color.fromARGB(
                                                255, 3, 144, 123),
                                            const Color.fromARGB(
                                                    255, 3, 144, 123)
                                                .withOpacity(0.3),
                                            Colors.transparent,
                                          ],
                                          stops: const [
                                            0.0,
                                            0.2,
                                            0.5,
                                            0.8,
                                            1.0
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color.fromARGB(
                                                    255, 3, 144, 123)
                                                .withOpacity(0.5),
                                            blurRadius: 12,
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Custom painter for the overlay
                      CustomPaint(
                        size: Size(MediaQuery.of(context).size.width,
                            MediaQuery.of(context).size.height),
                        painter: ScanOverlayPainter(),
                      ),

                      // Status text at the top
                      Positioned(
                        top: 120,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.qr_code_scanner,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Position QR code inside frame',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : _isProcessing
                    ? _buildLoadingWidget()
                    : Stack(
                        children: [
                          // Show a white background behind the result panel
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: Colors.white,
                          ),
                          // Show the slide-up panel with positioning to avoid app bar
                          Positioned(
                            // Position below app bar with extra margin for safety
                            top: appBarHeight + 10,
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: _buildResultWidget(),
                            ),
                          ),
                        ],
                      ),
          ),
          if (_isScanning)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: const Column(
                      children: [
                        Text(
                          'Scan Resident QR Code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 3, 144, 123),
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Position the QR code within the frame',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (!_isScanning && !_isProcessing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 3, 144, 123),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _resetScanner,
                  ),
                  const SizedBox(width: 16),
                  if (_isSuccess)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.history),
                      label: const Text('View History'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _viewScanHistory,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: const Color.fromARGB(255, 3, 144, 123),
          ),
          const SizedBox(height: 24),
          const Text(
            'Processing QR Code',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please wait while we verify the resident',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultWidget() {
    // Calculate available height that fits within the screen
    final double screenHeight = MediaQuery.of(context).size.height;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double appBarHeight = AppBar().preferredSize.height + statusBarHeight;
    final double bottomPadding =
        80; // Space for bottom buttons with extra margin
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    // Adjust the available height to account for keyboard
    final double availableHeight =
        screenHeight - appBarHeight - bottomPadding - 20 - keyboardHeight;

    // Get color for selected waste type
    final Color wasteTypeColor = getWasteTypeColor(_selectedGarbageType);
    final IconData wasteTypeIcon = getWasteTypeIcon(_selectedGarbageType);

    return Container(
      constraints: BoxConstraints(
        maxHeight: availableHeight,
      ),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8), // Add side margins
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag indicator
          Container(
            width: 50,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          // Always visible content - main scan result
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Status icon with message - more compact
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        _isSuccess
                            ? FontAwesomeIcons.circleCheck
                            : FontAwesomeIcons.circleXmark,
                        size: 24,
                        color: _isSuccess ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _scanResult,
                          style: TextStyle(
                            fontSize: 17,
                            color: _isSuccess
                                ? Colors.green[800]
                                : Colors.red[800],
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.left,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ],
                  ),
                ),

                // Error details if any
                if (_errorDetails.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[100]!),
                    ),
                    child: Text(
                      _errorDetails,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.red[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Scrollable content area
          Flexible(
            child: SingleChildScrollView(
              // Use BouncingScrollPhysics on iOS-style, but add padding at bottom for keyboard
              physics: const BouncingScrollPhysics(),
              // Add bottom padding to give space for keyboard
              padding: EdgeInsets.fromLTRB(20, 2, 20,
                  MediaQuery.of(context).viewInsets.bottom > 0 ? 200 : 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Resident information if success
                  if (_isSuccess && _userName.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 8),

                    // Resident info in card - more compact
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[100]!),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person,
                                  color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _userName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          if (_residentPurok.isNotEmpty ||
                              _residentBarangay.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    color: Colors.blue, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${_residentPurok.isNotEmpty ? "$_residentPurok" : ""}${_residentPurok.isNotEmpty && _residentBarangay.isNotEmpty ? ", " : ""}${_residentBarangay.isNotEmpty ? _residentBarangay : ""}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.stars,
                                  color: Colors.amber, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '$_pointsAwarded points',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Form title
                    Container(
                      width: double.infinity,
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'Garbage Collection Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 3, 144, 123),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Garbage Type Dropdown with color-coding
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              wasteTypeIcon,
                              size: 16,
                              color: wasteTypeColor,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Garbage Type',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (_selectedGarbageType != 'General Waste' &&
                                _selectedGarbageType != 'No Schedule For Today')
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: wasteTypeColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: wasteTypeColor.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Today\'s Schedule',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: wasteTypeColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            if (_selectedGarbageType == 'No Schedule For Today')
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.red.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'No Collection Today',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red.shade700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: wasteTypeColor.withOpacity(0.5),
                            ),
                            color: !_hasScheduleToday
                                ? Colors.grey.shade100
                                : null,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedGarbageType,
                              isExpanded: true,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              borderRadius: BorderRadius.circular(8),
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: !_hasScheduleToday ? Colors.grey : null,
                              ),
                              // Disable dropdown if there's no schedule today
                              onTap: !_hasScheduleToday
                                  ? () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'No waste collection scheduled for today'),
                                          backgroundColor: Colors.red,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  : null,
                              items: _garbageTypes
                                  .map((Map<String, dynamic> typeData) {
                                String type = typeData['name'] as String;
                                Color color = typeData['color'] as Color;
                                IconData icon = typeData['icon'] as IconData;
                                return DropdownMenuItem<String>(
                                  value: type,
                                  child: Row(
                                    children: [
                                      Icon(
                                        icon,
                                        size: 16,
                                        color: color,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        type,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: color,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: !_hasScheduleToday
                                  ? null
                                  : (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _selectedGarbageType = newValue;

                                          // Show error message if selecting "No Schedule For Today" manually
                                          if (newValue ==
                                              'No Schedule For Today') {
                                            // Don't set redundant error details
                                            // This will be handled by the warning banner
                                          } else {
                                            _errorDetails = '';
                                          }
                                        });
                                      }
                                    },
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Weight Input
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Garbage Weight (kg)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.amber.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: const Text(
                                  'Affects points',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.amber,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(fontSize: 16),
                          enabled: !_hasFailedToContribute &&
                              !_hasNotSegregated &&
                              !_hasNoContributions,
                          decoration: InputDecoration(
                            hintText: _hasFailedToContribute ||
                                    _hasNotSegregated ||
                                    _hasNoContributions
                                ? 'Weight input disabled due to warnings/penalties'
                                : 'Enter weight',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            suffixText: 'kg',
                            helperText: _hasFailedToContribute ||
                                    _hasNotSegregated ||
                                    _hasNoContributions
                                ? 'Weight and points are not awarded when warnings or penalties are applied'
                                : 'Weight determines points based on barangay reward matrix',
                            helperStyle: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: _hasFailedToContribute ||
                                      _hasNotSegregated ||
                                      _hasNoContributions
                                  ? Colors.red.shade600
                                  : Colors.grey.shade600,
                            ),
                            filled: _hasFailedToContribute ||
                                _hasNotSegregated ||
                                _hasNoContributions,
                            fillColor: _hasFailedToContribute ||
                                    _hasNotSegregated ||
                                    _hasNoContributions
                                ? Colors.grey.shade100
                                : null,
                          ),
                          onChanged: (_) => _updateEstimatedPoints(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Points preview section
                    if (_estimatedPoints != 0) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber.shade200,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.stars,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Points Preview',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _estimatedPoints == -1
                                ? Row(
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.amber,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Calculating points...',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Estimated points to be awarded: $_estimatedPoints points',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (_weightRangeInfo.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          _weightRangeInfo,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _weightRangeInfo
                                                    .contains('No matching')
                                                ? Colors.red.shade800
                                                : Colors.black87,
                                            fontStyle: _weightRangeInfo
                                                    .contains('No matching')
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                          ),
                                        ),
                                        if (_weightRangeInfo
                                            .contains('No matching')) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.red.shade200,
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.warning,
                                                        size: 14,
                                                        color: Colors
                                                            .red.shade800),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        'No points will be awarded for this weight',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors
                                                              .red.shade800,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Please check with your supervisor about the correct weight ranges for point rewards.',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.red.shade800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ],
                                  ),
                            const SizedBox(height: 4),
                            Text(
                              'Points are calculated based on the reward matrix for $_collectorBarangay',
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 12,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Your barangay admin has configured point rewards based on waste weight',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Warning and Penalties Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  size: 16, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Warning & Penalties',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Warning Checkbox
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                checkboxTheme: CheckboxThemeData(
                                  fillColor:
                                      MaterialStateProperty.resolveWith<Color>(
                                    (Set<MaterialState> states) {
                                      if (states
                                          .contains(MaterialState.selected)) {
                                        return Colors.orange;
                                      }
                                      return Colors.transparent;
                                    },
                                  ),
                                  side: BorderSide(color: Colors.grey.shade400),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                              child: CheckboxListTile(
                                title: const Text(
                                  'Failed to Contribute',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                value: _hasFailedToContribute,
                                onChanged: (bool? value) {
                                  setState(() {
                                    _hasFailedToContribute = value ?? false;
                                    if (_hasFailedToContribute) {
                                      // Reset weight and points if warning is checked
                                      _weightController.clear();
                                      _estimatedPoints = 0;
                                      _weightRangeInfo = '';
                                    }
                                  });
                                },
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Penalties Checkboxes
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                checkboxTheme: CheckboxThemeData(
                                  fillColor:
                                      MaterialStateProperty.resolveWith<Color>(
                                    (Set<MaterialState> states) {
                                      if (states
                                          .contains(MaterialState.selected)) {
                                        return Colors.red;
                                      }
                                      return Colors.transparent;
                                    },
                                  ),
                                  side: BorderSide(color: Colors.grey.shade400),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  CheckboxListTile(
                                    title: const Text(
                                      'Not Segregated',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    value: _hasNotSegregated,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        _hasNotSegregated = value ?? false;
                                        if (_hasNotSegregated) {
                                          // Reset weight and points if penalty is checked
                                          _weightController.clear();
                                          _estimatedPoints = 0;
                                          _weightRangeInfo = '';
                                        }
                                      });
                                    },
                                    dense: true,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                  ),
                                  const Divider(height: 1),
                                  CheckboxListTile(
                                    title: const Text(
                                      'No Contributions',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    value: _hasNoContributions,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        _hasNoContributions = value ?? false;
                                        if (_hasNoContributions) {
                                          // Reset weight and points if penalty is checked
                                          _weightController.clear();
                                          _estimatedPoints = 0;
                                          _weightRangeInfo = '';
                                        }
                                      });
                                    },
                                    dense: true,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),

          // Fixed position submit button area - always visible
          if (_isSuccess && _userName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Column(
                children: [
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 3, 144, 123),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: (_isSubmitting ||
                              !_hasScheduleToday ||
                              _selectedGarbageType == 'No Schedule For Today')
                          ? null
                          : _submitScan,
                      child: _isSubmitting
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Submitting...',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              !_hasScheduleToday ||
                                      _selectedGarbageType ==
                                          'No Schedule For Today'
                                  ? 'No Schedule Today'
                                  : 'Submit Scan',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    !_hasScheduleToday ||
                            _selectedGarbageType == 'No Schedule For Today'
                        ? 'No waste collection scheduled for today'
                        : 'Once submitted, scan data cannot be modified',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Custom painter for creating the overlay around the scan area
class ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scanAreaSize = 260;
    final double scanAreaLeft = (size.width - scanAreaSize) / 2;
    final double scanAreaTop = (size.height - scanAreaSize) / 2 + 20;
    final double cornerRadius = 16.0;

    final Paint paint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // Create a path for the entire screen
    final Path fullScreenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create the cutout for the scan area
    final Path scanAreaPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(scanAreaLeft, scanAreaTop, scanAreaSize, scanAreaSize),
          Radius.circular(cornerRadius)));

    // Use difference to create the overlay with a hole for the scan area
    final Path overlayPath = Path.combine(
      PathOperation.difference,
      fullScreenPath,
      scanAreaPath,
    );

    canvas.drawPath(overlayPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
