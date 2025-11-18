import 'dart:async';
import 'package:facilityfix/config/env.dart';
import 'package:facilityfix/services/api_services.dart';
import 'package:facilityfix/services/auth_storage.dart';
import 'package:facilityfix/services/chat_helper.dart';
import 'package:facilityfix/staff/announcement.dart';
import 'package:facilityfix/staff/calendar.dart';
import 'package:facilityfix/staff/home.dart';
import 'package:facilityfix/staff/inventory.dart';
import 'package:facilityfix/staff/workorder.dart';
import 'package:facilityfix/staff/form/assessment_form.dart';
import 'package:facilityfix/staff/view_details/concern_slip.dart';
import 'package:facilityfix/widgets/view_details.dart';
import 'package:flutter/material.dart';
import 'package:facilityfix/widgets/app&nav_bar.dart';
import 'package:facilityfix/widgets/buttons.dart' as fx;
import 'package:facilityfix/widgets/modals.dart';

class StaffJobServiceDetailPage extends StatefulWidget {
  final String jobServiceId;

  const StaffJobServiceDetailPage({super.key, required this.jobServiceId});

  @override
  State<StaffJobServiceDetailPage> createState() =>
      _StaffJobServiceDetailPageState();
}

class _StaffJobServiceDetailPageState extends State<StaffJobServiceDetailPage> {
  int _selectedIndex = 1;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Map<String, dynamic>? _jobServiceData;
  String? _currentUserId;

  // Status update form controllers
  final _statusFormKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();

  // Form state
  String _selectedStatus = 'pending';
  bool _isSubmittingStatus = false;

  // On Hold state
  Map<String, dynamic>? holdMeta;

  // Available status options for job services
  final List<String> _statusOptions = [
    'pending',
    'assigned',
    'in_progress',
    'completed',
    'cancelled',
    'on_hold',
  ];

  final List<NavItem> _navItems = const [
    NavItem(icon: Icons.home),
    NavItem(icon: Icons.work),
    NavItem(icon: Icons.build),
    NavItem(icon: Icons.announcement_rounded),
    NavItem(icon: Icons.calendar_month),
    NavItem(icon: Icons.inventory),
  ];

  @override
  void initState() {
    super.initState();
    // Ensure we have a valid default status
    if (!_statusOptions.contains(_selectedStatus)) {
      _selectedStatus =
          _statusOptions.isNotEmpty ? _statusOptions.first : 'pending';
    }
    _loadJobServiceData();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final profile = await AuthStorage.getProfile();
    if (profile != null && mounted) {
      setState(() {
        _currentUserId = profile['uid'] ?? profile['user_id'];
      });
    }
  }

  Future<void> _loadJobServiceData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Use staff role for API service
      final apiService = APIService(roleOverride: AppRole.staff);
      final data = await apiService.getJobServiceById(widget.jobServiceId);

      // Enrich data with user names if we have user IDs
      await _enrichWithUserNames(data, apiService);

      if (mounted) {
        setState(() {
          _jobServiceData = data;
          final currentStatus = (data['status'] ?? 'pending').toString();
          if (!_statusOptions.contains(currentStatus)) {
            _statusOptions.add(currentStatus);
          }
          _selectedStatus = currentStatus;
          _isLoading = false;
        });

        // Debug: Print available fields
        print('[JobService] Available data fields:');
        print('  id: ${data['id']}');
        print('  formatted_id: ${data['formatted_id']}');
        print('  job_service_id: ${data['job_service_id']}');
        print('  js_id: ${data['js_id']}');
        print('  concern_slip_id: ${data['concern_slip_id']}');
        print('  requested_by: ${data['requested_by']}');
        print('  requested_by_name: ${data['requested_by_name']}');
        print('  requester_name: ${data['requester_name']}');
        print('  tenant_name: ${data['tenant_name']}');
        print('  tenant_id: ${data['tenant_id']}');
        print('  unit_id: ${data['unit_id']}');
        print('  assigned_to: ${data['assigned_to']}');
        print('  assigned_to_name: ${data['assigned_to_name']}');
        print('  assigned_staff: ${data['assigned_staff']}');
        print('  assigned_staff_name: ${data['assigned_staff_name']}');
        print('  staff_name: ${data['staff_name']}');
        print('  category: ${data['category']}');
        print('  department: ${data['department']}');
        print('  staff_department: ${data['staff_department']}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _enrichWithUserNames(
    Map<String, dynamic> data,
    APIService apiService,
  ) async {
    try {
      // Fetch requested_by name if we have the ID but not the name
      if (data.containsKey('requested_by') &&
          data['requested_by'] != null &&
          !data.containsKey('requested_by_name')) {
        final userId = data['requested_by'].toString();
        print('[DEBUG] Fetching user name for requested_by: $userId');
        final userData = await apiService.getUserById(userId);
        if (userData != null) {
          final firstName = userData['first_name'] ?? '';
          final lastName = userData['last_name'] ?? '';
          data['requested_by_name'] = '$firstName $lastName'.trim();
          print(
            '[DEBUG] Set requested_by_name to: ${data['requested_by_name']}',
          );
        }
      }

      // Fetch assigned_to name if we have the ID but not the name
      if (data.containsKey('assigned_to') &&
          data['assigned_to'] != null &&
          !data.containsKey('assigned_to_name')) {
        final userId = data['assigned_to'].toString();
        print('[DEBUG] Fetching user name for assigned_to: $userId');
        final userData = await apiService.getUserById(userId);
        if (userData != null) {
          final firstName = userData['first_name'] ?? '';
          final lastName = userData['last_name'] ?? '';
          data['assigned_to_name'] = '$firstName $lastName'.trim();
          print('[DEBUG] Set assigned_to_name to: ${data['assigned_to_name']}');
        }
      }
    } catch (e) {
      print('[DEBUG] Error enriching user names: $e');
      // Don't fail the entire load if we can't fetch user names
    }
  }

  void _onTabTapped(int index) {
    final destinations = [
      const HomePage(),
      const WorkOrderPage(),
      const AnnouncementPage(),
      const CalendarPage(),
      const InventoryPage(),
    ];
    if (index != _selectedIndex) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destinations[index]),
      );
    }
  }

  Future<void> _updateJobServiceStatus(
    String newStatus, {
    String? notes,
  }) async {
    if (_statusOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No valid status options available.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final currentStatus = _jobServiceData?['status'] ?? '';
    if (newStatus == currentStatus) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status has not changed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSubmittingStatus = true;
      _selectedStatus = newStatus;
    });

    try {
      final apiService = APIService(roleOverride: AppRole.staff);
      final updated = await apiService.updateJobServiceStatus(
        jobServiceId: widget.jobServiceId,
        status: newStatus,
        notes: notes,
      );

      if (!mounted) return;

      setState(() {
        _isSubmittingStatus = false;
        _jobServiceData = updated;
        final updatedStatus = (updated['status'] ?? newStatus).toString();
        if (!_statusOptions.contains(updatedStatus)) {
          _statusOptions.add(updatedStatus);
        }
        _selectedStatus = updatedStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job service status updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSubmittingStatus = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completeJobService() async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => CustomPopup(
            title: 'Complete Job Service',
            message:
                'Are you sure you want to mark this job service as completed? This action cannot be undone.',
            primaryText: 'Complete',
            secondaryText: 'Cancel',
            onPrimaryPressed: () => Navigator.of(context).pop(true),
            onSecondaryPressed: () => Navigator.of(context).pop(false),
          ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmittingStatus = true);

    try {
      final apiService = APIService(roleOverride: AppRole.staff);
      await apiService.completeJobService(widget.jobServiceId);

      if (mounted) {
        setState(() => _isSubmittingStatus = false);

        // Show success dialog
        showDialog(
          context: context,
          builder:
              (_) => CustomPopup(
                title: 'Success',
                message: 'Job service has been marked as completed.',
                primaryText: 'OK',
                onPrimaryPressed: () {
                  Navigator.of(context).pop();
                  // Refresh the job service data
                  _loadJobServiceData();
                },
              ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingStatus = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete job service: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      return null;
    }
  }

  List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  bool _isDeletableStatus(dynamic status) {
    if (status == null) return false;
    final s = status.toString().toLowerCase().trim();
    return s == 'pending' || s == 'complete' || s == 'completed' || s == 'done';
  }

  void _showDeleteDialog() {
    if (_jobServiceData == null) return;

    final status = (_jobServiceData!['status'] ?? '').toString().toLowerCase();
    if (!_isDeletableStatus(status)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only pending or completed requests can be deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Request'),
            content: const Text(
              'Are you sure you want to delete this request? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _deleteJobService();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteJobService() async {
    try {
      final apiService = APIService(roleOverride: AppRole.staff);
      await apiService.deleteJobService(widget.jobServiceId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openStatusUpdateSheet() async {
    if (_jobServiceData == null || _statusOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update status right now.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    String pendingStatus =
        _statusOptions.contains(_selectedStatus)
            ? _selectedStatus
            : _statusOptions.first;

    _notesController.clear();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: bottomInset + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Form(
                key: _statusFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Update Job Service Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: pendingStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          _statusOptions
                              .map(
                                (status) => DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(
                                    status.replaceAll('_', ' ').toUpperCase(),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() => pendingStatus = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    fx.FilledButton(
                      label:
                          _isSubmittingStatus ? 'Updating...' : 'Update Status',
                      backgroundColor: const Color(0xFF005CE7),
                      textColor: Colors.white,
                      withOuterBorder: false,
                      isDisabled: _isSubmittingStatus,
                      onPressed: () {
                        if (_isSubmittingStatus) return;
                        final notes = _notesController.text.trim();
                        Navigator.of(sheetContext).pop();
                        _updateJobServiceStatus(
                          pendingStatus,
                          notes: notes.isEmpty ? null : notes,
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    _notesController.clear();
  }

  String _formatStatus(String? status) {
    if (status == null) return 'Unknown';
    return status.replaceAll('_', ' ').toUpperCase();
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'on_hold':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  void _openChat() async {
    if (_jobServiceData == null) return;

    final tenantId = _jobServiceData!['tenant_id']?.toString();
    if (tenantId == null || tenantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to start chat: Tenant information not available',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await ChatHelper.navigateToJobServiceChat(
      context: context,
      jobServiceId: widget.jobServiceId,
      isStaff: true,
    );
  }

  Future<void> _onHoldPressed() async {
    // Check if currently on hold
    bool isOnHold =
        _jobServiceData?['status']?.toString().toLowerCase() == 'on_hold';

    if (isOnHold) {
      // Resume task - set status back to assigned
      try {
        await _updateJobServiceStatus(
          'assigned',
          notes: 'Task resumed from on-hold status',
        );

        setState(() {
          holdMeta = null;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to resume task: ${e.toString()}'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Put on hold - show bottom sheet
      final result = await showHoldSheet(context);

      if (result == null) return; // User cancelled

      try {
        String notes = 'Reason: ${result.reason}';
        if (result.note != null && result.note!.isNotEmpty) {
          notes += '\nNotes: ${result.note}';
        }
        if (result.resumeAt != null) {
          notes += '\nResume at: ${result.resumeAt}';
        }

        await _updateJobServiceStatus('on_hold', notes: notes);

        setState(() {
          holdMeta = {
            'reason': result.reason,
            'note': result.note,
            'resumeAt': result.resumeAt,
          };
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task put on hold'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to put task on hold: ${e.toString()}'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _createAssessment() async {
    if (_jobServiceData == null) return;

    // Navigate to assessment form (simplified version without resolution type)
    // Pass a flag to indicate this is for a Job Sevice
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AssessmentForm(
              concernSlipId: widget.jobServiceId, // Use job service ID
              concernSlipData: _jobServiceData,
              requestType:
                  'Job Service ${_jobServiceData!['formatted_id'] ?? _jobServiceData!['id'] ?? ''}',
              showResolutionType:
                  false, // Hide resolution type for job services
            ),
      ),
    );

    // Refresh data if assessment was submitted
    if (result == true && mounted) {
      await _loadJobServiceData();
    }
  }

  void _viewConcernSlip() {
    if (_jobServiceData == null) return;

    final concernSlipId = _jobServiceData!['concern_slip_id'];
    if (concernSlipId == null || concernSlipId.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No concern slip associated with this job service'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => StaffConcernSlipDetailPage(
              concernSlipId: concernSlipId.toString(),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        leading: const BackButton(),
        title: 'Job Service Details',
        showMore: true,
        showDelete:
            _jobServiceData != null &&
            _isDeletableStatus(_jobServiceData!['status']),
        onDeleteTap: _showDeleteDialog,
      ),
      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading job service',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      fx.FilledButton(
                        label: 'Retry',
                        backgroundColor: const Color(0xFF005CE7),
                        textColor: Colors.white,
                        withOuterBorder: false,
                        onPressed: _loadJobServiceData,
                      ),
                    ],
                  ),
                )
                : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                  child: Column(
                    children: [
                      // Job Service Information
                      if (_jobServiceData != null) ...[
                        JobServiceDetails(
                          // Basic Information
                          // Use job_service_id or js_id if available, otherwise use formatted_id
                          id:
                              _jobServiceData!['job_service_id']?.toString() ??
                              _jobServiceData!['js_id']?.toString() ??
                              _jobServiceData!['formatted_id'] ??
                              _jobServiceData!['id'] ??
                              '',
                          formattedId: _jobServiceData!['formatted_id'],
                          concernSlipId:
                              _jobServiceData!['concern_slip_id']?.toString() ??
                              '',
                          createdAt:
                              _parseDateTime(_jobServiceData!['created_at']) ??
                              DateTime.now(),
                          updatedAt: _parseDateTime(
                            _jobServiceData!['updated_at'],
                          ),
                          requestTypeTag:
                              _jobServiceData!['request_type'] ?? 'Job Service',
                          priority: _jobServiceData!['priority'],
                          statusTag: _jobServiceData!['status'] ?? 'pending',
                          resolutionType: _jobServiceData!['resolution_type'],
                          departmentTag: _jobServiceData!['category'],

                          // Tenant / Requester - Use name fields, fallback to IDs
                          requestedBy:
                              _jobServiceData!['requested_by_name'] ??
                              _jobServiceData!['requested_by'] ??
                              '',
                          unitId:
                              _jobServiceData!['location'] ??
                              _jobServiceData!['unit_id'] ??
                              '',
                          scheduleAvailability:
                              _jobServiceData!['schedule_availability'] ??
                              _jobServiceData!['availability'] ??
                              _jobServiceData!['scheduled_date'],
                          additionalNotes:
                              _jobServiceData!['additional_notes'] ??
                              _jobServiceData!['description'] ??
                              _jobServiceData!['notes'],

                          // Staff - Use assigned_to_name (enriched from getUserById)
                          assignedStaff:
                              _jobServiceData!['assigned_to_name'] ??
                              _jobServiceData!['assigned_to'],
                          staffDepartment: _jobServiceData!['staff_department'],
                          staffPhotoUrl: _jobServiceData!['staff_photo_url'],

                          // Documentation
                          startedAt: _parseDateTime(
                            _jobServiceData!['started_at'] ??
                                _jobServiceData!['start_time'],
                          ),
                          completedAt: _parseDateTime(
                            _jobServiceData!['completed_at'] ??
                                _jobServiceData!['end_time'],
                          ),
                          completionAt: _parseDateTime(
                            _jobServiceData!['completion_at'],
                          ),
                          assessedAt: _parseDateTime(
                            _jobServiceData!['assessed_at'],
                          ),
                          assessment:
                              _jobServiceData!['assessment'] ??
                              _jobServiceData!['staff_assessment'],
                          staffAttachments: _parseStringList(
                            _jobServiceData!['staff_attachments'] ??
                                _jobServiceData!['attachments'],
                          ),

                          // Callbacks
                          onViewConcernSlip: _viewConcernSlip,
                          isStaff: true,
                        ),
                      ],
                      if (_jobServiceData!['assessment'] != null ||
                          _jobServiceData!['completion_notes'] != null ||
                          _jobServiceData!['staff_assessment'] != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.assignment_turned_in,
                                    color: Colors.blue[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Completion Assessment',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _jobServiceData!['assessment'] ??
                                    _jobServiceData!['completion_notes'] ??
                                    _jobServiceData!['staff_assessment'] ??
                                    '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: Color(0xFF374151),
                                ),
                              ),
                              if (_jobServiceData!['assessed_by_name'] !=
                                  null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Assessed by: ${_jobServiceData!['assessed_by_name']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              if (_jobServiceData!['assessed_at'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Date: ${_parseDateTime(_jobServiceData!['assessed_at'])?.toString() ?? 'N/A'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show On Hold and Create Assessment buttons if staff is assigned and no assessment exists
          if (_jobServiceData != null &&
              _jobServiceData!['assigned_to'] != null &&
              _jobServiceData!['assessment'] == null &&
              (_jobServiceData!['status']?.toString().toLowerCase() ==
                      'assigned' ||
                  _jobServiceData!['status']?.toString().toLowerCase() ==
                      'on_hold'))
            SafeArea(
              top: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: fx.OutlinedPillButton(
                          label:
                              _jobServiceData!['status']
                                          ?.toString()
                                          .toLowerCase() ==
                                      'on_hold'
                                  ? 'Resume Task'
                                  : 'On Hold',
                          icon:
                              _jobServiceData!['status']
                                          ?.toString()
                                          .toLowerCase() ==
                                      'on_hold'
                                  ? Icons.play_arrow
                                  : Icons.pause,
                          borderColor: const Color(0xFF005CE7),
                          foregroundColor: const Color(0xFF005CE7),
                          onPressed: _onHoldPressed,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: fx.FilledButton(
                          label: 'Create Assessment',
                          backgroundColor: const Color(0xFF005CE7),
                          textColor: Colors.white,
                          withOuterBorder: false,
                          onPressed: _createAssessment,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          NavBar(
            items: _navItems,
            currentIndex: _selectedIndex,
            onTap: _onTabTapped,
          ),
        ],
      ),
    );
  }
}
