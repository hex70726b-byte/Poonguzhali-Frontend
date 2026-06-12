import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'app_config.dart';

class DiariesPage extends StatefulWidget {
  const DiariesPage({super.key});

  @override
  State<DiariesPage> createState() => _DiariesPageState();
}

class _DiariesPageState extends State<DiariesPage> {
  static const String _baseUrl = AppConfig.baseUrl;

  List<dynamic> _diaries = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchDiaries();
  }

  Future<void> _fetchDiaries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/diaries')).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        setState(() {
          _diaries = jsonDecode(res.body);
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

  Future<void> _createDiary({
    required String date,
    required String day,
    required String diaryContent,
  }) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/diaries'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'date': date,
          'day': day,
          'diary': diaryContent,
        }),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📖 Diary entry saved!'), backgroundColor: Colors.lightBlue),
        );
        _fetchDiaries();
      } else {
        throw Exception('Failed to save entry');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _updateDiary({
    required String id,
    required String date,
    required String day,
    required String diaryContent,
  }) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/api/diaries/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'date': date,
          'day': day,
          'diary': diaryContent,
        }),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📖 Diary entry updated successfully!'), backgroundColor: Colors.lightBlue),
        );
        _fetchDiaries();
      } else {
        throw Exception('Failed to update entry');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _deleteDiary(String id) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/api/diaries/$id')).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Diary entry deleted!'), backgroundColor: Colors.blueGrey),
        );
        _fetchDiaries();
      } else {
        throw Exception('Failed to delete entry');
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
    final diaryCtrl = TextEditingController(text: isEdit ? existing['diary']?.toString() : '');

    DateTime selectedDate = isEdit && existing['date'] != null
        ? (DateTime.tryParse(existing['date'].toString()) ?? DateTime.now())
        : DateTime.now();

    String currentDay = DateFormat('EEEE').format(selectedDate); // e.g. Thursday

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
                            isEdit ? '📖 Edit Diary' : '📖 Add Diary Entry',
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

                      // Date & Day display picker
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setSheetState(() {
                                    selectedDate = picked;
                                    currentDay = DateFormat('EEEE').format(picked);
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_month_rounded, color: Colors.lightBlueAccent),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'DATE',
                                          style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat('yyyy-MM-dd').format(selectedDate),
                                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.today_rounded, color: Colors.lightBlueAccent),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'DAY',
                                        style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        currentDay,
                                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Diary Paragraph Text Input
                      TextField(
                        controller: diaryCtrl,
                        maxLines: 8,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                        decoration: InputDecoration(
                          labelText: 'How was your day? Write here...',
                          alignLabelWithHint: true,
                          labelStyle: const TextStyle(color: Colors.white54),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white24),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 1.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save/Delete Buttons
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
                                  _deleteDiary(existing['_id']);
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
                                backgroundColor: Colors.lightBlueAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                final text = diaryCtrl.text.trim();
                                final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

                                if (text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('⚠️ Diary content cannot be empty'), backgroundColor: Colors.redAccent),
                                  );
                                  return;
                                }

                                Navigator.pop(ctx);

                                if (isEdit) {
                                  _updateDiary(
                                    id: existing['_id'],
                                    date: dateStr,
                                    day: currentDay,
                                    diaryContent: text,
                                  );
                                } else {
                                  _createDiary(
                                    date: dateStr,
                                    day: currentDay,
                                    diaryContent: text,
                                  );
                                }
                              },
                              child: Text(
                                isEdit ? 'Update Entry' : 'Save Entry',
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
    final filteredDiaries = _diaries.where((d) {
      final text = d['diary']?.toString().toLowerCase() ?? '';
      final day = d['day']?.toString().toLowerCase() ?? '';
      final date = d['date']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return text.contains(query) || day.contains(query) || date.contains(query);
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
          '📖 Personal Diary',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          // Elegant Header Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.lightBlueAccent.withValues(alpha: 0.15), Colors.lightBlueAccent.withValues(alpha: 0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.lightBlueAccent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Colors.lightBlueAccent, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Sacred Space',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_diaries.length} stories recorded in your journey',
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
                hintText: 'Search memories by word, day, or date...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.lightBlueAccent),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                fillColor: const Color(0xFF1E1E1E),
                filled: true,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Memories List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchDiaries,
              color: Colors.lightBlueAccent,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.lightBlueAccent))
                  : _errorMessage != null
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.5,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                                const SizedBox(height: 12),
                                Text(_errorMessage!, style: const TextStyle(color: Colors.white70)),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _fetchDiaries,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filteredDiaries.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Container(
                                height: MediaQuery.of(context).size.height * 0.5,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.import_contacts_rounded, size: 72, color: Colors.white.withValues(alpha: 0.08)),
                                    const SizedBox(height: 16),
                                    const Text('No memories captured yet', style: TextStyle(color: Colors.white54, fontSize: 15)),
                                    const SizedBox(height: 8),
                                    const Text('Tap + to write down your day!', style: TextStyle(color: Colors.white30, fontSize: 12)),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filteredDiaries.length,
                              itemBuilder: (ctx, idx) {
                                final d = filteredDiaries[idx];
                                final date = d['date'] ?? '—';
                                final day = d['day'] ?? '—';
                                final text = d['diary'] ?? '';

                                // Format date string for displaying in user-friendly mode e.g. "May 28, 2026"
                                String formattedDisplayDate = date;
                                try {
                                  final parsed = DateTime.parse(date);
                                  formattedDisplayDate = DateFormat('MMMM dd, yyyy').format(parsed);
                                } catch (_) {}

                                return GestureDetector(
                                  onTap: () => _openFormSheet(existing: d),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E1E),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Date & Day Card Header
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.bookmark_rounded, color: Colors.lightBlueAccent, size: 18),
                                                const SizedBox(width: 6),
                                                Text(
                                                  formattedDisplayDate,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.lightBlueAccent.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                day,
                                                style: const TextStyle(
                                                  color: Colors.lightBlueAccent,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                          child: Divider(color: Colors.white10, height: 1),
                                        ),
                                        // Diary content paragraph
                                        Text(
                                          text,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.85),
                                            fontSize: 14,
                                            height: 1.5,
                                          ),
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
