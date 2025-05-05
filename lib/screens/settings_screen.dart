import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart'; // <-- Add this import for beautiful icons
import '../main.dart'; // Import MyApp to access the themeNotifier

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _saveThemeMode(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode); // Save the theme mode
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF232336) : Colors.white;
    final navActive = isDark ? Colors.deepPurpleAccent : Colors.deepPurple;
    final navInactive = isDark ? Colors.white70 : Colors.deepPurple.shade200;
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

    int _selectedIndex = 3; // Profile/Settings tab

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Theme',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Dark Mode'),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: MyApp.themeNotifier,
                  builder: (context, themeMode, child) {
                    return Switch(
                      value: themeMode == ThemeMode.dark,
                      onChanged: (bool isDarkMode) {
                        MyApp.themeNotifier.value =
                            isDarkMode ? ThemeMode.dark : ThemeMode.light;
                        _saveThemeMode(isDarkMode); // Save the theme mode
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
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
                icon: PhosphorIconsBold.checkCircle,
                label: "Tasks",
                selected: _selectedIndex == 0,
                onTap: () => Navigator.of(context).pushReplacementNamed('/home'),
                activeColor: navActive,
                inactiveColor: navInactive,
              ),
              _NavBarItem(
                icon: PhosphorIconsBold.bookBookmark,
                label: "Journal",
                selected: _selectedIndex == 1,
                onTap: () => Navigator.of(context).pushReplacementNamed('/home'),
                activeColor: navActive,
                inactiveColor: navInactive,
              ),
              _NavBarItem(
                icon: PhosphorIconsBold.chartBar,
                label: "Dashboard",
                selected: _selectedIndex == 2,
                onTap: () => Navigator.of(context).pushReplacementNamed('/home'),
                activeColor: navActive,
                inactiveColor: navInactive,
              ),
              _NavBarItem(
                icon: PhosphorIconsBold.userCircle,
                label: "Profile",
                selected: _selectedIndex == 3,
                onTap: () {}, // Already on settings/profile
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

// Custom nav bar item widget (copied from home_screen for consistency)
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
            color: selected ? activeColor.withOpacity(0.08) : Colors.transparent,
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
