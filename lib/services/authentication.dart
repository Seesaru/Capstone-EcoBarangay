import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==================== ADMIN AUTHENTICATION METHODS ====================

  // Register admin with email & password and store in Firestore
  Future<User?> registerAdmin({
    required String email,
    required String password,
    required String fullName,
    required String contactNumber,
    required String barangay,
  }) async {
    try {
      // Create user with Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Store admin data in Firestore
      await _storeAdminData(
        user: userCredential.user!,
        email: email,
        fullName: fullName,
        contactNumber: contactNumber,
        barangay: barangay,
      );

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("Admin registration error: ${e.code} - ${e.message}");
      rethrow; // Rethrow to handle in UI
    } catch (e) {
      print("Unexpected error during admin registration: $e");
      rethrow; // Rethrow to handle in UI
    }
  }

  // Store admin data in Firestore
  Future<void> _storeAdminData({
    required User user,
    required String email,
    required String fullName,
    required String contactNumber,
    required String barangay,
  }) async {
    try {
      // Generate unique barangayId using timestamp and random string
      String barangayId =
          'brgy_${DateTime.now().millisecondsSinceEpoch}_${user.uid.substring(0, 8)}';

      // Store admin data
      await _firestore.collection('barangay_admins').doc(user.uid).set({
        'email': email,
        'fullName': fullName,
        'contactNumber': contactNumber,
        'barangay': barangay,
        'barangayId': barangayId,
        'isVerified': false,
        'uid': user.uid,
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Store the barangay name and createdBy in the barangays collection using the generated barangayId
      await _firestore.collection('barangays').doc(barangayId).set(
          {
            'barangayId': barangayId,
            'name': barangay,
            'createdBy': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'isActive': true,
          },
          SetOptions(
              merge:
                  true)); // Using merge to avoid overwriting if barangay already exists

      print(
          "Admin data stored successfully and barangay added to collection with unique barangayId");
    } catch (e) {
      print("Error storing admin data: $e");
      throw Exception("Failed to store admin data: $e");
    }
  }

  // Admin sign in with email & password
  Future<UserCredential> signInAdmin(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if user is an admin
      DocumentSnapshot adminDoc = await _firestore
          .collection('barangay_admins')
          .doc(userCredential.user!.uid)
          .get();

      if (!adminDoc.exists) {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'not-admin',
          message: 'This account does not have admin privileges.',
        );
      }

      // Check if email is verified
      User? user = userCredential.user;
      if (user != null && !user.emailVerified) {
        // Email is not verified, throw custom exception
        throw FirebaseAuthException(
          code: 'email-not-verified',
          message: 'Please verify your email before logging in.',
        );
      }

      return userCredential;
    } catch (e) {
      print("Admin sign in error: $e");
      rethrow; // Rethrow to handle in UI
    }
  }

  // Check if admin is verified
  Future<bool> isAdminVerified() async {
    try {
      User? user = _auth.currentUser;

      if (user != null) {
        // Reload user to get latest verification status
        await user.reload();
        user = _auth.currentUser;

        // Update verification status in Firestore if email is verified
        if (user!.emailVerified) {
          try {
            await _firestore
                .collection('barangay_admins')
                .doc(user.uid)
                .update({
              'isVerified': true,
            });
            print("Admin verification status updated in barangay_admins");
          } catch (e) {
            print("Error updating admin verification status: $e");
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      print("Error checking admin verification: $e");
      return false;
    }
  }

  // ==================== RESIDENT AUTHENTICATION METHODS ====================

  // Register with email & password and store in Firestore (for residents)
  Future<User?> registerWithEmailAndPassword(
      String email, String password) async {
    try {
      // Check if email exists but is unverified
      try {
        var methods = await _auth.fetchSignInMethodsForEmail(email);
        if (methods.isNotEmpty) {
          // Email exists, try to sign in to check verification status
          try {
            UserCredential userCredential =
                await _auth.signInWithEmailAndPassword(
              email: email,
              password: password,
            );

            // If we get here, the password was correct
            User? user = userCredential.user;

            // Check if email is verified
            if (user != null && !user.emailVerified) {
              // Email exists but not verified, send verification again
              await user.sendEmailVerification();
              return user; // Return user to show verification screen
            }

            // If email is verified, sign out and throw exception (email in use)
            await _auth.signOut();
            throw FirebaseAuthException(
              code: 'email-already-in-use',
              message:
                  'The email address is already in use by another account.',
            );
          } catch (e) {
            // Wrong password or other error
            throw FirebaseAuthException(
              code: 'email-already-in-use',
              message:
                  'The email address is already in use by another account.',
            );
          }
        }
      } catch (e) {
        // Error checking email, continue with registration
        print("Error checking email existence: $e");
      }

      // Create user with Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Store user data in Firestore
      await _storeUserData(userCredential.user!, email);

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      return userCredential.user;
    } catch (e) {
      print("Registration error: $e");
      rethrow; // Rethrow to handle in UI
    }
  }

  // Store user data in Firestore
  Future<void> _storeUserData(User user, String email) async {
    try {
      // Check if the document already exists
      DocumentSnapshot doc =
          await _firestore.collection('resident').doc(user.uid).get();

      if (!doc.exists) {
        await _firestore.collection('resident').doc(user.uid).set({
          'email': email,
          'isVerified': false,
          'uid': user.uid,
          'role': 'resident',
          'createdAt': FieldValue.serverTimestamp(),
        });
        print("User data stored successfully in Firestore");
      } else {
        print("Document already exists for user: ${user.uid}");
      }
    } catch (e) {
      print("Error storing user data: $e");
      throw Exception("Failed to store user data: $e");
    }
  }

  // Check if user is verified
  Future<bool> isUserVerified() async {
    try {
      User? user = _auth.currentUser;

      if (user != null) {
        // Reload user to get latest verification status
        await user.reload();
        user = _auth.currentUser;

        // Update verification status in Firestore if email is verified
        if (user!.emailVerified) {
          try {
            await _firestore.collection('resident').doc(user.uid).update({
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

  // ==================== COMMON AUTHENTICATION METHODS ====================

  // Sign in with email & password (for residents)
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Check if this user is a collector (should not be able to login as resident)
        DocumentSnapshot collectorDoc =
            await _firestore.collection('collector').doc(user.uid).get();

        if (collectorDoc.exists) {
          // This is a collector account, sign out and throw error
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'not-resident',
            message:
                'This account is registered as a collector. Please use the collector login.',
          );
        }

        // Check if user exists in residents collection
        DocumentSnapshot residentDoc = await _firestore
            .collection('resident')
            .doc(user.uid)
            .get(GetOptions(source: Source.serverAndCache));

        if (!residentDoc.exists) {
          // User is not in residents collection
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'not-resident',
            message: 'This account is not registered as a resident.',
          );
        }

        // Check if email is verified
        if (!user.emailVerified) {
          Map<String, dynamic> userData =
              residentDoc.data() as Map<String, dynamic>;
          bool isVerified = userData['isVerified'] ?? false;

          if (!isVerified) {
            throw FirebaseAuthException(
              code: 'email-not-verified',
              message: 'Please verify your email before logging in.',
            );
          }
        }
      }

      return userCredential;
    } catch (e) {
      print("Sign in error: $e");
      rethrow;
    }
  }

  // Log resident login activity
  Future<void> logResidentLogin(String userId) async {
    try {
      // Get current user data to include in log
      DocumentSnapshot userDoc = await _firestore
          .collection('resident')
          .doc(userId)
          .get(GetOptions(source: Source.serverAndCache));

      Map<String, dynamic> userData = {};
      if (userDoc.exists) {
        userData = userDoc.data() as Map<String, dynamic>;
      }

      // Create the log entry with more detailed information
      await _firestore.collection('resident_logs').add({
        'userId': userId,
        'email': userData['email'] ?? 'unknown',
        'action': 'login',
        'status': 'success',
        'timestamp': FieldValue.serverTimestamp(),
        'barangay': userData['barangay'] ?? 'unknown',
        'deviceInfo': {
          'platform': 'mobile', // Can be enhanced with actual device info
          'appVersion':
              '1.0.0', // You can use package_info_plus to get actual version
        },
        'metadata': {
          'profileCompleted': userData['profileCompleted'] ?? false,
          'lastLogin': userData['lastLogin'] ?? null,
        }
      });

      // Update the user's last login time
      await _firestore.collection('resident').doc(userId).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      print("Resident login logged successfully");
    } catch (e) {
      print("Error logging resident login: $e");
      // Don't throw an exception here to prevent login failure due to logging failure
    }
  }

  // Log failed login attempts
  Future<void> logFailedLoginAttempt(String email, String errorCode) async {
    try {
      await _firestore.collection('resident_logs').add({
        'email': email,
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
      print("Failed login attempt logged successfully");
    } catch (e) {
      print("Error logging failed login attempt: $e");
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

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Password reset
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Add this method to check if user profile is completed
  Future<bool> isProfileCompleted() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Use cache first approach to speed up the check
        DocumentSnapshot userDoc = await _firestore
            .collection('resident')
            .doc(user.uid)
            .get(GetOptions(source: Source.serverAndCache));

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          return userData['profileCompleted'] == true;
        }
      }
      return false;
    } catch (e) {
      print("Error checking profile completion: $e");
      return false;
    }
  }

  // Check if user is currently logged in and get their role
  Future<Map<String, dynamic>?> getCurrentUserRole() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        return null;
      }

      // Check if user is a resident
      DocumentSnapshot residentDoc = await _firestore
          .collection('resident')
          .doc(user.uid)
          .get(GetOptions(source: Source.serverAndCache));

      if (residentDoc.exists) {
        Map<String, dynamic> userData =
            residentDoc.data() as Map<String, dynamic>;
        return {
          'role': 'resident',
          'uid': user.uid,
          'email': user.email,
          'data': userData,
        };
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

      // Check if user is an admin
      DocumentSnapshot adminDoc = await _firestore
          .collection('barangay_admins')
          .doc(user.uid)
          .get(GetOptions(source: Source.serverAndCache));

      if (adminDoc.exists) {
        Map<String, dynamic> adminData =
            adminDoc.data() as Map<String, dynamic>;
        return {
          'role': 'admin',
          'uid': user.uid,
          'email': user.email,
          'data': adminData,
        };
      }

      // User exists in Firebase Auth but not in any collection
      return null;
    } catch (e) {
      print("Error getting current user role: $e");
      return null;
    }
  }

  // Log resident logout activity
  Future<void> logResidentLogout(String userId) async {
    try {
      // Get current user data to include in log
      DocumentSnapshot userDoc = await _firestore
          .collection('resident')
          .doc(userId)
          .get(GetOptions(source: Source.serverAndCache));

      Map<String, dynamic> userData = {};
      if (userDoc.exists) {
        userData = userDoc.data() as Map<String, dynamic>;
      }

      // Create the log entry
      await _firestore.collection('resident_logs').add({
        'userId': userId,
        'email': userData['email'] ?? 'unknown',
        'action': 'logout',
        'status': 'success',
        'timestamp': FieldValue.serverTimestamp(),
        'barangay': userData['barangay'] ?? 'unknown',
        'deviceInfo': {
          'platform': 'mobile',
          'appVersion': '1.0.0',
        }
      });

      print("Resident logout logged successfully");
    } catch (e) {
      print("Error logging resident logout: $e");
      // Don't throw an exception here to prevent logout failure due to logging failure
    }
  }
}
