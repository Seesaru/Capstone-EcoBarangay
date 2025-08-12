import 'dart:async';
import 'package:flutter/material.dart';
import 'package:capstone_ecobarangay/services/authentication.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';

class VerificationScreen extends StatefulWidget {
  final String email;

  const VerificationScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final AuthService _authService = AuthService();
  bool _isVerified = false;
  bool _isLoading = false;
  bool _isCheckingVerification = false;
  Timer? _timer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Start verification check timer with longer interval
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkEmailVerification(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerification({bool silent = false}) async {
    // Prevent multiple simultaneous checks
    if (_isCheckingVerification) return;

    setState(() {
      _isCheckingVerification = true;
      if (!silent) _isLoading = true;
      if (!silent) _errorMessage = null;
    });

    try {
      bool isVerified = await _authService.isUserVerified();

      if (isVerified) {
        _timer?.cancel();
        setState(() {
          _isVerified = true;
        });

        // Increased delay to 4 seconds to see the animation
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        });
      }
    } catch (e) {
      print("Verification check error: $e");
      if (!silent) {
        setState(() {
          _errorMessage = "Error checking verification status";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingVerification = false;
          if (!silent) _isLoading = false;
        });
      }
    }
  }

  // Modified to prevent multiple clicks
  Future<void> _manualCheckVerification() async {
    if (_isLoading) return; // Prevent clicking while already checking
    _checkEmailVerification(silent: false);
  }

  Future<void> _resendVerificationEmail() async {
    if (_isLoading) return; // Prevent multiple simultaneous operations

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      User? user = _authService.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Verification email sent!'),
                ],
              ),
              backgroundColor: Color(0xFF0E6B6F),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = "You need to be logged in to resend verification";
        });
      }
    } catch (e) {
      print("Resend verification error: $e");
      setState(() {
        _errorMessage = "Error sending verification email";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Modified to go back to registration page instead of login
  void _backToRegistration() {
    _timer?.cancel(); // Make sure to cancel the timer before navigating
    Navigator.pop(context); // Go back to registration page
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8F5E9),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade800),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                    if (_isVerified) ...[
                      // Success animation with better control
                      Center(
                        child: Lottie.asset(
                          'assets/lottie/verified.json',
                          width: 200,
                          height: 200,
                          repeat: true,
                          animate: true,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.check_circle,
                              color: Color(0xFF0E6B6F),
                              size: 100,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Center the container horizontally
                      Center(
                        child: Container(
                          width: MediaQuery.of(context).size.width *
                              0.85, // Set width to 85% of screen width
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF0E6B6F).withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Email Verified!',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0E6B6F),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Thank you for verifying your email address.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Redirecting to login screen...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Verification pending animation
                      Lottie.asset(
                        'assets/lottie/verify_animate.json',
                        width: 200,
                        height: 200,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF0E6B6F).withOpacity(0.1),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Verify your email',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0E6B6F),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'We\'ve sent a verification email to:',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Color(0xFF0E6B6F).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                widget.email,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0E6B6F),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Please check your inbox and click the verification link to continue.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (_isLoading)
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFF0E6B6F),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Checking verification status...',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ElevatedButton(
                          onPressed: _manualCheckVerification,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0E6B6F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                            shadowColor: Color(0xFF0E6B6F).withOpacity(0.3),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline),
                              SizedBox(width: 8),
                              Text(
                                'I\'ve verified my email',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _isLoading ? null : _resendVerificationEmail,
                        icon: Icon(Icons.refresh, color: Color(0xFF0E6B6F)),
                        label: Text(
                          'Resend verification email',
                          style: TextStyle(
                            color: Color(0xFF0E6B6F),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton.icon(
                        onPressed: _backToRegistration,
                        icon: Icon(Icons.arrow_back, color: Colors.grey),
                        label: Text(
                          'Back to registration',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
