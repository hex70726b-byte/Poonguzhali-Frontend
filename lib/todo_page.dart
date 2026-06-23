import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'app_config.dart';
import 'app_drawer.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  static const String _baseUrl = AppConfig.baseUrl;

  List<dynamic> _todos = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedPriorityFilter = 'All'; // 'All', 'high', 'medium', 'low'

  @override
  void initState() {
    super.initState();
    _fetchTodos();
  }

  Future<void> _fetchTodos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    int maxRetries = 3;
    int retryDelaySeconds = 2;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final res = await http.get(Uri.parse('$_baseUrl/api/todos')).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          if (mounted) {
            setState(() {
              _todos = jsonDecode(res.body);
              _isLoading = false;
            });
          }
          return;
        } else {
          throw Exception('Server error: ${res.statusCode}');
        }
      } catch (e) {
        print('Fetch attempt $attempt failed: $e');
        if (attempt == maxRetries) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Connection failed: $e';
            });
          }
        } else {
          await Future.delayed(Duration(seconds: retryDelaySeconds * attempt));
        }
      }
    }
  }

  Future<void> _createTodo({
    required String title,
    required String description,
    required String priority,
    required String dueDate,
  }) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/todos'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'description': description,
          'priority': priority,
          'dueDate': dueDate,
          'isCompleted': false,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Task added successfully!'), backgroundColor: AppColors.lightBlueAccent),
        );
        _fetchTodos();
      } else {
        throw Exception('Failed to add task');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _updateTodo({
    required String id,
    String? title,
    String? description,
    String? priority,
    String? dueDate,
    bool? isCompleted,
    bool showFeedback = true,
  }) async {
    // If not doing background completion toggle, show loading indicator
    if (showFeedback) {
      setState(() => _isLoading = true);
    }
    try {
      final Map<String, dynamic> body = {};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (priority != null) body['priority'] = priority;
      if (dueDate != null) body['dueDate'] = dueDate;
      if (isCompleted != null) body['isCompleted'] = isCompleted;

      final res = await http.put(
        Uri.parse('$_baseUrl/api/todos/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        if (!mounted) return;
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✨ Task updated successfully!'), backgroundColor: AppColors.lightBlueAccent),
          );
        }
        _fetchTodos();
      } else {
        throw Exception('Failed to update task');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _deleteTodo(String id) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/api/todos/$id')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Task deleted successfully!'), backgroundColor: Colors.blueGrey),
        );
        _fetchTodos();
      } else {
        throw Exception('Failed to delete task');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _openFormSheet({dynamic existing}) {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: isEdit ? existing['title']?.toString() : '');
    final descCtrl = TextEditingController(text: isEdit ? existing['description']?.toString() : '');
    String selectedPriority = isEdit ? (existing['priority']?.toString() ?? 'medium') : 'medium';
    
    DateTime? selectedDate = isEdit && existing['dueDate'] != null && existing['dueDate'].toString().isNotEmpty
        ? DateTime.tryParse(existing['dueDate'].toString())
        : null;

    final dateCtrl = TextEditingController(
      text: selectedDate != null ? DateFormat('yyyy-MM-dd').format(selectedDate) : '',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEdit ? '📝 Edit Task' : '📝 Add New Task',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white60),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Title
                      TextField(
                        controller: titleCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          labelText: 'Task Title',
                          labelStyle: const TextStyle(color: Colors.white54),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white24),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.lightBlueAccent, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextField(
                        controller: descCtrl,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          labelText: 'Description (Optional)',
                          alignLabelWithHint: true,
                          labelStyle: const TextStyle(color: Colors.white54),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white24),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.lightBlueAccent, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Priority Selection
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PRIORITY',
                            style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: ['low', 'medium', 'high'].map((priority) {
                              final isSelected = selectedPriority == priority;
                              Color pColor = Colors.grey;
                              if (priority == 'high') pColor = Colors.redAccent;
                              if (priority == 'medium') pColor = Colors.orangeAccent;
                              if (priority == 'low') pColor = Colors.greenAccent;

                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: ChoiceChip(
                                    label: Text(
                                      priority.toUpperCase(),
                                      style: TextStyle(
                                        color: isSelected ? Colors.black : pColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    selected: isSelected,
                                    selectedColor: pColor,
                                    backgroundColor: const Color(0xFF2C2C2C),
                                    side: BorderSide(color: isSelected ? pColor : Colors.white12),
                                    showCheckmark: false,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setSheetState(() {
                                          selectedPriority = priority;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Due Date Picker
                      TextField(
                        controller: dateCtrl,
                        readOnly: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Due Date (Optional)',
                          labelStyle: const TextStyle(color: Colors.white60),
                          prefixIcon: const Icon(Icons.calendar_today_rounded, color: AppColors.lightBlueAccent),
                          suffixIcon: dateCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, color: Colors.white30),
                                  onPressed: () {
                                    setSheetState(() {
                                      selectedDate = null;
                                      dateCtrl.clear();
                                    });
                                  },
                                )
                              : null,
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white24),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.lightBlueAccent, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onTap: () async {
                          final datePick = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (datePick != null) {
                            setSheetState(() {
                              selectedDate = datePick;
                              dateCtrl.text = DateFormat('yyyy-MM-dd').format(datePick);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 24),

                      // Save/Delete Buttons
                      Row(
                        children: [
                          if (isEdit) ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(color: Colors.redAccent),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _deleteTodo(existing['_id']);
                                },
                                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.lightBlueAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                final title = titleCtrl.text.trim();
                                final desc = descCtrl.text.trim();
                                final dateStr = dateCtrl.text.trim();

                                if (title.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('⚠️ Title is required'), backgroundColor: Colors.redAccent),
                                  );
                                  return;
                                }

                                Navigator.pop(ctx);

                                if (isEdit) {
                                  _updateTodo(
                                    id: existing['_id'],
                                    title: title,
                                    description: desc,
                                    priority: selectedPriority,
                                    dueDate: dateStr,
                                  );
                                } else {
                                  _createTodo(
                                    title: title,
                                    description: desc,
                                    priority: selectedPriority,
                                    dueDate: dateStr,
                                  );
                                }
                              },
                              child: Text(
                                isEdit ? 'Update Task' : 'Add Task',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
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
        );
      },
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.redAccent;
      case 'medium':
        return Colors.orangeAccent;
      case 'low':
        return Colors.greenAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter & Search Logic
    final filteredTodos = _todos.where((t) {
      final title = t['title']?.toString().toLowerCase() ?? '';
      final desc = t['description']?.toString().toLowerCase() ?? '';
      final priority = t['priority']?.toString().toLowerCase() ?? 'medium';
      
      final matchesSearch = title.contains(_searchQuery.toLowerCase()) || desc.contains(_searchQuery.toLowerCase());
      final matchesPriority = _selectedPriorityFilter == 'All' || priority == _selectedPriorityFilter.toLowerCase();
      
      return matchesSearch && matchesPriority;
    }).toList();

    // Grouping into Active & Completed
    final activeTodos = filteredTodos.where((t) => t['isCompleted'] != true).toList();
    final completedTodos = filteredTodos.where((t) => t['isCompleted'] == true).toList();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      drawer: const AppDrawer(activePage: 'todo'),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.lightBlueAccent, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          '✅ Todo List',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.lightBlueAccent,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _openFormSheet(),
        child: const Icon(Icons.add_task_rounded, size: 28),
      ),
      body: Column(
        children: [
          // Header Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.lightBlueAccent.withValues(alpha: 0.15), AppColors.lightBlueAccent.withValues(alpha: 0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.lightBlueAccent.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlueAccent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.checklist_rounded, color: AppColors.lightBlueAccent, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Task Progress',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_todos.where((t) => t['isCompleted'] == true).length} of ${_todos.length} tasks completed',
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.lightBlueAccent),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                fillColor: const Color(0xFF1E1E1E),
                filled: true,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.lightBlueAccent, width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Priority Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['All', 'High', 'Medium', 'Low'].map((filter) {
                final isSelected = _selectedPriorityFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.lightBlueAccent,
                    checkmarkColor: Colors.black,
                    backgroundColor: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: BorderSide(color: isSelected ? AppColors.lightBlueAccent : Colors.white12),
                    onSelected: (selected) {
                      setState(() {
                        _selectedPriorityFilter = filter;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Task List Views
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchTodos,
              color: AppColors.lightBlueAccent,
              child: _isLoading && _todos.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppColors.lightBlueAccent))
                  : _errorMessage != null
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.4,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                                const SizedBox(height: 12),
                                Text(_errorMessage!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _fetchTodos,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filteredTodos.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Container(
                                height: MediaQuery.of(context).size.height * 0.4,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.assignment_turned_in_rounded, size: 72, color: Colors.white.withValues(alpha: 0.08)),
                                    const SizedBox(height: 16),
                                    const Text('No tasks found', style: TextStyle(color: Colors.white54, fontSize: 15)),
                                  ],
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                if (activeTodos.isNotEmpty) ...[
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4, bottom: 8, top: 8),
                                    child: Text(
                                      'PENDING TASKS',
                                      style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    ),
                                  ),
                                  ...activeTodos.map((todo) => _buildTodoCard(todo)),
                                ],
                                if (completedTodos.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4, bottom: 8, top: 8),
                                    child: Text(
                                      'COMPLETED TASKS',
                                      style: TextStyle(color: Colors.white30, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    ),
                                  ),
                                  ...completedTodos.map((todo) => _buildTodoCard(todo, isCompletedList: true)),
                                ],
                              ],
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoCard(dynamic todo, {bool isCompletedList = false}) {
    final title = todo['title'] ?? 'No Title';
    final description = todo['description'] ?? '';
    final priority = todo['priority'] ?? 'medium';
    final dueDate = todo['dueDate'] ?? '';
    final isCompleted = todo['isCompleted'] == true;
    final priorityColor = _getPriorityColor(priority);

    return Opacity(
      opacity: isCompletedList ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isCompletedList ? Colors.transparent : Colors.white.withValues(alpha: 0.04)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              // Priority bar indicator on left side
              Container(
                width: 5,
                height: description.isNotEmpty ? 84 : 64,
                color: isCompletedList ? Colors.grey : priorityColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // Checkbox
                      Transform.scale(
                        scale: 1.1,
                        child: Checkbox(
                          value: isCompleted,
                          activeColor: AppColors.lightBlueAccent,
                          checkColor: Colors.black,
                          side: const BorderSide(color: Colors.white38),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) {
                            _updateTodo(
                              id: todo['_id'],
                              isCompleted: val,
                              showFeedback: false,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Text info
                      Expanded(
                        child: InkWell(
                          onTap: () => _openFormSheet(existing: todo),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  color: isCompletedList ? Colors.white38 : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  decoration: isCompletedList ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              if (description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isCompletedList ? Colors.white24 : Colors.white54,
                                    fontSize: 12,
                                    decoration: isCompletedList ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ],
                              if (dueDate.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 11,
                                      color: isCompletedList ? Colors.white24 : AppColors.lightBlueAccent.withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      dueDate,
                                      style: TextStyle(
                                        color: isCompletedList ? Colors.white24 : AppColors.lightBlueAccent.withValues(alpha: 0.8),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Edit/More button
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, color: Colors.white38),
                onPressed: () => _openFormSheet(existing: todo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
