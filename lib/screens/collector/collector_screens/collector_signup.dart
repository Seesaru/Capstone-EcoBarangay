import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_ecobarangay/services/collector_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_ecobarangay/screens/others/collector_verification_screen.dart';
import 'package:capstone_ecobarangay/utilities/terms_service_helper.dart';
import 'package:flutter/services.dart'; // Added for FilteringTextInputFormatter

class CollectorSignUpScreen extends StatefulWidget {
  const CollectorSignUpScreen({super.key});

  @override
  State<CollectorSignUpScreen> createState() => _CollectorSignUpScreenState();
}

class _CollectorSignUpScreenState extends State<CollectorSignUpScreen> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _acceptedTerms = false;
  String? _errorMessage;
  final CollectorAuthService _collectorAuthService = CollectorAuthService();
  // Controllers for form fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _barangayController = TextEditingController();

  // For barangay dropdown
  String? _selectedBarangay;
  List<String> _barangaySuggestions = [];
  bool _isLoadingBarangays = true;
  List<String> _filteredBarangays = [];
  Map<String, String> _barangayIdMap = {};

  @override
  void initState() {
    super.initState();
    // Try to load barangays, but have fallback
    _loadBarangayData();

    // Setup listener to filter barangays as user types
    _barangayController.addListener(_filterBarangays);
  }

  void togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void toggleConfirmPasswordVisibility() {
    setState(() {
      _obscureConfirmPassword = !_obscureConfirmPassword;
    });
  }

  void _onBackToLoginTap() {
    // Navigate back to login screen using named route
    Navigator.pushReplacementNamed(context, '/login');
  }

  // Registration method
  Future<void> _register() async {
    // Validate form
    if (!_validateForm()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get barangayId from the mapping if available
      String barangayName = _selectedBarangay!;
      String? barangayId = _barangayIdMap[barangayName];

      // Register collector using the service
      User? user = await _collectorAuthService.registerCollector(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        contactNumber: _contactNumberController.text.trim(),
        barangay: barangayName,
        barangayId: barangayId,
      );

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Your collector account has been registered! Please verify your email.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Wait a moment to show the success message before navigating
        await Future.delayed(const Duration(milliseconds: 1500));

        // Navigate to verification screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CollectorVerificationScreen(
                email: _emailController.text.trim(),
              ),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getMessageFromErrorCode(e.code);
      });
    } catch (e) {
      print("Registration error: $e");
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _validateForm() {
    // Check if all fields are filled
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty ||
        _fullNameController.text.isEmpty ||
        _contactNumberController.text.isEmpty ||
        _selectedBarangay == null) {
      setState(() {
        _errorMessage = 'Please fill in all fields';
      });
      return false;
    }

    // Check if terms are accepted
    if (!_acceptedTerms) {
      setState(() {
        _errorMessage = 'You must accept the Terms and Services to continue';
      });
      return false;
    }

    // Validate email format
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      setState(() {
        _errorMessage = 'Please enter a valid email address';
      });
      return false;
    }

    // Check if passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return false;
    }

    // Check password strength (at least 6 characters)
    if (_passwordController.text.length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters long';
      });
      return false;
    }

    // Validate contact number format
    String phoneNumber =
        _contactNumberController.text.replaceAll(RegExp(r'\D'), '');
    if (phoneNumber.isEmpty ||
        phoneNumber.length != 10 ||
        !phoneNumber.startsWith('9')) {
      setState(() {
        _errorMessage =
            'Please enter a valid Philippine mobile number (must start with 9)';
      });
      return false;
    }

    return true;
  }

  // Helper method to get user-friendly error messages
  String _getMessageFromErrorCode(String errorCode) {
    switch (errorCode) {
      case 'email-already-in-use':
        return 'This email is already registered. Please login instead.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'weak-password':
        return 'The password is too weak.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  // Modified to fetch barangays from Firestore
  // Replace the current _loadBarangayData method with this one to fetch from Firestore
  Future<void> _loadBarangayData() async {
    try {
      setState(() {
        _isLoadingBarangays = true;
      });

      // Get barangays directly from the barangays collection
      QuerySnapshot barangayQuery =
          await FirebaseFirestore.instance.collection('barangays').get();

      // Extract barangay names from documents
      List<String> barangayList = [];
      Map<String, String> barangayIdMap =
          {}; // Store barangayId to name mapping

      for (var doc in barangayQuery.docs) {
        if (doc.data() is Map) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          if (data.containsKey('name')) {
            String? barangay = data['name'] as String?;
            String? barangayId = data['barangayId'] as String?;

            if (barangay != null && barangay.isNotEmpty) {
              barangayList.add(barangay);

              // Store barangayId mapping if available (for new entries)
              if (barangayId != null && barangayId.isNotEmpty) {
                barangayIdMap[barangay] = barangayId;
              } else {
                // For backward compatibility with existing data
                barangayIdMap[barangay] = doc.id;
              }
            }
          }
        }
      }

      // If no barangays found, add some defaults
      if (barangayList.isEmpty) {
        barangayList = ['Barangay 1', 'Barangay 2', 'Barangay 3'];
      }

      setState(() {
        _barangaySuggestions = barangayList;
        _filteredBarangays = List.from(_barangaySuggestions);
        _barangayIdMap = barangayIdMap; // Store the mapping
        _isLoadingBarangays = false;
      });
    } catch (e) {
      print('Error loading barangay data: $e');
      setState(() {
        _isLoadingBarangays = false;
        // Add some default barangays if there's an error
        _barangaySuggestions = ['Barangay 1', 'Barangay 2', 'Barangay 3'];
        _filteredBarangays = List.from(_barangaySuggestions);
      });
      // Optional: show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load barangay data')),
        );
      }
    }
  }

  // Filter barangays based on input text
  void _filterBarangays() {
    if (_barangayController.text.isEmpty) {
      setState(() {
        _filteredBarangays = List.from(_barangaySuggestions);
      });
    } else {
      setState(() {
        _filteredBarangays = _barangaySuggestions
            .where((barangay) => barangay
                .toLowerCase()
                .contains(_barangayController.text.toLowerCase()))
            .toList();
        _selectedBarangay = _barangayController.text.trim();
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _contactNumberController.dispose();
    _barangayController.removeListener(_filterBarangays);
    _barangayController.dispose();
    super.dispose();
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
                              'Sustaining Communities, Protecting Nature',
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
                    // Right side - signup form (takes about 60% of screen width)
                    Expanded(
                      flex: 6,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 450),
                            child: _buildSignUpForm(isLandscape: true),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              // Portrait layout
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
                            padding: const EdgeInsets.only(top: 40, bottom: 30),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Add Lottie animation here
                                Lottie.asset(
                                  'assets/lottie/signup.json',
                                  width: 110,
                                  height: 110,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Collector Sign Up',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0E6B6F),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                const Text(
                                  'Register as a waste collector',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Signup form
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 450),
                                child: _buildSignUpForm(),
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

  Widget _buildSignUpForm({bool isLandscape = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: isLandscape ? 8 : 16),

        // Display error message if any
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade800, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isLandscape ? 8 : 16),
        ],

        // Full Name field
        _buildFullNameField(),
        const SizedBox(height: 16),

        // Contact Number field
        _buildContactNumberField(),
        const SizedBox(height: 16),

        // Barangay dropdown
        _buildBarangayDropdown(),
        const SizedBox(height: 16),

        // Email field
        _buildEmailField(),
        const SizedBox(height: 16),

        // Password fields
        _buildPasswordField(),
        const SizedBox(height: 16),

        _buildConfirmPasswordField(),
        const SizedBox(height: 16),

        // Terms and Services checkbox
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Checkbox(
                value: _acceptedTerms,
                activeColor: const Color(0xFF0E6B6F),
                onChanged: (bool? value) {
                  setState(() {
                    _acceptedTerms = value ?? false;
                  });
                },
              ),
              const Text(
                'I agree to the ',
                style: TextStyle(fontSize: 14),
              ),
              GestureDetector(
                onTap: () {
                  // Show the full Terms of Service page instead of dialog
                  TermsServiceHelper.navigateToTermsPage(context);
                },
                child: Text(
                  'Terms and Services',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF0E6B6F),
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Sign Up button
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isLoading || !_acceptedTerms) ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E6B6F),
                padding: EdgeInsets.symmetric(vertical: isLandscape ? 12 : 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Register as Collector',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),

        // Already have an account
        Padding(
          padding: EdgeInsets.only(top: isLandscape ? 12 : 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Already have an account? ",
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              GestureDetector(
                onTap: _onBackToLoginTap,
                child: const Text(
                  'Login',
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

  Widget _buildFullNameField() {
    return TextField(
      controller: _fullNameController,
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
        prefixIcon: const Icon(Icons.person_outline),
        hintText: 'Full Name',
      ),
    );
  }

  Widget _buildContactNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      '🇵🇭',
                      style: TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+63',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _contactNumberController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  onChanged: (value) {
                    // Only format if there's actual input
                    if (value.isNotEmpty) {
                      String digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                      
                      // Format the number
                      String formattedNumber = '';
                      for (int i = 0; i < digitsOnly.length; i++) {
                        if (i == 0 && digitsOnly[i] != '9') continue;
                        formattedNumber += digitsOnly[i];
                        if ((i + 1) % 3 == 0 && i != digitsOnly.length - 1) {
                          formattedNumber += ' ';
                        }
                      }

                      // Update controller only if the format is different
                      if (formattedNumber != value) {
                        _contactNumberController.value = TextEditingValue(
                          text: formattedNumber,
                          selection: TextSelection.collapsed(offset: formattedNumber.length),
                        );
                      }
                    }
                  },
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: '9XX XXX XXXX',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    counterText: '', // Hide the character counter
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Enter your Philippine mobile number',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarangayDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Registered Barangay',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _barangayController,
          readOnly: true,
          onTap: () => _showBarangaySelector(context),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xFF0E6B6F), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            prefixIcon: const Icon(Icons.location_city_outlined,
                color: Color(0xFF0E6B6F)),
            hintText: 'Select your barangay',
            suffixIcon: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0E6B6F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_drop_down,
                color: Color(0xFF0E6B6F),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Select the barangay where you are registered',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  void _showBarangaySelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        const Text(
                          'Select Barangay',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0E6B6F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose your registered barangay',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _filteredBarangays = _barangaySuggestions
                              .where((barangay) => barangay
                                  .toLowerCase()
                                  .contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search barangay...',
                        prefixIcon:
                            const Icon(Icons.search, color: Color(0xFF0E6B6F)),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: _isLoadingBarangays
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF0E6B6F)),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Loading barangays...',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredBarangays.length,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemBuilder: (context, index) {
                              final barangay = _filteredBarangays[index];
                              final isSelected = _selectedBarangay == barangay;

                              return Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF0E6B6F).withOpacity(0.1)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF0E6B6F)
                                        : Colors.grey[300]!,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  title: Text(
                                    barangay,
                                    style: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFF0E6B6F)
                                          : Colors.black87,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle,
                                          color: Color(0xFF0E6B6F))
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _selectedBarangay = barangay;
                                      _barangayController.text = barangay;
                                    });
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
        hintText: 'Email',
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

  Widget _buildConfirmPasswordField() {
    return TextField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
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
            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: toggleConfirmPasswordVisibility,
        ),
        hintText: 'Confirm Password',
      ),
    );
  }
}
