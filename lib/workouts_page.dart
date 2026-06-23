import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_config.dart';
import 'app_drawer.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchWorkouts();
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
            backgroundColor: AppColors.lightBlueAccent,
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
            backgroundColor: AppColors.lightBlueAccent,
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
            backgroundColor: AppColors.lightBlueAccent,
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
                            color: AppColors.lightBlueAccent,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white24),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: AppColors.lightBlueAccent,
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
                              ? AppColors.blueAccent
                              : AppColors.lightBlueAccent;
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
                                ? AppColors.blueAccent
                                : AppColors.lightBlueAccent,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white24),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: selectedType == 'time'
                                  ? AppColors.blueAccent
                                  : AppColors.lightBlueAccent,
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
                                        ? AppColors.lightBlueAccent.withValues(
                                            alpha: 0.18,
                                          )
                                        : Colors.white.withValues(alpha: 0.04),
                                    border: Border.all(
                                      color: isDaySelected
                                          ? AppColors.lightBlueAccent
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
                                  backgroundColor: AppColors.lightBlueAccent.withValues(
                                    alpha: 0.15,
                                  ),
                                  foregroundColor: AppColors.lightBlueAccent,
                                  side: const BorderSide(
                                    color: AppColors.lightBlueAccent,
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
                                    ? AppColors.blueAccent
                                    : AppColors.lightBlueAccent,
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
                                      backgroundColor: AppColors.lightBlueAccent,
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
                                      backgroundColor: AppColors.lightBlueAccent,
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
      drawer: const AppDrawer(activePage: 'workout'),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(
              Icons.menu_rounded,
              color: AppColors.lightBlueAccent,
              size: 24,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
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
                        color: AppColors.blueAccent.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.timer_rounded,
                              color: AppColors.blueAccent,
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
                        color: AppColors.lightBlueAccent.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.replay_circle_filled_rounded,
                              color: AppColors.lightBlueAccent,
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
                  color: AppColors.lightBlueAccent,
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
                    color: AppColors.lightBlueAccent,
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
              onRefresh: _fetchWorkouts,
              color: AppColors.lightBlueAccent,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.lightBlueAccent),
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
                              color: AppColors.lightBlueAccent,
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
                          ? AppColors.blueAccent
                          : AppColors.lightBlueAccent;

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
                                  ? AppColors.lightBlueAccent.withValues(alpha: 0.15)
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
                                        ? AppColors.lightBlueAccent.withValues(
                                            alpha: 0.2,
                                          )
                                        : themeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isCompletedToday
                                          ? AppColors.lightBlueAccent
                                          : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    isCompletedToday
                                        ? Icons.check_circle_rounded
                                        : Icons.fitness_center_rounded,
                                    color: isCompletedToday
                                        ? AppColors.lightBlueAccent
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
                                          color: AppColors.lightBlueAccent,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Streak: $streak days',
                                          style: const TextStyle(
                                            color: AppColors.lightBlueAccent,
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
        backgroundColor: AppColors.lightBlueAccent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _openFormSheet(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
