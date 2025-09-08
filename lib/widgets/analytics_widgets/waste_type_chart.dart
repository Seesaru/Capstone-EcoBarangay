import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class WasteTypeChart extends StatelessWidget {
  final Map<String, double> wasteTypeData;
  final double totalWasteCollected;
  final bool isLoading;
  final VoidCallback onRefresh;
  final Color primaryColor;
  final Color textSecondaryColor;

  const WasteTypeChart({
    Key? key,
    required this.wasteTypeData,
    required this.totalWasteCollected,
    required this.isLoading,
    required this.onRefresh,
    required this.primaryColor,
    required this.textSecondaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Sort waste types and create a list of entries for consistent ordering
    final sortedWasteEntries = wasteTypeData.entries.toList()
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
                      '${totalWasteCollected.toStringAsFixed(1)} kg total',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onRefresh,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.refresh,
                        color: Colors.blue,
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
                    opacity: isLoading ? 0.3 : 1.0,
                    duration: const Duration(milliseconds: 500),
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: sortedWasteEntries.isNotEmpty
                            ? (sortedWasteEntries.first.value * 1.2).toDouble()
                            : 10.0,
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
}
