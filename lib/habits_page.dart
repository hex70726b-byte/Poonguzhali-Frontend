import 'dart:convert';
import 'dart:async';
import 'main.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_config.dart';

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  static const String _baseUrl = AppConfig.baseUrl;
  Timer? _countdownTimer;

  List<dynamic> _habits = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchHabits();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchHabits() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/habits')).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        setState(() {
          _habits = jsonDecode(res.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Server error: ${res.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Connection failed: $e';
      });
    }
  }

  Future<void> _triggerHabitReminderFromHabits(String habitId, String name, String customChat) async {
    if (customChat.isEmpty) return;
    final String messageText = "$name $customChat";
    final String currentTime = DateFormat('hh:mm a').format(DateTime.now());

    try {
      await http.post(
        Uri.parse('$_baseUrl/api/ai/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': messageText,
          'isMe': false,
          'time': currentTime,
        }),
      );
    } catch (e) {
      print("Error saving habit reminder from habits page: $e");
    }
  }

  Future<void> _createHabit({
    required String name,
    required String type,
    required String startingTime,
    required String endingTime,
    required String gap,
    required String customChat,
  }) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/habits'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'habitName': name,
          'type': type,
          'startingTime': startingTime,
          'endingTime': endingTime,
          'gap': gap,
          'customChat': customChat,
        }),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚡¡ Habit created successfully!'), backgroundColor: Colors.lightBlue),
        );
        _fetchHabits();
      } else {
        throw Exception('Failed to create habit');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _updateHabit({
    required String id,
    required String name,
    required String type,
    required String startingTime,
    required String endingTime,
    required String gap,
    required String customChat,
  }) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/api/habits/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'habitName': name,
          'type': type,
          'startingTime': startingTime,
          'endingTime': endingTime,
          'gap': gap,
          'customChat': customChat,
        }),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚡¡ Habit updated successfully!'), backgroundColor: Colors.lightBlue),
        );
        _fetchHabits();
      } else {
        throw Exception('Failed to update habit');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _deleteHabit(String id) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/api/habits/$id')).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Habit deleted successfully!'), backgroundColor: Colors.blueGrey),
        );
        _fetchHabits();
      } else {
        throw Exception('Failed to delete habit');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _checkinHabit(String id) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/habits/$id/checkin'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🔥 Check-in registered! Keep up the great work!'), backgroundColor: Colors.lightBlueAccent),
        );
        _fetchHabits();
      } else {
        throw Exception('Failed to checkin');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  int _getCount(String type) {
    return _habits.where((h) => h['type'] == type).length;
  }

  // Helper to format TimeOfDay to 12-hour format string (e.g. 09:00 AM)
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final min = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$min $period';
  }

  // Parse time string e.g. "09:00 AM" back to TimeOfDay
  TimeOfDay _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.split(' ');
      final tParts = parts[0].split(':');
      int hour = int.parse(tParts[0]);
      final min = int.parse(tParts[1]);
      final period = parts[1].toLowerCase();

      if (period == 'pm' && hour < 12) {
        hour += 12;
      } else if (period == 'am' && hour == 12) {
        hour = 0;
      }
      return TimeOfDay(hour: hour, minute: min);
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  int _calculateIntervals(String startStr, String endStr, String gapMinutesStr) {
    try {
      final start = _parseTimeString(startStr);
      final end = _parseTimeString(endStr);
      final gap = int.tryParse(gapMinutesStr) ?? 30;
      if (gap <= 0) return 0;

      final startMinutes = start.hour * 60 + start.minute;
      final endMinutes = end.hour * 60 + end.minute;

      int diff = endMinutes - startMinutes;
      if (diff < 0) {
        diff += 24 * 60; // Cross-midnight
      }
      return (diff / gap).floor();
    } catch (_) {
      return 0;
    }
  }

  void _openFormSheet({dynamic existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: isEdit ? existing['habitName']?.toString() : '');
    final gapCtrl = TextEditingController(text: isEdit ? existing['gap']?.toString() : '30');
    final customChatCtrl = TextEditingController(text: isEdit ? (existing['customChat']?.toString() ?? '') : '');
    String selectedType = isEdit ? (existing['type']?.toString() ?? 'single') : 'single';

    // Starting/ending time state
    TimeOfDay startingTime = isEdit && existing['startingTime'] != null && existing['startingTime'].toString().isNotEmpty
        ? _parseTimeString(existing['startingTime'].toString())
        : const TimeOfDay(hour: 9, minute: 0);

    TimeOfDay endingTime = isEdit && existing['endingTime'] != null && existing['endingTime'].toString().isNotEmpty
        ? _parseTimeString(existing['endingTime'].toString())
        : const TimeOfDay(hour: 21, minute: 0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEdit ? '⚡¡ Edit Habit' : '⚡¡ Add Habit',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white60),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Habit Name Input
                      TextField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Habit Name',
                          labelStyle: const TextStyle(color: Colors.white60),
                          prefixIcon: const Icon(Icons.fitness_center_rounded, color: Colors.lightBlueAccent),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white24),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Habit Type (Single, Multiple)
                      const Text(
                        'HABIT TYPE',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: ['single', 'multiple'].map((t) {
                          final isSelected = selectedType == t;
                          final themeColor = t == 'multiple' ? Colors.lightBlueAccent : Colors.lightBlueAccent;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setSheetState(() {
                                  selectedType = t;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: EdgeInsets.only(
                                  right: t == 'single' ? 8.0 : 0.0,
                                  left: t == 'multiple' ? 8.0 : 0.0,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? themeColor.withValues(alpha: 0.15)
                                      : Colors.white.withValues(alpha: 0.04),
                                  border: Border.all(
                                    color: isSelected ? themeColor : Colors.white12,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      t == 'multiple'
                                          ? Icons.alarm_on_rounded
                                          : Icons.done_all_rounded,
                                      color: isSelected ? themeColor : Colors.white38,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      t == 'multiple' ? 'Multiple times' : 'Single time',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Multiple type fields (starting time, ending time, gap)
                      if (selectedType == 'multiple') ...[
                        Row(
                          children: [
                            // Starting Time
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'STARTING TIME',
                                    style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () async {
                                      final TimeOfDay? picked = await showTimePicker(
                                        context: context,
                                        initialTime: startingTime,
                                      );
                                      if (picked != null) {
                                        setSheetState(() {
                                          startingTime = picked;
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.white24),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatTimeOfDay(startingTime),
                                            style: const TextStyle(color: Colors.white, fontSize: 14),
                                          ),
                                          const Icon(Icons.access_time_rounded, color: Colors.lightBlueAccent, size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Ending Time
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ENDING TIME',
                                    style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () async {
                                      final TimeOfDay? picked = await showTimePicker(
                                        context: context,
                                        initialTime: endingTime,
                                      );
                                      if (picked != null) {
                                        setSheetState(() {
                                          endingTime = picked;
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.white24),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatTimeOfDay(endingTime),
                                            style: const TextStyle(color: Colors.white, fontSize: 14),
                                          ),
                                          const Icon(Icons.access_time_rounded, color: Colors.lightBlueAccent, size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Gap in minutes
                        TextField(
                          controller: gapCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Gap (Minutes)',
                            labelStyle: const TextStyle(color: Colors.white60),
                            prefixIcon: const Icon(Icons.hourglass_empty_rounded, color: Colors.lightBlueAccent),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.white24),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 1.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Reminder Chat Message Field
                        TextField(
                          controller: customChatCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Reminder Chat Message',
                            labelStyle: const TextStyle(color: Colors.white60),
                            hintText: 'e.g. face wash panniya',
                            hintStyle: const TextStyle(color: Colors.white24),
                            prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.lightBlueAccent),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.white24),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 1.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else if (selectedType == 'single') ...[
                        // Single type scheduled time and message fields
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SCHEDULED REMINDER TIME',
                              style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final TimeOfDay? picked = await showTimePicker(
                                  context: context,
                                  initialTime: startingTime,
                                );
                                if (picked != null) {
                                  setSheetState(() {
                                    startingTime = picked;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white24),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatTimeOfDay(startingTime),
                                      style: const TextStyle(color: Colors.white, fontSize: 14),
                                    ),
                                    const Icon(Icons.access_time_rounded, color: Colors.lightBlueAccent, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            TextField(
                              controller: customChatCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Reminder Chat Message',
                                labelStyle: const TextStyle(color: Colors.white60),
                                hintText: 'e.g. take tablet',
                                hintStyle: const TextStyle(color: Colors.white24),
                                prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.lightBlueAccent),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Colors.white24),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 1.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Save/Delete Buttons
                      Row(
                        children: [
                          if (isEdit) ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(color: Colors.redAccent),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _deleteHabit(existing['_id']);
                                },
                                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedType == 'multiple' ? Colors.lightBlueAccent : Colors.lightBlueAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                final name = nameCtrl.text.trim();
                                final gap = gapCtrl.text.trim();

                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('⚠️ Habit Name is required'), backgroundColor: Colors.redAccent),
                                  );
                                  return;
                                }

                                if (selectedType == 'multiple') {
                                  if (gap.isEmpty || int.tryParse(gap) == null || int.parse(gap) <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('⚠️ Enter a valid positive integer gap in minutes'), backgroundColor: Colors.redAccent),
                                    );
                                    return;
                                  }
                                }

                                Navigator.pop(ctx);

                                final startingStr = _formatTimeOfDay(startingTime);
                                final endingStr = selectedType == 'multiple' ? _formatTimeOfDay(endingTime) : '';
                                final customChatStr = customChatCtrl.text.trim();
                                final gapStr = selectedType == 'multiple' ? gap : '';

                                if (isEdit) {
                                  _updateHabit(
                                    id: existing['_id'],
                                    name: name,
                                    type: selectedType,
                                    startingTime: startingStr,
                                    endingTime: endingStr,
                                    gap: gapStr,
                                    customChat: customChatStr,
                                  );
                                } else {
                                  _createHabit(
                                    name: name,
                                    type: selectedType,
                                    startingTime: startingStr,
                                    endingTime: endingStr,
                                    gap: gapStr,
                                    customChat: customChatStr,
                                  );
                                }
                              },
                              child: Text(
                                isEdit ? 'Update Habit' : 'Save Habit',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredHabits = _habits.where((h) {
      final name = h['habitName']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.lightBlueAccent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '⚡¡ Habit Tracker',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          // Dashboard grid widgets
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.done_all_rounded, color: Colors.lightBlueAccent, size: 18),
                            SizedBox(width: 6),
                            Text('Single habits', style: TextStyle(color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_getCount('single')}',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.alarm_on_rounded, color: Colors.lightBlueAccent, size: 18),
                            SizedBox(width: 6),
                            Text('Multiple habits', style: TextStyle(color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_getCount('multiple')}',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search habits...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.lightBlueAccent),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                fillColor: const Color(0xFF1E1E1E),
                filled: true,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Habits List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchHabits,
              color: Colors.lightBlueAccent,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.lightBlueAccent))
                  : _errorMessage != null
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.6,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                                const SizedBox(height: 12),
                                Text(_errorMessage!, style: const TextStyle(color: Colors.white70)),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _fetchHabits,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filteredHabits.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Container(
                                height: MediaQuery.of(context).size.height * 0.6,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.alarm_on_rounded, size: 72, color: Colors.white.withValues(alpha: 0.08)),
                                    const SizedBox(height: 16),
                                    const Text('No habits created yet', style: TextStyle(color: Colors.white54, fontSize: 15)),
                                    const SizedBox(height: 8),
                                    const Text('Tap + to set your first habit!', style: TextStyle(color: Colors.white30, fontSize: 12)),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filteredHabits.length,
                              itemBuilder: (ctx, idx) {
                                final h = filteredHabits[idx];
                                final id = h['_id']?.toString() ?? '';
                                final name = h['habitName'] ?? '—';
                                final type = h['type'] ?? 'single';
                                final starting = h['startingTime'] ?? '';
                                final ending = h['endingTime'] ?? '';
                                final gapStr = h['gap'] ?? '';
                                final isMultiple = type == 'multiple';
                                final themeColor = isMultiple ? Colors.lightBlueAccent : Colors.lightBlueAccent;

                                // Streak and completion tracking
                                final streak = h['streak'] ?? 0;
                                final lastCompleted = h['lastCompletedDate'] ?? '';
                                final multipleCompletions = h['multipleCompletions'] ?? 0;
                                final isSingleCompletedToday = !isMultiple && (lastCompleted == todayStr);

                                // Calculate target check-ins for multiple
                                final targetIntervals = isMultiple ? _calculateIntervals(starting, ending, gapStr) : 1;

                                // Calculate countdown remaining
                                String countdownText = '';
                                final gapMinutes = int.tryParse(gapStr) ?? 30;
                                if (isMultiple && id.isNotEmpty && gapMinutes > 0) {
                                  var lastSent = HabitSchedulerShared.lastSentReminderTime[id];
                                  if (lastSent == null) {
                                    // Start countdown instantly from now!
                                    lastSent = DateTime.now();
                                    HabitSchedulerShared.lastSentReminderTime[id] = lastSent;
                                  }
                                  final nextSent = lastSent.add(Duration(minutes: gapMinutes));
                                  final remaining = nextSent.difference(DateTime.now());
                                  if (remaining.isNegative) {
                                    countdownText = '00:00';
                                  } else {
                                    final min = remaining.inMinutes.toString().padLeft(2, '0');
                                    final sec = (remaining.inSeconds % 60).toString().padLeft(2, '0');
                                    countdownText = '$min:$sec';
                                  }
                                }

                                return GestureDetector(
                                  onTap: () => _openFormSheet(existing: h),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E1E),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSingleCompletedToday
                                            ? Colors.lightBlueAccent.withValues(alpha: 0.1)
                                            : Colors.white.withValues(alpha: 0.05),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Leading Icon with quick action functionality
                                        InkWell(
                                          onTap: () {
                                            if (isMultiple) {
                                              _checkinHabit(id);
                                            } else {
                                              if (!isSingleCompletedToday) {
                                                _checkinHabit(id);
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('🎉 Completed today! Keep it up tomorrow!'), backgroundColor: Colors.lightBlue),
                                                );
                                              }
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(12),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 250),
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: isSingleCompletedToday
                                                  ? Colors.lightBlueAccent.withValues(alpha: 0.2)
                                                  : themeColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isSingleCompletedToday
                                                    ? Colors.lightBlueAccent
                                                    : Colors.transparent,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Icon(
                                              isSingleCompletedToday
                                                  ? Icons.check_circle_rounded
                                                  : (isMultiple ? Icons.add_circle_outline_rounded : Icons.done_all_rounded),
                                              color: isSingleCompletedToday ? Colors.lightBlueAccent : themeColor,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),

                                        // Habit Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  decoration: isSingleCompletedToday
                                                      ? TextDecoration.lineThrough
                                                      : null,
                                                  decorationColor: Colors.white38,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              if (isMultiple) ...[
                                                Row(
                                                  children: [
                                                    const Icon(Icons.access_time_rounded, size: 12, color: Colors.white38),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '$starting - $ending',
                                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    const Icon(Icons.hourglass_empty_rounded, size: 12, color: Colors.white38),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      'Every $gapStr min',
                                                      style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.reply_all_rounded, size: 13, color: Colors.lightBlueAccent),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Replies: $multipleCompletions / $targetIntervals intervals',
                                                      style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.timer_outlined, size: 13, color: Colors.lightBlueAccent),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Next in: $countdownText',
                                                      style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                                if (h['customChat'] != null && h['customChat'].toString().isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Colors.lightBlueAccent),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          'Msg: ${h['customChat']}',
                                                          style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ] else ...[
                                                Row(
                                                  children: [
                                                    const Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.lightBlue),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Streak: $streak days',
                                                      style: const TextStyle(color: Colors.lightBlue, fontSize: 12, fontWeight: FontWeight.bold),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      isSingleCompletedToday ? 'Completed' : 'Pending today',
                                                      style: TextStyle(
                                                        color: isSingleCompletedToday ? Colors.lightBlueAccent : Colors.white38,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (starting.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.access_time_rounded, size: 12, color: Colors.white38),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Scheduled: $starting',
                                                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                                if (h['customChat'] != null && h['customChat'].toString().isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Colors.lightBlueAccent),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          'Msg: ${h['customChat']}',
                                                          style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ]
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.lightBlueAccent,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _openFormSheet(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
