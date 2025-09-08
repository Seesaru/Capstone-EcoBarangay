import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ResidentScansChart extends StatelessWidget {
  final Map<String, int> dailyScansCount;
  final String selectedTimeFilter;
  final String? selectedMonth;
  final bool isLoading;
  final Color accentColor;
  final Color textSecondaryColor;

  const ResidentScansChart({
    Key? key,
    required this.dailyScansCount,
    required this.selectedTimeFilter,
    this.selectedMonth,
    required this.isLoading,
    required this.accentColor,
    required this.textSecondaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scanData = <FlSpot>[];
    DateTime startDate = _getStartDate(selectedTimeFilter);
    DateTime endDate = _getEndDate(selectedTimeFilter);

    // Filter and process scan data
    List<MapEntry<String, int>> filteredScans =
        dailyScansCount.entries.where((entry) {
      if (entry.value <= 0) return false;
      try {
        DateTime scanDate = DateFormat('MMM d, yyyy').parse(entry.key);
        return scanDate.isAfter(startDate.subtract(Duration(days: 1))) &&
            scanDate.isBefore(endDate.add(Duration(days: 1)));
      } catch (e) {
        print('Invalid date format: ${entry.key}');
        return false;
      }
    }).toList();

    // Sort by date
    try {
      filteredScans.sort((a, b) {
        try {
          DateTime dateA = DateFormat('MMM d, yyyy').parse(a.key);
          DateTime dateB = DateFormat('MMM d, yyyy').parse(b.key);
          return dateA.compareTo(dateB);
        } catch (e) {
          return 0;
        }
      });
    } catch (e) {
      print('Error during sort: $e');
    }

    // Create chart data
    for (int i = 0; i < filteredScans.length; i++) {
      scanData.add(FlSpot(i.toDouble(), filteredScans[i].value.toDouble()));
    }

    // Calculate statistics
    int totalScans = filteredScans.fold(0, (sum, entry) => sum + entry.value);
    double averageScans = totalScans > 0 ? totalScans / filteredScans.length : 0;
    int maxScans = filteredScans.isNotEmpty 
        ? filteredScans.map((e) => e.value).reduce((a, b) => a > b ? a : b) 
        : 0;
    int minScans = filteredScans.isNotEmpty 
        ? filteredScans.map((e) => e.value).reduce((a, b) => a < b ? a : b) 
        : 0;

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withOpacity(0.05),
                  accentColor.withOpacity(0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getDynamicTitle(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getSubtitle(),
                            style: TextStyle(
                              fontSize: 14,
                              color: textSecondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accentColor, accentColor.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.3),
                            spreadRadius: 0,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.trending_up_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$totalScans',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Statistics Row
                if (filteredScans.isNotEmpty)
                  Row(
                    children: [
                      _buildStatCard('Avg', averageScans.toStringAsFixed(1), Icons.timeline_rounded),
                      const SizedBox(width: 12),
                      _buildStatCard('Max', maxScans.toString(), Icons.keyboard_arrow_up_rounded),
                      const SizedBox(width: 12),
                      _buildStatCard('Min', minScans.toString(), Icons.keyboard_arrow_down_rounded),
                      const SizedBox(width: 12),
                      _buildStatCard('Days', filteredScans.length.toString(), Icons.calendar_today_rounded),
                    ],
                  ),
              ],
            ),
          ),
          
          // Chart Section
          Container(
            height: 300,
            padding: const EdgeInsets.all(20),
            child: scanData.isEmpty
                ? _buildEmptyState()
                : AnimatedOpacity(
                    opacity: isLoading ? 0.3 : 1.0,
                    duration: const Duration(milliseconds: 500),
                    child: LineChart(
                      LineChartData(
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            tooltipBgColor: Colors.grey.shade900,
                            tooltipRoundedRadius: 12,
                            tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            tooltipMargin: 16,
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItems: (List<LineBarSpot> touchedSpots) {
                              return touchedSpots.map((spot) {
                                final dayIndex = spot.x.toInt();
                                if (dayIndex >= 0 && dayIndex < filteredScans.length) {
                                  final dayData = filteredScans[dayIndex];
                                  try {
                                    final date = DateFormat('MMM d, yyyy').parse(dayData.key);
                                    return LineTooltipItem(
                                      DateFormat('MMM d, yyyy').format(date),
                                      const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: '\n${spot.y.toInt()} scans',
                                          style: TextStyle(
                                            color: accentColor.withOpacity(0.9),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    );
                                  } catch (e) {
                                    return LineTooltipItem('', const TextStyle());
                                  }
                                }
                                return LineTooltipItem('', const TextStyle());
                              }).toList();
                            },
                          ),
                          handleBuiltInTouches: true,
                          touchSpotThreshold: 50,
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: _getGridInterval(maxScans),
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.withOpacity(0.1),
                              strokeWidth: 1,
                              dashArray: [5, 5],
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              interval: _getBottomInterval(filteredScans.length),
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < filteredScans.length) {
                                  try {
                                    final date = DateFormat('MMM d, yyyy').parse(filteredScans[index].key);
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        DateFormat('MMM d').format(date),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 11,
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    return const SizedBox.shrink();
                                  }
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 45,
                              interval: _getGridInterval(maxScans),
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    value.toInt().toString(),
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.withOpacity(0.2),
                              width: 1.5,
                            ),
                            left: BorderSide(
                              color: Colors.grey.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                        ),
                        minX: 0,
                        maxX: (scanData.length - 1).toDouble(),
                        minY: 0,
                        maxY: maxScans.toDouble() * 1.2,
                        lineBarsData: [
                          LineChartBarData(
                            spots: scanData,
                            isCurved: true,
                            curveSmoothness: 0.35,
                            color: accentColor,
                            barWidth: 3.5,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 6,
                                  color: accentColor,
                                  strokeWidth: 3,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  accentColor.withOpacity(0.4),
                                  accentColor.withOpacity(0.2),
                                  accentColor.withOpacity(0.05),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            shadow: Shadow(
                              blurRadius: 12,
                              color: accentColor.withOpacity(0.25),
                              offset: const Offset(0, 6),
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

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.grey.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: accentColor.withOpacity(0.8),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: textSecondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.analytics_outlined,
              size: 48,
              color: textSecondaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No scan data available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Data will appear here once scans are recorded',
            style: TextStyle(
              fontSize: 14,
              color: textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  double _getGridInterval(int maxValue) {
    if (maxValue <= 5) return 1;
    if (maxValue <= 10) return 2;
    if (maxValue <= 25) return 5;
    if (maxValue <= 50) return 10;
    if (maxValue <= 100) return 20;
    return (maxValue / 5).ceil().toDouble();
  }

  double _getBottomInterval(int dataLength) {
    if (dataLength <= 7) return 1;
    if (dataLength <= 15) return 2;
    if (dataLength <= 30) return 5;
    return (dataLength / 6).ceil().toDouble();
  }

  String _getSubtitle() {
    try {
      if (selectedTimeFilter == 'Select Month' && selectedMonth != null) {
        return 'Daily scan activity for selected month';
      } else if (selectedTimeFilter == 'This Week') {
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(Duration(days: 6));
        return '${DateFormat('MMM d').format(startOfWeek)} - ${DateFormat('MMM d, yyyy').format(endOfWeek)}';
      } else if (selectedTimeFilter == 'This Month') {
        return DateFormat('MMMM yyyy').format(DateTime.now());
      } else if (selectedTimeFilter == 'This Year') {
        return 'Scan activity throughout ${DateTime.now().year}';
      } else if (selectedTimeFilter == 'All Time') {
        return 'Complete scan history';
      } else {
        return 'Resident scan analytics';
      }
    } catch (e) {
      return 'Resident scan analytics';
    }
  }

  DateTime _getStartDate(String timeFilter) {
    try {
      final now = DateTime.now();
      if (timeFilter == 'Select Month' && selectedMonth != null) {
        final dt = DateFormat('MMM yyyy').parse(selectedMonth!);
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
          return DateTime(2000);
        default:
          return DateTime(now.year, now.month, 1);
      }
    } catch (e) {
      return DateTime.now().subtract(Duration(days: 30));
    }
  }

  DateTime _getEndDate(String timeFilter) {
    try {
      final now = DateTime.now();
      if (timeFilter == 'Select Month' && selectedMonth != null) {
        final dt = DateFormat('MMM yyyy').parse(selectedMonth!);
        return DateTime(dt.year, dt.month + 1, 0);
      }
      switch (timeFilter) {
        case 'This Week':
          return now.add(Duration(days: 7 - now.weekday));
        case 'This Month':
          return DateTime(now.year, now.month + 1, 0);
        case 'This Year':
          return DateTime(now.year, 12, 31);
        case 'All Time':
          return now;
        default:
          return DateTime(now.year, now.month + 1, 0);
      }
    } catch (e) {
      return DateTime.now();
    }
  }

  String _getDynamicTitle() {
    try {
      if (selectedTimeFilter == 'Select Month' && selectedMonth != null) {
        return 'Daily Resident Scans';
      } else if (selectedTimeFilter == 'This Week') {
        return 'Weekly Resident Scans';
      } else if (selectedTimeFilter == 'This Month') {
        return 'Monthly Resident Scans';
      } else if (selectedTimeFilter == 'This Year') {
        return 'Yearly Resident Scans';
      } else if (selectedTimeFilter == 'All Time') {
        return 'All-Time Resident Scans';
      } else {
        return 'Resident Scans';
      }
    } catch (e) {
      return 'Resident Scans';
    }
  }
}