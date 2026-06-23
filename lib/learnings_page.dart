import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'app_config.dart';
import 'app_drawer.dart';

class LearningsPage extends StatefulWidget {
  const LearningsPage({super.key});

  @override
  State<LearningsPage> createState() => _LearningsPageState();
}

class _LearningsPageState extends State<LearningsPage> {
  static const String _baseUrl = AppConfig.baseUrl;

  List<dynamic> _learnings = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchLearnings();
  }

  Future<void> _fetchLearnings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/learnings')).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        setState(() {
          _learnings = jsonDecode(res.body);
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

  Future<void> _createLearning(Map<String, dynamic> data) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/learnings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 201) {
        if (!mounted) return;
        showTopSnackBar(context, 
          const SnackBar(content: Text('📚 Topic added to learning path!'), backgroundColor: AppColors.lightBlueAccent),
        );
        _fetchLearnings();
      } else {
        throw Exception('Failed to add learning topic');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _updateLearning(String id, Map<String, dynamic> data) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/api/learnings/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        if (!mounted) return;
        showTopSnackBar(context, 
          const SnackBar(content: Text('📚 Topic updated successfully!'), backgroundColor: AppColors.lightBlueAccent),
        );
        _fetchLearnings();
      } else {
        throw Exception('Failed to update learning topic');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _deleteLearning(String id) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/api/learnings/$id')).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        if (!mounted) return;
        showTopSnackBar(context, 
          const SnackBar(content: Text('🗑️ Topic deleted from path'), backgroundColor: Colors.blueGrey),
        );
        _fetchLearnings();
      } else {
        throw Exception('Failed to delete learning topic');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _openFormSheet({dynamic existing}) {
    final isEdit = existing != null;

    final topicCtrl = TextEditingController(text: isEdit ? existing['learningTopic']?.toString() : '');
    final contentCtrl = TextEditingController(text: isEdit ? existing['content']?.toString() : '');

    // Parse links list
    List<String> linksList = [];
    if (isEdit && existing['links'] != null && existing['links'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(existing['links'].toString());
        if (decoded is List) {
          linksList = decoded.map((l) => l.toString()).toList();
        }
      } catch (_) {}
    }

    if (linksList.isEmpty) {
      linksList.add(''); // Start with one empty link field
    }

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
                            isEdit ? '📚 Edit Topic' : '📚 Add Learning Topic',
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

                      // Learning Topic
                      TextField(
                        controller: topicCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Learning Topic / Title',
                          labelStyle: const TextStyle(color: Colors.white60),
                          prefixIcon: const Icon(Icons.menu_book_rounded, color: AppColors.lightBlueAccent),
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
                      const SizedBox(height: 16),

                      // Content (Multi-line)
                      TextField(
                        controller: contentCtrl,
                        maxLines: 6,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Content / Notes',
                          alignLabelWithHint: true,
                          labelStyle: const TextStyle(color: Colors.white60),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 90),
                            child: Icon(Icons.article_rounded, color: AppColors.lightBlueAccent),
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
                      const SizedBox(height: 20),

                      // Links Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Reference Links',
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: AppColors.lightBlueAccent),
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                            label: const Text('Add Link', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              setSheetState(() {
                                linksList.add('');
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Dynamic Links Input List
                      ...List.generate(linksList.length, (idx) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: linksList[idx],
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  onChanged: (val) {
                                    linksList[idx] = val;
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'https://example.com/resource',
                                    hintStyle: const TextStyle(color: Colors.white24),
                                    prefixIcon: const Icon(Icons.link_rounded, color: AppColors.lightBlueAccent, size: 18),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Colors.white12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: AppColors.lightBlueAccent),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                onPressed: () {
                                  setSheetState(() {
                                    linksList.removeAt(idx);
                                    if (linksList.isEmpty) {
                                      linksList.add('');
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),

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
                                  _deleteLearning(existing['_id']);
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
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                final topic = topicCtrl.text.trim();
                                final content = contentCtrl.text.trim();
                                if (topic.isEmpty) {
                                  showTopSnackBar(context, 
                                    const SnackBar(content: Text('⚠️ Learning Topic is required'), backgroundColor: Colors.redAccent),
                                  );
                                  return;
                                }

                                Navigator.pop(ctx);

                                // Filter empty links
                                final validLinks = linksList.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

                                final payload = {
                                  'learningTopic': topic,
                                  'content': content,
                                  'links': jsonEncode(validLinks),
                                };

                                if (isEdit) {
                                  _updateLearning(existing['_id'], payload);
                                } else {
                                  _createLearning(payload);
                                }
                              },
                              child: Text(
                                isEdit ? 'Update Path' : 'Add to Path',
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
    final filteredLearnings = _learnings.where((l) {
      final matchesSearch = l['learningTopic']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
      return matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      drawer: const AppDrawer(activePage: 'learning'),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.lightBlueAccent, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          '📚 My Learning Space',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search topics & titles...',
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

          // Main list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchLearnings,
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
                                  onPressed: _fetchLearnings,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filteredLearnings.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Container(
                                height: MediaQuery.of(context).size.height * 0.6,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.local_library_rounded, size: 72, color: Colors.white.withValues(alpha: 0.08)),
                                    const SizedBox(height: 16),
                                    const Text('No learning topics added yet', style: TextStyle(color: Colors.white54, fontSize: 15)),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filteredLearnings.length,
                              itemBuilder: (ctx, idx) {
                                final l = filteredLearnings[idx];
                                final topic = l['learningTopic'] ?? 'Untitled Topic';
                                final content = l['content'] ?? '';
                                
                                List<String> links = [];
                                if (l['links'] != null && l['links'].toString().isNotEmpty) {
                                  try {
                                    final decoded = jsonDecode(l['links'].toString());
                                    if (decoded is List) {
                                      links = decoded.map((li) => li.toString()).toList();
                                    }
                                  } catch (_) {}
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E1E),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: ExpansionTile(
                                    iconColor: AppColors.lightBlueAccent,
                                    collapsedIconColor: Colors.white30,
                                    title: Text(
                                      topic,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    subtitle: const Text('Tap to view notes & resources', style: TextStyle(color: Colors.white30, fontSize: 12)),
                                    childrenPadding: const EdgeInsets.all(16),
                                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      const Divider(color: Colors.white12, height: 1),
                                      const SizedBox(height: 12),

                                      // Content Text
                                      if (content.toString().isNotEmpty) ...[
                                        const Text(
                                          'NOTES',
                                          style: TextStyle(color: AppColors.lightBlueAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          content,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.85),
                                            fontSize: 14,
                                            height: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],

                                      // Links
                                      if (links.isNotEmpty) ...[
                                        const Text(
                                          'RESOURCES & LINKS',
                                          style: TextStyle(color: AppColors.lightBlueAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: links.map((link) {
                                            return ActionChip(
                                              backgroundColor: AppColors.lightBlueAccent.withValues(alpha: 0.1),
                                              side: BorderSide(color: AppColors.lightBlueAccent.withValues(alpha: 0.2)),
                                              avatar: const Icon(Icons.link_rounded, size: 14, color: AppColors.lightBlueAccent),
                                              label: Text(
                                                link.length > 30 ? '${link.substring(0, 27)}...' : link,
                                                style: const TextStyle(color: AppColors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                              onPressed: () {
                                                Clipboard.setData(ClipboardData(text: link));
                                                showTopSnackBar(context, 
                                                  const SnackBar(
                                                    content: Text('📋 Link copied to clipboard!'),
                                                    backgroundColor: AppColors.lightBlueAccent,
                                                    duration: Duration(seconds: 2),
                                                  ),
                                                );
                                              },
                                            );
                                          }).toList(),
                                        ),
                                      ],

                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            style: TextButton.styleFrom(foregroundColor: AppColors.lightBlueAccent),
                                            icon: const Icon(Icons.edit_rounded, size: 18),
                                            label: const Text('Edit Details', style: TextStyle(fontWeight: FontWeight.bold)),
                                            onPressed: () => _openFormSheet(existing: l),
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
        foregroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _openFormSheet(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
