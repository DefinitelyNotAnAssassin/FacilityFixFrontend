import 'package:flutter/material.dart';
import '../popupwidgets/assignstaff_popup.dart';
import '../services/api_service.dart';

class EarthquakeDialog extends StatefulWidget {
  final Map<String, dynamic> maintenanceData;
  final VoidCallback? onSaved;

  const EarthquakeDialog({
    super.key,
    required this.maintenanceData,
    this.onSaved,
  });

  @override
  State<EarthquakeDialog> createState() => _EarthquakeDialogState();

  static void show(BuildContext context, Map<String, dynamic> data, {VoidCallback? onSaved}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EarthquakeDialog(maintenanceData: data, onSaved: onSaved);
      },
    );
  }
}

class _EarthquakeDialogState extends State<EarthquakeDialog> {
  bool isEditMode = false;
  int? selectedTaskIndex;
  late List<Map<String, dynamic>> tasks;
  final ApiService _apiService = ApiService();
  bool _isSaving = false;

  // Width for the new checkbox column to keep layout tidy
  static const double _checkColWidth = 40;

  @override
  void initState() {
    super.initState();
    // Convert checklist_completed from backend to tasks format for the UI
    final checklistCompleted = widget.maintenanceData['checklist_completed'] as List?;

    if (checklistCompleted != null && checklistCompleted.isNotEmpty) {
      tasks = checklistCompleted.map((item) {
        return {
          'id': item['id'] ?? '',
          'name': item['task'] ?? 'Unnamed Task',
          'assigned': item['assigned_to'] ?? null,  // Use item-level assignment
          'rotation': widget.maintenanceData['recurrence_type'] ?? 'Quarterly',
          'status': (item['completed'] == true) ? 'Completed' : null,
          'completed': item['completed'] ?? false,
        };
      }).toList().cast<Map<String, dynamic>>();
    } else {
      tasks = List<Map<String, dynamic>>.from(_getDefaultTasks());
    }
  }

  List<Map<String, dynamic>> _getDefaultTasks() {
    return [
      {
        'name': 'Inspect structural components (columns, beams, walls, parapets, stairs)',
        'assigned': null,
        'rotation': 'Annually',
        'status': 'In Progress',
      },
      {
        'name': 'Inspect non-structural elements (ceilings, lights, piping, façade, racks)',
        'assigned': null,
        'rotation': 'Annually',
        'status': null,
      },
      {
        'name': 'Inspect anchorage of heavy equipment, tanks, UPS, gas cylinders',
        'assigned': null,
        'rotation': 'Annually',
        'status': null,
      },
      {
        'name': 'Test critical systems (fire protection, water/gas lines, elevators, emergency power)',
        'assigned': null,
        'rotation': 'Annually',
        'status': null,
      },
    ];
  }

  void _addNewTask() {
    setState(() {
      tasks.add({
        'name': 'New Task',
        'assigned': null,
        'rotation': 'Monthly',
        'status': null,
      });
    });
  }

  void _deleteTask(int index) {
    setState(() {
      if (selectedTaskIndex == index) {
        selectedTaskIndex = null;
      } else if (selectedTaskIndex != null && selectedTaskIndex! > index) {
        selectedTaskIndex = selectedTaskIndex! - 1;
      }
      tasks.removeAt(index);
    });
  }

  void _handleAssignTask() {
    // Assign individual checklist item
    if (selectedTaskIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a checklist item first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selectedTask = tasks[selectedTaskIndex!];
    _assignChecklistItem(selectedTask);
  }

  Future<void> _assignChecklistItem(Map<String, dynamic> item) async {
    // Show assignment dialog for the specific checklist item
    final taskData = {
      'id': '${widget.maintenanceData['id']}_${item['id']}',
      'task_id': widget.maintenanceData['id'],
      'checklist_item_id': item['id'],
      'title': item['name'] ?? 'Checklist Item',
      'priority': widget.maintenanceData['priority'] ?? 'high',
      'category': 'safety',
      'department': 'Safety Team',
      'scheduled_date': widget.maintenanceData['scheduled_date'],
    };

    AssignScheduleWorkDialog.show(
      context,
      taskData,
      isMaintenanceTask: true,
      onAssignmentComplete: () async {
        // After assignment, refresh the task data
        try {
          final response = await _apiService.getSpecialMaintenanceTask('earthquake');
          if (response['success'] == true && mounted) {
            final updatedTask = response['task'] as Map<String, dynamic>;
            final checklistCompleted = updatedTask['checklist_completed'] as List?;

            if (checklistCompleted != null && checklistCompleted.isNotEmpty) {
              setState(() {
                tasks = checklistCompleted.map((checklistItem) {
                  return {
                    'id': checklistItem['id'] ?? '',
                    'name': checklistItem['task'] ?? 'Unnamed Task',
                    'assigned': checklistItem['assigned_to'] ?? null,
                    'rotation': updatedTask['recurrence_type'] ?? 'Quarterly',
                    'status': (checklistItem['completed'] == true) ? 'Completed' : null,
                    'completed': checklistItem['completed'] ?? false,
                  };
                }).toList().cast<Map<String, dynamic>>();
              });
            }
          }
        } catch (e) {
          print('[v0] Error refreshing task data: $e');
        }

        // Also call parent callback
        widget.onSaved?.call();
      },
    );
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final taskId = widget.maintenanceData['id'];
      if (taskId == null) {
        throw Exception('Task ID is missing');
      }

      // Convert tasks back to checklist format
      final checklistCompleted = tasks.map((task) {
        return {
          'id': task['id'] ?? '',
          'task': task['name'] ?? '',
          'completed': task['completed'] ?? (task['status']?.toLowerCase() == 'completed'),
        };
      }).toList();

      // Update the checklist via API
      final response = await _apiService.updateMaintenanceTaskChecklist(
        taskId,
        checklistCompleted,
      );

      if (response['success'] == true && mounted) {
        setState(() {
          isEditMode = false;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Changes saved successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Call the onSaved callback if provided
        widget.onSaved?.call();
      }
    } catch (e) {
      print('[v0] Error saving changes: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save changes: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Helper: determine if a task is completed based on its status
  bool _isTaskCompleted(Map<String, dynamic> task) {
    final status = (task['status'] as String?)?.trim().toLowerCase();
    return status == 'completed';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.75,
        constraints: const BoxConstraints(
          maxWidth: 1000,
          maxHeight: 700,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
              child: _buildTitleSection(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTasksTable(),
                    if (isEditMode) ...[
                      const SizedBox(height: 16),
                      _buildAddTaskButton(),
                    ],
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EARTHQUAKE SAFETY',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Task Description',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.maintenanceData['description'] ??
                      'Checklist for earthquake preparedness and safety inspections. Includes structural and non-structural evaluations, equipment anchorage, and critical systems testing to ensure facility resilience during seismic events.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.close,
              color: Colors.grey,
              size: 24,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksTable() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            children: [
              // Keep spacing for delete icon when in edit mode 
              if (isEditMode) const SizedBox(width: 40),

              // checkbox column  
              SizedBox(
                width: _checkColWidth,
                child: const Center(
                  child: Text(
                    '',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),

              const Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Details/Task',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const Expanded(
                flex: 1,
                child: Center(
                  child: Text(
                    'Assigned',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const Expanded(
                flex: 1,
                child: Center(
                  child: Text(
                    'Rotation',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const Expanded(
                flex: 1,
                child: Center(
                  child: Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...List.generate(tasks.length, (index) {
          return _buildTaskRow(index);
        }),
      ],
    );
  }

  Widget _buildTaskRow(int index) {
    final task = tasks[index];
    final isSelected = selectedTaskIndex == index;
    final isCompleted = _isTaskCompleted(task);

    return InkWell(
      onTap: isEditMode
          ? null
          : () {
              setState(() {
                selectedTaskIndex = isSelected ? null : index;
              });
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE3F2FD) : Colors.white,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey[300]!,
              width: 1,
            ),
            left: isSelected
                ? const BorderSide(color: Color(0xFF1976D2), width: 3)
                : BorderSide.none,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isEditMode)
              IconButton(
                onPressed: () => _deleteTask(index),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40),
              ),

            // NEW: Auto-checking checkbox column linked to task status
            SizedBox(
              width: _checkColWidth,
              child: Center(
                child: Checkbox(
                  value: isCompleted,
                  // In view mode, it's read-only; in edit mode, toggling updates status.
                  onChanged: isEditMode
                      ? (bool? value) {
                          setState(() {
                            if (value == true) {
                              tasks[index]['status'] = 'Completed';
                            } else {
                              // Simple fallback when unchecked in edit mode
                              tasks[index]['status'] = 'Pending';
                            }
                          });
                        }
                      : null,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),

            // Details/Task 
            const SizedBox(width: 0),
            Expanded(
              flex: 3,
              child: isEditMode
                  ? TextFormField(
                      initialValue: task['name'],
                      onChanged: (value) {
                        tasks[index]['name'] = value;
                      },
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(),
                      ),
                    )
                  : Text(
                      task['name'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
            ),
            const SizedBox(width: 16),

            // Assigned 
            Expanded(
              flex: 1,
              child: isEditMode
                  ? TextFormField(
                      initialValue: task['assigned'] ?? '',
                      textAlign: TextAlign.center,
                      onChanged: (value) {
                        tasks[index]['assigned'] = value.isEmpty ? null : value;
                      },
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(),
                        hintText: 'Null',
                      ),
                    )
                  : Center(
                      child: Text(
                        task['assigned'] ?? 'Null',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
            const SizedBox(width: 16),

            // Rotation 
            Expanded(
              flex: 1,
              child: isEditMode
                  ? Center(
                      child: DropdownButtonFormField<String>(
                        value: task['rotation'],
                        items: [
                          'Daily',
                          'Weekly',
                          'Monthly',
                          'Quarterly',
                          'Semi-Annually',
                          'Annually'
                        ]
                            .map((rotation) => DropdownMenuItem(
                                  value: rotation,
                                  child: Text(rotation),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              tasks[index]['rotation'] = value;
                            });
                          }
                        },
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        task['rotation'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
            const SizedBox(width: 16),

            // Status 
            Expanded(
              flex: 1,
              child: Center(
                child: task['status'] != null
                    ? _buildStatusChip(task['status'])
                    : const SizedBox(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;
    switch (status.toLowerCase()) {
      case 'in progress':
        bgColor = const Color(0xFFFFE8E0);
        textColor = const Color(0xFFD84315);
        break;
      case 'pending':
        bgColor = const Color(0xFFFFEBEE);
        textColor = const Color(0xFFD32F2F);
        break;
      case 'completed':
        bgColor = const Color(0xFFE8F5E8);
        textColor = const Color(0xFF2E7D32);
        break;
      default:
        bgColor = const Color(0xFFE8F4FD);
        textColor = const Color(0xFF1976D2);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildAddTaskButton() {
    return InkWell(
      onTap: _addNewTask,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.add_circle_outline,
              color: Color(0xFF1976D2),
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'Add New Task',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1976D2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isEditMode)
            TextButton(
              onPressed: () {
                setState(() {
                  isEditMode = false;
                  tasks = List<Map<String, dynamic>>.from(
                    widget.maintenanceData['tasks'] ?? _getDefaultTasks(),
                  );
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (isEditMode) const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: isEditMode ? _saveChanges : _handleAssignTask,
            icon: Icon(
              isEditMode ? Icons.save_outlined : Icons.edit_outlined,
              size: 20,
            ),
            label: Text(
              isEditMode ? 'Save Changes' : 'Assign Task',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                if (isEditMode) {
                  _saveChanges();
                } else {
                  isEditMode = true;
                  selectedTaskIndex = null;
                }
              });
            },
            icon: Icon(
              isEditMode ? Icons.check : Icons.edit_outlined,
              size: 20,
            ),
            label: Text(
              isEditMode ? 'Done' : 'Edit Task',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
