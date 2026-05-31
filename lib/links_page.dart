import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'app_config.dart';

class DocumentLinkItem {
  final String id;
  final String name;
  final String url;
  final DateTime createdAt;

  DocumentLinkItem({
    required this.id,
    required this.name,
    required this.url,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DocumentLinkItem.fromJson(Map<String, dynamic> json) => DocumentLinkItem(
        id: json['id']?.toString() ?? '',
        name: json['name'] ?? '',
        url: json['url'] ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
            : DateTime.now(),
      );
}

class DocumentFolder {
  final String id;
  final String name;
  final List<DocumentLinkItem> links;
  final int colorValue;

  DocumentFolder({
    required this.id,
    required this.name,
    required this.links,
    required this.colorValue,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'links': links.map((e) => e.toJson()).toList(),
        'colorValue': colorValue,
      };

  factory DocumentFolder.fromJson(Map<String, dynamic> json) {
    final list = json['links'] as List? ?? [];
    return DocumentFolder(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      links: list.map((e) => DocumentLinkItem.fromJson(e)).toList(),
      colorValue: json['colorValue'] ?? AppColors.skyBlue.value,
    );
  }
}

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  List<DocumentFolder> _folders = [];
  bool _isLoading = true;
  String _searchQuery = '';

  final List<Color> _folderColors = [
    AppColors.skyBlue,
    const Color(0xFF2ECC71),
    Colors.purpleAccent,
    Colors.orangeAccent,
    Colors.pinkAccent,
    Colors.amber,
    Colors.cyanAccent,
  ];

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  // Load folders from Backend with local offline fallback cache
  Future<void> _loadFolders() async {
    setState(() => _isLoading = true);

    // 1. Try to fetch from Backend MongoDB API
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.baseUrl}/api/documents'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body);
        final fetched = decoded.map((item) => DocumentFolder.fromJson(item)).toList();
        
        setState(() {
          _folders = fetched;
          _isLoading = false;
        });

        // Update local SharedPreferences Cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_link_folders', jsonEncode(decoded));
        return;
      }
    } catch (e) {
      debugPrint("Backend documents load failed, falling back to local cache: $e");
    }

    // 2. Offline Fallback to Local Cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString('saved_link_folders');
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        setState(() {
          _folders = decoded.map((item) => DocumentFolder.fromJson(item)).toList();
          _isLoading = false;
        });
        _showSnackBar("⚡ Offline Mode: Loaded from local vault cache", Colors.blueGrey);
      } else {
        // Prepopulate with a default "Scheme" folder containing actual TN/National scheme links
        final defaultFolder = DocumentFolder(
          id: 'default_scheme_folder',
          name: 'Scheme',
          colorValue: AppColors.skyBlue.value,
          links: [
            DocumentLinkItem(
              id: 'scheme_1',
              name: 'Tamil Nadu Government Schemes Portal',
              url: 'https://www.tn.gov.in/schemes',
              createdAt: DateTime.now(),
            ),
            DocumentLinkItem(
              id: 'scheme_2',
              name: 'National Government Services Portal',
              url: 'https://services.india.gov.in/',
              createdAt: DateTime.now(),
            ),
            DocumentLinkItem(
              id: 'scheme_3',
              name: 'Pudhumai Penn Scheme TN',
              url: 'https://penkalvi.tn.gov.in/',
              createdAt: DateTime.now(),
            ),
          ],
        );
        setState(() {
          _folders = [defaultFolder];
          _isLoading = false;
        });
        await prefs.setString(
            'saved_link_folders', jsonEncode([defaultFolder.toJson()]));
      }
    } catch (e) {
      print("Error loading folders fallback: $e");
      setState(() => _isLoading = false);
    }
  }

  // Save folders to local cache and sync instantly with backend
  Future<void> _saveFolders() async {
    // 1. Instant local persistence
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'saved_link_folders', jsonEncode(_folders.map((e) => e.toJson()).toList()));
    } catch (e) {
      print("Error saving local cache: $e");
    }

    // 2. Cloud synchronization with Backend MongoDB
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/documents/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_folders.map((e) => e.toJson()).toList()),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        _showSnackBar("📄 Documents synced to cloud vault!", AppColors.skyBlue);
      } else {
        _showSnackBar("📄 Saved locally (Cloud sync pending)", Colors.blueGrey);
      }
    } catch (_) {
      _showSnackBar("📄 Saved locally (Cloud sync pending)", Colors.blueGrey);
    }
  }

  void _showSnackBar(String text, Color bgColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Launch URL safely in browser
  Future<void> _launchURL(String urlString, BuildContext context) async {
    var cleanUrl = urlString.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }

    final Uri uri = Uri.parse(cleanUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⚠️ Could not open link: $cleanUrl"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Show Bottom Sheet to Add/Edit Folder
  void _openFolderSheet({DocumentFolder? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: isEdit ? existing.name : '');
    int selectedColorValue = isEdit ? existing.colorValue : _folderColors.first.value;

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
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit ? '✏️ Edit Folder' : '📁 Create New Folder',
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
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Folder Name (e.g. Scheme, Study, Entertainment)',
                        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                        prefixIcon: const Icon(Icons.folder_rounded, color: AppColors.skyBlue),
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
                    const SizedBox(height: 20),
                    const Text(
                      "Choose Folder Theme Color:",
                      style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _folderColors.length,
                        itemBuilder: (context, index) {
                          final color = _folderColors[index];
                          final isSelected = selectedColorValue == color.value;
                          return GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                selectedColorValue = color.value;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.5),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.skyBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('⚠️ Folder name cannot be empty!'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(ctx);

                        if (isEdit) {
                          final index = _folders.indexWhere((f) => f.id == existing.id);
                          if (index != -1) {
                            setState(() {
                              _folders[index] = DocumentFolder(
                                id: existing.id,
                                name: name,
                                links: existing.links,
                                colorValue: selectedColorValue,
                              );
                            });
                          }
                        } else {
                          setState(() {
                            _folders.add(DocumentFolder(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              name: name,
                              links: [],
                              colorValue: selectedColorValue,
                            ));
                          });
                        }
                        _saveFolders();
                      },
                      child: Text(
                        isEdit ? 'Update Folder' : 'Create Folder',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Delete a Folder with Confirmation
  void _deleteFolder(DocumentFolder folder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text("Delete Folder?", style: TextStyle(color: Colors.white)),
        content: Text(
          "Are you sure you want to delete '${folder.name}' folder? All its links will be permanently deleted.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _folders.removeWhere((f) => f.id == folder.id);
              });
              _saveFolders();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredFolders = _folders.where((f) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return f.name.toLowerCase().contains(q) ||
          f.links.any((l) =>
              l.name.toLowerCase().contains(q) || l.url.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.skyBlue, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '📄 Documents Vault',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // Stat/Welcome Banner Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.skyBlue.withValues(alpha: 0.15),
                    AppColors.skyBlue.withValues(alpha: 0.05)
                  ],
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
                    child: const Icon(Icons.assignment_rounded, color: AppColors.skyBlue, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Secure Documents Vault',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Organize your schemes and essential bookmarks in customizable folders.',
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
                hintText: 'Search folders or documents...',
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

          const SizedBox(height: 16),

          // Folders Grid List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.skyBlue))
                : filteredFolders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_off_rounded, color: Colors.white38, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'No folders or documents found!',
                              style: TextStyle(color: Colors.white38, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: filteredFolders.length,
                        itemBuilder: (context, index) {
                          final folder = filteredFolders[index];
                          final themeColor = Color(folder.colorValue);
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FolderDetailsPage(
                                    folder: folder,
                                    onFolderUpdated: (updatedFolder) {
                                      setState(() {
                                        final idx = _folders.indexWhere((f) => f.id == updatedFolder.id);
                                        if (idx != -1) {
                                          _folders[idx] = updatedFolder;
                                        }
                                      });
                                      _saveFolders();
                                    },
                                    launchURL: _launchURL,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceCard,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: themeColor.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: themeColor.withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.folder_open_rounded,
                                            color: themeColor,
                                            size: 26,
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              folder.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "${folder.links.length} Docs Saved",
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white60, size: 20),
                                      color: const Color(0xFF1E1E1E),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          _openFolderSheet(existing: folder);
                                        } else if (val == 'delete') {
                                          _deleteFolder(folder);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_rounded, color: AppColors.skyBlue, size: 18),
                                              SizedBox(width: 8),
                                              Text("Edit", style: TextStyle(color: Colors.white)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_rounded, color: Colors.redAccent, size: 18),
                                              SizedBox(width: 8),
                                              Text("Delete", style: TextStyle(color: Colors.white)),
                                            ],
                                          ),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.skyBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _openFolderSheet(),
        child: const Icon(Icons.create_new_folder_rounded, size: 28),
      ),
    );
  }
}

class FolderDetailsPage extends StatefulWidget {
  final DocumentFolder folder;
  final ValueChanged<DocumentFolder> onFolderUpdated;
  final Future<void> Function(String url, BuildContext context) launchURL;

  const FolderDetailsPage({
    super.key,
    required this.folder,
    required this.onFolderUpdated,
    required this.launchURL,
  });

  @override
  State<FolderDetailsPage> createState() => _FolderDetailsPageState();
}

class _FolderDetailsPageState extends State<FolderDetailsPage> {
  late DocumentFolder _folder;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _folder = widget.folder;
  }

  // Show Bottom Sheet to Add/Edit Link inside Folder
  void _openLinkSheet({DocumentLinkItem? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: isEdit ? existing.name : '');
    final urlCtrl = TextEditingController(text: isEdit ? existing.url : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
                    Text(
                      isEdit ? '✏️ Edit Document' : '📄 Add New Document',
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
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Document Name (e.g. TN Govt Scheme Portal)',
                    labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                    prefixIcon: const Icon(Icons.label_outline_rounded, color: AppColors.skyBlue),
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
                  controller: urlCtrl,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'URL (e.g. tn.gov.in or https://...)',
                    labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                    prefixIcon: const Icon(Icons.link_rounded, color: AppColors.skyBlue),
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
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    var url = urlCtrl.text.trim();

                    if (name.isEmpty || url.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ Name and URL cannot be empty!'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    if (!url.startsWith('http://') && !url.startsWith('https://')) {
                      url = 'https://$url';
                    }

                    Navigator.pop(ctx);

                    final updatedLinks = List<DocumentLinkItem>.from(_folder.links);
                    if (isEdit) {
                      final idx = updatedLinks.indexWhere((l) => l.id == existing.id);
                      if (idx != -1) {
                        updatedLinks[idx] = DocumentLinkItem(
                          id: existing.id,
                          name: name,
                          url: url,
                          createdAt: existing.createdAt,
                        );
                      }
                    } else {
                      updatedLinks.add(DocumentLinkItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: name,
                        url: url,
                        createdAt: DateTime.now(),
                      ));
                    }

                    final updatedFolder = DocumentFolder(
                      id: _folder.id,
                      name: _folder.name,
                      colorValue: _folder.colorValue,
                      links: updatedLinks,
                    );

                    setState(() {
                      _folder = updatedFolder;
                    });
                    widget.onFolderUpdated(updatedFolder);
                  },
                  child: Text(
                    isEdit ? 'Update Document' : 'Add Document',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Delete a specific link
  void _deleteLink(DocumentLinkItem link) {
    final updatedLinks = List<DocumentLinkItem>.from(_folder.links)..removeWhere((l) => l.id == link.id);
    final updatedFolder = DocumentFolder(
      id: _folder.id,
      name: _folder.name,
      colorValue: _folder.colorValue,
      links: updatedLinks,
    );

    setState(() {
      _folder = updatedFolder;
    });
    widget.onFolderUpdated(updatedFolder);
  }

  @override
  Widget build(BuildContext context) {
    final filteredLinks = _folder.links.where((l) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return l.name.toLowerCase().contains(q) || l.url.toLowerCase().contains(q);
    }).toList();

    final themeColor = Color(_folder.colorValue);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.skyBlue, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _folder.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // Search box within folder links
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _query = val;
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search documents inside ${_folder.name}...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: Icon(Icons.search_rounded, color: themeColor),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                fillColor: const Color(0xFF1E1E1E),
                filled: true,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: themeColor, width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          Expanded(
            child: filteredLinks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_rounded, color: Colors.white24, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'No documents inside this folder!',
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredLinks.length,
                    itemBuilder: (context, index) {
                      final link = filteredLinks[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: themeColor.withValues(alpha: 0.15),
                            child: Icon(Icons.description_rounded, color: themeColor, size: 22),
                          ),
                          title: Text(
                            link.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              link.url,
                              style: TextStyle(
                                color: themeColor.withValues(alpha: 0.7),
                                fontSize: 12,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, color: Colors.white60, size: 20),
                            color: const Color(0xFF1E1E1E),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            onSelected: (val) {
                              if (val == 'edit') {
                                _openLinkSheet(existing: link);
                              } else if (val == 'delete') {
                                _deleteLink(link);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_rounded, color: AppColors.skyBlue, size: 18),
                                    SizedBox(width: 8),
                                    Text("Edit", style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_rounded, color: Colors.redAccent, size: 18),
                                    SizedBox(width: 8),
                                    Text("Delete", style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          onTap: () => widget.launchURL(link.url, context),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _openLinkSheet(),
        child: const Icon(Icons.add_task_rounded, size: 28),
      ),
    );
  }
}
