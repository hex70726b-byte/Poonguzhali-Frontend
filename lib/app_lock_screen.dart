import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_config.dart';

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  String _lockType = 'pin';
  String _storedValue = '';
  String _enteredValue = '';
  bool _isObscure = true;
  String _errorMessage = '';
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLockData();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadLockData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lockType = prefs.getString('app_lock_type') ?? 'pin';
      _storedValue = prefs.getString('app_lock_value') ?? '';
    });
  }

  void _onKeyPress(String val) {
    if (_enteredValue.length < 6) {
      setState(() {
        _errorMessage = '';
        _enteredValue += val;
      });
    }

    if (_enteredValue.length == 6) {
      // Small delay to allow user to see the last dot fill
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          _verifyUnlock();
        }
      });
    }
  }

  void _onBackspace() {
    setState(() {
      _errorMessage = '';
      if (_enteredValue.isNotEmpty) {
        _enteredValue = _enteredValue.substring(0, _enteredValue.length - 1);
      }
    });
  }

  void _verifyUnlock() {
    final inputVal = _lockType == 'pin' ? _enteredValue : _passwordController.text.trim();
    if (inputVal == _storedValue) {
      widget.onUnlocked();
    } else {
      setState(() {
        _errorMessage = 'Incorrect ${_lockType == 'pin' ? 'PIN' : 'Password'}';
        _enteredValue = '';
        _passwordController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPin = _lockType == 'pin';

    return Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),
            
            // Rebranded Circular Profile Avatar
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.skyBlue.withValues(alpha: 0.3),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.skyBlue.withValues(alpha: 0.2),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.skyBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.security_rounded, size: 40, color: Colors.black),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Personal Agent',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPin ? 'Enter PIN to unlock' : 'Enter Password to unlock',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
            
            const Spacer(flex: 1),
            
            // Error Message Alert
            if (_errorMessage.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Main Input Area
            if (isPin) ...[
              // PIN Dots indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final filled = index < _enteredValue.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: filled ? AppColors.skyBlue : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: filled ? AppColors.skyBlue : Colors.white24,
                        width: 2,
                      ),
                      boxShadow: filled
                          ? [
                              BoxShadow(
                                color: AppColors.skyBlue.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                  );
                }),
              ),
              const Spacer(flex: 1),
              
              // Custom Numeric Keypad
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['1', '2', '3'].map((k) => _buildKey(k)).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['4', '5', '6'].map((k) => _buildKey(k)).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['7', '8', '9'].map((k) => _buildKey(k)).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const SizedBox(width: 70, height: 70), // Spacer for align
                        _buildKey('0'),
                        _buildBackspaceKey(),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Password input box & button
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    TextField(
                      controller: _passwordController,
                      obscureText: _isObscure,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter password',
                        hintStyle: const TextStyle(color: Colors.white30),
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.skyBlue),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isObscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: Colors.white54,
                          ),
                          onPressed: () => setState(() => _isObscure = !_isObscure),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: AppColors.skyBlue, width: 1.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onSubmitted: (_) => _verifyUnlock(),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.skyBlue,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: AppColors.skyBlue.withValues(alpha: 0.3),
                      ),
                      onPressed: _verifyUnlock,
                      child: const Text(
                        'Unlock',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String text) {
    return InkWell(
      onTap: () => _onKeyPress(text),
      borderRadius: BorderRadius.circular(35),
      child: Ink(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey() {
    return InkWell(
      onTap: _onBackspace,
      borderRadius: BorderRadius.circular(35),
      child: SizedBox(
        width: 70,
        height: 70,
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            color: Colors.white.withValues(alpha: 0.6),
            size: 24,
          ),
        ),
      ),
    );
  }
}
