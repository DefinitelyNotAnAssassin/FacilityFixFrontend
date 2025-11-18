import 'package:facilityfix/services/api_services.dart';
import 'package:facilityfix/services/chat_helper.dart';
import 'package:facilityfix/tenant/announcement.dart';
import 'package:facilityfix/tenant/home.dart';
import 'package:facilityfix/tenant/profile.dart';
import 'package:facilityfix/tenant/request_forms.dart';
import 'package:facilityfix/tenant/repair_management.dart';
import 'package:facilityfix/widgets/view_details.dart';
import 'package:facilityfix/utils/ui_format.dart';
import 'package:flutter/material.dart';
import 'package:facilityfix/widgets/app&nav_bar.dart';
import 'package:facilityfix/widgets/buttons.dart' as fx;
import 'package:intl/intl.dart' show DateFormat;

class TenantConcernSlipDetailPage extends StatefulWidget {
  final String concernSlipId;

  const TenantConcernSlipDetailPage({super.key, required this.concernSlipId});

  @override
  State<TenantConcernSlipDetailPage> createState() =>
      _TenantConcernSlipDetailPageState();
}

class _TenantConcernSlipDetailPageState
    extends State<TenantConcernSlipDetailPage> {
  int _selectedIndex = 1;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Map<String, dynamic>? _concernSlipData;

  final List<NavItem> _navItems = const [
    NavItem(icon: Icons.home),
    NavItem(icon: Icons.work),
    NavItem(icon: Icons.announcement_rounded),
    NavItem(icon: Icons.person),
  ];

  @override
  void initState() {
    super.initState();
    _loadConcernSlipData();
  }

  Future<void> _loadConcernSlipData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final apiService = APIService();
      Map<String, dynamic> data;

      // Try to determine the request type and call appropriate endpoint
      try {
        // First try as concern slip
        data = await apiService.getConcernSlipById(widget.concernSlipId);
        print('[DEBUG] Successfully fetched as concern slip');
      } catch (e) {
        print(
          '[DEBUG] Failed to fetch as concern slip, trying as job service: $e',
        );
        try {
          // Then try as job service
          data = await apiService.getJobServiceById(widget.concernSlipId);
          // Ensure request_type is set for job services
          if (!data.containsKey('request_type')) {
            data['request_type'] = 'Job Service';
          }
          print('[DEBUG] Successfully fetched as job service');
        } catch (e2) {
          print(
            '[DEBUG] Failed to fetch as job service, trying as work order: $e2',
          );
          try {
            // Finally try as work order
            data = await apiService.getWorkOrderById(widget.concernSlipId);
            // Ensure request_type is set for work orders
            if (!data.containsKey('request_type')) {
              data['request_type'] = 'Work Order Permit';
            }
            print('[DEBUG] Successfully fetched as work order');
          } catch (e3) {
            // If all fail, throw the original concern slip error
            print('[DEBUG] Failed to fetch as work order too: $e3');
            throw e;
          }
        }
      }

      // Enrich data with user names if we have user IDs
      await _enrichWithUserNames(data, apiService);

      if (mounted) {
        setState(() {
          _concernSlipData = data;
          _isLoading = false;
        });
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

  /// Fetch and populate user names when we have user IDs
  Future<void> _enrichWithUserNames(
    Map<String, dynamic> data,
    APIService apiService,
  ) async {
    try {
      // Fetch reported_by name if we have the ID but not the name
      if (data.containsKey('reported_by') &&
          data['reported_by'] != null &&
          !data.containsKey('reported_by_name')) {
        final userId = data['reported_by'].toString();
        print('[DEBUG] Fetching user name for reported_by: $userId');
        final userData = await apiService.getUserById(userId);
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
      const ProfilePage(),
    ];
    if (index != _selectedIndex) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destinations[index]),
      );
    }
  }

  void _showHistorySheet() {
    if (_concernSlipData == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) =>
              ConcernSlipHistorySheet(concernSlipData: _concernSlipData!),
    );
  }

  void _showEditDialog() {
    if (_concernSlipData == null) return;

    // Only allow editing if status is pending
    final status = (_concernSlipData!['status'] ?? '').toString().toLowerCase();
    // treat any status that starts with 'pending' as editable (covers 'pending', 'pending cs', 'pending js', 'pending wop')
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

    // Navigate to RequestForm for editing
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => RequestForm(
              requestType: 'Concern Slip',
              concernSlipId: widget.concernSlipId,
              initialData: _concernSlipData,
              requestId: widget.concernSlipId,
              isEditing: true,
            ),
      ),
    ).then((updated) {
      if (updated == true) {
        _loadConcernSlipData();
      }
    });
  }

  void _showDeleteDialog() {
    if (_concernSlipData == null) return;

    // Allow deleting if status is pending or complete/done
    final status = (_concernSlipData!['status'] ?? '').toString().toLowerCase();
    // allow delete for any 'pending*' or completed statuses
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
                  await _deleteConcernSlip();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteConcernSlip() async {
    try {
      final apiService = APIService();
      await apiService.deleteConcernSlip(widget.concernSlipId);

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

  @override
  Widget build(BuildContext context) {
    final status = _normalizeStatus(
      (_concernSlipData?['status'] ?? '').toString(),
    );
    final isPending = status.startsWith('pending');
    final isComplete = status.contains('complete') || status == 'done';
    final isAssigned =
        _concernSlipData?['assigned_to'] != null ||
        _concernSlipData?['assigned_to_name'] != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: 'View Details',
        leading: const Row(
          children: [
            Padding(padding: EdgeInsets.only(right: 8), child: BackButton()),
          ],
        ),
        showMore: true,
        showHistory: true,
        showEdit: isPending,
        showDelete: isPending || isComplete,
        onHistoryTap: _showHistorySheet,
        onEditTap: _showEditDialog,
        onDeleteTap: _showDeleteDialog,
      ),
      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Failed to load request details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF667085)),
                        ),
                        const SizedBox(height: 24),
                        fx.FilledButton(
                          label: 'Retry',
                          onPressed: _loadConcernSlipData,
                        ),
                      ],
                    ),
                  ),
                )
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _buildConcernSlipDetails(),
                ),
      ),
      bottomNavigationBar: NavBar(
        items: _navItems,
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
      ),
    );
  }

  Widget _buildConcernSlipDetails() {
    if (_concernSlipData == null) return const SizedBox();

    final data = _concernSlipData!;
    final resolutionType = data['resolution_type']?.toString().toLowerCase();
    final rawStatus = data['status']?.toString();

    // Debug logging
    print('[DEBUG] Concern Slip Data:');
    print('  Status: ${data['status']}');
    print('  Resolution Type: ${data['resolution_type']}');
    print('  Resolution Type (lowercase): $resolutionType');
    print('  Resolution Set By: ${data['resolution_set_by']}');
    print('  Resolution Set At: ${data['resolution_set_at']}');
    print(
      '  Schedule Availability: ${data['schedule_availability']} (Type: ${data['schedule_availability']?.runtimeType})',
    );
    print(
      '  Should Show Form: ${resolutionType != null && resolutionType.isNotEmpty && resolutionType != 'rejected'}',
    );

    // Convert schedule availability from multiple possible fields to a string
    String? scheduleAvailabilityStr;
    final candidates = [
      data['schedule_availability'],
      data['rawData']?['schedule_availability'],
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
        // fallback: try to stringify
        try {
          final s = c.toString();
          if (s.trim().isNotEmpty) {
            scheduleAvailabilityStr = s.trim();
            break;
          }
        } catch (_) {}
      }
    }
    print(
      '[DEBUG]   Converted Schedule Availability: $scheduleAvailabilityStr',
    );

    // Convert the extracted schedule string into a DateTimeRange now so the
    // details widget receives a typed value and doesn't need to re-parse.
    final DateTimeRange? scheduleRange = UiDateUtils.parseRange(
      scheduleAvailabilityStr,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConcernSlipDetails(
          id: data['formatted_id'] ?? data['id'] ?? '',
          title: data['title'] ?? 'Untitled Request',
          createdAt:
              DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
          updatedAt:
              data['updated_at'] != null
                  ? DateTime.tryParse(data['updated_at'])
                  : null,
          requestTypeTag: 'Concern Slip',
          // Normalize certain backend status variants (e.g. 'sent to client')
          // to show the 'inspected' state in the tenant UI.
          statusTag: _normalizeStatus(data['status']?.toString() ?? ''),
          priority: data['priority'] ?? '',
          departmentTag: data['category'],
          requestedBy: data['reported_by_name'] ?? data['reported_by'] ?? '',
          unitId: data['unit_id'] ?? '',
          // Pass the parsed DateTimeRange (or null) so the details widget
          // receives a typed range and displays it directly.
          scheduleAvailability: scheduleRange,
          description: data['description'] ?? '',
          attachments: (data['attachments'] as List?)?.cast<String>(),
          assignedStaff: data['assigned_to_name'] ?? data['assigned_to'],
          staffDepartment: data['staff_department'],
          assessedAt:
              data['assessed_at'] != null
                  ? DateTime.tryParse(data['assessed_at'])
                  : null,
          assessment: data['staff_assessment'],
          staffRecommendation: data['staff_recommendation'],
          staffAttachments:
              (data['assessment_attachments'] as List?)?.cast<String>(),
        ),
        // Show embedded form if resolution type is set and status allows it
        if (resolutionType != null &&
            resolutionType.isNotEmpty &&
            resolutionType != 'rejected' &&
            _shouldShowEmbeddedForm(rawStatus, resolutionType))
          _buildEmbeddedForm(resolutionType, data),
      ],
    );
  }

  bool _shouldShowEmbeddedForm(String? status, String resolutionType) {
    // Show embedded form if:
    // 1. Status is 'sent', 'sent to client', 'evaluated', or 'approved' (admin has processed it)
    // 2. Resolution type is set to job_service or work_order
    // 3. The concern slip hasn't been completed yet
    final normalizedStatus = (status ?? '').toLowerCase().replaceAll('_', ' ');
    return [
          'sent',
          'sent to client',
          'sent to tenant',
          'evaluated',
          'approved',
        ].contains(normalizedStatus) &&
        ['job_service', 'work_order', 'work_permit'].contains(resolutionType);
  }

  // Normalize various backend status variants to canonical values used
  // throughout the UI. In particular, map 'sent to client' -> 'inspected'
  // so tenant-facing screens consistently show the inspected state.
  String _normalizeStatus(String? raw) {
    if (raw == null) return '';
    final s = raw.trim().toLowerCase();

    // Map backend statuses to tenant-facing canonical statuses
    switch (s) {
      case 'sent to client':
      case 'sent_to_client':
      case 'sent to tenant':
      case 'sent':
      case 'evaluated': // Admin has evaluated, tenant needs to act
      case 'approved': // Admin has approved, tenant needs to act
        return 'inspected';
      case 'completed':
      case 'done':
        return 'inspected';
      case 'assigned':
        return 'to inspect';
      default:
        return s.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    }
  }

  /// Build an embedded form widget for job service / work order resolution types.
  /// This returns a RequestFormWrapper so the user can open/submit the corresponding form inline.
  Widget _buildEmbeddedForm(String resolutionType, Map<String, dynamic> data) {
    // Normalize resolutionType to a human-friendly request type label
    final String formType;

    if (resolutionType == 'job_service') {
      formType = 'Job Service';
    } else if (resolutionType == 'work_order' ||
        resolutionType == 'work_permit') {
      formType = 'Work Order';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.assignment,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proceed with $formType',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete the form below to proceed with your request',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => EmbeddedRequestFormPage(
                        requestType: formType,
                        concernSlipId: data['id'] ?? '',
                        concernSlipData: data,
                      ),
                ),
              ).then((submitted) {
                if (submitted == true) {
                  // Refresh the concern slip data after form submission
                  _loadConcernSlipData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$formType submitted successfully'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              });
            },
            icon: const Icon(Icons.edit_document),
            label: Text('Fill $formType Form'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConcernSlipHistorySheet extends StatelessWidget {
  final Map<String, dynamic> concernSlipData;

  const ConcernSlipHistorySheet({super.key, required this.concernSlipData});

  @override
  Widget build(BuildContext context) {
    final events = _buildTimelineEvents();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.history, color: Color(0xFF667085)),
                SizedBox(width: 12),
                Text(
                  'Request History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                final isLast = index == events.length - 1;
                return _TimelineItem(
                  title: event['title']!,
                  subtitle: event['subtitle'],
                  timestamp: event['timestamp']!,
                  isLast: isLast,
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Map<String, String>> _buildTimelineEvents() {
    final events = <Map<String, String>>[];

    // Created event
    if (concernSlipData['created_at'] != null) {
      events.add({
        'title': 'Request Created',
        'subtitle': 'Initial submission by tenant',
        'timestamp': _formatTimestamp(concernSlipData['created_at']),
      });
    }

    // Updated event
    if (concernSlipData['updated_at'] != null &&
        concernSlipData['updated_at'] != concernSlipData['created_at']) {
      events.add({
        'title': 'Request Updated',
        'subtitle': 'Details modified',
        'timestamp': _formatTimestamp(concernSlipData['updated_at']),
      });
    }

    // Evaluated event
    if (concernSlipData['evaluated_at'] != null) {
      final status = concernSlipData['status'] ?? '';
      events.add({
        'title': 'Request Evaluated',
        'subtitle': 'Status: ${_capitalizeFirst(status)}',
        'timestamp': _formatTimestamp(concernSlipData['evaluated_at']),
      });
    }

    // Assigned event
    if (concernSlipData['assigned_at'] != null) {
      final staffName = concernSlipData['assigned_to_name'] ?? 'Staff';
      events.add({
        'title': 'Staff Assigned',
        'subtitle': 'Assigned to $staffName',
        'timestamp': _formatTimestamp(concernSlipData['assigned_at']),
      });
    }

    // Assessed event
    if (concernSlipData['assessed_at'] != null) {
      events.add({
        'title': 'Assessment Completed',
        'subtitle': 'Staff submitted assessment',
        'timestamp': _formatTimestamp(concernSlipData['assessed_at']),
      });
    }

    // Returned to tenant event
    if (concernSlipData['returned_to_tenant_at'] != null) {
      events.add({
        'title': 'Returned to Tenant',
        'subtitle': 'Ready for next steps',
        'timestamp': _formatTimestamp(concernSlipData['returned_to_tenant_at']),
      });
    }

    return events.reversed.toList();
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.parse(timestamp);
      return DateFormat('MMM d, yyyy h:mm a').format(date);
    } catch (e) {
      return timestamp;
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}

// Embedded Request Form Page
class EmbeddedRequestFormPage extends StatelessWidget {
  final String requestType; // "Job Service" or "Work Order"
  final String concernSlipId;
  final Map<String, dynamic> concernSlipData;

  const EmbeddedRequestFormPage({
    super.key,
    required this.requestType,
    required this.concernSlipId,
    required this.concernSlipData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Submit $requestType'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card showing this is related to a concern slip
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF3B82F6),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Related to Concern Slip',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            concernSlipData['formatted_id'] ?? concernSlipId,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Import the actual form from RequestForm
              Text(
                'Complete $requestType Form',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Fill in the details below to proceed with your request',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              // Show the appropriate form based on request type
              RequestFormWrapper(
                requestType: requestType,
                concernSlipId: concernSlipId,
                concernSlipData: concernSlipData,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Wrapper to display the request form inline
class RequestFormWrapper extends StatelessWidget {
  final String requestType;
  final String concernSlipId;
  final Map<String, dynamic> concernSlipData;

  const RequestFormWrapper({
    super.key,
    required this.requestType,
    required this.concernSlipId,
    required this.concernSlipData,
  });

  @override
  Widget build(BuildContext context) {
    // Navigate to the actual RequestForm page
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => RequestForm(
                  requestType: requestType,
                  concernSlipId: concernSlipId,
                ),
          ),
        ).then((value) {
          // Return true to indicate submission success
          if (value == true) {
            Navigator.pop(context, true);
          }
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(double.infinity, 48),
      ),
      child: Text(
        'Open $requestType Form',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String timestamp;
  final bool isLast;

  const _TimelineItem({
    required this.title,
    this.subtitle,
    required this.timestamp,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFF2563EB),
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 60, color: const Color(0xFFE5E7EB)),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF101828),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF667085),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  timestamp,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
