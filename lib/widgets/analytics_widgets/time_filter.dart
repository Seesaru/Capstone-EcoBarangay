import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimeFilter extends StatelessWidget {
  final String selectedTimeFilter;
  final String? selectedMonth;
  final List<String> timeFilters;
  final Color primaryColor;
  final Color textPrimaryColor;
  final Function(String) onTimeFilterChanged;
  final Function(String) onMonthSelected;

  const TimeFilter({
    Key? key,
    required this.selectedTimeFilter,
    this.selectedMonth,
    required this.timeFilters,
    required this.primaryColor,
    required this.textPrimaryColor,
    required this.onTimeFilterChanged,
    required this.onMonthSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month,
              color: primaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Time Period',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textPrimaryColor,
              ),
            ),
            const SizedBox(width: 24),
            DropdownButton<String>(
              value: selectedTimeFilter,
              items: timeFilters.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textPrimaryColor,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) async {
                if (newValue == null) return;
                if (newValue == 'Select Month') {
                  final now = DateTime.now();
                  DateTime? picked = await showDialog<DateTime>(
                    context: context,
                    builder: (context) {
                      int selectedYear = now.year;
                      int selectedMonth = now.month;
                      return StatefulBuilder(
                        builder: (context, setStateDialog) {
                          return AlertDialog(
                            title: const Text('Select Month'),
                            content: SizedBox(
                              height: 120,
                              child: Column(
                                children: [
                                  DropdownButton<int>(
                                    value: selectedMonth,
                                    items: List.generate(12, (i) => i + 1)
                                        .map((month) => DropdownMenuItem(
                                              value: month,
                                              child: Text(DateFormat('MMMM')
                                                  .format(DateTime(0, month))),
                                            ))
                                        .toList(),
                                    onChanged: (int? month) {
                                      if (month != null) {
                                        setStateDialog(() {
                                          selectedMonth = month;
                                        });
                                      }
                                    },
                                  ),
                                  DropdownButton<int>(
                                    value: selectedYear,
                                    items: List.generate(
                                            10, (i) => now.year - 5 + i)
                                        .map((year) => DropdownMenuItem(
                                              value: year,
                                              child: Text(year.toString()),
                                            ))
                                        .toList(),
                                    onChanged: (int? year) {
                                      if (year != null) {
                                        setStateDialog(() {
                                          selectedYear = year;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop(
                                      DateTime(selectedYear, selectedMonth));
                                },
                                child: const Text('OK'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                  if (picked != null) {
                    final monthString = DateFormat('MMM yyyy').format(picked);
                    onMonthSelected(monthString);
                  }
                } else {
                  onTimeFilterChanged(newValue);
                }
              },
              underline: const SizedBox(),
              icon: Icon(Icons.arrow_drop_down, color: primaryColor),
              dropdownColor: Colors.white,
              focusColor: Colors.transparent,
              isDense: true,
            ),
            if (selectedTimeFilter == 'Select Month' &&
                selectedMonth != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  final now = DateTime.now();
                  // Parse the current selected month or use now
                  DateTime initial = now;
                  try {
                    initial = DateFormat('MMM yyyy').parse(selectedMonth!);
                  } catch (_) {}
                  DateTime? picked = await showDialog<DateTime>(
                    context: context,
                    builder: (context) {
                      int selectedYear = initial.year;
                      int selectedMonth = initial.month;
                      return StatefulBuilder(
                        builder: (context, setStateDialog) {
                          return AlertDialog(
                            title: const Text('Select Month'),
                            content: SizedBox(
                              height: 120,
                              child: Column(
                                children: [
                                  DropdownButton<int>(
                                    value: selectedMonth,
                                    items: List.generate(12, (i) => i + 1)
                                        .map((month) => DropdownMenuItem(
                                              value: month,
                                              child: Text(DateFormat('MMMM')
                                                  .format(DateTime(0, month))),
                                            ))
                                        .toList(),
                                    onChanged: (int? month) {
                                      if (month != null) {
                                        setStateDialog(() {
                                          selectedMonth = month;
                                        });
                                      }
                                    },
                                  ),
                                  DropdownButton<int>(
                                    value: selectedYear,
                                    items: List.generate(
                                            10, (i) => now.year - 5 + i)
                                        .map((year) => DropdownMenuItem(
                                              value: year,
                                              child: Text(year.toString()),
                                            ))
                                        .toList(),
                                    onChanged: (int? year) {
                                      if (year != null) {
                                        setStateDialog(() {
                                          selectedYear = year;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop(
                                      DateTime(selectedYear, selectedMonth));
                                },
                                child: const Text('OK'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                  if (picked != null) {
                    final monthString = DateFormat('MMM yyyy').format(picked);
                    onMonthSelected(monthString);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month, color: primaryColor, size: 18),
                      const SizedBox(width: 6),
                      Builder(
                        builder: (context) {
                          try {
                            return Text(
                              DateFormat('MMMM yyyy').format(
                                  DateFormat('MMM yyyy').parse(selectedMonth!)),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: primaryColor,
                              ),
                            );
                          } catch (_) {
                            return Text(
                              selectedMonth!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: primaryColor,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit, color: primaryColor, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
