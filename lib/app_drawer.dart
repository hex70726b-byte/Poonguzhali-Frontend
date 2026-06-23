import 'package:flutter/material.dart';
import 'app_config.dart';
import 'main.dart';
import 'workouts_page.dart';
import 'analysis_page.dart';
import 'wallets_page.dart';
import 'transactions_page.dart';
import 'debts_page.dart';
import 'goals_page.dart';
import 'habits_page.dart';
import 'contacts_page.dart';
import 'diaries_page.dart';
import 'reminders_page.dart';
import 'learnings_page.dart';
import 'passwords_page.dart';
import 'documents_page.dart';
import 'todo_page.dart';

class AppDrawer extends StatelessWidget {
  final String activePage;

  const AppDrawer({super.key, required this.activePage});

  void _navigateTo(BuildContext context, String targetKey, Widget targetPage) {
    Navigator.pop(context); // Close the drawer first

    if (activePage == targetKey) {
      // Already on this page, do nothing
      return;
    }

    final isRoot = ModalRoute.of(context)?.isFirst ?? false;

    if (targetKey == 'chat') {
      // Navigating back to home screen (root)
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      if (isRoot) {
        // From home screen, push the page
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => targetPage),
        );
      } else {
        // From another page, replace the current page so navigation stack depth remains 2 (Home -> Current)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => targetPage),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.scaffoldBackground,
      child: SafeArea(
        child: Column(
          children: [
            // Gorgeous Premium Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.royalBlue.withValues(alpha: 0.8),
                    AppColors.scaffoldBackground,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.skyBlue.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 30,
                      backgroundImage: AssetImage("assets/images/poonguzhali.png"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Poonguzhali',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Anbu Chellam ❤️',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                children: [
                  _drawerItem(
                    context,
                    key: 'chat',
                    icon: Icons.chat_bubble_rounded,
                    label: 'Chat Room',
                    color: Colors.greenAccent,
                    target: const MyHomePage(),
                  ),
                  const Divider(color: Colors.white10, height: 16),
                  _drawerItem(
                    context,
                    key: 'todo',
                    icon: Icons.task_alt_rounded,
                    label: 'Todo List',
                    color: Colors.cyanAccent,
                    target: const TodoPage(),
                  ),
                  _drawerItem(
                    context,
                    key: 'workout',
                    icon: Icons.fitness_center_rounded,
                    label: 'Workout Tracker',
                    color: AppColors.skyBlue,
                    target: const WorkoutsPage(),
                  ),
                  _drawerItem(
                    context,
                    key: 'analysis',
                    icon: Icons.analytics_rounded,
                    label: 'Financial Analysis',
                    color: Colors.indigoAccent,
                    target: const AnalysisPage(),
                  ),
                  _drawerItem(
                    context,
                    key: 'wallets',
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Wallets',
                    color: AppColors.lightBlueAccent,
                    target: const WalletsPage(),
                  ),
                  _drawerItem(
                    context,
                    key: 'transactions',
                    icon: Icons.swap_horizontal_circle_rounded,
                    label: 'Transactions',
                    color: AppColors.lightBlueAccent,
                    target: const TransactionsPage(),
                  ),
                  _drawerItem(
                    context,
                    key: 'debt',
                    icon: Icons.trending_down_rounded,
                    label: 'Debt Tracker',
                    color: Colors.blueGrey,
                    target: const DebtsPage(),
                  ),
                  _drawerItem(
                    context,
                    key: 'goals',
                    icon: Icons.emoji_events_rounded,
                    label: 'Goals',
                    color: Colors.amber,
                    target: const GoalsPage(),
                  ),
                  _drawerItem(
                    context,
                    key: 'habits',
                    icon: Icons.bolt_rounded,
                    label: 'Habit Tracker',
                    color: Colors.orangeAccent,
                    target: const HabitsPage(),
                  ),
                  _drawerItem(
                    context,
                    key: 'contact',
                    icon: Icons.contacts_rounded,
                    label: 'Contacts',
                    color: Colors.tealAccent,
                    target: const ContactsPage(),
                  ),
                  _drawerItem(
                    context,
                    key: 'diary',
                    icon: Icons.book_rounded,
                    label: 'Personal Diary',
                    color: Colors.purpleAccent,
                    target: const DiariesPage(),
                  ),
                  _drawerItem(
                    context,
                    key: 'reminders',
                    icon: Icons.alarm_rounded,
                    label: 'Reminders & Bdays',
                    color: Colors.redAccent,
                    target: const RemindersPage(),
                  ),
                  _drawerItem(
                    context,
                    key: 'learning',
                    icon: Icons.local_library_rounded,
                    label: 'Learning Corner',
                    color: Colors.lightGreenAccent,
                    target: const LearningsPage(),
                  ),
                  _drawerItem(
                    context,
                    key: 'passwords',
                    icon: Icons.vpn_key_rounded,
                    label: 'Password Manager',
                    color: Colors.amberAccent,
                    target: const PasswordsPage(),
                  ),
                  _drawerItem(
                    context,
                    key: 'documents',
                    icon: Icons.description_rounded,
                    label: 'Documents Vault',
                    color: Colors.blue,
                    target: const DocumentsPage(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required String key,
    required IconData icon,
    required String label,
    required Color color,
    required Widget target,
  }) {
    final isSelected = activePage == key;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: InkWell(
        onTap: () => _navigateTo(context, key, target),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.3)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? color : Colors.white60,
                size: 22,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
