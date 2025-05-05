import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:math';
import '../database/database_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int totalTasks = 0;
  int completedTasks = 0;
  int pendingTasks = 0;
  int totalPomodoros = 0;
  int pomodorosToday = 0;
  int totalDistractions = 0;
  Map<String, int> distractionReasons = {};
  List<Map<String, dynamic>> moodTrends = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final db = await DatabaseHelper().database;

    // Tasks
    final tasks = await db?.query('tasks') ?? [];
    totalTasks = tasks.length;
    completedTasks = tasks.where((t) => t['is_done'] == 1).length;
    pendingTasks = tasks.where((t) => t['is_done'] == 0).length;

    // Pomodoro
    final pomodoros = await db?.query('pomodoro_sessions') ?? [];
    totalPomodoros = pomodoros.length;
    final today = DateTime.now();
    pomodorosToday = pomodoros.where((p) {
      final start = DateTime.parse(p['start_time'] as String);
      return start.year == today.year && start.month == today.month && start.day == today.day;
    }).length;

    // Distractions
    final distractions = await db?.query('distraction_logs') ?? [];
    totalDistractions = distractions.length;
    distractionReasons.clear();
    for (final d in distractions) {
      final reason = (d['reason'] ?? '').toString();
      if (reason.isNotEmpty) {
        distractionReasons[reason] = (distractionReasons[reason] ?? 0) + 1;
      }
    }

    // Journal Mood Trends
    final journals = await db?.query('journal_entries', orderBy: 'timestamp ASC') ?? [];
    moodTrends = journals
        .map((e) => {
              'date': DateTime.parse(e['timestamp'] as String),
              'mood': (e['mood'] ?? '📝').toString(),
            })
        .toList();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF232336) : Colors.white;
    final accent = isDark ? Colors.deepPurpleAccent : Colors.deepPurple;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: accent,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: isDark ? const Color(0xFF181824) : const Color(0xFFF6F6F9),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          children: [
            // Productivity Overview
            _DashboardSection(
              title: "Productivity Overview",
              icon: PhosphorIconsBold.trendUp,
              children: [
                Row(
                  children: [
                    _StatCard(
                      icon: PhosphorIconsBold.checkCircle,
                      label: "Completed",
                      value: completedTasks,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 16),
                    _StatCard(
                      icon: PhosphorIconsBold.clockCountdown,
                      label: "Pending",
                      value: pendingTasks,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 16),
                    _StatCard(
                      icon: PhosphorIconsBold.listChecks,
                      label: "Total",
                      value: totalTasks,
                      color: accent,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: totalTasks == 0 ? 0 : completedTasks / totalTasks,
                  backgroundColor: isDark ? Colors.deepPurple.shade900 : Colors.deepPurple.shade50,
                  color: accent,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 8),
                Text(
                  "${((totalTasks == 0 ? 0 : completedTasks / totalTasks * 100)).toStringAsFixed(1)}% tasks completed",
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            // Pomodoro Analytics
            _DashboardSection(
              title: "Pomodoro Analytics",
              icon: PhosphorIconsBold.timer,
              children: [
                Row(
                  children: [
                    _StatCard(
                      icon: PhosphorIconsBold.timer,
                      label: "Total Pomodoros",
                      value: totalPomodoros,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 16),
                    _StatCard(
                      icon: PhosphorIconsBold.sun,
                      label: "Today",
                      value: pomodorosToday,
                      color: Colors.orangeAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Pomodoro trend (last 7 days)
                _PomodoroTrendChart(),
              ],
            ),
            // Distraction Analysis
            _DashboardSection(
              title: "Distraction Analysis",
              icon: PhosphorIconsBold.warningCircle,
              children: [
                Row(
                  children: [
                    _StatCard(
                      icon: PhosphorIconsBold.warningCircle,
                      label: "Total",
                      value: totalDistractions,
                      color: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (distractionReasons.isEmpty)
                  Text("No distractions logged.", style: TextStyle(color: Colors.grey[600]))
                else
                  _DistractionPieChart(distractionReasons: distractionReasons),
              ],
            ),
            // Journal Mood Trends
            _DashboardSection(
              title: "Journal Mood Trends",
              icon: PhosphorIconsBold.smiley,
              children: [
                if (moodTrends.isEmpty)
                  Text("No journal entries.", style: TextStyle(color: Colors.grey[600]))
                else
                  _MoodTrendChart(moodTrends: moodTrends),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _DashboardSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232336) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.deepPurple, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 0),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? color.withOpacity(0.13) : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Pomodoro trend chart (last 7 days, simple bar chart)
class _PomodoroTrendChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getPomodoroCountsPerDay(),
      builder: (context, snapshot) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final barColor = Colors.deepPurple;
        final bgColor = isDark
            ? Colors.deepPurple.shade900.withOpacity(0.13)
            : Colors.deepPurple.shade50;

        List<int> counts = List.filled(7, 0);
        List<String> days = List.generate(
          7,
          (i) => DateFormat('E').format(DateTime.now().subtract(Duration(days: 6 - i))),
        );

        if (snapshot.hasData) {
          // Map weekday (1=Mon, ..., 7=Sun) to count
          final data = snapshot.data!;
          Map<int, int> dayMap = {};
          for (final row in data) {
            final weekday = row['weekday'] as int;
            final count = row['count'] as int;
            dayMap[weekday] = count;
          }
          // Fill counts for last 7 days
          for (int i = 0; i < 7; i++) {
            final date = DateTime.now().subtract(Duration(days: 6 - i));
            final weekday = date.weekday; // 1=Mon, ..., 7=Sun
            counts[i] = dayMap[weekday] ?? 0;
          }
        }

        final maxCount = counts.isEmpty ? 1 : (counts.reduce((a, b) => a > b ? a : b)).clamp(1, 8);

        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: List.generate(7, (i) {
              return Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: counts[i] == 0 ? 8 : (counts[i] / maxCount) * 60 + 8,
                      width: 14,
                      decoration: BoxDecoration(
                        color: counts[i] == 0
                            ? barColor.withOpacity(0.18)
                            : barColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      days[i],
                      style: TextStyle(
                        fontSize: 11,
                        color: barColor.withOpacity(counts[i] == 0 ? 0.4 : 1),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (counts[i] > 0)
                      Text(
                        counts[i].toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: barColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getPomodoroCountsPerDay() async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 6));
    // SQLite: strftime('%w', ...) gives 0=Sunday, 1=Monday, ..., 6=Saturday
    // Dart: DateTime.weekday is 1=Monday, ..., 7=Sunday
    final result = await db?.rawQuery('''
      SELECT 
        CAST(STRFTIME('%w', start_time) AS INTEGER) AS sqlite_weekday,
        COUNT(*) as count
      FROM pomodoro_sessions
      WHERE DATE(start_time) >= DATE(?)
      GROUP BY sqlite_weekday
    ''', [weekAgo.toIso8601String()]) ?? [];

    // Map SQLite weekday to Dart weekday
    // SQLite: 0=Sun, 1=Mon, ..., 6=Sat
    // Dart:   1=Mon, ..., 7=Sun
    return result.map((row) {
      int sqliteWeekday = row['sqlite_weekday'] as int;
      int dartWeekday = sqliteWeekday == 0 ? 7 : sqliteWeekday;
      return {
        'weekday': dartWeekday,
        'count': row['count'] as int,
      };
    }).toList();
  }
}

// Mood trend chart (emoji line)
class _MoodTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> moodTrends;

  const _MoodTrendChart({required this.moodTrends});

  @override
  Widget build(BuildContext context) {
    final last7 = moodTrends.length > 7 ? moodTrends.sublist(moodTrends.length - 7) : moodTrends;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.deepPurple.shade900.withOpacity(0.13)
            : Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: last7.map((e) {
          final date = e['date'] as DateTime;
          final mood = e['mood'] as String;
          return Column(
            children: [
              Text(
                mood,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('E').format(date),
                style: const TextStyle(fontSize: 11, color: Colors.deepPurple),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _DistractionPieChart extends StatelessWidget {
  final Map<String, int> distractionReasons;
  const _DistractionPieChart({required this.distractionReasons});

  @override
  Widget build(BuildContext context) {
    final total = distractionReasons.values.fold<int>(0, (a, b) => a + b);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Color> pieColors = [
      Colors.deepPurple,
      Colors.orange,
      Colors.green,
      Colors.red,
      Colors.blue,
      Colors.purple,
      Colors.teal,
      Colors.amber,
    ];

    final reasons = distractionReasons.entries.toList();
    final double size = 120;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _PieChartPainter(
                data: reasons.map((e) => e.value).toList(),
                colors: pieColors,
              ),
              child: Center(
                child: Text(
                  '$total',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: isDark ? Colors.white : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...reasons.asMap().entries.map((entry) {
          final idx = entry.key;
          final e = entry.value;
          final percent = total == 0 ? 0 : (e.value / total * 100);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: pieColors[idx % pieColors.length],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.key,
                    style: TextStyle(
                      color: isDark ? Colors.deepPurple.shade100 : Colors.deepPurple.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${e.value} (${percent.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    color: isDark ? Colors.deepPurple.shade100 : Colors.deepPurple.shade700,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<int> data;
  final List<Color> colors;

  _PieChartPainter({required this.data, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.fold<int>(0, (a, b) => a + b);
    if (total == 0) return;
    double startRadian = -pi / 2;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final sweep = (data[i] / total) * 2 * pi;
      paint.color = colors[i % colors.length];
      canvas.drawArc(rect, startRadian, sweep, true, paint);
      startRadian += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
