import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'app_config.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  static const String _baseUrl = AppConfig.baseUrl;

  List<dynamic> _contacts = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedGroupFilter = 'All';

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    int maxRetries = 3;
    int retryDelaySeconds = 2;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final res = await http.get(Uri.parse('$_baseUrl/api/contacts')).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          setState(() {
            _contacts = jsonDecode(res.body);
            _isLoading = false;
          });
          return;
        } else {
          throw Exception('Server error: ${res.statusCode}');
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

  Future<void> _createContact(Map<String, dynamic> data) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/contacts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('👤 Contact created successfully!'), backgroundColor: AppColors.lightBlueAccent),
        );
        _fetchContacts();
      } else {
        throw Exception('Failed to create contact');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _updateContact(String id, Map<String, dynamic> data) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/api/contacts/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('👤 Contact updated successfully!'), backgroundColor: AppColors.lightBlueAccent),
        );
        _fetchContacts();
      } else {
        throw Exception('Failed to update contact');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _deleteContact(String id) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/api/contacts/$id')).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Contact deleted!'), backgroundColor: Colors.blueGrey),
        );
        _fetchContacts();
      } else {
        throw Exception('Failed to delete contact');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  int _getGroupCount(String group) {
    if (group == 'All') return _contacts.length;
    return _contacts.where((c) => c['groupCategory'] == group).length;
  }

  void _openFormSheet({dynamic existing}) {
    final isEdit = existing != null;

    final nameCtrl = TextEditingController(text: isEdit ? existing['fullName']?.toString() : '');
    final nickCtrl = TextEditingController(text: isEdit ? existing['nickname']?.toString() : '');
    final phoneCtrl = TextEditingController(text: isEdit ? existing['phoneNumber']?.toString() : '');
    final emailCtrl = TextEditingController(text: isEdit ? existing['email']?.toString() : '');
    final addressCtrl = TextEditingController(text: isEdit ? existing['address']?.toString() : '');
    final companyCtrl = TextEditingController(text: isEdit ? existing['company']?.toString() : '');
    final jobCtrl = TextEditingController(text: isEdit ? existing['jobTitle']?.toString() : '');
    final bdayCtrl = TextEditingController(text: isEdit ? existing['birthday']?.toString() : '');
    final photoCtrl = TextEditingController(text: isEdit ? existing['profilePhoto']?.toString() : '');
    final whatsCtrl = TextEditingController(text: isEdit ? existing['whatsAppNumber']?.toString() : '');
    final webCtrl = TextEditingController(text: isEdit ? existing['website']?.toString() : '');
    final notesCtrl = TextEditingController(text: isEdit ? existing['notes']?.toString() : '');

    // Parse structures
    Map<String, dynamic> socialLinks = {};
    if (isEdit && existing['socialMediaLinks'] != null && existing['socialMediaLinks'].toString().isNotEmpty) {
      try {
        socialLinks = Map<String, dynamic>.from(jsonDecode(existing['socialMediaLinks'].toString()));
      } catch (_) {}
    }
    final instaCtrl = TextEditingController(text: socialLinks['instagram'] ?? '');
    final fbCtrl = TextEditingController(text: socialLinks['facebook'] ?? '');
    final linkedCtrl = TextEditingController(text: socialLinks['linkedin'] ?? '');

    Map<String, dynamic> multNumbers = {};
    if (isEdit && existing['multipleNumbers'] != null && existing['multipleNumbers'].toString().isNotEmpty) {
      try {
        multNumbers = Map<String, dynamic>.from(jsonDecode(existing['multipleNumbers'].toString()));
      } catch (_) {}
    }
    final homePhoneCtrl = TextEditingController(text: multNumbers['home'] ?? '');
    final workPhoneCtrl = TextEditingController(text: multNumbers['work'] ?? '');
    final mobilePhoneCtrl = TextEditingController(text: multNumbers['mobile'] ?? '');

    Map<String, dynamic> multEmails = {};
    if (isEdit && existing['multipleEmails'] != null && existing['multipleEmails'].toString().isNotEmpty) {
      try {
        multEmails = Map<String, dynamic>.from(jsonDecode(existing['multipleEmails'].toString()));
      } catch (_) {}
    }
    final homeEmailCtrl = TextEditingController(text: multEmails['home'] ?? '');
    final workEmailCtrl = TextEditingController(text: multEmails['work'] ?? '');

    String selectedGroup = isEdit ? (existing['groupCategory']?.toString() ?? 'Other') : 'Other';

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
                            isEdit ? '👤 Edit Contact' : '👤 Add New Contact',
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
                      const SizedBox(height: 12),

                      // Group selection
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: ['Family', 'Friends', 'Work', 'Other'].map((g) {
                          final isSel = selectedGroup == g;
                          return ChoiceChip(
                            label: Text(g),
                            selected: isSel,
                            selectedColor: AppColors.lightBlueAccent,
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            labelStyle: TextStyle(color: isSel ? Colors.white : Colors.white60, fontSize: 12),
                            onSelected: (val) {
                              if (val) {
                                setSheetState(() {
                                  selectedGroup = g;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Standard Details
                      ExpansionTile(
                        title: const Text('Primary Info', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        initiallyExpanded: true,
                        iconColor: AppColors.lightBlueAccent,
                        collapsedIconColor: Colors.white54,
                        childrenPadding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          _buildField(nameCtrl, 'Full Name', Icons.person_rounded, AppColors.lightBlueAccent),
                          const SizedBox(height: 12),
                          _buildField(nickCtrl, 'Nickname', Icons.face_rounded, AppColors.lightBlueAccent),
                          const SizedBox(height: 12),
                          _buildField(phoneCtrl, 'Primary Phone Number', Icons.phone_rounded, AppColors.lightBlueAccent, isPhone: true),
                          const SizedBox(height: 12),
                          _buildField(whatsCtrl, 'WhatsApp Number', Icons.chat_rounded, AppColors.lightBlueAccent, isPhone: true),
                          const SizedBox(height: 12),
                          _buildField(emailCtrl, 'Primary Email Address', Icons.email_rounded, AppColors.blueAccent),
                          const SizedBox(height: 12),
                          _buildField(photoCtrl, 'Profile Image Url / Base64', Icons.image_rounded, AppColors.lightBlueAccent),
                        ],
                      ),

                      // Professional Info
                      ExpansionTile(
                        title: const Text('Professional Info', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        iconColor: AppColors.lightBlueAccent,
                        collapsedIconColor: Colors.white54,
                        childrenPadding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          _buildField(companyCtrl, 'Company Name', Icons.business_rounded, AppColors.blueAccent),
                          const SizedBox(height: 12),
                          _buildField(jobCtrl, 'Job Title', Icons.work_rounded, AppColors.lightBlueAccent),
                          const SizedBox(height: 12),
                          _buildField(webCtrl, 'Website', Icons.language_rounded, AppColors.indigoAccent),
                        ],
                      ),

                      // Multiple Numbers & Emails
                      ExpansionTile(
                        title: const Text('Multiple Numbers & Emails', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        iconColor: AppColors.lightBlueAccent,
                        collapsedIconColor: Colors.white54,
                        childrenPadding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          _buildField(homePhoneCtrl, 'Home Phone', Icons.home_rounded, AppColors.lightBlueAccent),
                          const SizedBox(height: 12),
                          _buildField(workPhoneCtrl, 'Work Phone', Icons.phone_android_rounded, AppColors.lightBlueAccent),
                          const SizedBox(height: 12),
                          _buildField(mobilePhoneCtrl, 'Mobile Phone', Icons.smartphone_rounded, AppColors.lightBlueAccent),
                          const SizedBox(height: 16),
                          _buildField(homeEmailCtrl, 'Home Email', Icons.mail_outline_rounded, AppColors.royalBlue),
                          const SizedBox(height: 12),
                          _buildField(workEmailCtrl, 'Work Email', Icons.contact_mail_rounded, Colors.blueGrey),
                        ],
                      ),

                      // Social Links & Birthday
                      ExpansionTile(
                        title: const Text('Social Links & Birthday', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        iconColor: AppColors.lightBlueAccent,
                        collapsedIconColor: Colors.white54,
                        childrenPadding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          _buildField(instaCtrl, 'Instagram Link', Icons.camera_alt_rounded, AppColors.lightBlueAccent),
                          const SizedBox(height: 12),
                          _buildField(fbCtrl, 'Facebook Link', Icons.facebook_rounded, AppColors.primary),
                          const SizedBox(height: 12),
                          _buildField(linkedCtrl, 'LinkedIn Link', Icons.group_work_rounded, AppColors.lightBlueAccent),
                          const SizedBox(height: 12),
                          TextField(
                            controller: bdayCtrl,
                            readOnly: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Birthday (YYYY-MM-DD)',
                              labelStyle: const TextStyle(color: Colors.white60),
                              prefixIcon: const Icon(Icons.cake_rounded, color: Colors.redAccent),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_month_rounded, color: AppColors.lightBlueAccent),
                                onPressed: () async {
                                  final DateTime? pick = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime.now(),
                                  );
                                  if (pick != null) {
                                    bdayCtrl.text = DateFormat('yyyy-MM-dd').format(pick);
                                  }
                                },
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Colors.white24),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: AppColors.lightBlueAccent, width: 1.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Notes & Address
                      ExpansionTile(
                        title: const Text('Notes & Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        iconColor: AppColors.lightBlueAccent,
                        collapsedIconColor: Colors.white54,
                        childrenPadding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          _buildField(addressCtrl, 'Physical Address', Icons.location_on_rounded, Colors.redAccent),
                          const SizedBox(height: 12),
                          TextField(
                            controller: notesCtrl,
                            maxLines: 3,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Notes',
                              labelStyle: const TextStyle(color: Colors.white60),
                              prefixIcon: const Icon(Icons.note_alt_rounded, color: AppColors.lightBlueAccent),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Colors.white24),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: AppColors.lightBlueAccent, width: 1.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Actions
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
                                  _deleteContact(existing['_id']);
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
                                backgroundColor: AppColors.lightBlueAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                final name = nameCtrl.text.trim();
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('⚠️ Full Name is required'), backgroundColor: Colors.redAccent),
                                  );
                                  return;
                                }

                                Navigator.pop(ctx);

                                final socLinks = {
                                  'instagram': instaCtrl.text.trim(),
                                  'facebook': fbCtrl.text.trim(),
                                  'linkedin': linkedCtrl.text.trim(),
                                };

                                final multNums = {
                                  'home': homePhoneCtrl.text.trim(),
                                  'work': workPhoneCtrl.text.trim(),
                                  'mobile': mobilePhoneCtrl.text.trim(),
                                };

                                final multEms = {
                                  'home': homeEmailCtrl.text.trim(),
                                  'work': workEmailCtrl.text.trim(),
                                };

                                final contactPayload = {
                                  'fullName': name,
                                  'nickname': nickCtrl.text.trim(),
                                  'phoneNumber': phoneCtrl.text.trim(),
                                  'email': emailCtrl.text.trim(),
                                  'address': addressCtrl.text.trim(),
                                  'company': companyCtrl.text.trim(),
                                  'jobTitle': jobCtrl.text.trim(),
                                  'birthday': bdayCtrl.text.trim(),
                                  'profilePhoto': photoCtrl.text.trim(),
                                  'whatsAppNumber': whatsCtrl.text.trim(),
                                  'website': webCtrl.text.trim(),
                                  'notes': notesCtrl.text.trim(),
                                  'groupCategory': selectedGroup,
                                  'socialMediaLinks': jsonEncode(socLinks),
                                  'multipleNumbers': jsonEncode(multNums),
                                  'multipleEmails': jsonEncode(multEms),
                                };

                                if (isEdit) {
                                  _updateContact(existing['_id'], contactPayload);
                                } else {
                                  _createContact(contactPayload);
                                }
                              },
                              child: Text(
                                isEdit ? 'Update Contact' : 'Save Contact',
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

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, Color color, {bool isPhone = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: color),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.lightBlueAccent, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredContacts = _contacts.where((c) {
      final matchesGroup = _selectedGroupFilter == 'All' || c['groupCategory'] == _selectedGroupFilter;
      final matchesSearch = c['fullName']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
      return matchesGroup && matchesSearch;
    }).toList();

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
          '👤 Contact Directory',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: ['All', 'Family', 'Friends', 'Work', 'Other'].map((g) {
                  final isSel = _selectedGroupFilter == g;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$g (${_getGroupCount(g)})'),
                      selected: isSel,
                      selectedColor: AppColors.lightBlueAccent,
                      backgroundColor: const Color(0xFF1E1E1E),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : Colors.white60,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedGroupFilter = g;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
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
                hintText: 'Search contacts...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.lightBlueAccent),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                fillColor: const Color(0xFF1E1E1E),
                filled: true,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.lightBlueAccent, width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Contacts List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchContacts,
              color: AppColors.lightBlueAccent,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.lightBlueAccent))
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
                                  onPressed: _fetchContacts,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filteredContacts.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Container(
                                height: MediaQuery.of(context).size.height * 0.6,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.people_alt_rounded, size: 72, color: Colors.white.withValues(alpha: 0.08)),
                                    const SizedBox(height: 16),
                                    const Text('No contacts found', style: TextStyle(color: Colors.white54, fontSize: 15)),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filteredContacts.length,
                              itemBuilder: (ctx, idx) {
                                final c = filteredContacts[idx];
                                final name = c['fullName'] ?? '—';
                                final nick = c['nickname'] ?? '';
                                final primaryPhone = c['phoneNumber'] ?? '—';
                                final email = c['email'] ?? '—';
                                final address = c['address'] ?? '';
                                final company = c['company'] ?? '';
                                final job = c['jobTitle'] ?? '';
                                final bday = c['birthday'] ?? '';
                                final photo = c['profilePhoto'] ?? '';
                                final whatsApp = c['whatsAppNumber'] ?? '';
                                final web = c['website'] ?? '';
                                final notes = c['notes'] ?? '';
                                final grp = c['groupCategory'] ?? 'Other';

                                // Multi-fields decode
                                Map<String, dynamic> soc = {};
                                if (c['socialMediaLinks'] != null && c['socialMediaLinks'].toString().isNotEmpty) {
                                  try { soc = Map<String, dynamic>.from(jsonDecode(c['socialMediaLinks'])); } catch (_) {}
                                }
                                Map<String, dynamic> mNums = {};
                                if (c['multipleNumbers'] != null && c['multipleNumbers'].toString().isNotEmpty) {
                                  try { mNums = Map<String, dynamic>.from(jsonDecode(c['multipleNumbers'])); } catch (_) {}
                                }
                                Map<String, dynamic> mEms = {};
                                if (c['multipleEmails'] != null && c['multipleEmails'].toString().isNotEmpty) {
                                  try { mEms = Map<String, dynamic>.from(jsonDecode(c['multipleEmails'])); } catch (_) {}
                                }

                                final imageProvider = AppConfig.getImageProvider(photo.toString());

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E1E),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                                  ),
                                  child: ExpansionTile(
                                    leading: CircleAvatar(
                                      radius: 22,
                                      backgroundColor: AppColors.lightBlueAccent.withValues(alpha: 0.2),
                                      backgroundImage: imageProvider,
                                      child: imageProvider == null
                                          ? Text(
                                              name.toString().substring(0, 1).toUpperCase(),
                                              style: const TextStyle(color: AppColors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 16),
                                            )
                                          : null,
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.lightBlueAccent.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            grp,
                                            style: const TextStyle(color: AppColors.lightBlueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      nick.toString().isNotEmpty ? 'Nickname: $nick' : primaryPhone,
                                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                                    ),
                                    trailing: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white24),
                                    childrenPadding: const EdgeInsets.all(16),
                                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      const Divider(color: Colors.white12, height: 1),
                                      const SizedBox(height: 12),

                                      // Phone & Email Lists
                                      if (primaryPhone.toString().isNotEmpty)
                                        _buildInfoRow('Primary Phone', primaryPhone, Icons.phone_rounded, AppColors.lightBlueAccent),
                                      if (whatsApp.toString().isNotEmpty)
                                        _buildInfoRow('WhatsApp', whatsApp, Icons.chat_rounded, AppColors.lightBlueAccent),
                                      if (email.toString().isNotEmpty)
                                        _buildInfoRow('Primary Email', email, Icons.email_rounded, AppColors.blueAccent),

                                      // Multi Phone
                                      if (mNums['home']?.toString().isNotEmpty ?? false)
                                        _buildInfoRow('Home Phone', mNums['home'], Icons.home_rounded, AppColors.lightBlueAccent),
                                      if (mNums['work']?.toString().isNotEmpty ?? false)
                                        _buildInfoRow('Work Phone', mNums['work'], Icons.phone_android_rounded, AppColors.lightBlueAccent),
                                      if (mNums['mobile']?.toString().isNotEmpty ?? false)
                                        _buildInfoRow('Mobile Phone', mNums['mobile'], Icons.smartphone_rounded, AppColors.lightBlueAccent),

                                      // Multi Email
                                      if (mEms['home']?.toString().isNotEmpty ?? false)
                                        _buildInfoRow('Home Email', mEms['home'], Icons.mail_outline_rounded, AppColors.royalBlue),
                                      if (mEms['work']?.toString().isNotEmpty ?? false)
                                        _buildInfoRow('Work Email', mEms['work'], Icons.contact_mail_rounded, Colors.blueGrey),

                                      // Professional Info
                                      if (company.toString().isNotEmpty || job.toString().isNotEmpty)
                                        _buildInfoRow(
                                          'Work',
                                          '${job.toString().isNotEmpty ? job : ""} ${company.toString().isNotEmpty ? "@ $company" : ""}',
                                          Icons.business_rounded,
                                          AppColors.lightBlueAccent,
                                        ),

                                      // Website
                                      if (web.toString().isNotEmpty)
                                        _buildInfoRow('Website', web, Icons.language_rounded, AppColors.indigoAccent),

                                      // Birthday
                                      if (bday.toString().isNotEmpty)
                                        _buildInfoRow('Birthday', bday, Icons.cake_rounded, Colors.redAccent),

                                      // Address
                                      if (address.toString().isNotEmpty)
                                        _buildInfoRow('Address', address, Icons.location_on_rounded, Colors.redAccent),

                                      // Social Links
                                      if ((soc['instagram']?.toString().isNotEmpty ?? false) ||
                                          (soc['facebook']?.toString().isNotEmpty ?? false) ||
                                          (soc['linkedin']?.toString().isNotEmpty ?? false)) ...[
                                        const SizedBox(height: 8),
                                        const Text('Socials', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            if (soc['instagram']?.toString().isNotEmpty ?? false)
                                              _buildSocialChip('Instagram', AppColors.lightBlueAccent),
                                            if (soc['facebook']?.toString().isNotEmpty ?? false)
                                              _buildSocialChip('Facebook', AppColors.blueAccent),
                                            if (soc['linkedin']?.toString().isNotEmpty ?? false)
                                              _buildSocialChip('LinkedIn', AppColors.blueAccent),
                                          ],
                                        ),
                                      ],

                                      // Notes
                                      if (notes.toString().isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        const Text('Notes', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(notes, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                                      ],

                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            style: TextButton.styleFrom(foregroundColor: AppColors.lightBlueAccent),
                                            icon: const Icon(Icons.edit_rounded, size: 18),
                                            label: const Text('Edit Details', style: TextStyle(fontWeight: FontWeight.bold)),
                                            onPressed: () => _openFormSheet(existing: c),
                                          ),
                                        ],
                                      ),
                                    ],
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

  Widget _buildInfoRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, height: 1.4),
                children: [
                  TextSpan(text: '$label: ', style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontWeight: FontWeight.bold)),
                  TextSpan(text: value, style: TextStyle(color: Colors.white.withValues(alpha: 0.87))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
