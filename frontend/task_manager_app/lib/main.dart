import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'add_task.dart';
import 'package:intl/intl.dart';

import 'dart:async';
Timer? _debounce;



void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),

        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task deleted'))
      );
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

    // int? blockedBy = task['blocked_by'];
    int blockedBy = task['blocked_by'] ?? -1;

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
                  const SizedBox(height: 8,),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 8,),
                  TextField(
                    controller: dueDateController,
                    decoration: const InputDecoration(labelText: 'Due Date'),
                  ),
                  const SizedBox(height: 8,),
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
                  const SizedBox(height: 8,),
                  DropdownButtonFormField<int>(
                    initialValue: blockedBy,
                    decoration: const InputDecoration(
                      labelText: 'Blocked By',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: -1,
                        child: Text('None'),
                      ),
                      ...allTasks
                      .where((t) => t['id'] != task['id']) // exclude itself
                      .map((t) {
                        return DropdownMenuItem<int>(
                          value: t['id'],
                          child: Text(t['title']),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        blockedBy = value!;
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
    int blockedBy,
  ) async {

    // Update
    if (isUpdating) return;

    // Change state
    setState(() {
      isUpdating = true;
    });

    await Future.delayed(Duration.zero);

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
        "blocked_by": blockedBy == -1 ? null : blockedBy,
      }),
    );

    if (response.statusCode == 200) {
      await fetchTasks(); // refresh list

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task updated'))
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task created'))
      );
    }

    setState(() {
      isCreating = false;
    });
  }

  // Helper method to highlight text in search
  Widget buildHighlightedText(String text, String query) {
  if (query.isEmpty) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();

  final startIndex = lowerText.indexOf(lowerQuery);

  if (startIndex == -1) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  final endIndex = startIndex + query.length;

  return RichText(
    text: TextSpan(
      style: const TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.bold,
      ),
      children: [
        TextSpan(text: text.substring(0, startIndex)),
        TextSpan(
          text: text.substring(startIndex, endIndex),
          style: const TextStyle(
            backgroundColor: Colors.yellow,
          ),
        ),
        TextSpan(text: text.substring(endIndex)),
      ],
    ),
  );
}

  // 
  Widget buildStatusBadge(String status) {
    Color color;
    switch(status) {
      case 'done':
      color = Colors.green;
      break;

      case 'in progress':
      color = Colors.orange;
      break;

      default:
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager', 
        style: TextStyle(
          fontWeight: FontWeight.bold),
        ),
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

                if (_debounce?.isActive ?? false) {
                  _debounce!.cancel();
                }

                _debounce = Timer(const Duration(microseconds: 300), () {
                  applyFilters();
                });
                // applyFilters();
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
          ? Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.inbox, size: 60, color: Colors.grey,),
              SizedBox(height: 10,),
              Text('No tasks found', style: TextStyle(color: Colors.grey),)
            ],
          ),
          )
              
              : ListView.builder(
                  itemCount: filteredTasks.length,
                  itemBuilder: (context, index) {
                    final task = filteredTasks[index];

                    final formattedDate = DateFormat('MMM d, yyyy - HH:mm').format(DateTime.parse(task['due_date']));

                    // compute isBlocked
                    final blockingTask = allTasks.firstWhere(
                      (t) => t['id'] == task['blocked_by'],
                      orElse: () => {},
                    );

                    final isBlocked = task['blocked_by'] != null && (blockingTask.isEmpty || blockingTask['status'] != 'done');

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    
                      child: Opacity(
                        opacity: isBlocked ? 0.6 : 1.0,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isBlocked ? Colors.grey[200] : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),                       
                        
                          child: ListTile(
                            leading: Icon(
                              task['status'] == 'done'
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: task['status'] == 'done'
                                  ? Colors.green
                                  : Colors.indigo,
                            ),
                            title: buildHighlightedText(task['title'], searchQuery),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(task['description']),
                                // const SizedBox(height: 5),
                                const Divider(height: 16),
                                
                                Text(
                                  formattedDate,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 6),
                                buildStatusBadge(task['status']),
                              ],
                            ),
                            onTap: () => showUpdateDialog(task),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit, size: 18),
                              IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                final confirm = await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Task'),
                                    content: const Text('Are you sure?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ));
                                  if (confirm == true) {
                                    deleteTask(task['id']);
                                  }
                              },
                            )],),
                          ),
                        )
                      ));
                  },
                ),
    ),
  ],
),
  floatingActionButton: FloatingActionButton(
    // backgroundColor: Colors.indigo,
    elevation: 5,
    onPressed: () async {
      final result = await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => AddTaskScreen(allTasks: allTasks),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child,);
          }
        )
        // MaterialPageRoute(builder: (context) => AddTaskScreen(allTasks: allTasks),),
      );

      if (result != null) {
        await createTaskFromData(result);
      }

    // fetchTasks();
    },
    child: const Icon(Icons.add, size: 24,),
  ),
    );
  }
}
