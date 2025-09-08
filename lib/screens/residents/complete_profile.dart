import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloudinary_url_gen/cloudinary.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';

class ResidentProfilePage extends StatefulWidget {
  const ResidentProfilePage({Key? key}) : super(key: key);

  @override
  State<ResidentProfilePage> createState() => _ResidentProfilePageState();
}

class _ResidentProfilePageState extends State<ResidentProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cloudinary instance
  final cloudinary = Cloudinary.fromCloudName(cloudName: 'dy00gocov');

  // For profile image
  File? _imageFile;
  String? _profileImageUrl;
  bool _isUploading = false;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _barangayController = TextEditingController();
  final TextEditingController _purokController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  String _selectedGender = 'Male';
  List<String> _genderOptions = ['Male', 'Female', 'Prefer not to say'];

  // For barangay suggestions
  List<String> _barangaySuggestions = [];
  List<String> _filteredBarangays = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, String> _barangayIdMap = {};
  String? _selectedBarangay;
  bool _isLoadingBarangays = true;

  // For page slider
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 4; // Now 4 pages with summary as the last page

  @override
  void initState() {
    super.initState();
    _loadBarangayData();
    _loadUserData();
    // Setup listener to filter barangays as user types
    _barangayController.addListener(_filterBarangays);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barangayController.removeListener(_filterBarangays);
    _barangayController.dispose();
    _purokController.dispose();
    _contactController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Pick image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });

        // Upload image immediately after picking
        _uploadImageToCloudinary();
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: ${e.toString()}')),
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
                  color: const Color(0xFF0E6B6F),
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
              color: const Color(0xFF0E6B6F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              size: 30,
              color: const Color(0xFF0E6B6F),
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

  // Upload image to Cloudinary
  Future<void> _uploadImageToCloudinary() async {
    if (_imageFile == null) return;

    try {
      setState(() {
        _isUploading = true;
      });

      // Your Cloudinary cloud name
      final cloudName = 'dy00gocov';
      // Create an upload preset in your Cloudinary dashboard (unsigned)
      final uploadPreset =
          'eco_barangay'; // Create this in Cloudinary dashboard

      // Prepare the upload URL
      final uri =
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      // Get current user ID for unique file name
      String userId = _auth.currentUser?.uid ?? 'unknown';
      String fileName =
          'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}';

      // Create multipart request
      var request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'ecobarangay/profiles'
        ..fields['public_id'] = fileName
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          _imageFile!.path,
        ));

      // Send the request
      var response = await request.send();

      // Get response data
      var responseData = await response.stream.toBytes();
      var responseString = String.fromCharCodes(responseData);

      // Parse response
      final jsonData = jsonDecode(responseString);

      if (response.statusCode == 200) {
        setState(() {
          _profileImageUrl = jsonData['secure_url'];
          _isUploading = false;
        });

        print('Image uploaded successfully: $_profileImageUrl');

        // Save to Firestore
        if (_auth.currentUser != null) {
          await _firestore
              .collection('resident')
              .doc(_auth.currentUser!.uid)
              .update({
            'profileImageUrl': _profileImageUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        throw Exception(
            'Failed to upload image: ${jsonData['error'] != null ? jsonData['error']['message'] : 'Unknown error'}');
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      print('Error uploading image to Cloudinary: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: ${e.toString()}')),
        );
      }
    }
  }

  // Load barangay suggestions from Firestore
  Future<void> _loadBarangayData() async {
    try {
      setState(() {
        _isLoading = true;
        _isLoadingBarangays = true;
      });

      // Get barangays directly from the barangays collection
      QuerySnapshot barangayQuery =
          await _firestore.collection('barangays').get();

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
        _isLoading = false;
        _isLoadingBarangays = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingBarangays = false;
        // Add some default barangays if there's an error
        _barangaySuggestions = ['Barangay 1', 'Barangay 2', 'Barangay 3'];
        _filteredBarangays = List.from(_barangaySuggestions);
      });
      print('Error loading barangay data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load barangay data')),
      );
    }
  }

  // Load existing user data if available
  Future<void> _loadUserData() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('resident').doc(currentUser.uid).get();

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;

          setState(() {
            _nameController.text = userData['fullName'] ?? '';
            _barangayController.text = userData['barangay'] ?? '';
            _selectedBarangay = userData['barangay'];
            _purokController.text = userData['purok'] ?? '';
            _contactController.text = userData['contactNumber'] ?? '';
            _selectedGender = userData['gender'] ?? 'Male';
            _profileImageUrl = userData['profileImageUrl'];
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
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

  // Save profile data
  Future<void> _saveProfile() async {
    // No need to check form validation if not using Form widget
    setState(() {
      _isSubmitting = true;
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Get user information
        String fullName = _nameController.text.trim();
        String barangay = _selectedBarangay ?? _barangayController.text.trim();
        String purok = _purokController.text.trim();
        String contactNumber = _contactController.text.trim();

        // Get barangayId from the mapping if available
        String? barangayId = _barangayIdMap[barangay];

        // Create a JSON string with user information for the QR code
        Map<String, String> qrData = {
          'fullName': fullName,
          'barangay': barangay,
          'purok': purok,
          'contactNumber': contactNumber,
          'userId': currentUser.uid,
        };

        // Add barangayId to QR data if available
        if (barangayId != null && barangayId.isNotEmpty) {
          qrData['barangayId'] = barangayId;
        }

        // Convert the map to a JSON string
        String qrCodeData = jsonEncode(qrData);

        // First check if document exists
        DocumentSnapshot userDoc =
            await _firestore.collection('resident').doc(currentUser.uid).get();

        // Prepare data for Firestore update
        Map<String, dynamic> userData = {
          'fullName': fullName,
          'barangay': barangay,
          'purok': purok,
          'contactNumber': contactNumber,
          'gender': _selectedGender,
          'profileCompleted': true,
          'qrCodeData': qrCodeData,
          'profileImageUrl': _profileImageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Add barangayId if available
        if (barangayId != null && barangayId.isNotEmpty) {
          userData['barangayId'] = barangayId;
        }

        if (userDoc.exists) {
          // Update existing document
          await _firestore
              .collection('resident')
              .doc(currentUser.uid)
              .update(userData);
          print('Profile updated successfully');
        } else {
          // Create new document if it doesn't exist - add additional fields for new users
          userData['createdAt'] = FieldValue.serverTimestamp();
          userData['userId'] = currentUser.uid;
          userData['email'] = currentUser.email;

          await _firestore
              .collection('resident')
              .doc(currentUser.uid)
              .set(userData);
          print('New profile created successfully');
        }

        // Add OneSignal tagging for barangay
        try {
          // Tag the user with their barangay for targeting notifications
          await OneSignal.login(currentUser.uid);
          await OneSignal.User.addTags({'barangay': barangay});

          // Also add barangayId tag if available
          if (barangayId != null && barangayId.isNotEmpty) {
            await OneSignal.User.addTags({'barangayId': barangayId});
          }

          print('OneSignal: Tagged user with barangay: $barangay');

          // External User ID ensures we can reach this specific user
          await OneSignal.login(currentUser.uid);
          print('OneSignal: Set external user ID: ${currentUser.uid}');
        } catch (e) {
          print('Error setting OneSignal tags: $e');
        }

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile saved successfully')),
          );
        }

        // Add a small delay before navigation to ensure Firestore operation completes
        await Future.delayed(const Duration(milliseconds: 500));

        // Navigate to home screen after successful profile completion
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/dashboardResident',
            (route) => false, // Remove all previous routes
          );
        }
      }
    } catch (e) {
      print('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // Navigate to next page
  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // Validate current page before proceeding
  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0:
        return _nameController.text.isNotEmpty;
      case 1:
        return (_selectedBarangay != null ||
                _barangayController.text.isNotEmpty) &&
            _purokController.text.isNotEmpty;
      case 2:
        return _contactController.text.isNotEmpty;
      case 3:
        return true; // Removed terms check
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    const primaryColor = Color(0xFF0E6B6F); // Match login page color

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: primaryColor),
                    const SizedBox(height: 16),
                    Text(
                      'Setting up your profile...',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Header with back button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      children: [
                        if (_currentPage > 0)
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios),
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            color: Colors.grey[800],
                          )
                        else
                          const SizedBox(width: 48), // Space for alignment
                        Expanded(
                          child: Text(
                            'Complete Your Profile',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48), // Space for alignment
                      ],
                    ),
                  ),

                  // Main content with swipeable pages - takes most of the screen
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (int page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // Page 1: Basic Info
                        _buildBasicInfoPage(primaryColor, screenSize),

                        // Page 2: Address
                        _buildAddressPage(primaryColor, screenSize),

                        // Page 3: Contact
                        _buildContactPage(primaryColor, screenSize),

                        // Page 4: Summary
                        _buildSummaryPage(primaryColor, screenSize),
                      ],
                    ),
                  ),

                  // Page indicator dots at bottom center
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _totalPages,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 5.0),
                          height: 8,
                          width: _currentPage == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? primaryColor
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Continue/Submit button at bottom
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              if (_validateCurrentPage()) {
                                if (_currentPage == _totalPages - 1) {
                                  // On last page, submit form
                                  _saveProfile();
                                } else {
                                  // Otherwise go to next page
                                  _nextPage();
                                }
                              } else {
                                // Show appropriate error message based on page
                                String message =
                                    'Please fill in all required fields';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(message)),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        minimumSize: const Size(double.infinity, 56),
                        elevation: 0,
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _currentPage == _totalPages - 1
                                  ? 'Submit'
                                  : 'Continue',
                              style: const TextStyle(
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

  // Page 1: Basic Info - Centered content with cleaner design
  Widget _buildBasicInfoPage(Color primaryColor, Size screenSize) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: screenSize.width * 0.9,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Page title
              Text(
                'Tell us about yourself',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'We need some basic information to set up your profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),

              // Profile Image
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[100],
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: _isUploading
                        ? CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.transparent,
                            child: CircularProgressIndicator(
                              color: primaryColor,
                              strokeWidth: 2,
                            ),
                          )
                        : CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.transparent,
                            backgroundImage: _profileImageUrl != null
                                ? NetworkImage(_profileImageUrl!)
                                : null,
                            child:
                                _profileImageUrl == null && _imageFile == null
                                    ? Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.grey[400],
                                      )
                                    : _imageFile != null
                                        ? null
                                        : null,
                            foregroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : null,
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Container(
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        padding: const EdgeInsets.all(8.0),
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
              const SizedBox(height: 40),

              // Full Name
              _buildTextField(
                controller: _nameController,
                labelText: 'Full Name',
                hintText: 'Enter your complete name',
                prefixIcon: Icons.person_outline,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: 24),

              // Gender Selection
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Static label above the field
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                    child: Text(
                      'Gender',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          Icons.people_outline,
                          color: primaryColor,
                          size: 24,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        // Ensure no floating behavior
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                      ),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: primaryColor,
                        size: 28,
                      ),
                      items: _genderOptions.map((String gender) {
                        return DropdownMenuItem<String>(
                          value: gender,
                          child: Text(gender),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedGender = newValue;
                          });
                        }
                      },
                      hint: const Text('Select your gender'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Page 2: Address
  Widget _buildAddressPage(Color primaryColor, Size screenSize) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: screenSize.width * 0.9,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Page title
              Text(
                'Where do you live?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please provide your complete address',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),

              // Barangay Dropdown
              _buildBarangayDropdown(primaryColor),
              const SizedBox(height: 24),

              // Purok
              _buildTextField(
                controller: _purokController,
                labelText: 'Purok',
                hintText: 'Enter your purok number/name',
                prefixIcon: Icons.home_outlined,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Page 3: Contact
  Widget _buildContactPage(Color primaryColor, Size screenSize) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: screenSize.width * 0.9,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Page title
              Text(
                'How can we reach you?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please provide your contact information',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),

              // Contact Number
              _buildTextField(
                controller: _contactController,
                labelText: 'Contact Number',
                hintText: 'Enter your mobile number',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Page 4: Summary - With clean card design
  Widget _buildSummaryPage(Color primaryColor, Size screenSize) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: screenSize.width * 0.9,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Page title
              Text(
                'Almost done!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please review your information',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 30),

              // Profile Summary Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: Colors.grey[100]!, width: 1),
                ),
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    // Profile image
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: primaryColor.withOpacity(0.1),
                      backgroundImage: _profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!)
                          : null,
                      child: (_profileImageUrl == null && _imageFile == null)
                          ? Icon(
                              Icons.person,
                              size: 40,
                              color: primaryColor,
                            )
                          : null,
                      foregroundImage:
                          _imageFile != null ? FileImage(_imageFile!) : null,
                    ),
                    const SizedBox(height: 20),

                    // Name
                    _buildSummaryItem(
                      Icons.person_outline,
                      'Name',
                      _nameController.text,
                      primaryColor,
                    ),

                    // Gender
                    _buildSummaryItem(
                      Icons.people_outline,
                      'Gender',
                      _selectedGender,
                      primaryColor,
                    ),

                    // Barangay
                    _buildSummaryItem(
                      Icons.location_city_outlined,
                      'Barangay',
                      _barangayController.text,
                      primaryColor,
                    ),

                    // Purok
                    _buildSummaryItem(
                      Icons.home_outlined,
                      'Purok',
                      _purokController.text,
                      primaryColor,
                    ),

                    // Contact
                    _buildSummaryItem(
                      Icons.phone_outlined,
                      'Contact',
                      _contactController.text,
                      primaryColor,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method for building text fields with consistent styling (no animation)
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    Color primaryColor = const Color(0xFF0E6B6F),
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Static label above the field
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            labelText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: primaryColor,
            ),
          ),
        ),
        // The actual text field without a floating label
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: hintText,
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
              prefixIcon,
              color: primaryColor,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            // Ensure no floating behavior
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

  // Helper for building summary items with consistent styling
  Widget _buildSummaryItem(
      IconData icon, String label, String value, Color primaryColor,
      {bool isLast = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isLast ? Colors.white : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: isLast ? null : Border.all(color: Colors.grey[100]!, width: 1),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value.isEmpty ? 'Not provided' : value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: value.isEmpty ? Colors.grey : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build barangay dropdown field
  Widget _buildBarangayDropdown(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Barangay',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: primaryColor,
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
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            prefixIcon: Icon(Icons.location_city_outlined, color: primaryColor),
            hintText: 'Select your barangay',
            suffixIcon: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_drop_down,
                color: primaryColor,
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

  // Show barangay selector modal
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
}
