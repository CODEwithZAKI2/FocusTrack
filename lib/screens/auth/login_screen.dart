import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../../database/database_helper.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorMessage;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final hashedPassword = DatabaseHelper.hashPassword(password);

      debugPrint('Attempting login with email: $email');

      try {
        if (kIsWeb) {
          // Use shared_preferences for web
          final prefs = await SharedPreferences.getInstance();
          final storedEmail = prefs.getString('email');
          final storedPasswordHash = prefs.getString('password_hash');

          debugPrint('Stored email: $storedEmail');
          debugPrint('Stored password hash: $storedPasswordHash');

          if (storedEmail == email && storedPasswordHash == hashedPassword) {
            await prefs.setBool('isLoggedIn', true);
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            setState(() {
              _errorMessage = 'Invalid email or password.';
            });
          }
        } else {
          // Use sqflite for other platforms
          final db = await DatabaseHelper().database;
          final result = await db?.query(
            'users',
            where: 'email = ?',
            whereArgs: [email],
          );

          debugPrint('Query result: $result');

          if (result != null && result.isNotEmpty) {
            final user = result.first;
            final storedPasswordHash = user['password_hash'];

            debugPrint('Stored password hash: $storedPasswordHash');

            if (hashedPassword == storedPasswordHash) {
              final userId = user['id'] as String; // Ensure userId is a string
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isLoggedIn', true);
              await prefs.setString('userId', userId); // Save userId as a string
              await prefs.setString('email', email); // Save email for reference

              debugPrint('Login successful. Saved userId: $userId');

              Navigator.pushReplacementNamed(context, '/home');
            } else {
              setState(() {
                _errorMessage = 'Invalid password.';
              });
            }
          } else {
            setState(() {
              _errorMessage = 'User not found.';
            });
          }
        }
      } catch (e) {
        debugPrint('Error during login: $e');
        setState(() {
          _errorMessage = 'An error occurred. Please try again.';
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
                'Login',
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
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            // Forgot password logic (if any)
                          },
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Log in',
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
                    "Don't have an account? ",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    ),
                    child: const Text(
                      'Register',
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
