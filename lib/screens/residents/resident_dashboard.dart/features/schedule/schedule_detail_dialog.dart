import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ScheduleDetailDialog extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final ScrollController? scrollController;

  const ScheduleDetailDialog({
    Key? key,
    required this.schedule,
    this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Extract schedule data
    bool isCompleted = schedule['status'] == 'Completed';
    bool isCancelled = schedule['status'] == 'Cancelled';

    Color scheduleColor = schedule['color'] as Color;
    IconData wasteIcon = schedule['icon'] as IconData;
    String wasteType = schedule['wasteType'] as String;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status header with appropriate color and X button
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isCompleted
                  ? [Colors.green.shade700, Colors.green.shade500]
                  : isCancelled
                      ? [Colors.red.shade700, Colors.red.shade500]
                      : [
                          scheduleColor.withOpacity(0.8),
                          scheduleColor.withOpacity(0.6)
                        ],
            ),
          ),
          child: Row(
            children: [
              // Icon with colored background
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle
                      : isCancelled
                          ? Icons.cancel
                          : wasteIcon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule['status'].toString().toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      wasteType,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 24),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        // Schedule content
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and type badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheduleColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        wasteIcon,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: scheduleColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: scheduleColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              wasteType,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: scheduleColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            schedule['title'] as String,
                            style: TextStyle(
                              fontSize: 20, // Slightly reduced
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              decoration: isCompleted || isCancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Location
                _buildInfoSection(
                  title: "LOCATION",
                  icon: Icons.location_on,
                  color: scheduleColor,
                  content: schedule['location'] as String,
                ),
                const SizedBox(height: 16),

                // Date and time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 18,
                          color: scheduleColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "COLLECTION TIME",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: scheduleColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Date",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.only(left: 24),
                                child: Text(
                                  DateFormat('EEEE, MMMM d, yyyy')
                                      .format(schedule['date'] as DateTime),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: scheduleColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Time",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.only(left: 24),
                                child: Text(
                                  schedule['time'] as String,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.grey.shade200),
                  ],
                ),
                const SizedBox(height: 16),

                // Description if available
                if (schedule['description'] != null &&
                    schedule['description'].toString().isNotEmpty)
                  _buildInfoSection(
                    title: "DESCRIPTION",
                    icon: Icons.description,
                    color: scheduleColor,
                    content: schedule['description'].toString(),
                  ),
                const SizedBox(height: 16),

                // Note about bringing materials
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: wasteType == 'Biodegradable'
                        ? Colors.green.shade50
                        : wasteType == 'Non-biodegradable'
                            ? Colors.orange.shade50
                            : wasteType == 'Recyclable'
                                ? Colors.teal.shade50
                                : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: wasteType == 'Biodegradable'
                          ? Colors.green.shade200
                          : wasteType == 'Non-biodegradable'
                              ? Colors.orange.shade200
                              : wasteType == 'Recyclable'
                                  ? Colors.teal.shade200
                                  : Colors.blue.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: scheduleColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "REMINDER",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: scheduleColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        wasteType == 'Biodegradable'
                            ? "Please ensure biodegradable waste is properly separated from other waste types. This includes food scraps, garden waste, and other compostable materials."
                            : wasteType == 'Non-biodegradable'
                                ? "Please ensure all non-biodegradable waste is clean and properly sorted. This includes plastics, metals, and other non-compostable materials."
                                : wasteType == 'Recyclable'
                                    ? "Please ensure all recyclable materials are cleaned and sorted. This includes paper, cardboard, certain plastics, glass, and metals."
                                    : "Please have your waste properly sorted and ready for collection at the scheduled time.",
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required Color color,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
            ),
          ),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 14, // Reduced font size
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeInfoItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              softWrap: true,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function to show the dialog as a slide-up modal
void showScheduleDetailDialog(
    BuildContext context, Map<String, dynamic> schedule) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    isDismissible: true,
    useRootNavigator: true,
    transitionAnimationController: AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 400),
    ),
    builder: (BuildContext context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        snap: true,
        snapSizes: const [0.7, 0.85, 0.95],
        builder: (_, controller) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Main content
                Expanded(
                  child: ScheduleDetailDialog(
                    schedule: schedule,
                    scrollController: controller,
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
