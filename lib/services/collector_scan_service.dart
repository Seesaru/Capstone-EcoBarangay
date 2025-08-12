import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CollectorScanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current collector ID
  String? get currentCollectorId => _auth.currentUser?.uid;

  // Process a scanned QR code - READ ONLY version
  Future<Map<String, dynamic>> processQrScan(String qrData) async {
    try {
      print('Scanning QR code: $qrData');

      // First, check if the scanned QR code matches a resident ID directly
      var residentDoc =
          await _firestore.collection('resident').doc(qrData).get();
      String residentId = qrData;

      // If the direct match fails, try to find a resident with this qrCodeData
      if (!residentDoc.exists) {
        print('No direct match for resident ID, checking qrCodeData field...');
        final querySnapshot = await _firestore
            .collection('resident')
            .where('qrCodeData', isEqualTo: qrData)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          return {
            'success': false,
            'message':
                'Resident not found in database. QR code may be invalid.',
          };
        }

        // Use the found resident document
        residentDoc = querySnapshot.docs.first;
        residentId = residentDoc.id;
        print('Found resident using qrCodeData: $residentId');
      } else {
        print('Found resident using direct ID: $residentId');
      }

      // Check if user data exists
      final residentData = residentDoc.data();
      if (residentData == null) {
        return {
          'success': false,
          'message': 'QR code is not associated with a resident account.',
        };
      }

      // Get resident name - check different name fields that might exist
      String residentName = residentData['name'] ??
          residentData['fullName'] ??
          residentData['displayName'] ??
          'Resident';

      // Get other resident info that might be useful
      String barangay = residentData['barangay'] ?? 'Unknown Barangay';
      String purok = residentData['purok'] ?? 'Unknown Purok';
      int currentPoints = residentData['points'] ?? 0;

      // Get today's scheduled waste type for this barangay
      var scheduleResult = await _getTodayScheduledWasteType(barangay);
      String? scheduledWasteType = scheduleResult['wasteType'];
      bool hasScheduleToday = scheduleResult['hasSchedule'];

      print('Today\'s scheduled waste type: $scheduledWasteType');

      // Return resident information with schedule status
      return {
        'success': true,
        'message': 'Found resident: $residentName',
        'userName': residentName,
        'points': currentPoints,
        'barangay': barangay,
        'purok': purok,
        'residentId': residentId,
        'scheduledWasteType': scheduledWasteType,
        'hasScheduleToday': hasScheduleToday
      };
    } catch (e) {
      print('Error processing scan: $e');
      return {
        'success': false,
        'message': 'Error processing scan: $e',
      };
    }
  }

  // Fetch today's scheduled waste type for a specific barangay
  Future<Map<String, dynamic>> _getTodayScheduledWasteType(
      String barangay) async {
    try {
      if (barangay.isEmpty || barangay == 'Unknown Barangay') {
        return {'wasteType': 'No Schedule For Today', 'hasSchedule': false};
      }

      // Get collector information to double-check barangay
      String collectorBarangay = barangay;
      if (currentCollectorId != null) {
        final collectorDoc = await _firestore
            .collection('collector')
            .doc(currentCollectorId)
            .get();
        if (collectorDoc.exists) {
          final collectorData = collectorDoc.data() as Map<String, dynamic>?;
          if (collectorData != null) {
            collectorBarangay = collectorData['barangay'] ?? barangay;
          }
        }
      }

      // Get today's date (normalized to remove time component)
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);

      // Query schedules collection for today's date and matching barangay
      final scheduleSnapshot = await _firestore.collection('schedule').get();

      // Need to manually filter for today and the barangay
      for (var doc in scheduleSnapshot.docs) {
        final data = doc.data();

        // Get schedule date and normalize
        if (data['date'] is Timestamp) {
          DateTime scheduleDate = (data['date'] as Timestamp).toDate();
          DateTime normalizedDate =
              DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day);

          // Compare normalized dates
          if (normalizedDate.isAtSameMomentAs(today)) {
            // Get the barangay and normalize for comparison
            String scheduleBarangay =
                (data['barangay'] ?? '').toString().trim().toLowerCase();
            String normalizedBarangay = collectorBarangay.trim().toLowerCase();

            // If barangay matches, return the waste type
            if (scheduleBarangay == normalizedBarangay) {
              String wasteType = data['wasteType'] ?? 'General';

              // Map database waste types to the app's waste type options
              String formattedWasteType;
              switch (wasteType) {
                case 'Biodegradable':
                  formattedWasteType = 'Biodegradable';
                  break;
                case 'Non-biodegradable':
                  formattedWasteType = 'Non-Biodegradable';
                  break;
                case 'Recyclable':
                  formattedWasteType = 'Recycables';
                  break;
                case 'General':
                default:
                  formattedWasteType = 'General Waste';
                  break;
              }

              return {'wasteType': formattedWasteType, 'hasSchedule': true};
            }
          }
        }
      }

      // No matching schedule found for today
      return {'wasteType': 'No Schedule For Today', 'hasSchedule': false};
    } catch (e) {
      print('Error getting today\'s schedule: $e');
      return {'wasteType': 'No Schedule For Today', 'hasSchedule': false};
    }
  }

  // Get scan history for a collector
  Future<List<Map<String, dynamic>>> getCollectorScanHistory() async {
    try {
      if (currentCollectorId == null) {
        return [];
      }

      print('Fetching scan history for collector: $currentCollectorId');

      final scansSnapshot = await _firestore
          .collection('scans')
          .where('collectorId', isEqualTo: currentCollectorId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      print(
          'Retrieved ${scansSnapshot.docs.length} scan records from Firestore');

      List<Map<String, dynamic>> scansData = [];
      for (var doc in scansSnapshot.docs) {
        Map<String, dynamic> data = doc.data();

        // Debug data coming back from Firestore
        print(
            'Scan record found: ID=${doc.id}, residentName=${data['residentName']}, '
            'timestamp=${data['timestamp']}');

        // Convert Firestore timestamp to DateTime for display
        if (data['timestamp'] is Timestamp) {
          final timestamp = data['timestamp'] as Timestamp;
          data['timestampFormatted'] = timestamp.toDate().toString();
        } else if (data['timestamp'] == null) {
          // For brand new records where server timestamp hasn't been set yet
          print('Timestamp is null for record ${doc.id}, using current time');
          data['timestampFormatted'] = DateTime.now().toString();
        }

        scansData.add({
          'id': doc.id,
          ...data,
        });
      }

      return scansData;
    } catch (e) {
      print('Error getting scan history: $e');
      return [];
    }
  }

  // Get total number of scans by collector
  Future<int> getTotalScans() async {
    try {
      if (currentCollectorId == null) {
        return 0;
      }

      final scansSnapshot = await _firestore
          .collection('scans')
          .where('collectorId', isEqualTo: currentCollectorId)
          .count()
          .get();

      return scansSnapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Calculate points based on reward matrix
  Future<int> _calculatePointsFromMatrix(
      String barangayId, double weight) async {
    try {
      print('Calculating points for barangay: $barangayId, weight: $weight kg');

      // Query reward_matrix collection for matching barangay entries
      final matrixSnap = await _firestore
          .collection('reward_matrix')
          .where('barangayId', isEqualTo: barangayId)
          .orderBy('minKg', descending: false)
          .get();

      // If no entries found, return 0 points (no fallback calculation)
      if (matrixSnap.docs.isEmpty) {
        print(
            'No reward matrix found for barangay $barangayId, returning 0 points');
        return 0;
      }

      print(
          'Found ${matrixSnap.docs.length} reward matrix entries for $barangayId');

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
        int points = 0;

        try {
          // Parse minKg
          if (data['minKg'] != null) {
            if (data['minKg'] is int) {
              minKg = (data['minKg'] as int).toDouble();
            } else if (data['minKg'] is double) {
              minKg = data['minKg'] as double;
            } else {
              minKg = double.tryParse(data['minKg'].toString()) ?? 0;
            }
          }

          // Parse maxKg
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

          // Parse points
          if (data['points'] != null) {
            if (data['points'] is int) {
              points = data['points'] as int;
            } else if (data['points'] is double) {
              points = (data['points'] as double).round();
            } else {
              int? parsedPoints = int.tryParse(data['points'].toString());
              if (parsedPoints != null) {
                points = parsedPoints;
              } else {
                double? parsedDoublePoints =
                    double.tryParse(data['points'].toString());
                if (parsedDoublePoints != null) {
                  points = parsedDoublePoints.round();
                }
              }
            }
          }

          print('Checking if weight $weight is in range: $minKg-$maxKg kg');

          // Check if weight falls within the range
          if (weight >= minKg && weight <= maxKg) {
            print(
                'MATCH FOUND: $weight kg is in range $minKg-$maxKg kg = $points points');
            return points;
          } else {
            print('No match: $weight kg is not in range $minKg-$maxKg kg');
          }
        } catch (e) {
          print('Error parsing matrix values: $e');
          continue; // Skip this entry if there's a parsing error
        }
      }

      // If no range match found, return 0 points
      print(
          'No matching weight range found in reward matrix, returning 0 points');
      return 0;
    } catch (e) {
      print('Error calculating points from matrix: $e');
      // Return 0 points in case of error
      return 0;
    }
  }

  // Public method to calculate points from the reward matrix
  Future<int> calculateRewardPoints({
    required String barangayId,
    required double weight,
  }) async {
    return _calculatePointsFromMatrix(barangayId, weight);
  }

  // Submit a new scan with garbage collection details
  Future<Map<String, dynamic>> submitScan({
    required String residentId,
    required String residentName,
    required String garbageType,
    required double garbageWeight,
    required String barangay,
    required String purok,
    bool hasFailedToContribute = false,
    bool hasNotSegregated = false,
    bool hasNoContributions = false,
  }) async {
    try {
      // Validate collector is logged in
      if (currentCollectorId == null) {
        return {
          'success': false,
          'message': 'Collector not authenticated. Please log in again.',
        };
      }

      // Check if there's a schedule for today
      var scheduleResult = await _getTodayScheduledWasteType(barangay);
      bool hasScheduleToday = scheduleResult['hasSchedule'];

      // If no schedule for today, prevent submission
      if (!hasScheduleToday) {
        return {
          'success': false,
          'message':
              'No waste collection scheduled for today. Cannot submit scan.',
          'noSchedule': true
        };
      }

      // If garbage type is "No Schedule For Today", prevent submission
      if (garbageType == 'No Schedule For Today') {
        return {
          'success': false,
          'message':
              'No waste collection scheduled for today. Cannot submit scan.',
          'noSchedule': true
        };
      }

      print('Submitting scan for resident: $residentName, ID: $residentId');

      // Get the current date (normalized to remove time component)
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);

      // Check if this resident has already been scanned today for the same waste type
      final QuerySnapshot existingScansSnapshot = await _firestore
          .collection('scans')
          .where('residentId', isEqualTo: residentId)
          .where('garbageType', isEqualTo: garbageType)
          .get();

      // Go through results and check if any are from today
      bool alreadyScannedToday = false;
      if (existingScansSnapshot.docs.isNotEmpty) {
        for (var doc in existingScansSnapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
            DateTime scanDate = (data['timestamp'] as Timestamp).toDate();
            DateTime normalizedScanDate =
                DateTime(scanDate.year, scanDate.month, scanDate.day);

            if (normalizedScanDate.isAtSameMomentAs(today)) {
              alreadyScannedToday = true;
              print(
                  'Resident already scanned today for this waste type: ${doc.id}');
              break;
            }
          }
        }
      }

      // If already scanned today for this waste type, prevent duplicate submission
      if (alreadyScannedToday) {
        return {
          'success': false,
          'message':
              'This resident has already been scanned today for $garbageType waste.',
          'alreadyScanned': true
        };
      }

      // Get collector data for storing name and double check barangay
      String collectorName = 'Unknown Collector';
      String collectorBarangay = barangay;
      try {
        final collectorDoc = await _firestore
            .collection('collector')
            .doc(currentCollectorId)
            .get();
        if (collectorDoc.exists) {
          final collectorData = collectorDoc.data() as Map<String, dynamic>?;
          if (collectorData != null) {
            collectorName = collectorData['fullName'] ?? 'Unknown Collector';
            collectorBarangay = collectorData['barangay'] ?? barangay;
          }
        }
      } catch (e) {
        print('Error fetching collector data: $e');
      }

      // Calculate points using the reward matrix instead of fixed formula
      final int pointsAwarded =
          await _calculatePointsFromMatrix(collectorBarangay, garbageWeight);

      // Create scan document
      final scanData = {
        'residentId': residentId,
        'residentName': residentName,
        'garbageType': garbageType,
        'garbageWeight': garbageWeight,
        'pointsAwarded': pointsAwarded,
        'barangay': barangay,
        'purok': purok,
        'collectorId': currentCollectorId,
        'collectorName': collectorName,
        'timestamp': FieldValue.serverTimestamp(),
        'timestampFormatted': now.toString(),
        'status': 'completed',
        // Add warning and penalty information
        'warnings': {
          'failedToContribute': hasFailedToContribute,
        },
        'penalties': {
          'notSegregated': hasNotSegregated,
          'noContributions': hasNoContributions,
        }
      };

      // Add to scans collection
      DocumentReference scanRef =
          await _firestore.collection('scans').add(scanData);

      print('Scan saved successfully with ID: ${scanRef.id}');

      // Get resident's current points before update
      DocumentSnapshot residentDoc =
          await _firestore.collection('resident').doc(residentId).get();
      int currentPoints = 0;
      int currentWarnings = 0;
      int currentPenalties = 0;
      if (residentDoc.exists) {
        Map<String, dynamic>? residentData =
            residentDoc.data() as Map<String, dynamic>?;
        if (residentData != null) {
          currentPoints = residentData['points'] ?? 0;
          currentWarnings = residentData['warnings'] ?? 0;
          currentPenalties = residentData['penalties'] ?? 0;
        }
      }

      // Calculate warnings and penalties to add
      int warningsToAdd = hasFailedToContribute ? 1 : 0;
      int penaltiesToAdd =
          (hasNotSegregated ? 1 : 0) + (hasNoContributions ? 1 : 0);

      // Update resident points, warnings, and penalties
      await _firestore.collection('resident').doc(residentId).update({
        'points': FieldValue.increment(pointsAwarded),
        'lastScanTimestamp': now,
        'totalScans': FieldValue.increment(1),
        'warnings': FieldValue.increment(warningsToAdd),
        'penalties': FieldValue.increment(penaltiesToAdd),
      });

      return {
        'success': true,
        'message': 'Scan submitted successfully',
        'scanId': scanRef.id,
        'pointsAwarded': pointsAwarded,
        'previousPoints': currentPoints,
        'newTotalPoints': currentPoints + pointsAwarded,
        'warningsAdded': warningsToAdd,
        'previousWarnings': currentWarnings,
        'newTotalWarnings': currentWarnings + warningsToAdd,
        'penaltiesAdded': penaltiesToAdd,
        'previousPenalties': currentPenalties,
        'newTotalPenalties': currentPenalties + penaltiesToAdd,
        'pointsCalculation': {
          'weight': garbageWeight,
          'fromRewardMatrix': true,
          'collectorBarangay': collectorBarangay,
        },
        'wasteType': garbageType,
      };
    } catch (e) {
      print('Error submitting scan: $e');
      return {
        'success': false,
        'message': 'Error submitting scan: $e',
      };
    }
  }
}
