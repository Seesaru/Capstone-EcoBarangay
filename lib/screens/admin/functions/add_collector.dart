import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/collector_auth.dart';
import '../../others/reusable_widgets.dart';

class AddCollectorForm extends StatefulWidget {
  final VoidCallback onCancel;
  final String adminBarangay;

  const AddCollectorForm({
    Key? key,
    required this.onCancel,
    required this.adminBarangay,
  }) : super(key: key);

  @override
  _AddCollectorFormState createState() => _AddCollectorFormState();
}

class _AddCollectorFormState extends State<AddCollectorForm> {
  final _formKey = GlobalKey<FormState>();
  final CollectorAuthService _collectorAuth = CollectorAuthService();

  // Text controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _barangayController = TextEditingController();

  String error = '';
  bool isLoading = false;
  bool _obscurePassword = true;
  final Color accentColor = const Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _barangayController.text = widget.adminBarangay;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _contactNumberController.dispose();
    _barangayController.dispose();
    super.dispose();
  }

  void _showSnackBar({required String message, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle,
                color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : accentColor,
        duration: const Duration(seconds: 4),
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
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      margin: const EdgeInsets.all(16),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_add, color: accentColor, size: 28),
                        const SizedBox(width: 16),
                        Text(
                          'Add New Collector',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onCancel,
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Personal Information',
                          accentColor: Color(0xFF4CAF50),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _fullNameController,
                          labelText: 'Full Name',
                          hintText: 'Enter collector\'s full name',
                          prefixIcon: Icons.person_outline,
                          validator: (val) =>
                              val!.isEmpty ? 'Enter full name' : null,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _contactNumberController,
                          labelText: 'Contact Number',
                          hintText: 'Enter mobile number',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (val) =>
                              val!.isEmpty ? 'Enter contact number' : null,
                        ),
                        const SizedBox(height: 24),
                        const SectionHeader(
                          title: 'Account Information',
                          accentColor: Color(0xFF4CAF50),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _emailController,
                          labelText: 'Email Address',
                          hintText: 'Enter collector\'s email',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) =>
                              val!.isEmpty ? 'Enter an email' : null,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _passwordController,
                          labelText: 'Password',
                          hintText: 'Enter password (minimum 6 characters)',
                          prefixIcon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          validator: (val) => val!.length < 6
                              ? 'Enter a password 6+ chars long'
                              : null,
                        ),
                        const SizedBox(height: 24),
                        const SectionHeader(
                          title: 'Location',
                          accentColor: Color(0xFF4CAF50),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _barangayController,
                          labelText: 'Barangay',
                          hintText: widget.adminBarangay,
                          prefixIcon: Icons.location_on_outlined,
                          validator: (val) =>
                              val!.isEmpty ? 'Barangay is required' : null,
                          onChanged: null,
                        ),
                        const SizedBox(height: 24),
                        if (error.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    error,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: isLoading
                                ? null
                                : () async {
                                    if (_formKey.currentState!.validate()) {
                                      setState(() => isLoading = true);
                                      try {
                                        await _collectorAuth.registerCollector(
                                          email: _emailController.text.trim(),
                                          password: _passwordController.text,
                                          fullName:
                                              _fullNameController.text.trim(),
                                          contactNumber:
                                              _contactNumberController.text
                                                  .trim(),
                                          barangay: _barangayController.text,
                                        );

                                        // Show success message
                                        if (mounted) {
                                          _showSnackBar(
                                            message:
                                                'Collector registered successfully!',
                                            isError: false,
                                          );
                                          widget.onCancel(); // Close the form
                                        }
                                      } on FirebaseAuthException catch (e) {
                                        setState(() {
                                          error =
                                              e.message ?? 'An error occurred';
                                          isLoading = false;
                                        });
                                        _showSnackBar(
                                          message: error,
                                          isError: true,
                                        );
                                      } catch (e) {
                                        setState(() {
                                          error =
                                              'An unexpected error occurred';
                                          isLoading = false;
                                        });
                                        _showSnackBar(
                                          message: error,
                                          isError: true,
                                        );
                                      }
                                    }
                                  },
                            child: isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Text(
                                    'Register Collector',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
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
}
