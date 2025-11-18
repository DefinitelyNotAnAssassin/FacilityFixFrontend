import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/tags.dart';
import '../../../services/api_services.dart';
import '../../../utils/ui_format.dart';
import 'package:intl/intl.dart';

class JobServiceConcernSlipDialog extends StatefulWidget {
  final Map<String, dynamic> task;
  final VoidCallback? onAssignmentComplete;

  const JobServiceConcernSlipDialog({
    super.key,
    required this.task,
    this.onAssignmentComplete,
  });

  @override
  State<JobServiceConcernSlipDialog> createState() =>
      _JobServiceConcernSlipDialogState();

  static void show(
    BuildContext context,
    Map<String, dynamic> task, {
    VoidCallback? onAssignmentComplete,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return JobServiceConcernSlipDialog(
          task: task,
          onAssignmentComplete: onAssignmentComplete,
        );
      },
    );
  }
}

class _JobServiceConcernSlipDialogState
    extends State<JobServiceConcernSlipDialog> {
  final _formKey = GlobalKey<FormState>();
  final APIService _apiService = APIService();

  bool _formValid = false;
  bool _isLoading = false;
  bool _isAssigning = false;
  int _currentStep = 1; // 0 = CS Details, 1 = JS Details, 2 = Assign & Schedule

  String? selectedStaffId;
  String? selectedStaffName;
  DateTime? selectedDate;
  DateTime? selectedEndDate;
  final TextEditingController notesController = TextEditingController();

  List<Map<String, dynamic>> _staffList = [];
  Map<String, dynamic>? _taskData;

  Map<String, dynamic> get task => _taskData ?? widget.task;

  // Helper to check status
  bool get _isPendingStatus {
    final status = task['status']?.toString().toLowerCase() ?? '';
    return status == 'pending';
  }

  bool get _isCompletedStatus {
    final status = task['status']?.toString().toLowerCase() ?? '';
    return status == 'completed' || status.contains('complete');
  }

  @override
  void initState() {
    super.initState();
    notesController.addListener(_revalidate);
    _initializeScheduleDate();
    // Fetch canonical job-service details (if available) and refresh UI
    _loadJobServiceDetails();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revalidate();
    });
  }

  /// Fetch the full job-service record by id and merge into the existing
  /// task map so the dialog uses the canonical server-side fields (same as
  /// TenantJobServiceDetailPage behavior).
  Future<void> _loadJobServiceDetails() async {
    try {
      // The backend stores job services with UUID only, not with "JS-" prefix
      final jobServiceIdRaw = task['id'] ?? task['concern_slip_id'];
      final jobServiceId = jobServiceIdRaw?.toString();
      if (jobServiceId == null || jobServiceId.isEmpty) return;

      setState(() => _isLoading = true);

      // Use API to fetch full payload
      final data = await _apiService.getJobServiceById(jobServiceId);

      // Merge the fetched data into the existing task data to preserve fields
      // from the list view (like 'additionalNotes') while updating with canonical data.
      _taskData = Map<String, dynamic>.from(
        widget.task,
      ); // Start with initial data
      _taskData!.addAll(data); // Merge fetched data on top

      // Debug: log a few top-level fields to aid tracing
      try {
        print('[JobServiceDialog] Fetched job service id: $jobServiceId');
        print('[JobServiceDialog] top-level keys: ${_taskData?.keys.toList()}');
        print(
          '[JobServiceDialog] rawData present: ${_taskData?['rawData'] != null}',
        );
      } catch (_) {}

      // If rawData not present, try to fetch the originating concern slip and attach
      dynamic csId =
          _taskData?['concern_slip_id'] ??
          _taskData?['concernSlipId'] ??
          _taskData?['concern_slip'] ??
          _taskData?['cs_id'];
      final rawData = _taskData?['rawData'];
      if ((rawData == null || rawData.toString().isEmpty) && csId != null) {
        try {
          final cs = await _apiService.getConcernSlipById(csId.toString());
          _taskData?['rawData'] = cs;
        } catch (e) {
          print('[JobServiceDialog] Failed to fetch concern slip $csId: $e');
        }
      }

      // Re-run schedule parsing and refresh staff based on possibly-updated department
      _initializeScheduleDate();
      // Populate assigned staff display for the concern slip details view
      try {
        selectedStaffName = _extractStaffName();
      } catch (_) {}
      await _loadStaffMembers();
      if (mounted) setState(() {});
    } catch (e) {
      print('[JobServiceDialog] Error loading job service details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  void _initializeScheduleDate() {
    // Auto-populate inspection schedule from several possible schedule fields
    final candidates = [
      task['rawData']?['schedule_availability'],
      task['rawData']?['schedule'],
      task['rawData']?['availability'],
      task['rawData']?['schedule_availabilities'],
      task['schedule'],
      task['availability'],
      task['dateRequested'],
      task['requested_at'],
    ];

    // Debug: list candidate values
    try {
      print(
        '[JobServiceDialog] schedule candidates: ${candidates.map((c) => c?.toString() ?? '<null>').toList()}',
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
        try {
          print(
            '[JobServiceDialog] parseRange -> start: $selectedDate, end: $selectedEndDate',
          );
        } catch (_) {}
        return;
      }
    } catch (_) {}

    // Fallback parsing (similar to ConcernSlipDetailDialog)
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

        try {
          print(
            '[JobServiceDialog] parsed schedule -> start: $selectedDate, end: $selectedEndDate',
          );
        } catch (_) {}
      } else if (sa.contains('T')) {
        selectedDate = DateTime.parse(sa);
      } else if (RegExp(r'^\d{4}-\d{2}-\d{2}\$').hasMatch(sa)) {
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
              final d = DateFormat('MMM d, yyyy').parse(sa);
              selectedDate = DateTime(d.year, d.month, d.day, 9, 0);
            } catch (_) {
              try {
                selectedDate = UiDateUtils.parse(sa);
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      print('[JobServiceDialog] Error parsing schedule date: $e');
    }
  }

  Future<void> _loadStaffMembers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String? taskCategory = task['department']?.toString().toLowerCase();
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
        case 'house keeping':
          department = 'house_keeping';
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
        _isLoading = false;
      });

      _autoAssignStaff();
      print('[JobServiceDialog] Loaded ${_staffList.length} staff members');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('[JobServiceDialog] Error loading staff: $e');
    }
  }

  void _revalidate() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (ok != _formValid) setState(() => _formValid = ok);
  }

  void _autoAssignStaff() {
    if (_staffList.isEmpty) return;

    _staffList.sort((a, b) {
      final workloadA = a['current_workload'] ?? 0;
      final workloadB = b['current_workload'] ?? 0;
      return workloadA.compareTo(workloadB);
    });

    final autoSelectedStaff = _staffList.first;
    setState(() {
      selectedStaffId = _getStaffId(autoSelectedStaff);
      selectedStaffName = _getStaffDisplayName(autoSelectedStaff);
    });
    _revalidate();

    print(
      '[JobServiceDialog] Auto-assigned staff: $selectedStaffName (ID: $selectedStaffId)',
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

  String _extractStaffName() {
    try {
      final s = task['staffName'];
      if (s != null && s.toString().trim().isNotEmpty) return s.toString();

      final raw = task['rawData'];
      if (raw is Map) {
        final profile = raw['staff_profile'];
        if (profile is Map) {
          final first = profile['first_name'] ?? profile['firstName'] ?? '';
          final last = profile['last_name'] ?? profile['lastName'] ?? '';
          final full = '${first.toString()} ${last.toString()}'.trim();
          if (full.isNotEmpty) return full;
        }

        final staffNameField =
            raw['staff_name'] ?? raw['staff'] ?? raw['assignee'];
        if (staffNameField != null &&
            staffNameField.toString().trim().isNotEmpty) {
          return staffNameField.toString();
        }
      }
    } catch (e) {
      print('[JobServiceDialog] _extractStaffName error: $e');
    }
    return 'Staff Member';
  }

  Widget _buildSimpleAvatar(String name, {double size = 32}) {
    final parts = name.trim().split(' ');
    String initials = '';
    if (parts.isNotEmpty) {
      initials = parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '';
      if (parts.length > 1 && parts.last.isNotEmpty) {
        initials += parts.last[0].toUpperCase();
      }
    }
    if (initials.isEmpty) initials = '?';

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

  String _formatScheduleDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
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

        if (start != null && end != null)
          return UiDateUtils.dateTimeRange(start, end);
        return s;
      }

      if (s.contains('T')) {
        final d = DateTime.parse(s);
        return UiDateUtils.dateTimeRange(d);
      }

      if (RegExp(r'^\d{4}-\d{2}-\d{2}\$').hasMatch(s)) {
        final parts = s.split('-');
        final d = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        return UiDateUtils.fullDate(d);
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

  /// Prefer returning a UiDateUtils.dateTimeRange when the raw schedule can be
  /// parsed into a DateTime (or a start/end pair). Falls back to
  /// [_formatScheduleDate] for more generic formatting.
  String _formatScheduleToDateTimeRange(String? raw) {
    if (raw == null || raw.toString().trim().isEmpty) return 'N/A';
    final s = raw.toString().trim();

    try {
      // Range like "start - end"
      if (s.contains(' - ')) {
        final parts = s.split(' - ');
        final left = parts[0].trim();
        final right = parts.length > 1 ? parts[1].trim() : '';

        DateTime? start;
        DateTime? end;

        // Try ISO first then UiDateUtils.parse
        try {
          start = DateTime.parse(left);
        } catch (_) {
          try {
            start = UiDateUtils.parse(left);
          } catch (_) {}
        }

        try {
          end = DateTime.parse(right);
        } catch (_) {
          try {
            end = UiDateUtils.parse(right);
          } catch (_) {}
        }

        if (start != null && end != null)
          return UiDateUtils.dateTimeRange(start, end);
        if (start != null) return UiDateUtils.dateTimeRange(start);
      }

      // Single datetime
      try {
        final d = DateTime.parse(s);
        return UiDateUtils.dateTimeRange(d);
      } catch (_) {}

      try {
        final d = UiDateUtils.parse(s);
        return UiDateUtils.dateTimeRange(d);
      } catch (_) {}
    } catch (e) {
      print('[JobServiceDialog] _formatScheduleToDateTimeRange error: $e');
    }

    // Fallback to existing flexible formatter
    return _formatScheduleDate(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
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
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child:
                      _currentStep == 0
                          ? _buildConcernSlipDetails()
                          : _currentStep == 1
                          ? _buildJobServiceDetails()
                          : _buildAssignmentForm(),
                ),
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    String title;
    switch (_currentStep) {
      case 0:
        title = 'Concern Slip Details';
        break;
      case 1:
        title = 'Job Service Details';
        break;
      case 2:
        title = 'Assign & Schedule Work';
        break;
      default:
        title = 'Job Service';
    }

    return Container(
      padding: const EdgeInsets.only(left: 32, right: 24, top: 20, bottom: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
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

  // Step 0: Concern Slip Details
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
                    task['title'] ?? 'No Title',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    task['id'] ?? 'N/A',
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
                      final ds = task['dateRequested'] ?? task['rawData']?['schedule_availability'];
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
                widget.task['rawData']?['reported_by'] ?? 'N/A',
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildDetailItem(
                'DEPARTMENT',
                task['department'] ?? 'N/A',
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
                _formatBuildingUnit(task['buildingUnit'] ?? 'N/A'),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: InkWell(
                onTap: () async {
                  // Open date time picker and update selectedDate
                  await _selectDateTime(context);
                  if (selectedDate != null) {
                    // Update task map so subsequent renders use the new value
                    try {
                      task['dateRequested'] = selectedDate!.toIso8601String();
                    } catch (_) {}
                    setState(() {});
                  }
                },
                child: _buildDetailItem(
                  'SCHEDULE AVAILABILITY',
                  selectedDate != null
                      ? UiDateUtils.dateTimeRange(
                        selectedDate!,
                        selectedEndDate,
                      )
                      : _formatScheduleDate(
                        task['dateRequested'] ??
                            task['rawData']?['schedule_availability'],
                      ),
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
          task['description'] ?? 'No description available.',
          style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[700]),
        ),
      ],
    );
  }

  // Assessment Section
  Widget _buildAssessmentSection() {
    // Use assessment and recommendation from rawData
    final assessment =
        task['assessment'] ?? task['rawData']?['staff_assessment'];
    final recommendation =
        task['recommendation'] ?? task['rawData']?['staff_recommendation'];
    final resolutionType = task['rawData']?['resolution_type'];

    if (assessment == null &&
        recommendation == null &&
        resolutionType == null) {
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
      ],
    );
  }

  // Shared assigned staff display for both details and assignment form
  Widget _buildAutoAssignedStaffDisplay() {
    // Use assigned staff or fallback to selectedStaffName
    String staffName = selectedStaffName ?? '';
    if (staffName.isEmpty) {
      final data = task;
      dynamic assignedStaff =
          data['rawData']?['assigned_staff'] ??
          data['rawData']?['assigned_to'] ??
          data['assigned_staff'] ??
          data['assigned_to'] ??
          data['assigned_staff_name'];

      if (assignedStaff != null) {
        if (assignedStaff is String) {
          staffName = assignedStaff;
        } else if (assignedStaff is Map<String, dynamic>) {
          staffName =
              assignedStaff['name'] ??
              assignedStaff['full_name'] ??
              ((assignedStaff['first_name'] ?? '') +
                      ' ' +
                      (assignedStaff['last_name'] ?? ''))
                  .trim();
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
                      task['department'] ?? 'No Department',
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

  // Step 1: Job Service Details
  Widget _buildJobServiceDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title with JS ID (matching CS dialog style)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Job Service',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    task['serviceId'] ?? task['id'] ?? 'N/A',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    // Format date as: "Aug 23, 2025"
                    'Date Requested: ${(() {
                      final ds = task['dateRequested'] ?? task['rawData']?['schedule_availability'];
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
                  const SizedBox(height: 8),
                  // Small action to view the originating concern slip
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentStep = 0; // show concern slip details
                        });
                      },
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View Concern Slip'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue[700],
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            PriorityTag(task['priority'] ?? ''),
            const SizedBox(width: 8),
            StatusTag(task['status'] ?? ''),
          ],
        ),
        const SizedBox(height: 24),
        Divider(color: Colors.grey[200], thickness: 1, height: 1),
        const SizedBox(height: 24),

        // Service Details
        _buildSectionTitle('Service Details'),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _buildDetailItem(
                'REQUESTED BY',
                (() {
                  final candidates = [
                    task['requested_by_name'],
                    task['requestedBy'],
                    task['requester_name'],
                    task['rawData']?['requested_by_name'],
                    task['rawData']?['requester_name'],
                    task['rawData']?['reported_by'],
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
                'SCHEDULE DATE',
                selectedDate != null
                    ? UiDateUtils.dateTimeRange(selectedDate!, selectedEndDate)
                    : _formatScheduleToDateTimeRange(task['schedule']),
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
                task['buildingUnit'] ?? 'N/A',
              ),
            ),
            const SizedBox(width: 24),
            const Expanded(child: SizedBox()),
          ],
        ),
        const SizedBox(height: 24),

        Divider(color: Colors.grey[200], thickness: 1, height: 1),
        const SizedBox(height: 24),

        // Additional Notes
        _buildSectionTitle('Additional Notes'),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Text(
            task['additionalNotes'] ?? '',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.grey[800],
            ),
          ),
        ),

        if (_isCompletedStatus) ...[
          const SizedBox(height: 24),
          Divider(color: Colors.grey[200], thickness: 1, height: 1),
          const SizedBox(height: 24),
          _buildCompletionAssessmentSection(),
        ],
      ],
    );
  }

  // Step 2: Assignment Form

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
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'JS: ${task['serviceId'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            task['title'] ?? 'Job Service Request',
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
                    PriorityTag(task['priority'] ?? 'Low'),
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

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Work Schedule',
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
                                  ? UiDateUtils.dateTimeRange(
                                    selectedDate!,
                                    selectedEndDate,
                                  )
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

  // Backwards-compatible wrapper (some code references _buildAssignmentForm)
  Widget _buildAssignmentForm() => _buildAssignmentFormView();

  Future<void> _selectDateTime(BuildContext context) async {
    // First select date
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030, 12),
    );

    if (pickedDate != null) {
      // Then select time
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime:
            selectedDate != null
                ? TimeOfDay.fromDateTime(selectedDate!)
                : const TimeOfDay(hour: 9, minute: 0),
      );

      if (pickedTime != null) {
        setState(() {
          selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
        _revalidate();
      }
    }
  }

  Widget _buildFooter(BuildContext context) {
    final hasBack =
        _currentStep !=
        1; // show back on concern slip (0) and assignment (2), but NOT on job service (1)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        mainAxisAlignment:
            hasBack ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
        children: [
          if (hasBack)
            OutlinedButton(
              onPressed:
                  _isAssigning
                      ? null
                      : () {
                        if (_currentStep == 0) {
                          // On concern slip details, Back should close the dialog
                          Navigator.of(context).pop();
                        } else {
                          // On assignment step (2), go back to previous step
                          setState(() {
                            _currentStep--;
                          });
                        }
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

          if (_currentStep == 1 && !_isCompletedStatus)
            ElevatedButton.icon(
              onPressed: () async {
                setState(() {
                  _currentStep = 2;
                });
                await _loadStaffMembers();
                _autoAssignStaff();
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

          if (_currentStep == 2)
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
        ],
      ),
    );
  }

  Future<void> _handleSaveAndAssign() async {
    if (!_formValid ||
        selectedStaffId == null ||
        selectedStaffId!.toString().trim().isEmpty) {
      // Ensure a staff member is selected before proceeding
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a staff member to assign'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    setState(() => _isAssigning = true);

    try {
      // Use the raw ID for API calls, not the display ID ('serviceId')
      // The raw ID is typically stored under 'id' or in 'rawData'.
      final jobServiceId = task['rawData']?['id'] ?? task['id']?.toString();

      if (jobServiceId == null || jobServiceId.isEmpty)
        throw Exception('Job Service ID not found');

      // Persist any selected schedule to the job service before assignment
      try {
        if (selectedDate != null) {
          DateTime start = selectedDate!;
          DateTime? end = selectedEndDate;
          // If end exists but is before start, prompt the admin to correct it instead of auto-fixing.
          if (end != null && end.isBefore(start)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Selected end time is before start time. Please correct the schedule.',
                ),
              ),
            );
          } else {
            await _apiService.updateJobServiceSchedule(
              jobServiceId,
              start,
              end,
            );
          }
        }
      } catch (e) {
        print('[JobServiceDialog] Failed to update schedule: $e');
        // Non-fatal: continue to assignment even if schedule update fails
      }

      final staffId = selectedStaffId!.toString();
      print(
        '[JobServiceDialog] Assigning staff $staffId to job service $jobServiceId',
      );

      final result = await _apiService.assignStaffToJobService(
        jobServiceId,
        staffId,
      );
      // Also assign the same staff to the originating Concern Slip (if any).
      try {
        dynamic csId =
            _taskData?['concern_slip_id'] ??
            _taskData?['concernSlipId'] ??
            _taskData?['cs_id'] ??
            _taskData?['csId'] ??
            _taskData?['rawData']?['id'] ??
            _taskData?['rawData']?['concern_slip_id'];
        final csIdStr = csId?.toString();
        if (csIdStr != null && csIdStr.isNotEmpty) {
          try {
            await _apiService.assignStaffToConcernSlip(csIdStr, staffId);
            // Update local rawData to reflect assigned staff
            _taskData ??= Map<String, dynamic>.from(widget.task);
            _taskData?['rawData'] ??= {};
            _taskData?['rawData']?['assigned_staff'] = staffId;
            _taskData?['rawData']?['assigned_staff_name'] =
                selectedStaffName ?? '';
          } catch (e) {
            print(
              '[JobServiceDialog] Warning: failed to assign staff to concern slip $csIdStr: $e',
            );
          }
        }
      } catch (e) {
        print('[JobServiceDialog] _syncAssignToConcernSlip error: $e');
      }

      print('[JobServiceDialog] Assignment successful: $result');

      if (mounted) {
        // Show confirmation before closing the dialog so the SnackBar is visible in the app scaffold
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Staff assigned successfully to ${task['serviceId']}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
        widget.onAssignmentComplete?.call();
      }
    } catch (e) {
      print('[JobServiceDialog] Assignment failed: $e');
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

  Widget _buildCompletionAssessmentSection() {
    final assessment = task['assessment'] ?? task['completionAssessment'];
    final assessorName =
        task['assessorName'] ?? task['staffName'] ?? 'Staff Member';
    final dateAssessed = task['dateAssessed'] ?? task['assessmentDate'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Completion Assessment'),
        const SizedBox(height: 16),

        // Assessor info
        Row(
          children: [
            _buildSimpleAvatar(assessorName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assessorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task['department'] ?? 'No Department',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
            if (dateAssessed != null)
              Text(
                _formatAssessmentDate(dateAssessed),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),

        if (assessment != null) ...[
          const SizedBox(height: 16),
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
      ],
    );
  }

  String _formatAssessmentDate(dynamic dateVal) {
    if (dateVal == null) return '';
    try {
      final d =
          dateVal is DateTime ? dateVal : DateTime.parse(dateVal.toString());
      return UiDateUtils.fullDate(d);
    } catch (_) {
      return dateVal.toString();
    }
  }
}
