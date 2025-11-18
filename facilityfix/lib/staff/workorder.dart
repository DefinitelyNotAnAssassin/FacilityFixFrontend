import 'dart:async';
import 'package:facilityfix/services/api_services.dart';
import 'package:facilityfix/services/auth_storage.dart';
import 'package:facilityfix/config/env.dart';
import 'package:facilityfix/staff/view_details/concern_slip.dart';
import 'package:facilityfix/staff/view_details/job_service_detail.dart';
import 'package:facilityfix/staff/maintenance.dart';
import 'package:facilityfix/staff/announcement.dart';
import 'package:facilityfix/staff/calendar.dart';
import 'package:facilityfix/staff/inventory.dart';
import 'package:facilityfix/services/chat_helper.dart';
import 'package:facilityfix/staff/notification.dart';
import 'package:facilityfix/staff/home.dart';
import 'package:facilityfix/widgets/app&nav_bar.dart';
import 'package:facilityfix/widgets/buttons.dart';
import 'package:facilityfix/widgets/cards.dart';
import 'package:facilityfix/widgets/helper_models.dart';
import 'package:facilityfix/widgets/modals.dart';
import 'package:flutter/material.dart';

class WorkOrderPage extends StatefulWidget {
  const WorkOrderPage({super.key});

  @override
  State<WorkOrderPage> createState() => _WorkOrderPageState();
}

class _WorkOrderPageState extends State<WorkOrderPage> {
  // ─────────────── Tabs (by request type) ───────────────
  String _selectedTabLabel = "All";

  // ─────────────── Filters ───────────────
  String _selectedStatus = 'All';
  final TextEditingController _searchController = TextEditingController();

  // ─────────────── Dynamic data from API ───────────────
  List<Map<String, dynamic>> _allRequests = [];
  bool _isLoading = true;
  int _unreadNotifCount = 0;

  // ─────────────── Current user info ───────────────
  String? _currentUserId;
  bool _showOnlyMyAssignments = false; // Toggle for assigned tasks

  // ===== Refresh =============================================================
  Future<void> _refresh() async {
    await _loadAllRequests();
  }

  Future<void> _loadAllRequests() async {
    setState(() => _isLoading = true);

    try {
      // Use staff role for API service
      final apiService = APIService(roleOverride: AppRole.staff);
      final allRequests = await apiService.getAllTenantRequests();

      if (mounted) {
        setState(() {
          _allRequests =
              allRequests.map((request) {
                // Convert API response to WorkOrder-like structure
                // Determine canonical status; prefer assessment-derived 'inspected'
                final rawStatus =
                    (request['status'] ?? '').toString().toLowerCase();
                final hasAssessment =
                    (request['staff_assessment'] != null) ||
                    (request['staff_recommendation'] != null) ||
                    (request['assessed_by'] != null) ||
                    (request['assessed_at'] != null) ||
                    (request['completed_at'] != null) ||
                    (request['dateCompleted'] != null) ||
                    rawStatus.contains('inspected');

                String statusToken;
                if (hasAssessment) {
                  statusToken = 'inspected';
                } else if (rawStatus.contains('assigned') ||
                    rawStatus.contains('to inspect') ||
                    rawStatus.contains('to_inspect')) {
                  statusToken = 'to inspect';
                } else if (rawStatus.contains('in_progress') ||
                    rawStatus.contains('in progress')) {
                  statusToken = 'in progress';
                } else if (rawStatus.contains('pending')) {
                  statusToken = 'pending';
                } else {
                  statusToken = rawStatus.isNotEmpty ? rawStatus : 'pending';
                }

                final requestType =
                    (request['request_type'] ?? '').toString().toLowerCase();
                String resolutionType = '';
                if (requestType.contains('job service')) {
                  resolutionType = 'job_service';
                } else if (requestType.contains('concern slip')) {
                  resolutionType = 'concern_slip';
                } else {
                  resolutionType = 'work_order';
                }

                return {
                  'id': request['formatted_id'] ?? request['id'] ?? '',
                  'raw_id':
                      request['id'] ?? '', // Store the raw ID for API calls
                  'title': request['title'] ?? 'Untitled Request',
                  'created_at':
                      request['created_at'] ?? DateTime.now().toIso8601String(),
                  'status': statusToken,
                  'category':
                      request['category'] ??
                      request['department_tag'] ??
                      'general',
                  'priority': request['priority'] ?? '',
                  'request_type': request['request_type'] ?? 'Concern Slip',
                  'unit_id': request['unit_id'] ?? '',
                  // Prefer explicit assigned staff name fields if available; keep assigned_to id separately
                  'assigned_staff':
                      request['assigned_staff_name'] ??
                      request['assigned_staff'] ??
                      '',
                  'assigned_to_id': request['assigned_to'] ?? '',
                  'staff_department':
                      request['staff_department'] ?? request['category'],
                  'description': request['description'] ?? '',
                  'location': request['location'] ?? '',
                  'raw_status': request['status'] ?? 'pending',
                  'job_service_id': request['job_service_id'] ?? '',
                  'resolution_type': resolutionType,
                };
              }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading requests: $e');
      if (mounted) {
        setState(() {
          _allRequests = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadCurrentUser();
    _loadAllRequests();
    _loadUnreadNotifCount();
  }

  Future<void> _loadUnreadNotifCount() async {
    try {
      final api = APIService(roleOverride: AppRole.staff);
      final count = await api.getUnreadNotificationCount();
      if (mounted) setState(() => _unreadNotifCount = count);
    } catch (e) {
      print('[Staff WorkOrder] Failed to load unread notification count: $e');
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final profile = await AuthStorage.getProfile();
      if (profile != null && mounted) {
        setState(() {
          _currentUserId = profile['uid'] ?? profile['user_id'];
        });
      }
    } catch (e) {
      print('Error loading current user: $e');
    }
  }

  // ===== Bottom nav ==========================================================
  final List<NavItem> _navItems = const [
    NavItem(icon: Icons.home),
    NavItem(icon: Icons.work),
    NavItem(icon: Icons.build),
    NavItem(icon: Icons.announcement_rounded),
    NavItem(icon: Icons.calendar_month),
    NavItem(icon: Icons.inventory),
  ];

  void _onTabTapped(int index) {
    if (index == 1) return; // Already on WorkOrder page

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MaintenancePage()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AnnouncementPage()),
        );
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CalendarPage()),
        );
        break;
      case 5:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const InventoryPage()),
        );
        break;
    }
  }

  // ===== Chat Navigation =====================================================
  Future<void> _handleChatNavigation(Map<String, dynamic> request) async {
    try {
      final requestId = request['raw_id'] ?? request['id'] ?? '';
      final requestType = (request['request_type'] ?? '').toLowerCase();

      if (requestId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Unable to start chat - Invalid request ID'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Navigate to appropriate chat based on request type
      // No need to extract tenant ID - chat will be filtered by reference ID
      if (requestType.contains('job service')) {
        await ChatHelper.navigateToJobServiceChat(
          context: context,
          jobServiceId: requestId,
          isStaff: true,
        );
      } else if (requestType.contains('maintenance')) {
        await ChatHelper.navigateToMaintenanceChat(
          context: context,
          maintenanceId: requestId,
          isStaff: true,
        );
      } else {
        // Default to work order/concern slip chat
        await ChatHelper.navigateToWorkOrderChat(
          context: context,
          workOrderId: requestId,
          isStaff: true,
        );
      }
    } catch (e) {
      print('Error navigating to chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting chat: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ===== Popup to create request ============================================
  // Note: Staff members respond to requests rather than creating them
  void _showRequestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (_) => CustomPopup(
            title: 'Staff Access',
            message:
                'Staff members can view and respond to requests. Only tenants can create new requests.',
            primaryText: 'OK',
            onPrimaryPressed: () {
              Navigator.of(context).pop();
            },
          ),
    );
  }

  // ===== Filtering logic =====================================================
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';
  String _norm(String? s) => (s ?? '').toLowerCase().trim();

  // Map backend status values to canonical display labels for cards/list.
  String _displayStatus(dynamic raw) {
    if (raw == null) return 'pending';
    final s = raw.toString().toLowerCase().trim();

    if (s.contains('pending')) return 'pending';
    if (s == 'sent to client' ||
        s == 'sent_to_client' ||
        s == 'sent to tenant' ||
        s == 'sent')
      return 'inspected';
    if (s.contains('inspected') || s.contains('sent')) return 'inspected';
    if (s.contains('to inspect') ||
        s.contains('to be inspect') ||
        s.contains('to_be_inspect') ||
        s.contains('to_inspect'))
      return 'to inspect';
    // Map assigned -> to inspect per request
    if (s == 'assigned') return 'to inspect';
    if (s.contains('in progress') || s.contains('in_progress'))
      return 'in progress';
    if (s.contains('on hold') || s.contains('on_hold')) return 'on hold';

    return s.isEmpty ? 'pending' : s;
  }

  bool _tabMatchesByRequestType(Map<String, dynamic> w) {
    final type = _norm(w['request_type']);
    final rawStatus = _norm(w['raw_status'] ?? w['status'] ?? '');

    // Hide completed concern slips (they've been converted to job service/work order)
    if (type == 'concern slip' && rawStatus == 'completed') {
      return false;
    }

    switch (_norm(_selectedTabLabel)) {
      case 'all':
        return true;
      case 'concern slip':
        return type == 'concern slip';
      case 'job service':
        return type == 'job service';
      case 'work order':
        return type == 'work order';
      default:
        return true;
    }
  }

  bool _statusMatches(Map<String, dynamic> w) {
    if (_selectedStatus == 'All') return true;
    return _norm(w['status']) == _norm(_selectedStatus);
  }

  bool _departmentMatches(Map<String, dynamic> w) {
    // Department filter removed — always match
    return true;
  }

  bool _assignmentMatches(Map<String, dynamic> w) {
    if (!_showOnlyMyAssignments || _currentUserId == null) return true;
    // Prefer explicit assigned_to_id (internal id) for matching against current user
    final assignedId =
        (w['assigned_to_id'] ?? w['assigned_to'] ?? '').toString();
    if (assignedId.isNotEmpty) return assignedId == (_currentUserId ?? '');
    // fallback to name comparison (unlikely) — compare raw assigned_staff string
    final assignedStaff = w['assigned_staff'] ?? '';
    return assignedStaff == (_currentUserId ?? '');
  }

  bool _searchMatches(Map<String, dynamic> w) {
    final q = _norm(_searchController.text);
    if (q.isEmpty) return true;

    final createdAt =
        DateTime.tryParse(w['created_at'] ?? '') ?? DateTime.now();
    final dateText = shortDate(createdAt);

    return <String>[
      w['title'] ?? '',
      w['id'] ?? '',
      w['category'] ?? '',
      w['unit_id'] ?? '',
      w['status'] ?? '',
      w['request_type'] ?? '',
      dateText,
    ].any((s) => _norm(s).contains(q));
  }

  List<Map<String, dynamic>> get _filtered =>
      _allRequests
          .where(_tabMatchesByRequestType)
          .where(_statusMatches)
          .where(_departmentMatches)
          .where(_searchMatches)
          .where(_assignmentMatches)
          .toList();

  List<Map<String, dynamic>> get _filteredSorted {
    final list = List<Map<String, dynamic>>.from(_filtered);
    list.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
      final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
      return bDate.compareTo(aDate);
    });
    return list;
  }

  List<String> get _statusOptions {
    // Use fixed status options per product requirement
    return [
      'All',
      'Pending',
      'To be Inspect',
      'Inspected',
      'Assigned',
      'In Progress',
      'On Hold',
    ];
  }

  List<String> get _deptOptions {
    // Department filter removed per request — keep only 'All' to preserve UI
    return ['All'];
  }

  List<TabItem> get _tabs {
    final visible =
        _allRequests
            .where(_statusMatches)
            .where(_departmentMatches)
            .where(_searchMatches)
            .toList();

    int countFor(String type) {
      if (_norm(type) == 'concern slip') {
        // For concern slips, exclude completed ones (they've been converted)
        return visible
            .where(
              (w) =>
                  _norm(w['request_type']) == _norm(type) &&
                  _norm(w['raw_status'] ?? w['status'] ?? '') != 'completed',
            )
            .length;
      }
      return visible
          .where((w) => _norm(w['request_type']) == _norm(type))
          .length;
    }

    return [
      TabItem(label: 'All', count: visible.length),
      TabItem(label: 'Concern Slip', count: countFor('concern slip')),
      TabItem(label: 'Job Service', count: countFor('job service')),
      TabItem(label: 'Work Order', count: countFor('work order')),
    ];
  }

  Widget buildCard(Map<String, dynamic> r) {
    final createdAt =
        DateTime.tryParse(r['created_at'] ?? '') ?? DateTime.now();
    final requestType = (r['request_type'] ?? '').toLowerCase();

    return RepairCard(
      title: r['title'] ?? 'Untitled Request',
      id:
          (() {
            if (requestType.contains('job service')) {
              return (r['job_service_id'] ?? r['id'] ?? '').toString();
            }
            return (r['formatted_id'] ?? r['id'] ?? '').toString();
          })(),
      createdAt: createdAt,
      // display a normalized, human-friendly status for the card
      statusTag: _displayStatus(r['status'] ?? 'pending'),
      departmentTag: r['category'],
      priorityTag: r['priority'],
      unitId: r['unit_id'] ?? '',
      requestTypeTag: r['request_type'] ?? 'Concern Slip',
      assignedStaff: r['assigned_staff'],
      staffDepartment: r['staff_department'],
      resolutionType: r['resolution_type'],
      onTap: () {
        // Extract the raw ID from the formatted ID or use the ID directly
        final requestId = r['raw_id'] ?? r['id'] ?? '';
        final requestType = (r['request_type'] ?? '').toLowerCase();

        if (requestId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Invalid request ID'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        // Navigate to appropriate detail page based on request type
        if (requestType.contains('job service')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => StaffJobServiceDetailPage(jobServiceId: requestId),
            ),
          ).then((_) {
            // Refresh data when returning
            _loadAllRequests();
          });
        } else {
          // Default to concern slip detail page for other types
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => StaffConcernSlipDetailPage(concernSlipId: requestId),
            ),
          ).then((_) {
            // Refresh data when returning
            _loadAllRequests();
          });
        }
      },
      onChatTap: () {
        _handleChatNavigation(r);
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredSorted;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: 'Repair Tasks',
        notificationCount: _unreadNotifCount,
        onNotificationTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationPage()),
          );
          _loadUnreadNotifCount();
        },
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: Stack(
            children: [
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SearchAndFilterBar(
                          searchController: _searchController,
                          selectedStatus: _selectedStatus,
                          statuses: _statusOptions,
                          onStatusChanged: (status) {
                            setState(() {
                              _selectedStatus =
                                  status.trim().isEmpty ? 'All' : status;
                            });
                          },
                          onSearchChanged: (_) {
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 16),
                        StatusTabSelector(
                          tabs: _tabs,
                          selectedLabel: _selectedTabLabel,
                          onTabSelected:
                              (label) =>
                                  setState(() => _selectedTabLabel = label),
                        ),
                        const SizedBox(height: 20),

                        Row(
                          children: [
                            Text(
                              'Recent $_selectedTabLabel',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F4F7),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${items.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF475467),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Expanded(
                          child:
                              items.isEmpty
                                  ? const EmptyState()
                                  : ListView.separated(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    itemCount: items.length,
                                    separatorBuilder:
                                        (_, __) => const SizedBox(height: 12),
                                    itemBuilder: (_, i) => buildCard(items[i]),
                                  ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavBar(
        items: _navItems,
        currentIndex: 1,
        onTap: _onTabTapped,
      ),
    );
  }
}
