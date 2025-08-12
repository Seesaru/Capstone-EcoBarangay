import 'package:flutter/material.dart';
import '../../residents/resident_dashboard.dart/features/schedule/schedule_detail_dialog.dart';

// Reuse the resident schedule dialog - just forward the call
Future<bool?> showCollectorScheduleDetailDialog(
    BuildContext context, Map<String, dynamic> schedule) async {
  // Simply call the resident implementation
  showScheduleDetailDialog(context, schedule);
  return null; // Return null here since the resident implementation doesn't return a value
}
