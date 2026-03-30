import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'add_task.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: TasksScreen(),
    );
  }
}

// Need mutable state, since tasks view will change
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

// Internal state management, logic for the Tasks Screen widget
class _TasksScreenState extends State<TasksScreen> {

  // List tasks = [];
  bool isLoading = true;

  // Add state variables for searching and filtering
  List allTasks = [];
  List filteredTasks = [];

  String searchQuery = '';
  String selectedStatus = 'all';

  // Loading state variables
  bool isCreating = false;
  bool isUpdating = false;

  // Input controllers for title, description, due date
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController dueDateController = TextEditingController();

  // Add state for selected blocked by task
  int? selectedBlockedBy;

  @override
  void initState() {
    super.initState();
    fetchTasks();
    loadDraft();
  }

  // GET /tasks
  Future<void> fetchTasks() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/tasks'),
      );

      if (response.statusCode == 200) {
        setState(() {
          allTasks = jsonDecode(response.body);
          applyFilters();
          isLoading = false;   // ✅ IMPORTANT
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print(e);
      setState(() {
        isLoading = false;
      });
    }
  }

  // Filter function
  void applyFilters() {
    setState(() {
      filteredTasks = allTasks.where((task) {
        // being very safe - cast to string
        final matchesSearch = (task['title'] ?? '').toString().toLowerCase().contains(searchQuery.toLowerCase());

        final matchesStatus = selectedStatus == 'all' || task['status'] == selectedStatus;

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  // POST /create - create a new task
  Future<void> createTask() async {

    // prevent double tap
    if (isCreating) return;

    setState(() {
      isCreating = true;
    });

    // ui updates first
    await Future.delayed(Duration.zero);

    // 2 second delay
    await Future.delayed(const Duration(seconds: 2));

    final response = await http.post(
      Uri.parse('http://localhost:5000/create'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "title": titleController.text,
        "description": descriptionController.text,
        "due_date": dueDateController.text,
        "status": "to-do",
        "blocked_by": selectedBlockedBy,
      })
    );

    // If resource is created
    if (response.statusCode == 201) {
      // clear the input fields
      titleController.clear();
      descriptionController.clear();
      dueDateController.clear();

      
      // clear drafts
      await clearDraft();
      
      // refresh list of tasks rendered
      await fetchTasks();

      // reset blocked by
      selectedBlockedBy = null;

    } else {
      // Temporary
      print('Failed to create task: ${response.body}');
    }

    // modify to implement loading state
    setState(() {
      isCreating = false;
    });
  }

  // POST /delete
  Future<void> deleteTask(int id) async {
    final response = await http.post(
      Uri.parse('http://localhost:5000/delete'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"id": id}),
    );

    // Success
    if (response.statusCode == 200) {
      // refresh tasks list
      fetchTasks();
    } else {
      // Temporary print
      print('Failed to delete task: ${response.body}');
    }
  }

  // add update dialog - on tap, ability to update task
  void showUpdateDialog(Map task) {

    final titleController = TextEditingController(text: task['title']);
    final descriptionController = TextEditingController(text: task['description']);
    final dueDateController = TextEditingController(text: task['due_date']);
    String status = task['status'];

    int? blockedBy = task['blocked_by'];

  // add update dialog above app
  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Update Task'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  TextField(
                    controller: dueDateController,
                    decoration: const InputDecoration(labelText: 'Due Date'),
                  ),
                  DropdownButton<String>(
                    value: status,
                    items: const [
                      DropdownMenuItem(value: "to-do", child: Text("To-Do")),
                      DropdownMenuItem(value: "in progress", child: Text("In Progress")),
                      DropdownMenuItem(value: "done", child: Text("Done")),
                    ],
                    onChanged: (value) {
                      setState(() {
                        status = value!;
                      });
                      // status = value!;
                    },
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: blockedBy,
                    decoration: const InputDecoration(
                      labelText: 'Blocked By',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...allTasks
                      .where((t) => t['td'] != task['td']) // exclude itself
                      .map((t) {
                        return DropdownMenuItem<int>(
                          value: t['id'],
                          child: Text(t['title']),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        blockedBy = value;
                      });
                    },
                  )
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          // Update dialog save button
          ElevatedButton(
            onPressed: isUpdating
                      ? null
                      : () async {
                        await updateTask(
                          task['id'],
                          titleController.text,
                          descriptionController.text,
                          dueDateController.text,
                          status,
                          blockedBy
                        );
                        Navigator.pop(context);
                      },
            child: isUpdating
                  ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Save'),
          ),
        ],
      );
        },
      );
      
    },
  );
}

  // POST /update 
  Future<void> updateTask(
    int id,
    String title,
    String description,
    String dueDate,
    String status,
    int? blockedBy,
  ) async {

    // Update
    if (isUpdating) return;

    // Change state
    setState(() {
      isUpdating = true;
    });

    // Add 2 seconds delay
    await Future.delayed(const Duration(seconds: 2));
    
    final response = await http.post(
      Uri.parse('http://localhost:5000/update'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "id": id,
        "title": title,
        "description": description,
        "due_date": dueDate,
        "status": status,
        "blocked_by": blockedBy,
      }),
    );

    if (response.statusCode == 200) {
      await fetchTasks(); // refresh list
    } else {
      print("Failed to update task: ${response.body}");
    }

    setState(() {
      isUpdating = false;
    });
  }

  // Save drafts on change
  void saveDraft() async {
    final preferences = await SharedPreferences.getInstance();

    preferences.setString('title', titleController.text);
    preferences.setString('description', descriptionController.text);
    preferences.setString('due_date', dueDateController.text);
  }

  // Load drafts
  Future<void> loadDraft() async {
    final preferences = await SharedPreferences.getInstance();

    titleController.text = preferences.getString('title') ?? '';
    descriptionController.text = preferences.getString('description') ?? '';
    dueDateController.text = preferences.getString('due_date') ?? '';
  }

  // Clear all drafts
  Future<void> clearDraft() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove('title');
    await preferences.remove('description');
    await preferences.remove('due_date');
  }

  // helper method for separate task creation screen
  Future<void> createTaskFromData(Map data) async {
    if (isCreating) return;

    setState(() {
      isCreating = true;
    });

    await Future.delayed(Duration.zero);
    await Future.delayed(const Duration(seconds: 2));

    final response = await http.post(
      Uri.parse('http://localhost:5000/create'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );

    if (response.statusCode == 201) {
      await fetchTasks();
    }

    setState(() {
      isCreating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
        centerTitle: true,
      ),
      body: Column(
              children: [
    // 
    SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search and filter
            const Text(
              'Search & Filter',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            TextField(
              decoration: const InputDecoration(
                labelText: 'Search by title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                searchQuery = value;
                applyFilters();
              },
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              // value: selectedStatus,
              initialValue: selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Filter by status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'to-do', child: Text('To-Do')),
                DropdownMenuItem(value: 'in progress', child: Text('In Progress')),
                DropdownMenuItem(value: 'done', child: Text('Done')),
              ],
              onChanged: (value) {
                selectedStatus = value!;
                applyFilters();
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    ),

    // All tasks list
    Expanded(
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredTasks.isEmpty
              ? const Center(child: Text('No tasks found'))
              : ListView.builder(
                  itemCount: filteredTasks.length,
                  itemBuilder: (context, index) {
                    final task = filteredTasks[index];

                    // compute isBlocked
                    final blockingTask = allTasks.firstWhere(
                      (t) => t['id'] == task['blocked_by'],
                      orElse: () => {},
                    );

                    final isBlocked = task['blocked_by'] != null && (blockingTask.isEmpty || blockingTask['status'] != 'done');

                    return Opacity(
                      opacity: isBlocked ? 0.6 : 1.0,
                      child: Card(
                        color: isBlocked ? Colors.grey[300] : null,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text(
                            task['title'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(task['description']),
                              const SizedBox(height: 4),
                              Text(
                                task['status'],
                                style: TextStyle(
                                  color: task['status'] == 'done'
                                      ? Colors.green
                                      : task['status'] == 'in progress'
                                          ? Colors.orange
                                          : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => showUpdateDialog(task),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => deleteTask(task['id']),
                          ),
                        ),
                      )
                      );
                  },
                ),
    ),
  ],
),
  floatingActionButton: FloatingActionButton(
    onPressed: () async {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddTaskScreen(allTasks: allTasks),),
      );

      if (result != null) {
        await createTaskFromData(result);
      }

    // fetchTasks();
    },
    child: const Icon(Icons.add),
  ),
    );
  }
}
