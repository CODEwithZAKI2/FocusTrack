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

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(id == null ? 'New Journal Entry' : 'Edit Journal Entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contentController,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Content'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
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
              child: Text(id == null ? 'Save' : 'Update'),
            ),
          ],
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry['title'],
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(entry['timestamp'])),
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Text(
                entry['content'],
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _addOrUpdateJournalEntry(
                        id: entry['id'],
                        currentTitle: entry['title'],
                        currentContent: entry['content'],
                      );
                    },
                    child: const Text('Edit'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteJournalEntry(entry['id']);
                    },
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
      ),
      body: _journalEntries.isEmpty
          ? const Center(child: Text('No journal entries yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _journalEntries.length,
              itemBuilder: (context, index) {
                final entry = _journalEntries[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () => _showJournalDetail(entry),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry['title'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              Text(
                                DateFormat('MMM d, yyyy').format(DateTime.parse(entry['timestamp'])),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            entry['content'].toString().length > 50
                                ? '${entry['content'].toString().substring(0, 50)}...'
                                : entry['content'],
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.edit, size: 16, color: Colors.deepPurple),
                              const SizedBox(width: 4),
                              Text(
                                'Tap to view details',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.deepPurple,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrUpdateJournalEntry(),
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}
