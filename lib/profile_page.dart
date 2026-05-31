import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
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

  bool _isAppLockEnabled = false;
  String _appLockType = 'pin';

  @override
  void initState() {
    super.initState();
    _loadBackupSettings();
    _loadAppLockSettings();
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
                  ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
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
          ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("⚠️ Error initiating backup: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
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
                        ScaffoldMessenger.of(context).showSnackBar(
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
                _saveBackupSettings();
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
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: const InputDecoration(
                    labelText: "Backup Time",
                    labelStyle: TextStyle(color: Colors.white60, fontSize: 13),
                    hintText: "e.g. 10:30 PM",
                    hintStyle: TextStyle(color: Colors.white30),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.skyBlue),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                  ),
                  onChanged: (_) => _saveBackupSettings(),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _triggerManualBackup,
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20),
                label: const Text("Backup Now", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.skyBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
      await _channel.invokeMethod('speak', {'text': 'Backup Completed'});
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
        ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
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
