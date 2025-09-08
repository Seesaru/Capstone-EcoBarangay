import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class MonthlyCollectionChart extends StatelessWidget {
  final Map<String, double> monthlyCollectionData;
  final Map<String, double> dailyScansCount;
  final String selectedTimeFilter;
  final String? selectedMonth;
  final bool isLoading;
  final VoidCallback onRefresh;
  final Color primaryColor;
  final Color textSecondaryColor;

  const MonthlyCollectionChart({
    Key? key,
    required this.monthlyCollectionData,
    required this.dailyScansCount,
    required this.selectedTimeFilter,
    this.selectedMonth,
    required this.isLoading,
    required this.onRefresh,
    required this.primaryColor,
    required this.textSecondaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Process data based on selected filter
    List<MapEntry<String, double>> processedData = _getProcessedData();

    // Calculate statistics
    double totalCollection =
        processedData.fold(0, (sum, entry) => sum + entry.value);
    double averageCollection =
        processedData.isNotEmpty ? totalCollection / processedData.length : 0;
    double maxCollection = processedData.isNotEmpty
        ? processedData.map((e) => e.value).reduce((a, b) => a > b ? a : b)
        : 0;
    double minCollection = processedData.isNotEmpty
        ? processedData.map((e) => e.value).reduce((a, b) => a < b ? a : b)
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
                  primaryColor.withOpacity(0.05),
                  primaryColor.withOpacity(0.02),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, primaryColor.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
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
                            Icons.eco_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${totalCollection.toStringAsFixed(1)} kg',
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
                if (processedData.isNotEmpty)
                  Row(
                    children: [
                      _buildStatCard(
                          'Avg',
                          '${averageCollection.toStringAsFixed(1)} kg',
                          Icons.timeline_rounded),
                      const SizedBox(width: 12),
                      _buildStatCard(
                          'Max',
                          '${maxCollection.toStringAsFixed(1)} kg',
                          Icons.keyboard_arrow_up_rounded),
                      const SizedBox(width: 12),
                      _buildStatCard(
                          'Min',
                          '${minCollection.toStringAsFixed(1)} kg',
                          Icons.keyboard_arrow_down_rounded),
                      const SizedBox(width: 12),
                      _buildStatCard('Periods', processedData.length.toString(),
                          Icons.calendar_today_rounded),
                    ],
                  ),
              ],
            ),
          ),

          // Chart Section
          Container(
            height: 300,
            padding: const EdgeInsets.all(20),
            child: processedData.isEmpty
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
                            tooltipPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            tooltipMargin: 16,
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItems: (List<LineBarSpot> touchedSpots) {
                              return touchedSpots.map((spot) {
                                final index = spot.x.toInt();
                                if (index >= 0 &&
                                    index < processedData.length) {
                                  final dataEntry = processedData[index];
                                  String displayLabel = dataEntry.key;
                                  String unit = 'kg';

                                  // Format display for daily vs monthly data
                                  if (selectedTimeFilter == 'Select Month' &&
                                      selectedMonth != null) {
                                    try {
                                      final date = DateFormat('MMM d, yyyy')
                                          .parse(dataEntry.key);
                                      displayLabel = DateFormat('MMM d, yyyy')
                                          .format(date);
                                      unit = 'kg';
                                    } catch (e) {
                                      displayLabel = dataEntry.key;
                                    }
                                  }

                                  return LineTooltipItem(
                                    displayLabel,
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    children: [
                                      TextSpan(
                                        text:
                                            '\n${spot.y.toStringAsFixed(1)} $unit',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
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
                          touchSpotThreshold: 50,
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: _getGridInterval(maxCollection),
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
                              reservedSize: 40,
                              interval:
                                  _getBottomInterval(processedData.length),
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 &&
                                    index < processedData.length) {
                                  final dataEntry = processedData[index];
                                  String label = '';

                                  try {
                                    if (selectedTimeFilter == 'Select Month' &&
                                        selectedMonth != null) {
                                      final date = DateFormat('MMM d, yyyy')
                                          .parse(dataEntry.key);
                                      label = DateFormat('d').format(date);
                                    } else {
                                      final date = DateFormat('MMM yyyy')
                                          .parse(dataEntry.key);
                                      label = DateFormat('MMM').format(date);
                                    }
                                  } catch (e) {
                                    label = dataEntry.key.substring(0, 3);
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 11,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 50,
                              interval: _getGridInterval(maxCollection),
                              getTitlesWidget: (value, meta) {
                                String unit =
                                    selectedTimeFilter == 'Select Month' &&
                                            selectedMonth != null
                                        ? 'kg'
                                        : 'kg';
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    '${value.toInt()}$unit',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 11,
                                    ),
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
                              width: 1.5,
                            ),
                            left: BorderSide(
                              color: Colors.grey.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                        ),
                        minX: 0,
                        maxX: (processedData.length - 1).toDouble(),
                        minY: 0,
                        maxY: maxCollection * 1.2,
                        lineBarsData: [
                          LineChartBarData(
                            spots: processedData
                                .map((entry) => FlSpot(
                                    processedData.indexOf(entry).toDouble(),
                                    entry.value))
                                .toList(),
                            isCurved: true,
                            curveSmoothness: 0.35,
                            color: primaryColor,
                            barWidth: 3.5,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 6,
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
                                  primaryColor.withOpacity(0.4),
                                  primaryColor.withOpacity(0.2),
                                  primaryColor.withOpacity(0.05),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            shadow: Shadow(
                              blurRadius: 12,
                              color: primaryColor.withOpacity(0.25),
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
              color: primaryColor.withOpacity(0.8),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
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
              Icons.eco_outlined,
              size: 48,
              color: textSecondaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No collection data available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Collection data will appear here once recorded',
            style: TextStyle(
              fontSize: 14,
              color: textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  List<MapEntry<String, double>> _getProcessedData() {
    if (selectedTimeFilter == 'Select Month' && selectedMonth != null) {
      // Return daily scan data for the selected month
      final dailyData = <MapEntry<String, double>>[];
      final sortedDays = dailyScansCount.entries.toList()
        ..sort((a, b) {
          try {
            DateTime dateA = DateFormat('MMM d, yyyy').parse(a.key);
            DateTime dateB = DateFormat('MMM d, yyyy').parse(b.key);
            return dateA.compareTo(dateB);
          } catch (e) {
            return 0;
          }
        });

      try {
        final parsedSelectedMonth =
            DateFormat('MMM yyyy').parse(selectedMonth!);
        for (final day in sortedDays) {
          try {
            final date = DateFormat('MMM d, yyyy').parse(day.key);
            if (date.year == parsedSelectedMonth.year &&
                date.month == parsedSelectedMonth.month &&
                day.value > 0) {
              dailyData.add(MapEntry(day.key, day.value.toDouble()));
            }
          } catch (e) {
            continue;
          }
        }
      } catch (e) {
        // Return empty if parsing fails
      }

      return dailyData;
    } else {
      // Return monthly collection data sorted chronologically
      final sortedData = monthlyCollectionData.entries.toList()
        ..sort((a, b) {
          try {
            DateTime dateA = DateFormat('MMM yyyy').parse(a.key);
            DateTime dateB = DateFormat('MMM yyyy').parse(b.key);
            return dateA.compareTo(dateB);
          } catch (e) {
            return 0;
          }
        });
      return sortedData;
    }
  }

  double _getGridInterval(double maxValue) {
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
        return 'Daily collection (kg) for selected month';
      } else if (selectedTimeFilter == 'This Week') {
        return 'Collection trends this week';
      } else if (selectedTimeFilter == 'This Month') {
        return DateFormat('MMMM yyyy').format(DateTime.now());
      } else if (selectedTimeFilter == 'This Year') {
        return 'Monthly collection trends for ${DateTime.now().year}';
      } else if (selectedTimeFilter == 'All Time') {
        return 'Complete collection history';
      } else {
        return 'Collection analytics dashboard';
      }
    } catch (e) {
      return 'Collection analytics dashboard';
    }
  }

  String _getDynamicTitle() {
    try {
      if (selectedTimeFilter == 'Select Month' && selectedMonth != null) {
        return 'Daily Collection Trends';
      } else if (selectedTimeFilter == 'This Week') {
        return 'Weekly Collection Trends';
      } else if (selectedTimeFilter == 'This Month') {
        return 'Monthly Collection Trends';
      } else if (selectedTimeFilter == 'This Year') {
        return 'Yearly Collection Trends';
      } else if (selectedTimeFilter == 'All Time') {
        return 'All-Time Collection Trends';
      } else {
        return 'Collection Trends';
      }
    } catch (e) {
      return 'Collection Trends';
    }
  }
}
