import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // Just in case, standard imports
import 'app_config.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> with SingleTickerProviderStateMixin {
  static const String _baseUrl = AppConfig.baseUrl;

  late TabController _tabController;
  List<dynamic> _contacts = [];
  List<dynamic> _customReminders = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    int maxRetries = 3;
    int retryDelaySeconds = 2;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final results = await Future.wait([
          http.get(Uri.parse('$_baseUrl/api/contacts')).timeout(const Duration(seconds: 15)),
          http.get(Uri.parse('$_baseUrl/api/reminders')).timeout(const Duration(seconds: 15)),
        ]);

        final contactsRes = results[0];
        final remindersRes = results[1];

        if (contactsRes.statusCode == 200 && remindersRes.statusCode == 200) {
          setState(() {
            _contacts = jsonDecode(contactsRes.body);
            _customReminders = jsonDecode(remindersRes.body);
            _isLoading = false;
          });
          return;
        } else {
          throw Exception('Server error: ${contactsRes.statusCode} / ${remindersRes.statusCode}');
        }
      } catch (e) {
        print('Fetch attempt $attempt failed: $e');
        if (attempt == maxRetries) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Connection failed: $e';
          });
        } else {
          await Future.delayed(Duration(seconds: retryDelaySeconds * attempt));
        }
      }
    }
  }

  Future<void> _createReminder(String title, String dateTime) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/reminders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'dateTime': dateTime,
          'type': 'custom',
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🔔 Reminder added successfully da thambi!'), backgroundColor: Colors.lightBlueAccent),
        );
        _fetchAllData();
      } else {
        throw Exception('Failed to create reminder');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _deleteReminder(String id) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/api/reminders/$id')).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Reminder deleted!'), backgroundColor: Colors.blueGrey),
        );
        _fetchAllData();
      } else {
        throw Exception('Failed to delete reminder');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  // Calculate days remaining until next birthday
  Map<String, dynamic> _calculateBirthdayDetails(String bdayStr) {
    if (bdayStr.isEmpty) return {'daysLeft': 999, 'ageNext': 0, 'formattedDate': ''};
    try {
      final birthDate = DateTime.parse(bdayStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      var nextBday = DateTime(now.year, birthDate.month, birthDate.day);
      if (nextBday.isBefore(today)) {
        nextBday = DateTime(now.year + 1, birthDate.month, birthDate.day);
      }
      
      final daysLeft = nextBday.difference(today).inDays;
      final ageNext = nextBday.year - birthDate.year;
      final formattedDate = DateFormat('dd MMM').format(birthDate);
      
      return {
        'daysLeft': daysLeft,
        'ageNext': ageNext,
        'formattedDate': formattedDate,
      };
    } catch (_) {
      return {'daysLeft': 999, 'ageNext': 0, 'formattedDate': ''};
    }
  }

  void _openAddReminderSheet() {
    final titleCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    DateTime? selectedDateTime;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '⏰ Add Custom Reminder',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white60),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Reminder Title
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Reminder Title',
                    labelStyle: const TextStyle(color: Colors.white60),
                    prefixIcon: const Icon(Icons.alarm_rounded, color: Colors.lightBlueAccent),
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

                // Date Picker field
                StatefulBuilder(
                  builder: (BuildContext context, StateSetter setFieldState) {
                    return TextField(
                      controller: dateCtrl,
                      readOnly: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Date & Time',
                        labelStyle: const TextStyle(color: Colors.white60),
                        prefixIcon: const Icon(Icons.calendar_today_rounded, color: Colors.lightBlueAccent),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.date_range_rounded, color: Colors.lightBlueAccent),
                          onPressed: () async {
                            final datePick = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (datePick != null) {
                              if (!context.mounted) return;
                              final timePick = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (timePick != null) {
                                selectedDateTime = DateTime(
                                  datePick.year,
                                  datePick.month,
                                  datePick.day,
                                  timePick.hour,
                                  timePick.minute,
                                );
                                setFieldState(() {
                                  dateCtrl.text = DateFormat('yyyy-MM-dd HH:mm').format(selectedDateTime!);
                                });
                              }
                            }
                          },
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                ),

                const SizedBox(height: 24),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlueAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    final dateTime = dateCtrl.text.trim();
                    if (title.isEmpty || dateTime.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('⚠️ Type some title and choose date/time first da!'), backgroundColor: Colors.redAccent),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    _createReminder(title, dateTime);
                  },
                  child: const Text('Create Reminder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _launchWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Cannot launch';
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp launch panna mudiyala da! Number check pannu.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _launchCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Cannot launch';
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call panna mudiyala da! Check phone configurations.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Process Birthdays
    final birthdayContacts = _contacts.where((c) {
      final bday = c['birthday']?.toString() ?? '';
      return bday.isNotEmpty && bday != '—';
    }).map((c) {
      final bdayStr = c['birthday'].toString();
      final details = _calculateBirthdayDetails(bdayStr);
      return {
        'contact': c,
        'daysLeft': details['daysLeft'],
        'ageNext': details['ageNext'],
        'formattedDate': details['formattedDate'],
      };
    }).toList();

    // Sort Birthdays: closest upcoming first
    birthdayContacts.sort((a, b) => (a['daysLeft'] as int).compareTo(b['daysLeft'] as int));

    // Sort Custom Reminders by Date Time
    final sortedReminders = List<dynamic>.from(_customReminders);
    sortedReminders.sort((a, b) {
      final aTime = a['dateTime']?.toString() ?? '';
      final bTime = b['dateTime']?.toString() ?? '';
      return aTime.compareTo(bTime);
    });

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
          '⏰ Reminders & Birthdays',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.lightBlueAccent),
            onPressed: _fetchAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.lightBlueAccent,
          labelColor: Colors.lightBlueAccent,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(icon: Icon(Icons.alarm_rounded, size: 20), text: 'Custom Reminders'),
            Tab(icon: Icon(Icons.cake_rounded, size: 20), text: 'Birthdays'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.lightBlueAccent,
        foregroundColor: Colors.black,
        elevation: 6,
        onPressed: _openAddReminderSheet,
        child: const Icon(Icons.add_alarm_rounded, size: 26),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.lightBlueAccent))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchAllData,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlueAccent, foregroundColor: Colors.black),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Custom Reminders Tab View
                    sortedReminders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.alarm_add_rounded, size: 72, color: Colors.white.withValues(alpha: 0.08)),
                                const SizedBox(height: 16),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 32),
                                  child: Text(
                                    'Inga custom reminders ethuvum illada chellam! Add button click panni reminder set panniko! 🔔❤️',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: sortedReminders.length,
                            itemBuilder: (ctx, idx) {
                              final r = sortedReminders[idx];
                              final id = r['_id'] ?? '';
                              final title = r['title'] ?? 'No Title';
                              final dateTimeStr = r['dateTime'] ?? '';

                              // Format display date time
                              var formatted = dateTimeStr;
                              try {
                                final parsed = DateFormat('yyyy-MM-dd HH:mm').parse(dateTimeStr);
                                formatted = DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
                              } catch (_) {}

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.lightBlueAccent.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.alarm_on_rounded, color: Colors.lightBlueAccent, size: 22),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            formatted,
                                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                                      onPressed: () => _deleteReminder(id),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                    // Birthdays Tab View
                    birthdayContacts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cake_rounded, size: 72, color: Colors.white.withValues(alpha: 0.08)),
                                const SizedBox(height: 16),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 32),
                                  child: Text(
                                    'Contacts la yaarukum birthday dynamic-a setup panlana birthday list empty-a thaan varum da thambi! 👤🎂',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: birthdayContacts.length,
                            itemBuilder: (ctx, idx) {
                              final item = birthdayContacts[idx];
                              final c = item['contact'] as Map<String, dynamic>;
                              final name = c['fullName'] ?? '—';
                              final photo = c['profilePhoto'] ?? '';
                              final phone = c['phoneNumber'] ?? '';
                              final waNum = c['whatsAppNumber'] ?? '';
                              final imageProvider = AppConfig.getImageProvider(photo.toString());
                              
                              final daysLeft = item['daysLeft'] as int;
                              final ageNext = item['ageNext'] as int;
                              final formattedDate = item['formattedDate'] as String;

                              String daysText = '';
                              if (daysLeft == 0) {
                                daysText = 'Today! 🎉';
                              } else if (daysLeft == 1) {
                                daysText = 'Tomorrow 🎂';
                              } else {
                                daysText = 'In $daysLeft Days ⏳';
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.lightBlueAccent.withValues(alpha: 0.2),
                                      backgroundImage: imageProvider,
                                      child: imageProvider == null
                                          ? Text(
                                              name.toString().substring(0, 1).toUpperCase(),
                                              style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 18),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                '$formattedDate • Turning $ageNext',
                                                style: const TextStyle(color: Colors.white38, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: daysLeft == 0
                                                  ? Colors.lightBlueAccent.withValues(alpha: 0.2)
                                                  : Colors.lightBlueAccent.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              daysText,
                                              style: TextStyle(
                                                color: daysLeft == 0 ? Colors.lightBlueAccent : Colors.lightBlueAccent,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Contact Shortcuts (WA and Call)
                                    if (waNum.toString().isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.chat_rounded, color: Colors.lightBlueAccent, size: 20),
                                        onPressed: () => _launchWhatsApp(waNum.toString()),
                                      ),
                                    if (phone.toString().isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.phone_rounded, color: Colors.lightBlueAccent, size: 20),
                                        onPressed: () => _launchCall(phone.toString()),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ],
                ),
    );
  }
}
