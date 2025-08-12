import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_ecobarangay/services/authentication.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_ecobarangay/utilities/terms_service_helper.dart';

class AdminSignupScreen extends StatefulWidget {
  const AdminSignupScreen({Key? key}) : super(key: key);

  @override
  State<AdminSignupScreen> createState() => _AdminSignupScreenState();
}

class _AdminSignupScreenState extends State<AdminSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _barangayController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  bool _isCheckingBarangay = false;
  bool _barangayExists = false;

  // Define your theme colors here
  final Color primaryColor = const Color(0xFF0E6B6F);
  final Color backgroundColor = Colors.white;
  final Color textColor = Colors.grey.shade800;

  // Helper method to create form fields
  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isConfirmPassword = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    String? prefix,
    List<TextInputFormatter>? inputFormatters,
    Function(String)? onChanged,
    String? tooltip,
  }) {
    final inputField = TextFormField(
      controller: controller,
      obscureText: isPassword
          ? _obscurePassword
          : (isConfirmPassword ? _obscureConfirmPassword : false),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        prefixText: prefix,
        suffixIcon: label == 'Barangay' && _isCheckingBarangay
            ? Container(
                width: 20,
                height: 20,
                padding: const EdgeInsets.all(8),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : (label == 'Barangay' && _barangayExists
                ? const Icon(Icons.warning, color: Colors.orange)
                : (isPassword || isConfirmPassword)
                    ? IconButton(
                        icon: Icon(
                          (isPassword
                                  ? _obscurePassword
                                  : _obscureConfirmPassword)
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            if (isPassword) {
                              _obscurePassword = !_obscurePassword;
                            } else {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            }
                          });
                        },
                      )
                    : null),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 16),
        labelStyle: TextStyle(color: Colors.grey),
        errorStyle: TextStyle(height: 0, color: Colors.transparent),
      ),
      validator: validator,
    );

    // If tooltip is provided, wrap with tooltip widget
    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: inputField,
        ),
      );
    }

    // Otherwise return the basic container
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: inputField,
    );
  }

  // Check if barangay name already exists
  Future<bool> _checkBarangayExists(String barangayName) async {
    if (barangayName.isEmpty) return false;

    setState(() {
      _isCheckingBarangay = true;
      _barangayExists = false;
    });

    try {
      // Query Firestore to check if the barangay name already exists
      QuerySnapshot querySnapshot = await _firestore
          .collection('barangays')
          .where('name', isEqualTo: barangayName)
          .get();

      bool exists = querySnapshot.docs.isNotEmpty;

      setState(() {
        _barangayExists = exists;
        _isCheckingBarangay = false;
      });

      return exists;
    } catch (e) {
      print("Error checking barangay existence: $e");
      setState(() {
        _isCheckingBarangay = false;
      });
      return false;
    }
  }

  Future<void> _signup() async {
    // Clear previous error message
    setState(() {
      _errorMessage = '';
    });

    // Collect all validation errors
    List<String> errors = [];

    // Check form validation
    if (!_formKey.currentState!.validate()) {
      errors.add('Please fill in all required fields correctly.');
    }

    // Check password match
    if (_passwordController.text != _confirmPasswordController.text) {
      errors.add('Passwords do not match.');
    }

    // Check terms acceptance
    if (!_acceptedTerms) {
      errors.add('You must accept the Terms and Services to continue.');
    }

    // Check for duplicate barangay name
    bool barangayExists =
        await _checkBarangayExists(_barangayController.text.trim());
    if (barangayExists) {
      errors.add(
          'A barangay with this name already exists. Please use a different name or contact support if this is your barangay.');
    }

    // If there are errors, display them and return
    if (errors.isNotEmpty) {
      setState(() {
        _errorMessage = errors.join('\n');
      });
      return;
    }

    // If no errors, proceed with signup
    setState(() {
      _isLoading = true;
    });

    try {
      // Register admin using the consolidated AuthService
      User? user = await _authService.registerAdmin(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        contactNumber: _contactController.text.trim(),
        barangay: _barangayController.text.trim(),
      );

      if (user != null) {
        // Show success SnackBar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Registration successful! Please check your email for verification.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              duration: Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );

          // Navigate to admin verification screen after a short delay
          Future.delayed(Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pushReplacementNamed(
                context,
                '/admin-verification',
                arguments: {'email': _emailController.text.trim()},
              );
            }
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Registration failed. Please try again.';
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Registration failed. Please try again.';
      });
      print(
          "FirebaseAuthException during admin signup: ${e.code} - ${e.message}");
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
      print("Error during admin signup: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.lightBlue.shade100, Colors.white],
          ),
        ),
        child: Center(
          child: Row(
            children: [
              // Left side - decorative area
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.eco_rounded, size: 80, color: primaryColor),
                      const SizedBox(height: 24),
                      Text(
                        'EcoBarangay',
                        style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: primaryColor),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Admin Registration Portal',
                        style: TextStyle(
                            fontSize: 24, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Create an admin account to manage your barangay\'s environmental initiatives, track progress, and engage with residents.',
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),

              // Right side - form area
              Expanded(
                flex: 3,
                child: Container(
                  color: Colors.white,
                  height: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Create Admin Account',
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Fill in the details below to register',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // Form fields in two columns
                            Flexible(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left column
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildFormField(
                                          controller: _nameController,
                                          label: 'Full Name',
                                          icon: Icons.person_outline,
                                          validator: (value) =>
                                              value == null || value.isEmpty
                                                  ? 'Please enter your name'
                                                  : null,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildFormField(
                                          controller: _contactController,
                                          label: 'Contact Number',
                                          icon: Icons.phone_outlined,
                                          keyboardType: TextInputType.number,
                                          prefix: '+63 ',
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                            LengthLimitingTextInputFormatter(
                                                10),
                                          ],
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Please enter your contact number';
                                            }
                                            if (value.length < 10) {
                                              return 'Please enter a valid 10-digit number';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        _buildFormField(
                                          controller: _passwordController,
                                          label: 'Password',
                                          icon: Icons.lock_outline,
                                          isPassword: true,
                                          validator: (value) {
                                            if (value == null || value.isEmpty)
                                              return 'Please enter a password';
                                            if (value.length < 6)
                                              return 'Password must be at least 6 characters';
                                            return null;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 24),

                                  // Right column
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildFormField(
                                          controller: _emailController,
                                          label: 'Email',
                                          icon: Icons.email_outlined,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          validator: (value) {
                                            if (value == null || value.isEmpty)
                                              return 'Please enter your email';
                                            if (!RegExp(
                                                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                                .hasMatch(value)) {
                                              return 'Please enter a valid email';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        _buildFormField(
                                          controller: _barangayController,
                                          label: 'Barangay',
                                          icon: Icons.location_city_outlined,
                                          validator: (value) =>
                                              value == null || value.isEmpty
                                                  ? 'Please enter your barangay'
                                                  : null,
                                          onChanged: (value) {
                                            if (value.isNotEmpty) {
                                              // Debounce the barangay check
                                              Future.delayed(
                                                  Duration(milliseconds: 500),
                                                  () {
                                                if (_barangayController.text ==
                                                    value) {
                                                  _checkBarangayExists(value);
                                                }
                                              });
                                            }
                                          },
                                          tooltip:
                                              'Enter a unique name for your barangay. This will be used as a unique identifier.',
                                        ),
                                        if (_barangayExists)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: 4.0, left: 12.0),
                                            child: Text(
                                              'This barangay name already exists',
                                              style: TextStyle(
                                                color: Colors.orange.shade800,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        if (!_barangayExists &&
                                            _barangayController.text.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: 4.0, left: 12.0),
                                            child: Text(
                                              'Unique barangay name available',
                                              style: TextStyle(
                                                color: Colors.green.shade800,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 16),
                                        _buildFormField(
                                          controller:
                                              _confirmPasswordController,
                                          label: 'Confirm Password',
                                          icon: Icons.lock_outline,
                                          isConfirmPassword: true,
                                          validator: (value) => value == null ||
                                                  value.isEmpty
                                              ? 'Please confirm your password'
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Centralized Error Message - moved outside of the columns
                            if (_errorMessage.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 24),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.red.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.error_outline,
                                            color: Colors.red, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Please correct the following:',
                                          style: TextStyle(
                                            color: Colors.red.shade800,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    ..._errorMessage
                                        .split('\n')
                                        .map((error) => Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 28, bottom: 4),
                                              child: Text(
                                                '• $error',
                                                style: TextStyle(
                                                    color: Colors.red.shade700,
                                                    fontSize: 13),
                                              ),
                                            )),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 24),

                            // Terms and Services checkbox
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _acceptedTerms,
                                    activeColor: primaryColor,
                                    onChanged: (bool? value) {
                                      setState(() =>
                                          _acceptedTerms = value ?? false);
                                    },
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      // Show the full Terms of Service page instead of dialog
                                      TermsServiceHelper.navigateToTermsPage(
                                          context);
                                    },
                                    child: Text(
                                      'Terms and Services',
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Signup Button wrapped with Tooltip
                            Tooltip(
                              message: !_acceptedTerms
                                  ? 'You must accept the Terms and Services to continue'
                                  : 'Create your admin account',
                              child: ElevatedButton(
                                onPressed: (_isLoading || !_acceptedTerms)
                                    ? null
                                    : _signup,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  disabledForegroundColor: Colors.grey.shade600,
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Text('Create Account',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500)),
                              ),
                            ),

                            // Already have an account
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("Already have an account?",
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14)),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pushReplacementNamed(
                                          context, '/admin'),
                                  child: Text('Sign in',
                                      style: TextStyle(
                                          color: primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _barangayController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
