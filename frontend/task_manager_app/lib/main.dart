import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  List tasks = [];
  bool isLoading = true;

  // Input controllers for title, description, due date
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController dueDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchTasks();
  }

  // GET /tasks
  Future<void> fetchTasks() async {
    final response = await http.get(Uri.parse('http://localhost:5000/tasks'));

    if (response.statusCode == 200) {
      setState(() {
        tasks = jsonDecode(response.body);
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  // POST /create - create a new task
  Future<void> createTask() async {
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

      // refresh list of tasks rendered
      fetchTasks();
    } else {
      // Temporary
      print('Failed to create task: ${response.body}');
    }
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

    // display dialog above app
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Update Task'),
          content: SingleChildScrollView(
            child: Column(children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: "Title"),
              ),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: dueDateController,
                decoration: InputDecoration(labelText: 'Due Date'),
              ),
              DropdownButton<String>(
                value: status,
                items: [
                  DropdownMenuItem(value: 'to-do', child: Text('To-Do')),
                  DropdownMenuItem(value: 'in-progress', child: Text("In progress")),
                  DropdownMenuItem(value: 'done', child: Text('Done')),
                ],
                onChanged: (value) {
                  status = value!;
                },
              )
            ],)
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await updateTask(
                  task['id'],
                  titleController.text,
                  descriptionController.text,
                  dueDateController.text,
                  status
                );
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
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

    // if success
    if (response.statusCode == 200) {
      fetchTasks();
    } else {
      print('Failed to update task: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tasks'),
      ),
      body: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(labelText: 'Title'),
                      ),
                      TextField(
                        controller: descriptionController,
                        decoration: InputDecoration(labelText: 'Description'),
                      ),
                      TextField(
                        controller: dueDateController,
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'Due Date'),
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
                            }
                          }
                        },
                      ),
                      ElevatedButton(
                        onPressed: createTask,
                        child: const Text('Add Task'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: isLoading
                      ? Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return ListTile(
                              title: Text(task['title']),
                              subtitle: Text(task['description']),
                              onTap: () => showUpdateDialog(task), // make a task 'tappable'
                              trailing: IconButton(
                                icon: Icon(Icons.delete),
                                onPressed: () => deleteTask(task['id']),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
 
    );
  }
}