import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  Future<Database?> get database async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      throw UnsupportedError('sqflite is not supported on web or desktop.');
    }
    if (_database != null) return _database;
    _database = await _initDatabase();
    return _database;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'taskflow.db');

    return await openDatabase(
      path,
      version: 3, // Ensure the version is set to 3 to apply schema changes
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id TEXT PRIMARY KEY, -- Ensure id is of type TEXT
            email TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            description TEXT,
            estimated_pomodoros INTEGER NOT NULL,
            is_done INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, -- Ensure created_at column exists
            FOREIGN KEY(user_id) REFERENCES users(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE pomodoro_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_id INTEGER NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT,
            FOREIGN KEY(task_id) REFERENCES tasks(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE distraction_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_id INTEGER NOT NULL,
            session_id INTEGER,
            timestamp TEXT NOT NULL,
            reason TEXT NOT NULL,
            FOREIGN KEY(task_id) REFERENCES tasks(id),
            FOREIGN KEY(session_id) REFERENCES pomodoro_sessions(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE journal_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          // Check if the journal_entries table already exists
          final existingTables = await db.rawQuery('SELECT name FROM sqlite_master WHERE type="table"');
          final tableExists = existingTables.any((table) => table['name'] == 'journal_entries');

          if (!tableExists) {
            await db.execute('''
              CREATE TABLE journal_entries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                timestamp TEXT NOT NULL
              )
            ''');
          }
        }
      },
    );
  }

  Future<void> deleteDatabaseFile() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'taskflow.db');
    await deleteDatabase(path); // Delete the database file to reset the schema
  }

  Future<void> saveUserToPreferences(String userId, String email, String hashedPassword) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId); // Save the unique user ID
    await prefs.setString('email', email); // Save the email
    await prefs.setString('passwordHash', hashedPassword); // Save the hashed password
  }

  Future<Map<String, String>?> getUserFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId'); // Retrieve the userId
    final email = prefs.getString('email');

    // Debug logs to verify the retrieved values
    print('Retrieved userId: $userId');
    print('Retrieved email: $email');

    if (userId != null && email != null) {
      return {'userId': userId, 'email': email};
    }
    return null;
  }

  Future<void> clearUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId'); // Remove the user ID
    await prefs.remove('email'); // Remove the email
    await prefs.remove('passwordHash'); // Remove the hashed password
  }

  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<void> printUserTableSchema() async {
    final db = await database;
    final schema = await db?.rawQuery('PRAGMA table_info(users)');
    print('Users Table Schema: $schema');
  }

  Future<void> printTasksTableSchema() async {
    final db = await database;
    final schema = await db?.rawQuery('PRAGMA table_info(tasks)');
    print('Tasks Table Schema: $schema');
  }

  Future<void> printJournalTableSchema() async {
    final db = await database;
    final schema = await db?.rawQuery('PRAGMA table_info(journal_entries)');
    print('Journal Entries Table Schema: $schema');
  }

  Future<void> saveDistractionLog({
    required int taskId,
    int? sessionId,
    required String reason,
  }) async {
    final db = await database;
    await db?.insert('distraction_logs', {
      'task_id': taskId,
      'session_id': sessionId,
      'timestamp': DateTime.now().toIso8601String(),
      'reason': reason,
    });
    print('Distraction log saved for task $taskId: $reason');
  }

  Future<List<Map<String, dynamic>>> getDistractionLogsByTaskId(int taskId) async {
    final db = await database;
    return await db?.query(
          'distraction_logs',
          where: 'task_id = ?',
          whereArgs: [taskId],
        ) ??
        [];
  }

  Future<List<Map<String, dynamic>>> getDistractionLogsBySessionId(int sessionId) async {
    final db = await database;
    return await db?.query(
          'distraction_logs',
          where: 'session_id = ?',
          whereArgs: [sessionId],
        ) ??
        [];
  }
}
