import 'package:flutter/material.dart';
import '../../residents/resident_dashboard.dart/features/announcement/announcement_detail_dialog.dart';

// Reuse the resident announcement dialog - just forward the call
void showCollectorAnnouncementDetailDialog(
    BuildContext context, Map<String, dynamic> announcement) {
  // Simply call the resident implementation
  showAnnouncementDetailDialog(context, announcement);
}
