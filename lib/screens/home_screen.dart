import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:taskflow/screens/dashboard_screen.dart';
import 'package:taskflow/screens/journal_screen.dart';
import 'package:taskflow/screens/profile_screen.dart';
import '../main.dart'; // Import MyApp to access the themeNotifier
import 'task_screen.dart'; // Import TaskScreen
import 'settings_screen.dart'; // Import the SettingsScreen
import '../database/database_helper.dart'; // Import DatabaseHelper
import 'package:phosphor_flutter/phosphor_flutter.dart'; // <-- Add this import for beautiful icons

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // Track the selected index

  final List<Widget> _screens = [
    const TaskScreen(userId: ''), // Placeholder for TaskScreen
    const JournalScreen(), // Placeholder for Journal
    const DashboardScreen(), // Use the new DashboardScreen here
    const ProfileScreen(), // Placeholder for Profile
  ];

  Future<void> _openSettings(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await DatabaseHelper().clearUserPreferences(); // Clear login details
    Navigator.pushReplacementNamed(context, '/login'); // Navigate to login screen
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF232336) : Colors.white;
    final navActive = isDark ? Colors.deepPurpleAccent : const Color(0xFF6C4DFF);
    final navInactive = isDark ? Colors.white70 : const Color(0xFFB6A7E6);
    final navShadow = isDark
        ? [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.18),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ];

    return Scaffold(
      body: FutureBuilder<Map<String, String>?>( 
        future: DatabaseHelper().getUserFromPreferences(), // Retrieve user preferences
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator()); // Show loading indicator
          }
          if (snapshot.hasData && snapshot.data != null) {
            final userId = snapshot.data!['userId']!;
            return _currentIndex == 0
                ? TaskScreen(userId: userId) // Pass the correct userId to TaskScreen
                : _screens[_currentIndex]; // Show other screens
          }
          return const Center(child: Text('Error loading user data.'));
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: navShadow,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavBarItem(
                icon: PhosphorIconsBold.checkCircle, // Tasks
                label: "Tasks",
                selected: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
                activeColor: navActive,
                inactiveColor: navInactive,
              ),
              _NavBarItem(
                icon: PhosphorIconsBold.bookBookmark, // Journal
                label: "Journal",
                selected: _currentIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
                activeColor: navActive,
                inactiveColor: navInactive,
              ),
              _NavBarItem(
                icon: PhosphorIconsBold.chartBar, // Dashboard
                label: "Dashboard",
                selected: _currentIndex == 2,
                onTap: () => setState(() => _currentIndex = 2),
                activeColor: navActive,
                inactiveColor: navInactive,
              ),
              _NavBarItem(
                icon: PhosphorIconsBold.userCircle, // Profile
                label: "Profile",
                selected: _currentIndex == 3,
                onTap: () => setState(() => _currentIndex = 3),
                activeColor: navActive,
                inactiveColor: navInactive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom nav bar item widget
class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? activeColor.withOpacity(0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: selected ? 30 : 26,
                color: selected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: selected ? 14 : 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? activeColor : inactiveColor,
                  letterSpacing: 0.1,
                ),
                child: Text(label),
              ),
              if (selected)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  height: 3,
                  width: 18,
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
