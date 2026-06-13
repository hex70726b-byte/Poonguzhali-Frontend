import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_config.dart';

class WorkoutsPage extends StatefulWidget {
  const WorkoutsPage({super.key});

  @override
  State<WorkoutsPage> createState() => _WorkoutsPageState();
}

class _WorkoutsPageState extends State<WorkoutsPage> {
  static const String _baseUrl = AppConfig.baseUrl;

  List<dynamic> _workouts = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  int _stepCount = 0;
  int _stepLimit = 10000;

  @override
  void initState() {
    super.initState();
    _fetchWorkouts();
    _fetchTodaySteps();
  }

  Future<void> _fetchWorkouts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/workouts'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        setState(() {
          _workouts = jsonDecode(res.body);
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

  Future<void> _createWorkout({
    required String name,
    required String type,
    required String target,
    required List<String> scheduledDays,
  }) async {
    setState(() => _isLoading = true);
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/workouts'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'workoutName': name,
              'type': type,
              'target': target,
              'scheduledDays': scheduledDays,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💪 Workout created! Let\'s crush it!'),
            backgroundColor: Colors.lightBlue,
          ),
        );
        _fetchWorkouts();
      } else {
        throw Exception('Failed to create workout');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _updateWorkout({
    required String id,
    required String name,
    required String type,
    required String target,
    required List<String> scheduledDays,
  }) async {
    setState(() => _isLoading = true);
    try {
      final res = await http
          .put(
            Uri.parse('$_baseUrl/api/workouts/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'workoutName': name,
              'type': type,
              'target': target,
              'scheduledDays': scheduledDays,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💪 Workout updated successfully!'),
            backgroundColor: Colors.lightBlue,
          ),
        );
        _fetchWorkouts();
      } else {
        throw Exception('Failed to update workout');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _deleteWorkout(String id) async {
    setState(() => _isLoading = true);
    try {
      final res = await http
          .delete(Uri.parse('$_baseUrl/api/workouts/$id'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Workout deleted!'),
            backgroundColor: Colors.blueGrey,
          ),
        );
        _fetchWorkouts();
      } else {
        throw Exception('Failed to delete workout');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _checkinWorkout(String id, {String? date}) async {
    setState(() => _isLoading = true);
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/workouts/$id/checkin'),
            headers: {'Content-Type': 'application/json'},
            body: date != null ? jsonEncode({'date': date}) : null,
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        if (!mounted) return;
        final resData = jsonDecode(res.body);
        final completedMsg =
            resData['message'] ?? '🔥 Workout completed! Streak increased!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(completedMsg),
            backgroundColor: Colors.lightBlueAccent,
          ),
        );
        _fetchWorkouts();
      } else {
        throw Exception('Failed to checkin workout');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _fetchTodaySteps() async {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/steps/$todayStr'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _stepCount = data['steps'] ?? 0;
          _stepLimit = data['limit'] ?? 10000;
        });
      } else {
        throw Exception('Server error: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching steps: $e');
    }
  }

  Future<void> _updateTodaySteps({int? steps, int? limit}) async {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    try {
      final bodyMap = <String, dynamic>{};
      if (steps != null) bodyMap['steps'] = steps;
      if (limit != null) bodyMap['limit'] = limit;

      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/steps/$todayStr'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(bodyMap),
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _stepCount = data['steps'] ?? 0;
          _stepLimit = data['limit'] ?? 10000;
        });
      } else {
        throw Exception('Failed to update steps');
      }
    } catch (e) {
      debugPrint('Error updating steps: $e');
    }
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      _fetchWorkouts(),
      _fetchTodaySteps(),
    ]);
  }

  void _openStepLimitDialog() {
    final limitCtrl = TextEditingController(text: _stepLimit.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(
          children: [
            Icon(Icons.settings_rounded, color: AppColors.skyBlue),
            SizedBox(width: 10),
            Text('Daily Goal Limit', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set your target daily step limit:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: limitCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. 10000',
                hintStyle: const TextStyle(color: Colors.white30),
                suffixText: 'steps',
                suffixStyle: const TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white24),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.skyBlue, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.skyBlue,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final limit = int.tryParse(limitCtrl.text.trim());
              if (limit != null && limit > 0) {
                _updateTodaySteps(limit: limit);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _openCustomStepsDialog() {
    final stepsCtrl = TextEditingController(text: _stepCount.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(
          children: [
            Icon(Icons.directions_walk_rounded, color: AppColors.skyBlue),
            SizedBox(width: 10),
            Text('Update Today\'s Steps', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your current steps for today:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: stepsCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. 5000',
                hintStyle: const TextStyle(color: Colors.white30),
                suffixText: 'steps',
                suffixStyle: const TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white24),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.skyBlue, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.skyBlue,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final steps = int.tryParse(stepsCtrl.text.trim());
              if (steps != null && steps >= 0) {
                _updateTodaySteps(steps: steps);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _quickStepButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.04),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 14, color: AppColors.skyBlue),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }



  int _getCount(String type) {
    return _workouts.where((w) => w['type'] == type).length;
  }

  void _openFormSheet({dynamic existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(
      text: isEdit ? existing['workoutName']?.toString() : '',
    );
    final targetCtrl = TextEditingController(
      text: isEdit ? existing['target']?.toString() : '',
    );
    String selectedType = isEdit
        ? (existing['type']?.toString() ?? 'time')
        : 'time';
    final List<String> selectedDays = isEdit
        ? List<String>.from(existing['scheduledDays'] ?? [])
        : [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
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
                            isEdit ? '💪 Edit Workout' : '💪 Add Workout',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white60,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Workout Name Input
                      TextField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Workout Name',
                          labelStyle: const TextStyle(color: Colors.white60),
                          prefixIcon: const Icon(
                            Icons.fitness_center_rounded,
                            color: Colors.lightBlueAccent,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white24),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Colors.lightBlueAccent,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Workout Type Select
                      const Text(
                        'WORKOUT TYPE',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: ['time', 'count'].map((t) {
                          final isSelected = selectedType == t;
                          final themeColor = t == 'time'
                              ? Colors.blueAccent
                              : Colors.lightBlueAccent;
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
                                  right: t == 'time' ? 8.0 : 0.0,
                                  left: t == 'count' ? 8.0 : 0.0,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? themeColor.withValues(alpha: 0.15)
                                      : Colors.white.withValues(alpha: 0.04),
                                  border: Border.all(
                                    color: isSelected
                                        ? themeColor
                                        : Colors.white12,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      t == 'time'
                                          ? Icons.timer_rounded
                                          : Icons.replay_circle_filled_rounded,
                                      color: isSelected
                                          ? themeColor
                                          : Colors.white38,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      t == 'time'
                                          ? 'Time Based'
                                          : 'Repetition Count',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white54,
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

                      // Target Input (e.g., target minutes or target counts)
                      TextField(
                        controller: targetCtrl,
                        keyboardType: TextInputType.text,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: selectedType == 'time'
                              ? 'Target Duration (e.g. 30 mins)'
                              : 'Target Count (e.g. 50 reps)',
                          labelStyle: const TextStyle(color: Colors.white60),
                          prefixIcon: Icon(
                            selectedType == 'time'
                                ? Icons.timer_rounded
                                : Icons.plus_one_rounded,
                            color: selectedType == 'time'
                                ? Colors.blueAccent
                                : Colors.lightBlueAccent,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white24),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: selectedType == 'time'
                                  ? Colors.blueAccent
                                  : Colors.lightBlueAccent,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Weekday Picker Select
                      const Text(
                        'SCHEDULED DAYS',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children:
                            [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun',
                            ].map((day) {
                              final isDaySelected = selectedDays.contains(day);
                              return GestureDetector(
                                onTap: () {
                                  setSheetState(() {
                                    if (isDaySelected) {
                                      selectedDays.remove(day);
                                    } else {
                                      selectedDays.add(day);
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isDaySelected
                                        ? Colors.lightBlueAccent.withValues(
                                            alpha: 0.18,
                                          )
                                        : Colors.white.withValues(alpha: 0.04),
                                    border: Border.all(
                                      color: isDaySelected
                                          ? Colors.lightBlueAccent
                                          : Colors.white12,
                                      width: 1.2,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    day.substring(0, 1),
                                    style: TextStyle(
                                      color: isDaySelected
                                          ? Colors.white
                                          : Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // Actions
                      Row(
                        children: [
                          if (isEdit) ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.lightBlueAccent.withValues(
                                    alpha: 0.15,
                                  ),
                                  foregroundColor: Colors.lightBlueAccent,
                                  side: const BorderSide(
                                    color: Colors.lightBlueAccent,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _deleteWorkout(existing['_id']);
                                },
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                ),
                                label: const Text(
                                  'Delete',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedType == 'time'
                                    ? Colors.blueAccent
                                    : Colors.lightBlueAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                final name = nameCtrl.text.trim();
                                final target = targetCtrl.text.trim();

                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '⚠️ Workout Name is required',
                                      ),
                                      backgroundColor: Colors.lightBlueAccent,
                                    ),
                                  );
                                  return;
                                }

                                if (target.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '⚠️ Target value is required',
                                      ),
                                      backgroundColor: Colors.lightBlueAccent,
                                    ),
                                  );
                                  return;
                                }

                                Navigator.pop(ctx);

                                if (isEdit) {
                                  _updateWorkout(
                                    id: existing['_id'],
                                    name: name,
                                    type: selectedType,
                                    target: target,
                                    scheduledDays: selectedDays,
                                  );
                                } else {
                                  _createWorkout(
                                    name: name,
                                    type: selectedType,
                                    target: target,
                                    scheduledDays: selectedDays,
                                  );
                                }
                              },
                              child: Text(
                                isEdit ? 'Update Workout' : 'Save Workout',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
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
    final filteredWorkouts = _workouts.where((w) {
      final name = w['workoutName']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.lightBlueAccent,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '💪 Workouts Tracker',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // Dashboard Counters
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
                      border: Border.all(
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.timer_rounded,
                              color: Colors.blueAccent,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Time workouts',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_getCount('time')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
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
                      border: Border.all(
                        color: Colors.lightBlueAccent.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.replay_circle_filled_rounded,
                              color: Colors.lightBlueAccent,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Count workouts',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_getCount('count')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Step Tracker Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.surfaceCard,
                  AppColors.surfaceSecondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.skyBlue.withValues(alpha: 0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.skyBlue.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.directions_walk_rounded,
                            color: AppColors.skyBlue,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Walk Steps',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Keep moving to reach your goal',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.settings_rounded,
                        color: Colors.white54,
                        size: 20,
                      ),
                      onPressed: _openStepLimitDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_stepCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'Goal: $_stepLimit steps',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            value: _stepLimit > 0 ? (_stepCount / _stepLimit).clamp(0.0, 1.0) : 0.0,
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.skyBlue),
                            strokeWidth: 6,
                          ),
                        ),
                        Text(
                          '${_stepLimit > 0 ? ((_stepCount / _stepLimit) * 100).toInt().clamp(0, 100) : 0}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _quickStepButton(
                        label: '+500 steps',
                        icon: Icons.directions_run_rounded,
                        onPressed: () {
                          _updateTodaySteps(steps: _stepCount + 500);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _quickStepButton(
                        label: '+1,000 steps',
                        icon: Icons.flash_on_rounded,
                        onPressed: () {
                          _updateTodaySteps(steps: _stepCount + 1000);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _quickStepButton(
                        label: 'Custom',
                        icon: Icons.edit_rounded,
                        onPressed: _openCustomStepsDialog,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search input
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
                hintText: 'Search workouts...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.lightBlueAccent,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                fillColor: const Color(0xFF1E1E1E),
                filled: true,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: Colors.lightBlueAccent,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Workouts List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: Colors.lightBlueAccent,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.lightBlueAccent),
                    )
                  : _errorMessage != null
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.5,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.lightBlueAccent,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchWorkouts,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : filteredWorkouts.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.5,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fitness_center_rounded,
                              size: 72,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No workouts logged yet',
                              style: TextStyle(color: Colors.white54, fontSize: 15),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap + to log your first workout!',
                              style: TextStyle(color: Colors.white30, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: filteredWorkouts.length,
                    itemBuilder: (ctx, idx) {
                      final w = filteredWorkouts[idx];
                      final id = w['_id']?.toString() ?? '';
                      final name = w['workoutName'] ?? '—';
                      final type = w['type'] ?? 'time';
                      final target = w['target'] ?? '';
                      final streak = w['streak'] ?? 0;
                      final lastCompleted = w['lastCompletedDate'] ?? '';

                      final isCompletedToday = lastCompleted == todayStr;
                      final isTime = type == 'time';
                      final themeColor = isTime
                          ? Colors.blueAccent
                          : Colors.lightBlueAccent;

                      return GestureDetector(
                        onTap: () => _openFormSheet(existing: w),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCompletedToday
                                  ? Colors.lightBlueAccent.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Quick check-in action
                              InkWell(
                                onTap: () {
                                  _checkinWorkout(id);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isCompletedToday
                                        ? Colors.lightBlueAccent.withValues(
                                            alpha: 0.2,
                                          )
                                        : themeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isCompletedToday
                                          ? Colors.lightBlueAccent
                                          : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    isCompletedToday
                                        ? Icons.check_circle_rounded
                                        : Icons.fitness_center_rounded,
                                    color: isCompletedToday
                                        ? Colors.lightBlueAccent
                                        : themeColor,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Workout Details
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
                                        decoration: isCompletedToday
                                            ? TextDecoration.lineThrough
                                            : null,
                                        decorationColor: Colors.white38,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_rounded,
                                          size: 11,
                                          color: Colors.white38,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          (w['scheduledDays'] as List<dynamic>?)
                                                      ?.isEmpty ??
                                                  true
                                              ? 'Daily'
                                              : (w['scheduledDays']
                                                        as List<dynamic>)
                                                    .join(', '),
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          isTime
                                              ? Icons.timer_rounded
                                              : Icons.plus_one_rounded,
                                          size: 13,
                                          color: Colors.white38,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Target: $target',
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Icon(
                                          Icons.local_fire_department_rounded,
                                          size: 14,
                                          color: Colors.lightBlueAccent,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Streak: $streak days',
                                          style: const TextStyle(
                                            color: Colors.lightBlueAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white24,
                              ),
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
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _openFormSheet(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
