import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportApprovalService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Approve a report with specified visibility
  ///
  /// [reportId] - The ID of the report to approve
  /// [visibility] - Either 'public' or 'confidential'
  /// Returns a map with success status and message
  static Future<Map<String, dynamic>> approveReport(
      String reportId, String visibility) async {
    try {
      User? currentUser = _auth.currentUser;
      String adminId = currentUser?.uid ?? 'unknown';

      // Validate visibility parameter
      if (visibility != 'public' && visibility != 'confidential') {
        return {
          'success': false,
          'message':
              'Invalid visibility parameter. Must be "public" or "confidential".'
        };
      }

      // Update the report status
      await _firestore.collection('reports').doc(reportId).update({
        'approvalStatus': 'approved',
        'visibility': visibility,
        'status': visibility == 'public' ? 'New' : 'Confidential',
        'approvedAt': Timestamp.now(),
        'approvedBy': adminId,
        'lastUpdated': Timestamp.now(),
      });

      return {
        'success': true,
        'message':
            'Report approved as ${visibility == 'public' ? 'public' : 'confidential'}. The author will be notified.',
        'visibility': visibility,
      };
    } catch (e) {
      print('Error approving report: $e');
      return {
        'success': false,
        'message': 'Error approving report: ${e.toString()}'
      };
    }
  }

  /// Reject a report
  ///
  /// [reportId] - The ID of the report to reject
  /// Returns a map with success status and message
  static Future<Map<String, dynamic>> rejectReport(String reportId) async {
    try {
      User? currentUser = _auth.currentUser;
      String adminId = currentUser?.uid ?? 'unknown';

      // Update the report status
      await _firestore.collection('reports').doc(reportId).update({
        'approvalStatus': 'rejected',
        'status': 'Rejected',
        'rejectedAt': Timestamp.now(),
        'rejectedBy': adminId,
        'lastUpdated': Timestamp.now(),
      });

      return {
        'success': true,
        'message': 'Report rejected. The author will be notified.',
      };
    } catch (e) {
      print('Error rejecting report: $e');
      return {
        'success': false,
        'message': 'Error rejecting report: ${e.toString()}'
      };
    }
  }

  /// Get pending reports for a specific barangay
  ///
  /// [barangay] - The barangay to get pending reports for
  /// Returns a list of pending reports
  static Future<List<Map<String, dynamic>>> getPendingReports(
      String barangay) async {
    try {
      if (barangay.isEmpty) return [];

      Query query = _firestore
          .collection('reports')
          .where('residentBarangay', isEqualTo: barangay)
          .where('approvalStatus', isEqualTo: 'pending')
          .orderBy('submittedAt', descending: true);

      QuerySnapshot querySnapshot = await query.get();
      List<Map<String, dynamic>> pendingReports = [];

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Convert Timestamp to DateTime
        DateTime reportDate = DateTime.now();
        if (data['submittedAt'] is Timestamp) {
          reportDate = (data['submittedAt'] as Timestamp).toDate();
        }

        pendingReports.add({
          'id': doc.id,
          'title': data['title'] ?? 'No Title',
          'content': data['content'] ?? 'No content',
          'category': data['category'] ?? 'General',
          'location': data['location'],
          'date': reportDate,
          'author': data['author'],
          'authorId': data['authorId'],
          'authorRole': data['authorRole'] ?? 'Resident',
          'status': data['status'] ?? 'Pending Approval',
          'userType': data['userType'],
          'isAnonymous': data['isAnonymous'] ?? false,
          'barangay': data['residentBarangay'] ?? barangay,
          'imageUrl': data['imageUrl'] ?? '',
          'approvalStatus': data['approvalStatus'] ?? 'pending',
          'visibility': data['visibility'] ?? 'pending',
          'submittedAt': data['submittedAt'],
        });
      }

      return pendingReports;
    } catch (e) {
      print('Error fetching pending reports: $e');
      return [];
    }
  }

  /// Get approved reports for a specific barangay
  ///
  /// [barangay] - The barangay to get approved reports for
  /// Returns a list of approved reports
  static Future<List<Map<String, dynamic>>> getApprovedReports(
      String barangay) async {
    try {
      if (barangay.isEmpty) return [];

      Query query = _firestore
          .collection('reports')
          .where('residentBarangay', isEqualTo: barangay)
          .where('approvalStatus', isEqualTo: 'approved')
          .orderBy('date', descending: true);

      QuerySnapshot querySnapshot = await query.get();
      List<Map<String, dynamic>> approvedReports = [];

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Convert Timestamp to DateTime
        DateTime reportDate = DateTime.now();
        if (data['date'] is Timestamp) {
          reportDate = (data['date'] as Timestamp).toDate();
        }

        approvedReports.add({
          'id': doc.id,
          'title': data['title'] ?? 'No Title',
          'content': data['content'] ?? 'No content',
          'category': data['category'] ?? 'General',
          'location': data['location'],
          'date': reportDate,
          'author': data['author'],
          'authorId': data['authorId'],
          'authorRole': data['authorRole'] ?? 'Resident',
          'status': data['status'] ?? 'New',
          'userType': data['userType'],
          'isAnonymous': data['isAnonymous'] ?? false,
          'barangay': data['residentBarangay'] ?? barangay,
          'imageUrl': data['imageUrl'] ?? '',
          'approvalStatus': data['approvalStatus'] ?? 'approved',
          'visibility': data['visibility'] ?? 'public',
        });
      }

      return approvedReports;
    } catch (e) {
      print('Error fetching approved reports: $e');
      return [];
    }
  }

  /// Update report status (for admin use)
  ///
  /// [reportId] - The ID of the report to update
  /// [newStatus] - The new status to set
  /// Returns a map with success status and message
  static Future<Map<String, dynamic>> updateReportStatus(
      String reportId, String newStatus) async {
    try {
      // Update the report status in Firestore
      await _firestore.collection('reports').doc(reportId).update({
        'status': newStatus,
        'lastUpdated': Timestamp.now(),
      });

      return {
        'success': true,
        'message': 'Report marked as $newStatus',
        'status': newStatus,
      };
    } catch (e) {
      print('Error updating report status: $e');
      return {
        'success': false,
        'message': 'Error updating report status: ${e.toString()}'
      };
    }
  }

  /// Delete a report
  ///
  /// [reportId] - The ID of the report to delete
  /// Returns a map with success status and message
  static Future<Map<String, dynamic>> deleteReport(String reportId) async {
    try {
      // Delete the report from Firestore
      await _firestore.collection('reports').doc(reportId).delete();

      return {
        'success': true,
        'message': 'Report deleted successfully',
      };
    } catch (e) {
      print('Error deleting report: $e');
      return {
        'success': false,
        'message': 'Error deleting report: ${e.toString()}'
      };
    }
  }
}
