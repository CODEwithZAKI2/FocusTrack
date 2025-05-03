import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; // Import audioplayers
import '../database/database_helper.dart';
import 'package:motion_toast/motion_toast.dart'; // Import Motion Toast
import 'package:phosphor_flutter/phosphor_flutter.dart'; // <-- Add this import for beautiful icons

class PomodoroTimerScreen extends StatefulWidget {
  final int taskId; // Link the timer to a specific task
  const PomodoroTimerScreen({super.key, required this.taskId});

  @override
  State<PomodoroTimerScreen> createState() => _PomodoroTimerScreenState();
}

class _PomodoroTimerScreenState extends State<PomodoroTimerScreen> with SingleTickerProviderStateMixin {
  static const int defaultWorkDuration = 30; // Default 30 seconds for work
  static const int defaultBreakDuration = 10; // Default 10 seconds for break

  late int _workDuration;
  late int _breakDuration;
  late int _remainingTime;
  late int _totalTime; // Total time for the current session
  bool _isWorkSession = true; // True for work, false for break
  bool _isRunning = false;
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer(); // Initialize AudioPlayer

  final TextEditingController _workDurationController = TextEditingController();
  final TextEditingController _breakDurationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _workDuration = defaultWorkDuration;
    _breakDuration = defaultBreakDuration;
    _remainingTime = _workDuration;
    _totalTime = _workDuration;

    _workDurationController.text = (_workDuration ~/ 60).toString(); // Default in minutes
    _breakDurationController.text = (_breakDuration ~/ 60).toString(); // Default in minutes
  }

  void _startTimer() {
    if (_timer != null) _timer!.cancel();
    setState(() {
      _isRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });

        // Play a short beep during the last 5 seconds
        if (_remainingTime <= 5 && _remainingTime > 0) {
          await _audioPlayer.play(AssetSource('sounds/short_beep.mp3')); // Short beep sound
        }
      } else {
        _timer!.cancel();
        await _audioPlayer.play(AssetSource('sounds/long_beep.mp3')); // Long beep sound
        _onSessionComplete();
      }
    });
  }

  void _pauseTimer() {
    if (_timer != null) _timer!.cancel();
    setState(() {
      _isRunning = false;
    });

    // Show distraction log modal
    _showDistractionLogModal();
  }

  void _resetTimer() {
    if (_timer != null) _timer!.cancel();
    setState(() {
      _isRunning = false;
      _remainingTime = _isWorkSession ? _workDuration : _breakDuration;
      _totalTime = _remainingTime;
    });
  }

  void _applyDurations() {
    final int workMinutes = int.tryParse(_workDurationController.text) ?? 0;
    final int breakMinutes = int.tryParse(_breakDurationController.text) ?? 0;

    setState(() {
      _workDuration = workMinutes * 60; // Convert minutes to seconds
      _breakDuration = breakMinutes * 60; // Convert minutes to seconds
      _remainingTime = _isWorkSession ? _workDuration : _breakDuration;
      _totalTime = _remainingTime;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Timer durations updated!')),
    );
  }

  Future<void> _onSessionComplete() async {
    if (_isWorkSession) {
      // Automatically save the session
      final startTime = DateTime.now().subtract(Duration(seconds: _workDuration));
      final endTime = DateTime.now();

      await _saveSession(startTime, endTime);

      // Display Motion Toast
      MotionToast.success(
        title: const Text('Session Saved'),
        description: const Text('Your work session has been saved successfully.'),
        animationType: AnimationType.slideInFromTop,
        position: MotionToastPosition.top,
      ).show(context);
    }

    // Switch between work and break sessions
    setState(() {
      _isWorkSession = !_isWorkSession;
      _remainingTime = _isWorkSession ? _workDuration : _breakDuration;
      _totalTime = _remainingTime;
    });
  }

  Future<void> _saveSession(DateTime startTime, DateTime endTime) async {
    try {
      final db = await DatabaseHelper().database;
      await db?.insert('pomodoro_sessions', {
        'task_id': widget.taskId,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
      });
      debugPrint('Pomodoro session saved for task ${widget.taskId}');
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
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

    int _selectedIndex = 0; // Tasks tab

    return WillPopScope(
      onWillPop: () async {
        if (!_isWorkSession) {
          // Allow navigation immediately if it's break time
          return true;
        }
        if (_isRunning) {
          _pauseTimer(); // Pause the timer
        }
        if (_remainingTime > 0 && _totalTime != _remainingTime) {
          // Show the distraction log modal only during work sessions
          final shouldClose = await _showDistractionLogModal();
          return shouldClose; // Close the screen based on user response
        }
        return true; // Allow navigation if the timer hasn't started
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isWorkSession ? 'Work Session' : 'Break Session'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: 1 - (_remainingTime / _totalTime),
                      strokeWidth: 8,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isWorkSession ? Colors.blue : Colors.green,
                      ),
                    ),
                  ),
                  Text(
                    _formatTime(_remainingTime),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _isRunning ? _pauseTimer : _startTimer,
                    child: Text(_isRunning ? 'Pause' : 'Start'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _resetTimer,
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _workDurationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Work (min)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _breakDurationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Break (min)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _applyDurations,
                    child: const Text('Set'),
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
                  onTap: () => Navigator.of(context).pushReplacementNamed('/home'),
                  activeColor: navActive,
                  inactiveColor: navInactive,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_timer != null) _timer!.cancel();
    _audioPlayer.dispose(); // Dispose the AudioPlayer
    _workDurationController.dispose();
    _breakDurationController.dispose();
    super.dispose();
  }

  Future<bool> _showDistractionLogModal() async {
    final TextEditingController distractionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('What distracted you?'),
          content: TextField(
            controller: distractionController,
            decoration: const InputDecoration(
              labelText: 'Reason for distraction',
              hintText: 'e.g., Checked phone, Got a call',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, true); // Close the dialog and allow screen close
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = distractionController.text.trim();
                if (reason.isNotEmpty) {
                  await _saveDistractionLog(reason);
                  MotionToast.success(
                    title: const Text('Distraction Logged'),
                    description: const Text('Your distraction has been logged successfully.'),
                    animationType: AnimationType.slideInFromTop,
                    position: MotionToastPosition.top,
                  ).show(context);
                }
                Navigator.pop(context, true); // Close the dialog and allow screen close
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    return result ?? false; // Return true to close the screen, false otherwise
  }

  Future<void> _saveDistractionLog(String reason) async {
    try {
      final db = await DatabaseHelper().database;
      await db?.insert('distraction_logs', {
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
        'task_id': widget.taskId, // Save the task ID to link the log to the task
        'session_id': null, // Set to null for now; can be linked to a session later
      });
      debugPrint('Distraction logged for task ${widget.taskId}: $reason');
    } catch (e) {
      debugPrint('Error saving distraction log: $e');
    }
  }
}

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
