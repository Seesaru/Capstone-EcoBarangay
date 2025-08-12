import 'package:flutter/material.dart';
import '../../residents/resident_dashboard.dart/features/reports/more/report_detail_dialog.dart';

// Reuse the resident report dialog - just forward the call
void showCollectorReportDetailDialog(
    BuildContext context, Map<String, dynamic> report) {
  // Simply call the resident implementation
  ReportDetailDialog.show(context, report);
}
