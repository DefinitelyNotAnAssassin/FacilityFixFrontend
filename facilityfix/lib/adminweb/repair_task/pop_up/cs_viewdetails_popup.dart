import 'package:facilityfix/adminweb/widgets/tags.dart';
import 'package:facilityfix/services/api_services.dart';
import 'package:facilityfix/utils/ui_format.dart';
import 'package:facilityfix/adminweb/widgets/delete_popup.dart';
import 'package:intl/intl.dart';
import 'edit_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart' as admin_api;

class ConcernSlipDetailDialog extends StatefulWidget {
  final Map<String, dynamic> task;
  final VoidCallback? onAssignmentComplete;
  final bool isMaintenanceTask;

  const ConcernSlipDetailDialog({
    super.key,
    required this.task,
    this.onAssignmentComplete,
    this.isMaintenanceTask = false,
  });

  @override
  State<ConcernSlipDetailDialog> createState() =>
      _ConcernSlipDetailDialogState();

  static void show(
    BuildContext context,
    Map<String, dynamic> task, {
    VoidCallback? onAssignmentComplete,
    bool isMaintenanceTask = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ConcernSlipDetailDialog(
          task: task,
          onAssignmentComplete: onAssignmentComplete,
          isMaintenanceTask: isMaintenanceTask,
        );
      },
    );
  }
}

class _ConcernSlipDetailDialogState extends State<ConcernSlipDetailDialog> {
  final _formKey = GlobalKey<FormState>();
  final APIService _apiService = APIService();
  final admin_api.ApiService _adminApiService = admin_api.ApiService();

  bool _formValid = false;
  bool _isAssigning = false;
  bool _showAssignmentForm = false; // Track which view to show

  String? selectedStaffId;
  String? selectedStaffName;
  DateTime? selectedDate;
  DateTime? selectedEndDate;
  final TextEditingController notesController = TextEditingController();

  List<Map<String, dynamic>> _staffList = [];

  // Helper to check status
  bool get _isPendingStatus {
    final status = widget.task['status']?.toString().toLowerCase() ?? '';
    return status == 'pending';
  }

  bool get _isAssignedStatus {
    final status = widget.task['status']?.toString().toLowerCase() ?? '';
    // Treat both explicit 'assigned' and canonical 'to inspect' as assignment state
    return status == 'assigned' ||
        status == 'to inspect' ||
        status.contains('to_inspect');
  }

  bool get _isToInspectStatus {
    final status = widget.task['status']?.toString().toLowerCase() ?? '';
    // Exclude 'inspected' (inspection completed) which is handled separately
    return (status.contains('to inspect') ||
        status.contains('to_inspect') ||
        status.contains('for inspection') ||
        (status.contains('inspect') && !status.contains('inspected')) ||
        status == 'inspect');
  }

  bool get _isInspectedStatus {
    final status = widget.task['status']?.toString().toLowerCase() ?? '';
    return status.contains('inspected') || status == 'inspected';
  }

  // Return a normalized canonical status used across the UI
  String _normalizedStatus() {
    final s = widget.task['status']?.toString().toLowerCase() ?? '';
    if (s.contains('pending')) return 'pending';
    if (s.contains('assigned') ||
        s.contains('to inspect') ||
        s.contains('to_inspect'))
      return 'to inspect';
    if (s.contains('in_progress') || s.contains('in progress'))
      return 'in progress';
    if (s.contains('inspected') ||
        s.contains('assessed') ||
        s.contains('completed') ||
        s.contains('assess'))
      return 'inspected';
    return 'pending';
  }

  @override
  void initState() {
    super.initState();
    notesController.addListener(_revalidate);
    _initializeScheduleDate(); // Auto-populate schedule date

    print('Task rawData keys: ${widget.task['rawData']?.keys.toList()}');
    print('Attachments value: ${widget.task['rawData']?['attachments']}');
    print('Full task keys: ${widget.task.keys.toList()}');

    // Load staff details when task is in an inspection-related state
    final norm = _normalizedStatus();
    if (norm == 'to inspect' || norm == 'inspected' || norm == 'in progress') {
      _loadAssignedStaffDetails();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revalidate();
      // Auto-load and assign staff when showing assignment form
      if (_showAssignmentForm) {
        _loadStaffMembers().then((_) => _autoAssignStaff());
      }
    });
  }

  void _initializeScheduleDate() {
    // Auto-populate inspection schedule from several possible schedule fields
    // Backend and tenants sometimes send schedule under different keys.
    // Prefer explicit schedule fields (rawData.schedule_availability etc.)
    // before falling back to generic dateRequested/requested_at.
    final candidates = [
      widget.task['rawData']?['schedule_availability'],
      widget.task['rawData']?['schedule'],
      widget.task['rawData']?['availability'],
      widget.task['rawData']?['schedule_availabilities'],
      widget.task['schedule'],
      widget.task['availability'],
      widget.task['dateRequested'],
      widget.task['requested_at'],
    ];

    // Debug: list all candidate values (stringified)
    try {
      print(
        '[ConcernSlipDetail] schedule candidates: ${candidates.map((c) => c?.toString() ?? '<null>').toList()}',
      );
    } catch (_) {}

    String? sa;
    for (final c in candidates) {
      if (c != null) {
        final s = c.toString().trim();
        if (s.isNotEmpty) {
          sa = s;
          break;
        }
      }
    }

    if (sa == null || sa.isEmpty) return;

    // Try centralized parser first to capture both start and end times.
    try {
      final parsed = UiDateUtils.parseRange(sa);
      if (parsed != null) {
        selectedDate = parsed.start;
        selectedEndDate = parsed.end;

        // Debug: log parsed start/end datetimes from UiDateUtils
        try {
          print(
            '[ConcernSlipDetail] parseRange -> start: $selectedDate, end: $selectedEndDate',
          );
        } catch (_) {}

        return;
      }
    } catch (_) {}

    try {
      // Range like "start - end"
      if (sa.contains(' - ')) {
        final parts = sa.split(' - ');
        final left = parts[0].trim();
        final right = parts.length > 1 ? parts[1].trim() : '';

        // Parse start
        try {
          selectedDate = DateTime.parse(left);
        } catch (_) {
          try {
            selectedDate = DateFormat('MMM d, yyyy h:mm a').parse(left);
          } catch (_) {
            try {
              final dateOnly = DateFormat('MMM d, yyyy').parse(left);
              selectedDate = DateTime(
                dateOnly.year,
                dateOnly.month,
                dateOnly.day,
                9,
                0,
              );
            } catch (_) {}
          }
        }

        // Parse end (may be time-only)
        if (right.isNotEmpty) {
          try {
            final t = DateFormat('h:mm a').parse(right);
            if (selectedDate != null)
              selectedEndDate = DateTime(
                selectedDate!.year,
                selectedDate!.month,
                selectedDate!.day,
                t.hour,
                t.minute,
              );
          } catch (_) {
            try {
              selectedEndDate = DateTime.parse(right);
            } catch (_) {
              try {
                selectedEndDate = DateFormat('MMM d, yyyy h:mm a').parse(right);
              } catch (_) {}
            }
          }
        }
        // Make sure end is after start. If inverted, set to start + 1 hour for UX.
        if (selectedDate != null &&
            selectedEndDate != null &&
            selectedEndDate!.isBefore(selectedDate!)) {
          selectedEndDate = selectedDate!.add(const Duration(hours: 1));
        }

        // Debug: log parsed start/end datetimes
        try {
          print(
            '[ConcernSlipDetail] parsed schedule -> start: $selectedDate, end: $selectedEndDate',
          );
        } catch (_) {}
      } else if (sa.contains('T')) {
        selectedDate = DateTime.parse(sa);
      } else if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(sa)) {
        final parts = sa.split('-');
        selectedDate = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
          9,
          0,
        );
      } else {
        try {
          selectedDate = DateTime.parse(sa);
        } catch (_) {
          try {
            selectedDate = DateFormat('MMM d, yyyy h:mm a').parse(sa);
          } catch (_) {
            try {
              selectedDate = DateFormat('MMM d, yyyy').parse(sa);
              selectedDate = DateTime(
                selectedDate!.year,
                selectedDate!.month,
                selectedDate!.day,
                9,
                0,
              );
            } catch (_) {
              // last resort: try UiDateUtils.parse if available
              try {
                selectedDate = UiDateUtils.parse(sa);
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      print('[ConcernSlipDetail] Error parsing schedule date: $e');
    }
  }

  Future<void> _loadStaffMembers() async {
    try {
      String? taskCategory = widget.task['category']?.toString().toLowerCase();
      String? department;

      switch (taskCategory) {
        case 'electrical':
          department = 'electrical';
          break;
        case 'plumbing':
          department = 'plumbing';
          break;
        case 'carpentry':
          department = 'carpentry';
          break;
        case 'masonry':
          department = 'masonry';
          break;
        case 'hvac':
          department = 'electrical';
          break;
        case 'pest control':
        case 'pest_control':
          department = 'masonry';
          break;
        default:
          department = null;
      }

      final staffData = await _apiService.getStaffMembers(
        department: department,
        availableOnly: true,
      );

      setState(() {
        _staffList = staffData;
      });

      print('[ConcernSlipDetail] Loaded ${_staffList.length} staff members');
    } catch (e) {
      print('[ConcernSlipDetail] Error loading staff: $e');
    }
  }

  void _revalidate() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (ok != _formValid) setState(() => _formValid = ok);
  }

  void _autoAssignStaff() {
    // Auto-assign staff based on department using round-robin or first available
    if (_staffList.isEmpty) return;

    // Sort by workload if available, otherwise use first staff
    _staffList.sort((a, b) {
      final workloadA = a['current_workload'] ?? 0;
      final workloadB = b['current_workload'] ?? 0;
      return workloadA.compareTo(workloadB);
    });

    // Auto-select the staff member with lowest workload
    final autoSelectedStaff = _staffList.first;
    setState(() {
      selectedStaffId = _getStaffId(autoSelectedStaff);
      selectedStaffName = _getStaffDisplayName(autoSelectedStaff);
    });
    _revalidate();

    print(
      '[ConcernSlipDetail] Auto-assigned staff: $selectedStaffName (ID: $selectedStaffId)',
    );
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  String _getStaffDisplayName(Map<String, dynamic> staff) {
    final firstName = staff['first_name'] ?? '';
    final lastName = staff['last_name'] ?? '';
    String name = '$firstName $lastName'.trim();
    if (name.isEmpty) name = 'Staff Member';
    return name;
  }

  String _getStaffId(Map<String, dynamic> staff) {
    return staff['user_id'] ?? staff['id'] ?? '';
  }

  Widget _buildSimpleAvatar(String name, {double size = 32}) {
    // Get initials from name
    final parts = name.trim().split(' ');
    String initials = '';
    if (parts.isNotEmpty) {
      initials = parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '';
      if (parts.length > 1 && parts.last.isNotEmpty) {
        initials += parts.last[0].toUpperCase();
      }
    }
    if (initials.isEmpty) initials = '?';

    // Generate color from name
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final colors = [
      Colors.blue[700]!,
      Colors.green[700]!,
      Colors.orange[700]!,
      Colors.purple[700]!,
      Colors.teal[700]!,
      Colors.pink[700]!,
    ];
    final color = colors[hash.abs() % colors.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _fmtDateTime(DateTime d, [DateTime? end]) {
    // Use UiDateUtils for consistent formatting and include end time when available
    return UiDateUtils.dateTimeRange(d, end);
  }

  // Return a normalized, human-friendly status label for display
  String _statusLabel() {
    // Display the normalized status (use the same canonical set as admin)
    return _normalizedStatus();
  }

  String _formatScheduleDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      // Debug: log incoming raw schedule string
      try {
        print('[ConcernSlipDetail] _formatScheduleDate received: $dateString');
      } catch (_) {}
      final s = dateString.trim();
      if (s.contains(' - ')) {
        final parts = s.split(' - ');
        final left = parts[0].trim();
        final right = parts[1].trim();
        DateTime? start;
        DateTime? end;

        // Parse start
        try {
          start = DateTime.parse(left);
        } catch (_) {
          try {
            start = DateFormat('MMM d, yyyy h:mm a').parse(left);
          } catch (_) {
            try {
              final d = DateFormat('MMM d, yyyy').parse(left);
              start = DateTime(d.year, d.month, d.day, 9, 0);
            } catch (_) {}
          }
        }

        // Parse end (may be time-only)
        try {
          final t = DateFormat('h:mm a').parse(right);
          if (start != null)
            end = DateTime(
              start.year,
              start.month,
              start.day,
              t.hour,
              t.minute,
            );
        } catch (_) {
          try {
            end = DateTime.parse(right);
          } catch (_) {
            try {
              end = DateFormat('MMM d, yyyy h:mm a').parse(right);
            } catch (_) {}
          }
        }

        // Prefer using UiDateUtils.dateTimeRange for both full ranges and single
        // datetimes (UiDateUtils will render a compact representation).
        if (start != null) return UiDateUtils.dateTimeRange(start, end);
        return s;
      }

      if (s.contains('T')) {
        final d = DateTime.parse(s);
        return UiDateUtils.dateTimeRange(d);
      }

      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
        final parts = s.split('-');
        final d = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        // Use dateTimeRange to keep style consistent (will show date-only compactly).
        return UiDateUtils.dateTimeRange(d);
      }

      // Try to parse generic tenant formats
      try {
        final d = DateFormat('MMM d, yyyy h:mm a').parse(s);
        return UiDateUtils.dateTimeRange(d);
      } catch (_) {}

      return s;
    } catch (e) {
      print('[JobServiceDialog] Error formatting schedule: $e');
    }
    return dateString;
  }

  Future<void> _loadAssignedStaffDetails() async {
    // Load staff details from the task data (handle multiple possible shapes/keys)
    final data = widget.task;
    // Possible locations and keys where assigned staff info might exist
    dynamic assignedStaff =
        data['rawData']?['assigned_staff'] ??
        data['rawData']?['assigned_to'] ??
        data['assigned_staff'] ??
        data['assigned_to'] ??
        data['assigned_staff_name'] ??
        data['assigned_staff_id'];

    // Also look for explicit id fields if name is not present
    final explicitId =
        data['rawData']?['assigned_staff_id'] ??
        data['assigned_staff_id'] ??
        data['rawData']?['assigned_to'] ??
        data['assigned_to'];

    if (assignedStaff == null && explicitId == null) return;

    // If assignedStaff is a map, prefer its name fields
    if (assignedStaff is Map<String, dynamic>) {
      final id =
          assignedStaff['user_id'] ??
          assignedStaff['id'] ??
          assignedStaff['userId'];
      final name =
          assignedStaff['name'] ??
          assignedStaff['full_name'] ??
          ((assignedStaff['first_name'] ?? '') +
                  ' ' +
                  (assignedStaff['last_name'] ?? ''))
              .toString()
              .trim();
      setState(() {
        selectedStaffId = id?.toString();
        selectedStaffName = (name != null && name.isNotEmpty) ? name : null;
      });
      // If we still don't have a name but have an id, try to resolve it
      if ((selectedStaffName == null || selectedStaffName!.isEmpty) &&
          selectedStaffId != null) {
        try {
          final staffList = await _apiService.getStaffMembers();
          final found = staffList.firstWhere(
            (m) =>
                (m['user_id']?.toString() == selectedStaffId) ||
                (m['id']?.toString() == selectedStaffId),
            orElse: () => {},
          );
          if (found.isNotEmpty)
            setState(() => selectedStaffName = _getStaffDisplayName(found));
        } catch (_) {}
      }
      return;
    }

    // If it's a string, decide if it's a name or an id
    if (assignedStaff is String) {
      final s = assignedStaff.trim();
      final looksLikeId = RegExp(r'^[0-9]+$').hasMatch(s) || s.contains('_');
      if (!looksLikeId) {
        // It's a human-readable name
        setState(() {
          selectedStaffName = s;
          selectedStaffId = explicitId?.toString();
        });
        return;
      }

      // Looks like id: try to resolve name
      setState(() => selectedStaffId = s);
      try {
        final staffList = await _apiService.getStaffMembers();
        final found = staffList.firstWhere(
          (m) => (m['user_id']?.toString() == s) || (m['id']?.toString() == s),
          orElse: () => {},
        );
        if (found.isNotEmpty) {
          setState(() => selectedStaffName = _getStaffDisplayName(found));
          return;
        }
      } catch (_) {}

      // Fallback to showing raw id as name
      setState(() => selectedStaffName = s);
      return;
    }

    // If assignedStaff is null but explicit id exists, try to resolve via id
    if (assignedStaff == null && explicitId != null) {
      final sid = explicitId.toString();
      setState(() => selectedStaffId = sid);
      try {
        final staffList = await _apiService.getStaffMembers();
        final found = staffList.firstWhere(
          (m) =>
              (m['user_id']?.toString() == sid) || (m['id']?.toString() == sid),
          orElse: () => {},
        );
        if (found.isNotEmpty) {
          setState(() => selectedStaffName = _getStaffDisplayName(found));
          return;
        }
      } catch (_) {}
      // fallback
      setState(() => selectedStaffName = sid);
      return;
    }

    // Unknown shape: stringify
    setState(() {
      try {
        selectedStaffName = assignedStaff.toString();
      } catch (_) {
        selectedStaffName = 'Staff Member';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child:
                    _showAssignmentForm
                        ? Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: _buildAssignmentFormView(),
                        )
                        : _buildDetailsView(),
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 32, right: 24, top: 20, bottom: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        children: [
          Text(
            _showAssignmentForm
                ? 'Assign & Schedule Work'
                : 'Concern Slip Details',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          if (!_showAssignmentForm) ...[
            // Edit button
            IconButton(
              onPressed:
                  _isAssigning
                      ? null
                      : () async {
                        final result = await EditDialog.show(
                          context,
                          type: EditDialogType.concernSlip,
                          task: widget.task,
                          onSave: () {
                            // Optionally perform any local updates when save occurs
                          },
                        );

                        if (result == true && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Changes saved'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          // Notify parent/list to refresh
                          widget.onAssignmentComplete?.call();
                        }
                      },
              icon: const Icon(
                Icons.edit_outlined,
                color: Colors.blue,
                size: 20,
              ),
              tooltip: 'Edit',
            ),

            IconButton(
              onPressed: () => _deleteTask(),
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Delete Task',
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            onPressed: _isAssigning ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.grey, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        mainAxisAlignment:
            _showAssignmentForm
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.end,
        children: [
          if (_showAssignmentForm) ...[
            OutlinedButton(
              onPressed:
                  _isAssigning
                      ? null
                      : () {
                        setState(() {
                          _showAssignmentForm = false;
                        });
                      },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey[300]!),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed:
                  (_formValid && !_isAssigning) ? _handleSaveAndAssign : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                elevation: 0,
              ),
              child:
                  _isAssigning
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Text('Save and Assign'),
            ),
          ] else ...[
            // Only show Next button if status is pending
            if (_isPendingStatus)
              ElevatedButton.icon(
                onPressed: () async {
                  setState(() {
                    _showAssignmentForm = true;
                  });
                  await _loadStaffMembers();
                  _autoAssignStaff(); // Auto-assign based on department
                },
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Next'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  elevation: 0,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConcernSlipDetails(),
        // Show assessment/assigned-staff section for To Inspect, Inspected, or In Progress statuses
        if (_statusLabel() == 'inspected' ||
            _statusLabel() == 'to inspect' ||
            _statusLabel() == 'in progress') ...[
          const SizedBox(height: 24),
          Divider(color: Colors.grey[200], thickness: 1, height: 1),
          const SizedBox(height: 24),
          _buildAssessmentSection(),
        ],
        if ((widget.task['rawData']?['attachments'] as List?)?.isNotEmpty ??
            false) ...[
          const SizedBox(height: 24),
          Divider(color: Colors.grey[200], thickness: 1, height: 1),
          const SizedBox(height: 24),
          _buildTenantAttachmentsSection(),
        ],
      ],
    );
  }

  Widget _buildConcernSlipDetails() {
    // Title, IDs, and meta info
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.task['title'] ?? 'No Title',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.task['id'] ?? 'N/A',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    // Format date as: "Aug 23, 2025"
                    'Date Requested: ${(() {
                      final ds = widget.task['dateRequested'] ?? widget.task['rawData']?['schedule_availability'];
                      if (ds == null) return 'N/A';
                      try {
                        DateTime date;
                        final s = ds.toString();
                        if (s.contains('T')) {
                          date = DateTime.parse(s);
                        } else {
                          final parts = s.split('-');
                          if (parts.length == 3) {
                            date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                          } else {
                            return s;
                          }
                        }
                        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                        return '${months[date.month - 1]} ${date.day}, ${date.year}';
                      } catch (_) {
                        return ds.toString();
                      }
                    })()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            PriorityTag(widget.task['priority'] ?? ''),
            const SizedBox(width: 8),
            // Display a normalized, human-friendly status label
            StatusTag(_statusLabel()),
          ],
        ),
        const SizedBox(height: 24),
        Divider(color: Colors.grey[200], thickness: 1, height: 1),
        const SizedBox(height: 24),
        // Requester Details
        _buildSectionTitle('Requester Details'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDetailItem(
                'REQUESTED BY',
                (() {
                  final candidates = [
                    widget.task['requested_by_name'],
                    widget.task['requestedBy'],
                    widget.task['requester_name'],
                    widget.task['rawData']?['requested_by_name'],
                    widget.task['rawData']?['requester_name'],
                    widget.task['rawData']?['reported_by'],
                  ];
                  final name = candidates.firstWhere(
                    (c) => c != null && c.toString().trim().isNotEmpty,
                    orElse: () => null,
                  );
                  return name?.toString() ?? 'N/A';
                })(),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildDetailItem(
                'DEPARTMENT',
                widget.task['department'] ?? 'N/A',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildDetailItem(
                'BLDG & UNIT NO.',
                _formatBuildingUnit(widget.task['buildingUnit'] ?? 'N/A'),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: InkWell(
                child: _buildDetailItem(
                  _statusLabel() == 'inspected'
                      ? 'DATE INSPECTED'
                      : 'SCHEDULE AVAILABILITY',
                  _statusLabel() == 'inspected'
                      ? (() {
                        final dateVal =
                            widget.task['dateCompleted'] ??
                            widget.task['rawData']?['date_completed'] ??
                            widget.task['completed_at'] ??
                            widget.task['rawData']?['completedAt'];
                        if (dateVal == null) return 'N/A';
                        try {
                          final d =
                              dateVal is DateTime
                                  ? dateVal
                                  : DateTime.parse(dateVal.toString());
                          return UiDateUtils.fullDate(d);
                        } catch (_) {
                          return dateVal.toString();
                        }
                      })()
                      : (selectedDate != null
                          ? UiDateUtils.dateTimeRange(
                            selectedDate!,
                            selectedEndDate,
                          )
                          : _formatScheduleDate(
                            (() {
                              final candidates = [
                                widget
                                    .task['rawData']?['schedule_availability'],
                                widget.task['rawData']?['schedule'],
                                widget.task['rawData']?['availability'],
                                widget.task['schedule'],
                                widget.task['availability'],
                                widget.task['dateRequested'],
                              ];
                              return candidates
                                  .firstWhere(
                                    (c) =>
                                        c != null &&
                                        c.toString().trim().isNotEmpty,
                                    orElse: () => null,
                                  )
                                  ?.toString();
                            })(),
                          )),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Divider(color: Colors.grey[200], thickness: 1, height: 1),
        const SizedBox(height: 24),
        // Work Description
        _buildSectionTitle('Work Description'),
        const SizedBox(height: 16),
        Text(
          widget.task['description'] ?? 'No description available.',
          style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[700]),
        ),
        if ((widget.task['rawData']?['attachments'] as List?)?.isNotEmpty ??
            false) ...[
          const SizedBox(height: 24),
          Divider(color: Colors.grey[200], thickness: 1, height: 1),
          const SizedBox(height: 24),
          _buildTenantAttachmentsSection(),
        ],
      ],
    );
  }

  Widget _buildAssessmentSection() {
    // Use assessment and recommendation from rawData
    final assessment = widget.task['rawData']?['staff_assessment'];
    final recommendation = widget.task['rawData']?['staff_recommendation'];
    final resolutionType = widget.task['rawData']?['resolution_type'];

    // If there is no assessment/recommendation/resolution, only show the
    // assessment block when the task is in an inspection-related state
    // (assigned / to-inspect / inspected) — otherwise hide it.
    if (assessment == null &&
        recommendation == null &&
        resolutionType == null &&
        !_isToInspectStatus &&
        !_isAssignedStatus &&
        !_isInspectedStatus) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Assessment and Resolution Details'),
        const SizedBox(height: 16),
        // Use the shared assigned staff display
        _buildAutoAssignedStaffDisplay(),
        const SizedBox(height: 24),
        if (resolutionType != null) ...[
          Text(
            'RESOLUTION TYPE',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          RequestTypeTag(resolutionType.toString().replaceAll('_', ' ')),
          const SizedBox(height: 24),
        ],
        if (assessment != null) ...[
          Text(
            'ASSESSMENT',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Text(
              assessment,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
        if (recommendation != null) ...[
          const SizedBox(height: 24),
          Text(
            'RECOMMENDATION',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Text(
              recommendation,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Shared assigned staff display for both details and assignment form
  Widget _buildAutoAssignedStaffDisplay() {
    // Try to use explicit selectedStaffName first
    String staffName = selectedStaffName ?? '';

    // Helper to resolve id -> name from loaded staff list
    String _resolveFromLoadedList(String id) {
      try {
        final found = _staffList.firstWhere(
          (m) =>
              (m['user_id']?.toString() == id) || (m['id']?.toString() == id),
          orElse: () => <String, dynamic>{},
        );
        if (found.isNotEmpty) return _getStaffDisplayName(found);
      } catch (_) {}
      return '';
    }

    // If we only have an id selected, try to resolve it from loaded staff
    if (staffName.isEmpty &&
        selectedStaffId != null &&
        selectedStaffId!.isNotEmpty) {
      final resolved = _resolveFromLoadedList(selectedStaffId!);
      if (resolved.isNotEmpty) staffName = resolved;
    }

    // Fallback to reading assigned staff info from task rawData if still empty
    if (staffName.isEmpty) {
      final data = widget.task;
      dynamic assignedStaff =
          data['rawData']?['assigned_staff'] ??
          data['rawData']?['assigned_to'] ??
          data['assigned_staff'] ??
          data['assigned_to'] ??
          data['assigned_staff_name'] ??
          data['rawData']?['assigned_staff_id'] ??
          data['assigned_staff_id'];

      if (assignedStaff != null) {
        if (assignedStaff is String) {
          final s = assignedStaff.trim();
          // If it looks like an id, try resolving from loaded list
          final looksLikeId = RegExp(r'^[0-9_]+$').hasMatch(s);
          if (looksLikeId) {
            final fromList = _resolveFromLoadedList(s);
            staffName = fromList.isNotEmpty ? fromList : s;
          } else {
            staffName = s;
          }
        } else if (assignedStaff is Map<String, dynamic>) {
          staffName =
              assignedStaff['name'] ??
              assignedStaff['full_name'] ??
              ((assignedStaff['first_name'] ?? '') +
                      ' ' +
                      (assignedStaff['last_name'] ?? ''))
                  .toString()
                  .trim();

          // If map contains an id but no human name, try to resolve
          if ((staffName.isEmpty || staffName == 'null') &&
              (assignedStaff['user_id'] ??
                  assignedStaff['id'] ??
                  assignedStaff['_id'] != null)) {
            final id =
                (assignedStaff['user_id'] ??
                        assignedStaff['id'] ??
                        assignedStaff['_id'])
                    .toString();
            final resolved = _resolveFromLoadedList(id);
            if (resolved.isNotEmpty) staffName = resolved;
          }
        } else {
          staffName = assignedStaff.toString();
        }
      }
    }

    if (staffName.isEmpty) staffName = 'Staff Member';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ASSIGNED STAFF',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              _buildSimpleAvatar(staffName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staffName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.task['department'] ?? 'No Department',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.check_circle, color: Colors.green[600], size: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Assign & Schedule Work Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.assignment_ind, color: Colors.blue[700], size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Assign & Schedule Work',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CS: ${widget.task['id'] ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.task['title'] ?? 'No Title',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildPriorityChip(widget.task['priority'] ?? 'Low'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Assign Staff and Inspection Schedule in one row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildAutoAssignedStaffDisplay()),
            const SizedBox(width: 24),
            Expanded(child: _buildDatePicker()),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey[600],
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Inspection Schedule',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        FormField<DateTime>(
          validator: (_) {
            if (selectedDate == null) return 'Please pick a date';
            final today = DateTime.now();
            final floor = DateTime(today.year, today.month, today.day);
            if (selectedDate!.isBefore(floor))
              return 'Date can\'t be in the past';
            return null;
          },
          builder:
              (state) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap:
                        () =>
                            _selectDateTime(context).then((_) => _revalidate()),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color:
                              state.hasError ? Colors.red : Colors.grey[300]!,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color:
                                state.hasError ? Colors.red : Colors.grey[600],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedDate != null
                                  ? _fmtDateTime(selectedDate!, selectedEndDate)
                                  : 'DD/MM/YYYY HH:MM',
                              style: TextStyle(
                                color:
                                    selectedDate != null
                                        ? Colors.black87
                                        : (state.hasError
                                            ? Colors.red
                                            : Colors.grey[500]),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (state.hasError) ...[
                    const SizedBox(height: 6),
                    Text(
                      state.errorText!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
        ),
      ],
    );
  }

  Future<void> _selectDateTime(BuildContext context) async {
    // First select date
    // Ensure initial date is not Sunday (if today is Sunday, move to Monday)
    DateTime initial = selectedDate ?? DateTime.now();
    if (initial.weekday == DateTime.sunday) {
      initial = initial.add(const Duration(days: 1));
    }

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030, 12),
      selectableDayPredicate: (date) => date.weekday != DateTime.sunday,
    );

    if (pickedDate != null) {
      // Then select time (restrict to 9:00 - 17:00)
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime:
            selectedDate != null
                ? TimeOfDay.fromDateTime(selectedDate!)
                : const TimeOfDay(hour: 9, minute: 0),
      );

      if (pickedTime != null) {
        // Validate working hours (9 AM - 5 PM)
        final int h = pickedTime.hour;
        final int m = pickedTime.minute;
        final bool valid = (h > 9 && h < 17) || (h == 9) || (h == 17 && m == 0);
        if (!valid) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Please select a time between 9:00 AM and 5:00 PM (Mon-Sat).',
                ),
              ),
            );
          }
          return;
        }

        setState(() {
          selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _handleSaveAndAssign() async {
    if (!_formValid || selectedStaffId == null) return;
    setState(() => _isAssigning = true);

    try {
      if (widget.isMaintenanceTask) {
        // Maintenance task path: may be a checklist item or whole maintenance task
        final checklistItemId = widget.task['checklist_item_id'];

        if (checklistItemId != null) {
          // Assign to checklist item
          final taskId = widget.task['task_id'];
          if (taskId == null) throw Exception('Task ID not found');

          print(
            '[ConcernSlipDetail] Assigning staff $selectedStaffId to checklist item $checklistItemId',
          );

          final result = await _adminApiService.assignStaffToChecklistItem(
            taskId,
            checklistItemId,
            selectedStaffId!,
          );

          print(
            '[ConcernSlipDetail] Checklist item assignment successful: $result',
          );

          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Staff assigned successfully to checklist item'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
            widget.onAssignmentComplete?.call();
          }
        } else {
          // Assign to whole maintenance task
          final taskId = widget.task['id'] ?? widget.task['task_id'];
          if (taskId == null) throw Exception('Maintenance task ID not found');

          print(
            '[ConcernSlipDetail] Assigning staff $selectedStaffId to maintenance task $taskId',
          );

          final result = await _adminApiService.assignStaffToMaintenanceTask(
            taskId,
            selectedStaffId!,
            scheduledDate: selectedDate,
            notes:
                notesController.text.trim().isNotEmpty
                    ? notesController.text.trim()
                    : null,
          );

          print(
            '[ConcernSlipDetail] Maintenance task assignment successful: $result',
          );

          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Staff assigned successfully to maintenance task',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
            widget.onAssignmentComplete?.call();
          }
        }
      } else {
        // Concern slip assignment (existing behavior)
        final concernSlipId =
            widget.task['rawData']?['id'] ??
            widget.task['rawData']?['_doc_id'] ??
            widget.task['id'];
        if (concernSlipId == null) throw Exception('Concern slip ID not found');

        print(
          '[ConcernSlipDetail] Assigning staff $selectedStaffId to concern slip $concernSlipId',
        );

        final result = await _apiService.assignStaffToConcernSlip(
          concernSlipId,
          selectedStaffId!,
        );

        print('[ConcernSlipDetail] Assignment successful: $result');

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Staff assigned successfully to ${widget.task['id']}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          widget.onAssignmentComplete?.call();
        }
      }
    } catch (e) {
      print('[ConcernSlipDetail] Assignment failed: $e');
      if (mounted) {
        setState(() => _isAssigning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign staff: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
          ),
        ),
        if (value.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPriorityChip(String priority) {
    // This method is kept for backward compatibility but not used
    // Using PriorityTag widget instead
    return PriorityTag(priority);
  }

  String _formatBuildingUnit(String buildingUnit) {
    // Convert "Bldg A - Unit 302" to "A - 1010" format
    if (buildingUnit.contains('Unit')) {
      final parts = buildingUnit.split(' - Unit ');
      if (parts.length == 2) {
        final building = parts[0].replaceAll('Bldg ', '');
        return '$building - 1010';
      }
    }
    return buildingUnit;
  }

  void _deleteTask() async {
    final confirmed = await showDeleteDialog(
      context,
      itemName: 'Task',
      description:
          'Are you sure you want to delete this task ${widget.task['id']}? This action cannot be undone. All associated data will be permanently removed from the system.',
    );

    if (confirmed) {
      try {
        // Call API to delete the concern slip
        await _apiService.deleteConcernSlip(widget.task['id']);

        // Close the dialog and show success message
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task ${widget.task['id']} deleted successfully'),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTenantAttachmentsSection() {
    final attachments =
        (widget.task['rawData']?['attachments'] as List?) ??
        (widget.task['attachments'] as List?) ??
        [];
    if (attachments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Tenant Attachments'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children:
              attachments
                  .map((url) => _buildAttachmentThumb(url.toString()))
                  .toList(),
        ),
      ],
    );
  }

  Widget _buildAttachmentThumb(String url) {
    final isNetwork = url.startsWith('http');
    final borderRadius = BorderRadius.circular(8);

    return ClipRRect(
      borderRadius: borderRadius,
      child:
          isNetwork
              ? Image.network(
                url,
                height: 120,
                width: 160,
                fit: BoxFit.cover,
                errorBuilder:
                    (context, error, stackTrace) =>
                        _buildBrokenThumbPlaceholder(120, 160, borderRadius),
              )
              : Image.asset(
                url,
                height: 120,
                width: 160,
                fit: BoxFit.cover,
                errorBuilder:
                    (context, error, stackTrace) =>
                        _buildBrokenThumbPlaceholder(120, 160, borderRadius),
              ),
    );
  }

  Widget _buildBrokenThumbPlaceholder(double h, double w, BorderRadius radius) {
    return Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: radius,
        border: Border.all(color: Colors.grey[300]!),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.broken_image, color: Colors.grey[400], size: 32),
    );
  }
}
