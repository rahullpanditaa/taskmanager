import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
        "blocked_by": null,
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
                          status
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
        "blocked_by": null,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Column(
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

                  // Add a new task
                  const Text(
                    'Add Task',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                    onChanged: (_) => saveDraft(),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description', 
                      border: OutlineInputBorder()
                    ),
                    onChanged: (_) => saveDraft(),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: dueDateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Due Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                   if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                     if (time != null) {
                          final dateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                          dueDateController.text = dateTime.toString();
                          saveDraft();
                        }
                      }
                    },
                    onChanged: (_) => saveDraft(),
                  ),
                  const SizedBox(height: 12),

                  // Update create button UI
                  ElevatedButton(
                    onPressed: isCreating ? null : createTask,
                    child: isCreating
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Add Task'),
                  ),
                ],
              ),
                ),
                Expanded(
                  child: isLoading
                      ? Center(child: CircularProgressIndicator())
                      : filteredTasks.isEmpty
                        ? const Center(child: Text('No tasks found'))
                        : ListView.builder(
                          itemCount: filteredTasks.length,
                          itemBuilder: (context, index) {
                            final task = filteredTasks[index];
                            
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                title: Text(
                                task['title'],
                                style: const TextStyle(fontWeight: FontWeight.bold),),
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
                                        fontWeight: FontWeight.w500, 
                                      ),
                                    )
                                  ]
                                ),
                                onTap: () => showUpdateDialog(task), // make a task 'tappable'
                                trailing: IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () => deleteTask(task['id']),
                                ),
                              )
                            );
                          },
                        ),
                ),
              ],
            ),
      )
 
    );
  }
}