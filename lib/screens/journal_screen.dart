import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  List<Map<String, dynamic>> _journalEntries = [];

  @override
  void initState() {
    super.initState();
    _loadJournalEntries();
  }

  Future<void> _loadJournalEntries() async {
    final db = await DatabaseHelper().database;
    final entries = await db?.query('journal_entries', orderBy: 'timestamp DESC') ?? [];
    setState(() {
      _journalEntries = entries;
    });
  }

  Future<void> _addOrUpdateJournalEntry({int? id, String? currentTitle, String? currentContent}) async {
    final titleController = TextEditingController(text: currentTitle);
    final contentController = TextEditingController(text: currentContent);
    String selectedMood = '📝';
    final moods = ['😊', '😐', '😢', '😎', '😴', '📝'];

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    id == null ? 'New Journal Entry' : 'Edit Journal Entry',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Mood selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: moods.map((mood) {
                      final isSelected = selectedMood == mood;
                      return GestureDetector(
                        onTap: () {
                          selectedMood = mood;
                          (context as Element).markNeedsBuild();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.deepPurple.shade50 : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            mood,
                            style: TextStyle(fontSize: isSelected ? 28 : 24),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  // Title
                  TextField(
                    controller: titleController,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      labelStyle: TextStyle(color: Colors.deepPurple.shade300),
                      filled: true,
                      fillColor: Colors.deepPurple.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Content
                  TextField(
                    controller: contentController,
                    maxLines: 7,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'What\'s on your mind?',
                      labelStyle: TextStyle(color: Colors.deepPurple.shade300),
                      filled: true,
                      fillColor: Colors.deepPurple.shade50,
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
                        onPressed: () async {
                          final title = titleController.text.trim();
                          final content = contentController.text.trim();
                          if (title.isNotEmpty && content.isNotEmpty) {
                            final db = await DatabaseHelper().database;
                            final entry = {
                              'title': title,
                              'content': content,
                              'timestamp': DateTime.now().toIso8601String(),
                              'mood': selectedMood,
                            };
                            if (id == null) {
                              await db?.insert('journal_entries', entry);
                            } else {
                              await db?.update('journal_entries', entry, where: 'id = ?', whereArgs: [id]);
                            }
                            Navigator.pop(context);
                            _loadJournalEntries();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        child: Text(id == null ? 'Save' : 'Update'),
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

  Future<void> _deleteJournalEntry(int id) async {
    final db = await DatabaseHelper().database;
    await db?.delete('journal_entries', where: 'id = ?', whereArgs: [id]);
    _loadJournalEntries();
  }

  void _showJournalDetail(Map<String, dynamic> entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final date = DateTime.parse(entry['timestamp']);
        final mood = entry['mood'] ?? '📝';
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF232336) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.deepPurple.shade900 : Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.deepPurple.shade900 : Colors.deepPurple.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            mood,
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry['title'],
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.deepPurple.shade100 : Colors.deepPurple,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                DateFormat('EEEE, MMM d, yyyy • h:mm a').format(date),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.deepPurple.shade200.withOpacity(0.8) : Colors.deepPurple.shade200,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      entry['content'],
                      style: TextStyle(
                        fontSize: 18,
                        color: isDark ? Colors.grey[100] : Colors.black87,
                        height: 1.6,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _addOrUpdateJournalEntry(
                              id: entry['id'],
                              currentTitle: entry['title'],
                              currentContent: entry['content'],
                            );
                          },
                          icon: Icon(Icons.edit, color: isDark ? Colors.deepPurple.shade100 : Colors.deepPurple),
                          label: Text('Edit', style: TextStyle(color: isDark ? Colors.deepPurple.shade100 : Colors.deepPurple)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isDark ? Colors.deepPurple.shade900 : Colors.deepPurple.shade100),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            backgroundColor: isDark ? Colors.deepPurple.shade900.withOpacity(0.08) : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _deleteJournalEntry(entry['id']);
                          },
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          label: const Text('Delete', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade100),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            backgroundColor: isDark ? Colors.red.shade900.withOpacity(0.08) : null,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        elevation: 0,
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
        foregroundColor: Colors.deepPurple,
        centerTitle: true,
      ),
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF181824) : const Color(0xFFF6F6F9),
      body: _journalEntries.isEmpty
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book_rounded, size: 80, color: Colors.deepPurple.shade100),
                const SizedBox(height: 16),
                Text(
                  'No journal entries yet.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.deepPurple.shade200.withOpacity(0.7)
                        : Colors.deepPurple.shade200,
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              itemCount: _journalEntries.length,
              itemBuilder: (context, index) {
                final entry = _journalEntries[index];
                final date = DateTime.parse(entry['timestamp']);
                final mood = entry['mood'] ?? '📝';

                // Show a date label if this is the first entry of a new day
                bool showDateLabel = true;
                if (index > 0) {
                  final prevDate = DateTime.parse(_journalEntries[index - 1]['timestamp']);
                  showDateLabel = !(date.year == prevDate.year &&
                                    date.month == prevDate.month &&
                                    date.day == prevDate.day);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDateLabel)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.deepPurple.withOpacity(0.18)
                                : Colors.deepPurple.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          child: Text(
                            DateFormat('EEEE, MMM d, yyyy').format(date),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.deepPurple.shade100
                                  : Colors.deepPurple,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ),
                    InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _showJournalDetail(entry),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: Theme.of(context).brightness == Brightness.dark
                              ? null
                              : LinearGradient(
                                  colors: [
                                    Colors.deepPurple.shade50,
                                    Colors.white,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[900]
                              : null,
                          boxShadow: [
                            if (Theme.of(context).brightness == Brightness.light)
                              BoxShadow(
                                color: Colors.deepPurple.withOpacity(0.07),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Mood emoji
                              Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.deepPurple.shade900
                                      : Colors.deepPurple.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  mood,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                              const SizedBox(width: 18),
                              // Main content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title
                                    Text(
                                      entry['title'],
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.deepPurple.shade100
                                            : Colors.deepPurple.shade700,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    // Content preview
                                    Text(
                                      entry['content'].toString().length > 80
                                          ? '${entry['content'].toString().substring(0, 80)}...'
                                          : entry['content'],
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade800,
                                        fontWeight: FontWeight.w400,
                                        height: 1.4,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 10),
                                    // Date and time
                                    Row(
                                      children: [
                                        Icon(Icons.access_time_rounded, size: 16, color: Colors.deepPurple.shade200),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat('EEE, MMM d • h:mm a').format(date),
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? Colors.deepPurple.shade200.withOpacity(0.7)
                                                : Colors.deepPurple.shade200,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Chevron
                              const SizedBox(width: 10),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.deepPurple.shade200.withOpacity(0.7)
                                    : Colors.deepPurple.shade200,
                                size: 28,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrUpdateJournalEntry(),
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.add),
        label: const Text('New Entry', style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 4,
      ),
    );
  }
}
