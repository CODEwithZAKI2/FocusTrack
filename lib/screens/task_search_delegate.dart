import 'package:flutter/material.dart';

class TaskSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> tasks;

  TaskSearchDelegate(this.tasks);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = ''; // Clear the search query
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null); // Close the search box
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = tasks
        .where((task) =>
            task['title'].toLowerCase().contains(query.toLowerCase()) ||
            task['description'].toLowerCase().contains(query.toLowerCase()))
        .toList();

    if (results.isEmpty) {
      return const Center(
        child: Text('No tasks found.'),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final task = results[index];
        return ListTile(
          title: Text(task['title']),
          subtitle: Text(task['description'] ?? ''),
          onTap: () {
            close(context, task); // Close the search and return the selected task
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = tasks
        .where((task) =>
            task['title'].toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final task = suggestions[index];
        return ListTile(
          title: Text(task['title']),
          onTap: () {
            query = task['title']; // Update the search query
            showResults(context); // Show the search results
          },
        );
      },
    );
  }
}
