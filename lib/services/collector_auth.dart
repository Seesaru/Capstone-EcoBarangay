import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CollectorAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Register collector with email & password and store in Firestore
  Future<User?> registerCollector({
    required String email,
    required String password,
    required String fullName,
    required String contactNumber,
    required String barangay,
    String? barangayId,
  }) async {
    try {
      // Create user with Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Store collector data using the helper method
      await _storeCollectorData(
        user: userCredential.user!,
        email: email,
        fullName: fullName,
        contactNumber: contactNumber,
        barangay: barangay,
        barangayId: barangayId,
      );

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      print("Collector registered successfully: ${userCredential.user!.uid}");
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("Collector registration error: ${e.code} - ${e.message}");
      rethrow; // Rethrow to handle in UI
    } catch (e) {
      print("Unexpected error during collector registration: $e");
      rethrow; // Rethrow to handle in UI
    }
  }

  // Store collector data in Firestore
  Future<void> _storeCollectorData({
    required User user,
    required String email,
    required String fullName,
    required String contactNumber,
    required String barangay,
    String? barangayId,
  }) async {
    try {
      // Debug admin status
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        print("Current admin user: ${currentUser.uid}");
        print("Attempting to store collector with UID: ${user.uid}");
      }

      // Prepare collector data
      Map<String, dynamic> collectorData = {
        'email': email,
        'fullName': fullName,
        'contactNumber': contactNumber,
        'barangay': barangay,
        'uid': user.uid,
        'role': 'collector',
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'isVerified': false,
        'isApproved': false,
        'status': 'pending', // Add status field for filtering
        'canLogin': false, // Prevent login until approved
      };

      // Add barangayId if available
      if (barangayId != null && barangayId.isNotEmpty) {
        collectorData['barangayId'] = barangayId;
      }

      // Store collector data
      await _firestore.collection('collector').doc(user.uid).set(collectorData);

      print("Collector data stored successfully");
    } catch (e) {
      print("Error storing collector data: $e");

      // Additional debug info
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        try {
          final adminDoc = await _firestore
              .collection('barangay_admins')
              .doc(currentUser.uid)
              .get();

          if (adminDoc.exists) {
            print("Admin document data: ${adminDoc.data()}");
          } else {
            print("⚠️ Admin document NOT found!");
          }
        } catch (debugError) {
          print("Error fetching admin doc: $debugError");
        }
      }

      throw Exception("Failed to store collector data: $e");
    }
  }

  // Check if collector is verified
  Future<bool> isCollectorVerified() async {
    try {
      User? user = _auth.currentUser;

      if (user != null) {
        // Reload user to get latest verification status
        await user.reload();
        user = _auth.currentUser;

        // Update verification status in Firestore if email is verified
        if (user!.emailVerified) {
          try {
            await _firestore.collection('collector').doc(user.uid).update({
              'isVerified': true,
            });
          } catch (e) {
            print("Error updating verification status: $e");
            // Continue even if update fails
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      print("Error checking verification: $e");
      return false;
    }
  }

  // Resend verification email
  Future<void> resendVerificationEmail() async {
    try {
      User? user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      print("Error sending verification email: $e");
      rethrow;
    }
  }

  // Delete collector completely (both Firestore document and Auth account)
  Future<void> deleteCollector(
      String collectorId, String email, String password) async {
    try {
      // Step 1: Delete Firestore document first
      await _firestore.collection('collector').doc(collectorId).delete();
      print("Collector Firestore document deleted: $collectorId");

      // Step 2: Sign in as the collector to delete their Auth account
      // This requires the admin to have the collector's password
      // If you don't have the password, this part won't work
      try {
        if (email.isNotEmpty && password.isNotEmpty) {
          // Saving the current user to sign back in later
          User? currentUser = _auth.currentUser;
          String? currentEmail;

          if (currentUser != null) {
            currentEmail = currentUser.email;

            // Sign out the current admin user
            await _auth.signOut();
          }

          // Sign in as the collector
          UserCredential userCredential =
              await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          // Delete the user account
          await userCredential.user?.delete();
          print("Collector Auth account deleted for: $email");

          // Sign back in as admin if needed
          if (currentEmail != null) {
            print("Attempting to sign back in as admin: $currentEmail");
            // You would need to implement admin sign-in logic here
          }
        }
      } catch (authError) {
        // If we can't delete the Auth account, log the error but don't fail the operation
        // The Firestore document is already deleted at this point
        print("Warning: Could not delete Auth account: $authError");
      }
    } catch (e) {
      print("Error deleting collector: $e");
      rethrow; // Rethrow to handle in UI
    }
  }

  // Alternative method to delete collector (Firestore only)
  // Use this when you don't have collector's credentials
  Future<void> deleteCollectorDocument(String collectorId) async {
    try {
      await _firestore.collection('collector').doc(collectorId).delete();
      print("Collector Firestore document deleted: $collectorId");
    } catch (e) {
      print("Error deleting collector document: $e");
      rethrow; // Rethrow to handle in UI
    }
  }

  // Approve collector (change status from pending to active)
  Future<void> approveCollector(String collectorId) async {
    try {
      await _firestore.collection('collector').doc(collectorId).update({
        'isApproved': true,
        'status': 'active',
        'approvedAt': FieldValue.serverTimestamp(),
        'canLogin': true, // Allow the collector to log in
      });
      print("Collector approved successfully: $collectorId");
    } catch (e) {
      print("Error approving collector: $e");
      rethrow; // Rethrow to handle in UI
    }
  }

  // Check if collector can login
  Future<bool> canCollectorLogin(String uid) async {
    try {
      final doc = await _firestore.collection('collector').doc(uid).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['canLogin'] == true;
      }
      return false;
    } catch (e) {
      print("Error checking if collector can login: $e");
      return false;
    }
  }

  // Handle collector login with validation for role
  Future<UserCredential> signInCollectorWithEmailAndPassword(
      String email, String password) async {
    try {
      // Sign in with Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Check if this user is a resident (should not be able to login as collector)
        DocumentSnapshot residentDoc =
            await _firestore.collection('resident').doc(user.uid).get();

        if (residentDoc.exists) {
          // This is a resident account, sign out and throw error
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'not-collector',
            message:
                'This account is registered as a resident. Please use the resident login.',
          );
        }

        // Verify this user is a collector in the database
        DocumentSnapshot collectorDoc =
            await _firestore.collection('collector').doc(user.uid).get();

        if (!collectorDoc.exists) {
          // Not a collector, sign out and show error
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'not-collector',
            message: 'This account does not have collector privileges',
          );
        }

        // Check if collector is active
        Map<String, dynamic> collectorData =
            collectorDoc.data() as Map<String, dynamic>;
        bool isActive = collectorData['isActive'] ?? false;

        if (!isActive) {
          // Collector account is inactive
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'inactive-account',
            message:
                'This collector account is inactive. Please contact your administrator',
          );
        }

        // Verify this user has role "collector"
        String role = collectorData['role'] ?? '';
        if (role != 'collector') {
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'not-collector',
            message: 'This account does not have collector privileges',
          );
        }

        // Check if user's email is verified (if required)
        if (!user.emailVerified) {
          // Email verification is required
          bool isVerified = collectorData['isVerified'] ?? false;
          if (!isVerified) {
            throw FirebaseAuthException(
              code: 'email-not-verified',
              message: 'Please verify your email before logging in',
            );
          }
        }
      }

      return userCredential;
    } catch (e) {
      print("Collector sign in error: $e");
      rethrow;
    }
  }

  // Log collector login activity
  Future<void> logCollectorLogin(String userId) async {
    try {
      // Get current collector data to include in log
      DocumentSnapshot collectorDoc =
          await _firestore.collection('collector').doc(userId).get();

      Map<String, dynamic> collectorData = {};
      if (collectorDoc.exists) {
        collectorData = collectorDoc.data() as Map<String, dynamic>;
      }

      // Create the log entry with detailed information
      await _firestore.collection('collector_logs').add({
        'userId': userId,
        'collectorId': userId,
        'email': collectorData['email'] ?? 'unknown',
        'fullName': collectorData['fullName'] ?? 'unknown',
        'action': 'login',
        'status': 'success',
        'timestamp': FieldValue.serverTimestamp(),
        'barangay': collectorData['barangay'] ?? 'unknown',
        'deviceInfo': {
          'platform': 'mobile', // Can be enhanced with actual device info
          'appVersion':
              '1.0.0', // Can use package_info_plus to get actual version
        },
        'metadata': {
          'isActive': collectorData['isActive'] ?? false,
          'isApproved': collectorData['isApproved'] ?? false,
          'lastLogin': collectorData['lastLogin'] ?? null,
        }
      });

      // Update the collector's last login time
      await _firestore.collection('collector').doc(userId).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      print("Collector login logged successfully");
    } catch (e) {
      print("Error logging collector login: $e");
      // Don't throw an exception here to prevent login failure due to logging failure
    }
  }

  // Log failed collector login attempts
  Future<void> logFailedLoginAttempt(String email, String errorCode) async {
    try {
      await _firestore.collection('collector_logs').add({
        'email': email,
        'collectorId': 'unknown',
        'action': 'login',
        'status': 'failed',
        'errorCode': errorCode,
        'timestamp': FieldValue.serverTimestamp(),
        'barangay': 'unknown', // Unknown barangay for failed logins
        'deviceInfo': {
          'platform': 'mobile',
          'appVersion': '1.0.0',
        }
      });
      print("Failed collector login attempt logged successfully");
    } catch (e) {
      print("Error logging failed collector login attempt: $e");
    }
  }

  // Log collector logout activity
  Future<void> logCollectorLogout(String userId) async {
    try {
      // Get current collector data to include in log
      DocumentSnapshot collectorDoc =
          await _firestore.collection('collector').doc(userId).get();

      Map<String, dynamic> collectorData = {};
      if (collectorDoc.exists) {
        collectorData = collectorDoc.data() as Map<String, dynamic>;
      }

      // Create the log entry
      await _firestore.collection('collector_logs').add({
        'userId': userId,
        'collectorId': userId,
        'email': collectorData['email'] ?? 'unknown',
        'fullName': collectorData['fullName'] ?? 'unknown',
        'action': 'logout',
        'status': 'success',
        'timestamp': FieldValue.serverTimestamp(),
        'barangay': collectorData['barangay'] ?? 'unknown',
        'deviceInfo': {
          'platform': 'mobile',
          'appVersion': '1.0.0',
        }
      });

      print("Collector logout logged successfully");
    } catch (e) {
      print("Error logging collector logout: $e");
      // Don't throw an exception here to prevent logout failure due to logging failure
    }
  }

  // Sign out method
  Future<void> signOut() async {
    try {
      // Get the userId before signing out
      String? userId = _auth.currentUser?.uid;

      // Log the logout if we have a user ID
      if (userId != null) {
        await logCollectorLogout(userId);
      }

      await _auth.signOut();
    } catch (e) {
      print("Error signing out: $e");
      rethrow;
    }
  }

  // Check if collector is currently logged in and get their role
  Future<Map<String, dynamic>?> getCurrentCollectorRole() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        return null;
      }

      // Check if user is a collector
      DocumentSnapshot collectorDoc = await _firestore
          .collection('collector')
          .doc(user.uid)
          .get(GetOptions(source: Source.serverAndCache));

      if (collectorDoc.exists) {
        Map<String, dynamic> collectorData =
            collectorDoc.data() as Map<String, dynamic>;
        return {
          'role': 'collector',
          'uid': user.uid,
          'email': user.email,
          'data': collectorData,
        };
      }

      // User exists in Firebase Auth but not in collector collection
      return null;
    } catch (e) {
      print("Error getting current collector role: $e");
      return null;
    }
  }
}
