import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Import MyApp to access the themeNotifier

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _saveThemeMode(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode); // Save the theme mode
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
    );
  }
}
