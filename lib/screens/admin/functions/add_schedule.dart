import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capstone_ecobarangay/screens/others/reusable_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_ecobarangay/services/onesignal_notif.dart';

class AddScheduleScreen extends StatefulWidget {
  final Function? onBackPressed;
  final bool isEditing;
  final String? scheduleId;
  final String? recurringGroupId;

  const AddScheduleScreen({
    Key? key,
    this.onBackPressed,
    this.isEditing = false,
    this.scheduleId,
    this.recurringGroupId,
  }) : super(key: key);

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  // Color scheme to match the admin schedule dashboard
  final Color primaryColor = const Color(0xFF1E1E1E);
  final Color accentColor = const Color(0xFF4CAF50);
  final Color backgroundColor = Colors.grey.shade100;
  final Color cardColor = Colors.white;
  final Color textColor = Colors.grey.shade800;

  bool _isSubmitting = false;
  bool _isLoading = false;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();

  // Schedule type
  bool _isRecurring = false;

  // Form values for single date schedule
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  String _wasteType = 'General';

  // Form values for recurring schedule
  DateTime _recurringStartDate = DateTime.now();
  DateTime _recurringEndDate = DateTime.now().add(const Duration(days: 30));

  // Selected weekdays for recurring schedule (index 0 = Monday, 6 = Sunday)
  List<bool> _selectedWeekdays = List.generate(7, (_) => false);

  // Waste type per weekday
  List<String> _weekdayWasteTypes = List.generate(7, (_) => 'General');

  // Lists for dropdowns
  final List<String> _wasteTypes = [
    'General',
    'Biodegradable',
    'Non-biodegradable',
    'Recyclable'
  ];

  // Weekday names
  final List<String> _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  // Add Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _adminBarangay = '';

  @override
  void initState() {
    super.initState();
    _fetchAdminBarangay();

    if (widget.isEditing && widget.scheduleId != null) {
      _fetchScheduleData();
    }
  }

  Future<void> _fetchAdminBarangay() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot adminDoc = await _firestore
            .collection('barangay_admins')
            .doc(currentUser.uid)
            .get();

        if (adminDoc.exists) {
          Map<String, dynamic> adminData =
              adminDoc.data() as Map<String, dynamic>;
          setState(() {
            _adminBarangay = adminData['barangay'] ?? '';
            // Pre-fill the location field with barangay
            if (_adminBarangay.isNotEmpty && _locationController.text.isEmpty) {
              _locationController.text = 'Barangay $_adminBarangay';
            }
          });
        }
      }
    } catch (e) {
      print('Error fetching admin barangay: ${e.toString()}');
    }
  }

  Future<void> _fetchScheduleData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      DocumentSnapshot scheduleDoc =
          await _firestore.collection('schedule').doc(widget.scheduleId).get();

      if (scheduleDoc.exists) {
        Map<String, dynamic> data = scheduleDoc.data() as Map<String, dynamic>;

        // Check if it's a recurring schedule
        bool isRecurring = data['isRecurring'] == true;

        if (isRecurring) {
          // Handle recurring schedule
          setState(() {
            _isRecurring = true;

            // Set basic info
            _titleController.text = data['title'] ?? '';
            _locationController.text = data['location'] ?? '';

            // Set time values
            Map<String, dynamic> startTimeMap =
                data['startTime'] ?? {'hour': 8, 'minute': 0};
            Map<String, dynamic> endTimeMap =
                data['endTime'] ?? {'hour': 10, 'minute': 0};
            _startTime = TimeOfDay(
              hour: startTimeMap['hour'] ?? 8,
              minute: startTimeMap['minute'] ?? 0,
            );
            _endTime = TimeOfDay(
              hour: endTimeMap['hour'] ?? 10,
              minute: endTimeMap['minute'] ?? 0,
            );

            // Get recurring metadata
            if (data['isRecurringMaster'] == true &&
                data['recurringMetadata'] != null) {
              Map<String, dynamic> metadata = data['recurringMetadata'];

              // Set dates
              Timestamp? startTimestamp = metadata['startDate'];
              Timestamp? endTimestamp = metadata['endDate'];
              if (startTimestamp != null) {
                _recurringStartDate = startTimestamp.toDate();
              }
              if (endTimestamp != null) {
                _recurringEndDate = endTimestamp.toDate();
              }

              // Set weekdays and waste types
              List<dynamic>? weekdays = metadata['weekdays'];
              List<dynamic>? wasteTypes = metadata['wasteTypes'];

              if (weekdays != null && weekdays.length == 7) {
                for (int i = 0; i < 7; i++) {
                  _selectedWeekdays[i] = weekdays[i] == true;
                }
              }

              if (wasteTypes != null && wasteTypes.length == 7) {
                for (int i = 0; i < 7; i++) {
                  _weekdayWasteTypes[i] = wasteTypes[i] ?? 'General';
                }
              }
            } else {
              // If no metadata, set this specific occurrence data
              int weekday = data['weekday'] ?? 0;
              if (weekday >= 0 && weekday < 7) {
                _selectedWeekdays = List.generate(7, (i) => i == weekday);
                _weekdayWasteTypes[weekday] = data['wasteType'] ?? 'General';
              }

              // Get the date from this occurrence
              Timestamp? dateTimestamp = data['date'];
              if (dateTimestamp != null) {
                DateTime occurrenceDate = dateTimestamp.toDate();
                _recurringStartDate = occurrenceDate;
                _recurringEndDate =
                    occurrenceDate.add(const Duration(days: 30));
              }
            }
          });
        } else {
          // Handle single schedule
          setState(() {
            _isRecurring = false;

            // Set basic info
            _titleController.text = data['title'] ?? '';
            _locationController.text = data['location'] ?? '';
            _wasteType = data['wasteType'] ?? 'General';

            // Set date value
            Timestamp? dateTimestamp = data['date'];
            if (dateTimestamp != null) {
              _selectedDate = dateTimestamp.toDate();
            }

            // Set time values
            Map<String, dynamic> startTimeMap =
                data['startTime'] ?? {'hour': 8, 'minute': 0};
            Map<String, dynamic> endTimeMap =
                data['endTime'] ?? {'hour': 10, 'minute': 0};
            _startTime = TimeOfDay(
              hour: startTimeMap['hour'] ?? 8,
              minute: startTimeMap['minute'] ?? 0,
            );
            _endTime = TimeOfDay(
              hour: endTimeMap['hour'] ?? 10,
              minute: endTimeMap['minute'] ?? 0,
            );
          });
        }
      }
    } catch (e) {
      print('Error fetching schedule data: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading schedule: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: accentColor,
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with back button
                  Row(
                    children: [
                      CustomBackButton(
                        onPressed: () {
                          if (widget.onBackPressed != null) {
                            widget.onBackPressed!();
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isEditing
                                ? 'Edit Schedule'
                                : 'Create New Schedule',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.isEditing
                                ? 'Update waste collection schedule details'
                                : 'Schedule waste collection for your barangay',
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

                  // Preview card
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
                              // Schedule Details Section
                              SectionHeader(
                                title: 'Schedule Details',
                                accentColor: accentColor,
                              ),
                              const SizedBox(height: 16),

                              // Title field
                              CustomTextField(
                                controller: _titleController,
                                labelText: 'Schedule Title',
                                hintText:
                                    'Enter the title for this collection schedule',
                                prefixIcon: Icons.title,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a title';
                                  }
                                  return null;
                                },
                                onChanged: (value) => setState(() {}),
                              ),

                              const SizedBox(height: 24),

                              // Schedule Type Selection
                              SectionHeader(
                                title: 'Schedule Type',
                                accentColor: accentColor,
                              ),
                              const SizedBox(height: 16),

                              // Toggle between one-time and recurring schedule
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _isRecurring = false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        decoration: BoxDecoration(
                                          color: !_isRecurring
                                              ? accentColor
                                              : Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Single Date',
                                            style: TextStyle(
                                              color: !_isRecurring
                                                  ? Colors.white
                                                  : Colors.grey.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _isRecurring = true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        decoration: BoxDecoration(
                                          color: _isRecurring
                                              ? accentColor
                                              : Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Recurring',
                                            style: TextStyle(
                                              color: _isRecurring
                                                  ? Colors.white
                                                  : Colors.grey.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // Date & Time Section
                              SectionHeader(
                                title: 'Date & Time',
                                accentColor: accentColor,
                              ),
                              const SizedBox(height: 16),

                              // Different date pickers based on schedule type
                              if (!_isRecurring) ...[
                                _buildDatePicker(),
                              ] else ...[
                                _buildRecurringDateRange(),
                                const SizedBox(height: 16),
                                _buildWeekdaySelection(),
                              ],

                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  Expanded(child: _buildTimePicker(true)),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildTimePicker(false)),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // Waste Type Section - only show for single schedule
                              if (!_isRecurring) ...[
                                SectionHeader(
                                  title: 'Waste Details',
                                  accentColor: accentColor,
                                ),
                                const SizedBox(height: 16),
                                CustomDropdownField(
                                  label: 'Waste Type',
                                  value: _wasteType,
                                  items: _wasteTypes,
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _wasteType = value;
                                      });
                                    }
                                  },
                                  icon: Icons.recycling,
                                  iconColor: _getWasteTypeColor(_wasteType),
                                  showColoredIcon: true,
                                ),
                                const SizedBox(height: 32),
                              ],

                              // Location field
                              CustomTextField(
                                controller: _locationController,
                                labelText: 'Location',
                                hintText:
                                    'Enter the location of the collection',
                                prefixIcon: Icons.location_on,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a location';
                                  }
                                  return null;
                                },
                                onChanged: (value) => setState(() {}),
                              ),

                              const SizedBox(height: 32),

                              // Submit Button
                              Center(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _isSubmitting ? null : _saveSchedule,
                                  icon: _isSubmitting
                                      ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(widget.isEditing
                                          ? Icons.update
                                          : Icons.send),
                                  label: Text(
                                    _isSubmitting
                                        ? 'Saving...'
                                        : widget.isEditing
                                            ? 'Update Schedule'
                                            : 'Save Schedule',
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

  Color _getWasteTypeColor(String wasteType) {
    final Map<String, Color> wasteTypeColors = {
      'General': Colors.blue,
      'Biodegradable': Colors.green,
      'Non-biodegradable': Colors.orange,
      'Recyclable': Colors.teal,
    };
    return wasteTypeColors[wasteType] ?? Colors.blue;
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Collection Date',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(primary: accentColor),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                _selectedDate = picked;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                  style: TextStyle(color: textColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker(bool isStartTime) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isStartTime ? 'Start Time' : 'End Time',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: isStartTime ? _startTime : _endTime,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(primary: accentColor),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                if (isStartTime) {
                  _startTime = picked;
                  // Ensure end time is after start time
                  if (_endTime.hour < _startTime.hour ||
                      (_endTime.hour == _startTime.hour &&
                          _endTime.minute < _startTime.minute)) {
                    _endTime = TimeOfDay(
                      hour: _startTime.hour + 2,
                      minute: _startTime.minute,
                    );
                  }
                } else {
                  _endTime = picked;
                }
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Text(
                  _formatTimeOfDay(isStartTime ? _startTime : _endTime),
                  style: TextStyle(color: textColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatTimeOfDay(TimeOfDay timeOfDay) {
    final hour = timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod;
    final minute = timeOfDay.minute.toString().padLeft(2, '0');
    final period = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // Preview card to match announcement style
  Widget _buildPreviewCard() {
    final bool hasTitle = _titleController.text.isNotEmpty;
    final Color wasteTypeColor = _getWasteTypeColor(_wasteType);

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
              color: primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Waste type icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: wasteTypeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.recycling,
                    color: wasteTypeColor,
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
                          if (!_isRecurring) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: wasteTypeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: wasteTypeColor.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _wasteType,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: wasteTypeColor,
                                ),
                              ),
                            ),
                          ],
                          if (_isRecurring) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.repeat,
                                    size: 10,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Recurring',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasTitle
                            ? _titleController.text
                            : 'Preview: Schedule Title',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: hasTitle ? textColor : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (!_isRecurring) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM dd, yyyy').format(_selectedDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_formatTimeOfDay(_startTime)} - ${_formatTimeOfDay(_endTime)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Show recurring schedule information
                        Row(
                          children: [
                            const Icon(
                              Icons.date_range,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${DateFormat('MMM dd').format(_recurringStartDate)} - ${DateFormat('MMM dd, yyyy').format(_recurringEndDate)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_formatTimeOfDay(_startTime)} - ${_formatTimeOfDay(_endTime)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: List.generate(
                            7,
                            (index) => _selectedWeekdays[index]
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getWasteTypeColor(
                                              _weekdayWasteTypes[index])
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: _getWasteTypeColor(
                                                _weekdayWasteTypes[index])
                                            .withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _weekdayNames[index].substring(0, 3),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: _getWasteTypeColor(
                                                _weekdayWasteTypes[index]),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Container(
                                          width: 1,
                                          height: 10,
                                          color: _getWasteTypeColor(
                                                  _weekdayWasteTypes[index])
                                              .withOpacity(0.3),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _weekdayWasteTypes[index],
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: _getWasteTypeColor(
                                                _weekdayWasteTypes[index]),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
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

  void _saveSchedule() {
    if (_formKey.currentState!.validate()) {
      // Validate weekday selection for recurring schedules
      if (_isRecurring && !_selectedWeekdays.contains(true)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select at least one day of the week'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() {
        _isSubmitting = true;
      });

      if (widget.isEditing) {
        if (widget.recurringGroupId != null && _isRecurring) {
          _updateRecurringSchedules();
        } else {
          _updateSingleSchedule();
        }
      } else {
        if (!_isRecurring) {
          _saveSingleSchedule();
        } else {
          _saveRecurringSchedules();
        }
      }
    }
  }

  void _updateSingleSchedule() {
    if (widget.scheduleId == null) {
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    // Create updated schedule data map
    final scheduleData = {
      'title': _titleController.text,
      'description': 'Collection of ${_wasteType.toLowerCase()} waste',
      'date': Timestamp.fromDate(_selectedDate),
      'startTime': {
        'hour': _startTime.hour,
        'minute': _startTime.minute,
      },
      'endTime': {
        'hour': _endTime.hour,
        'minute': _endTime.minute,
      },
      'wasteType': _wasteType,
      'location': _locationController.text,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Update in Firestore
    FirebaseFirestore.instance
        .collection('schedule')
        .doc(widget.scheduleId)
        .update(scheduleData)
        .then((_) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Schedule updated successfully!'),
            backgroundColor: accentColor,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Use callback if available, otherwise pop
        if (widget.onBackPressed != null) {
          widget.onBackPressed!();
        } else {
          Navigator.pop(context);
        }
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _updateRecurringSchedules() {
    if (widget.recurringGroupId == null) {
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    // First, delete all existing schedules in the group
    FirebaseFirestore.instance
        .collection('schedule')
        .where('recurringGroupId', isEqualTo: widget.recurringGroupId)
        .get()
        .then((snapshot) {
      // Create a batch to delete all documents
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (DocumentSnapshot doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      // Commit the batch deletion
      return batch.commit();
    }).then((_) {
      // After deleting, create new schedules with updated data
      _saveRecurringSchedules(isUpdate: true);
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating schedules: ${error.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _saveSingleSchedule() {
    // Convert selected date and times to a format suitable for Firestore
    final DateTime scheduleDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final DateTime endDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    // Create schedule data map
    final scheduleData = {
      'title': _titleController.text,
      'description': 'Collection of ${_wasteType.toLowerCase()} waste',
      'date': Timestamp.fromDate(_selectedDate),
      'startTime': {
        'hour': _startTime.hour,
        'minute': _startTime.minute,
      },
      'endTime': {
        'hour': _endTime.hour,
        'minute': _endTime.minute,
      },
      'wasteType': _wasteType,
      'location': _locationController.text,
      'barangay': _adminBarangay,
      'adminId': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      'adminName': FirebaseAuth.instance.currentUser?.displayName ?? 'Admin',
      'status': 'Scheduled',
      'createdAt': FieldValue.serverTimestamp(),
      'isRecurring': false,
    };

    // Save to Firestore
    FirebaseFirestore.instance
        .collection('schedule')
        .add(scheduleData)
        .then((docRef) {
      if (mounted) {
        // Format date for notification
        String formattedDate = DateFormat('MMMM d, yyyy').format(_selectedDate);
        String formattedTime =
            '${_formatTimeOfDay(_startTime)} - ${_formatTimeOfDay(_endTime)}';

        // Send notification to users in the barangay
        NotifServices.sendBarangayNotification(
          barangay: _adminBarangay,
          heading: 'New Waste Collection Schedule',
          content:
              '${_wasteType} waste collection scheduled for $formattedDate at $formattedTime. Location: ${_locationController.text}',
        );

        setState(() {
          _isSubmitting = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Schedule created successfully and notification sent!'),
            backgroundColor: accentColor,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Use callback if available, otherwise pop
        if (widget.onBackPressed != null) {
          widget.onBackPressed!();
        } else {
          Navigator.pop(context);
        }
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _saveRecurringSchedules({bool isUpdate = false}) {
    // Get all dates between start and end date
    List<DateTime> allDates =
        _getDatesInRange(_recurringStartDate, _recurringEndDate);

    // Filter dates based on selected weekdays
    Map<int, List<DateTime>> weekdaySchedules = {};

    // Group dates by weekday
    for (int i = 0; i < _selectedWeekdays.length; i++) {
      if (_selectedWeekdays[i]) {
        // Filter dates for this weekday (weekday is 1-based, Monday = 1)
        List<DateTime> datesForWeekday = allDates.where((date) {
          // Convert to 0-based weekday to match our _selectedWeekdays array
          int weekday = date.weekday - 1;
          return weekday == i;
        }).toList();

        weekdaySchedules[i] = datesForWeekday;
      }
    }

    // Check if any dates match
    List<DateTime> allScheduleDates =
        weekdaySchedules.values.expand((dates) => dates).toList();

    if (allScheduleDates.isEmpty) {
      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'No matching dates found in the selected range and days'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Batch create all schedules
    WriteBatch batch = FirebaseFirestore.instance.batch();

    // Create a recurring group ID to link all schedules together
    String recurringGroupId = isUpdate && widget.recurringGroupId != null
        ? widget.recurringGroupId!
        : DateTime.now().millisecondsSinceEpoch.toString();

    // For each selected weekday, create schedules with the corresponding waste type
    int totalSchedules = 0;
    weekdaySchedules.forEach((weekdayIndex, dates) {
      String wasteType = _weekdayWasteTypes[weekdayIndex];

      for (DateTime date in dates) {
        DocumentReference docRef =
            FirebaseFirestore.instance.collection('schedule').doc();

        batch.set(docRef, {
          'title': _titleController.text,
          'description': 'Collection of ${wasteType.toLowerCase()} waste',
          'date': Timestamp.fromDate(date),
          'startTime': {
            'hour': _startTime.hour,
            'minute': _startTime.minute,
          },
          'endTime': {
            'hour': _endTime.hour,
            'minute': _endTime.minute,
          },
          'wasteType': wasteType,
          'location': _locationController.text,
          'barangay': _adminBarangay,
          'adminId': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
          'adminName':
              FirebaseAuth.instance.currentUser?.displayName ?? 'Admin',
          'status': 'Scheduled',
          'createdAt': FieldValue.serverTimestamp(),
          'isRecurring': true,
          'recurringGroupId': recurringGroupId,
          'weekday': weekdayIndex,
          // Store recurring metadata in the first document
          'isRecurringMaster': totalSchedules == 0,
          'recurringMetadata': totalSchedules == 0
              ? {
                  'startDate': Timestamp.fromDate(_recurringStartDate),
                  'endDate': Timestamp.fromDate(_recurringEndDate),
                  'weekdays': _selectedWeekdays,
                  'wasteTypes': _weekdayWasteTypes,
                }
              : null,
        });

        totalSchedules++;
      }
    });

    // Commit the batch
    batch.commit().then((_) {
      if (mounted) {
        // Format string for notification including waste types per day
        List<String> scheduleDetails = [];
        for (int i = 0; i < _selectedWeekdays.length; i++) {
          if (_selectedWeekdays[i]) {
            scheduleDetails
                .add('${_weekdayNames[i]}: ${_weekdayWasteTypes[i]} waste');
          }
        }

        String scheduleText = scheduleDetails.join(', ');

        // Format date range for notification
        String dateRange =
            '${DateFormat('MMM d').format(_recurringStartDate)} - ${DateFormat('MMM d').format(_recurringEndDate)}';

        // Send notification to users in the barangay
        NotifServices.sendBarangayNotification(
          barangay: _adminBarangay,
          heading: isUpdate
              ? 'Updated Waste Collection Schedule'
              : 'New Waste Collection Schedule',
          content:
              'Recurring waste collection from $dateRange at ${_formatTimeOfDay(_startTime)}.\n$scheduleText.\nLocation: ${_locationController.text}',
        );

        setState(() {
          _isSubmitting = false;
        });

        // Show success message with count of schedules created
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUpdate
                ? 'Updated $totalSchedules collection schedules successfully!'
                : 'Created $totalSchedules collection schedules successfully!'),
            backgroundColor: accentColor,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Use callback if available, otherwise pop
        if (widget.onBackPressed != null) {
          widget.onBackPressed!();
        } else {
          Navigator.pop(context);
        }
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  // Helper method to get all dates between two dates
  List<DateTime> _getDatesInRange(DateTime startDate, DateTime endDate) {
    List<DateTime> dates = [];
    DateTime currentDate =
        DateTime(startDate.year, startDate.month, startDate.day);

    while (!currentDate.isAfter(endDate)) {
      dates.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return dates;
  }

  Widget _buildRecurringDateRange() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date Range',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _recurringStartDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(primary: accentColor),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _recurringStartDate = picked;
                      // Ensure end date is after start date
                      if (_recurringEndDate.isBefore(_recurringStartDate)) {
                        _recurringEndDate =
                            _recurringStartDate.add(const Duration(days: 30));
                      }
                    });
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Date',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: Colors.grey.shade600, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMM d, yyyy')
                                .format(_recurringStartDate),
                            style: TextStyle(color: textColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _recurringEndDate,
                    firstDate: _recurringStartDate,
                    lastDate:
                        _recurringStartDate.add(const Duration(days: 365)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(primary: accentColor),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _recurringEndDate = picked;
                    });
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'End Date',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: Colors.grey.shade600, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMM d, yyyy').format(_recurringEndDate),
                            style: TextStyle(color: textColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekdaySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Collection Days',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Select the days of the week for waste collection and specify waste type for each day',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(
            7,
            (index) => GestureDetector(
              onTap: () {
                setState(() {
                  _selectedWeekdays[index] = !_selectedWeekdays[index];
                });
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _selectedWeekdays[index]
                      ? _getWasteTypeColor(_weekdayWasteTypes[index])
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedWeekdays[index]
                        ? _getWasteTypeColor(_weekdayWasteTypes[index])
                        : Colors.grey.shade300,
                  ),
                ),
                child: Center(
                  child: Text(
                    _weekdayNames[index].substring(0, 1),
                    style: TextStyle(
                      color: _selectedWeekdays[index]
                          ? Colors.white
                          : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: List.generate(
            7,
            (index) => _selectedWeekdays[index]
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _getWasteTypeColor(_weekdayWasteTypes[index])
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  _getWasteTypeColor(_weekdayWasteTypes[index])
                                      .withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _weekdayNames[index],
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  _getWasteTypeColor(_weekdayWasteTypes[index]),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _weekdayWasteTypes[index],
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              hintText: 'Select waste type',
                              prefixIcon: Icon(
                                Icons.recycling,
                                color: _getWasteTypeColor(
                                    _weekdayWasteTypes[index]),
                              ),
                            ),
                            items: _wasteTypes.map((type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _weekdayWasteTypes[index] = value;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
