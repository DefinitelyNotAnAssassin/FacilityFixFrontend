import 'dart:async';
import 'package:facilityfix/config/env.dart';
import 'package:facilityfix/services/api_services.dart';
import 'package:facilityfix/services/auth_storage.dart';
import 'package:facilityfix/services/chat_helper.dart';
import 'package:facilityfix/widgets/view_details.dart';
import 'package:facilityfix/utils/ui_format.dart';
import 'package:flutter/material.dart';
import 'package:facilityfix/widgets/app&nav_bar.dart';
import 'package:facilityfix/widgets/buttons.dart' as fx;
import 'package:facilityfix/widgets/modals.dart';
import 'package:facilityfix/tenant/announcement.dart';
import 'package:facilityfix/tenant/home.dart';
import 'package:facilityfix/tenant/profile.dart';
import 'package:facilityfix/tenant/repair_management.dart';
import 'package:facilityfix/tenant/request_forms.dart';
import 'package:facilityfix/tenant/view_details/concern_slip_details.dart';
import 'package:facilityfix/tenant/view_details/workorder_details.dart';

class TenantJobServiceDetailPage extends StatefulWidget {
  final String jobServiceId;
  final String? initialTitle;

  const TenantJobServiceDetailPage({
    super.key,
    required this.jobServiceId,
    this.initialTitle,
  });

  @override
  State<TenantJobServiceDetailPage> createState() =>
      _TenantJobServiceDetailPageState();
}

class _TenantJobServiceDetailPageState
    extends State<TenantJobServiceDetailPage> {
  int _selectedIndex = 1;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Map<String, dynamic>? _fallbackConcernSlip;
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
      final apiService = APIService(roleOverride: AppRole.tenant);
      final data = await apiService.getJobServiceById(widget.jobServiceId);

      // Enrich data with user names if we have user IDs
      await _enrichWithUserNames(data, apiService);

      // Convert any schedule availability fields into a DateTimeRange so
      // downstream widgets receive a typed value.
      try {
        String? scheduleAvailabilityStr;
        final candidates = [
          data['schedule_availability'],
          data['rawData']?['schedule_availability'],
          data['rawData']?['schedule'],
          data['rawData']?['availability'],
          data['schedule'],
          data['availability'],
          data['requested_at'],
          data['dateRequested'],
        ];
        for (final c in candidates) {
          if (c == null) continue;
          if (c is List && c.isNotEmpty) {
            final first = c.first;
            if (first != null) {
              scheduleAvailabilityStr = first.toString();
              break;
            }
          } else if (c is String) {
            if (c.trim().isNotEmpty) {
              scheduleAvailabilityStr = c.trim();
              break;
            }
          } else {
            try {
              final s = c.toString();
              if (s.trim().isNotEmpty) {
                scheduleAvailabilityStr = s.trim();
                break;
              }
            } catch (_) {}
          }
        }

        final DateTimeRange? scheduleRange = UiDateUtils.parseRange(
          scheduleAvailabilityStr,
        );
        if (scheduleRange != null) {
          data['schedule_availability'] = scheduleRange;
        }
      } catch (e) {
        // non-fatal
      }

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

        // Debug logging
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
        // If job service fetch failed, try to fetch a concern slip with the
        // same id so we can present the tenant with an action (fill JS/WOP)
        try {
          final api = APIService();
          final cs = await api.getConcernSlipById(widget.jobServiceId);
          setState(() {
            _fallbackConcernSlip = cs;
            _isLoading = false;
            _hasError = false;
          });
          return;
        } catch (_) {
          setState(() {
            _hasError = true;
            _errorMessage = e.toString();
            _isLoading = false;
          });
        }
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

  void _viewConcernSlipFromFallback() {
    final csId = _fallbackConcernSlip?['id']?.toString() ?? widget.jobServiceId;
    if (csId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No concern slip available'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TenantConcernSlipDetailPage(concernSlipId: csId),
      ),
    );
  }

  Future<void> _createJobServiceFromConcernSlip() async {
    final csId = _fallbackConcernSlip?['id']?.toString() ?? widget.jobServiceId;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => RequestForm(
              requestType: 'Job Service',
              concernSlipId: csId,
              returnToCallerOnSuccess: true,
            ),
      ),
    );

    // Support the new canonical return shape {resource_type, resource_id, raw}
    // while remaining backwards-compatible with older raw result maps.
    if (mounted && result is Map<String, dynamic>) {
      String? jsId;
      if (result.containsKey('resource_type') &&
          result.containsKey('resource_id')) {
        final rt = result['resource_type']?.toString() ?? '';
        final rid = result['resource_id']?.toString() ?? '';
        if (rt == 'job_service' && rid.isNotEmpty) jsId = rid;
        // If resource_type was omitted but resource_id exists, try it below
      }

      // Backwards compatibility: check legacy keys
      jsId ??=
          result['job_service_id']?.toString() ??
          result['id']?.toString() ??
          result['formatted_id']?.toString();

      if (jsId != null && jsId.isNotEmpty) {
        // Navigate directly to the Job Service details page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => TenantJobServiceDetailPage(jobServiceId: jsId!),
          ),
        );
        return;
      }
    }

    // Fallback: refresh the page data as before
    if (mounted) await _loadJobServiceData();
  }

  Future<void> _createWorkOrderFromConcernSlip() async {
    final csId = _fallbackConcernSlip?['id']?.toString() ?? widget.jobServiceId;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => RequestForm(
              requestType: 'Work Order',
              concernSlipId: csId,
              returnToCallerOnSuccess: true,
            ),
      ),
    );

    // Accept canonical return shape and legacy maps
    if (mounted && result is Map<String, dynamic>) {
      String? woId;
      if (result.containsKey('resource_type') &&
          result.containsKey('resource_id')) {
        final rt = result['resource_type']?.toString() ?? '';
        final rid = result['resource_id']?.toString() ?? '';
        if (rt == 'work_order' && rid.isNotEmpty) woId = rid;
      }

      woId ??=
          result['work_order_id']?.toString() ??
          result['id']?.toString() ??
          result['formatted_id']?.toString();

      if (woId != null && woId.isNotEmpty) {
        // Navigate directly to the Work Order details page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => WorkOrderDetailsPage(
                  workOrderId: woId!,
                  selectedTabLabel: '',
                ),
          ),
        );
        return;
      }
    }

    // Fallback: refresh the page data as before
    if (mounted) await _loadJobServiceData();
  }

  void _onTabTapped(int index) {
    final destinations = [
      const HomePage(),
      const WorkOrderPage(),
      const AnnouncementPage(),
      const ProfilePage(),
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
      final apiService = APIService(roleOverride: AppRole.tenant);
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
      // Use tenant role for completing job service
      final apiService = APIService(roleOverride: AppRole.tenant);
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
      final apiService = APIService(roleOverride: AppRole.tenant);
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

  void _openStatusUpdateSheet() async {
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
            (context) => TenantConcernSlipDetailPage(
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
                          // Prefer server-provided title, fall back to the card title passed in when available
                          title:
                              (_jobServiceData!['title'] != null &&
                                      _jobServiceData!['title']
                                          .toString()
                                          .isNotEmpty)
                                  ? _jobServiceData!['title'].toString()
                                  : widget.initialTitle,
                          isStaff: false,
                        ),
                      ] else if (_fallbackConcernSlip != null) ...[
                        // Show an action required panel when the job service is
                        // missing but a concern slip exists that requires tenant action
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE6EDF8)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Action required',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'This request has been inspected by staff and requires you to fill the next step. Please open the appropriate form to continue.',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF374151),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Builder(
                                builder: (ctx) {
                                  // Determine which button(s) to show based on the
                                  // concern slip's resolution_type for clearer UX.
                                  final resType =
                                      (_fallbackConcernSlip!['resolution_type']
                                                  ?.toString() ??
                                              '')
                                          .toLowerCase();
                                  final showJS =
                                      resType.isEmpty ||
                                      resType.contains('job') ||
                                      resType.contains('job_service');
                                  final showWO =
                                      resType.isEmpty ||
                                      resType.contains('work') ||
                                      resType.contains('work_permit') ||
                                      resType.contains('work_order') ||
                                      resType.contains('wop');

                                  final List<Widget> buttons = [];
                                  if (showJS) {
                                    buttons.add(
                                      Expanded(
                                        child: fx.FilledButton(
                                          label: 'Open Job Service Form',
                                          backgroundColor: const Color(
                                            0xFF005CE7,
                                          ),
                                          textColor: Colors.white,
                                          withOuterBorder: false,
                                          onPressed:
                                              _createJobServiceFromConcernSlip,
                                        ),
                                      ),
                                    );
                                  }
                                  if (showWO) {
                                    if (buttons.isNotEmpty)
                                      buttons.add(const SizedBox(width: 12));
                                    buttons.add(
                                      Expanded(
                                        child: fx.OutlinedPillButton(
                                          label: 'Open Work Order Form',
                                          borderColor: const Color(0xFF005CE7),
                                          foregroundColor: const Color(
                                            0xFF005CE7,
                                          ),
                                          onPressed:
                                              _createWorkOrderFromConcernSlip,
                                        ),
                                      ),
                                    );
                                  }

                                  return Row(children: buttons);
                                },
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _viewConcernSlipFromFallback,
                                child: const Text('View Concern Slip'),
                              ),
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
          // Tenants should not have access to these staff-only features
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
