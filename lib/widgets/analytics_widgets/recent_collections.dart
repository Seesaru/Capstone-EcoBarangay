import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RecentCollections extends StatelessWidget {
  final List<Map<String, dynamic>> recentCollections;
  final String selectedTimeFilter;
  final String? selectedMonth;
  final Color primaryColor;
  final Color textSecondaryColor;

  const RecentCollections({
    Key? key,
    required this.recentCollections,
    required this.selectedTimeFilter,
    this.selectedMonth,
    required this.primaryColor,
    required this.textSecondaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Row(
                children: [
                  Icon(
                    Icons.history,
                    color: primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Collections',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedTimeFilter == 'Select Month' &&
                                selectedMonth != null
                            ? 'Showing collections for ${DateFormat('MMMM yyyy').format(DateFormat('MMM yyyy').parse(selectedMonth!))}'
                            : 'Showing collections for $selectedTimeFilter',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondaryColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${recentCollections.length} Collections',
                    style: TextStyle(
                      fontSize: 14,
                      color: textSecondaryColor,
                    ),
                  ),
                  Text(
                    selectedTimeFilter == 'Select Month' &&
                            selectedMonth != null
                        ? DateFormat('MMMM yyyy').format(
                            DateFormat('MMM yyyy').parse(selectedMonth!))
                        : selectedTimeFilter,
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondaryColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            constraints:
                const BoxConstraints(maxHeight: 300), // Set maximum height
            child: recentCollections.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Colors.grey.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No collections found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'for the selected time period',
                          style: TextStyle(
                            fontSize: 14,
                            color: textSecondaryColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics:
                        const AlwaysScrollableScrollPhysics(), // Make it scrollable
                    itemCount: recentCollections.length,
                    itemBuilder: (context, index) {
                      final collection = recentCollections[index];
                      // Determine border color based on warnings/penalties
                      Color borderColor = Colors.grey.shade200;
                      Color backgroundColor = Colors.grey.shade50;

                      if (collection['hasPenalties'] == true) {
                        borderColor = Colors.red.withOpacity(0.5);
                        backgroundColor = Colors.red.withOpacity(0.05);
                      } else if (collection['hasWarnings'] == true) {
                        borderColor = Colors.orange.withOpacity(0.5);
                        backgroundColor = Colors.orange.withOpacity(0.05);
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: borderColor,
                            width: collection['hasWarnings'] == true ||
                                    collection['hasPenalties'] == true
                                ? 2
                                : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    _getWasteTypeColor(collection['wasteType'])
                                        .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getWasteTypeIcon(collection['wasteType']),
                                color:
                                    _getWasteTypeColor(collection['wasteType']),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          collection['residentName'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      // Warning/Penalty indicator icon
                                      if (collection['hasWarnings'] == true ||
                                          collection['hasPenalties'] == true)
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: collection['hasPenalties'] ==
                                                    true
                                                ? Colors.red.withOpacity(0.1)
                                                : Colors.orange
                                                    .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            collection['hasPenalties'] == true
                                                ? Icons.block
                                                : Icons.warning_amber_rounded,
                                            color: collection['hasPenalties'] ==
                                                    true
                                                ? Colors.red
                                                : Colors.orange,
                                            size: 16,
                                          ),
                                        ),
                                    ],
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
                            // Show warnings/penalties or weight based on scan type
                            if (collection['hasWarnings'] == true ||
                                collection['hasPenalties'] == true) ...[
                              // Show warning/penalty indicators
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (collection['hasWarnings'] == true)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.orange.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            color: Colors.orange,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Warning',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (collection['hasWarnings'] == true &&
                                      collection['hasPenalties'] == true)
                                    const SizedBox(width: 8),
                                  if (collection['hasPenalties'] == true)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.red.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.block,
                                            color: Colors.red,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Penalty',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ] else ...[
                              // Show weight for normal scans
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getWasteTypeColor(
                                          collection['wasteType'])
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${collection['weight'].toStringAsFixed(1)} kg',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _getWasteTypeColor(
                                        collection['wasteType']),
                                  ),
                                ),
                              ),
                            ],
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
}
