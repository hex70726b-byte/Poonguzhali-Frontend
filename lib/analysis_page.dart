import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_config.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  static const String _baseUrl = AppConfig.baseUrl;

  bool _isLoading = true;
  String? _errorMessage;

  // Raw data from APIs
  List<dynamic> _workouts = [];
  List<dynamic> _accounts = [];
  List<dynamic> _members = [];
  List<dynamic> _transactions = [];
  List<dynamic> _goals = [];
  List<dynamic> _habits = [];
  List<dynamic> _diaries = [];
  List<dynamic> _learnings = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$_baseUrl/api/workouts')).timeout(const Duration(seconds: 8)),
        http.get(Uri.parse('$_baseUrl/api/accounts')).timeout(const Duration(seconds: 8)),
        http.get(Uri.parse('$_baseUrl/api/accountsMembers')).timeout(const Duration(seconds: 8)),
        http.get(Uri.parse('$_baseUrl/api/transactions')).timeout(const Duration(seconds: 8)),
        http.get(Uri.parse('$_baseUrl/api/goals')).timeout(const Duration(seconds: 8)),
        http.get(Uri.parse('$_baseUrl/api/habits')).timeout(const Duration(seconds: 8)),
        http.get(Uri.parse('$_baseUrl/api/diaries')).timeout(const Duration(seconds: 8)),
        http.get(Uri.parse('$_baseUrl/api/learnings')).timeout(const Duration(seconds: 8)),
      ]);

      if (responses.any((res) => res.statusCode != 200)) {
        throw Exception('One or more services failed to respond correctly');
      }

      setState(() {
        _workouts = jsonDecode(responses[0].body);
        _accounts = jsonDecode(responses[1].body);
        _members = jsonDecode(responses[2].body);
        _transactions = jsonDecode(responses[3].body);
        _goals = jsonDecode(responses[4].body);
        _habits = jsonDecode(responses[5].body);
        _diaries = jsonDecode(responses[6].body);
        _learnings = jsonDecode(responses[7].body);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to fetch analysis dashboard data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculators & Parsers

    // 1. Wallets (Accounts & Members)
    double totalWalletBalance = 0.0;
    for (var m in _members) {
      final bal = double.tryParse(m['Amount']?.toString() ?? '') ?? 0.0;
      totalWalletBalance += bal;
    }

    // 2. Transactions
    double totalIncome = 0.0;
    double totalExpense = 0.0;
    for (var tx in _transactions) {
      final amt = double.tryParse(tx['amount']?.toString() ?? '') ?? 0.0;
      final type = tx['type']?.toString().toLowerCase() ?? '';
      if (type == 'income') {
        totalIncome += amt;
      } else if (type == 'expense') {
        totalExpense += amt;
      }
    }
    double netSavings = totalIncome - totalExpense;
    double savingsRate = totalIncome > 0 ? (netSavings / totalIncome) * 100 : 0;

    // 3. Goals
    int totalGoals = _goals.length;
    int moneyGoalsCount = _goals.where((g) => g['type'] == 'money').length;
    int generalGoalsCount = _goals.where((g) => g['type'] == 'general').length;

    // Money goals dynamic targets/contributions
    double totalTargetMoneyGoals = 0.0;
    double totalContributedMoneyGoals = 0.0;
    for (var g in _goals) {
      if (g['type'] == 'money') {
        final targetAmt = double.tryParse(g['amount']?.toString() ?? '') ?? 0.0;
        totalTargetMoneyGoals += targetAmt;

        // Find linked transactions
        double contributed = 0.0;
        for (var tx in _transactions) {
          if (tx['others']?.toString() == 'goals' && tx['goalId']?.toString() == g['_id']?.toString()) {
            final amt = double.tryParse(tx['amount']?.toString() ?? '') ?? 0.0;
            contributed += amt;
          }
        }
        totalContributedMoneyGoals += contributed;
      }
    }

    // 4. Habits
    int totalHabits = _habits.length;
    int singleHabits = _habits.where((h) => h['type'] == 'single').length;
    int multipleHabits = _habits.where((h) => h['type'] == 'multiple').length;
    double avgHabitStreak = totalHabits > 0
        ? _habits.map((h) => int.tryParse(h['streak']?.toString() ?? '0') ?? 0).reduce((a, b) => a + b) / totalHabits
        : 0.0;

    // 5. Workouts
    int totalWorkouts = _workouts.length;
    int countWorkouts = _workouts.where((w) => w['type'] == 'count').length;
    int timeWorkouts = _workouts.where((w) => w['type'] == 'time').length;
    int highestWorkoutStreak = totalWorkouts > 0
        ? _workouts.map((w) => int.tryParse(w['streak']?.toString() ?? '0') ?? 0).reduce((a, b) => a > b ? a : b)
        : 0;

    // 6. Diary
    int totalDiaries = _diaries.length;

    // 7. Learning
    int totalLearnings = _learnings.length;
    int totalLearningLinks = 0;
    for (var l in _learnings) {
      if (l['links'] != null && l['links'].toString().isNotEmpty) {
        try {
          final decoded = jsonDecode(l['links'].toString());
          if (decoded is List) {
            totalLearningLinks += decoded.length;
          }
        } catch (_) {}
      }
    }

    // Comprehensive Life Score (Composite index 0-100)
    double compositeScore = 0.0;
    if (totalHabits > 0) compositeScore += (avgHabitStreak.clamp(0, 10) * 3); // max 30 pts
    if (totalWorkouts > 0) compositeScore += (highestWorkoutStreak.clamp(0, 10) * 2); // max 20 pts
    if (totalDiaries > 0) compositeScore += (totalDiaries.clamp(0, 15) * 1.5); // max 22.5 pts
    if (totalGoals > 0) {
      double completedRatio = totalTargetMoneyGoals > 0 ? (totalContributedMoneyGoals / totalTargetMoneyGoals).clamp(0.0, 1.0) : 1.0;
      compositeScore += (completedRatio * 27.5); // max 27.5 pts
    } else {
      compositeScore += 15.0; // default points
    }
    final int displayLifeScore = compositeScore.clamp(0.0, 100.0).round();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.indigoAccent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '📊 Core Analysis Center',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.indigoAccent),
            onPressed: _fetchDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.analytics_rounded, color: Colors.redAccent, size: 64),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
                          onPressed: _fetchDashboardData,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Grand Composite Life Score Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3F51B5), Color(0xFF1A237E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'LIFE SYNC INDEX',
                                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Overall Score',
                                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    displayLifeScore >= 75
                                        ? '🔥 You are performing exceptionally well!'
                                        : displayLifeScore >= 45
                                            ? '📈 Great steady progress, keep pushing!'
                                            : '💪 Focus on streaks & goals to rank up!',
                                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: CircularProgressIndicator(
                                    value: displayLifeScore / 100,
                                    strokeWidth: 8,
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
                                  ),
                                ),
                                Text(
                                  '$displayLifeScore%',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'METRIC ANALYSIS BREAKDOWN',
                        style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 12),

                      // 1. Wallets & Financials Card (Green/Teal)
                      _buildAnalysisCard(
                        title: '💰 Financial & Transaction Flow',
                        accentColor: Colors.lightBlueAccent,
                        child: Column(
                          children: [
                            _buildRowMetric('Total Wallet Balances', '₹${totalWalletBalance.toStringAsFixed(2)}', Colors.lightBlueAccent),
                            _buildRowMetric('Total Income Stream', '₹${totalIncome.toStringAsFixed(2)}', Colors.white70),
                            _buildRowMetric('Total Expenses Stream', '₹${totalExpense.toStringAsFixed(2)}', Colors.redAccent),
                            const Divider(color: Colors.white12, height: 16),
                            _buildRowMetric('Net Savings Flow', '₹${netSavings.toStringAsFixed(2)}', netSavings >= 0 ? Colors.lightBlueAccent : Colors.redAccent),
                            _buildRowMetric('Income Savings Rate', '${savingsRate.toStringAsFixed(1)}%', Colors.blueAccent),
                          ],
                        ),
                      ),

                      // 2. Goal Tracking (Gold/Amber)
                      _buildAnalysisCard(
                        title: '🎯 Target Goals & Contributions',
                        accentColor: Colors.lightBlueAccent,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildMetricMiniTile('Total Goals', '$totalGoals', Colors.lightBlueAccent)),
                                Expanded(child: _buildMetricMiniTile('Money Goals', '$moneyGoalsCount', Colors.lightBlueAccent)),
                                Expanded(child: _buildMetricMiniTile('General', '$generalGoalsCount', Colors.lightBlueAccent)),
                              ],
                            ),
                            if (moneyGoalsCount > 0) ...[
                              const SizedBox(height: 16),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('MONEY GOAL TARGET CONSOLIDATION', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: totalTargetMoneyGoals > 0 ? (totalContributedMoneyGoals / totalTargetMoneyGoals) : 0.0,
                                backgroundColor: Colors.white12,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
                                minHeight: 6,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Saved: ₹${totalContributedMoneyGoals.toStringAsFixed(0)}', style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12)),
                                  Text('Target: ₹${totalTargetMoneyGoals.toStringAsFixed(0)}', style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12)),
                                ],
                              ),
                            ]
                          ],
                        ),
                      ),

                      // 3. Habits Performance (Cyan/TealAccent)
                      _buildAnalysisCard(
                        title: '⚡ Daily Habits Sync',
                        accentColor: Colors.blueAccent,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildMetricMiniTile('Total Habits', '$totalHabits', Colors.blueAccent)),
                                Expanded(child: _buildMetricMiniTile('Single Type', '$singleHabits', Colors.lightBlueAccent)),
                                Expanded(child: _buildMetricMiniTile('Multiple Type', '$multipleHabits', Colors.deepOrangeAccent)),
                              ],
                            ),
                            const Divider(color: Colors.white12, height: 24),
                            _buildRowMetric('Average Habits Streak', '${avgHabitStreak.toStringAsFixed(1)} Days', Colors.blueAccent),
                          ],
                        ),
                      ),

                      // 4. Workout Highlights (Red/Coral)
                      _buildAnalysisCard(
                        title: '💪 Workout & Fitness',
                        accentColor: Colors.redAccent,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildMetricMiniTile('Fitness Workouts', '$totalWorkouts', Colors.redAccent)),
                                Expanded(child: _buildMetricMiniTile('Time Workouts', '$timeWorkouts', Colors.lightBlueAccent)),
                                Expanded(child: _buildMetricMiniTile('Count Workouts', '$countWorkouts', Colors.lightBlueAccent)),
                              ],
                            ),
                            const Divider(color: Colors.white12, height: 24),
                            _buildRowMetric('Highest Active Streak', '$highestWorkoutStreak Days', Colors.redAccent),
                          ],
                        ),
                      ),

                      // 5. Diary Analytics (Pink/Rose)
                      _buildAnalysisCard(
                        title: '📖 Diary & Writing Journal',
                        accentColor: Colors.lightBlueAccent,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildMetricMiniTile('Journal Entries', '$totalDiaries', Colors.lightBlueAccent)),
                                Expanded(
                                  child: _buildMetricMiniTile(
                                    'Consistency Status',
                                    totalDiaries >= 10
                                        ? 'Excellent'
                                        : totalDiaries >= 4
                                            ? 'Good'
                                            : 'Needs Focus',
                                    Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 6. Learning progress (Orange)
                      _buildAnalysisCard(
                        title: '📚 Learning & Resources Path',
                        accentColor: Colors.lightBlueAccent,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildMetricMiniTile('Learning Topics', '$totalLearnings', Colors.lightBlueAccent)),
                                Expanded(child: _buildMetricMiniTile('Reference Links', '$totalLearningLinks', Colors.blueAccent)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildAnalysisCard({required String title, required Color accentColor, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.15), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildRowMetric(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMetricMiniTile(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
