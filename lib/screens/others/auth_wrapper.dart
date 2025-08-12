import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_ecobarangay/services/authentication.dart';
import 'package:capstone_ecobarangay/screens/residents/login_page.dart';
import 'package:capstone_ecobarangay/screens/residents/home_screen.dart';
import 'package:capstone_ecobarangay/screens/residents/complete_profile.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  Widget? _redirectWidget;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User is logged in, check if profile is completed
      bool isProfileCompleted = await _authService.isProfileCompleted();

      setState(() {
        if (isProfileCompleted) {
          _redirectWidget = const HomeScreen();
        } else {
          _redirectWidget = const ResidentProfilePage();
        }
        _isLoading = false;
      });
    } else {
      // No user logged in
      setState(() {
        _redirectWidget = const LoginScreen();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _redirectWidget!;
  }
}