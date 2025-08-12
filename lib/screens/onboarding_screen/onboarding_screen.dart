import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to the appropriate screen after 5 seconds
    Timer(const Duration(seconds: 5), () {
      Navigator.pushReplacementNamed(context, '/login');
    });
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
          ],
        ),
      ),
    );
  }
}
