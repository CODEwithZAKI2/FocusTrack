import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:motion_toast/motion_toast.dart'; // Import Motion Toast
import '../database/database_helper.dart';
import 'pomodoro_timer_screen.dart'; // Import PomodoroTimerScreen

class TaskSearchDelegate extends SearchDelegate<Map<String, dynamic>?> {
  final List<Map<String, dynamic>> tasks;

  TaskSearchDelegate(this.tasks);

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildResultsOrSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildResultsOrSuggestions(context);

  Widget _buildResultsOrSuggestions(BuildContext context) {
    final filteredTasks = tasks
        .where((task) => task['title'].toString().toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        return ListTile(
          title: Text(task['title']),
          subtitle: Text(task['description'] ?? ''),
          onTap: () {
            close(context, task);
          },
        );
      },
    );
  }
}

class TaskScreen extends StatefulWidget {
  final String userId; // Pass the logged-in user's ID
  const TaskScreen({super.key, required this.userId});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _pendingTasks = [];
  List<Map<String, dynamic>> _completedTasks = [];
  Map<int, List<Map<String, dynamic>>> _pomodoroSessions = {}; // Map task ID to its Pomodoro sessions
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Initialize TabController
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose(); // Dispose of TabController
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final db = await DatabaseHelper().database;
    final tasks = await db?.query(
      'tasks',
      where: 'user_id = ?',
      whereArgs: [widget.userId],
    ) ?? [];

    // Load Pomodoro sessions for all tasks
    final pomodoroSessions = await db?.query('pomodoro_sessions') ?? [];
    final sessionMap = <int, List<Map<String, dynamic>>>{};
    for (final session in pomodoroSessions) {
      final taskId = session['task_id'] as int;
      sessionMap.putIfAbsent(taskId, () => []).add(session);
    }

    // Load distraction logs for all tasks
    final distractionLogs = await db?.query('distraction_logs') ?? [];
    final distractionMap = <int, List<Map<String, dynamic>>>{};
    for (final log in distractionLogs) {
      final taskId = log['task_id'] as int;
      distractionMap.putIfAbsent(taskId, () => []).add(log);
    }

    setState(() {
      _pendingTasks = tasks
          .where((task) => task['is_done'] == 0)
          .map((task) => {...task}) // Create a mutable copy of the task map
          .toList();
      _completedTasks = tasks
          .where((task) => task['is_done'] == 1)
          .map((task) => {...task}) // Create a mutable copy of the task map
          .toList();
      _pomodoroSessions = sessionMap;

      // Attach distraction logs to each task
      for (final task in _pendingTasks) {
        task['distractions'] = distractionMap[task['id']] ?? [];
      }
      for (final task in _completedTasks) {
        task['distractions'] = distractionMap[task['id']] ?? [];
      }
    });

    debugPrint('Loaded tasks for user ${widget.userId}: Pending: $_pendingTasks, Completed: $_completedTasks');
    debugPrint('Loaded Pomodoro sessions: $_pomodoroSessions');
    debugPrint('Loaded Distraction Logs: $distractionMap');
  }

  Future<void> _toggleTaskStatus(int id, bool isDone) async {
    try {
      final db = await DatabaseHelper().database;
      await db?.update(
        'tasks',
        {'is_done': isDone ? 1 : 0},
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, widget.userId],
      );

      // Display Motion Toast
      if (isDone) {
        MotionToast.success(
          title: const Text('Task Completed'),
          description: const Text('The task has been marked as completed.'),
          animationType: AnimationType.slideInFromTop, // Corrected constant
          position: MotionToastPosition.top,
        ).show(context);
      } else {
        MotionToast.info(
          title: const Text('Task Pending'),
          description: const Text('The task has been marked as pending.'),
          animationType: AnimationType.slideInFromTop, // Corrected constant
          position: MotionToastPosition.top,
        ).show(context);
      }

      _loadTasks(); // Reload tasks to update the UI
    } catch (e) {
      debugPrint('Error toggling task status: $e');
    }
  }

  Future<void> _addOrUpdateTask(int? id, String title, String description) async {
    final task = {
      'id': id ?? DateTime.now().millisecondsSinceEpoch,
      'user_id': widget.userId,
      'title': title,
      'description': description,
      'estimated_pomodoros': 0,
      'is_done': 0,
      'created_at': id == null ? DateTime.now().toIso8601String() : null, // Populate created_at for new tasks
    };

    try {
      final db = await DatabaseHelper().database;

      if (id == null) {
        // Add a new task
        await db?.insert('tasks', task);
      } else {
        // Update an existing task
        await db?.update(
          'tasks',
          task..remove('created_at'), // Remove created_at for updates
          where: 'id = ? AND user_id = ?',
          whereArgs: [id, widget.userId],
        );
      }

      debugPrint('Task ${id == null ? "added" : "updated"} for user ${widget.userId}: $task');
      _loadTasks(); // Reload tasks to update the UI
    } catch (e) {
      debugPrint('Error adding/updating task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save task. Please try again.')),

      );
    }
  }

  Future<void> _deleteTask(int id) async {
    try {
      final db = await DatabaseHelper().database;
      await db?.delete(
        'tasks',
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, widget.userId],
      );

      // Display Motion Toast
      MotionToast.error(
        title: const Text('Task Deleted'),
        description: const Text('The task has been successfully deleted.'),
        animationType: AnimationType.slideInFromTop, // Corrected constant
        position: MotionToastPosition.top,
      ).show(context);

      _loadTasks(); // Reload tasks to update the UI
    } catch (e) {
      debugPrint('Error deleting task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete task. Please try again.')),

      );
    }
  }

  Widget _buildTaskCard(Map<String, dynamic> task, bool isCompleted) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      
      key: Key(task['id'].toString()), // Unique key for each task
      direction: isCompleted ? DismissDirection.none : DismissDirection.startToEnd, // Allow swipe only for pending tasks
      onDismissed: (direction) {
        _toggleTaskStatus(task['id'], true); // Mark as completed
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        color: Colors.green, // Background color for swipe action
        child: const Icon(Icons.check, color: Colors.white, size: 30), // Check icon
      ),
      child: GestureDetector(
        onTap: () => _showTaskDetailsBottomSheet(task), // Show bottom sheet on tap
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: isCompleted
                ? null // No gradient for completed tasks
                : isDarkMode
                    ? null // No gradient in dark mode
                    : const LinearGradient( // Gradient for pending tasks in light mode
                        colors: [Color(0xFFB3E5FC), Color(0xFF81D4FA)], // Light blue gradient
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
            color: isDarkMode
                ? Colors.black // Dark mode: Use black for both pending and completed tasks
                : (isCompleted
                    ? Colors.green[100] // Light mode: Use original green color for completed tasks
                    : null), // Gradient already applied for pending tasks in light mode
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDarkMode
                ? [
                  BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                ] // Red shadow in dark mode
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isCompleted
                      ? (isDarkMode ? Colors.greenAccent : Colors.green)
                      : (isDarkMode ? Colors.blueAccent : Colors.blue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task['description'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isCompleted) // Show delete and timer icons only for pending tasks
                  Row(
                    children: [
                      IconButton(
                        iconSize: 30,
                        icon: Icon(PhosphorIconsBold.timer, color: isDarkMode ? Colors.greenAccent : Colors.green),
                        tooltip: 'Start Pomodoro Timer',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              body: PomodoroTimerScreen(taskId: task['id']),
                              
                            ),
                          ),
                        ).then((_) => _loadTasks()),
                      ),
                      IconButton(
                        iconSize: 30,
                        icon: Icon(PhosphorIconsBold.trash, color: isDarkMode ? Colors.redAccent : Colors.red),
                        tooltip: 'Delete Task',
                        onPressed: () => _deleteTask(task['id']),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTaskDialog({int? id, String? currentTitle, String? currentDescription}) {
    final titleController = TextEditingController(text: currentTitle);
    final descriptionController = TextEditingController(text: currentDescription);

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF232336) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.task_alt_rounded, size: 48, color: Colors.deepPurple.shade300),
                  const SizedBox(height: 10),
                  Text(
                    id == null ? 'Add New Task' : 'Edit Task',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      labelStyle: TextStyle(color: Colors.deepPurple.shade300),
                      filled: true,
                      fillColor: isDark ? Colors.deepPurple.shade900.withOpacity(0.12) : Colors.deepPurple.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descriptionController,
                    maxLines: 5,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: Colors.deepPurple.shade300),
                      filled: true,
                      fillColor: isDark ? Colors.deepPurple.shade900.withOpacity(0.12) : Colors.deepPurple.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                          textStyle: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          final title = titleController.text.trim();
                          final description = descriptionController.text.trim();
                          if (title.isNotEmpty) {
                            _addOrUpdateTask(id, title, description);
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Title cannot be empty')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        child: Text(id == null ? 'Add Task' : 'Update'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTaskDetailsBottomSheet(Map<String, dynamic> task) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF232336) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.deepPurple.shade900 : Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.deepPurple.shade900 : Colors.deepPurple.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            task['is_done'] == 1 ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: task['is_done'] == 1
                                ? (isDarkMode ? Colors.greenAccent : Colors.green)
                                : (isDarkMode ? Colors.blueAccent : Colors.blue),
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task['title'],
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.deepPurple.shade100 : Colors.deepPurple,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                task['description'] ?? '',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              DateFormat('d').format(DateTime.parse(task['created_at'] ?? DateTime.now().toIso8601String())),
                              style: TextStyle(
                                fontSize: 28,
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat('MMM').format(DateTime.parse(task['created_at'] ?? DateTime.now().toIso8601String())),
                              style: TextStyle(
                                fontSize: 16,
                                color: isDarkMode ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            Text(
                              DateFormat('EEEE').format(DateTime.parse(task['created_at'] ?? DateTime.now().toIso8601String())),
                              style: TextStyle(
                                fontSize: 16,
                                color: isDarkMode ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Divider(thickness: 1, color: isDarkMode ? Colors.grey[800] : Colors.grey[300]),
                    const SizedBox(height: 18),
                    _buildPomodoroSessions(task['id']),
                    const SizedBox(height: 18),
                    _buildDistractionLogs(task['id']),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _toggleTaskStatus(task['id'], task['is_done'] == 0);
                          },
                          icon: Icon(
                            task['is_done'] == 0 ? Icons.check : Icons.undo,
                            color: Colors.white,
                          ),
                          label: Text(
                            task['is_done'] == 0 ? 'Mark as Done' : 'Unmark',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: task['is_done'] == 0 ? Colors.green : Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showTaskDialog(
                              id: task['id'],
                              currentTitle: task['title'],
                              currentDescription: task['description'],
                            );
                          },
                          icon: Icon(Icons.edit, color: isDarkMode ? Colors.deepPurple.shade100 : Colors.deepPurple),
                          label: Text(
                            "Edit",
                            style: TextStyle(
                              color: isDarkMode ? Colors.deepPurple.shade100 : Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isDarkMode ? Colors.deepPurple.shade900 : Colors.deepPurple.shade100),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            backgroundColor: isDarkMode ? Colors.deepPurple.shade900.withOpacity(0.08) : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDistractionLogs(int taskId) {
    final task = _pendingTasks.firstWhere(
        (task) => task['id'] == taskId,
        orElse: () => _completedTasks.firstWhere(
            (task) => task['id'] == taskId,
            orElse: () => <String, dynamic>{})); // Return an empty map instead of null

    final distractions = task['distractions'] ?? [];

    if (distractions.isEmpty) {
      return const Text(
        'No distractions logged.',
        style: TextStyle(fontSize: 18, color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Distraction Logs:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...distractions.map((log) {
          final timestamp = DateTime.parse(log['timestamp']);
          final formattedTime = DateFormat('MMM d, h:mm a').format(timestamp);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${log['reason']} - $formattedTime',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70 // Dark mode color
                              : Colors.black87,),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildPomodoroSessions(int taskId) {
    final sessions = _pomodoroSessions[taskId] ?? [];
    if (sessions.isEmpty) {
      return const Text(
        'No Pomodoro sessions logged.',
        style: TextStyle(fontSize: 18, color: Colors.grey),
      );
    }

    final totalPomodoros = sessions.length;
    final dateFormatter = DateFormat('h:mm a'); // Format: 8:53 PM

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.access_time, size: 20, color: Colors.purple),
            const SizedBox(width: 8),
            Text(
              'Pomodoro Sessions (Total: $totalPomodoros)',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sessions.asMap().entries.map((entry) {
            final index = entry.key;
            final session = entry.value;
            final startTime = DateTime.parse(session['start_time']);
            final endTime = DateTime.parse(session['end_time']);
            final backgroundColor = index % 2 == 0 ? Colors.purple.shade50 : Colors.orange.shade50;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF181824) // Dark mode color
                              : backgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🍅', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(
                    '${dateFormatter.format(startTime)} – ${dateFormatter.format(endTime)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70 // Dark mode color
                              : null, // Keep light mode color unchanged
                        ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(
      length: 2, // Two tabs: Pending and Completed
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          title: const Text('Tasks'),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController, // Use the manually created TabController
            indicatorColor: Colors.deepPurple,
            labelColor: Colors.deepPurple,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Pending Tasks', icon: Icon(PhosphorIconsBold.listChecks)),
              Tab(text: 'Completed Tasks', icon: Icon(PhosphorIconsBold.checkCircle)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(PhosphorIconsBold.magnifyingGlass),
              tooltip: 'Search Tasks',
              onPressed: () async {
                final selectedTask = await showSearch<Map<String, dynamic>?>(
                  context: context,
                  delegate: TaskSearchDelegate(_pendingTasks + _completedTasks),
                );

                if (selectedTask != null) {
                  final isCompleted = _completedTasks.contains(selectedTask);
                  setState(() {
                    _tabController.index = isCompleted ? 1 : 0; // Switch to Completed or Pending tab
                  });
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0), // Add margin from the right
              child: IconButton(
                icon: const Icon(PhosphorIconsBold.plusCircle),
                tooltip: 'Add Task',
                onPressed: () => _showTaskDialog(),
              ),
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController, // Use the manually created TabController
          children: [
            // Tab 1: Pending Tasks
            _pendingTasks.isEmpty
                ? const Center(child: Text('No pending tasks.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _pendingTasks.length,
                    itemBuilder: (context, index) {
                      return _buildTaskCard(_pendingTasks[index], false);
                    },
                  ),
            // Tab 2: Completed Tasks
            _completedTasks.isEmpty
                ? const Center(child: Text('No completed tasks.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _completedTasks.length,
                    itemBuilder: (context, index) {
                      return _buildTaskCard(_completedTasks[index], true);
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
