import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart'; // Correctly import the uuid package
import '../../database/database_helper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorMessage;

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final hashedPassword = DatabaseHelper.hashPassword(password); // Ensure this returns a valid string
      final userId = const Uuid().v4(); // Generate a unique ID as a string

      debugPrint('Registering user with:');
      debugPrint('ID: $userId');
      debugPrint('Email: $email');
      debugPrint('Password Hash: $hashedPassword');

      try {
        if (kIsWeb) {
          // Use shared_preferences for web
          await DatabaseHelper().saveUserToPreferences(userId, email, hashedPassword);
        } else {
          // Use sqflite for other platforms
          final db = await DatabaseHelper().database;

          // Print the schema for debugging
          await DatabaseHelper().printUserTableSchema();

          final existingUser = await db?.query(
            'users',
            where: 'email = ?',
            whereArgs: [email],
          );

          if (existingUser != null && existingUser.isNotEmpty) {
            throw Exception('Email already exists.');
          }

          // Ensure all values are non-null and properly formatted
          if (userId.isEmpty || email.isEmpty || hashedPassword.isEmpty) {
            throw Exception('Invalid data: One or more fields are empty.');
          }

          await db?.insert('users', {
            'id': userId, // Ensure id is a string
            'email': email,
            'password_hash': hashedPassword,
          });

          debugPrint('User successfully registered.');
        }
        Navigator.pop(context); // Go back to login screen
      } catch (e) {
        debugPrint('Error during registration: $e');
        setState(() {
          _errorMessage = e.toString().contains('Email already exists.')
              ? 'Email already exists.'
              : 'An error occurred. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDE7F6), // Soft lavender background
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Register',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_errorMessage != null)
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.red,
                          ),
                        ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Enter your email' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                          ),
                        ),
                        obscureText: true,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Enter your password' : null,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _register,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Register',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "I have an account? ",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context), // Navigate back to login
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
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
  }
}
