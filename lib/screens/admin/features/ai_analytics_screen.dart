import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'ai_analytics.dart';

class AIAnalyticsScreen extends StatefulWidget {
  final String adminBarangay;

  const AIAnalyticsScreen({
    Key? key,
    required this.adminBarangay,
  }) : super(key: key);

  @override
  State<AIAnalyticsScreen> createState() => _AIAnalyticsScreenState();
}

class _AIAnalyticsScreenState extends State<AIAnalyticsScreen> {
  late AIAnalyticsService _aiService;
  bool _isAnalyzing = false;
  String? _errorMessage;
  int _currentTabIndex = 0;

  final Color primaryColor = const Color(0xFF2E7D32);
  final Color backgroundColor = const Color(0xFFF5F7FA);
  final Color cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _aiService = AIAnalyticsService();
    _aiService.adminBarangay = widget.adminBarangay;
    _generateAIAnalysis();
  }

  Future<void> _generateAIAnalysis() async {
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      print('Starting AI analysis for barangay: ${widget.adminBarangay}');
      final result = await _aiService.generateAIAnalysis();
      print('AI analysis result: $result');

      setState(() {
        _isAnalyzing = false;
        if (result['success'] != true) {
          _errorMessage = result['error'] ?? 'Analysis failed';
          print('AI analysis failed: $_errorMessage');
        } else {
          print('AI analysis completed successfully');
          print('Recommendations: ${_aiService.aiRecommendations}');
          print('Predictions: ${_aiService.aiPredictions}');
          print('Insights: ${_aiService.aiInsights}');

          // Debug formatted data
          final formattedRecs = _aiService.getFormattedRecommendations();
          final formattedPreds = _aiService.getFormattedPredictions();
          final formattedInsights = _aiService.getFormattedInsights();

          print('Formatted recommendations count: ${formattedRecs.length}');
          print('Formatted predictions: $formattedPreds');
          print('Formatted insights: $formattedInsights');
        }
      });
    } catch (e) {
      print('Error in AI analysis: $e');
      setState(() {
        _isAnalyzing = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title:
            const Text('AI Analytics', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isAnalyzing ? null : _generateAIAnalysis,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [primaryColor, primaryColor.withOpacity(0.8)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.psychology, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI-Powered Insights',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Intelligent recommendations for ${widget.adminBarangay}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.9), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isAnalyzing) ...[
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                ),
                const SizedBox(width: 12),
                Text('Analyzing data with AI...',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.9), fontSize: 14)),
              ],
            ),
          ] else if (_errorMessage != null) ...[
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(_errorMessage!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14))),
              ],
            ),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Analysis complete - ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9), fontSize: 14),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: cardColor,
      child: Row(
        children: [
          _buildTabButton('Recommendations', 0, Icons.lightbulb_outline),
          _buildTabButton('Predictions', 1, Icons.trending_up),
          _buildTabButton('Insights', 2, Icons.analytics),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index, IconData icon) {
    final isSelected = _currentTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: isSelected ? primaryColor : Colors.transparent,
                    width: 3)),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? primaryColor : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? primaryColor : Colors.grey,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_isAnalyzing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text('AI is analyzing your data...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: Colors.red.withOpacity(0.7)),
            const SizedBox(height: 16),
            Text('Analysis Failed',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _generateAIAnalysis,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    switch (_currentTabIndex) {
      case 0:
        return _buildRecommendationsTab();
      case 1:
        return _buildPredictionsTab();
      case 2:
        return _buildInsightsTab();
      default:
        return _buildRecommendationsTab();
    }
  }

  Widget _buildRecommendationsTab() {
    final recommendations = _aiService.getFormattedRecommendations();

    print('Building recommendations tab with ${recommendations.length} items');
    print('Raw AI recommendations: ${_aiService.aiRecommendations}');

    if (recommendations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline,
                size: 48, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('No recommendations available'),
            const SizedBox(height: 8),
            Text(
              'AI analysis may still be processing or there was an issue with the response.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _generateAIAnalysis,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Analysis'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: recommendations.length,
      itemBuilder: (context, index) {
        final rec = recommendations[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(rec['icon'], color: rec['color'], size: 20),
                  const SizedBox(width: 8),
                  Text(rec['category'],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          _getPriorityColor(rec['priority']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      rec['priority'],
                      style: TextStyle(
                          color: _getPriorityColor(rec['priority']),
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(rec['recommendation'], style: const TextStyle(fontSize: 16)),
              if (rec['expectedImpact'] != null &&
                  rec['expectedImpact'].isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Expected Impact: ${rec['expectedImpact']}',
                    style: TextStyle(color: Colors.blue.shade700)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPredictionsTab() {
    final predictions = _aiService.getFormattedPredictions();

    if (predictions.isEmpty) {
      return const Center(
        child: Text('No predictions available'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection('Volume Predictions', predictions['volumePredictions']),
        _buildSection('Trend Analysis', [predictions['trendAnalysis']]),
        _buildSection('Challenges', predictions['challenges']),
        _buildSection('Opportunities', predictions['opportunities']),
      ],
    );
  }

  Widget _buildInsightsTab() {
    final insights = _aiService.getFormattedInsights();

    if (insights.isEmpty) {
      return const Center(
        child: Text('No insights available'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection('Patterns', insights['patterns']),
        _buildSection('Hotspots', insights['hotspots']),
        _buildSection('Efficiency Insights', insights['efficiencyInsights']),
        _buildSection('Anomalies', insights['anomalies']),
      ],
    );
  }

  Widget _buildSection(String title, List<dynamic> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...data.map((item) => _buildDataItem(item)).toList(),
        ],
      ),
    );
  }

  Widget _buildDataItem(dynamic item) {
    if (item == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...item.entries.map((entry) {
            if (entry.value == null || entry.value.toString().isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${entry.key}: ',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Expanded(child: Text(entry.value.toString())),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
