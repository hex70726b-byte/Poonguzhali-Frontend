import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'app_config.dart';
import 'main.dart';

class ProfilePage extends StatefulWidget {
  final String name;
  final String avatar;
  final List<ChatMessage> messages;

  const ProfilePage({
    super.key,
    this.name = "Poonguzhali",
    this.avatar = "assets/images/poonguzhali.png",
    this.messages = const [],
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _channel = MethodChannel('sms_reader_channel');
  bool _backupEnabled = false;
  final TextEditingController _backupTimeController = TextEditingController(text: "10:00 PM");
  Timer? _countdownTimer;

  bool _isAppLockEnabled = false;
  String _appLockType = 'pin';

  @override
  void initState() {
    super.initState();
    _loadBackupSettings();
    _loadAppLockSettings();
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _loadAppLockSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAppLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
      _appLockType = prefs.getString('app_lock_type') ?? 'pin';
    });
  }

  @override
  void dispose() {
    _backupTimeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBackupSettings() async {
    if (kIsWeb) return;
    try {
      final file = File("/storage/emulated/0/DailyBackup/backup_settings.json");
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        setState(() {
          _backupEnabled = data['enabled'] ?? false;
          _backupTimeController.text = data['backupTime'] ?? "10:00 PM";
        });
      }
    } catch (e) {
      print("Error loading backup settings: $e");
    }
  }

  Future<void> _saveBackupSettings() async {
    if (kIsWeb) return;
    try {
      final dir = Directory("/storage/emulated/0/DailyBackup");
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File("/storage/emulated/0/DailyBackup/backup_settings.json");
      final data = {
        'enabled': _backupEnabled,
        'backupTime': _backupTimeController.text.trim(),
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print("Error saving backup settings: $e");
    }
  }
  String _disappearingMessagesStatus = "Off";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: CustomScrollView(
        slivers: [
          // 1. Collapsing Parallax Header with Hero Image
          SliverAppBar(
            expandedHeight: 350.0,
            pinned: true,
            backgroundColor: AppColors.surfaceCard,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1.5),
                      blurRadius: 4.0,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              background: Hero(
                tag: 'profile_avatar',
                child: Image.asset(
                  widget.avatar,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () {
                  showTopSnackBar(context, 
                    const SnackBar(
                      content: Text("Profile options"),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),

          // 2. Profile Details list
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 8),

              // Encryption & Disappearing Messages Section
              _buildSecuritySection(),

              _buildSectionDivider(),

              // Daily Auto Backup Section
              _buildBackupSettingsSection(),

              const SizedBox(height: 50),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionDivider() {
    return Container(
      height: 8,
      color: AppColors.darkDivider,
    );
  }

  // Encryption keys and disappearing message options
  Widget _buildSecuritySection() {
    return Container(
      color: AppColors.surfaceCard,
      child: Column(
        children: [
          // 1. Encryption detail tile
          ListTile(
            onTap: _showEncryptionVerifySheet,
            leading: const Icon(Icons.lock, color: Colors.white70),
            title: const Text(
              "Encryption",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            subtitle: const Text(
              "Messages and calls are end-to-end encrypted. Tap to verify.",
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),

          // 2. Disappearing messages selection tile
          ListTile(
            onTap: _showDisappearingMessagesDialog,
            leading: const Icon(Icons.timer, color: Colors.white70),
            title: const Text(
              "Disappearing messages",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            subtitle: Text(
              _disappearingMessagesStatus == "Off"
                  ? "Off"
                  : "On ($_disappearingMessagesStatus)",
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white30),
          ),

          // 3. App Lock option tile
          ListTile(
            onTap: _manageAppLock,
            leading: const Icon(Icons.security_rounded, color: Colors.white70),
            title: const Text(
              "App Lock",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            subtitle: Text(
              _isAppLockEnabled ? "Enabled (${_appLockType.toUpperCase()})" : "Disabled",
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white30),
          ),

          // 4. Starred Messages option tile
          ListTile(
            onTap: _showStarredMessagesPage,
            leading: const Icon(Icons.star_rounded, color: Colors.amber),
            title: const Text(
              "Starred Messages",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            subtitle: const Text(
              "View your favorite and saved messages",
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white30),
          ),

          // 5. Chatbot Settings tile
          ListTile(
            onTap: _showChatSettingsPage,
            leading: const Icon(Icons.psychology_alt_rounded, color: AppColors.skyBlue),
            title: const Text(
              "Chatbot Persona",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            subtitle: const Text(
              "Customize Poonguzhali's behavior & intelligence",
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white30),
          ),

          // 6. Transaction Categories tile
          ListTile(
            onTap: _showTransactionCategoriesPage,
            leading: const Icon(Icons.category_rounded, color: AppColors.lightBlueAccent),
            title: const Text(
              "Transaction Categories",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            subtitle: const Text(
              "Manage custom categories for income and expenses",
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white30),
          ),
        ],
      ),
    );
  }

  void _manageAppLock() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _AppLockConfigSheet(
            initialEnabled: _isAppLockEnabled,
            initialType: _appLockType,
            onChanged: () {
              _loadAppLockSettings();
            },
          ),
        );
      },
    );
  }

  void _showStarredMessagesPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StarredMessagesPage(messages: widget.messages),
      ),
    );
  }

  void _showChatSettingsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatSettingsPage(),
      ),
    );
  }

  void _showTransactionCategoriesPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TransactionCategoriesPage(),
      ),
    );
  }

  // WhatsApp style modal bottom sheet verifying QR / security codes
  void _showEncryptionVerifySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Icon(
                    Icons.verified_user,
                    color: AppColors.skyBlue,
                    size: 50,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Verify Security Code",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "To verify that messages and calls with Poonguzhali are end-to-end encrypted, scan this QR code or compare these numbers.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  // Mock QR code frame
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SizedBox(
                      width: 150,
                      height: 150,
                      child: CustomPaint(
                        painter: MockQrPainter(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Safety verification code sequence
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: const [
                      Text("48293", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 1.2)),
                      Text("81729", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 1.2)),
                      Text("38920", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 1.2)),
                      Text("92817", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 1.2)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.skyBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      "Dismiss",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Opens dialog for disappearing message settings
  void _showDisappearingMessagesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          backgroundColor: AppColors.surfaceCard,
          title: const Text(
            "Disappearing messages",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          children: [
            _buildDialogRadioOption("24 hours"),
            _buildDialogRadioOption("7 days"),
            _buildDialogRadioOption("90 days"),
            _buildDialogRadioOption("Off"),
          ],
        );
      },
    );
  }

  Future<void> _triggerManualBackup() async {
    if (kIsWeb) {
      showTopSnackBar(context, 
        const SnackBar(
          content: Text("⚠️ Backup is only supported on Android devices."),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }
    try {
      final bool isGranted = await _channel.invokeMethod<bool>('checkStoragePermission') ?? false;
      if (!isGranted) {
        final String res = await _channel.invokeMethod<String>('requestStoragePermission') ?? 'denied';
        if (res != 'granted') {
          showTopSnackBar(context, 
            const SnackBar(
              content: Text("⚠️ Storage permission is required to back up files."),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
      }
      _runBackupProcedure(true);
    } catch (e) {
      print("Error initiating backup: $e");
      showTopSnackBar(context, 
        SnackBar(
          content: Text("⚠️ Error initiating backup: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _selectBackupTime(BuildContext context) async {
    TimeOfDay initialTime = const TimeOfDay(hour: 22, minute: 0); // Default 10:00 PM
    try {
      final text = _backupTimeController.text.trim();
      DateTime dateTime;
      try {
        dateTime = DateFormat('hh:mm a').parse(text);
      } catch (_) {
        dateTime = DateFormat.jm().parse(text);
      }
      initialTime = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
    } catch (e) {
      print("Error parsing initial time: $e");
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.skyBlue,
              onPrimary: Colors.black,
              surface: AppColors.surfaceCard,
              onSurface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.skyBlue,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      final formattedTime = DateFormat('hh:mm a').format(dt);
      setState(() {
        _backupTimeController.text = formattedTime;
      });
    }
  }

  String _calculateGapTime() {
    if (!_backupEnabled) return "";
    try {
      final text = _backupTimeController.text.trim();
      DateTime parsedTime;
      try {
        parsedTime = DateFormat('hh:mm a').parse(text);
      } catch (_) {
        parsedTime = DateFormat.jm().parse(text);
      }
      final now = DateTime.now();
      var target = DateTime(now.year, now.month, now.day, parsedTime.hour, parsedTime.minute);
      if (target.isBefore(now)) {
        target = target.add(const Duration(days: 1));
      }

      final diff = target.difference(now);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      final seconds = diff.inSeconds % 60;

      List<String> parts = [];
      if (hours > 0) {
        parts.add("$hours hr${hours > 1 ? 's' : ''}");
        if (minutes > 0) parts.add("$minutes min${minutes > 1 ? 's' : ''}");
      } else {
        if (minutes > 0) parts.add("$minutes min${minutes > 1 ? 's' : ''}");
        parts.add("$seconds sec${seconds > 1 ? 's' : ''}");
      }

      return parts.isEmpty ? "0 secs" : parts.join(' ');
    } catch (_) {
      return "";
    }
  }

  Widget _buildBackupSettingsSection() {
    return Container(
      color: AppColors.surfaceCard,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.backup_rounded, color: AppColors.skyBlue),
              SizedBox(width: 12),
              Text(
                "Daily Auto Backup",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.sync_rounded, color: Colors.white70),
            title: const Text(
              "Enable Auto Backup",
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
            subtitle: const Text(
              "Runs daily backup of your device media/docs",
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            trailing: Switch(
              value: _backupEnabled,
              activeColor: AppColors.skyBlue,
              onChanged: (bool val) async {
                if (val) {
                  try {
                    final bool isGranted = await _channel.invokeMethod<bool>('checkStoragePermission') ?? false;
                    if (!isGranted) {
                      final String res = await _channel.invokeMethod<String>('requestStoragePermission') ?? 'denied';
                      if (res != 'granted') {
                        showTopSnackBar(context, 
                           const SnackBar(
                            content: Text("⚠️ Storage permission is required to enable daily backup."),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }
                    }
                  } catch (e) {
                    print("Error checking permission: $e");
                  }
                }
                setState(() {
                  _backupEnabled = val;
                });
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, color: Colors.white70, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _backupTimeController,
                  readOnly: true,
                  onTap: () => _selectBackupTime(context),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: const InputDecoration(
                    labelText: "Backup Time",
                    labelStyle: TextStyle(color: Colors.white60, fontSize: 13),
                    hintText: "Select backup time",
                    hintStyle: TextStyle(color: Colors.white30),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.skyBlue),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_backupEnabled) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 36.0),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.orangeAccent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    "Next backup in: ${_calculateGapTime()}",
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _saveBackupSettings();
                    showTopSnackBar(context, 
                      const SnackBar(
                        content: Text("📁 Backup settings saved successfully!"),
                        backgroundColor: AppColors.skyBlue,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_rounded, color: Colors.black, size: 18),
                  label: const Text(
                    "Save Settings",
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.skyBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _triggerManualBackup,
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    "Backup Now",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<List<File>> _safeListFiles(Directory dir) async {
    List<File> files = [];
    try {
      final stream = dir.list(recursive: false, followLinks: false);
      await for (var entity in stream) {
        if (entity is File) {
          files.add(entity);
        } else if (entity is Directory) {
          // Skip the Backup folder itself to avoid circular copy
          if (entity.path.contains("DailyBackup")) continue;
          final subFiles = await _safeListFiles(entity);
          files.addAll(subFiles);
        }
      }
    } catch (e) {
      print("Skipping restricted directory ${dir.path}: $e");
    }
    return files;
  }

  Future<void> _runBackupProcedure(bool manual) async {
    if (kIsWeb) return;
    if (manual) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.skyBlue),
        ),
      );
    }

    int movedCount = 0;
    List<String> movedFiles = [];

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

      if (!await todayBackup.exists()) {
        await todayBackup.create(recursive: true);
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
        if (!await dir.exists()) continue;

        List<File> files = [];
        try {
          files = await _safeListFiles(dir);
        } catch (e) {
          print("Error listing source folder $source: $e");
          continue;
        }

        for (var file in files) {
          try {
            final modifiedDate = await file.lastModified();
            final differenceInHours = todayDate.difference(modifiedDate).inHours;
            final isSameDay = modifiedDate.year == todayDate.year &&
                modifiedDate.month == todayDate.month &&
                modifiedDate.day == todayDate.day;

            if (isSameDay || (differenceInHours >= 0 && differenceInHours <= 24)) {
              final dotIndex = file.path.lastIndexOf('.');
              if (dotIndex == -1) continue;
              final ext = file.path.substring(dotIndex).toLowerCase();
              String? category;
              extensions.forEach((key, exts) {
                if (exts.contains(ext)) {
                  category = key;
                }
              });

              if (category != null) {
                final catFolder = Directory("${todayBackup.path}/$category");
                if (!await catFolder.exists()) {
                  await catFolder.create(recursive: true);
                }

                final fileName = file.path.split(RegExp(r'[/\\]')).last;
                final destPath = "${catFolder.path}/$fileName";

                // Try to move (rename) the file first
                try {
                  await file.rename(destPath);
                } catch (e) {
                  // Fallback to copy and delete if rename fails
                  try {
                    await file.copy(destPath);
                    await file.delete();
                  } catch (err) {
                    print("Copy/delete failed for ${file.path}: $err");
                    continue;
                  }
                }

                movedCount++;
                movedFiles.add(fileName);
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      print("Backup failed: $e");
    }

    // TTS & Vibration notifications on completion
    try {
      await _channel.invokeMethod('speak', {'text': 'backup finished'});
      await _channel.invokeMethod('vibrate');
    } catch (e) {
      print("TTS/Vibrate failed: $e");
    }

    if (manual) {
      Navigator.pop(context); // Close loading dialog
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: AppColors.skyBlue),
              SizedBox(width: 8),
              Text("Backup Completed", style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Text(
            movedCount > 0
                ? "Successfully moved $movedCount files modified today into /storage/emulated/0/DailyBackup!\n\nFiles:\n${movedFiles.take(5).join('\n')}${movedFiles.length > 5 ? '\n...and ${movedFiles.length - 5} more' : ''}"
                : "No files modified today were found in your camera, pictures, downloads, or media folders.",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK", style: TextStyle(color: AppColors.skyBlue, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDialogRadioOption(String option) {
    return SimpleDialogOption(
      onPressed: () {
        setState(() {
          _disappearingMessagesStatus = option;
        });
        Navigator.pop(context);
        showTopSnackBar(context, 
          SnackBar(
            content: Text("Disappearing messages set to: $option"),
            backgroundColor: AppColors.skyBlue,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Radio<String>(
              value: option,
              groupValue: _disappearingMessagesStatus,
              activeColor: AppColors.skyBlue,
              onChanged: (val) {},
            ),
            Text(
              option,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// Paints a detailed scanning matrix mimicking genuine QR codes
class MockQrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..style = PaintingStyle.fill;

    // Outer framing squares
    canvas.drawRect(const Rect.fromLTWH(0, 0, 40, 40), paint);
    canvas.drawRect(const Rect.fromLTWH(110, 0, 40, 40), paint);
    canvas.drawRect(const Rect.fromLTWH(0, 110, 40, 40), paint);

    // Inner white squares to mimic QR structure
    paint.color = Colors.white;
    canvas.drawRect(const Rect.fromLTWH(8, 8, 24, 24), paint);
    canvas.drawRect(const Rect.fromLTWH(118, 8, 24, 24), paint);
    canvas.drawRect(const Rect.fromLTWH(8, 118, 24, 24), paint);

    // QR center anchors
    paint.color = Colors.black;
    canvas.drawRect(const Rect.fromLTWH(16, 16, 8, 8), paint);
    canvas.drawRect(const Rect.fromLTWH(126, 16, 8, 8), paint);
    canvas.drawRect(const Rect.fromLTWH(16, 126, 8, 8), paint);

    // Scattered mock data bits
    canvas.drawRect(const Rect.fromLTWH(50, 10, 12, 6), paint);
    canvas.drawRect(const Rect.fromLTWH(70, 20, 8, 14), paint);
    canvas.drawRect(const Rect.fromLTWH(55, 60, 20, 10), paint);
    canvas.drawRect(const Rect.fromLTWH(85, 45, 14, 25), paint);
    canvas.drawRect(const Rect.fromLTWH(100, 80, 8, 18), paint);
    canvas.drawRect(const Rect.fromLTWH(30, 90, 25, 8), paint);
    canvas.drawRect(const Rect.fromLTWH(65, 100, 10, 24), paint);
    canvas.drawRect(const Rect.fromLTWH(120, 90, 18, 8), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AppLockConfigSheet extends StatefulWidget {
  final bool initialEnabled;
  final String initialType;
  final VoidCallback onChanged;

  const _AppLockConfigSheet({
    required this.initialEnabled,
    required this.initialType,
    required this.onChanged,
  });

  @override
  State<_AppLockConfigSheet> createState() => _AppLockConfigSheetState();
}

class _AppLockConfigSheetState extends State<_AppLockConfigSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _oldPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _isObscureOld = true;
  bool _isObscureNew = true;
  bool _isObscureConfirm = true;
  String _errorMessage = '';
  bool _isChangingCode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2, 
      vsync: this, 
      initialIndex: widget.initialType == 'pin' ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _oldPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _enableAppLock() async {
    setState(() {
      _errorMessage = '';
    });

    final newCode = _newPassController.text.trim();
    final confirmCode = _confirmPassController.text.trim();
    final isPin = _tabController.index == 0;
    final lockType = isPin ? 'pin' : 'password';

    if (newCode.isEmpty || confirmCode.isEmpty) {
      setState(() {
        _errorMessage = 'All fields are required';
      });
      return;
    }

    if (isPin) {
      if (newCode.length != 6 || int.tryParse(newCode) == null) {
        setState(() {
          _errorMessage = 'PIN must be exactly 6 digits and only numbers';
        });
        return;
      }
    }

    if (newCode != confirmCode) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', true);
    await prefs.setString('app_lock_type', lockType);
    await prefs.setString('app_lock_value', newCode);

    widget.onChanged();
    if (mounted) {
      Navigator.pop(context);
      showTopSnackBar(context, 
        SnackBar(
          content: Text('🔒 App Lock enabled with ${lockType.toUpperCase()} successfully!'),
          backgroundColor: AppColors.skyBlue,
        ),
      );
    }
  }

  Future<void> _disableAppLock() async {
    setState(() {
      _errorMessage = '';
    });

    final currentCodeInput = _oldPassController.text.trim();
    if (currentCodeInput.isEmpty) {
      setState(() {
        _errorMessage = 'Enter your current PIN or Password to disable';
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedCode = prefs.getString('app_lock_value') ?? '';

    if (currentCodeInput != storedCode) {
      setState(() {
        _errorMessage = 'Incorrect PIN or Password';
      });
      return;
    }

    await prefs.setBool('app_lock_enabled', false);
    await prefs.remove('app_lock_value');
    await prefs.remove('app_lock_type');

    widget.onChanged();
    if (mounted) {
      Navigator.pop(context);
      showTopSnackBar(context, 
        const SnackBar(
          content: Text('🔓 App Lock disabled successfully.'),
          backgroundColor: Colors.blueGrey,
        ),
      );
    }
  }

  Future<void> _changeAppLockCode() async {
    setState(() {
      _errorMessage = '';
    });

    final oldCode = _oldPassController.text.trim();
    final newCode = _newPassController.text.trim();
    final confirmCode = _confirmPassController.text.trim();
    final isPin = widget.initialType == 'pin';

    if (oldCode.isEmpty || newCode.isEmpty || confirmCode.isEmpty) {
      setState(() {
        _errorMessage = 'All fields are required';
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedCode = prefs.getString('app_lock_value') ?? '';

    if (oldCode != storedCode) {
      setState(() {
        _errorMessage = 'Incorrect old PIN or Password';
      });
      return;
    }

    if (isPin) {
      if (newCode.length != 6 || int.tryParse(newCode) == null) {
        setState(() {
          _errorMessage = 'New PIN must be exactly 6 digits and only numbers';
        });
        return;
      }
    }

    if (newCode != confirmCode) {
      setState(() {
        _errorMessage = 'New passwords do not match';
      });
      return;
    }

    await prefs.setString('app_lock_value', newCode);

    widget.onChanged();
    if (mounted) {
      Navigator.pop(context);
      showTopSnackBar(context, 
        SnackBar(
          content: Text('🎉 ${isPin ? 'PIN' : 'Password'} changed successfully!'),
          backgroundColor: AppColors.skyBlue,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActiveLock = widget.initialEnabled;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  hasActiveLock ? 'Manage App Lock' : 'Setup App Lock',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_errorMessage.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (!hasActiveLock) ...[
              // Setup Flow
              // Tab Selector
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.skyBlue,
                labelColor: AppColors.skyBlue,
                unselectedLabelColor: Colors.white54,
                tabs: const [
                  Tab(icon: Icon(Icons.pin), text: 'PIN (6 Digits)'),
                  Tab(icon: Icon(Icons.password), text: 'Password'),
                ],
              ),
              const SizedBox(height: 24),
              
              // Inputs
              TextField(
                controller: _newPassController,
                obscureText: _isObscureNew,
                keyboardType: TextInputType.text,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Enter PIN / Password',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.skyBlue),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscureNew ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white54,
                    ),
                    onPressed: () => setState(() => _isObscureNew = !_isObscureNew),
                  ),
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
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPassController,
                obscureText: _isObscureConfirm,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Confirm PIN / Password',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.skyBlue),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscureConfirm ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white54,
                    ),
                    onPressed: () => setState(() => _isObscureConfirm = !_isObscureConfirm),
                  ),
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
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.skyBlue,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _enableAppLock,
                child: const Text('Enable App Lock', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              // Already Configured Flow
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isChangingCode ? Colors.transparent : AppColors.skyBlue.withValues(alpha: 0.15),
                        foregroundColor: Colors.white,
                        side: BorderSide(color: _isChangingCode ? Colors.white24 : AppColors.skyBlue),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => setState(() {
                        _isChangingCode = false;
                        _errorMessage = '';
                      }),
                      child: const Text('Disable Lock'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isChangingCode ? AppColors.skyBlue.withValues(alpha: 0.15) : Colors.transparent,
                        foregroundColor: Colors.white,
                        side: BorderSide(color: _isChangingCode ? AppColors.skyBlue : Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => setState(() {
                        _isChangingCode = true;
                        _errorMessage = '';
                      }),
                      child: const Text('Change Code'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              if (!_isChangingCode) ...[
                // Disable Form
                TextField(
                  controller: _oldPassController,
                  obscureText: _isObscureOld,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Enter Current PIN / Password',
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.skyBlue),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscureOld ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () => setState(() => _isObscureOld = !_isObscureOld),
                    ),
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
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _disableAppLock,
                  child: const Text('Confirm Disable', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ] else ...[
                // Change Form
                TextField(
                  controller: _oldPassController,
                  obscureText: _isObscureOld,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Enter Old PIN / Password',
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.password, color: AppColors.skyBlue),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscureOld ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () => setState(() => _isObscureOld = !_isObscureOld),
                    ),
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
                const SizedBox(height: 16),
                TextField(
                  controller: _newPassController,
                  obscureText: _isObscureNew,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Enter New PIN / Password',
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.skyBlue),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscureNew ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () => setState(() => _isObscureNew = !_isObscureNew),
                    ),
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
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPassController,
                  obscureText: _isObscureConfirm,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Confirm New PIN / Password',
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.skyBlue),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscureConfirm ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () => setState(() => _isObscureConfirm = !_isObscureConfirm),
                    ),
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
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.skyBlue,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _changeAppLockCode,
                  child: const Text('Update PIN / Password', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class StarredMessagesPage extends StatefulWidget {
  final List<ChatMessage> messages;

  const StarredMessagesPage({super.key, required this.messages});

  @override
  State<StarredMessagesPage> createState() => _StarredMessagesPageState();
}

class _StarredMessagesPageState extends State<StarredMessagesPage> {
  @override
  Widget build(BuildContext context) {
    final starredList = widget.messages.where((m) => m.isStarred).toList();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        title: const Text(
          "Starred Messages ⭐",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: starredList.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.star_border_rounded,
                      size: 96,
                      color: Colors.amber,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Aiyo chellam, empty-ah irukku! 🥺",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Chat page-la message-ah hold panni tap the ⭐ icon to save them here!",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: starredList.length,
              itemBuilder: (context, index) {
                final msg = starredList[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                msg.isMe ? "You" : "Poonguzhali",
                                style: TextStyle(
                                  color: msg.isMe ? const Color(0xFF00B0FF) : Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 14,
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                msg.time,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  setState(() {
                                    msg.isStarred = false;
                                  });
                                  try {
                                    // Remove from local SharedPreferences
                                    try {
                                      final prefs = await SharedPreferences.getInstance();
                                      final starredIds = prefs.getStringList('starred_message_ids') ?? [];
                                      starredIds.remove(msg.id);
                                      await prefs.setStringList('starred_message_ids', starredIds);
                                    } catch (_) {}

                                    if (msg.id.isNotEmpty) {
                                      await http.post(
                                        Uri.parse('${AppConfig.baseUrl}/api/ai/messages/${msg.id}/star'),
                                        headers: {'Content-Type': 'application/json'},
                                        body: jsonEncode({'isStarred': false}),
                                      );
                                    }
                                  } catch (_) {}
                                  
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text("Unstarred message!"),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                child: const Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        msg.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class ChatSettingsPage extends StatefulWidget {
  const ChatSettingsPage({super.key});

  @override
  State<ChatSettingsPage> createState() => _ChatSettingsPageState();
}

class _ChatSettingsPageState extends State<ChatSettingsPage> {
  String _selectedPersona = "";
  List<dynamic> _personas = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final settingsRes = await http.get(Uri.parse('${AppConfig.baseUrl}/api/ai/settings'));
      final personasRes = await http.get(Uri.parse('${AppConfig.baseUrl}/api/ai/personas'));

      if (settingsRes.statusCode == 200 && personasRes.statusCode == 200) {
        final settingsData = jsonDecode(settingsRes.body);
        final List<dynamic> personasData = jsonDecode(personasRes.body);

        setState(() {
          _personas = personasData;
          final String loadedPersona = settingsData['selectedPersona'] ?? "";
          if (loadedPersona.isEmpty || loadedPersona == "gbf") {
            if (_personas.isNotEmpty) {
              final firstP = _personas.first;
              final isSystem = firstP['isSystem'] ?? false;
              _selectedPersona = isSystem ? (firstP['key'] ?? '') : (firstP['_id'] ?? '');
            } else {
              _selectedPersona = "";
            }
          } else {
            _selectedPersona = loadedPersona;
          }
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showErrorSnackBar("Failed to load settings or personas from server.");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar("Connection error: $e");
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/ai/settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'selectedPersona': _selectedPersona,
        }),
      );
      setState(() => _isSaving = false);
      if (response.statusCode == 200) {
        showTopSnackBar(context, 
          const SnackBar(
            content: Text("🎉 Chatbot persona updated successfully!"),
            backgroundColor: AppColors.skyBlue,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } else {
        _showErrorSnackBar("Failed to update settings.");
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showErrorSnackBar("Connection error: $e");
    }
  }

  Future<void> _deletePersona(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text("Delete Persona", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to delete '$name'?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await http.delete(Uri.parse('${AppConfig.baseUrl}/api/ai/personas/$id'));
        if (res.statusCode == 200) {
          await _fetchSettings();
          if (_selectedPersona == id) {
            setState(() {
              if (_personas.isNotEmpty) {
                final firstP = _personas.first;
                final isSystem = firstP['isSystem'] ?? false;
                _selectedPersona = isSystem ? (firstP['key'] ?? '') : (firstP['_id'] ?? '');
              } else {
                _selectedPersona = "";
              }
            });
          }
          showTopSnackBar(context, 
            const SnackBar(
              content: Text("Persona deleted successfully"),
              backgroundColor: AppColors.skyBlue,
            ),
          );
        } else {
          _showErrorSnackBar("Failed to delete persona.");
        }
      } catch (e) {
        _showErrorSnackBar("Connection error: $e");
      }
    }
  }

  void _showCreatePersonaSheet() {
    final nameController = TextEditingController();
    final promptController = TextEditingController();
    bool isCreating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Create Custom Persona 🧠",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: "Persona Name (e.g. Angry GF, Code Coach)",
                        labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: AppColors.skyBlue),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        fillColor: Colors.black26,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: promptController,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: "Instructions / Prompt",
                        labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
                        hintText: "E.g., You are a highly toxic but caring companion who mocks me when I don't code...",
                        hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: AppColors.skyBlue),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        fillColor: Colors.black26,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isCreating
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              final prompt = promptController.text.trim();
                              if (name.isEmpty || prompt.isEmpty) {
                                showTopSnackBar(context, 
                                  const SnackBar(
                                    content: Text("Please fill all fields"),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }

                              setSheetState(() => isCreating = true);
                              try {
                                final res = await http.post(
                                  Uri.parse('${AppConfig.baseUrl}/api/ai/personas'),
                                  headers: {'Content-Type': 'application/json'},
                                  body: jsonEncode({'name': name, 'prompt': prompt}),
                                );

                                if (res.statusCode == 201) {
                                  final newPersona = jsonDecode(res.body);
                                  Navigator.pop(context);
                                  _fetchSettings(); // Re-fetch list
                                  setState(() {
                                    _selectedPersona = newPersona['_id']; // Auto select new persona
                                  });
                                  showTopSnackBar(context, 
                                    SnackBar(
                                      content: Text("🎉 Persona '$name' created and selected!"),
                                      backgroundColor: AppColors.skyBlue,
                                    ),
                                  );
                                } else {
                                  setSheetState(() => isCreating = false);
                                  showTopSnackBar(context, 
                                    const SnackBar(
                                      content: Text("Failed to create persona"),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() => isCreating = false);
                                showTopSnackBar(context, 
                                  SnackBar(
                                    content: Text("Connection error: $e"),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.skyBlue,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isCreating
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                            )
                          : const Text("Save & Add to List", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showErrorSnackBar(String msg) {
    showTopSnackBar(context, 
      SnackBar(
        content: Text("⚠️ $msg"),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        title: const Text(
          "Poonguzhali Persona 🧠",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.skyBlue))
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Select Chatbot Profile",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Change Poonguzhali's behavior, relationship status, and speech style instantly.",
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(height: 20),

                      // List of Personas
                      ..._personas.map((persona) {
                        final isSystem = persona['isSystem'] ?? false;
                        final String id = isSystem ? (persona['key'] ?? '') : (persona['_id'] ?? '');
                        final String name = persona['name'] ?? '';
                        final String prompt = persona['prompt'] ?? '';

                        Color cardColor;
                        String title;
                        String subtitle;

                        if (isSystem) {
                          if (id == 'gbf') {
                            cardColor = Colors.tealAccent;
                            title = "Playful Girl Best Friend (GBF) 👩‍❤️‍👨";
                            subtitle = "Super smart, mature bestie. Speaks witty Tanglish, cracks bold dark comedy & suggestive jokes.";
                          } else if (id == 'romantic_gf') {
                            cardColor = Colors.pinkAccent;
                            title = "Romantic Girlfriend ❤️";
                            subtitle = "Deeply affectionate, highly romantic, extremely sweet, smart doubt-solver. Always showers you with love.";
                          } else if (id == 'possessive_gf') {
                            cardColor = Colors.amberAccent;
                            title = "Possessive Girlfriend 😤";
                            subtitle = "Very sweet but super possessive and protective. Gets jealous if other girls' names are mentioned!";
                          } else if (id == 'mentor') {
                            cardColor = AppColors.lightBlueAccent;
                            title = "Strict Mentor 💪";
                            subtitle = "Mature and encouraging. Explains coding, math, and science deeply to motivate you to focus and study.";
                          } else {
                            cardColor = AppColors.blueAccent;
                            title = name;
                            subtitle = prompt;
                          }
                        } else {
                          cardColor = Colors.purpleAccent;
                          title = "$name ⚙️";
                          subtitle = prompt.length > 100 ? prompt.substring(0, 100) + '...' : prompt;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _buildPersonaCard(
                            id: id,
                            title: title,
                            subtitle: subtitle,
                            color: cardColor,
                            isCustom: !isSystem,
                            onDelete: () => _deletePersona(id, name),
                          ),
                        );
                      }).toList(),

                      const SizedBox(height: 16),

                      // Button to create new persona
                      OutlinedButton.icon(
                        onPressed: _showCreatePersonaSheet,
                        icon: const Icon(Icons.add_rounded, color: AppColors.skyBlue),
                        label: const Text("Create Custom Persona", style: TextStyle(color: AppColors.skyBlue, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.skyBlue, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),

                      const SizedBox(height: 120), // extra padding for save button
                    ],
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.skyBlue,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                            )
                          : const Text(
                              "Save Active Persona",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPersonaCard({
    required String id,
    required String title,
    required String subtitle,
    required Color color,
    bool isCustom = false,
    VoidCallback? onDelete,
  }) {
    final bool isSelected = _selectedPersona == id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPersona = id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.white12,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Theme(
              data: Theme.of(context).copyWith(
                unselectedWidgetColor: Colors.white30,
              ),
              child: Radio<String>(
                value: id,
                groupValue: _selectedPersona,
                activeColor: color,
                onChanged: (val) {
                  setState(() {
                    _selectedPersona = val!;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? color : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (isCustom && onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

class TransactionCategoriesPage extends StatefulWidget {
  const TransactionCategoriesPage({super.key});

  @override
  State<TransactionCategoriesPage> createState() => _TransactionCategoriesPageState();
}

class _TransactionCategoriesPageState extends State<TransactionCategoriesPage> {
  final TextEditingController _categoryController = TextEditingController();
  List<dynamic> _categories = [];
  bool _isLoading = true;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await http.get(Uri.parse('${AppConfig.baseUrl}/api/categories'));
      if (res.statusCode == 200) {
        setState(() {
          _categories = jsonDecode(res.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showErrorSnackBar("Failed to load categories.");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar("Connection error: $e");
    }
  }

  Future<void> _addCategory() async {
    final name = _categoryController.text.trim();
    if (name.isEmpty) {
      _showErrorSnackBar("Category name cannot be empty.");
      return;
    }

    setState(() => _isAdding = true);
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/categories'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name}),
      );

      setState(() => _isAdding = false);
      if (res.statusCode == 201) {
        _categoryController.clear();
        _fetchCategories();
        showTopSnackBar(context, 
          SnackBar(
            content: Text("🎉 Category '$name' added!"),
            backgroundColor: AppColors.skyBlue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        String msg = "Failed to add category.";
        try {
          msg = jsonDecode(res.body)['message'] ?? msg;
        } catch (_) {}
        _showErrorSnackBar(msg);
      }
    } catch (e) {
      setState(() => _isAdding = false);
      _showErrorSnackBar("Connection error: $e");
    }
  }

  Future<void> _deleteCategory(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text("Delete Category", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to delete category '$name'?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white30)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.delete(Uri.parse('${AppConfig.baseUrl}/api/categories/$id'));
      if (res.statusCode == 200) {
        _fetchCategories();
        showTopSnackBar(context, 
          SnackBar(
            content: Text("🗑️ Category '$name' deleted!"),
            backgroundColor: Colors.blueGrey,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _showErrorSnackBar("Failed to delete category.");
      }
    } catch (e) {
      _showErrorSnackBar("Connection error: $e");
    }
  }

  void _showErrorSnackBar(String msg) {
    if (!mounted) return;
    showTopSnackBar(context, 
      SnackBar(
        content: Text("⚠️ $msg"),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        title: const Text(
          "Transaction Categories 📁",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.skyBlue))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Add New Category",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _categoryController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Category name (e.g. Food, Travel)",
                            hintStyle: const TextStyle(color: Colors.white30),
                            filled: true,
                            fillColor: AppColors.surfaceCard,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          onSubmitted: (_) => _addCategory(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isAdding ? null : _addCategory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.skyBlue,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isAdding
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                              )
                            : const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Existing Categories",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _categories.isEmpty
                        ? const Center(
                            child: Text(
                              "No categories added yet.\nCreate one above to list in transactions!",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white38),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _categories.length,
                            separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                            itemBuilder: (ctx, idx) {
                              final cat = _categories[idx];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  cat['name'] ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 15),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => _deleteCategory(cat['_id'], cat['name']),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
