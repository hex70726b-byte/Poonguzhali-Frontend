import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'app_config.dart';

class DebtsPage extends StatefulWidget {
  const DebtsPage({super.key});

  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  static const String _baseUrl = AppConfig.baseUrl;

  List<dynamic> _debts = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchDebts();
  }

  Future<void> _fetchDebts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/debt')).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        setState(() {
          _debts = jsonDecode(res.body);
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

  Future<void> _createDebt(String person, String amount, String dueDate) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/debt'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'debtHolderName': person,
          'debtAmount': amount,
          'dueDate': dueDate,
        }),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Debt record created successfully!'), backgroundColor: Colors.lightBlue),
        );
        _fetchDebts();
      } else {
        throw Exception('Failed to create debt');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _updateDebt(String id, String person, String amount, String dueDate) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/api/debt/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'debtHolderName': person,
          'debtAmount': amount,
          'dueDate': dueDate,
        }),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Debt record updated successfully!'), backgroundColor: Colors.lightBlue),
        );
        _fetchDebts();
      } else {
        throw Exception('Failed to update debt');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _deleteDebt(String id) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/api/debt/$id')).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Debt record deleted!'), backgroundColor: Colors.blueGrey),
        );
        _fetchDebts();
      } else {
        throw Exception('Failed to delete debt');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  double _totalDebtAmount() {
    double total = 0.0;
    for (var d in _debts) {
      final amt = double.tryParse(d['debtAmount']?.toString() ?? '0') ?? 0.0;
      total += amt;
    }
    return total;
  }

  void _openFormSheet({dynamic existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: isEdit ? existing['debtHolderName']?.toString() : '');
    final amtCtrl = TextEditingController(text: isEdit ? existing['debtAmount']?.toString() : '');
    DateTime? selectedDate;
    
    if (isEdit && existing['dueDate'] != null && existing['dueDate'].toString().isNotEmpty) {
      try {
        selectedDate = DateFormat('dd MMM yyyy').parse(existing['dueDate']);
      } catch (_) {
        selectedDate = DateTime.tryParse(existing['dueDate']);
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final dateText = selectedDate != null
                ? DateFormat('dd MMM yyyy').format(selectedDate!)
                : 'Select Due Date';

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
                          isEdit ? '✏️️ Edit Debt' : '➕ Add Debt Record',
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
                        labelText: 'Debt Person Name',
                        labelStyle: const TextStyle(color: Colors.white60),
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.lightBlueAccent),
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
                    TextField(
                      controller: amtCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Amount (₹)',
                        labelStyle: const TextStyle(color: Colors.white60),
                        prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Colors.lightBlueAccent),
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
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Colors.lightBlueAccent,
                                  onPrimary: Colors.black,
                                  surface: Color(0xFF121212),
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setSheetState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: Colors.lightBlueAccent),
                            const SizedBox(width: 12),
                            Text(
                              dateText,
                              style: TextStyle(
                                color: selectedDate != null ? Colors.white : Colors.white60,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (isEdit) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent.withOpacity(0.15),
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _deleteDebt(existing['_id']);
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
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              final name = nameCtrl.text.trim();
                              final amt = amtCtrl.text.trim();
                              
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('⚠️ Name is required'), backgroundColor: Colors.redAccent),
                                );
                                return;
                              }
                              if (amt.isEmpty || double.tryParse(amt) == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('⚠️ Enter a valid amount'), backgroundColor: Colors.redAccent),
                                );
                                return;
                              }
                              if (selectedDate == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('⚠️ Please select a due date'), backgroundColor: Colors.redAccent),
                                );
                                return;
                              }

                              final formattedDate = DateFormat('dd MMM yyyy').format(selectedDate!);
                              Navigator.pop(ctx);

                              if (isEdit) {
                                _updateDebt(existing['_id'], name, amt, formattedDate);
                              } else {
                                _createDebt(name, amt, formattedDate);
                              }
                            },
                            child: Text(
                              isEdit ? 'Update Details' : 'Save Record',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ),
                      ],
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

  Color _getDueDateColor(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return Colors.white38;
    try {
      final date = DateFormat('dd MMM yyyy').parse(dateStr);
      final now = DateTime.now();
      final diff = date.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (diff < 0) {
        return Colors.redAccent;
      } else if (diff <= 3) {
        return Colors.lightBlueAccent;
      } else {
        return Colors.lightBlueAccent;
      }
    } catch (_) {
      return Colors.white38;
    }
  }

  String _getDueDateStatusText(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateFormat('dd MMM yyyy').parse(dateStr);
      final now = DateTime.now();
      final diff = date.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (diff < 0) {
        return 'Overdue by ${diff.abs()} days';
      } else if (diff == 0) {
        return 'Due today';
      } else if (diff == 1) {
        return 'Due tomorrow';
      } else {
        return 'Due in $diff days';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredDebts = _debts.where((d) {
      final name = d['debtHolderName']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
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
          '💸 Debt Manager',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          // Elegant Header Summary Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.lightBlueAccent.withOpacity(0.15),
                  Colors.blueAccent.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.lightBlueAccent.withOpacity(0.2),
                  child: const Icon(Icons.trending_down_rounded, color: Colors.lightBlueAccent, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Outstanding Debt',
                        style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '₹${_totalDebtAmount().toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_debts.length} Active',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
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
                hintText: 'Search debt person...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.lightBlueAccent),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                fillColor: const Color(0xFF1E1E1E),
                filled: true,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
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

          // Debt Records List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchDebts,
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
                                  onPressed: _fetchDebts,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filteredDebts.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Container(
                                height: MediaQuery.of(context).size.height * 0.5,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.money_off_rounded, size: 72, color: Colors.white.withOpacity(0.08)),
                                    const SizedBox(height: 16),
                                    const Text('No debt records found', style: TextStyle(color: Colors.white54, fontSize: 15)),
                                    const SizedBox(height: 8),
                                    const Text('Tap + to create a new record', style: TextStyle(color: Colors.white30, fontSize: 12)),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filteredDebts.length,
                              itemBuilder: (ctx, idx) {
                                final d = filteredDebts[idx];
                                final name = d['debtHolderName'] ?? '—';
                                final amt = d['debtAmount'] ?? '0';
                                final dateStr = d['dueDate'] ?? '';
                                final dateColor = _getDueDateColor(dateStr);
                                final statusText = _getDueDateStatusText(dateStr);

                                return GestureDetector(
                                  onTap: () => _openFormSheet(existing: d),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E1E),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: dateColor.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(Icons.trending_down_rounded, color: dateColor, size: 22),
                                        ),
                                        const SizedBox(width: 14),
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
                                              Row(
                                                children: [
                                                  const Icon(Icons.calendar_month_rounded, color: Colors.white38, size: 12),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Due: $dateStr',
                                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                                  ),
                                                  if (statusText.isNotEmpty) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: dateColor.withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        statusText,
                                                        style: TextStyle(color: dateColor, fontSize: 10, fontWeight: FontWeight.w600),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '₹$amt',
                                          style: TextStyle(
                                            color: dateColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
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
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _openFormSheet(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
