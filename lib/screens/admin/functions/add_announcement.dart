import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:capstone_ecobarangay/screens/others/reusable_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_ecobarangay/services/onesignal_notif.dart';

class AddAnnouncementScreen extends StatefulWidget {
  final Function? onBackPressed;
  final String
      adminBarangay; // Add this parameter to receive the admin's barangay

  const AddAnnouncementScreen({
    Key? key,
    this.onBackPressed,
    required this.adminBarangay,
  }) : super(key: key);

  @override
  State<AddAnnouncementScreen> createState() => _AddAnnouncementScreenState();
}

class _AddAnnouncementScreenState extends State<AddAnnouncementScreen> {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isSubmitting = false;

  // Color scheme to match the admin dashboard - same as announcement_screen.dart
  final Color primaryColor = const Color(0xFF1E1E1E);
  final Color accentColor = const Color(0xFF4CAF50);
  final Color backgroundColor = Colors.grey.shade100;
  final Color cardColor = Colors.white;
  final Color textColor = Colors.grey.shade800;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String _selectedCategory = 'General';
  String _selectedPurok = 'General';
  String _selectedPriority = 'Medium';
  bool _isUrgent = false;

  // Data for dropdowns - matching the structure in announcement_screen.dart
  final List<String> _categories = [
    'General',
    'Waste Management',
    'Event',
    'Warning',
    'Notice',
    'Other'
  ];

  final List<String> _puroks = [
    'General',
    'Purok 1',
    'Purok 2',
    'Purok 3',
    'Purok 4',
    'Purok 5'
  ];

  final List<String> _priorities = ['Low', 'Medium', 'High'];

  // Maps for icons and colors - matching announcement_screen.dart
  final Map<String, IconData> _categoryIcons = {
    'General': FontAwesomeIcons.bullhorn,
    'Waste Management': FontAwesomeIcons.recycle,
    'Event': FontAwesomeIcons.calendarAlt,
    'Warning': FontAwesomeIcons.exclamationTriangle,
    'Notice': FontAwesomeIcons.infoCircle,
    'Other': FontAwesomeIcons.thList,
  };

  final Map<String, Color> _categoryColors = {
    'General': Colors.blue,
    'Waste Management': Colors.green,
    'Event': Colors.purple,
    'Warning': Colors.orange,
    'Notice': Colors.teal,
    'Other': Colors.grey,
  };

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Set submitting state to show loading indicator
      setState(() {
        _isSubmitting = true;
      });

      try {
        // Get current user
        User? currentUser = _auth.currentUser;
        String authorName = 'Admin';

        // Try to get admin's name from Firestore
        if (currentUser != null) {
          DocumentSnapshot adminDoc = await _firestore
              .collection('barangay_admins')
              .doc(currentUser.uid)
              .get();

          if (adminDoc.exists) {
            Map<String, dynamic> adminData =
                adminDoc.data() as Map<String, dynamic>;
            authorName = adminData['fullName'] ?? 'Admin';
          }
        }

        // Create announcement data
        Map<String, dynamic> announcementData = {
          'title': _titleController.text,
          'content': _contentController.text,
          'date': DateTime.now(),
          'category': _selectedCategory,
          'purok': _selectedPurok,
          'priority': _selectedPriority,
          'urgent': _isUrgent,
          'author': authorName,
          'barangay': widget.adminBarangay,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'categoryIcon': _categoryIcons[_selectedCategory]?.codePoint ??
              FontAwesomeIcons.bullhorn.codePoint,
          'categoryColor':
              (_categoryColors[_selectedCategory] ?? Colors.blue).value,
        };

        // Add to Firestore
        await _firestore.collection('announcements').add(announcementData);

        // Format the content for notification
        String notificationContent = _contentController.text.length > 100
            ? '${_contentController.text.substring(0, 100)}...'
            : _contentController.text;

        try {
          // Try specific barangay targeting first
          await NotifServices.sendBarangayNotification(
            barangay: widget.adminBarangay,
            heading: _isUrgent
                ? "URGENT: ${_titleController.text}"
                : "New announcement posted: ${_titleController.text}",
            content: notificationContent,
          );

          // Also send to all users for now (you can remove this later once barangay targeting works)
          await NotifServices.sendBroadcastNotification(
            heading: "New announcement posted in ${widget.adminBarangay}",
            content: _titleController.text,
          );

          print(
              "Notifications sent for new announcement: ${_titleController.text}");
        } catch (e) {
          print("Error sending notifications: $e");
        }

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Announcement published successfully!'),
              backgroundColor: accentColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        // Go back to the announcement screen
        if (widget.onBackPressed != null) {
          widget.onBackPressed!();
        }
      } catch (e) {
        print("Error publishing announcement: $e");
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error publishing announcement: ${e.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        // Reset submitting state
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red.shade600;
      case 'Medium':
        return Colors.orange.shade600;
      case 'Low':
        return Colors.blue.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button - matching style from announcement_screen.dart
            Row(
              children: [
                CustomBackButton(
                  onPressed: () {
                    if (widget.onBackPressed != null) {
                      widget.onBackPressed!();
                    }
                  },
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create New Announcement',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Publish an announcement to inform your barangay residents',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Preview card - similar to announcement cards in announcement_screen.dart
            _buildPreviewCard(),

            const SizedBox(height: 20),

            // Form content
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Announcement Details Section
                        SectionHeader(
                          title: 'Announcement Details',
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: 16),

                        // Title field
                        CustomTextField(
                          controller: _titleController,
                          labelText: 'Title',
                          hintText: 'Enter announcement title',
                          prefixIcon: Icons.title,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a title';
                            }
                            return null;
                          },
                          onChanged: (value) => setState(() {}),
                        ),
                        const SizedBox(height: 16),

                        // Content field
                        CustomTextField(
                          controller: _contentController,
                          labelText: 'Content',
                          hintText: 'Enter announcement content',
                          prefixIcon: Icons.message,
                          maxLines: 5,
                          alignLabelWithHint: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter content';
                            }
                            return null;
                          },
                          onChanged: (value) => setState(() {}),
                        ),
                        const SizedBox(height: 24),

                        // Targeting & Classification Section
                        SectionHeader(
                          title: 'Targeting & Classification',
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: 16),

                        // Category & Purok in a row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category Dropdown
                            Expanded(
                              child: CustomDropdownField(
                                label: 'Category',
                                value: _selectedCategory,
                                items: _categories,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedCategory = value;
                                    });
                                  }
                                },
                                icon: _categoryIcons[_selectedCategory],
                                iconColor: _categoryColors[_selectedCategory],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Purok Dropdown
                            Expanded(
                              child: CustomDropdownField(
                                label: 'Target Area',
                                value: _selectedPurok,
                                items: _puroks,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedPurok = value;
                                    });
                                  }
                                },
                                icon: FontAwesomeIcons.users,
                                iconColor: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Priority & Urgent flag in a row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Priority Dropdown
                            Expanded(
                              child: CustomDropdownField(
                                label: 'Priority',
                                value: _selectedPriority,
                                items: _priorities,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedPriority = value;
                                    });
                                  }
                                },
                                icon: Icons.priority_high,
                                iconColor: _getPriorityColor(_selectedPriority),
                                showColoredIcon: true,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Urgent Toggle
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Urgency',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: SwitchListTile(
                                      title: Text(
                                        'Mark as Urgent',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: _isUrgent
                                              ? Colors.red
                                              : textColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                      value: _isUrgent,
                                      onChanged: (value) {
                                        setState(() {
                                          _isUrgent = value;
                                        });
                                      },
                                      activeColor: Colors.red,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16),
                                      secondary: Icon(
                                        FontAwesomeIcons.exclamationCircle,
                                        size: 18,
                                        color: _isUrgent
                                            ? Colors.red
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Submit Button - matching style from announcement_screen.dart
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submitForm,
                            icon: _isSubmitting
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send),
                            label: Text(
                              _isSubmitting
                                  ? 'Publishing...'
                                  : 'Publish Announcement',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              minimumSize: const Size(220, 50),
                              disabledBackgroundColor:
                                  accentColor.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    // Create a preview of what the announcement will look like
    final bool hasTitle = _titleController.text.isNotEmpty;
    final bool hasContent = _contentController.text.isNotEmpty;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isUrgent
                  ? Colors.red.withOpacity(0.1)
                  : primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (_categoryColors[_selectedCategory] ?? Colors.blue)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _categoryIcons[_selectedCategory] ??
                        FontAwesomeIcons.bullhorn,
                    color: _categoryColors[_selectedCategory] ?? Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: (_categoryColors[_selectedCategory] ??
                                      Colors.blue)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (_categoryColors[_selectedCategory] ??
                                        Colors.blue)
                                    .withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _selectedPurok,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _categoryColors[_selectedCategory] ??
                                    Colors.blue,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(_selectedPriority),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _selectedPriority,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasTitle
                            ? _titleController.text
                            : 'Preview: Announcement Title',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: hasTitle ? textColor : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM dd, yyyy').format(DateTime.now()),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.person,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Admin (${widget.adminBarangay})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content preview
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              hasContent
                  ? _contentController.text.length > 100
                      ? '${_contentController.text.substring(0, 100)}...'
                      : _contentController.text
                  : 'Preview: Your announcement content will appear here...',
              style: TextStyle(
                fontSize: 14,
                color: hasContent ? textColor : Colors.grey.shade400,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Preview label
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Center(
              child: Text(
                'PREVIEW - Actual appearance may vary',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
