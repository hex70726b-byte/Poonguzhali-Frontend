import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'app_config.dart';
import 'profile_page.dart';
import 'debts_page.dart';
import 'goals_page.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage>
    with SingleTickerProviderStateMixin {
  static const String _baseUrl = AppConfig.baseUrl;
  static const MethodChannel _smsChannel = MethodChannel('sms_reader_channel');

  List<dynamic> _transactions = [];
  List<dynamic> _accounts = [];
  List<dynamic> _members = [];
  List<dynamic> _debts = [];
  List<dynamic> _goals = [];
  List<dynamic> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        http.get(Uri.parse('$_baseUrl/api/transactions')).timeout(const Duration(seconds: 6)),
        http.get(Uri.parse('$_baseUrl/api/accounts')).timeout(const Duration(seconds: 6)),
        http.get(Uri.parse('$_baseUrl/api/accountsMembers')).timeout(const Duration(seconds: 6)),
        http.get(Uri.parse('$_baseUrl/api/debt')).timeout(const Duration(seconds: 6)),
        http.get(Uri.parse('$_baseUrl/api/goals')).timeout(const Duration(seconds: 6)),
        http.get(Uri.parse('$_baseUrl/api/categories')).timeout(const Duration(seconds: 6)),
      ]);
      if (results[0].statusCode == 200 &&
          results[1].statusCode == 200 &&
          results[2].statusCode == 200 &&
          results[3].statusCode == 200 &&
          results[4].statusCode == 200 &&
          results[5].statusCode == 200) {
        setState(() {
          _transactions = jsonDecode(results[0].body);
          _accounts = jsonDecode(results[1].body);
          _members = jsonDecode(results[2].body);
          _debts = jsonDecode(results[3].body);
          _goals = jsonDecode(results[4].body);
          _categories = jsonDecode(results[5].body);
          _isLoading = false;
        });
      } else {
        throw Exception('Server error');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Connection failed: $e';
      });
    }
  }

  String _accountName(String? id) {
    if (id == null) return '—';
    final acc = _accounts.firstWhere(
      (a) => a['_id'] == id,
      orElse: () => null,
    );
    return acc != null ? acc['accountName'] ?? '—' : '—';
  }

  List<dynamic> _filtered(String type) =>
      _transactions.where((t) => t['type'] == type).toList();

  void _showAddSheet() {
    _openFormSheet(existing: null);
  }

  void _showEditSheet(dynamic tx) {
    _openFormSheet(existing: tx);
  }

  Future<void> _delete(String id) async {
    setState(() => _isLoading = true);
    try {
      final res = await http
          .delete(Uri.parse('$_baseUrl/api/transactions/$id'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🗑️ Transaction deleted'), backgroundColor: Colors.blueGrey),
          );
        }
        _fetchAll();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _extractAmount(String body) {
    final reg = RegExp(r'(?:Rs\.?|INR)\s*([0-9,]+(?:\.[0-9]{2})?)', caseSensitive: false);
    final match = reg.firstMatch(body);
    if (match != null) {
      return match.group(1) ?? '';
    }
    return '';
  }

  Future<void> _scanSmsAndShowPopup() async {
    try {
      final isGranted = await _smsChannel.invokeMethod<bool>('checkSmsPermission') ?? false;
      if (!isGranted) {
        final result = await _smsChannel.invokeMethod<String>('requestSmsPermission');
        if (result != 'granted') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ SMS permission access denied!'),
                backgroundColor: Colors.blueAccent,
              ),
            );
          }
          return;
        }
      }

      final fetchedList = await _smsChannel.invokeMethod<List<dynamic>>('readBankSms').then((val) => val ?? []);
      if (!mounted) return;

      if (fetchedList.isEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('🏦 SMS Scan Complete', style: TextStyle(color: Colors.white)),
            content: const Text(
              'Unga inbox la entha puthu transaction SMS-um illa da chellam! Ellame scan panni mudiyachu.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Ok', style: TextStyle(color: Colors.lightBlueAccent)),
              ),
            ],
          ),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black87,
        builder: (ctx) {
          List<dynamic> smsList = List.from(fetchedList);

          return StatefulBuilder(
            builder: (ctx2, setSheetState) {
              return DraggableScrollableSheet(
                initialChildSize: 0.8,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                builder: (_, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF151515),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                      boxShadow: [
                        BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -5)),
                      ],
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.lightBlueAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.lightBlueAccent, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '🏦 Scan New Bank SMS',
                                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Scanned ${smsList.length} unprocessed transaction alerts',
                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(ctx),
                                icon: const Icon(Icons.close_rounded, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white10, height: 1),
                        Expanded(
                          child: smsList.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.done_all_rounded, size: 64, color: Colors.lightBlueAccent),
                                      SizedBox(height: 16),
                                      Text(
                                        'All Messages Processed',
                                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Ella SMS record-um add/dismiss panni mudichutinga da thambi!',
                                        style: TextStyle(color: Colors.white38, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  itemCount: smsList.length,
                                  itemBuilder: (context, index) {
                                    final sms = Map<String, dynamic>.from(smsList[index]);
                                    final sender = sms['sender'] ?? 'Unknown Sender';
                                    final body = sms['body'] ?? '';
                                    final dateMs = sms['date'] as int? ?? 0;
                                    final type = sms['type'] ?? 'general';
                                    
                                    final date = DateTime.fromMillisecondsSinceEpoch(dateMs);
                                    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
                                    
                                    final isDebit = type == 'debit';
                                    final isCredit = type == 'credit';
                                    final amount = _extractAmount(body);
                                    
                                    final accentColor = isDebit
                                        ? Colors.blueAccent
                                        : (isCredit ? Colors.lightBlueAccent : Colors.lightBlueAccent);

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E1E1E),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: accentColor.withValues(alpha: 0.1)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: accentColor.withValues(alpha: 0.1),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      isDebit
                                                          ? Icons.arrow_downward_rounded
                                                          : (isCredit ? Icons.arrow_upward_rounded : Icons.sms_outlined),
                                                      color: accentColor,
                                                      size: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    sender.toUpperCase(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (amount.isNotEmpty)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: accentColor.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    '${isDebit ? "-" : (isCredit ? "+" : "")} Rs. $amount',
                                                    style: TextStyle(
                                                      color: accentColor,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            body,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                formattedDate,
                                                style: const TextStyle(color: Colors.white30, fontSize: 10),
                                              ),
                                              Row(
                                                children: [
                                                  TextButton.icon(
                                                    onPressed: () async {
                                                      await _smsChannel.invokeMethod('markSmsProcessed', {'date': dateMs});
                                                      setSheetState(() {
                                                        smsList.removeAt(index);
                                                      });
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                          content: Text('🗑️ SMS removed from scan list'),
                                                          backgroundColor: Colors.white24,
                                                          duration: Duration(seconds: 1),
                                                        ),
                                                      );
                                                    },
                                                    style: TextButton.styleFrom(
                                                      foregroundColor: Colors.blueAccent,
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      minimumSize: Size.zero,
                                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    ),
                                                    icon: const Icon(Icons.delete_sweep_rounded, size: 14),
                                                    label: const Text('Remove', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ElevatedButton.icon(
                                                    onPressed: () {
                                                      _openFormSheet(
                                                        prefilledAmount: amount,
                                                        prefilledType: isDebit ? 'expense' : (isCredit ? 'income' : 'income'),
                                                        prefilledNote: body,
                                                        onSaveSuccess: () async {
                                                          await _smsChannel.invokeMethod('markSmsProcessed', {'date': dateMs});
                                                          setSheetState(() {
                                                            smsList.removeAt(index);
                                                          });
                                                        },
                                                      );
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.lightBlueAccent,
                                                      foregroundColor: Colors.black,
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                      minimumSize: Size.zero,
                                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    ),
                                                    icon: const Icon(Icons.add_rounded, size: 14),
                                                    label: const Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      );
    } catch (e) {
      print("SMS reading popup failed: $e");
    }
  }

  void _openFormSheet({
    dynamic existing,
    String? prefilledAmount,
    String? prefilledType,
    String? prefilledNote,
    VoidCallback? onSaveSuccess,
  }) {
    // local state inside sheet
    String selType = existing?['type'] ?? prefilledType ?? 'income';
    String amount = existing?['amount'] ?? prefilledAmount ?? '';
    String? memberId = existing?['memberId']?.toString();
    String? toMemberId = existing?['toMemberId']?.toString();
    String others = existing?['others'] ?? 'category';
    String? debtId = existing?['debtId']?.toString();
    String? goalId = existing?['goalId']?.toString();
    String? selectedCategoryName = existing?['category']?.toString();
    if (selectedCategoryName != null && selectedCategoryName.isEmpty) {
      selectedCategoryName = null;
    }
    String note = existing?['note'] ?? prefilledNote ?? '';

    final amtCtrl = TextEditingController(text: amount);
    final noteCtrl = TextEditingController(text: note);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setSheet) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        existing == null ? 'New Transaction' : 'Edit Transaction',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── TYPE SELECTOR ──
                      _label('TYPE'),
                      const SizedBox(height: 8),
                      Row(
                        children: ['income', 'expense', 'exchange'].map((t) {
                          final sel = selType == t;
                          final color = t == 'income'
                              ? Colors.lightBlueAccent
                              : t == 'expense'
                                  ? Colors.blueAccent
                                  : Colors.lightBlueAccent;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setSheet(() {
                                selType = t;
                                others = 'none';
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: sel ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                  border: Border.all(color: sel ? color : Colors.white12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      t == 'income'
                                          ? Icons.arrow_downward_rounded
                                          : t == 'expense'
                                              ? Icons.arrow_upward_rounded
                                              : Icons.swap_horiz_rounded,
                                      color: sel ? color : Colors.white38,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      t[0].toUpperCase() + t.substring(1),
                                      style: TextStyle(
                                        color: sel ? color : Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // ── AMOUNT ──
                      _label('AMOUNT (₹)'),
                      const SizedBox(height: 8),
                      _field(amtCtrl, 'e.g. 5000', keyboardType: TextInputType.number),
                      const SizedBox(height: 16),

                      // ── FROM MEMBER ──
                      _label(selType == 'exchange' ? 'FROM MEMBER' : 'MEMBER'),
                      const SizedBox(height: 8),
                      _memberPicker(
                        label: selType == 'exchange' ? 'From Member' : 'Member',
                        value: memberId,
                        onChanged: (v) => memberId = v,
                        setSheet: setSheet,
                      ),
                      const SizedBox(height: 16),

                      // ── EXCHANGE: TO MEMBER ──
                      if (selType == 'exchange') ...[
                        _label('TO MEMBER'),
                        const SizedBox(height: 8),
                        _memberPicker(
                          label: 'To Member',
                          value: toMemberId,
                          onChanged: (v) => toMemberId = v,
                          setSheet: setSheet,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── INCOME / EXPENSE: OTHERS ──
                      if (selType != 'exchange') ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _label('LINK TO'),
                            GestureDetector(
                              onTap: () {
                                if (others == 'category') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const TransactionCategoriesPage(),
                                    ),
                                  ).then((_) {
                                    _fetchAll();
                                  });
                                } else if (others == 'debt') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const DebtsPage(),
                                    ),
                                  ).then((_) {
                                    _fetchAll();
                                  });
                                } else if (others == 'goals') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const GoalsPage(),
                                    ),
                                  ).then((_) {
                                    _fetchAll();
                                  });
                                }
                              },
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.add_circle_outline_rounded,
                                    size: 14,
                                    color: Colors.lightBlueAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    others == 'category'
                                        ? 'Add Category'
                                        : others == 'debt'
                                            ? 'Add Debt'
                                            : 'Add Goal',
                                    style: const TextStyle(
                                      color: Colors.lightBlueAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: ['category', 'debt', 'goals'].map((o) {
                            final sel = others == o;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setSheet(() => others = o),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? Colors.lightBlueAccent.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.04),
                                    border: Border.all(
                                      color: sel ? Colors.lightBlueAccent : Colors.white12,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    o[0].toUpperCase() + o.substring(1),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: sel ? Colors.lightBlueAccent : Colors.white38,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Category dropdown picker
                        if (others == 'category') ...[
                          _label('CATEGORY'),
                          const SizedBox(height: 8),
                          _categoryPicker(
                            value: selectedCategoryName,
                            onChanged: (v) => selectedCategoryName = v,
                            setSheet: setSheet,
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (others == 'debt') ...[
                          _label('SELECT DEBT RECORD'),
                          const SizedBox(height: 8),
                          _debtPicker(
                            value: debtId,
                            onChanged: (v) => debtId = v,
                            setSheet: setSheet,
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (others == 'goals') ...[
                          _label('SELECT GOAL RECORD'),
                          const SizedBox(height: 8),
                          _goalPicker(
                            value: goalId,
                            onChanged: (v) => goalId = v,
                            setSheet: setSheet,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],

                      // ── NOTE ──
                      _label('NOTE (optional)'),
                      const SizedBox(height: 8),
                      _field(noteCtrl, 'Add a note…'),
                      const SizedBox(height: 24),

                      // ── ACTION BUTTONS ──
                      Row(
                        children: [
                          if (existing != null)
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.blueAccent),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () => _delete(existing['_id']),
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.blueAccent, size: 18),
                                label: const Text('Delete', style: TextStyle(color: Colors.blueAccent)),
                              ),
                            ),
                          if (existing != null) const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lightBlueAccent,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () async {
                                final amountStr = amtCtrl.text.trim();
                                if (amountStr.isEmpty || double.tryParse(amountStr) == null) {
                                  ScaffoldMessenger.of(ctx2).showSnackBar(
                                    const SnackBar(
                                      content: Text('⚠️ Please enter a valid amount'),
                                      backgroundColor: Colors.blueAccent,
                                    ),
                                  );
                                  return;
                                }

                                if (memberId == null || memberId == '') {
                                  ScaffoldMessenger.of(ctx2).showSnackBar(
                                    SnackBar(
                                      content: Text(selType == 'exchange'
                                          ? '⚠️ Please select the source member'
                                          : '⚠️ Please select a member'),
                                      backgroundColor: Colors.blueAccent,
                                    ),
                                  );
                                  return;
                                }

                                if (selType == 'exchange' && (toMemberId == null || toMemberId == '')) {
                                  ScaffoldMessenger.of(ctx2).showSnackBar(
                                    const SnackBar(
                                      content: Text('⚠️ Please select the destination member'),
                                      backgroundColor: Colors.blueAccent,
                                    ),
                                  );
                                  return;
                                }

                                if (selType == 'exchange' && memberId == toMemberId) {
                                  ScaffoldMessenger.of(ctx2).showSnackBar(
                                    const SnackBar(
                                      content: Text('⚠️ Source and destination members cannot be the same'),
                                      backgroundColor: Colors.blueAccent,
                                    ),
                                  );
                                  return;
                                }

                                if (selType != 'exchange' && others == 'category' && (selectedCategoryName == null || selectedCategoryName!.isEmpty)) {
                                  ScaffoldMessenger.of(ctx2).showSnackBar(
                                    const SnackBar(
                                      content: Text('⚠️ Please select a category'),
                                      backgroundColor: Colors.blueAccent,
                                    ),
                                  );
                                  return;
                                }

                                final selectedMember = _members.firstWhere(
                                  (m) => m['_id'].toString() == memberId,
                                  orElse: () => null,
                                );
                                final accId = selectedMember?['AccountId']?.toString() ?? '';

                                final selectedToMember = _members.firstWhere(
                                  (m) => m['_id'].toString() == toMemberId,
                                  orElse: () => null,
                                );
                                final toAccId = selectedToMember?['AccountId']?.toString() ?? '';

                                final body = {
                                  'type': selType,
                                  'amount': amtCtrl.text.trim(),
                                  'memberId': memberId ?? '',
                                  'accountId': accId,
                                  if (selType == 'exchange') 'toMemberId': toMemberId ?? '',
                                  if (selType == 'exchange') 'toAccountId': toAccId,
                                  if (selType != 'exchange') 'others': others,
                                  if (others == 'category') 'category': selectedCategoryName ?? '',
                                  if (others == 'debt' && debtId != null) 'debtId': debtId,
                                  if (others == 'goals' && goalId != null) 'goalId': goalId,
                                  if (noteCtrl.text.trim().isNotEmpty) 'note': noteCtrl.text.trim(),
                                };

                                setState(() => _isLoading = true);
                                try {
                                  http.Response res;
                                  if (existing == null) {
                                    res = await http.post(
                                      Uri.parse('$_baseUrl/api/transactions'),
                                      headers: {'Content-Type': 'application/json'},
                                      body: jsonEncode(body),
                                    ).timeout(const Duration(seconds: 6));
                                  } else {
                                    res = await http.put(
                                      Uri.parse('$_baseUrl/api/transactions/${existing['_id']}'),
                                      headers: {'Content-Type': 'application/json'},
                                      body: jsonEncode(body),
                                    ).timeout(const Duration(seconds: 6));
                                  }
                                  if (res.statusCode == 200 || res.statusCode == 201) {
                                    if (mounted) {
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(existing == null
                                              ? '🎉 Transaction saved!'
                                              : '🎉 Transaction updated!'),
                                          backgroundColor: Colors.lightBlue,
                                        ),
                                      );
                                      if (onSaveSuccess != null) {
                                        onSaveSuccess();
                                      }
                                    }
                                    _fetchAll();
                                  } else {
                                    setState(() => _isLoading = false);
                                    if (mounted) {
                                      String errMsg = 'Failed to save transaction';
                                      try {
                                        errMsg = jsonDecode(res.body)['message'] ?? errMsg;
                                      } catch (_) {}
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('⚠️ $errMsg'),
                                          backgroundColor: Colors.blueAccent,
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  setState(() => _isLoading = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('⚠️ Error: ${e.toString()}'),
                                        backgroundColor: Colors.blueAccent,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Text(
                                existing == null ? 'Save Transaction' : 'Update',
                                style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
        ),
      );

  Widget _field(TextEditingController ctrl, String hint,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white12),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // Helper: Get member name + account name
  String _memberName(String? memberId) {
    if (memberId == null) return '—';
    final mem = _members.firstWhere(
      (m) => m['_id'].toString() == memberId,
      orElse: () => null,
    );
    if (mem == null) return '—';
    final mName = mem['AccountMemberName'] ?? '—';
    final accId = mem['AccountId']?.toString();
    final accName = _accountName(accId);
    return '$mName ($accName)';
  }

  // Custom member picker — opens a sheet showing flat list of members
  Widget _memberPicker({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
    required StateSetter setSheet,
  }) {
    final selectedMember = _members.firstWhere(
      (m) => m['_id'].toString() == value,
      orElse: () => null,
    );
    String selectedText = 'Select $label';
    if (selectedMember != null) {
      final mName = selectedMember['AccountMemberName'] ?? '—';
      final mAmt = selectedMember['Amount'] ?? '0';
      final accId = selectedMember['AccountId']?.toString();
      final accName = _accountName(accId);
      selectedText = '$mName - ₹$mAmt - $accName';
    }

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Select $label',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: _members.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text(
                            'No members found! Please add members in the Wallets page first.',
                            style: TextStyle(color: Colors.white54),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _members.length,
                          separatorBuilder: (_, __) => Divider(
                            color: Colors.white.withOpacity(0.06),
                            height: 1,
                          ),
                          itemBuilder: (_, idx) {
                            final mem = _members[idx];
                            final memId = mem['_id'].toString();
                            final mName = mem['AccountMemberName'] ?? '—';
                            final mAmt = mem['Amount'] ?? '0';
                            final accId = mem['AccountId']?.toString();
                            final accName = _accountName(accId);
                            final isSelected = value == memId;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                        children: [
                                          TextSpan(
                                            text: mName,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          TextSpan(
                                            text: '  -  ₹$mAmt',
                                            style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.w600),
                                          ),
                                          TextSpan(
                                            text: '  -  $accName',
                                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle_rounded, color: Colors.lightBlueAccent, size: 20),
                                ],
                              ),
                              onTap: () {
                                setSheet(() => onChanged(memId));
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_pin_rounded, color: Colors.white38, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedText,
                style: TextStyle(
                  color: selectedMember != null ? Colors.white : Colors.white30,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _debtPicker({
    required String? value,
    required ValueChanged<String?> onChanged,
    required StateSetter setSheet,
  }) {
    final selectedDebt = _debts.firstWhere(
      (d) => d['_id'].toString() == value,
      orElse: () => null,
    );
    String selectedText = 'Select Debt Record';
    if (selectedDebt != null) {
      final name = selectedDebt['debtHolderName'] ?? '—';
      final amt = selectedDebt['debtAmount'] ?? '0';
      final date = selectedDebt['dueDate'] ?? '';
      selectedText = '$name - ₹$amt (Due: $date)';
    }

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Select Linked Debt',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: _debts.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text(
                            'No active debts found! Please create a debt record first.',
                            style: TextStyle(color: Colors.white54),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _debts.length,
                          separatorBuilder: (_, __) => Divider(
                            color: Colors.white.withOpacity(0.06),
                            height: 1,
                          ),
                          itemBuilder: (_, idx) {
                            final d = _debts[idx];
                            final debtId = d['_id'].toString();
                            final name = d['debtHolderName'] ?? '—';
                            final amt = d['debtAmount'] ?? '0';
                            final date = d['dueDate'] ?? '';
                            final isSelected = value == debtId;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                        children: [
                                          TextSpan(
                                            text: name,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          TextSpan(
                                            text: '  -  ₹$amt',
                                            style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.w600),
                                          ),
                                          TextSpan(
                                            text: '  (Due: $date)',
                                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle_rounded, color: Colors.lightBlueAccent, size: 20),
                                ],
                              ),
                              onTap: () {
                                setSheet(() => onChanged(debtId));
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.trending_down_rounded, color: Colors.white38, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedText,
                style: TextStyle(
                  color: selectedDebt != null ? Colors.white : Colors.white30,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _goalPicker({
    required String? value,
    required ValueChanged<String?> onChanged,
    required StateSetter setSheet,
  }) {
    final selectedGoal = _goals.firstWhere(
      (g) => g['_id'].toString() == value,
      orElse: () => null,
    );
    String selectedText = 'Select Goal Record';
    if (selectedGoal != null) {
      final name = selectedGoal['goalName'] ?? '—';
      final type = selectedGoal['type'] ?? 'general';
      final amt = selectedGoal['amount'] ?? '';
      selectedText = type == 'money' ? '$name - ₹$amt (Target)' : '$name (General)';
    }

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Select Linked Goal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: _goals.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text(
                            'No active goals found! Please create a goal record first.',
                            style: TextStyle(color: Colors.white54),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _goals.length,
                          separatorBuilder: (_, __) => Divider(
                            color: Colors.white.withOpacity(0.06),
                            height: 1,
                          ),
                          itemBuilder: (_, idx) {
                            final g = _goals[idx];
                            final goalId = g['_id'].toString();
                            final name = g['goalName'] ?? '—';
                            final type = g['type'] ?? 'general';
                            final amt = g['amount'] ?? '';
                            final isMoney = type == 'money';
                            final isSelected = value == goalId;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                        children: [
                                          TextSpan(
                                            text: name,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          if (isMoney) ...[
                                            TextSpan(
                                              text: '  -  ₹$amt',
                                              style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.w600),
                                            ),
                                            const TextSpan(
                                              text: '  (Money Goal)',
                                              style: TextStyle(color: Colors.white54, fontSize: 11),
                                            ),
                                          ] else ...[
                                            const TextSpan(
                                              text: '  (General Goal)',
                                              style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ]
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle_rounded, color: Colors.lightBlueAccent, size: 20),
                                ],
                              ),
                              onTap: () {
                                setSheet(() => onChanged(goalId));
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_rounded, color: Colors.white38, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedText,
                style: TextStyle(
                  color: selectedGoal != null ? Colors.white : Colors.white30,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _categoryPicker({
    required String? value,
    required ValueChanged<String?> onChanged,
    required StateSetter setSheet,
  }) {
    final selectedCategory = _categories.firstWhere(
      (c) => c['name']?.toString() == value,
      orElse: () => null,
    );
    String selectedText = 'Select Category';
    if (selectedCategory != null) {
      selectedText = selectedCategory['name'] ?? '—';
    } else if (value != null && value.isNotEmpty) {
      selectedText = value;
    }

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Category',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TransactionCategoriesPage(),
                            ),
                          ).then((_) {
                            _fetchAll();
                          });
                        },
                        icon: const Icon(Icons.settings, size: 16, color: Colors.lightBlueAccent),
                        label: const Text('Manage', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: _categories.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'No categories found! Click Manage to add some.',
                                style: TextStyle(color: Colors.white54),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.lightBlueAccent,
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const TransactionCategoriesPage(),
                                    ),
                                  ).then((_) {
                                    _fetchAll();
                                  });
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Add Category'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) => Divider(
                            color: Colors.white.withOpacity(0.06),
                            height: 1,
                          ),
                          itemBuilder: (_, idx) {
                            final cat = _categories[idx];
                            final catName = cat['name']?.toString() ?? '—';
                            final isSelected = value == catName;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      catName,
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle_rounded, color: Colors.lightBlueAccent, size: 20),
                                ],
                              ),
                              onTap: () {
                                setSheet(() => onChanged(catName));
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.category_rounded, color: Colors.white38, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedText,
                style: TextStyle(
                  color: (selectedCategory != null || (value != null && value.isNotEmpty)) ? Colors.white : Colors.white30,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<dynamic> list) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchAll,
        color: Colors.lightBlueAccent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_rounded, size: 72, color: Colors.white.withValues(alpha: 0.08)),
                const SizedBox(height: 16),
                const Text('No transactions yet', style: TextStyle(color: Colors.white54, fontSize: 15)),
                const SizedBox(height: 8),
                const Text('Tap + to add one', style: TextStyle(color: Colors.white30, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAll,
      color: Colors.lightBlueAccent,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final tx = list[i];
        final type = tx['type'] ?? 'income';
        final typeColor = type == 'income'
            ? Colors.lightBlueAccent
            : type == 'expense'
                ? Colors.blueAccent
                : Colors.lightBlueAccent;
        final typeIcon = type == 'income'
            ? Icons.arrow_downward_rounded
            : type == 'expense'
                ? Icons.arrow_upward_rounded
                : Icons.swap_horiz_rounded;

        final others = tx['others'] ?? 'none';
        String otherLabel = '';
        if (others != 'none') {
          if (others == 'debt' && tx['debtId'] != null) {
            final linkedDebt = _debts.firstWhere(
              (d) => d['_id'].toString() == tx['debtId']?.toString(),
              orElse: () => null,
            );
            if (linkedDebt != null) {
              otherLabel = 'Debt: ${linkedDebt['debtHolderName']}';
            } else {
              otherLabel = 'Debt Linked';
            }
          } else if (others == 'goals' && tx['goalId'] != null) {
            final linkedGoal = _goals.firstWhere(
              (g) => g['_id'].toString() == tx['goalId']?.toString(),
              orElse: () => null,
            );
            if (linkedGoal != null) {
              otherLabel = 'Goal: ${linkedGoal['goalName']}';
            } else {
              otherLabel = 'Goal Linked';
            }
          } else {
            otherLabel = others[0].toUpperCase() + others.substring(1);
          }
        }

        return GestureDetector(
          onTap: () => _showEditSheet(tx),
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
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _memberName(tx['memberId']?.toString()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (type == 'exchange' && tx['toMemberId'] != null) ...[
                            const Icon(Icons.arrow_forward_rounded, color: Colors.white30, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              _memberName(tx['toMemberId']?.toString()),
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ] else if (otherLabel.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.lightBlueAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                otherLabel,
                                style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11),
                              ),
                            ),
                          ] else
                            const Text('No link', style: TextStyle(color: Colors.white30, fontSize: 12)),
                          if ((tx['note'] ?? '').isNotEmpty) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.notes_rounded, color: Colors.white24, size: 12),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                tx['note'],
                                style: const TextStyle(color: Colors.white30, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${tx['amount'] ?? '0'}',
                  style: TextStyle(
                    color: typeColor,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final income = _filtered('income');
    final expense = _filtered('expense');
    final exchange = _filtered('exchange');

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
          'Transactions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.lightBlueAccent),
            tooltip: 'Scan Bank SMS',
            onPressed: _scanSmsAndShowPopup,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.lightBlueAccent,
          unselectedLabelColor: Colors.white38,
          indicatorColor: Colors.lightBlueAccent,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_downward_rounded, size: 14),
                  const SizedBox(width: 4),
                  Text('Income (${income.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_upward_rounded, size: 14, color: Colors.blueAccent),
                  const SizedBox(width: 4),
                  Text('Expense (${expense.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_horiz_rounded, size: 14, color: Colors.lightBlueAccent),
                  const SizedBox(width: 4),
                  Text('Exchange (${exchange.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off_rounded, color: Colors.blueAccent, size: 60),
                      const SizedBox(height: 12),
                      Text(_errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlueAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: _fetchAll,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(income),
                    _buildList(expense),
                    _buildList(exchange),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.lightBlueAccent,
        foregroundColor: Colors.black,
        onPressed: _showAddSheet,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
