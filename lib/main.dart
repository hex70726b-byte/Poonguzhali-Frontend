import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'debts_page.dart';
import 'wallets_page.dart';
import 'transactions_page.dart';
import 'goals_page.dart';
import 'habits_page.dart';
import 'workouts_page.dart';
import 'diaries_page.dart';
import 'contacts_page.dart';
import 'reminders_page.dart';
import 'learnings_page.dart';
import 'analysis_page.dart';
import 'profile_page.dart';
import 'notification_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_lock_screen.dart';
import 'passwords_page.dart';
import 'documents_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isChecking = true;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _checkAppLock();
  }

  Future<void> _checkAppLock() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isEnabled = prefs.getBool('app_lock_enabled') ?? false;
    setState(() {
      _isLocked = isEnabled;
      _isChecking = false;
    });
  }

  void _unlockApp() {
    setState(() {
      _isLocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: AppColors.primary,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.scaffoldBackground,
        ),
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: Colors.lightBlueAccent),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: AppColors.primary,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.scaffoldBackground,
      ),
      home: _isLocked
          ? AppLockScreen(onUnlocked: _unlockApp)
          : const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class ChatMessage {
  final String id;
  String text;
  final String time;
  final bool isMe;
  List<String> reactions;
  String? replyTo;
  bool isPinned;
  bool isEdited;
  bool isStarred;

  ChatMessage({
    required this.id,
    required this.text,
    required this.time,
    required this.isMe,
    this.reactions = const [],
    this.replyTo,
    this.isPinned = false,
    this.isEdited = false,
    this.isStarred = false,
  });
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  static const String _baseUrl = AppConfig.baseUrl;
  static const MethodChannel _smsChannel = MethodChannel('sms_reader_channel');
  final TextEditingController msgController = TextEditingController();
  Timer? _habitSchedulerTimer;
  Timer? _habitFetchTimer;
  List<dynamic> _schedulerHabits = [];
  List<dynamic> _schedulerContacts = [];
  List<dynamic> _schedulerReminders = [];
  Map<String, bool> _reminderSentState = {};
  Map<String, DateTime> get _lastSentReminderTime => HabitSchedulerShared.lastSentReminderTime;
  Map<String, bool> get _waitingForReply => HabitSchedulerShared.waitingForReply;
  final List<ChatMessage> messages = [];
  bool _isTyping = false;
  bool _isLoading = true;

  ChatMessage? replyingToMessage;
  ChatMessage? editingMessage;
  ChatMessage? selectedMessage;
  final FocusNode messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.init();
    NotificationService.requestPermissions();
    _loadCachedChat().then((_) {
      fetchChatHistory();
    });
    _startHabitScheduler();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _habitSchedulerTimer?.cancel();
    _habitFetchTimer?.cancel();
    msgController.dispose();
    messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _appLifecycleState = state;
    });
    print("App Lifecycle State changed: $state");

    if (state == AppLifecycleState.resumed) {
      // WhatsApp style: clear system tray when user returns to app
      NotificationService.cancelAll();
      // Catch up on any reminders that occurred while app was in background or closed
      _catchUpMissedReminders();
    } else if (state == AppLifecycleState.paused) {
      // Schedule future reminders to be managed by system when app is closed/minimized
      _scheduleUpcomingNotifications();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  bool _isTimeInIntervalForDateTime(DateTime dt, String startingStr, String endingStr) {
    if (startingStr.isEmpty || endingStr.isEmpty) return true;
    try {
      final checkMinutes = dt.hour * 60 + dt.minute;
      
      final start = _parseTimeString(startingStr);
      final end = _parseTimeString(endingStr);
      
      final startMinutes = start.hour * 60 + start.minute;
      final endMinutes = end.hour * 60 + end.minute;
      
      if (startMinutes <= endMinutes) {
        return checkMinutes >= startMinutes && checkMinutes <= endMinutes;
      } else {
        return checkMinutes >= startMinutes || checkMinutes <= endMinutes;
      }
    } catch (_) {
      return true;
    }
  }

  Future<void> _scheduleUpcomingNotifications() async {
    // Clear any previous schedules
    await NotificationService.cancelAll();

    final now = DateTime.now();
    int notificationId = 1000;

    for (var h in _schedulerHabits) {
      final type = h['type']?.toString() ?? 'single';
      final id = h['_id']?.toString() ?? '';
      final name = h['habitName']?.toString() ?? '';
      final customChat = h['customChat']?.toString() ?? '';
      final starting = h['startingTime']?.toString() ?? '';

      if (id.isEmpty || name.isEmpty) continue;

      if (type == 'single') {
        if (starting.isEmpty || customChat.isEmpty) continue;
        if (_waitingForReply[id] == true) continue;

        // Check if completed today
        final lastCompleted = h['lastCompletedDate']?.toString() ?? '';
        final todayStr = DateFormat('yyyy-MM-dd').format(now);
        final bool completedToday = lastCompleted == todayStr;

        final startTOD = _parseTimeString(starting);

        for (int dayOffset = 0; dayOffset <= 1; dayOffset++) {
          if (dayOffset == 0 && completedToday) continue;

          final targetDay = now.add(Duration(days: dayOffset));
          final startDateTime = DateTime(
            targetDay.year,
            targetDay.month,
            targetDay.day,
            startTOD.hour,
            startTOD.minute,
          );

          if (startDateTime.isAfter(now)) {
            if (startDateTime.difference(now).inHours <= 24) {
              final int uniqueId = notificationId++;
              await NotificationService.scheduleNotification(
                id: uniqueId,
                title: "$name $customChat",
                body: "",
                scheduledTime: startDateTime,
              );
            }
          }
        }
      } else if (type == 'multiple') {
        final gapStr = h['gap']?.toString() ?? '';
        final ending = h['endingTime']?.toString() ?? '';

        if (customChat.isEmpty || gapStr.isEmpty) continue;
        if (_waitingForReply[id] == true) continue;

        final gapMinutes = int.tryParse(gapStr) ?? 30;
        if (gapMinutes <= 0) continue;

        // Base scheduling time starts at the last sent time, or now if no last sent time
        DateTime lastSent = _lastSentReminderTime[id] ?? now;

        // Find next scheduled times starting from lastSent + gapMinutes
        DateTime candidateTime = lastSent.add(Duration(minutes: gapMinutes));

        int scheduledCount = 0;
        while (candidateTime.difference(now).inHours <= 24 && scheduledCount < 12) {
          if (_isTimeInIntervalForDateTime(candidateTime, starting, ending)) {
            final int uniqueId = notificationId++;
            await NotificationService.scheduleNotification(
              id: uniqueId,
              title: "$name $customChat",
              body: "",
              scheduledTime: candidateTime,
            );
            scheduledCount++;
          }
          candidateTime = candidateTime.add(Duration(minutes: gapMinutes));
        }
      }
    }

    // Schedule Custom Reminders
    for (var r in _schedulerReminders) {
      final id = r['_id']?.toString() ?? '';
      final title = r['title']?.toString() ?? '';
      final dtStr = r['dateTime']?.toString() ?? '';
      if (id.isEmpty || title.isEmpty || dtStr.isEmpty) continue;
      try {
        final rTime = DateFormat('yyyy-MM-dd HH:mm').parse(dtStr);
        if (rTime.isAfter(now) && rTime.difference(now).inHours <= 24) {
          final int uniqueId = notificationId++;
          await NotificationService.scheduleNotification(
            id: uniqueId,
            title: "⏰ Reminder: $title",
            body: "Your custom reminder is here!",
            scheduledTime: rTime,
          );
        }
      } catch (_) {}
    }

    // Schedule Birthdays
    for (var c in _schedulerContacts) {
      final name = c['fullName']?.toString() ?? '';
      final bday = c['birthday']?.toString() ?? '';
      if (name.isEmpty || bday.isEmpty || bday == '—') continue;
      try {
        final bDate = DateTime.parse(bday);
        var targetBday = DateTime(now.year, bDate.month, bDate.day, 9, 0); // 9 AM
        if (targetBday.isBefore(now)) {
          targetBday = DateTime(now.year + 1, bDate.month, bDate.day, 9, 0);
        }
        if (targetBday.isAfter(now) && targetBday.difference(now).inHours <= 24) {
          final int uniqueId = notificationId++;
          await NotificationService.scheduleNotification(
            id: uniqueId,
            title: "🎉 Birthday Alert!",
            body: "It's $name's birthday today! Don't forget to wish them!",
            scheduledTime: targetBday,
          );
        }
      } catch (_) {}
    }

    print("Scheduled all upcoming reminders successfully!");
  }

  Future<void> _catchUpMissedReminders() async {
    final now = DateTime.now();
    bool addedAny = false;

    for (var h in _schedulerHabits) {
      final type = h['type']?.toString() ?? 'single';
      final id = h['_id']?.toString() ?? '';
      final name = h['habitName']?.toString() ?? '';
      final customChat = h['customChat']?.toString() ?? '';
      final starting = h['startingTime']?.toString() ?? '';
      final ending = h['endingTime']?.toString() ?? '';

      if (id.isEmpty || name.isEmpty || customChat.isEmpty || starting.isEmpty) continue;

      if (type == 'single') {
        // Check if scheduled time for today has passed
        final startTOD = _parseTimeString(starting);
        final todaySchedule = DateTime(
          now.year,
          now.month,
          now.day,
          startTOD.hour,
          startTOD.minute,
        );

        if (todaySchedule.isBefore(now)) {
          // Check if already completed today
          final lastCompleted = h['lastCompletedDate']?.toString() ?? '';
          final todayStr = DateFormat('yyyy-MM-dd').format(now);
          final bool completedToday = lastCompleted == todayStr;

          // Check if already sent today
          final lastSent = _lastSentReminderTime[id];
          final bool alreadySentToday = lastSent != null &&
              lastSent.year == now.year &&
              lastSent.month == now.month &&
              lastSent.day == now.day;

          if (!completedToday && !alreadySentToday) {
            final String messageText = "$name $customChat";
            final String formattedTime = DateFormat('hh:mm a').format(todaySchedule);

            // Update maps and DB immediately before network call
            _lastSentReminderTime[id] = todaySchedule;
            _updateHabitSchedulerState(id, todaySchedule.toIso8601String(), false);

            try {
              await http.post(
                Uri.parse('$_baseUrl/api/ai/messages'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'text': messageText,
                  'isMe': false,
                  'time': formattedTime,
                }),
              );

              messages.add(ChatMessage(
                id: (DateTime.now().millisecondsSinceEpoch + todaySchedule.millisecondsSinceEpoch).toString() + id,
                text: messageText,
                time: formattedTime,
                isMe: false,
              ));
              addedAny = true;
            } catch (e) {
              print("Error catching up single reminder: $e");
            }
          }
        }
      } else if (type == 'multiple') {
        final gapStr = h['gap']?.toString() ?? '';
        if (gapStr.isEmpty) continue;

        final gapMinutes = int.tryParse(gapStr) ?? 30;
        if (gapMinutes <= 0) continue;

        final lastSent = _lastSentReminderTime[id];
        if (lastSent == null) continue;

        DateTime checkTime = lastSent.add(Duration(minutes: gapMinutes));
        while (checkTime.isBefore(now)) {
          if (_isTimeInIntervalForDateTime(checkTime, starting, ending)) {
            final String messageText = "$name $customChat";
            final String formattedTime = DateFormat('hh:mm a').format(checkTime);

            // Update local maps and database immediately BEFORE the network call
            _lastSentReminderTime[id] = checkTime;
            _updateHabitSchedulerState(id, checkTime.toIso8601String(), false);

            try {
              await http.post(
                Uri.parse('$_baseUrl/api/ai/messages'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'text': messageText,
                  'isMe': false,
                  'time': formattedTime,
                }),
              );

              messages.add(ChatMessage(
                id: (DateTime.now().millisecondsSinceEpoch + checkTime.millisecondsSinceEpoch).toString() + id,
                text: messageText,
                time: formattedTime,
                isMe: false,
              ));
              addedAny = true;
            } catch (e) {
              print("Error catching up reminder: $e");
            }
          }
          checkTime = checkTime.add(Duration(minutes: gapMinutes));
        }
      }
    }

    if (addedAny && mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  void _startHabitScheduler() {
    _fetchSchedulerHabits();
    _fetchSchedulerRemindersAndContacts();
    // Refetch the habits list every 30 seconds so it picks up any new or edited habits
    _habitFetchTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchSchedulerHabits();
      _fetchSchedulerRemindersAndContacts();
    });
    // Check for gaps every 10 seconds
    _habitSchedulerTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkHabitGaps();
    });
  }

  Future<void> _checkAndShowBankSmsPopup() async {
    // Wait for the build context to settle
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    try {
      final isGranted = await _smsChannel.invokeMethod<bool>('checkSmsPermission') ?? false;
      if (!isGranted) {
        _showSmsPermissionPrompt();
      } else {
        _fetchAndShowSmsDialog();
      }
    } catch (e) {
      print("Error checking SMS permission: $e");
    }
  }

  void _showSmsPermissionPrompt() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'SMS Permission',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.lightBlueAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sms_rounded, color: Colors.lightBlueAccent, size: 40),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Bank SMS Reader',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'App open panna odane unga bank SMS read panni debit & credit details show panna SMS permission venum da chellam. Grant pannitiya?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white54,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            final result = await _smsChannel.invokeMethod<String>('requestSmsPermission');
                            if (result == 'granted') {
                              _fetchAndShowSmsDialog();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlueAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Grant Now', style: TextStyle(fontWeight: FontWeight.bold)),
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
  }

  String _extractAmount(String body) {
    final reg = RegExp(r'(?:Rs\.?|INR)\s*([0-9,]+(?:\.[0-9]{2})?)', caseSensitive: false);
    final match = reg.firstMatch(body);
    if (match != null) {
      return match.group(1) ?? '';
    }
    return '';
  }

  Future<void> _fetchAndShowSmsDialog() async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -5)),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.lightBlueAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.lightBlueAccent, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                '🏦 Banking Transaction SMS',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Debit/Credit details fetched from SMS inbox',
                                style: TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10, height: 1),
                  Expanded(
                    child: FutureBuilder<List<dynamic>>(
                      future: _smsChannel.invokeMethod<List<dynamic>>('readBankSms').then((val) => val ?? []),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.lightBlueAccent),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                '⚠️ SMS fetch panna mudiyala da chellam: ${snapshot.error}',
                                style: const TextStyle(color: Colors.white54, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        final smsList = snapshot.data ?? [];
                        if (smsList.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.sms_failed_rounded, size: 64, color: Colors.white10),
                                SizedBox(height: 16),
                                Text(
                                  'No Bank SMS Found',
                                  style: TextStyle(color: Colors.white54, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Unga inbox la transactions SMS ethuvum illada chellam!',
                                  style: TextStyle(color: Colors.white30, fontSize: 11),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: smsList.length,
                          itemBuilder: (context, index) {
                            final sms = Map<String, dynamic>.from(smsList[index]);
                            final sender = sms['sender'] ?? 'Unknown Sender';
                            final body = sms['body'] ?? '';
                            final dateMs = sms['date'] as int? ?? 0;
                            final type = sms['type'] ?? 'general';
                            
                            final date = DateTime.fromMillisecondsSinceEpoch(dateMs);
                            final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
                            
                            final isDebit = type == 'debit';
                            final isCredit = type == 'credit';
                            
                            final amount = _extractAmount(body);
                            
                            final accentColor = isDebit
                                ? Colors.blueAccent
                                : (isCredit ? Colors.lightBlueAccent : Colors.lightBlueAccent);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: accentColor.withValues(alpha: 0.1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: accentColor.withValues(alpha: 0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              isDebit
                                                  ? Icons.arrow_downward_rounded
                                                  : (isCredit ? Icons.arrow_upward_rounded : Icons.sms_outlined),
                                              color: accentColor,
                                              size: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            sender.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (amount.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: accentColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${isDebit ? "-" : (isCredit ? "+" : "")} Rs. $amount',
                                            style: TextStyle(
                                              color: accentColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    body,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        formattedDate,
                                        style: const TextStyle(color: Colors.white30, fontSize: 10),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: body));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('📋 SMS copied to clipboard!'),
                                              backgroundColor: Colors.lightBlue,
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          child: Row(
                                            children: const [
                                              Icon(Icons.copy_rounded, size: 10, color: Colors.white38),
                                              SizedBox(width: 4),
                                              Text('Copy', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
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

  Future<void> _fetchSchedulerHabits() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/habits')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _schedulerHabits = list;
            // Hydrate maps from database state
            for (var h in _schedulerHabits) {
              final id = h['_id']?.toString() ?? '';
              if (id.isNotEmpty) {
                final lastSentStr = h['lastSentReminderTime']?.toString() ?? '';
                if (lastSentStr.isNotEmpty) {
                  final dbTime = DateTime.parse(lastSentStr);
                  final memTime = _lastSentReminderTime[id];
                  if (memTime == null || dbTime.isAfter(memTime)) {
                    _lastSentReminderTime[id] = dbTime;
                    _waitingForReply[id] = h['waitingForReply'] == true;
                  }
                } else {
                  if (!_lastSentReminderTime.containsKey(id)) {
                    _waitingForReply[id] = h['waitingForReply'] == true;
                  }
                }
              }
            }
          });
        }
      }
    } catch (e) {
      print("Error fetching habits for scheduler: $e");
    }
  }

  Future<void> _fetchSchedulerRemindersAndContacts() async {
    try {
      final contactsRes = await http.get(Uri.parse('$_baseUrl/api/contacts')).timeout(const Duration(seconds: 5));
      final remRes = await http.get(Uri.parse('$_baseUrl/api/reminders')).timeout(const Duration(seconds: 5));
      if (contactsRes.statusCode == 200 && remRes.statusCode == 200) {
        if (mounted) {
          setState(() {
            _schedulerContacts = jsonDecode(contactsRes.body);
            _schedulerReminders = jsonDecode(remRes.body);
          });
        }
      }
    } catch (e) {
      print("Error fetching reminders/contacts for scheduler: $e");
    }
  }

  Future<void> _updateHabitSchedulerState(String habitId, String lastSentStr, bool waiting) async {
    try {
      await http.put(
        Uri.parse('$_baseUrl/api/habits/$habitId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lastSentReminderTime': lastSentStr,
          'waitingForReply': waiting,
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      print("Error updating habit scheduler state: $e");
    }
  }

  String _lastBackupDate = "";

  Future<void> _checkDailyBackupSchedule() async {
    try {
      final file = File("/storage/emulated/0/DailyBackup/backup_settings.json");
      if (!await file.exists()) return;

      final content = await file.readAsString();
      final data = jsonDecode(content);
      final enabled = data['enabled'] ?? false;
      if (!enabled) return;

      final backupTimeStr = data['backupTime'] ?? "10:00 PM";
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      if (_lastBackupDate == todayStr) return;

      final parts = backupTimeStr.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) return;
      final tParts = parts[0].split(':');
      if (tParts.length < 2) return;
      int hour = int.parse(tParts[0]);
      final min = int.parse(tParts[1]);
      final period = parts[1].toLowerCase();

      if (period == 'pm' && hour < 12) {
        hour += 12;
      } else if (period == 'am' && hour == 12) {
        hour = 0;
      }

      if (now.hour == hour && now.minute == min) {
        _lastBackupDate = todayStr;
        await _runScheduledBackup();
      }
    } catch (_) {}
  }

  Future<void> _runScheduledBackup() async {
    int movedCount = 0;
    try {
      final sourceFolders = [
        "/storage/emulated/0/DCIM/Camera",
        "/storage/emulated/0/Pictures",
        "/storage/emulated/0/Download",
        "/storage/emulated/0/Music",
        "/storage/emulated/0/Movies",
        "/storage/emulated/0/WhatsApp/Media",
        "/storage/emulated/0/Recordings",
        "/storage/emulated/0/CallRecordings",
        "/storage/emulated/0/Sounds",
        "/storage/emulated/0/MIUI/sound_recorder",
        "/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media"
      ];

      final backupDir = "/storage/emulated/0/DailyBackup";
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayBackup = Directory("$backupDir/$todayStr");

      if (!todayBackup.existsSync()) {
        todayBackup.createSync(recursive: true);
      }

      final todayDate = DateTime.now();

      final extensions = {
        "Images": [".jpg", ".jpeg", ".png", ".gif"],
        "Videos": [".mp4", ".mkv", ".avi"],
        "Audio": [".mp3", ".wav", ".aac", ".awb"],
        "Documents": [".pdf", ".docx", ".txt"]
      };

      for (var source in sourceFolders) {
        final dir = Directory(source);
        if (!dir.existsSync()) continue;

        List<FileSystemEntity> entities = [];
        try {
          entities = dir.listSync(recursive: true, followLinks: false);
        } catch (e) {
          print("Error listing source folder $source: $e");
          continue;
        }

        for (var entity in entities) {
          if (entity is File) {
            try {
              final modifiedDate = entity.lastModifiedSync();
              if (modifiedDate.year == todayDate.year &&
                  modifiedDate.month == todayDate.month &&
                  modifiedDate.day == todayDate.day) {
                
                final dotIndex = entity.path.lastIndexOf('.');
                if (dotIndex == -1) continue;
                final ext = entity.path.substring(dotIndex).toLowerCase();
                String? category;
                extensions.forEach((key, exts) {
                  if (exts.contains(ext)) {
                    category = key;
                  }
                });

                if (category != null) {
                  final catFolder = Directory("${todayBackup.path}/$category");
                  if (!catFolder.existsSync()) {
                    catFolder.createSync(recursive: true);
                  }

                  final fileName = entity.path.split(RegExp(r'[/\\]')).last;
                  final destPath = "${catFolder.path}/$fileName";

                  // Try to move (rename) the file first
                  try {
                    entity.renameSync(destPath);
                  } catch (e) {
                    // Fallback to copy and delete if rename fails (e.g. cross-partition boundary)
                    entity.copySync(destPath);
                    entity.deleteSync();
                  }

                  movedCount++;
                }
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    // TTS & Vibration notifications on completion
    try {
      await _smsChannel.invokeMethod('speak', {'text': 'Backup Completed'});
      await _smsChannel.invokeMethod('vibrate');
    } catch (e) {
      print("TTS/Vibrate failed: $e");
    }

    // Post backup notification message to chat db
    final String messageText = "[Daily Backup] 📁 Daily Auto Backup Completed! Moved $movedCount files modified today.";
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
    } catch (_) {}

    if (mounted) {
      setState(() {
        messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: messageText,
          time: currentTime,
          isMe: false,
        ));
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("📁 Daily Auto Backup Completed! Moved $movedCount files."),
          backgroundColor: const Color(0xFF00B0FF),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _checkHabitGaps() {
    _checkDailyBackupSchedule();
    
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // Check Custom Reminders
    for (var r in _schedulerReminders) {
      final id = r['_id']?.toString() ?? '';
      final title = r['title']?.toString() ?? '';
      final dtStr = r['dateTime']?.toString() ?? '';
      if (id.isEmpty || title.isEmpty || dtStr.isEmpty) continue;
      try {
        final rTime = DateFormat('yyyy-MM-dd HH:mm').parse(dtStr);
        if (now.isAfter(rTime) && _reminderSentState[id] != true) {
          _reminderSentState[id] = true;
          _triggerSystemMessage("⏰ Reminder", title);
        }
      } catch (_) {}
    }

    // Check Birthdays
    for (var c in _schedulerContacts) {
      final id = c['_id']?.toString() ?? '';
      final name = c['fullName']?.toString() ?? '';
      final bday = c['birthday']?.toString() ?? '';
      if (id.isEmpty || name.isEmpty || bday.isEmpty || bday == '—') continue;
      try {
        final bDate = DateTime.parse(bday);
        if (now.month == bDate.month && now.day == bDate.day) {
          // Trigger at 9 AM
          final stateKey = 'bday_${id}_$todayStr';
          if (now.hour >= 9 && _reminderSentState[stateKey] != true) {
            _reminderSentState[stateKey] = true;
            _triggerSystemMessage("🎉 Birthday Alert!", "It's $name's birthday today! Don't forget to wish them!");
          }
        }
      } catch (_) {}
    }

    if (_schedulerHabits.isEmpty) return;

    for (var h in _schedulerHabits) {
      final type = h['type']?.toString() ?? 'single';
      final id = h['_id']?.toString() ?? '';
      final name = h['habitName']?.toString() ?? '';
      final customChat = h['customChat']?.toString() ?? '';
      final starting = h['startingTime']?.toString() ?? '';

      if (id.isEmpty || name.isEmpty) continue;

      if (type == 'single') {
        // Only trigger if startingTime and customChat are configured
        if (starting.isEmpty || customChat.isEmpty) continue;

        // Check if current time is at or after scheduled startingTime
        final start = _parseTimeString(starting);
        final startMinutes = start.hour * 60 + start.minute;
        final nowMinutes = now.hour * 60 + now.minute;
        if (nowMinutes < startMinutes) continue;

        // Check if already sent today
        final lastSent = _lastSentReminderTime[id];
        final bool alreadySentToday = lastSent != null &&
            lastSent.year == now.year &&
            lastSent.month == now.month &&
            lastSent.day == now.day;
        if (alreadySentToday) continue;

        // Check if already completed today
        final lastCompleted = h['lastCompletedDate']?.toString() ?? '';
        final todayStr = DateFormat('yyyy-MM-dd').format(now);
        final bool completedToday = lastCompleted == todayStr;
        if (completedToday) continue;

        // Trigger single habit reminder!
        _triggerHabitReminder(id, name, customChat);
      } else if (type == 'multiple') {
        final gapStr = h['gap']?.toString() ?? '';
        final ending = h['endingTime']?.toString() ?? '';

        print("⚡¡ [SCHEDULER] Multiple Habit ID: $id, Name: $name, GapStr: '$gapStr', Ending: '$ending'");

        if (customChat.isEmpty || gapStr.isEmpty) {
          print("⚡¡ [SCHEDULER] Skip: customChat or gapStr is empty");
          continue;
        }

        final gapMinutes = int.tryParse(gapStr) ?? 30;
        if (gapMinutes <= 0) {
          print("⚡¡ [SCHEDULER] Skip: gapMinutes <= 0");
          continue;
        }

        if (!_isTimeInInterval(starting, ending)) {
          print("⚡¡ [SCHEDULER] Skip: not in active time interval ($starting to $ending)");
          continue;
        }

        if (!_lastSentReminderTime.containsKey(id)) {
          print("⚡¡ [SCHEDULER] Triggering initial reminder (no last sent time)");
          _triggerHabitReminder(id, name, customChat);
          continue;
        }

        final lastSent = _lastSentReminderTime[id]!;
        final diffSeconds = now.difference(lastSent).inSeconds;

        print("⚡¡ [SCHEDULER] Last Sent: $lastSent, Diff Seconds: $diffSeconds, Required Seconds: ${gapMinutes * 60}");

        if (diffSeconds >= gapMinutes * 60) {
          print("⚡¡ [SCHEDULER] Interval met! Triggering reminder.");
          _triggerHabitReminder(id, name, customChat);
        }
      }
    }
  }

  Future<void> _triggerHabitReminder(String habitId, String name, String customChat) async {
    final nowTime = DateTime.now();
    _lastSentReminderTime[habitId] = nowTime;
    _waitingForReply[habitId] = false;
    _updateHabitSchedulerState(habitId, nowTime.toIso8601String(), false);
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
      print("Error saving habit reminder: $e");
    }

    if (_appLifecycleState != AppLifecycleState.resumed || !(ModalRoute.of(context)?.isCurrent ?? true)) {
      NotificationService.showNotification(
        id: habitId.hashCode,
        title: "$name $customChat",
        body: "",
      );
    }

    if (mounted) {
      setState(() {
        messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: messageText,
          time: currentTime,
          isMe: false,
        ));
      });
      _scrollToBottom();
    }
  }

  Future<void> _triggerSystemMessage(String title, String body) async {
    final String messageText = "$title - $body";
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
    } catch (e) {}

    if (_appLifecycleState != AppLifecycleState.resumed || !(ModalRoute.of(context)?.isCurrent ?? true)) {
      NotificationService.showNotification(
        id: title.hashCode,
        title: title,
        body: body,
      );
    }

    if (mounted) {
      setState(() {
        messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: messageText,
          time: currentTime,
          isMe: false,
        ));
      });
      _scrollToBottom();
    }
  }

  Future<void> _checkinHabit(String id) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/habits/$id/checkin'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 6));
    } catch (e) {
      print("Error checkin habit: $e");
    }
  }

  Future<void> _saveChatMessage(String text, bool isMe, String time) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/ai/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'isMe': isMe,
          'time': time,
        }),
      );
    } catch (_) {}
  }

  bool _isTimeInInterval(String startingStr, String endingStr) {
    if (startingStr.isEmpty || endingStr.isEmpty) return true;
    try {
      final now = DateTime.now();
      final nowMinutes = now.hour * 60 + now.minute;
      
      final start = _parseTimeString(startingStr);
      final end = _parseTimeString(endingStr);
      
      final startMinutes = start.hour * 60 + start.minute;
      final endMinutes = end.hour * 60 + end.minute;
      
      if (startMinutes <= endMinutes) {
        return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
      } else {
        return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
      }
    } catch (_) {
      return true;
    }
  }


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

  Future<void> _toggleReaction(ChatMessage msg, String emoji) async {
    try {
      setState(() {
        if (msg.reactions.contains(emoji)) {
          msg.reactions.remove(emoji);
        } else {
          msg.reactions.add(emoji);
        }
      });

      if (msg.id.isNotEmpty) {
        await http.post(
          Uri.parse('$_baseUrl/api/ai/messages/${msg.id}/react'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'emoji': emoji}),
        );
      }
    } catch (_) {}
  }

  Future<void> _togglePin(ChatMessage msg) async {
    try {
      final newStatus = !msg.isPinned;
      setState(() {
        msg.isPinned = newStatus;
      });

      if (msg.id.isNotEmpty) {
        await http.post(
          Uri.parse('$_baseUrl/api/ai/messages/${msg.id}/pin'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'isPinned': newStatus}),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? "Message pinned to top! 📌" : "Message unpinned!"),
          backgroundColor: const Color(0xFF00B0FF),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (_) {}
  }

  Future<void> _toggleStar(ChatMessage msg) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final newStatus = !msg.isStarred;
      setState(() {
        msg.isStarred = newStatus;
      });

      // Local persistence fallback in SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final starredIds = prefs.getStringList('starred_message_ids') ?? [];
        if (newStatus) {
          if (!starredIds.contains(msg.id)) {
            starredIds.add(msg.id);
          }
        } else {
          starredIds.remove(msg.id);
        }
        await prefs.setStringList('starred_message_ids', starredIds);
      } catch (_) {}

      if (msg.id.isNotEmpty) {
        await http.post(
          Uri.parse('$_baseUrl/api/ai/messages/${msg.id}/star'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'isStarred': newStatus}),
        );
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(newStatus ? "Message starred! ⭐" : "Message unstarred!"),
          backgroundColor: const Color(0xFF00B0FF),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (_) {}
  }

  Future<void> _deleteMessage(ChatMessage msg, {required bool forEveryone}) async {
    try {
      setState(() {
        messages.remove(msg);
      });

      if (forEveryone && msg.id.isNotEmpty) {
        await http.delete(Uri.parse('$_baseUrl/api/ai/messages/${msg.id}'));
      }
    } catch (_) {}
  }



  void _showDeleteConfirmDialog(ChatMessage msg) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F2C34),
          title: const Text("Delete message?", style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteMessage(msg, forEveryone: false);
              },
              child: const Text("Delete for me", style: TextStyle(color: Color(0xFF00B0FF))),
            ),
            if (msg.isMe)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteMessage(msg, forEveryone: true);
                },
                child: const Text("Delete for everyone", style: TextStyle(color: Color(0xFF00B0FF), fontWeight: FontWeight.bold)),
              ),
          ],
        );
      },
    );
  }

  Future<void> _loadCachedChat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('cached_chat_history');
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final List<dynamic> data = jsonDecode(cachedStr);
        
        List<String> starredIds = [];
        try {
          starredIds = prefs.getStringList('starred_message_ids') ?? [];
        } catch (_) {}

        if (mounted) {
          setState(() {
            messages.clear();
            for (var item in data) {
              final msgId = item['id']?.toString() ?? '';
              final isStarredLocal = starredIds.contains(msgId) || item['isStarred'] == true;

              messages.add(ChatMessage(
                id: msgId,
                text: item['text'] ?? '',
                time: item['time'] ?? '',
                isMe: item['isMe'] == true,
                reactions: List<String>.from(item['reactions'] ?? []),
                replyTo: item['replyTo']?.toString(),
                isPinned: item['isPinned'] == true,
                isEdited: item['isEdited'] == true,
                isStarred: isStarredLocal,
              ));
            }
            _isLoading = false;
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      print("Error loading cached chat: $e");
    }
  }

  Future<void> _saveChatToCache(List<ChatMessage> msgs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> data = msgs.map((m) => {
        'id': m.id,
        'text': m.text,
        'time': m.time,
        'isMe': m.isMe,
        'reactions': m.reactions,
        'replyTo': m.replyTo,
        'isPinned': m.isPinned,
        'isEdited': m.isEdited,
        'isStarred': m.isStarred,
      }).toList();
      await prefs.setString('cached_chat_history', jsonEncode(data));
    } catch (e) {
      print("Error saving chat to cache: $e");
    }
  }

  Future<void> fetchChatHistory() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/ai/messages'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        List<String> starredIds = [];
        try {
          final prefs = await SharedPreferences.getInstance();
          starredIds = prefs.getStringList('starred_message_ids') ?? [];
        } catch (_) {}

        setState(() {
          messages.clear();
          for (var item in data) {
            final msgId = item['_id']?.toString() ?? '';
            final backendStarred = item['isStarred'] ?? false;
            final isStarredLocal = starredIds.contains(msgId) || backendStarred;

            messages.add(ChatMessage(
              id: msgId,
              text: item['text'] ?? '',
              time: item['time'] ?? '',
              isMe: item['isMe'] ?? false,
              reactions: List<String>.from(item['reactions'] ?? []),
              replyTo: item['replyTo']?.toString(),
              isPinned: item['isPinned'] ?? false,
              isEdited: item['isEdited'] ?? false,
              isStarred: isStarredLocal,
            ));
          }
          _isLoading = false;
        });
        _scrollToBottom();
        _saveChatToCache(messages);
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching chat: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> clearChatHistory() async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/api/ai/messages'));
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          messages.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Chat cleared successfully! ✨", style: TextStyle(color: Colors.white)),
            backgroundColor: Color(0xFF00B0FF),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error clearing chat. Please try again! 🥺", style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    } catch (e) {
      print("Error clearing chat: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Net connection check pannu da chellam! 🥺💔", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.blueAccent,
        ),
      );
    }
  }

  void _showClearChatConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F2C34),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Clear this chat?",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Are you sure you want to clear all messages in this chat?",
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                clearChatHistory();
              },
              child: const Text(
                "Clear chat",
                style: TextStyle(
                  color: Color(0xFF00B0FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> changeText() async {
    final String userMsg = msgController.text.trim();
    if (userMsg.isEmpty) return;

    final String currentTime = DateFormat('hh:mm a').format(DateTime.now());

    if (editingMessage != null) {
      final String editId = editingMessage!.id;
      setState(() {
        editingMessage!.text = userMsg;
        editingMessage!.isEdited = true;
        editingMessage = null;
      });
      msgController.clear();
      messageFocusNode.unfocus();

      try {
        await http.put(
          Uri.parse('$_baseUrl/api/ai/messages/$editId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'text': userMsg}),
        );
      } catch (_) {}
      return;
    }

    final String? replyText = replyingToMessage?.text;
    setState(() {
      replyingToMessage = null;
    });

    final String tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final localMsg = ChatMessage(
      id: tempId,
      text: userMsg,
      time: currentTime,
      isMe: true,
      replyTo: replyText,
    );

    setState(() {
      messages.add(localMsg);
      _isTyping = true;
    });

    msgController.clear();
    messageFocusNode.unfocus();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/ai/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': userMsg,
          'time': currentTime,
          'replyTo': replyText,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String reply = data['reply'] ?? "Hmm... Chellam, enna solra nu puriyala da! ❤️";
        setState(() {
          messages.add(
            ChatMessage(
              id: data['_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
              text: reply,
              time: DateFormat('hh:mm a').format(DateTime.now()),
              isMe: false,
            ),
          );
        });
      } else {
        setState(() {
          messages.add(
            ChatMessage(
              id: '',
              text: "Aiyo chellam, server edho error solra madhiri iruku da! 🥺💔",
              time: DateFormat('hh:mm a').format(DateTime.now()),
              isMe: false,
            ),
          );
        });
      }
    } catch (e) {
      setState(() {
        messages.add(
          ChatMessage(
            id: '',
            text: "Net connection check pannu da chella kutty! Illa .env api key check pannu! 🥺💔",
            time: DateFormat('hh:mm a').format(DateTime.now()),
            isMe: false,
          ),
        );
      });
    } finally {
      setState(() {
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  void showAttachmentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(top: 20, left: 10, right: 10),
          height: 380,
          decoration: BoxDecoration(
            color: const Color(0xFF232323),
            borderRadius: BorderRadius.circular(25),
          ),
          margin: const EdgeInsets.only(bottom: 60, left: 10, right: 10),
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 5,
            crossAxisSpacing: 5,
            mainAxisSpacing: 15,
            childAspectRatio: 0.8,
            children: [
              attachmentItem(
                Icons.fitness_center_rounded,
                "Workout",
                Colors.blueAccent,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const WorkoutsPage()),
                  );
                },
              ),
              attachmentItem(
                Icons.analytics_rounded,
                "Analysis",
                Colors.indigo,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AnalysisPage()),
                  );
                },
              ),
              attachmentItem(
                Icons.account_balance_wallet_rounded,
                "Wallets",
                Colors.lightBlue,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const WalletsPage()),
                  );
                },
              ),
              attachmentItem(
                Icons.swap_horizontal_circle_rounded,
                "Transactions",
                Colors.lightBlue,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TransactionsPage()),
                  );
                },
              ),
              attachmentItem(
                Icons.trending_down_rounded,
                "Debt",
                Colors.blueGrey,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DebtsPage()),
                  );
                },
              ),
              attachmentItem(
                Icons.emoji_events_rounded,
                "Goals",
                Colors.lightBlue,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GoalsPage()),
                  );
                },
              ),
              attachmentItem(
                Icons.bolt_rounded,
                "Habits",
                Colors.lightBlueAccent,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HabitsPage()),
                  );
                },
              ),
              attachmentItem(
                Icons.contacts_rounded,
                "Contact",
                Colors.lightBlueAccent,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ContactsPage()),
                  );
                },
              ),
              attachmentItem(
                Icons.book_rounded,
                "Diary",
                Colors.lightBlue,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DiariesPage()),
                  );
                },
              ),
              attachmentItem(
                Icons.alarm_rounded,
                "Reminders",
                Colors.lightBlueAccent,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RemindersPage()),
                  );
                },
              ),
              attachmentItem(
                Icons.local_library_rounded,
                "Learning",
                Colors.lightBlueAccent,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LearningsPage()),
                  );
                },
              ),
              attachmentItem(
                Icons.vpn_key_rounded,
                "Passwords",
                Colors.lightBlue,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PasswordsPage()),
                  );
                },
              ),
              attachmentItem(
                Icons.description_rounded,
                "Documents",
                AppColors.skyBlue,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DocumentsPage()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget attachmentItem(IconData icon, String text, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color,

            child: Icon(icon, color: Colors.white, size: 20),
          ),

          SizedBox(height: 8),

          Text(
            text,
            style: TextStyle(color: Colors.white, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: selectedMessage != null
          ? AppBar(
              backgroundColor: const Color(0xFF1F2C34),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    selectedMessage = null;
                  });
                },
              ),
              title: const Text(
                "1",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    selectedMessage?.isStarred == true ? Icons.star : Icons.star_border,
                    color: selectedMessage?.isStarred == true ? Colors.amber : Colors.white,
                  ),
                  onPressed: () {
                    if (selectedMessage == null) return;
                    final msg = selectedMessage!;
                    setState(() {
                      selectedMessage = null;
                    });
                    _toggleStar(msg);
                  },
                ),
                IconButton(
                  icon: Icon(
                    selectedMessage?.isPinned == true ? Icons.push_pin : Icons.push_pin_outlined,
                    color: selectedMessage?.isPinned == true ? const Color(0xFF00B0FF) : Colors.white,
                  ),
                  onPressed: () {
                    if (selectedMessage == null) return;
                    final msg = selectedMessage!;
                    setState(() {
                      selectedMessage = null;
                    });
                    _togglePin(msg);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white),
                  onPressed: () {
                    if (selectedMessage == null) return;
                    final text = selectedMessage!.text;
                    Clipboard.setData(ClipboardData(text: text));
                    setState(() {
                      selectedMessage = null;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Message copied to clipboard! 📋"),
                        backgroundColor: Color(0xFF00B0FF),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () {
                    if (selectedMessage == null) return;
                    final msg = selectedMessage!;
                    setState(() {
                      selectedMessage = null;
                    });
                    _showDeleteConfirmDialog(msg);
                  },
                ),
              ],
            )
          : AppBar(
              backgroundColor: const Color(0xFF232323),
              title: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfilePage(
                        name: "Poonguzhali",
                        avatar: "assets/images/poonguzhali.png",
                        messages: messages,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    const Hero(
                      tag: 'profile_avatar',
                      child: CircleAvatar(
                        radius: 18,
                        backgroundImage: AssetImage("assets/images/poonguzhali.png"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Poonguzhali",
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ],
                ),
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  color: const Color(0xFF1F2C34),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onSelected: (value) {
                    if (value == 'clear_chat') {
                      _showClearChatConfirmDialog(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Selected: $value",
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: const Color(0xFF00B0FF),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      const PopupMenuItem<String>(
                        value: 'view_contact',
                        child: Text('View contact', style: TextStyle(color: Colors.white)),
                      ),
                      const PopupMenuItem<String>(
                        value: 'media',
                        child: Text('Media, links, and docs', style: TextStyle(color: Colors.white)),
                      ),
                      const PopupMenuItem<String>(
                        value: 'search',
                        child: Text('Search', style: TextStyle(color: Colors.white)),
                      ),
                      const PopupMenuItem<String>(
                        value: 'mute',
                        child: Text('Mute notifications', style: TextStyle(color: Colors.white)),
                      ),
                      const PopupMenuItem<String>(
                        value: 'wallpaper',
                        child: Text('Wallpaper', style: TextStyle(color: Colors.white)),
                      ),
                      const PopupMenuItem<String>(
                        value: 'clear_chat',
                        child: Text('Clear chat', style: TextStyle(color: Colors.white)),
                      ),
                    ];
                  },
                ),
              ],
            ),

      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/whatsapp_background.jpg"),
            fit: BoxFit.cover,
          ),
        ),

        child: Align(
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,

            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (messages.any((m) => m.isPinned == true)) ...[
                  Builder(
                    builder: (context) {
                      final pinnedMsg = messages.firstWhere((m) => m.isPinned == true);
                      return Container(
                        width: double.infinity,
                        color: const Color(0xFF1F2C34),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.push_pin_rounded, color: Color(0xFF00B0FF), size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  final idx = messages.indexOf(pinnedMsg);
                                  if (idx > -1 && _scrollController.hasClients) {
                                    _scrollController.animateTo(
                                      idx * 70.0,
                                      duration: const Duration(milliseconds: 500),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                },
                                child: Text(
                                  "Pinned: ${pinnedMsg.text}",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                              onPressed: () {
                                _togglePin(pinnedMsg);
                              },
                            ),
                          ],
                        ),
                      );
                    }
                  ),
                  const Divider(color: Colors.white12, height: 1),
                ],
                _isLoading
                    ? const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF00B0FF),
                          ),
                        ),
                      )
                    : Expanded(
                        child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(10),
                    itemCount: messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2D2D2D),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                                bottomLeft: Radius.circular(0),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                BouncingDotsIndicator(),
                              ],
                            ),
                          ),
                        );
                      }

                      final msg = messages[index];
                      final isSelected = selectedMessage == msg;
                      return Container(
                        width: double.infinity,
                        color: isSelected ? const Color(0x3300B0FF) : Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Align(
                          alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 6, left: 10, right: 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1F2C34),
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 8,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: ["👍", "❤️", "😂", "😮", "😢", "🙏"].map((emoji) {
                                      final isReacted = msg.reactions.contains(emoji);
                                      return GestureDetector(
                                        onTap: () {
                                          _toggleReaction(msg, emoji);
                                          setState(() {
                                            selectedMessage = null;
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isReacted ? Colors.white24 : Colors.transparent,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            emoji,
                                            style: const TextStyle(fontSize: 22),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                              SwipeToReply(
                                onSwipe: () {
                                  setState(() {
                                    replyingToMessage = msg;
                                  });
                                  messageFocusNode.requestFocus();
                                },
                                child: GestureDetector(
                                  onLongPress: () {
                                    setState(() {
                                      selectedMessage = msg;
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                                    ),
                                    decoration: BoxDecoration(
                                      color: msg.isMe ? const Color(0xFF00B0FF) : const Color(0xFF2D2D2D),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(12),
                                        topRight: const Radius.circular(12),
                                        bottomLeft: msg.isMe ? const Radius.circular(12) : const Radius.circular(0),
                                        bottomRight: msg.isMe ? const Radius.circular(0) : const Radius.circular(12),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (msg.replyTo != null) ...[
                                          Container(
                                            width: double.infinity,
                                            margin: const EdgeInsets.only(bottom: 6),
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.black12,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border(
                                                left: BorderSide(
                                                  color: msg.isMe ? Colors.white70 : const Color(0xFF00B0FF),
                                                  width: 3,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              msg.replyTo!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.white60, fontSize: 11, fontStyle: FontStyle.italic),
                                            ),
                                          ),
                                        ],
                                        Text(
                                          msg.text,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (msg.isPinned == true) ...[
                                              const Icon(Icons.push_pin_rounded, color: Colors.white70, size: 10),
                                              const SizedBox(width: 4),
                                            ],
                                            if (msg.isStarred == true) ...[
                                              const Icon(Icons.star, color: Colors.amber, size: 10),
                                              const SizedBox(width: 4),
                                            ],
                                            if (msg.isEdited == true) ...[
                                              const Text("edited ", style: TextStyle(color: Colors.white60, fontSize: 8, fontStyle: FontStyle.italic)),
                                            ],
                                            Text(
                                              msg.time,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 8,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (msg.reactions.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: msg.reactions.map((emoji) {
                                              return Container(
                                                margin: const EdgeInsets.only(right: 4),
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1F2C34),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(emoji, style: const TextStyle(fontSize: 10)),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                if (replyingToMessage != null) ...[
                  Container(
                    width: double.infinity,
                    color: const Color(0xFF1F2C34),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 35,
                          color: const Color(0xFF00B0FF),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                replyingToMessage!.isMe ? "You" : "Poonguzhali",
                                style: const TextStyle(color: Color(0xFF00B0FF), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                replyingToMessage!.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                          onPressed: () {
                            setState(() {
                              replyingToMessage = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                if (editingMessage != null) ...[
                  Container(
                    width: double.infinity,
                    color: const Color(0xFF1F2C34),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 35,
                          color: Colors.lightBlueAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "Editing message",
                                style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                editingMessage!.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                          onPressed: () {
                            setState(() {
                              editingMessage = null;
                              msgController.clear();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                Container(
                  width: double.infinity,
                  height: 50,
                  margin: EdgeInsets.only(bottom: 5, left: 5, right: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF232323),
                            borderRadius: BorderRadius.circular(50),
                          ),

                          child: Row(
                            children: [
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: Color(0xFF232323),
                                ),
                                color: Colors.white,
                                onPressed: changeText,
                                icon: Icon(Icons.emoji_emotions_outlined),
                              ),

                              Expanded(
                                child: TextField(
                                  focusNode: messageFocusNode,
                                  controller: msgController,
                                  style: TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: "Message",
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                  ),
                                ),
                              ),

                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: Color(0xFF232323),
                                ),
                                color: Colors.white,
                                onPressed: () {
                                  showAttachmentSheet(context);
                                },
                                icon: Icon(Icons.attach_file),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(width: 5),

                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Color(0xFF00B0FF),
                          minimumSize: Size(50, 50),
                        ),

                        color: Colors.black,
                        onPressed: changeText,
                        icon: Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BouncingDotsIndicator extends StatefulWidget {
  const BouncingDotsIndicator({super.key});

  @override
  State<BouncingDotsIndicator> createState() => _BouncingDotsIndicatorState();
}

class _BouncingDotsIndicatorState extends State<BouncingDotsIndicator> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    _startAnimations();
  }

  void _startAnimations() async {
    while (mounted) {
      for (int i = 0; i < 3; i++) {
        if (!mounted) return;
        _controllers[i].forward().then((_) {
          if (mounted) {
            _controllers[i].reverse();
          }
        });
        await Future.delayed(const Duration(milliseconds: 150));
      }
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animations[index].value),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white70,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class HabitSchedulerShared {
  static final Map<String, DateTime> lastSentReminderTime = {};
  static final Map<String, bool> waitingForReply = {};
}

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipe;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onSwipe,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragOffset = 0.0;
  static const double _maxDragOffset = 50.0; // Limit drag distance nicely
  static const double _triggerThreshold = 35.0; // Trigger threshold
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _controller.addListener(() {
      setState(() {
        _dragOffset = _controller.value * _dragOffset;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (details.primaryDelta == null) return;
    setState(() {
      _dragOffset = (_dragOffset + details.primaryDelta!).clamp(0.0, _maxDragOffset);
      if (_dragOffset >= _triggerThreshold && !_hasTriggered) {
        _hasTriggered = true;
        HapticFeedback.lightImpact();
        widget.onSwipe();
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    _controller.reverse(from: 1.0).then((_) {
      setState(() {
        _dragOffset = 0.0;
        _hasTriggered = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -35 + (_dragOffset * 0.4),
            top: 0,
            bottom: 10,
            child: Center(
              child: Opacity(
                opacity: (_dragOffset / _maxDragOffset).clamp(0.0, 1.0),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white12,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.reply_rounded,
                    color: Color(0xFF00B0FF),
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_dragOffset, 0.0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

