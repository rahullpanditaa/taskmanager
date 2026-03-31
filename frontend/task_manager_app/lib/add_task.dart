import 'package:flutter/material.dart';


// Add new screen for task creation
class AddTaskScreen extends StatefulWidget {
  final List allTasks;

  const AddTaskScreen({super.key, required this.allTasks});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final dueDateController = TextEditingController();

  int? selectedBlockedBy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Task')),
      body: SafeArea (child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 10),

              // due date picker
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

                      setState(() {
                        dueDateController.text = dateTime.toString();
                      });
                    }
                  }
                },
              ),

              const SizedBox(height: 10),

              // blocked by dropdown
              DropdownButtonFormField<int>(
                initialValue: selectedBlockedBy,
                decoration: const InputDecoration(
                  labelText: 'Blocked By (optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('None'),
                  ),
                  ...widget.allTasks.map((task) {
                    return DropdownMenuItem<int>(
                      value: task['id'],
                      child: Text(task['title']),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedBlockedBy = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      "title": titleController.text,
                      "description": descriptionController.text,
                      "due_date": dueDateController.text,
                      "status": "to-do",
                      "blocked_by": selectedBlockedBy,
                    });
                  },
                  child: const Text('Add Task'),
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}