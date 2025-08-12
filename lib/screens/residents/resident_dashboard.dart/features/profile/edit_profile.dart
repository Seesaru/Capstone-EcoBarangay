import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloudinary_url_gen/cloudinary.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentFullName;
  final String currentEmail;
  final String currentBarangay;
  final String currentProfileImageUrl;

  const EditProfileScreen({
    Key? key,
    required this.currentFullName,
    required this.currentEmail,
    required this.currentBarangay,
    required this.currentProfileImageUrl,
  }) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _purokController;
  late TextEditingController _contactController;

  String _barangay = '';
  String _profileImageUrl = '';
  File? _newProfileImage;
  bool _isLoading = false;
  bool _isUploading = false;

  String? _phoneNumberError;

  // Cloudinary configuration
  final cloudinary = Cloudinary.fromCloudName(cloudName: 'dy00gocov');

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.currentFullName);
    _emailController = TextEditingController(text: widget.currentEmail);
    _barangay = widget.currentBarangay;
    _profileImageUrl = widget.currentProfileImageUrl;
    _loadAdditionalUserData();
    _purokController = TextEditingController();
    _contactController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _purokController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _loadAdditionalUserData() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('resident').doc(currentUser.uid).get();

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;

          // Format the phone number - remove +63 prefix if it exists
          String phoneNumber = userData['contactNumber'] ?? '';
          if (phoneNumber.startsWith('+63')) {
            phoneNumber = phoneNumber.substring(3);
          }

          setState(() {
            _purokController.text = userData['purok'] ?? '';
            _contactController.text = phoneNumber;
          });
        }
      }
    } catch (e) {
      print('Error loading additional user data: ${e.toString()}');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _newProfileImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show image source selection dialog
  Future<void> _showImageSourceDialog() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Image Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 3, 144, 123),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // Build image source selection option
  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 3, 144, 123).withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              size: 30,
              color: const Color.fromARGB(255, 3, 144, 123),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _uploadImage() async {
    if (_newProfileImage == null) return null;

    try {
      setState(() {
        _isUploading = true;
      });

      User? currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      // Cloudinary configuration
      final cloudName = 'dy00gocov';
      final uploadPreset = 'eco_barangay';

      // Prepare the upload URL
      final uri =
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      // Generate unique file name
      String userId = currentUser.uid;
      String fileName =
          'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}';

      // Create multipart request
      var request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'ecobarangay/profiles'
        ..fields['public_id'] = fileName
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          _newProfileImage!.path,
        ));

      // Send the request
      var response = await request.send();

      // Get response data
      var responseData = await response.stream.toBytes();
      var responseString = String.fromCharCodes(responseData);

      // Parse response
      final jsonData = jsonDecode(responseString);

      setState(() {
        _isUploading = false;
      });

      if (response.statusCode == 200) {
        return jsonData['secure_url'];
      } else {
        throw Exception(
            'Failed to upload image: ${jsonData['error'] != null ? jsonData['error']['message'] : 'Unknown error'}');
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      print('Error uploading image: ${e.toString()}');
      if (mounted) {
        _showCustomErrorSnackBar('Error uploading image: ${e.toString()}');
      }
      return null;
    }
  }

  bool isValidPhilippineNumber(String number) {
    // Remove any whitespace or special characters
    String cleanNumber = number.replaceAll(RegExp(r'[^\d]'), '');

    // Check if the number has exactly 10 digits and starts with 9
    if (cleanNumber.length == 10 && cleanNumber.startsWith('9')) {
      return true;
    }
    return false;
  }

  void validatePhoneNumber(String value) {
    setState(() {
      if (value.isEmpty) {
        _phoneNumberError = 'Phone number is required';
      } else if (!isValidPhilippineNumber(value)) {
        _phoneNumberError =
            'Please enter a valid Philippine mobile number (9XXXXXXXXX)';
      } else {
        _phoneNumberError = null;
      }
    });
  }

  Future<void> _saveProfile() async {
    // Validate phone number before saving
    validatePhoneNumber(_contactController.text);
    if (_phoneNumberError != null) {
      _showCustomErrorSnackBar(_phoneNumberError!);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Upload new image if selected
      String? newImageUrl;
      if (_newProfileImage != null) {
        newImageUrl = await _uploadImage();
      }

      // Format phone number to include country code
      String formattedPhoneNumber = '+63${_contactController.text.trim()}';

      // Update profile data
      Map<String, dynamic> updateData = {
        'fullName': _fullNameController.text.trim(),
        'barangay': _barangay,
        'purok': _purokController.text.trim(),
        'contactNumber': formattedPhoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add image URL to update data if new image was uploaded
      if (newImageUrl != null) {
        updateData['profileImageUrl'] = newImageUrl;
      }

      // Update email if it has changed and user is authenticated
      if (_emailController.text.trim() != currentUser.email) {
        await currentUser.updateEmail(_emailController.text.trim());
        updateData['email'] = _emailController.text.trim();
      }

      // Update Firestore document
      await _firestore
          .collection('resident')
          .doc(currentUser.uid)
          .update(updateData);

      if (mounted) {
        _showCustomSnackBar('Profile updated successfully');
        Navigator.pop(
            context, true); // Return true to indicate profile was updated
      }
    } catch (e) {
      print('Error updating profile: ${e.toString()}');
      if (mounted) {
        _showCustomErrorSnackBar('Error updating profile: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Show custom styled SnackBar
  void _showCustomSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color.fromARGB(255, 3, 144, 123),
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        elevation: 4,
      ),
    );
  }

  // Show custom styled error SnackBar
  void _showCustomErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        elevation: 4,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color.fromARGB(255, 3, 144, 123),
        title: const Text(
          "Edit Profile",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: const Color.fromARGB(255, 3, 144, 123),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  // Profile Image
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color.fromARGB(255, 3, 144, 123),
                              width: 2,
                            ),
                          ),
                          child: _isUploading
                              ? CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.grey[200],
                                  child: const CircularProgressIndicator(
                                    color: Color.fromARGB(255, 3, 144, 123),
                                  ),
                                )
                              : CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: _newProfileImage != null
                                      ? FileImage(_newProfileImage!)
                                          as ImageProvider
                                      : (_profileImageUrl.isNotEmpty
                                          ? NetworkImage(_profileImageUrl)
                                          : null),
                                  child: (_newProfileImage == null &&
                                          _profileImageUrl.isEmpty)
                                      ? const Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.grey,
                                        )
                                      : null,
                                ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showImageSourceDialog,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color.fromARGB(255, 3, 144, 123),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Form
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          offset: const Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 3, 144, 123),
                          ),
                        ),
                        const SizedBox(height: 25),

                        // Full Name
                        _buildField(
                          controller: _fullNameController,
                          label: 'Full Name',
                          icon: Icons.person_outline,
                        ),

                        const SizedBox(height: 20),

                        // Email
                        _buildField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),

                        const SizedBox(height: 20),

                        // Barangay (non-editable)
                        _buildNonEditableField(
                          value: _barangay,
                          label: 'Barangay',
                          icon: Icons.location_city_outlined,
                        ),

                        const SizedBox(height: 20),

                        // Purok
                        _buildField(
                          controller: _purokController,
                          label: 'Purok',
                          icon: Icons.home_outlined,
                        ),

                        const SizedBox(height: 20),

                        // Contact Number
                        _buildField(
                          controller: _contactController,
                          label: 'Contact Number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Save Button
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 3, 144, 123),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final primaryColor = const Color.fromARGB(255, 3, 144, 123);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: primaryColor,
            ),
          ),
        ),
        if (label == 'Contact Number')
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: _phoneNumberError != null ? Colors.red : Colors.grey[300]!,
                    width: _phoneNumberError != null ? 2 : 1,
                  ),
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
                        controller: controller,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        onChanged: (value) {
                          // Only validate if there's actual input
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
                              controller.value = TextEditingValue(
                                text: formattedNumber,
                                selection: TextSelection.collapsed(offset: formattedNumber.length),
                              );
                            }
                          }
                          validatePhoneNumber(value);
                        },
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[50],
                          hintText: '9XX XXX XXXX',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
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
              if (_phoneNumberError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                  child: Text(
                    _phoneNumberError!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          )
        else
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[50],
              hintText: 'Enter your ${label.toLowerCase()}',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              prefixIcon: Icon(
                icon,
                color: primaryColor,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              floatingLabelBehavior: FloatingLabelBehavior.never,
            ),
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
      ],
    );
  }

  Widget _buildNonEditableField({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final primaryColor = const Color.fromARGB(255, 3, 144, 123);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: primaryColor,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: primaryColor,
              ),
              const SizedBox(width: 16),
              Text(
                value.isEmpty ? 'Not available' : value,
                style: TextStyle(
                  fontSize: 16,
                  color: value.isEmpty ? Colors.grey[500] : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
