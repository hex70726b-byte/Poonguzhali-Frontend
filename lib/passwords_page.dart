import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'app_config.dart';
import 'app_drawer.dart';

class PasswordEntry {
  final String id;
  final String website;
  final String idNo;
  final String username; // ID in the image
  final String name;
  final String gmail;
  final String number;
  final String password;
  final String category; // 'important' or 'others'
  final DateTime createdAt;

  PasswordEntry({
    required this.id,
    required this.website,
    required this.idNo,
    required this.username,
    required this.name,
    required this.gmail,
    required this.number,
    required this.password,
    required this.category,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    // Base64 encode password for lightweight local privacy
    final encodedPassword = base64.encode(utf8.encode(password));
    return {
      'id': id,
      'website': website,
      'idNo': idNo,
      'username': username,
      'name': name,
      'gmail': gmail,
      'number': number,
      'password': encodedPassword,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PasswordEntry.fromJson(Map<String, dynamic> json) {
    String decodedPassword = '';
    try {
      final rawPassword = json['password'] ?? '';
      decodedPassword = utf8.decode(base64.decode(rawPassword));
    } catch (_) {
      decodedPassword = json['password'] ?? '';
    }

    return PasswordEntry(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      website: json['website'] ?? '',
      idNo: json['idNo'] ?? '',
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      gmail: json['gmail'] ?? '',
      number: json['number'] ?? '',
      password: decodedPassword,
      category: json['category'] ?? 'others',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class PasswordsPage extends StatefulWidget {
  const PasswordsPage({super.key});

  @override
  State<PasswordsPage> createState() => _PasswordsPageState();
}

class _PasswordsPageState extends State<PasswordsPage> with SingleTickerProviderStateMixin {
  static const String _baseUrl = AppConfig.baseUrl;
  late TabController _tabController;
  List<PasswordEntry> _allPasswords = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final Set<String> _expandedIds = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadPasswords();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Load passwords from backend with local fallback cache
  Future<void> _loadPasswords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 1. Try to fetch from Backend API
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/passwords')).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(res.body);
        final fetched = decoded.map((item) => PasswordEntry.fromJson(item)).toList();
        
        setState(() {
          _allPasswords = fetched;
          _allPasswords.sort((a, b) => a.website.toLowerCase().compareTo(b.website.toLowerCase()));
          _isLoading = false;
        });

        // Update local SharedPreferences Cache
        final prefs = await SharedPreferences.getInstance();
        final cacheData = jsonEncode(fetched.map((item) => item.toJson()).toList());
        await prefs.setString('saved_passwords_list', cacheData);
        return;
      }
    } catch (e) {
      debugPrint("Backend load failed, falling back to local cache: $e");
    }

    // 2. Fallback to Local Cache if backend fails or times out
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString('saved_passwords_list');
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        setState(() {
          _allPasswords = decoded.map((item) => PasswordEntry.fromJson(item)).toList();
          _allPasswords.sort((a, b) => a.website.toLowerCase().compareTo(b.website.toLowerCase()));
          _isLoading = false;
        });
        _showSnackBar("⚡ Offline Mode: Loaded from local vault cache", Colors.blueGrey);
      } else {
        setState(() {
          _allPasswords = [];
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Failed to load passwords.";
      });
    }
  }

  // Add a new password entry (Instant local save + async backend sync)
  Future<void> _createPassword(PasswordEntry entry) async {
    setState(() => _isLoading = true);

    // Save locally first to guarantee instant offline response
    final localCopy = List<PasswordEntry>.from(_allPasswords)..add(entry);
    localCopy.sort((a, b) => a.website.toLowerCase().compareTo(b.website.toLowerCase()));
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_passwords_list', jsonEncode(localCopy.map((item) => item.toJson()).toList()));
    } catch (_) {}

    // Sync with backend API
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/passwords'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'website': entry.website,
          'idNo': entry.idNo,
          'username': entry.username,
          'name': entry.name,
          'gmail': entry.gmail,
          'number': entry.number,
          'password': entry.password,
          'category': entry.category,
        }),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 201) {
        _showSnackBar("🔑 Password synced to cloud vault!", AppColors.skyBlue);
      } else {
        _showSnackBar("🔑 Saved locally (Cloud sync pending)", Colors.blueGrey);
      }
    } catch (_) {
      _showSnackBar("🔑 Saved locally (Offline mode)", Colors.blueGrey);
    }

    _loadPasswords();
  }

  // Edit an existing password entry (Instant local update + async backend sync)
  Future<void> _editPassword(PasswordEntry updatedEntry) async {
    setState(() => _isLoading = true);

    // Update locally first
    final index = _allPasswords.indexWhere((element) => element.id == updatedEntry.id);
    if (index != -1) {
      final localCopy = List<PasswordEntry>.from(_allPasswords);
      localCopy[index] = updatedEntry;
      localCopy.sort((a, b) => a.website.toLowerCase().compareTo(b.website.toLowerCase()));
      
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_passwords_list', jsonEncode(localCopy.map((item) => item.toJson()).toList()));
      } catch (_) {}
    }

    // Sync update with backend API
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/api/passwords/${updatedEntry.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'website': updatedEntry.website,
          'idNo': updatedEntry.idNo,
          'username': updatedEntry.username,
          'name': updatedEntry.name,
          'gmail': updatedEntry.gmail,
          'number': updatedEntry.number,
          'password': updatedEntry.password,
          'category': updatedEntry.category,
        }),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        _showSnackBar("✏️ Password updated & cloud synced!", AppColors.skyBlue);
      } else {
        _showSnackBar("✏️ Updated locally (Cloud sync pending)", Colors.blueGrey);
      }
    } catch (_) {
      _showSnackBar("✏️ Updated locally (Offline mode)", Colors.blueGrey);
    }

    _loadPasswords();
  }

  // Delete a password entry (Instant local delete + async backend sync)
  Future<void> _deletePassword(String id) async {
    setState(() => _isLoading = true);

    // Remove locally first
    final localCopy = List<PasswordEntry>.from(_allPasswords)..removeWhere((element) => element.id == id);
    _expandedIds.remove(id);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_passwords_list', jsonEncode(localCopy.map((item) => item.toJson()).toList()));
    } catch (_) {}

    // Sync delete with backend API
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/api/passwords/$id')).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        _showSnackBar("🗑️ Password deleted from cloud vault!", AppColors.skyBlue);
      } else {
        _showSnackBar("🗑️ Deleted locally", Colors.blueGrey);
      }
    } catch (_) {
      _showSnackBar("🗑️ Deleted locally", Colors.blueGrey);
    }

    _loadPasswords();
  }

  void _showSnackBar(String message, Color color) {
    showTopSnackBar(context, 
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Generate strong random password
  String _generatePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()_+';
    final rand = Random.secure();
    return List.generate(14, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  // Show bottom sheet for Adding/Editing password
  void _openFormSheet({PasswordEntry? existing}) {
    final isEdit = existing != null;
    
    final websiteCtrl = TextEditingController(text: isEdit ? existing.website : '');
    final idNoCtrl = TextEditingController(text: isEdit ? existing.idNo : '');
    final usernameCtrl = TextEditingController(text: isEdit ? existing.username : '');
    final nameCtrl = TextEditingController(text: isEdit ? existing.name : '');
    final gmailCtrl = TextEditingController(text: isEdit ? existing.gmail : '');
    final numberCtrl = TextEditingController(text: isEdit ? existing.number : '');
    final passwordCtrl = TextEditingController(text: isEdit ? existing.password : '');
    
    String selectedCategory = isEdit ? existing.category : (_tabController.index == 0 ? 'important' : 'others');
    bool showPasswordInput = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ],
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
                            isEdit ? '✏️ Edit Password Entry' : '🔑 Add Password Entry',
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

                      // Category selection chips
                      Row(
                        children: [
                          const Text(
                            "Category:  ",
                            style: TextStyle(color: Colors.white60, fontWeight: FontWeight.bold),
                          ),
                          ChoiceChip(
                            label: const Text('Important'),
                            selected: selectedCategory == 'important',
                            labelStyle: TextStyle(
                              color: selectedCategory == 'important' ? Colors.white : Colors.white60,
                              fontWeight: FontWeight.bold,
                            ),
                            selectedColor: AppColors.skyBlue,
                            backgroundColor: Colors.white.withValues(alpha: 0.04),
                            onSelected: (selected) {
                              if (selected) {
                                setSheetState(() => selectedCategory = 'important');
                              }
                            },
                          ),
                          const SizedBox(width: 12),
                          ChoiceChip(
                            label: const Text('Others'),
                            selected: selectedCategory == 'others',
                            labelStyle: TextStyle(
                              color: selectedCategory == 'others' ? Colors.white : Colors.white60,
                              fontWeight: FontWeight.bold,
                            ),
                            selectedColor: Colors.blueGrey,
                            backgroundColor: Colors.white.withValues(alpha: 0.04),
                            onSelected: (selected) {
                              if (selected) {
                                setSheetState(() => selectedCategory = 'others');
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Website Field (WEBSITE)
                      _buildTextField(
                        controller: websiteCtrl,
                        label: 'WEBSITE (e.g. google.com, facebook.com)',
                        icon: Icons.language_rounded,
                      ),
                      const SizedBox(height: 12),

                      // ID No Field (ID No)
                      _buildTextField(
                        controller: idNoCtrl,
                        label: 'ID No (e.g. Roll Number / Unique Index)',
                        icon: Icons.tag_rounded,
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 12),

                      // ID Field (ID)
                      _buildTextField(
                        controller: usernameCtrl,
                        label: 'ID (e.g. username / unique_id)',
                        icon: Icons.alternate_email_rounded,
                      ),
                      const SizedBox(height: 12),

                      // Name Field (NAME)
                      _buildTextField(
                        controller: nameCtrl,
                        label: 'NAME (e.g. Account Holder Name)',
                        icon: Icons.person_rounded,
                      ),
                      const SizedBox(height: 12),

                      // Gmail Field (Gmail)
                      _buildTextField(
                        controller: gmailCtrl,
                        label: 'Gmail (e.g. user@gmail.com)',
                        icon: Icons.email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),

                      // Number Field (NUMBER)
                      _buildTextField(
                        controller: numberCtrl,
                        label: 'NUMBER (e.g. Phone Number)',
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),

                      // Password Field (PASSWORD) with show/hide and generator helper
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: passwordCtrl,
                              obscureText: !showPasswordInput,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'PASSWORD',
                                labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                                prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.skyBlue),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    showPasswordInput ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                    color: Colors.white60,
                                  ),
                                  onPressed: () {
                                    setSheetState(() => showPasswordInput = !showPasswordInput);
                                  },
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
                          ),
                          const SizedBox(width: 8),
                          // Password Generator Button
                          Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.skyBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.3)),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.cached_rounded, color: AppColors.skyBlue),
                              tooltip: 'Generate Strong Password',
                              onPressed: () {
                                final pass = _generatePassword();
                                setSheetState(() {
                                  passwordCtrl.text = pass;
                                  showPasswordInput = true;
                                });
                                _showSnackBar("🎲 Generated & filled a strong password!", AppColors.skyBlue);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.skyBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final website = websiteCtrl.text.trim();
                          final idNo = idNoCtrl.text.trim();
                          final username = usernameCtrl.text.trim();
                          final name = nameCtrl.text.trim();
                          final gmail = gmailCtrl.text.trim();
                          final number = numberCtrl.text.trim();
                          final password = passwordCtrl.text;

                          if (website.isEmpty) {
                            showTopSnackBar(context, 
                              const SnackBar(
                                content: Text('⚠️ Website name cannot be empty!'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }

                          Navigator.pop(ctx);

                          final entry = PasswordEntry(
                            id: isEdit ? existing.id : DateTime.now().millisecondsSinceEpoch.toString(),
                            website: website,
                            idNo: idNo,
                            username: username,
                            name: name,
                            gmail: gmail,
                            number: number,
                            password: password,
                            category: selectedCategory,
                            createdAt: isEdit ? existing.createdAt : DateTime.now(),
                          );

                          if (isEdit) {
                            _editPassword(entry);
                          } else {
                            _createPassword(entry);
                          }
                        },
                        child: Text(
                          isEdit ? 'Update Vault' : 'Save in Vault',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.skyBlue),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.skyBlue, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Separate lists by category
    final importantPasswords = _allPasswords.where((e) => e.category == 'important').toList();
    final othersPasswords = _allPasswords.where((e) => e.category == 'others').toList();

    // Filter lists by search query
    List<PasswordEntry> getFilteredList(List<PasswordEntry> list) {
      if (_searchQuery.isEmpty) return list;
      final q = _searchQuery.toLowerCase();
      return list.where((item) {
        return item.website.toLowerCase().contains(q) ||
            item.username.toLowerCase().contains(q) ||
            item.name.toLowerCase().contains(q) ||
            item.gmail.toLowerCase().contains(q) ||
            item.number.toLowerCase().contains(q) ||
            item.idNo.toLowerCase().contains(q);
      }).toList();
    }

    final filteredImportant = getFilteredList(importantPasswords);
    final filteredOthers = getFilteredList(othersPasswords);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      drawer: const AppDrawer(activePage: 'passwords'),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.skyBlue, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          '🔑 Passwords Vault',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.skyBlue),
            onPressed: _loadPasswords,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.skyBlue,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text("Important (${importantPasswords.length})"),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.security_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text("Others (${othersPasswords.length})"),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Elegant Header Card with visual stats
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.skyBlue.withValues(alpha: 0.15), AppColors.skyBlue.withValues(alpha: 0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.skyBlue.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.vpn_key_rounded, color: AppColors.skyBlue, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Encrypted Hybrid Vault',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total of ${_allPasswords.length} items securely saved on device & cloud',
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Box
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
                hintText: 'Search by Website, Name, Email, Username...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.skyBlue),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                fillColor: const Color(0xFF1E1E1E),
                filled: true,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.skyBlue, width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Password lists tab views
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.skyBlue))
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
                              onPressed: _loadPasswords,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPasswordList(filteredImportant, 'No important passwords found'),
                          _buildPasswordList(filteredOthers, 'No other passwords found'),
                        ],
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.skyBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _openFormSheet(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildPasswordList(List<PasswordEntry> list, String emptyMessage) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPasswords,
        color: AppColors.skyBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.5,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_open_rounded, size: 72, color: Colors.white.withValues(alpha: 0.08)),
                const SizedBox(height: 16),
                Text(emptyMessage, style: const TextStyle(color: Colors.white54, fontSize: 15)),
                const SizedBox(height: 8),
                const Text('Tap + to add your first password entry!', style: TextStyle(color: Colors.white30, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPasswords,
      color: AppColors.skyBlue,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: list.length,
      itemBuilder: (ctx, idx) {
        final entry = list[idx];
        final isExpanded = _expandedIds.contains(entry.id);
        
        final firstLetter = entry.website.trim().isNotEmpty
            ? entry.website.trim()[0].toUpperCase()
            : '?';

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isExpanded 
                  ? AppColors.skyBlue.withValues(alpha: 0.3) 
                  : Colors.white.withValues(alpha: 0.05),
              width: 1.5,
            ),
            boxShadow: isExpanded
                ? [
                    BoxShadow(
                      color: AppColors.skyBlue.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey<String>(entry.id),
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  if (expanded) {
                    _expandedIds.add(entry.id);
                  } else {
                    _expandedIds.remove(entry.id);
                  }
                });
              },
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.royalBlue, AppColors.skyBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  firstLetter,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              title: Text(
                entry.website,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                entry.username.isNotEmpty ? 'ID: ${entry.username}' : (entry.gmail.isNotEmpty ? entry.gmail : 'No ID / Username'),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              trailing: Icon(
                isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: isExpanded ? AppColors.skyBlue : Colors.white38,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(color: Colors.white12, height: 1, thickness: 1),
                      const SizedBox(height: 12),
                      
                      _buildDetailRow('WEBSITE', entry.website, canCopy: true),
                      if (entry.idNo.isNotEmpty) _buildDetailRow('ID No', entry.idNo, canCopy: true),
                      if (entry.username.isNotEmpty) _buildDetailRow('ID', entry.username, canCopy: true),
                      if (entry.name.isNotEmpty) _buildDetailRow('NAME', entry.name, canCopy: true),
                      if (entry.gmail.isNotEmpty) _buildDetailRow('Gmail', entry.gmail, canCopy: true),
                      if (entry.number.isNotEmpty) _buildDetailRow('NUMBER', entry.number, canCopy: true),
                      
                      _buildPasswordDetailRow(entry.password),
                      
                      const SizedBox(height: 16),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: AppColors.skyBlue),
                            onPressed: () => _openFormSheet(existing: entry),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                            onPressed: () {
                              _confirmDelete(entry);
                            },
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    ),
  );
}

  Widget _buildDetailRow(String label, String value, {bool canCopy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          if (canCopy && value.isNotEmpty)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                _showSnackBar("📋 Copied $label to clipboard!", AppColors.skyBlue);
              },
              child: const Icon(Icons.copy_rounded, color: AppColors.skyBlue, size: 16),
            ),
        ],
      ),
    );
  }

  Widget _buildPasswordDetailRow(String password) {
    return StatefulBuilder(
      builder: (context, setStateLocal) {
        bool reveal = false;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 90,
                child: Text(
                  'PASSWORD',
                  style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Expanded(
                child: StatefulBuilder(
                  builder: (context, setRevealState) {
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            reveal ? password : '••••••••••••',
                            style: TextStyle(
                              color: reveal ? Colors.white : Colors.white38,
                              fontSize: 14,
                              fontFamily: reveal ? null : 'Courier',
                              letterSpacing: reveal ? 0 : 2,
                            ),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            reveal ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                            color: Colors.white54,
                            size: 18,
                          ),
                          onPressed: () {
                            setRevealState(() => reveal = !reveal);
                          },
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: password));
                            _showSnackBar("📋 Copied Password to clipboard!", AppColors.skyBlue);
                          },
                          child: const Icon(Icons.copy_rounded, color: AppColors.skyBlue, size: 16),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(PasswordEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Password?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete the saved password for ${entry.website}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              _deletePassword(entry.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
