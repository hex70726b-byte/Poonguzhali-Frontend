import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_config.dart';

class WalletsPage extends StatefulWidget {
  const WalletsPage({super.key});

  @override
  State<WalletsPage> createState() => _WalletsPageState();
}

class _WalletsPageState extends State<WalletsPage> {
  // Base URLs for fallback support (local machine vs android emulator)
  static const String _defaultLocalhost = AppConfig.baseUrl;
  static const String _defaultEmulator = 'http://10.0.2.2:5000';
  
  late TextEditingController _baseUrlController;
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _memberNameController = TextEditingController();
  final TextEditingController _memberAmountController = TextEditingController();
  
  List<dynamic> _accounts = [];
  List<dynamic> _members = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Defaulting to localhost. If it fails, we try emulator, or let user customize.
    _baseUrlController = TextEditingController(text: _defaultLocalhost);
    _fetchData();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _accountNameController.dispose();
    _memberNameController.dispose();
    _memberAmountController.dispose();
    super.dispose();
  }

  // Fetch accounts and members from the backend APIs
  Future<void> _fetchData({String? overrideUrl}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final baseUrl = overrideUrl ?? _baseUrlController.text.trim();
    final accountsUrl = Uri.parse('$baseUrl/api/accounts');
    final membersUrl = Uri.parse('$baseUrl/api/accountsMembers');

    try {
      final accountsResponse = await http.get(accountsUrl).timeout(const Duration(seconds: 5));
      final membersResponse = await http.get(membersUrl).timeout(const Duration(seconds: 5));

      if (accountsResponse.statusCode == 200 && membersResponse.statusCode == 200) {
        final List<dynamic> accountsData = jsonDecode(accountsResponse.body);
        final List<dynamic> membersData = jsonDecode(membersResponse.body);
        
        setState(() {
          _accounts = accountsData;
          _members = membersData;
          _isLoading = false;
        });
      } else {
        throw Exception('Server returned error statuses: Accounts (${accountsResponse.statusCode}), Members (${membersResponse.statusCode})');
      }
    } catch (e) {
      // Auto-fallback check: if we tried localhost and failed, let's automatically try 10.0.2.2 for emulator
      if (baseUrl == _defaultLocalhost && overrideUrl == null) {
        debugPrint('Localhost failed, trying emulator fallback...');
        _baseUrlController.text = _defaultEmulator;
        _fetchData(overrideUrl: _defaultEmulator);
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not connect to backend at $baseUrl.\n'
            'Please verify your backend server is running and the database is connected.\n\n'
            'Details: $e';
      });
    }
  }

  // Create a new wallet account on the backend
  Future<void> _createAccount() async {
    final name = _accountNameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final baseUrl = _baseUrlController.text.trim();
    final url = Uri.parse('$baseUrl/api/accounts');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'accountName': name}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 201) {
        _accountNameController.clear();
        if (mounted) {
          Navigator.of(context).pop(); // Close the input dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Wallet account created successfully!'),
              backgroundColor: AppColors.lightBlueAccent,
            ),
          );
        }
        _fetchData();
      } else {
        throw Exception('Server returned status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error creating wallet: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Update an existing wallet account on the backend
  Future<void> _updateAccount(String accountId) async {
    final name = _accountNameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final baseUrl = _baseUrlController.text.trim();
    final url = Uri.parse('$baseUrl/api/accounts/$accountId');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'accountName': name}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _accountNameController.clear();
        if (mounted) {
          Navigator.of(context).pop(); // Close dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Wallet updated successfully!'),
              backgroundColor: AppColors.lightBlueAccent,
            ),
          );
        }
        _fetchData();
      } else {
        throw Exception('Server returned status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error updating wallet: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Delete a wallet account from the backend
  Future<void> _deleteAccount(String accountId) async {
    setState(() {
      _isLoading = true;
    });

    final baseUrl = _baseUrlController.text.trim();
    final url = Uri.parse('$baseUrl/api/accounts/$accountId');

    try {
      final response = await http.delete(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.of(context).pop(); // Close delete confirmation dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Wallet deleted successfully!'),
              backgroundColor: Colors.blueGrey,
            ),
          );
        }
        _fetchData();
      } else {
        throw Exception('Server returned status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error deleting wallet: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Add a new member to a specific account
  Future<void> _addAccountMember(String accountId) async {
    final name = _memberNameController.text.trim();
    final amount = _memberAmountController.text.trim();

    if (name.isEmpty || amount.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please fill out all fields'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final baseUrl = _baseUrlController.text.trim();
    final url = Uri.parse('$baseUrl/api/accountsMembers');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'AccountMemberName': name,
          'Amount': amount,
          'AccountId': accountId,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 201) {
        _memberNameController.clear();
        _memberAmountController.clear();
        if (mounted) {
          Navigator.of(context).pop(); // Close the detail/input modal
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('👥 Member added to wallet successfully!'),
              backgroundColor: AppColors.lightBlueAccent,
            ),
          );
        }
        _fetchData();
      } else {
        throw Exception('Server returned status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error adding member: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Update an existing member/balance on the backend
  Future<void> _updateAccountMember(String memberId) async {
    final name = _memberNameController.text.trim();
    final amount = _memberAmountController.text.trim();

    if (name.isEmpty || amount.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final baseUrl = _baseUrlController.text.trim();
    final url = Uri.parse('$baseUrl/api/accountsMembers/$memberId');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'AccountMemberName': name,
          'Amount': amount,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _memberNameController.clear();
        _memberAmountController.clear();
        if (mounted) {
          Navigator.of(context).pop(); // Close edit member dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Member updated successfully!'),
              backgroundColor: AppColors.lightBlueAccent,
            ),
          );
        }
        _fetchData();
      } else {
        throw Exception('Server returned status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error updating member: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Delete a member from the backend
  Future<void> _deleteAccountMember(String memberId) async {
    setState(() {
      _isLoading = true;
    });

    final baseUrl = _baseUrlController.text.trim();
    final url = Uri.parse('$baseUrl/api/accountsMembers/$memberId');

    try {
      final response = await http.delete(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.of(context).pop(); // Close delete confirmation dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Member deleted successfully!'),
              backgroundColor: Colors.blueGrey,
            ),
          );
        }
        _fetchData();
      } else {
        throw Exception('Server returned status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error deleting member: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Calculate total balance for a specific account
  double _calculateTotalBalance(String accountId) {
    double total = 0.0;
    for (var member in _members) {
      if (member['AccountId'] == accountId) {
        final amtStr = member['Amount']?.toString() ?? '0';
        final amt = double.tryParse(amtStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        total += amt;
      }
    }
    return total;
  }

  // Get members belonging to a specific account
  List<dynamic> _getAccountMembers(String accountId) {
    return _members.where((m) => m['AccountId'] == accountId).toList();
  }

  // Show dialog to add a new wallet/account
  void _showAddWalletDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'New Wallet Account',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the name of your new wallet account. The system will automatically encrypt it secure-side.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _accountNameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Account Name',
                  labelStyle: const TextStyle(color: AppColors.lightBlueAccent),
                  hintText: 'e.g., Personal Savings, HDFC Bank',
                  hintStyle: const TextStyle(color: Colors.white30),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.lightBlueAccent, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _accountNameController.clear();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lightBlueAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _createAccount,
              child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Show dialog to edit wallet/account name
  void _showEditWalletDialog(dynamic account) {
    final accountId = account['_id'];
    _accountNameController.text = account['accountName'] ?? '';
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Edit Wallet Account',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _accountNameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Account Name',
                  labelStyle: const TextStyle(color: AppColors.lightBlueAccent),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.lightBlueAccent, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _accountNameController.clear();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lightBlueAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _updateAccount(accountId),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Show dialog to confirm wallet deletion
  void _showDeleteConfirmationDialog(String accountId, String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Delete Wallet?',
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete "$name"? This will permanently delete the wallet and all associated member accounts.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _deleteAccount(accountId),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Show dialog to edit account member
  void _showEditMemberDialog(dynamic member) {
    final memberId = member['_id'];
    _memberNameController.text = member['AccountMemberName'] ?? '';
    _memberAmountController.text = member['Amount'] ?? '';
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Edit Account Member',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _memberNameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Member Name',
                  labelStyle: const TextStyle(color: AppColors.lightBlueAccent),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.lightBlueAccent, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _memberAmountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  labelStyle: const TextStyle(color: AppColors.lightBlueAccent),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.lightBlueAccent, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _memberNameController.clear();
                _memberAmountController.clear();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lightBlueAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _updateAccountMember(memberId),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Show dialog to confirm member deletion
  void _showDeleteMemberConfirmationDialog(dynamic member) {
    final memberId = member['_id'];
    final name = member['AccountMemberName'] ?? 'Unnamed Member';
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Delete Member?',
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete "$name" from this wallet?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _deleteAccountMember(memberId),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Show bottom sheet with account members/transactions details
  void _showAccountDetailsSheet(dynamic account) {
    final accountId = account['_id'];
    final name = account['accountName'] ?? 'Unnamed Account';
    final members = _getAccountMembers(accountId);
    final total = _calculateTotalBalance(accountId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, color: AppColors.lightBlueAccent, size: 18),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    onPressed: () {
                                      Navigator.of(context).pop(); // Close bottom sheet
                                      _showEditWalletDialog(account);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    onPressed: () {
                                      Navigator.of(context).pop(); // Close bottom sheet
                                      _showDeleteConfirmationDialog(accountId, name);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Wallet Directory & Balances',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('TOTAL BALANCE', style: TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: 1)),
                            Text(
                              '₹${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.lightBlueAccent,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 32),
                    const Text(
                      'ACCOUNT MEMBERS',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    members.isEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            width: double.infinity,
                            alignment: Alignment.center,
                            child: const Column(
                              children: [
                                Icon(Icons.people_outline_rounded, color: Colors.white24, size: 40),
                                SizedBox(height: 8),
                                Text(
                                  'No members linked to this account.',
                                  style: TextStyle(color: Colors.white38, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: members.length,
                              itemBuilder: (context, idx) {
                                final member = members[idx];
                                final mName = member['AccountMemberName'] ?? 'Unnamed Member';
                                final mAmount = member['Amount'] ?? '0';
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor: AppColors.lightBlueAccent.withOpacity(0.2),
                                              child: Text(
                                                mName.isNotEmpty ? mName[0].toUpperCase() : 'M',
                                                style: const TextStyle(color: AppColors.lightBlueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    mName,
                                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Amount: ₹$mAmount',
                                                    style: const TextStyle(color: AppColors.lightBlueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_rounded, color: AppColors.lightBlueAccent, size: 16),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              Navigator.of(context).pop(); // Close bottom sheet
                                              _showEditMemberDialog(member);
                                            },
                                          ),
                                          const SizedBox(width: 12),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              Navigator.of(context).pop(); // Close bottom sheet
                                              _showDeleteMemberConfirmationDialog(member);
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                    const Divider(color: Colors.white12, height: 32),
                    const Text(
                      'ADD NEW MEMBER',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _memberNameController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Member Name',
                              labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                              hintText: 'e.g., John Doe',
                              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Colors.white12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: AppColors.lightBlueAccent),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _memberAmountController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Amount (₹)',
                              labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                              hintText: '5000',
                              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Colors.white12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: AppColors.lightBlueAccent),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lightBlueAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _addAccountMember(accountId),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text(
                          'Add Member',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
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

  @override
  Widget build(BuildContext context) {
    final List<Color> cardColors = [
      AppColors.royalBlue,
      AppColors.lightBlueAccent,
      AppColors.lightBlueAccent,
      AppColors.lightBlueAccent,
      Colors.blueGrey
    ];

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
          'Wallets & Accounts',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: const [],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                'YOUR DIGITAL CARDS (Tap to View Members)',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              // Dynamic Content Area
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchData,
                  color: AppColors.lightBlueAccent,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.lightBlueAccent),
                          ),
                        )
                      : _errorMessage != null
                          ? Center(
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.redAccent),
                                    const SizedBox(height: 16),
                                    Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                                    ),
                                    const SizedBox(height: 20),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.lightBlueAccent,
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                      onPressed: () => _fetchData(),
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text('Try Again'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _accounts.isEmpty
                              ? SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  child: Container(
                                    height: MediaQuery.of(context).size.height * 0.5,
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.account_balance_wallet_outlined,
                                          size: 80,
                                          color: Colors.white.withOpacity(0.15),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'No Active Wallets Found',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Add a wallet card to store encrypted accounts.',
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.lightBlueAccent,
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(30),
                                            ),
                                          ),
                                          onPressed: _showAddWalletDialog,
                                          icon: const Icon(Icons.add_rounded),
                                          label: const Text(
                                            'Create First Wallet',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: _accounts.length,
                                itemBuilder: (context, index) {
                                  final account = _accounts[index];
                                  final name = account['accountName'] ?? 'Unnamed Account';
                                  final accountId = account['_id'] ?? '';
                                  final color = cardColors[index % cardColors.length];
                                  final balance = _calculateTotalBalance(accountId);

                                  return GestureDetector(
                                    onTap: () => _showAccountDetailsSheet(account),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      height: 180,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [color, color.withBlue(180).withGreen(100)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withOpacity(0.4),
                                            blurRadius: 15,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        children: [
                                          // Glassmorphism accent circle
                                          Positioned(
                                            right: -40,
                                            bottom: -40,
                                            child: Container(
                                              width: 150,
                                              height: 150,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white.withOpacity(0.1),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            right: 20,
                                            top: 20,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.white24,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.lock_outline_rounded, color: Colors.white, size: 14),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'ENCRYPTED',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(24.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Icon(
                                                      Icons.credit_card_rounded,
                                                      color: Colors.white70,
                                                      size: 28,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      name,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 22,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Balance: ₹${balance.toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox.shrink(),
                                                  ],
                                                ),
                                              ],
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
        ),
      ),
      floatingActionButton: _accounts.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: AppColors.lightBlueAccent,
              foregroundColor: Colors.black,
              onPressed: _showAddWalletDialog,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}
