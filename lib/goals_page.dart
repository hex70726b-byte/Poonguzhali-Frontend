import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_config.dart';
import 'app_drawer.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  static const String _baseUrl = AppConfig.baseUrl;

  List<dynamic> _goals = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchGoals();
  }

  Future<void> _fetchGoals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/goals')).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        setState(() {
          _goals = jsonDecode(res.body);
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

  Future<void> _createGoal(String name, String type, String amount, String description) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/goals'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'goalName': name,
          'type': type,
          'amount': amount,
          'description': description,
        }),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎯 Goal created successfully!'), backgroundColor: AppColors.primary),
        );
        _fetchGoals();
      } else {
        throw Exception('Failed to create goal');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _updateGoal(String id, String name, String type, String amount, String description) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/api/goals/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'goalName': name,
          'type': type,
          'amount': amount,
          'description': description,
        }),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎯 Goal updated successfully!'), backgroundColor: AppColors.primary),
        );
        _fetchGoals();
      } else {
        throw Exception('Failed to update goal');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _deleteGoal(String id) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/api/goals/$id')).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Goal deleted successfully!'), backgroundColor: Colors.blueGrey),
        );
        _fetchGoals();
      } else {
        throw Exception('Failed to delete goal');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  int _getCount(String type) {
    return _goals.where((g) => g['type'] == type).length;
  }

  void _openFormSheet({dynamic existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: isEdit ? existing['goalName']?.toString() : '');
    final amtCtrl = TextEditingController(text: isEdit ? existing['amount']?.toString() : '');
    final descCtrl = TextEditingController(text: isEdit ? existing['description']?.toString() : '');
    String selectedType = isEdit ? (existing['type']?.toString() ?? 'general') : 'general';

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
                            isEdit ? '✏️ Edit Goal' : '🎯 Add Goal',
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

                      // Goal Name Input
                      TextField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Goal Name',
                          labelStyle: const TextStyle(color: Colors.white60),
                          prefixIcon: const Icon(Icons.stars_rounded, color: AppColors.lightBlueAccent),
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

                      // Goal Type (General, Money)
                      const Text(
                        'GOAL TYPE',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: ['general', 'money'].map((t) {
                          final isSelected = selectedType == t;
                          final themeColor = t == 'money' ? AppColors.blueAccent : AppColors.lightBlueAccent;
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
                                  right: t == 'general' ? 8.0 : 0.0,
                                  left: t == 'money' ? 8.0 : 0.0,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? themeColor.withValues(alpha: 0.15)
                                      : Colors.white.withValues(alpha: 0.04),
                                  border: Border.all(
                                    color: isSelected ? themeColor : Colors.white12,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      t == 'money'
                                          ? Icons.currency_rupee_rounded
                                          : Icons.assignment_turned_in_rounded,
                                      color: isSelected ? themeColor : Colors.white38,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      t == 'money' ? 'Money Goal' : 'General Goal',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.white54,
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
                      const SizedBox(height: 16),

                      // Money Goal Amount Input
                      if (selectedType == 'money') ...[
                        TextField(
                          controller: amtCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Target Amount (₹)',
                            labelStyle: const TextStyle(color: Colors.white60),
                            prefixIcon: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.blueAccent),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.white24),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppColors.blueAccent, width: 1.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Description
                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Description',
                          labelStyle: const TextStyle(color: Colors.white60),
                          prefixIcon: const Icon(Icons.description_outlined, color: Colors.white38),
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
                      const SizedBox(height: 24),

                      // Save/Delete Actions
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
                                  _deleteGoal(existing['_id']);
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
                                backgroundColor: selectedType == 'money' ? AppColors.blueAccent : AppColors.lightBlueAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                final name = nameCtrl.text.trim();
                                final amt = amtCtrl.text.trim();
                                final desc = descCtrl.text.trim();

                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('⚠️ Goal Name is required'), backgroundColor: Colors.redAccent),
                                  );
                                  return;
                                }

                                if (selectedType == 'money') {
                                  if (amt.isEmpty || double.tryParse(amt) == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('⚠️ Enter a valid target amount'), backgroundColor: Colors.redAccent),
                                    );
                                    return;
                                  }
                                }

                                Navigator.pop(ctx);

                                if (isEdit) {
                                  _updateGoal(existing['_id'], name, selectedType, amt, desc);
                                } else {
                                  _createGoal(name, selectedType, amt, desc);
                                }
                              },
                              child: Text(
                                isEdit ? 'Update Goal' : 'Save Goal',
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
    final filteredGoals = _goals.where((g) {
      final name = g['goalName']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      drawer: const AppDrawer(activePage: 'goals'),
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
          '🎯 Goal Tracker',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          // Dynamic Counters Header Grid
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
                      border: Border.all(color: AppColors.lightBlueAccent.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.assignment_turned_in_rounded, color: AppColors.lightBlueAccent, size: 18),
                            SizedBox(width: 6),
                            Text('General Goals', style: TextStyle(color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_getCount('general')}',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
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
                      border: Border.all(color: AppColors.blueAccent.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.currency_rupee_rounded, color: AppColors.blueAccent, size: 18),
                            SizedBox(width: 6),
                            Text('Money Goals', style: TextStyle(color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_getCount('money')}',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Input Bar
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
                hintText: 'Search goals...',
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

          // Goals List View
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchGoals,
              color: AppColors.lightBlueAccent,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.lightBlueAccent))
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
                                  onPressed: _fetchGoals,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filteredGoals.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Container(
                                height: MediaQuery.of(context).size.height * 0.5,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.emoji_events_rounded, size: 72, color: Colors.white.withValues(alpha: 0.08)),
                                    const SizedBox(height: 16),
                                    const Text('No goals setup yet', style: TextStyle(color: Colors.white54, fontSize: 15)),
                                    const SizedBox(height: 8),
                                    const Text('Tap + to set your first goal!', style: TextStyle(color: Colors.white30, fontSize: 12)),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filteredGoals.length,
                              itemBuilder: (ctx, idx) {
                                final g = filteredGoals[idx];
                                final name = g['goalName'] ?? '—';
                                final type = g['type'] ?? 'general';
                                final amountStr = g['amount'] ?? '0';
                                final savedAmountStr = g['savedAmount'] ?? '0';
                                final desc = g['description'] ?? '';
                                final isMoney = type == 'money';
                                final themeColor = isMoney ? AppColors.blueAccent : AppColors.lightBlueAccent;

                                return GestureDetector(
                                  onTap: () => _openFormSheet(existing: g),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E1E),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            // Leading Goal Type Icon
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: themeColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                isMoney ? Icons.currency_rupee_rounded : Icons.assignment_turned_in_rounded,
                                                color: themeColor,
                                                size: 22,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            // Goal Details
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    desc.isNotEmpty ? desc : 'No description',
                                                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Right-side value/type indicator
                                            if (isMoney) ...[
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '₹$amountStr',
                                                    style: TextStyle(
                                                      color: themeColor,
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  const Text(
                                                    'Target',
                                                    style: TextStyle(color: Colors.white30, fontSize: 9),
                                                  ),
                                                ],
                                              ),
                                            ] else ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.lightBlueAccent.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'General',
                                                  style: TextStyle(color: AppColors.lightBlueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (isMoney) ...[
                                          const SizedBox(height: 16),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  RichText(
                                                    text: TextSpan(
                                                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                                                      children: [
                                                        const TextSpan(text: 'Saved: '),
                                                        TextSpan(
                                                          text: '₹$savedAmountStr',
                                                          style: const TextStyle(color: AppColors.blueAccent, fontWeight: FontWeight.bold),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Text(
                                                    '${((double.tryParse(savedAmountStr) ?? 0.0) / (double.tryParse(amountStr) ?? 1.0) * 100).clamp(0.0, 100.0).toStringAsFixed(1)}%',
                                                    style: const TextStyle(
                                                      color: AppColors.blueAccent,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: ((double.tryParse(savedAmountStr) ?? 0.0) / (double.tryParse(amountStr) ?? 1.0)).clamp(0.0, 1.0),
                                                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.blueAccent),
                                                  minHeight: 6,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
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
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _openFormSheet(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
