// Tenant-only Work Order / Permit detail view (stable, minimal)
import 'package:facilityfix/tenant/repair_management.dart';
import 'package:flutter/material.dart';
import 'package:facilityfix/models/work_orders.dart';
import 'package:facilityfix/tenant/home.dart';
import 'package:facilityfix/tenant/announcement.dart';
import 'package:facilityfix/tenant/profile.dart';
import 'package:facilityfix/tenant/view_details/concern_slip_details.dart';
import 'package:facilityfix/tenant/view_details/job_service_details.dart';
import 'package:facilityfix/widgets/app&nav_bar.dart';
import 'package:facilityfix/widgets/view_details.dart';
import 'package:facilityfix/services/api_services.dart';

/// Tenant-only details page.
/// - Uses only the mobile `APIService`.
/// - Supports Concern Slip (CS-), Job Service (JS-), and Work Order / Permit (WO-/WP-).
/// - No admin API calls and no MT-/maintenance-specific behavior.
class WorkOrderDetailsPage extends StatefulWidget {
  final String selectedTabLabel;
  final WorkOrderDetails? workOrder;
  final String workOrderId;

  const WorkOrderDetailsPage({
    super.key,
    required this.selectedTabLabel,
    this.workOrder,
    required this.workOrderId,
  });

  @override
  State<WorkOrderDetailsPage> createState() => _WorkOrderDetailsState();
}

class _WorkOrderDetailsState extends State<WorkOrderDetailsPage> {
  final int _selectedIndex = 1;
  WorkOrderDetails? _fetchedWorkOrder;
  bool _isLoading = false;
  String? _errorMessage;
  bool _navigatedToConcernSlip = false;
  bool _navigatedToJobService = false;
  bool _isMarkingComplete = false;

  final APIService _apiService = APIService();

  final List<NavItem> _navItems = const [
    NavItem(icon: Icons.home),
    NavItem(icon: Icons.work),
    NavItem(icon: Icons.announcement_rounded),
    NavItem(icon: Icons.person),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.workOrder == null) _fetchWorkOrderData();
  }

  void _showHistorySheet() {
    // TODO: Implement history sheet
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('History view coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showEditDialog() {
    final w = widget.workOrder ?? _fetchedWorkOrder;
    if (w == null) return;

    // Only allow editing if status is pending
    final status = w.statusTag.toLowerCase();
    final isPending = status.startsWith('pending');
    if (!isPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only pending requests can be edited'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Navigate to edit page based on request type
    final id = w.id.toUpperCase();
    final idLower = w.id.toLowerCase();

    String requestType;
    if (id.startsWith('CS-') || idLower.startsWith('cs_')) {
      requestType = 'Concern Slip';
    } else if (id.startsWith('JS-') || idLower.startsWith('js_')) {
      requestType = 'Job Service';
    } else if (id.startsWith('WP-') || idLower.startsWith('wp_')) {
      requestType = 'Work Order';
    } else {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => EditWorkOrderPage(
              workOrderId: w.id,
              requestType: requestType,
              workOrderData: w,
            ),
      ),
    ).then((updated) {
      if (updated == true) {
        _fetchWorkOrderData();
      }
    });
  }

  void _showDeleteDialog() {
    final w = widget.workOrder ?? _fetchedWorkOrder;
    if (w == null) return;

    final status = w.statusTag.toLowerCase();
    final deletable =
        status.startsWith('pending') ||
        status.contains('complete') ||
        status == 'done';
    if (!deletable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only pending (including pending CS/JS/WOP) or completed requests can be deleted',
          ),
          backgroundColor: Colors.orange,
        ),
      );
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
    final w = widget.workOrder ?? _fetchedWorkOrder;
    if (w == null) return;

    try {
      final id = w.id.toUpperCase();
      final idLower = w.id.toLowerCase();

      if (id.startsWith('CS-') || idLower.startsWith('cs_')) {
        await _apiService.deleteConcernSlip(w.id);
      } else if (id.startsWith('JS-') || idLower.startsWith('js_')) {
        await _apiService.deleteJobService(w.id);
      } else if (id.startsWith('WP-') || idLower.startsWith('wp_')) {
        await _apiService.deleteWorkOrder(w.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WorkOrderPage()),
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

  Future<void> _fetchWorkOrderData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final id = widget.workOrderId;
      final idUpper = id.toUpperCase();

      if (idUpper.startsWith('CS-') || id.toLowerCase().startsWith('cs_')) {
        final data = await _apiService.getConcernSlipById(id);
        final cs = ConcernSlip.fromJson(data);
        _fetchedWorkOrder = _concernSlipToWorkOrderDetails(cs);
      } else if (idUpper.startsWith('JS-') ||
          id.toLowerCase().startsWith('js_')) {
        final data = await _apiService.getJobServiceById(id);
        final js = JobService.fromJson(data);
        _fetchedWorkOrder = _jobServiceToWorkOrderDetails(js);
      } else if (idUpper.startsWith('WP-') ||
          id.toLowerCase().startsWith('wp_')) {
        final data = await _apiService.getWorkOrderById(id);
        final wo = WorkOrderPermit.fromJson(data);
        _fetchedWorkOrder = _workOrderPermitToWorkOrderDetails(wo);
      } else {
        throw Exception(
          'Unknown work order type: $id. Expected CS-, JS-, WP- prefix or cs_, js_, wp_ format.',
        );
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load details: $e';
      });
    }
  }

  // Small converters to the unified WorkOrderDetails used by view widgets
  WorkOrderDetails _concernSlipToWorkOrderDetails(ConcernSlip cs) =>
      WorkOrderDetails(
        id: cs.id,
        createdAt: cs.createdAt,
        updatedAt: cs.updatedAt,
        requestTypeTag: cs.requestTypeTag,
        departmentTag: cs.departmentTag,
        priority: cs.priority,
        statusTag: cs.statusTag,
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
        additionalNotes: cs.description,
        assessment: cs.assessment,
        staffAttachments: cs.staffAttachments,
      );

  WorkOrderDetails _jobServiceToWorkOrderDetails(JobService js) =>
      WorkOrderDetails(
        id: js.id,
        createdAt: js.createdAt,
        updatedAt: js.updatedAt,
        requestTypeTag: js.requestTypeTag,
        departmentTag: js.departmentTag,
        priority: js.priority,
        statusTag: js.statusTag,
        requestedBy: js.requestedBy,
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

  WorkOrderDetails _workOrderPermitToWorkOrderDetails(WorkOrderPermit wop) =>
      WorkOrderDetails(
        id: wop.id,
        createdAt: wop.createdAt,
        updatedAt: wop.updatedAt,
        requestTypeTag: wop.requestTypeTag,
        departmentTag: wop.departmentTag,
        priority: wop.priority,
        statusTag: wop.statusTag,
        resolutionType: wop.resolutionType,
        title: wop.title,
        unitId: wop.unitId,
        assignedStaff: wop.assignedStaff,
        staffDepartment: wop.staffDepartment,
        assignedPhotoUrl: wop.assignedPhotoUrl,
        concernSlipId: wop.concernSlipId,
        requestedBy: wop.requestedByName ?? wop.requestedBy,
        contractorName: wop.contractorName,
        contractorNumber: wop.contractorNumber,
        contractorEmail: wop.contractorEmail,
        additionalNotes: wop.additionalNotes,
        workScheduleFrom: wop.workScheduleFrom,
        workScheduleTo: wop.workScheduleTo,
        approvedBy: wop.approvedByName ?? wop.approvedBy,
        approvalDate: wop.approvalDate,
        denialReason: wop.denialReason,
        attachments: wop.attachments,
        staffAttachments: wop.staffAttachments,
      );

  Widget _buildTabContent() {
    if (_isLoading)
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    if (_errorMessage != null)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );

    final w = widget.workOrder ?? _fetchedWorkOrder;
    if (w == null)
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('No data available'),
        ),
      );

    final id = w.id.toUpperCase();
    final idLower = w.id.toLowerCase();

    if (id.startsWith('CS-') || idLower.startsWith('cs_')) {
      // Open the full Tenant Concern Slip page instead of embedding the
      // ConcernSlipDetails widget here. We schedule navigation after build
      // to avoid calling Navigator during the build phase.
      if (!_navigatedToConcernSlip) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _navigatedToConcernSlip = true);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TenantConcernSlipDetailPage(concernSlipId: w.id),
            ),
          ).then((_) {
            if (!mounted) return;
            setState(() => _navigatedToConcernSlip = false);
            // Refresh details when returning from the concern slip page
            _fetchWorkOrderData();
          });
        });
      }

      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('Opening Concern Slip...'),
        ),
      );
    }

    if (id.startsWith('JS-') || idLower.startsWith('js_')) {
      // Open the full Tenant Job Service page instead of embedding the
      // staff JobServiceDetails widget here. Schedule navigation after build
      // to avoid calling Navigator during the build phase.
      if (!_navigatedToJobService) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _navigatedToJobService = true);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TenantJobServiceDetailPage(jobServiceId: w.id),
            ),
          ).then((_) {
            if (!mounted) return;
            setState(() => _navigatedToJobService = false);
            // Refresh details when returning from the job service page
            _fetchWorkOrderData();
          });
        });
      }

      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('Opening Job Service...'),
        ),
      );
    }

    // Default: work order permit (handles WP- or wp_ format only)
    return WorkOrderPermitDetails(
      id: w.id,
      concernSlipId: w.concernSlipId ?? '—',
      createdAt: w.createdAt,
      updatedAt: w.updatedAt,
      requestTypeTag: 'Work Order',
      priority: w.priority,
      statusTag: w.statusTag,
      resolutionType: w.resolutionType,
      requestedBy: w.requestedBy ?? '—',
      unitId: w.unitId,
      title: w.title, // Add title field
      contractorName: w.contractorName ?? '—',
      contractorNumber: w.contractorNumber ?? '—',
      contractorEmail: w.contractorEmail,
      workScheduleFrom: w.workScheduleFrom ?? w.createdAt,
      workScheduleTo: w.workScheduleTo ?? w.createdAt,
      approvedBy: w.approvedBy,
      approvalDate: w.approvalDate,
      denialReason: w.denialReason,
      adminNotes: w.adminNotes,
      onViewConcernSlip:
          (w.concernSlipId != null && w.concernSlipId != '—')
              ? () => _navigateToConcernSlip(w.concernSlipId!)
              : null,
    );
  }

  void _navigateToConcernSlip(String concernSlipId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                TenantConcernSlipDetailPage(concernSlipId: concernSlipId),
      ),
    );
  }

  void _onTabTapped(int index) {
    final destinations = [
      const HomePage(),
      const WorkOrderPage(),
      const AnnouncementPage(),
      const ProfilePage(),
    ];
    if (index != _selectedIndex)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destinations[index]),
      );
  }

  Future<void> _markAsCompleted() async {
    final w = widget.workOrder ?? _fetchedWorkOrder;
    if (w == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Mark as Completed'),
            content: const Text(
              'Are you sure you want to mark this work order as completed? This action will notify the admin and update the status.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.green),
                child: const Text('Mark Complete'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() => _isMarkingComplete = true);

    try {
      final id = w.id.toUpperCase();
      final idLower = w.id.toLowerCase();

      if (id.startsWith('CS-') || idLower.startsWith('cs_')) {
        await _apiService.markConcernSlipCompleted(
          concernSlipId: w.id,
          completionNotes: 'Marked as completed by tenant on ${DateTime.now()}',
        );
      } else if (id.startsWith('JS-') || idLower.startsWith('js_')) {
        await _apiService.markJobServiceCompleted(
          jobServiceId: w.id,
          completionNotes: 'Marked as completed by tenant on ${DateTime.now()}',
        );
      } else if (id.startsWith('WP-') || idLower.startsWith('wp_')) {
        await _apiService.markWorkOrderCompleted(
          workOrderId: w.id,
          completionNotes: 'Marked as completed by tenant on ${DateTime.now()}',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Work marked as completed successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the details
        _fetchWorkOrderData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark as completed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isMarkingComplete = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.workOrder ?? _fetchedWorkOrder;
    final status = w?.statusTag.toLowerCase() ?? '';
    final isPending = status == 'pending';
    // deletable when pending or completed/done
    final isDeletable =
        status == 'pending' ||
        status == 'complete' ||
        status == 'completed' ||
        status == 'done';
    final isCompletionEligible =
        status == 'assigned' ||
        status == 'to inspect' ||
        status == 'inspected' ||
        status == 'in progress' ||
        status == 'approved';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: 'View Details',
        leading: const Padding(
          padding: EdgeInsets.only(right: 8),
          child: BackButton(),
        ),
        showMore: true,
        showHistory: true,
        showEdit: isPending,
        showDelete: isDeletable,
        onHistoryTap: _showHistorySheet,
        onEditTap: _showEditDialog,
        onDeleteTap: _showDeleteDialog,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
          child: Column(
            children: [
              _buildTabContent(),
              if (isCompletionEligible)
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isMarkingComplete ? null : _markAsCompleted,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon:
                          _isMarkingComplete
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Icon(Icons.check_circle),
                      label: Text(
                        _isMarkingComplete
                            ? 'Marking Complete...'
                            : 'Mark as Completed',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavBar(
        items: _navItems,
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

// Edit Work Order Page
class EditWorkOrderPage extends StatefulWidget {
  final String workOrderId;
  final String requestType;
  final WorkOrderDetails workOrderData;

  const EditWorkOrderPage({
    super.key,
    required this.workOrderId,
    required this.requestType,
    required this.workOrderData,
  });

  @override
  State<EditWorkOrderPage> createState() => _EditWorkOrderPageState();
}

class _EditWorkOrderPageState extends State<EditWorkOrderPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _availabilityController;
  late TextEditingController _permitIdController;
  late TextEditingController _contractorNameController;
  late TextEditingController _contractorNumberController;
  late TextEditingController _contractorEmailController;
  late TextEditingController _workScheduleFromController;
  late TextEditingController _workScheduleToController;
  late TextEditingController _entryEquipmentsController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers based on request type
    _availabilityController = TextEditingController(
      text: widget.workOrderData.scheduleAvailability ?? '',
    );

    // Work Order specific fields
    _permitIdController = TextEditingController(text: widget.workOrderData.id);
    _contractorNameController = TextEditingController(
      text: widget.workOrderData.contractorName ?? '',
    );
    _contractorNumberController = TextEditingController(
      text: widget.workOrderData.contractorNumber ?? '',
    );
    _contractorEmailController = TextEditingController(
      text: widget.workOrderData.contractorEmail ?? '',
    );
    _workScheduleFromController = TextEditingController(
      text:
          widget.workOrderData.workScheduleFrom != null
              ? _formatDateTime(widget.workOrderData.workScheduleFrom!)
              : '',
    );
    _workScheduleToController = TextEditingController(
      text:
          widget.workOrderData.workScheduleTo != null
              ? _formatDateTime(widget.workOrderData.workScheduleTo!)
              : '',
    );
    _entryEquipmentsController = TextEditingController(
      text: widget.workOrderData.additionalNotes ?? '',
    );
  }

  @override
  void dispose() {
    _availabilityController.dispose();
    _permitIdController.dispose();
    _contractorNameController.dispose();
    _contractorNumberController.dispose();
    _contractorEmailController.dispose();
    _workScheduleFromController.dispose();
    _workScheduleToController.dispose();
    _entryEquipmentsController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickAvailabilityRange() async {
    final now = DateTime.now();

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;

    final TimeOfDay? startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
      helpText: 'Select start time',
    );
    if (startTime == null) return;

    final TimeOfDay? endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (startTime.hour + 2) % 24,
        minute: startTime.minute,
      ),
      helpText: 'Select end time',
    );
    if (endTime == null) return;

    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;

    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    final dateStr = '${pickedDate.month}/${pickedDate.day}/${pickedDate.year}';
    final startTimeStr = _formatTimeOfDay(startTime);
    final endTimeStr = _formatTimeOfDay(endTime);

    setState(() {
      _availabilityController.text = '$dateStr $startTimeStr - $endTimeStr';
    });
  }

  Future<void> _pickDateTime(TextEditingController controller) async {
    final now = DateTime.now();

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (pickedTime == null) return;

    final dt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      controller.text = _formatDateTime(dt);
    });
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final displayHour = hour == 0 ? 12 : hour;
    return '$displayHour:$minute $period';
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final apiService = APIService();

      if (widget.requestType == 'Concern Slip') {
        await apiService.updateConcernSlip(
          concernSlipId: widget.workOrderId,
          scheduleAvailability: _availabilityController.text.trim(),
        );
      } else if (widget.requestType == 'Job Service') {
        await apiService.updateJobService(
          jobServiceId: widget.workOrderId,
          scheduleAvailability: _availabilityController.text.trim(),
        );
      } else if (widget.requestType == 'Work Order') {
        // Work Order update
        await apiService.updateWorkOrder(
          workOrderId: widget.workOrderId,
          contractorName: _contractorNameController.text.trim(),
          contractorNumber: _contractorNumberController.text.trim(),
          contractorEmail: _contractorEmailController.text.trim(),
          workScheduleFrom: _workScheduleFromController.text.trim(),
          workScheduleTo: _workScheduleToController.text.trim(),
          // additionalNotes: _entryEquipmentsController.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Edit ${widget.requestType}'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show availability field for Concern Slip and Job Service
                if (widget.requestType == 'Concern Slip' ||
                    widget.requestType == 'Job Service') ...[
                  const Text(
                    'Time Availability',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF344054),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _availabilityController,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: 'Select availability time range',
                      suffixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onTap: _pickAvailabilityRange,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Availability is required';
                      }
                      return null;
                    },
                  ),
                ],

                // Show permit details for Work Order
                if (widget.requestType == 'Work Order') ...[
                  const Text(
                    'Permit Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Contractor Name',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF344054),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _contractorNameController,
                    decoration: InputDecoration(
                      hintText: 'Enter contractor name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Contractor name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Contractor Number',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF344054),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _contractorNumberController,
                    decoration: InputDecoration(
                      hintText: 'Enter contractor number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Contractor number is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Contractor Company',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF344054),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _contractorEmailController,
                    decoration: InputDecoration(
                      hintText: 'Enter contractor company',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Contractor company is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Work Schedule',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Schedule From',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF344054),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _workScheduleFromController,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: 'Select start date and time',
                      suffixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onTap: () => _pickDateTime(_workScheduleFromController),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Start date is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Schedule To',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF344054),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _workScheduleToController,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: 'Select end date and time',
                      suffixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onTap: () => _pickDateTime(_workScheduleToController),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'End date is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Entry Equipments',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF344054),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _entryEquipmentsController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter equipments (comma-separated)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
                        _isSaving
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
