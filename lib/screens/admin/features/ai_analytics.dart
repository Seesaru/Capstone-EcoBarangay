import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AIAnalyticsService {
  // Data storage
  Map<String, double> wasteTypeData = {};
  Map<String, double> monthlyCollectionData = {};
  Map<String, double> purokCollectionData = {};
  List<Map<String, dynamic>> recentCollections = [];
  double totalWasteCollected = 0;
  int totalCollections = 0;
  String adminBarangay = '';

  // AI analysis results
  Map<String, dynamic> aiRecommendations = {};
  Map<String, dynamic> aiPredictions = {};
  Map<String, dynamic> aiInsights = {};
  bool isAnalyzing = false;
  String? analysisError;

  Future<Map<String, dynamic>> generateAIAnalysis() async {
    isAnalyzing = true;
    analysisError = null;

    try {
      // Fetch fresh data from Firestore
      await _fetchLatestDataFromFirestore();

      final analysisData = _prepareAnalysisData();

      aiRecommendations = await _generateRecommendations(analysisData);
      aiPredictions = await _generatePredictions(analysisData);
      aiInsights = await _generateInsights(analysisData);

      return {
        'recommendations': aiRecommendations,
        'predictions': aiPredictions,
        'insights': aiInsights,
        'success': true,
      };
    } catch (e) {
      analysisError = e.toString();
      return {'error': e.toString(), 'success': false};
    } finally {
      isAnalyzing = false;
    }
  }

  Future<void> _fetchLatestDataFromFirestore() async {
    try {
      print('Fetching latest data from Firestore for barangay: $adminBarangay');

      // Get all scans for this barangay
      final QuerySnapshot scansSnapshot = await FirebaseFirestore.instance
          .collection('scans')
          .where('barangay', isEqualTo: adminBarangay)
          .orderBy('timestamp', descending: true)
          .get();

      print('Found ${scansSnapshot.docs.length} scans in Firestore');

      // Reset data
      wasteTypeData = {
        'Biodegradable': 0.0,
        'Non-Biodegradable': 0.0,
        'Recyclables': 0.0,
        'General Waste': 0.0,
      };
      monthlyCollectionData = {};
      purokCollectionData = {};
      recentCollections = [];
      totalWasteCollected = 0;
      totalCollections = 0;

      // Process each scan
      for (var doc in scansSnapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          if (data['timestamp'] == null) continue;

          DateTime scanDate = (data['timestamp'] as Timestamp).toDate();
          String rawWasteType = data['garbageType'] ?? 'General Waste';
          double weight = (data['garbageWeight'] ?? 0).toDouble();
          String purok = data['purok'] ?? 'Unknown';

          // Standardize waste type
          String standardizedWasteType = _standardizeWasteType(rawWasteType);

          // Update waste type data
          wasteTypeData[standardizedWasteType] =
              (wasteTypeData[standardizedWasteType] ?? 0.0) + weight;

          // Update monthly data
          String monthKey = DateFormat('MMM yyyy').format(scanDate);
          monthlyCollectionData[monthKey] =
              (monthlyCollectionData[monthKey] ?? 0.0) + weight;

          // Update purok data
          purokCollectionData[purok] =
              (purokCollectionData[purok] ?? 0.0) + weight;

          // Update totals
          totalWasteCollected += weight;
          totalCollections++;

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

          // Add to recent collections (last 50 for AI analysis)
          if (recentCollections.length < 50) {
            recentCollections.add({
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
          }
        } catch (e) {
          print('Error processing scan document: $e');
          continue;
        }
      }

      print(
          'Processed data: $totalCollections collections, ${totalWasteCollected.toStringAsFixed(1)} kg total waste');
      print('Waste types: $wasteTypeData');
      print('Puroks: ${purokCollectionData.keys.length} puroks');
    } catch (e) {
      print('Error fetching data from Firestore: $e');
      throw Exception('Failed to fetch data from Firestore: $e');
    }
  }

  String _standardizeWasteType(String rawWasteType) {
    final lowerCase = rawWasteType.toLowerCase();
    if (lowerCase.contains('bio') && !lowerCase.contains('non')) {
      return 'Biodegradable';
    }
    if (lowerCase.contains('non') || lowerCase.contains('non-bio')) {
      return 'Non-Biodegradable';
    }
    if (lowerCase.contains('recycl')) {
      return 'Recyclables';
    }
    return 'General Waste';
  }

  Map<String, dynamic> _prepareAnalysisData() {
    final avgWastePerCollection =
        totalCollections > 0 ? totalWasteCollected / totalCollections : 0;
    final sortedWasteTypes = wasteTypeData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedPuroks = purokCollectionData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final monthlyTrends = _calculateMonthlyTrends();
    final warningStats = _calculateWarningStats();

    return {
      'barangay': adminBarangay.isNotEmpty ? adminBarangay : 'Unknown',
      'totalWasteCollected': totalWasteCollected,
      'totalCollections': totalCollections,
      'avgWastePerCollection': avgWastePerCollection,
      'wasteTypeDistribution':
          wasteTypeData.isNotEmpty ? wasteTypeData : {'No Data': 0.0},
      'topWasteTypes': sortedWasteTypes.isNotEmpty
          ? sortedWasteTypes
              .take(3)
              .map((e) => {'key': e.key, 'value': e.value})
              .toList()
          : [],
      'purokDistribution': purokCollectionData.isNotEmpty
          ? purokCollectionData
          : {'No Data': 0.0},
      'topPuroks': sortedPuroks.isNotEmpty
          ? sortedPuroks
              .take(3)
              .map((e) => {'key': e.key, 'value': e.value})
              .toList()
          : [],
      'monthlyTrends': monthlyTrends.isNotEmpty
          ? monthlyTrends
          : {
              'trend': 0.0,
              'trendDirection': 'stable',
              'recentAverage': 0.0,
              'olderAverage': 0.0,
              'monthlyData': {}
            },
      'warningStats': warningStats.isNotEmpty
          ? warningStats
          : {
              'totalWarnings': 0,
              'totalPenalties': 0,
              'warningRate': 0.0,
              'penaltyRate': 0.0
            },
      'recentCollections': recentCollections.isNotEmpty
          ? recentCollections.take(10).toList()
          : [],
    };
  }

  Map<String, dynamic> _calculateMonthlyTrends() {
    if (monthlyCollectionData.isEmpty) return {};

    final sortedMonths = monthlyCollectionData.entries.toList()
      ..sort((a, b) {
        final dateA = DateFormat('MMM yyyy').parse(a.key);
        final dateB = DateFormat('MMM yyyy').parse(b.key);
        return dateA.compareTo(dateB);
      });

    if (sortedMonths.length < 2) return {};

    final recentMonths = sortedMonths.take(3).toList();
    final totalRecent =
        recentMonths.fold(0.0, (sum, entry) => sum + entry.value);
    final avgRecent = totalRecent / recentMonths.length;

    final olderMonths = sortedMonths.skip(3).take(3).toList();
    final totalOlder = olderMonths.fold(0.0, (sum, entry) => sum + entry.value);
    final avgOlder = olderMonths.isEmpty ? 0 : totalOlder / olderMonths.length;

    final trend = avgOlder > 0 ? ((avgRecent - avgOlder) / avgOlder) * 100 : 0;

    return {
      'trend': trend,
      'trendDirection': trend > 0
          ? 'increasing'
          : trend < 0
              ? 'decreasing'
              : 'stable',
      'recentAverage': avgRecent,
      'olderAverage': avgOlder,
      'monthlyData': monthlyCollectionData,
    };
  }

  Map<String, dynamic> _calculateWarningStats() {
    int totalWarnings = 0;
    int totalPenalties = 0;

    for (final collection in recentCollections) {
      if (collection['hasWarnings'] == true) totalWarnings++;
      if (collection['hasPenalties'] == true) totalPenalties++;
    }

    return {
      'totalWarnings': totalWarnings,
      'totalPenalties': totalPenalties,
      'warningRate':
          totalCollections > 0 ? (totalWarnings / totalCollections) * 100 : 0,
      'penaltyRate':
          totalCollections > 0 ? (totalPenalties / totalCollections) * 100 : 0,
    };
  }

  Future<Map<String, dynamic>> _generateRecommendations(
      Map<String, dynamic> data) async {
    final prompt = '''
You are an AI waste management consultant for ${data['barangay'] ?? 'Unknown'} barangay. Based on this real-time data from the scans collection, provide actionable recommendations:

CURRENT DATA ANALYSIS:
- Total waste collected: ${data['totalWasteCollected'] ?? 0} kg from ${data['totalCollections'] ?? 0} collections
- Average per collection: ${(data['avgWastePerCollection'] ?? 0).toStringAsFixed(1)} kg
- Waste composition: ${data['wasteTypeDistribution']}
- Geographic distribution: ${data['purokDistribution']}
- Monthly trends: ${data['monthlyTrends']?['trendDirection'] ?? 'stable'} (${(data['monthlyTrends']?['trend'] ?? 0).toStringAsFixed(1)}% change)
- Compliance issues: ${(data['warningStats']?['warningRate'] ?? 0).toStringAsFixed(1)}% warning rate, ${(data['warningStats']?['penaltyRate'] ?? 0).toStringAsFixed(1)}% penalty rate

RECENT COLLECTION PATTERNS:
${(data['recentCollections'] as List?)?.take(5).map((c) => '- ${c['residentName']}: ${c['weight']} kg ${c['wasteType']} from ${c['purok']} (${c['hasWarnings'] ? 'Has warnings' : 'No issues'})').join('\n') ?? 'No recent data'}

Provide specific, data-driven recommendations in this JSON format:
{
  "wasteReduction": [{"recommendation": "Specific action based on waste composition", "priority": "High/Medium/Low", "expectedImpact": "Quantified impact"}],
  "efficiency": [{"recommendation": "Route optimization or process improvement", "priority": "High/Medium/Low", "expectedImpact": "Expected efficiency gain"}],
  "compliance": [{"recommendation": "Address specific compliance issues found", "priority": "High/Medium/Low", "expectedImpact": "Reduction in violations"}],
  "sustainability": [{"recommendation": "Long-term environmental improvement", "priority": "High/Medium/Low", "expectedImpact": "Environmental benefit"}]
}
''';

    return await _callGeminiAPI(prompt);
  }

  Future<Map<String, dynamic>> _generatePredictions(
      Map<String, dynamic> data) async {
    final prompt = '''
You are an AI waste management analyst predicting trends for ${data['barangay'] ?? 'Unknown'} barangay. Based on this real-time data from the scans collection, predict the next 3 months:

HISTORICAL ANALYSIS:
- Monthly data: ${data['monthlyTrends']?['monthlyData'] ?? 'No historical data available'}
- Current trend: ${data['monthlyTrends']?['trendDirection'] ?? 'stable'} (${(data['monthlyTrends']?['trend'] ?? 0).toStringAsFixed(1)}% change)
- Recent average: ${(data['monthlyTrends']?['recentAverage'] ?? 0).toStringAsFixed(1)} kg per month
- Total collections: ${data['totalCollections'] ?? 0} over time period
- Waste composition trends: ${data['wasteTypeDistribution']}

RECENT PATTERNS:
- Average collection weight: ${(data['avgWastePerCollection'] ?? 0).toStringAsFixed(1)} kg
- Geographic distribution: ${data['purokDistribution']}
- Compliance rate: ${100 - (data['warningStats']?['warningRate'] ?? 0).toDouble()}% (${(data['warningStats']?['warningRate'] ?? 0).toStringAsFixed(1)}% warnings)

Provide data-driven predictions in this JSON format:
{
  "volumePredictions": [{"month": "Next Month", "predictedVolume": "X kg", "confidence": "High/Medium/Low", "reasoning": "Based on..."}],
  "trendAnalysis": {"expectedDirection": "increasing/decreasing/stable", "confidence": "High/Medium/Low", "factors": "Key factors influencing trend"},
  "challenges": [{"challenge": "Specific challenge based on data", "probability": "High/Medium/Low", "impact": "Expected impact"}],
  "opportunities": [{"opportunity": "Specific opportunity identified", "potential": "High/Medium/Low", "timeline": "When to implement"}]
}
''';

    return await _callGeminiAPI(prompt);
  }

  Future<Map<String, dynamic>> _generateInsights(
      Map<String, dynamic> data) async {
    final prompt = '''
You are an AI waste management expert providing insights for ${data['barangay'] ?? 'Unknown'} barangay. Analyze this real-time data from the scans collection:

COMPREHENSIVE DATA ANALYSIS:
- Waste composition: ${data['wasteTypeDistribution'] ?? 'No waste data available'}
- Geographic distribution: ${data['purokDistribution'] ?? 'No geographic data available'}
- Temporal patterns: ${data['monthlyTrends'] ?? 'No temporal data available'}
- Compliance metrics: ${data['warningStats'] ?? 'No compliance data available'}
- Collection efficiency: ${data['totalCollections'] ?? 0} collections, ${(data['avgWastePerCollection'] ?? 0).toStringAsFixed(1)} kg average

RECENT COLLECTION DETAILS:
${(data['recentCollections'] as List?)?.take(10).map((c) => '- ${c['date'].toString().substring(0, 10)}: ${c['residentName']} (${c['purok']}) - ${c['weight']} kg ${c['wasteType']}${c['hasWarnings'] ? ' ⚠️' : ''}${c['hasPenalties'] ? ' ❌' : ''}').join('\n') ?? 'No recent collections'}

Provide detailed, data-driven insights in this JSON format:
{
  "patterns": [{"pattern": "Specific pattern identified in data", "significance": "High/Medium/Low", "evidence": "Data points supporting pattern"}],
  "hotspots": [{"location": "Specific purok/area", "issue": "Specific problem identified", "recommendation": "Targeted solution", "severity": "High/Medium/Low"}],
  "efficiencyInsights": [{"metric": "Specific efficiency metric", "value": "Current value", "status": "Good/Fair/Poor", "benchmark": "Industry standard or target"}],
  "anomalies": [{"anomaly": "Specific unusual pattern", "possibleCause": "Root cause analysis", "action": "Immediate action required", "priority": "High/Medium/Low"}]
}
''';

    return await _callGeminiAPI(prompt);
  }

  Future<Map<String, dynamic>> _callGeminiAPI(String prompt) async {
    try {
      const String geminiApiKey = 'AIzaSyA52Ezw9pMm8Mr9tdpToFAU8vxuwlZufVQ';
      const String geminiApiUrl =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

      print('Calling Gemini API with URL: $geminiApiUrl');
      print('API Key: ${geminiApiKey.substring(0, 10)}...');

      final response = await http.post(
        Uri.parse('$geminiApiUrl?key=$geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 2048,
          },
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final generatedText =
            responseData['candidates'][0]['content']['parts'][0]['text'];

        try {
          final parsedResponse = jsonDecode(generatedText);
          print('Successfully parsed AI response: $parsedResponse');
          return parsedResponse;
        } catch (e) {
          print('Error parsing JSON response: $e');
          print('Raw AI response text: $generatedText');

          // Try to extract JSON from the response if it's wrapped in markdown
          try {
            final cleanText = generatedText
                .replaceAll('```json', '')
                .replaceAll('```', '')
                .trim();
            final parsedResponse = jsonDecode(cleanText);
            print('Successfully parsed cleaned AI response: $parsedResponse');
            return parsedResponse;
          } catch (e2) {
            print('Failed to parse cleaned response: $e2');
            return {
              'rawResponse': generatedText,
              'parseError': e.toString(),
            };
          }
        }
      } else {
        print('API request failed with status ${response.statusCode}');
        print('Error response: ${response.body}');
        // Fallback to sample data if API fails
        return _getFallbackRecommendations(prompt);
      }
    } catch (e) {
      print('Error calling Gemini API: $e');
      // Fallback to sample data if there's an error
      return _getFallbackRecommendations(prompt);
    }
  }

  Map<String, dynamic> _getFallbackRecommendations(String prompt) {
    final promptType = prompt.contains('recommendations')
        ? 'recommendations'
        : prompt.contains('predictions')
            ? 'predictions'
            : 'insights';
    print('Using fallback recommendations for prompt type: $promptType');

    if (prompt.contains('recommendations')) {
      return {
        "wasteReduction": [
          {
            "recommendation":
                "Implement a comprehensive recycling program with separate bins for different waste types",
            "priority": "High",
            "expectedImpact": "Reduce waste by 30% and increase recycling rates"
          },
          {
            "recommendation":
                "Launch educational campaigns about waste segregation",
            "priority": "Medium",
            "expectedImpact": "Improve compliance and reduce contamination"
          }
        ],
        "efficiency": [
          {
            "recommendation":
                "Optimize collection routes based on waste volume data",
            "priority": "High",
            "expectedImpact":
                "Reduce fuel costs and improve collection efficiency"
          },
          {
            "recommendation":
                "Implement digital tracking for collection vehicles",
            "priority": "Medium",
            "expectedImpact": "Better monitoring and route optimization"
          }
        ],
        "compliance": [
          {
            "recommendation":
                "Establish clear waste disposal guidelines for residents",
            "priority": "High",
            "expectedImpact":
                "Reduce violations and improve community cooperation"
          },
          {
            "recommendation":
                "Create incentive programs for proper waste disposal",
            "priority": "Medium",
            "expectedImpact": "Increase participation and reduce penalties"
          }
        ],
        "sustainability": [
          {
            "recommendation": "Partner with local composting facilities",
            "priority": "Medium",
            "expectedImpact": "Convert organic waste into valuable compost"
          },
          {
            "recommendation": "Explore waste-to-energy conversion options",
            "priority": "Low",
            "expectedImpact": "Generate renewable energy from waste"
          }
        ]
      };
    } else if (prompt.contains('predictions')) {
      return {
        "volumePredictions": [
          {
            "month": "Next Month",
            "predictedVolume": "150 kg",
            "confidence": "Medium"
          },
          {
            "month": "Month 2",
            "predictedVolume": "145 kg",
            "confidence": "Medium"
          },
          {"month": "Month 3", "predictedVolume": "160 kg", "confidence": "Low"}
        ],
        "trendAnalysis": {
          "expectedDirection": "stable",
          "confidence": "Medium"
        },
        "challenges": [
          {
            "challenge": "Seasonal variations in waste generation",
            "probability": "High"
          },
          {
            "challenge": "Limited recycling infrastructure",
            "probability": "Medium"
          }
        ],
        "opportunities": [
          {"opportunity": "Expand composting programs", "potential": "High"},
          {"opportunity": "Implement smart waste bins", "potential": "Medium"}
        ]
      };
    } else if (prompt.contains('insights')) {
      return {
        "patterns": [
          {
            "pattern": "Higher waste generation on weekends",
            "significance": "High"
          },
          {
            "pattern": "Biodegradable waste dominates collection",
            "significance": "Medium"
          }
        ],
        "hotspots": [
          {
            "location": "Purok 1",
            "issue": "High contamination rates",
            "recommendation": "Increase education efforts"
          },
          {
            "location": "Purok 3",
            "issue": "Irregular collection",
            "recommendation": "Optimize collection schedule"
          }
        ],
        "efficiencyInsights": [
          {"metric": "Collection Efficiency", "value": "85%", "status": "Good"},
          {"metric": "Recycling Rate", "value": "25%", "status": "Fair"}
        ],
        "anomalies": [
          {
            "anomaly": "Unusual spike in waste volume",
            "possibleCause": "Special event",
            "action": "Monitor for patterns"
          }
        ]
      };
    }

    return {};
  }

  // Getters for analysis state
  bool get isAnalysisComplete => !isAnalyzing && analysisError == null;
  bool get hasError => analysisError != null;
  String? get errorMessage => analysisError;

  // Format recommendations for UI display
  List<Map<String, dynamic>> getFormattedRecommendations() {
    print('Formatting recommendations from: $aiRecommendations');

    if (aiRecommendations.isEmpty) {
      print('No AI recommendations available');
      return [];
    }

    // Check if we have a parse error
    if (aiRecommendations.containsKey('parseError')) {
      print('AI response had parse error: ${aiRecommendations['parseError']}');
      return [];
    }

    final List<Map<String, dynamic>> formatted = [];

    if (aiRecommendations['wasteReduction'] != null) {
      for (final rec in aiRecommendations['wasteReduction']) {
        formatted.add({
          'category': 'Waste Reduction',
          'recommendation': rec['recommendation'] ?? '',
          'priority': rec['priority'] ?? 'Medium',
          'expectedImpact': rec['expectedImpact'] ?? '',
          'icon': Icons.recycling,
          'color': Colors.green,
        });
      }
    }

    if (aiRecommendations['efficiency'] != null) {
      for (final rec in aiRecommendations['efficiency']) {
        formatted.add({
          'category': 'Efficiency',
          'recommendation': rec['recommendation'] ?? '',
          'priority': rec['priority'] ?? 'Medium',
          'expectedImpact': rec['expectedImpact'] ?? '',
          'icon': Icons.speed,
          'color': Colors.blue,
        });
      }
    }

    if (aiRecommendations['compliance'] != null) {
      for (final rec in aiRecommendations['compliance']) {
        formatted.add({
          'category': 'Compliance',
          'recommendation': rec['recommendation'] ?? '',
          'priority': rec['priority'] ?? 'Medium',
          'expectedImpact': rec['expectedImpact'] ?? '',
          'icon': Icons.warning,
          'color': Colors.orange,
        });
      }
    }

    if (aiRecommendations['sustainability'] != null) {
      for (final rec in aiRecommendations['sustainability']) {
        formatted.add({
          'category': 'Sustainability',
          'recommendation': rec['recommendation'] ?? '',
          'priority': rec['priority'] ?? 'Medium',
          'expectedImpact': rec['expectedImpact'] ?? '',
          'icon': Icons.eco,
          'color': Colors.teal,
        });
      }
    }

    return formatted;
  }

  // Format predictions for UI display
  Map<String, dynamic> getFormattedPredictions() {
    if (aiPredictions.isEmpty) return {};
    return {
      'volumePredictions': aiPredictions['volumePredictions'] ?? [],
      'trendAnalysis': aiPredictions['trendAnalysis'] ?? {},
      'challenges': aiPredictions['challenges'] ?? [],
      'opportunities': aiPredictions['opportunities'] ?? [],
    };
  }

  // Format insights for UI display
  Map<String, dynamic> getFormattedInsights() {
    if (aiInsights.isEmpty) return {};
    return {
      'patterns': aiInsights['patterns'] ?? [],
      'hotspots': aiInsights['hotspots'] ?? [],
      'efficiencyInsights': aiInsights['efficiencyInsights'] ?? [],
      'anomalies': aiInsights['anomalies'] ?? [],
    };
  }
}
