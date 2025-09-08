import 'package:flutter/material.dart';
import 'package:capstone_ecobarangay/services/authentication.dart';
import 'package:capstone_ecobarangay/services/collector_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoggingIn = false;
  bool _isCollector = false;
  final AuthService _authService = AuthService();
  final CollectorAuthService _collectorAuthService = CollectorAuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void toggleUserType() {
    setState(() {
      _isCollector = !_isCollector;
    });
  }

  void _onSignUpTap() {
    Navigator.pushNamed(context, '/signup');
  }

  void _onCollectorSignUpTap() {
    Navigator.pushNamed(context, '/collector-signup');
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please enter both email and password',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.05,
            left: 20,
            right: 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoggingIn = true;
    });

    try {
      // Pre-trim the email before authentication to avoid doing it twice
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isCollector) {
        // Handle collector login
        UserCredential userCredential = await _collectorAuthService
            .signInCollectorWithEmailAndPassword(email, password);

        // Log the collector login
        await _collectorAuthService.logCollectorLogin(userCredential.user!.uid);

        // Check if collector is approved
        DocumentSnapshot collectorDoc = await _firestore
            .collection('collector')
            .doc(userCredential.user!.uid)
            .get();

        Map<String, dynamic> collectorData =
            collectorDoc.data() as Map<String, dynamic>;

        // Check if collector is approved
        bool isApproved = collectorData['isApproved'] ?? false;
        if (!isApproved) {
          // Collector is not yet approved, redirect to pending approval screen
          if (mounted) {
            Navigator.pushReplacementNamed(
                context, '/collector-pending-approval');
          }
          return;
        }

        // Successfully authenticated as a collector
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/collector-dashboard');
        }
      } else {
        // Handle resident login
        UserCredential userCredential =
            await _authService.signInWithEmailAndPassword(email, password);

        // Log the resident login
        await _authService.logResidentLogin(userCredential.user!.uid);

        // Only check profile completion after successful login
        bool isProfileCompleted = await _authService.isProfileCompleted();

        // Ensure the navigation only happens if the widget is still mounted
        if (mounted) {
          if (isProfileCompleted) {
            Navigator.pushReplacementNamed(context, '/dashboardResident');
          } else {
            Navigator.pushReplacementNamed(context, '/complete-profile');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Login failed';
        String errorCode = 'unknown_error';

        // Clean up error message for better user experience
        if (e is FirebaseAuthException) {
          errorCode = e.code;
          switch (e.code) {
            case 'user-not-found':
              errorMessage = 'No account found with this email';
              break;
            case 'wrong-password':
              errorMessage = 'Invalid password';
              break;
            case 'invalid-credential':
              errorMessage = 'Invalid email or password';
              break;
            case 'user-disabled':
              errorMessage = 'This account has been disabled';
              break;
            case 'too-many-requests':
              errorMessage = 'Too many login attempts. Please try again later';
              break;
            case 'not-resident':
              errorMessage =
                  'This account is registered as a collector. Please toggle to collector login.';
              break;
            case 'not-collector':
              errorMessage =
                  'This account is registered as a resident. Please toggle to resident login.';
              break;
            case 'inactive-account':
              errorMessage =
                  'This collector account is inactive. Please contact your administrator.';
              break;
            case 'email-not-verified':
              errorMessage = 'Please verify your email before logging in';
              break;
            default:
              errorMessage =
                  e.message?.replaceAll(RegExp(r'\[.*\]'), '').trim() ??
                      'Login failed';
          }

          // Log failed login attempt for residents only
          if (!_isCollector) {
            _authService.logFailedLoginAttempt(
                _emailController.text.trim(), errorCode);
          } else {
            // Log failed login attempt for collectors
            _collectorAuthService.logFailedLoginAttempt(
                _emailController.text.trim(), errorCode);
          }
        } else {
          // For non-Firebase errors
          errorMessage = e.toString().contains('Exception:')
              ? e.toString().split('Exception:')[1].trim()
              : e.toString();

          // Log failed login attempts
          if (!_isCollector) {
            // For residents
            _authService.logFailedLoginAttempt(
                _emailController.text.trim(), 'non_firebase_error');
          } else {
            // For collectors
            _collectorAuthService.logFailedLoginAttempt(
                _emailController.text.trim(), 'non_firebase_error');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height * 0.05,
              left: 20,
              right: 20,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions and orientation
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: isLandscape
              // Landscape layout
              ? Row(
                  children: [
                    // Left side - logo and app name (takes about 40% of screen width)
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset(
                              'assets/lottie/icon.json',
                              width: 100,
                              height: 100,
                            ),
                            const Text(
                              'EcoBarangay',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0E6B6F),
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Sustaining Communities',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Right side - login form (takes about 60% of screen width)
                    Expanded(
                      flex: 6,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 450),
                            child: _buildLoginForm(isLandscape: true),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              // Portrait layout (modified for better centering)
              : SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height -
                          MediaQuery.of(context).padding.top -
                          MediaQuery.of(context).padding.bottom,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo section with reduced vertical padding
                          Padding(
                            padding: const EdgeInsets.only(top: 20, bottom: 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Lottie.asset(
                                  'assets/lottie/icon.json',
                                  width: 110,
                                  height: 110,
                                ),
                                const Text(
                                  'EcoBarangay',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0E6B6F),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Sustaining Communities',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Login form with adjusted padding
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 450),
                                child: _buildLoginForm(),
                              ),
                            ),
                          ),
                          // Add some padding at the bottom
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLoginForm({bool isLandscape = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Login header text first
        Center(
          child: Text(
            'Login',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0E6B6F),
            ),
          ),
        ),
        SizedBox(height: isLandscape ? 8 : 12),

        // User type toggle below login text
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Resident toggle
                  GestureDetector(
                    onTap: () {
                      if (_isCollector) toggleUserType();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: !_isCollector
                            ? Color(0xFF0E6B6F)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        'Resident',
                        style: TextStyle(
                          color: !_isCollector
                              ? Colors.white
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Collector toggle
                  GestureDetector(
                    onTap: () {
                      if (!_isCollector) toggleUserType();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: _isCollector
                            ? Color(0xFF0E6B6F)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        'Collector',
                        style: TextStyle(
                          color: _isCollector
                              ? Colors.white
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: isLandscape ? 16 : 20),

        // Email and password fields - side by side in landscape, stacked in portrait
        if (isLandscape)
          Row(
            children: [
              // Email field
              Expanded(child: _buildEmailField()),
              const SizedBox(width: 16),
              // Password field
              Expanded(child: _buildPasswordField()),
            ],
          )
        else ...[
          _buildEmailField(),
          const SizedBox(height: 16),
          _buildPasswordField(),
        ],

        // Forgot password
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/forgot-password');
            },
            child: const Text(
              'Forgot Password',
              style: TextStyle(
                color: Color(0xFF0E6B6F),
                fontSize: 12,
              ),
            ),
          ),
        ),

        // Login button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoggingIn ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E6B6F),
              padding: EdgeInsets.symmetric(vertical: isLandscape ? 12 : 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: _isLoggingIn
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _isCollector ? 'Login as Collector' : 'Login as Resident',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),

        // Don't have account text with sign up link
        Padding(
          padding: EdgeInsets.only(top: isLandscape ? 12 : 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              GestureDetector(
                onTap: _isCollector ? _onCollectorSignUpTap : _onSignUpTap,
                child: Text(
                  _isCollector ? 'Sign up as Collector' : 'Sign up as Resident',
                  style: TextStyle(
                    color: Color(0xFF0E6B6F),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Color(0xFF0E6B6F), width: 2),
        ),
        prefixIcon: const Icon(Icons.email_outlined),
        hintText: _isCollector ? 'Collector Email' : 'Email',
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Color(0xFF0E6B6F), width: 2),
        ),
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: togglePasswordVisibility,
        ),
        hintText: 'Password',
      ),
    );
  }
}
