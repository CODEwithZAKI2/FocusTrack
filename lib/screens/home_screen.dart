import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:taskflow/screens/profile_screen.dart';
import '../main.dart'; // Import MyApp to access the themeNotifier
import 'task_screen.dart'; // Import TaskScreen
import 'settings_screen.dart'; // Import the SettingsScreen
import '../database/database_helper.dart'; // Import DatabaseHelper

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // Track the selected index

  final List<Widget> _screens = [
    const TaskScreen(userId: ''), // Placeholder for TaskScreen
    Center(child: Text('Journal')), // Placeholder for Journal
    Center(child: Text('Books')), // Placeholder for Books
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
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: Colors.transparent,
        color: Theme.of(context).primaryColor,
        buttonBackgroundColor: Theme.of(context).primaryColor,
        height: 60,
        items: const [
          Icon(Icons.task, size: 30, color: Colors.white), // Tasks
          Icon(Icons.book, size: 30, color: Colors.white), // Journal
          Icon(Icons.menu_book, size: 30, color: Colors.white), // Books
          Icon(Icons.person, size: 30, color: Colors.white), // Profile
        ],
        index: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
