import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow/database/database_helper.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart'; // Import SettingsScreen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await DatabaseHelper().deleteDatabaseFile();
  await DatabaseHelper().printTasksTableSchema(); // Print the schema for debugging
  // Initialize sqflite for desktop or web
  if (DatabaseFactory == null) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Load the saved theme mode
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;
  MyApp.themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  // Make themeNotifier static so it can be accessed globally
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'FocusTrack',
          theme: ThemeData(
            fontFamily: 'Poppins', // Updated font family
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            fontFamily: 'Poppins', // Updated font family
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
          ),
          themeMode: themeMode, // Use the current theme mode
          home: const SplashScreen(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const HomeScreen(),
            '/settings': (context) => const SettingsScreen(), // Add the settings route
          },
        );
      },
    );
  }
}
