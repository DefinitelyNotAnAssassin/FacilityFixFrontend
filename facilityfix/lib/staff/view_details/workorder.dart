import 'package:facilityfix/config/env.dart';
import 'package:flutter/material.dart';
import 'package:facilityfix/models/work_orders.dart'; // <-- unified WorkOrderDetails class only
import 'package:facilityfix/staff/announcement.dart';
import 'package:facilityfix/staff/calendar.dart';
import 'package:facilityfix/staff/home.dart';
import 'package:facilityfix/staff/inventory.dart';
import 'package:facilityfix/staff/workorder.dart'; // WorkOrderPage (list)
import 'package:facilityfix/widgets/app&nav_bar.dart';
import 'package:facilityfix/widgets/buttons.dart' as custom_buttons;

// Your detail widgets should be exported by this file:
import 'package:facilityfix/widgets/view_details.dart';
// Expecting these classes there:
// - ConcernSlipDetails
// - JobServiceDetails
// - MaintenanceDetails
// - WorkOrderPermitDetails

// Import API services
import 'package:facilityfix/services/api_services.dart';

class WorkOrderDetailsPage extends StatefulWidget {
  final String selectedTabLabel;
  final bool startInAssessment; // kept for compatibility
  final WorkOrderDetails? workOrder; // unified data model instance
  final String workOrderId; // ID to fetch if workOrder is null

  const WorkOrderDetailsPage({
    super.key,
    required this.selectedTabLabel,
    this.startInAssessment = false,
    this.workOrder,
    required this.workOrderId,
  });

  @override
  State<WorkOrderDetailsPage> createState() => _WorkOrderDetailsState();
}

class _WorkOrderDetailsState extends State<WorkOrderDetailsPage> {
  final int _selectedIndex = 1;
  late String _detailsLabel;

  // Fetched work order data
  WorkOrderDetails? _fetchedWorkOrder;
  bool _isLoading = false;
  String? _errorMessage;

  final APIService _apiService = APIService();

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

    _detailsLabel = widget.selectedTabLabel.toLowerCase().trim();

    // If no workOrder is passed, fetch it using the workOrderId
    if (widget.workOrder == null) {
      _fetchWorkOrderData();
    } else {
      // Remap generic labels using actual data (unified model)
      if (_detailsLabel == 'repair detail' ||
          _detailsLabel == 'maintenance detail') {
        _detailsLabel = _autoLabelFromWorkOrder(widget.workOrder!);
        debugPrint('[Details] remapped to: $_detailsLabel');
      }
    }

    debugPrint(
      'DETAILS label="${widget.selectedTabLabel}" '
      'stored="$_detailsLabel" hasWorkOrder=${widget.workOrder != null}',
    );
  }

  Future<void> _fetchWorkOrderData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final workOrderId = widget.workOrderId;
      Map<String, dynamic> data;

      // Determine the type of work order based on ID prefix
      if (workOrderId.toUpperCase().startsWith('CS-')) {
        data = await _apiService.getConcernSlipById(workOrderId);
        await _enrichWithUserNames(data);
        final concernSlip = ConcernSlip.fromJson(data);
        _fetchedWorkOrder = _concernSlipToWorkOrderDetails(concernSlip);
      } else if (workOrderId.toUpperCase().startsWith('JS-')) {
        data = await _apiService.getJobServiceById(workOrderId);
        await _enrichWithUserNames(data);
        final jobService = JobService.fromJson(data);
        _fetchedWorkOrder = _jobServiceToWorkOrderDetails(jobService);
      } else if (workOrderId.toUpperCase().startsWith('MT-')) {
        data = await _apiService.getMaintenanceTaskById(workOrderId);
        await _enrichWithUserNames(data);
        final maintenance = Maintenance.fromJson(data);
        _fetchedWorkOrder = _maintenanceToWorkOrderDetails(maintenance);
      } else {
        // ID has no known prefix. Try graceful fallbacks in order: ConcernSlip -> JobService -> Maintenance
        bool found = false;

        try {
          data = await _apiService.getConcernSlipById(workOrderId);
          if (data != null) {
            await _enrichWithUserNames(data);
            final concernSlip = ConcernSlip.fromJson(data);
            _fetchedWorkOrder = _concernSlipToWorkOrderDetails(concernSlip);
            found = true;
          }
        } catch (e) {
          debugPrint('[Details] getConcernSlipById fallback failed: $e');
        }

        if (!found) {
          try {
            data = await _apiService.getJobServiceById(workOrderId);
            if (data != null) {
              await _enrichWithUserNames(data);
              final jobService = JobService.fromJson(data);
              _fetchedWorkOrder = _jobServiceToWorkOrderDetails(jobService);
              found = true;
            }
          } catch (e) {
            debugPrint('[Details] getJobServiceById fallback failed: $e');
          }
        }

        // Fallback to Work Order / Maintenance removed per request.
        // We no longer attempt to resolve other types here; explicit ID prefixes are required.

        if (!found) {
          throw Exception('Unknown work order type: $workOrderId');
        }
      }

      // Remap labels if needed
      if (_detailsLabel == 'repair detail' ||
          _detailsLabel == 'maintenance detail') {
        _detailsLabel = _autoLabelFromWorkOrder(_fetchedWorkOrder!);
        debugPrint('[Details] remapped to: $_detailsLabel');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[Details] Error fetching work order: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load work order details: $e';
      });
    }
  }

  /// Fetch and populate user names when we have user IDs
  Future<void> _enrichWithUserNames(Map<String, dynamic> data) async {
    try {
      // Fetch requested_by name if we have the ID but not the name
      if (data.containsKey('requested_by') &&
          data['requested_by'] != null &&
          !data.containsKey('requested_by_name')) {
        final userId = data['requested_by'].toString();
        print('[DEBUG] Fetching user name for requested_by: $userId');
        final userData = await _apiService.getUserById(userId);
        if (userData != null) {
          final firstName = userData['first_name'] ?? '';
          final lastName = userData['last_name'] ?? '';
          data['requested_by_name'] = '$firstName $lastName'.trim();
          print(
            '[DEBUG] Set requested_by_name to: ${data['requested_by_name']}',
          );
        }
      }

      // Also handle reported_by (for concern slips)
      if (data.containsKey('reported_by') &&
          data['reported_by'] != null &&
          !data.containsKey('reported_by_name')) {
        final userId = data['reported_by'].toString();
        print('[DEBUG] Fetching user name for reported_by: $userId');
        final userData = await _apiService.getUserById(userId);
        if (userData != null) {
          final firstName = userData['first_name'] ?? '';
          final lastName = userData['last_name'] ?? '';
          data['reported_by_name'] = '$firstName $lastName'.trim();
          print('[DEBUG] Set reported_by_name to: ${data['reported_by_name']}');
        }
      }

      // Fetch assigned_to name if we have the ID but not the name
      if (data.containsKey('assigned_to') &&
          data['assigned_to'] != null &&
          !data.containsKey('assigned_to_name')) {
        final userId = data['assigned_to'].toString();
        print('[DEBUG] Fetching user name for assigned_to: $userId');
        final userData = await _apiService.getUserById(userId);
        if (userData != null) {
          final firstName = userData['first_name'] ?? '';
          final lastName = userData['last_name'] ?? '';
          data['assigned_to_name'] = '$firstName $lastName'.trim();
          print('[DEBUG] Set assigned_to_name to: ${data['assigned_to_name']}');
        }
      }

      // Fetch approved_by name if we have the ID but not the name
      if (data.containsKey('approved_by') &&
          data['approved_by'] != null &&
          !data.containsKey('approved_by_name')) {
        final userId = data['approved_by'].toString();
        print('[DEBUG] Fetching user name for approved_by: $userId');
        final userData = await _apiService.getUserById(userId);
        if (userData != null) {
          final firstName = userData['first_name'] ?? '';
          final lastName = userData['last_name'] ?? '';
          data['approved_by_name'] = '$firstName $lastName'.trim();
          print('[DEBUG] Set approved_by_name to: ${data['approved_by_name']}');
        }
      }
    } catch (e) {
      print('[DEBUG] Error enriching user names: $e');
      // Don't fail the entire load if we can't fetch user names
    }
  }

  // Helper methods to convert specific types to WorkOrderDetails
  WorkOrderDetails _concernSlipToWorkOrderDetails(ConcernSlip cs) {
    return WorkOrderDetails(
      id: cs.id,
      createdAt: cs.createdAt,
      updatedAt: cs.updatedAt,
      requestTypeTag: cs.requestTypeTag,
      departmentTag: cs.departmentTag,
      priority: cs.priority,
      statusTag: cs.statusTag,
      resolutionType: cs.resolutionType,
      requestedBy: cs.requestedBy,
      unitId: cs.unitId,
      scheduleAvailability: cs.scheduleAvailability,
      title: cs.title,
      description: cs.description,
      attachments: cs.attachments,
      assignedStaff: cs.assignedStaff,
      staffDepartment: cs.staffDepartment,
      assignedPhotoUrl: cs.assignedPhotoUrl,
      assessedAt: cs.assessedAt,
      assessment: cs.assessment,
      staffAttachments: cs.staffAttachments,
    );
  }

  WorkOrderDetails _jobServiceToWorkOrderDetails(JobService js) {
    return WorkOrderDetails(
      id: js.id,
      createdAt: js.createdAt,
      updatedAt: js.updatedAt,
      requestTypeTag: js.requestTypeTag,
      departmentTag: js.departmentTag,
      priority: js.priority,
      statusTag: js.statusTag,
      resolutionType: js.resolutionType,
      requestedBy: js.requestedBy,
      requestedByName: js.requestedByName,
      requestedByEmail: js.requestedByEmail,
      concernSlipId: js.concernSlipId,
      unitId: js.unitId,
      scheduleAvailability: js.scheduleAvailability,
      title: js.title,
      additionalNotes: js.additionalNotes,
      assignedStaff: js.assignedStaff,
      staffDepartment: js.staffDepartment,
      assignedPhotoUrl: js.assignedPhotoUrl,
      startedAt: js.startedAt,
      completedAt: js.completedAt,
      assessedAt: js.assessedAt,
      assessment: js.assessment,
      attachments: js.attachments,
      staffAttachments: js.staffAttachments,
    );
  }

  WorkOrderDetails _maintenanceToWorkOrderDetails(Maintenance mt) {
    return WorkOrderDetails(
      id: mt.id,
      createdAt: mt.createdAt,
      updatedAt: mt.updatedAt,
      requestTypeTag: mt.requestTypeTag,
      departmentTag: mt.departmentTag,
      priority: mt.priority,
      statusTag: mt.statusTag,
      resolutionType: mt.resolutionType,
      requestedBy: mt.requestedBy,
      title: mt.title,
      description: mt.description,
      location: mt.location,
      checklist: mt.checklist,
      adminNotes: mt.adminNote,
      assignedStaff: mt.assignedStaff,
      staffDepartment: mt.staffDepartment,
      assignedPhotoUrl: mt.assignedPhotoUrl,
      assessedAt: mt.assessedAt,
      assessment: mt.assessment,
      attachments: mt.attachments,
      staffAttachments: mt.staffAttachments,
    );
  }

  WorkOrderDetails _workOrderPermitToWorkOrderDetails(WorkOrderPermit wop) {
    return WorkOrderDetails(
      id: wop.id,
      createdAt: wop.createdAt,
      updatedAt: wop.updatedAt,
      requestTypeTag: wop.requestTypeTag,
      departmentTag: wop.departmentTag,
      priority: wop.priority,
      statusTag: wop.statusTag,
      requestedBy: wop.requestedByName ?? wop.requestedBy,
      concernSlipId: wop.concernSlipId,
      unitId: wop.unitId,
      title: wop.title,
      assignedStaff: wop.assignedStaff,
      staffDepartment: wop.staffDepartment,
      assignedPhotoUrl: wop.assignedPhotoUrl,
      contractorName: wop.contractorName,
      contractorNumber: wop.contractorNumber,
      contractorEmail: wop.contractorEmail,
      workScheduleFrom: wop.workScheduleFrom,
      workScheduleTo: wop.workScheduleTo,
      approvedBy: wop.approvedByName ?? wop.approvedBy,
      approvalDate: wop.approvalDate,
      denialReason: wop.denialReason,
      adminNotes: wop.adminNotes,
      attachments: wop.attachments,
      staffAttachments: wop.staffAttachments,
    );
  }

  void _onTabTapped(int index) {
    final destinations = [
      const HomePage(),
      const WorkOrderPage(), // list page
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

  Future<void> _showMarkAsCompleteDialog() async {
    debugPrint('[Details] _showMarkAsCompleteDialog called');
    final completionNotesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Mark as Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to mark this work order as completed?',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: completionNotesController,
                decoration: const InputDecoration(
                  labelText: 'Completion Notes (Optional)',
                  hintText: 'Add any final notes about the work completed...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                minLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                debugPrint('[Details] Cancel button pressed');
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                debugPrint('[Details] Complete button pressed');
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
              ),
              child: const Text('Complete'),
            ),
          ],
        );
      },
    );

    debugPrint('[Details] Dialog confirmed: $confirmed, mounted: $mounted');

    if (confirmed == true && mounted) {
      debugPrint('[Details] Proceeding with completion...');
      // Get the work order data
      final workOrder = widget.workOrder ?? _fetchedWorkOrder;

      debugPrint('[Details] Work order data: ${workOrder?.id}');

      if (workOrder != null) {
        try {
          // Update the work order status to completed
          final completionNotes = completionNotesController.text.trim();

          debugPrint('[Details] Completing work order: ${workOrder.id}');
          debugPrint('[Details] Work order type: ${workOrder.requestTypeTag}');
          debugPrint('[Details] Completion notes: $completionNotes');

          // Call the appropriate API endpoint based on work order type
          final workOrderId = workOrder.id;
          debugPrint(
            '[Details] Work order ID uppercase: ${workOrderId.toUpperCase()}',
          );

          if (workOrderId.toUpperCase().startsWith('JS-')) {
            debugPrint('[Details] Executing Job Service completion');
            // Complete Job Service
            await _apiService.completeJobService(workOrderId);

            // Add completion notes if provided
            if (completionNotes.isNotEmpty) {
              await _apiService.addJobServiceNotes(
                jobServiceId: workOrderId,
                notes: completionNotes,
              );
            }
          } else if (workOrderId.toUpperCase().startsWith('CS-')) {
            debugPrint('[Details] Executing Concern Slip completion');

            // Concern Slips don't have a direct complete endpoint
            // Update status through updateConcernSlip
            await _apiService.updateConcernSlip(
              concernSlipId: workOrderId,
              // Note: You may need to add a status field to the update method
            );
          } else if (workOrderId.toUpperCase().startsWith('MT-')) {
            // Complete Maintenance Task
            await _apiService.updateMaintenanceTask(workOrderId, {
              'status': 'completed',
              'completion_notes': completionNotes,
            });
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Work order marked as complete'),
                backgroundColor: Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
              ),
            );

            // Navigate back to work order list
            Navigator.of(context).pop();
          }
        } catch (e) {
          debugPrint('[Details] Error completing work order: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to complete work order: ${e.toString()}'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    }

    completionNotesController.dispose();
  }

  // ---------- Builders: map unified model -> concrete details widgets ----------

  Widget _buildConcernSlip(WorkOrderDetails w, {required bool assessed}) {
    return ConcernSlipDetails(
      // Basic
      id: w.id,
      createdAt: w.createdAt,
      updatedAt: w.updatedAt,
      departmentTag: w.departmentTag,
      requestTypeTag: 'Concern Slip',
      priority: w.priority,
      statusTag: w.statusTag,
      resolutionType: w.resolutionType,

      // Requester
      requestedBy: w.requestedBy ?? '—',
      unitId: w.unitId ?? '—',
      scheduleAvailability: w.scheduleAvailability,

      // Request Details
      title: w.title,
      description: (w.description ?? '').isNotEmpty ? w.description! : '—',
      attachments: w.attachments,

      // Staff / Assessment
      assignedStaff: w.assignedStaff,
      staffDepartment: w.staffDepartment,
      staffPhotoUrl: w.assignedPhotoUrl,
      assessedAt: w.assessedAt,
      assessment: w.assessment,
      staffAttachments: w.staffAttachments,
    );
  }

  Widget _buildJobService(WorkOrderDetails w, {required bool assessed}) {
    return JobServiceDetails(
      // Basic
      id: w.id,
      // formattedId: w.formattedId,
      concernSlipId: w.concernSlipId ?? '—',
      createdAt: w.createdAt,
      updatedAt: w.updatedAt,
      requestTypeTag: 'Job Service',
      priority: w.priority,
      statusTag: w.statusTag,
      resolutionType: w.resolutionType,

      // Tenant / Requester
      requestedBy: w.requestedBy ?? '—',
      requestedByName: w.requestedByName,
      unitId: w.unitId ?? '—',
      scheduleAvailability: w.scheduleAvailability,
      additionalNotes: w.additionalNotes,

      // Staff
      assignedStaff: w.assignedStaff,
      staffDepartment: w.staffDepartment,
      staffPhotoUrl: w.assignedPhotoUrl,

      // Documentation
      startedAt: w.startedAt,
      completedAt: w.completedAt,
      completionAt: w.completedAt, // keep mapping if your widget shows both
      assessedAt: w.assessedAt,
      assessment: w.assessment,
      staffAttachments: w.staffAttachments,
      isStaff: true,
    );
  }

  Widget _buildMaintenance(WorkOrderDetails w, {required bool assessed}) {
    return MaintenanceDetails(
      // Basic
      id: w.id,
      createdAt: w.createdAt,
      updatedAt: w.updatedAt,
      departmentTag: w.departmentTag,
      requestTypeTag: 'Maintenance',
      priority: w.priority,
      statusTag: w.statusTag,

      // Tenant / requester
      requestedBy: w.requestedBy ?? '—',
      scheduleDate: w.scheduleAvailability, // String? in your widget API
      // Request details
      title: w.title,
      startedAt: w.startedAt,
      completedAt: w.completedAt,
      location: w.location ?? w.unitId, // prefer location, fallback to unit
      description: w.description,
      checklist:
          (w.checklist ?? '')
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
      attachments: w.attachments,
      adminNote: w.adminNotes ?? w.additionalNotes,

      // Staff
      assignedStaff: w.assignedStaff,
      staffDepartment: w.staffDepartment,
      staffPhotoUrl: w.assignedPhotoUrl,
      assessedAt: w.assessedAt,
      assessment: w.assessment,
      staffAttachments: w.staffAttachments,
    );
  }

  // ---------- Infer route label from unified model ----------
  String _autoLabelFromWorkOrder(WorkOrderDetails w) {
    final id = w.id.toUpperCase();
    final type = (w.requestTypeTag).toLowerCase().trim();
    final s = (w.statusTag).toLowerCase().trim();

    bool isMaint() => type.contains('maintenance') || id.startsWith('MT');
    bool isSlip() => type.contains('concern') || id.startsWith('CS');
    bool isJS() => type.contains('job service') || id.startsWith('JS');

    if (isMaint()) {
      return (s == 'scheduled' || s == 'assigned' || s == 'in progress')
          ? 'maintenance task scheduled'
          : 'maintenance task assessed';
    }
    if (isJS()) {
      return (s == 'assigned' || s == 'on hold' || s == 'scheduled')
          ? 'job service assigned'
          : 'job service assessed';
    }
    if (isSlip()) {
      return (s == 'assigned' || s == 'on hold')
          ? 'concern slip assigned'
          : 'concern slip assessed';
    }
    return 'concern slip assigned';
  }

  // -------------------- main tab content --------------------
  Widget _buildTabContent() {
    // Show loading indicator while fetching data
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show error message if fetch failed
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchWorkOrderData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Use the passed work order or the fetched one
    final w = widget.workOrder ?? _fetchedWorkOrder;

    // If still no data, show error
    if (w == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No work order data available',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final children = <Widget>[];

    switch (_detailsLabel) {
      case 'concern slip assigned':
      case 'concern slip assessed':
        children.add(
          _buildConcernSlip(w, assessed: _detailsLabel.contains('assessed')),
        );
        break;

      case 'job service assigned':
      case 'job service assessed':
        children.add(
          _buildJobService(w, assessed: _detailsLabel.contains('assessed')),
        );
        break;

      case 'maintenance task scheduled':
      case 'maintenance task assessed':
        children.add(
          _buildMaintenance(w, assessed: _detailsLabel.contains('assessed')),
        );
        break;

      // generic -> infer from data
      case 'repair detail':
      case 'maintenance detail':
        final mapped = _autoLabelFromWorkOrder(w);
        if (mapped.contains('maintenance')) {
          children.add(
            _buildMaintenance(w, assessed: mapped.contains('assessed')),
          );
        } else if (mapped.contains('job service')) {
          children.add(
            _buildJobService(w, assessed: mapped.contains('assessed')),
          );
        } else {
          children.add(
            _buildConcernSlip(w, assessed: mapped.contains('assessed')),
          );
        }
        break;

      default:
        final mapped = _autoLabelFromWorkOrder(w);
        if (mapped.contains('maintenance')) {
          children.add(
            _buildMaintenance(w, assessed: mapped.contains('assessed')),
          );
        } else if (mapped.contains('job service')) {
          children.add(
            _buildJobService(w, assessed: mapped.contains('assessed')),
          );
        } else {
          children.add(
            _buildConcernSlip(w, assessed: mapped.contains('assessed')),
          );
        }
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [...children, const SizedBox(height: 8)],
    );
  }

  // Determine whether a work order with the given status can be deleted.
  // Adjust the list of deletable statuses as needed for your business rules.
  bool _isDeletableStatus(String? status) {
    if (status == null) return false;
    final s = status.toLowerCase().trim();
    // Common deletable statuses — modify to match backend semantics
    return s == 'draft' || s == 'cancelled' || s == 'rejected' || s == 'closed';
  }

  void _showDeleteDialog() {
    final workOrder = widget.workOrder ?? _fetchedWorkOrder;
    if (workOrder == null) return;

    final status = (workOrder.statusTag ?? '').toString().toLowerCase();
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
                  await _deleteWorkOrder();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteWorkOrder() async {
    try {
      final apiService = APIService(roleOverride: AppRole.staff);
      await apiService.deleteWorkOrder(widget.workOrderId);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        leading: const BackButton(),
        title: 'Work Order Details',
        showMore: true,
        showDelete:
            ((widget.workOrder ?? _fetchedWorkOrder) != null) &&
            _isDeletableStatus(
              (widget.workOrder ?? _fetchedWorkOrder)!.statusTag,
            ),
        onDeleteTap: _showDeleteDialog,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
          child: _buildTabContent(),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_detailsLabel != 'assessed repair detail' &&
              _detailsLabel != 'assessed maintenance detail')
            SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: custom_buttons.FilledButton(
                  label: 'Mark as Complete',
                  withOuterBorder: false,
                  backgroundColor: const Color(0xFF10B981),
                  icon: Icons.check_circle_outline,
                  onPressed: () async {
                    debugPrint('[Details] Mark as Complete button pressed');
                    await _showMarkAsCompleteDialog();
                    debugPrint('[Details] Mark as Complete dialog finished');
                  },
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
