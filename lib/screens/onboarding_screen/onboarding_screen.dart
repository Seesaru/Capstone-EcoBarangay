import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_ecobarangay/services/authentication.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Add a small delay to show splash screen
    await Future.delayed(const Duration(seconds: 3));

    try {
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        // User is logged in, check their role and redirect accordingly
        await _redirectBasedOnUserRole(currentUser);
      } else {
        // No user logged in, go to login screen
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      print('Error checking auth state: $e');
      // If there's an error, go to login screen
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _redirectBasedOnUserRole(User user) async {
    try {
      // Check if user is a resident
      DocumentSnapshot residentDoc =
          await _firestore.collection('resident').doc(user.uid).get();

      if (residentDoc.exists) {
        // User is a resident, check if profile is completed
        bool isProfileCompleted = await _authService.isProfileCompleted();

        if (mounted) {
          if (isProfileCompleted) {
            Navigator.pushReplacementNamed(context, '/dashboardResident');
          } else {
            Navigator.pushReplacementNamed(context, '/complete-profile');
          }
        }
        return;
      }

      // Check if user is a collector
      DocumentSnapshot collectorDoc =
          await _firestore.collection('collector').doc(user.uid).get();

      if (collectorDoc.exists) {
        Map<String, dynamic> collectorData =
            collectorDoc.data() as Map<String, dynamic>;

        // Check if collector is approved
        bool isApproved = collectorData['isApproved'] ?? false;

        if (mounted) {
          if (isApproved) {
            Navigator.pushReplacementNamed(context, '/collector-dashboard');
          } else {
            Navigator.pushReplacementNamed(
                context, '/collector-pending-approval');
          }
        }
        return;
      }

      // Check if user is an admin
      DocumentSnapshot adminDoc =
          await _firestore.collection('barangay_admins').doc(user.uid).get();

      if (adminDoc.exists) {
        // User is an admin, redirect to admin dashboard
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/admin-dashboard');
        }
        return;
      }

      // If user exists in Firebase Auth but not in any collection, sign them out
      print(
          'User exists in Firebase Auth but not in any collection, signing out');
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('Error checking user role: $e');
      // If there's an error, go to login screen
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/icon/eco_splash.png',
              width: 180,
              height: 180,
            ),
            const SizedBox(height: 30),
            // App name
            const Text(
              'EcoBarangay',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0E6B6F),
              ),
            ),
            const SizedBox(height: 10),
            // Motto
            const Text(
              'Sustaining Communities',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF0E6B6F),
              ),
            ),
            const SizedBox(height: 30),
            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0E6B6F)),
            ),
          ],
        ),
      ),
    );
  }
}
