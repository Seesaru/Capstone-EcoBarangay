import 'package:flutter/material.dart';

class OverviewCards extends StatelessWidget {
  final double totalWasteCollected;
  final int totalCollections;
  final int totalWarnings;
  final int totalPenalties;
  final Color primaryColor;
  final Color secondaryColor;
  final Color textSecondaryColor;

  const OverviewCards({
    Key? key,
    required this.totalWasteCollected,
    required this.totalCollections,
    required this.totalWarnings,
    required this.totalPenalties,
    required this.primaryColor,
    required this.secondaryColor,
    required this.textSecondaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildOverviewCard(
          'Total Waste Collected',
          '${totalWasteCollected.toStringAsFixed(1)} kg',
          Icons.delete_outline,
          primaryColor,
        ),
        _buildOverviewCard(
          'Total Collections',
          totalCollections.toString(),
          Icons.calendar_today,
          secondaryColor,
        ),
        _buildOverviewCard(
          'Warnings',
          totalWarnings.toString(),
          Icons.warning_amber_rounded,
          Colors.orange,
        ),
        _buildOverviewCard(
          'Penalties',
          totalPenalties.toString(),
          Icons.block,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildOverviewCard(
      String title, String value, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        // You can add navigation or show details here
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
