import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class PurokDistributionChart extends StatelessWidget {
  final Map<String, double> purokCollectionData;
  final double totalWasteCollected;
  final Color primaryColor;
  final Color textSecondaryColor;

  const PurokDistributionChart({
    Key? key,
    required this.purokCollectionData,
    required this.totalWasteCollected,
    required this.primaryColor,
    required this.textSecondaryColor,
  }) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
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
                  '${purokCollectionData.length} Puroks',
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
            child: purokCollectionData.isEmpty
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
                      // Pie Chart Section with reduced size to prevent overlapping
                      Container(
                        height: 200, // Fixed height for pie chart
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                sections:
                                    purokCollectionData.entries.map((entry) {
                                  final index = purokCollectionData.keys
                                      .toList()
                                      .indexOf(entry.key);
                                  final color = _modernColors[
                                      index % _modernColors.length];

                                  // Pie chart percentage calculation
                                  final percentage = totalWasteCollected == 0
                                      ? 0
                                      : (entry.value /
                                          totalWasteCollected *
                                          100);

                                  // Show labels only for larger sections to prevent overlapping
                                  final shouldShowLabel = percentage >= 5;

                                  return PieChartSectionData(
                                    value: entry.value,
                                    title: shouldShowLabel
                                        ? '${percentage.toInt()}%'
                                        : '',
                                    color: color,
                                    radius: 80, // Reduced radius
                                    titleStyle: const TextStyle(
                                      fontSize: 10, // Smaller font
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    titlePositionPercentageOffset: 0.6,
                                    badgeWidget: null,
                                    badgePositionPercentageOffset: 0,
                                  );
                                }).toList(),
                                sectionsSpace: 2,
                                centerSpaceRadius: 30, // Reduced center space
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
                              width: 60, // Smaller center container
                              height: 60,
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
                                      fontSize: 10, // Smaller font
                                      color: textSecondaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${totalWasteCollected.toStringAsFixed(1)} kg',
                                    style: TextStyle(
                                      fontSize: 12, // Smaller font
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
                      const SizedBox(height: 16),
                      // Scrollable Legend Section
                      Expanded(
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight: 150, // Maximum height for legend
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: purokCollectionData.length,
                            itemBuilder: (context, index) {
                              final entries = purokCollectionData.entries
                                  .toList()
                                ..sort((a, b) => b.value.compareTo(
                                    a.value)); // Sort by value descending

                              final entry = entries[index];
                              final color = _modernColors[purokCollectionData
                                      .keys
                                      .toList()
                                      .indexOf(entry.key) %
                                  _modernColors.length];
                              // List percentage calculation
                              final percentage = totalWasteCollected == 0
                                  ? '0.0'
                                  : (entry.value / totalWasteCollected * 100)
                                      .toStringAsFixed(1);
                              final weight = entry.value.toStringAsFixed(1);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 0.5,
                                  ),
                                ),
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
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[800],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Percentage
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        '$percentage%',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    // Weight
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        '$weight kg',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: textSecondaryColor,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
