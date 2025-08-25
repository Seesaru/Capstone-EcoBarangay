import 'package:capstone_ecobarangay/screens/admin/announcement_screen.dart';
import 'package:capstone_ecobarangay/screens/collector/collector_screens/collector_dashboard.dart';
import 'package:capstone_ecobarangay/screens/others/collector_pending_approval.dart';
import 'package:capstone_ecobarangay/screens/others/collector_verification_screen.dart';
import 'package:capstone_ecobarangay/screens/residents/resident_dashboard.dart/dashboard.dart';
import 'package:capstone_ecobarangay/screens/residents/resident_dashboard.dart/features/reports/more/add_report.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:capstone_ecobarangay/screens/residents/login_page.dart';
import 'package:capstone_ecobarangay/screens/residents/register_screen.dart';
import 'package:capstone_ecobarangay/screens/admin/admin_login.dart';
import 'package:capstone_ecobarangay/screens/admin/admin_signup.dart';
import 'package:capstone_ecobarangay/screens/admin/admin_dashboard.dart';
import 'package:capstone_ecobarangay/screens/others/admin_verification.dart';
import 'package:capstone_ecobarangay/screens/residents/complete_profile.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:capstone_ecobarangay/screens/onboarding_screen/onboarding_screen.dart';
import 'package:capstone_ecobarangay/screens/collector/collector_screens/collector_signup.dart';
import 'package:capstone_ecobarangay/screens/collector/features/collector_scan.dart';
import 'package:capstone_ecobarangay/screens/collector/features/collector_scan_history.dart';
import 'package:capstone_ecobarangay/services/forgot_password.dart';
import 'package:capstone_ecobarangay/services/schedule_notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: "AIzaSyCOPW4JYSeHYRf7uh_hPUgZmf6nIfdDrHE",
        authDomain: "capstone-ecobarangay.firebaseapp.com",
        projectId: "capstone-ecobarangay",
        storageBucket: "capstone-ecobarangay.appspot.com",
        messagingSenderId: "894124992565",
        appId: "1:894124992565:web:a60d40f87dd6964f7ba97c",
        measurementId: "G-MBED7G3GPR",
      ),
    );
  } else {
    await Firebase.initializeApp();

    // Only initialize OneSignal for mobile platforms
    try {
      // Enable verbose logging temporarily to help with debugging
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      print('Initializing OneSignal...');

      // Initialize OneSignal
      OneSignal.initialize("836b9037-820a-4906-acf5-6d3e36d3899e");
      print('OneSignal initialized');

      // Request notification permissions
      OneSignal.Notifications.requestPermission(true).then((accepted) {
        print('Notification permission ${accepted ? 'accepted' : 'declined'}');
      });

      // Make notifications appear even when app is in foreground
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        print(
            'Received notification in foreground: ${event.notification.title}');
        // Display the notification rather than suppressing it
        event.notification.display();
      });

      // NEW: Handle notifications when app is opened from background/closed state
      OneSignal.Notifications.addClickListener((event) {
        print('Notification clicked: ${event.notification.title}');
        print('Notification data: ${event.notification.additionalData}');

        // Handle navigation based on notification type
        _handleNotificationClick(event.notification);
      });

      // NEW: Handle notifications received when app is in background
      OneSignal.Notifications.addPermissionObserver((state) {
        print('Notification permission changed: $state');
      });

      // Start schedule notification service
      ScheduleNotificationService.startScheduleNotificationCheck();

      // If user is already logged in, set their external user ID and barangay tag
      FirebaseAuth.instance.authStateChanges().listen((User? user) async {
        if (user != null) {
          try {
            print('Setting OneSignal external user ID for: ${user.uid}');
            // Set external user ID
            await OneSignal.login(user.uid);
            print('OneSignal: Set external user ID on app launch: ${user.uid}');

            // Check if user is a resident
            DocumentSnapshot userDoc = await FirebaseFirestore.instance
                .collection('resident')
                .doc(user.uid)
                .get();

            if (userDoc.exists) {
              Map<String, dynamic> userData =
                  userDoc.data() as Map<String, dynamic>;
              String? barangay = userData['barangay'];

              if (barangay != null && barangay.isNotEmpty) {
                print('Setting barangay tag: $barangay');
                await OneSignal.User.addTags({'barangay': barangay});
                print(
                    'OneSignal: Tagged resident with barangay on app launch: $barangay');

                // Verify tags were set
                final tags = await OneSignal.User.getTags();
                print('Current OneSignal tags after setting: $tags');
              }
            } else {
              // If not a resident, check if user is a collector
              DocumentSnapshot collectorDoc = await FirebaseFirestore.instance
                  .collection('collector')
                  .doc(user.uid)
                  .get();

              if (collectorDoc.exists) {
                Map<String, dynamic> collectorData =
                    collectorDoc.data() as Map<String, dynamic>;
                String? barangay = collectorData['barangay'];

                if (barangay != null && barangay.isNotEmpty) {
                  print('Setting collector tags - barangay: $barangay');
                  await OneSignal.User.addTags(
                      {'barangay': barangay, 'user_type': 'collector'});
                  print(
                      'OneSignal: Tagged collector with barangay on app launch: $barangay');

                  // Verify tags were set
                  final tags = await OneSignal.User.getTags();
                  print('Current OneSignal tags after setting: $tags');
                }
              }
            }
          } catch (e) {
            print('Error setting OneSignal user ID on app launch: $e');
          }
        }
      });
    } catch (e) {
      print('OneSignal initialization error: $e');
    }
  }

  // Run the app
  runApp(const MyApp());
}

// NEW: Handle notification clicks and navigate accordingly
void _handleNotificationClick(OSNotification notification) {
  final data = notification.additionalData;

  if (data != null) {
    final type = data['type'];

    switch (type) {
      case 'scheduled_collection':
        // Navigate to schedule screen
        print('Navigating to schedule screen for collection notification');
        // You can implement navigation logic here
        break;
      case 'daily_schedule':
        // Navigate to schedule screen for daily schedule
        print('Navigating to schedule screen for daily schedule notification');
        break;
      case 'upcoming_collection':
        // Navigate to schedule screen for upcoming collection
        print(
            'Navigating to schedule screen for upcoming collection notification');
        break;
      case 'announcement':
        // Navigate to announcement screen
        print('Navigating to announcement screen');
        break;
      default:
        print('Unknown notification type: $type');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: kIsWeb ? '/admin-login' : '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/admin-login': (context) => const AdminLoginScreen(),
        '/admin-signup': (context) => const AdminSignupScreen(),
        '/admin-verification': (context) => const AdminVerificationScreen(),
        '/admin-dashboard': (context) => const AdminDashboardScreen(),
        '/complete-profile': (context) => const ResidentProfilePage(),
        '/dashboardResident': (context) => const DashboardScreen(),
        '/admin-announcement': (context) => const AdminAnnouncements(),
        '/addReports': (context) => const CreateReportScreen(),
        '/collector-signup': (context) => const CollectorSignUpScreen(),
        '/collector-verification': (context) =>
            const CollectorVerificationScreen(email: ''),
        '/collecto r-pending-approval': (context) =>
            const CollectorPendingApprovalScreen(),
        '/collector-dashboard': (context) => const CollectorDashboardScreen(),
        '/collector/scan': (context) => const CollectorScanScreen(),
        '/collector/scan-history': (context) =>
            const CollectorScanHistoryScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
      },
    );
  }
}
