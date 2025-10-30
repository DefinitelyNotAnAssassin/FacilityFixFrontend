import 'dart:async';
import 'package:facilityfix/services/api_services.dart';
import 'package:facilityfix/services/chat_helper.dart';
import 'package:facilityfix/tenant/announcement.dart';
import 'package:facilityfix/tenant/home.dart';
import 'package:facilityfix/tenant/notification.dart';
import 'package:facilityfix/tenant/profile.dart';
import 'package:facilityfix/tenant/request_forms.dart';
import 'package:facilityfix/tenant/view_details/concern_slip_details.dart';
import 'package:facilityfix/tenant/view_details/workorder_details.dart';
import 'package:facilityfix/widgets/view_details.dart';
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
  String _selectedDepartment = 'All'; // mapped as "classification"
  final TextEditingController _searchController = TextEditingController();

  // ─────────────── Dynamic data from API ───────────────
  List<Map<String, dynamic>> _allRequests = [];
  bool _isLoading = true;

  // ===== Refresh =============================================================
  Future<void> _refresh() async {
    await _loadAllRequests();
  }

  Future<void> _loadAllRequests() async {
    setState(() => _isLoading = true);

    try {
      final apiService = APIService();
      final allRequests = await apiService.getAllTenantRequests();

      // Enrich requests with staff names
      for (var request in allRequests) {
        await _enrichWithStaffName(request, apiService);
      }

      if (mounted) {
        setState(() {
          _allRequests =
              allRequests.map((request) {
                // Convert API response to WorkOrder-like structure
                // For work orders, try to get department from various fields
                final requestType = (request['request_type'] ?? '').toLowerCase();
                String? department;
                
                if (requestType.contains('work order') || requestType.contains('work permit')) {
                  // For work orders, try department_tag, then request_type_detail, then category
                  department = request['department_tag'] ?? 
                               request['request_type_detail'] ?? 
                               request['category'] ?? 
                               'general';
                } else {
                  // For other requests, use category or department_tag
                  department = request['category'] ?? 
                               request['department_tag'] ?? 
                               'general';
                }
                
                return {
                  'id': request['id'] ?? '', // Use raw ID for navigation
                  'formatted_id': request['formatted_id'] ?? request['id'] ?? '', // Keep formatted ID for display
                  'title': request['title'] ?? 'Untitled Request',
                  'created_at':
                      request['created_at'] ?? DateTime.now().toIso8601String(),
                  'status': request['status'] ?? 'pending',
                  'category': department,
                  'priority': request['priority'] ?? 'medium',
                  'request_type': request['request_type'] ?? 'Concern Slip',
                  'unit_id': request['unit_id'] ?? request['location'] ?? '',
                  'assigned_staff':
                      request['assigned_to_name'] ?? 
                      request['assigned_staff'] ?? 
                      request['assigned_to'],
                  'staff_department':
                      request['staff_department'] ?? department,
                  'staff_photo_url':
                      request['staff_photo_url'] ?? 
                      request['assigned_photo_url'] ?? 
                      request['photo_url'],
                  'description': request['description'] ?? '',
                  'location': request['location'] ?? '',
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

  /// Fetch and populate staff name when we have staff user ID
  Future<void> _enrichWithStaffName(Map<String, dynamic> data, APIService apiService) async {
    try {
      // Fetch assigned_to name if we have the ID but not the name
      if (data.containsKey('assigned_to') &&
          data['assigned_to'] != null &&
          data['assigned_to'].toString().isNotEmpty &&
          !data.containsKey('assigned_to_name')) {
        final userId = data['assigned_to'].toString();
        print('[DEBUG] Fetching staff name for assigned_to: $userId');
        
        try {
          final userData = await apiService.getUserById(userId);
          if (userData != null) {
            final firstName = userData['first_name'] ?? '';
            final lastName = userData['last_name'] ?? '';
            final fullName = '$firstName $lastName'.trim();
            if (fullName.isNotEmpty) {
              data['assigned_to_name'] = fullName;
              print('[DEBUG] Set assigned_to_name to: $fullName');
            }
          }
        } catch (e) {
          print('[DEBUG] Could not fetch user data for $userId: $e');
          // Don't fail, just continue without the name
        }
      }
    } catch (e) {
      print('[DEBUG] Error enriching staff name: $e');
      // Don't fail the entire load if we can't fetch staff names
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadAllRequests();
  }

  // ===== Bottom nav ==========================================================
  final List<NavItem> _navItems = const [
    NavItem(icon: Icons.home),
    NavItem(icon: Icons.work),
    NavItem(icon: Icons.announcement_rounded),
    NavItem(icon: Icons.person),
  ];

  void _onTabTapped(int index) {
    final destinations = [
      const HomePage(),
      const WorkOrderPage(),
      const AnnouncementPage(),
      const ProfilePage(),
    ];
    if (index != 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destinations[index]),
      );
    }
  }

  // ===== Popup to create request ============================================
  void _showRequestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (_) => CustomPopup(
            title: 'Create a Concern Slip',
            message: 'Would you like to create a new concern slip?',
            primaryText: 'Yes, Continue',
            onPrimaryPressed: () {
              Navigator.of(context).pop();
              showDialog(
                context: context,
                builder:
                    (_) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Create a new Concern Slip?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              leading: const Icon(Icons.assignment_outlined),
                              title: const Text('Concern Slip'),
                              onTap: () {
                                Navigator.of(context).pop();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => const RequestForm(
                                          requestType: 'Concern Slip',
                                        ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
              );
            },
            secondaryText: 'Cancel',
            onSecondaryPressed: () => Navigator.of(context).pop(),
          ),
    );
  }

  // ===== Chat Navigation =====================================================
  Future<void> _handleChatNavigation(Map<String, dynamic> request) async {
    try {
      final requestId = request['id'] ?? '';
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
      if (requestType.contains('job service')) {
        await ChatHelper.navigateToJobServiceChat(
          context: context,
          jobServiceId: requestId,
          isStaff: false,
        );
      } else if (requestType.contains('maintenance')) {
        await ChatHelper.navigateToMaintenanceChat(
          context: context,
          maintenanceId: requestId,
          isStaff: false,
        );
      } else {
        // Default to work order/concern slip chat
        await ChatHelper.navigateToWorkOrderChat(
          context: context,
          workOrderId: requestId,
          isStaff: false,
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

  bool _tabMatchesByRequestType(Map<String, dynamic> w) {
    final type = _norm(w['request_type']);
    switch (_norm(_selectedTabLabel)) {
      case 'all':
        return true;
      case 'concern slip':
        return type == 'concern slip';
      case 'job service':
        return type == 'job service';
      case 'work order':
        return type == 'work order' || type == 'work order permit';
      default:
        return true;
    }
  }

  bool _statusMatches(Map<String, dynamic> w) {
    if (_selectedStatus == 'All') return true;
    return _norm(w['status']) == _norm(_selectedStatus);
  }

  bool _departmentMatches(Map<String, dynamic> w) {
    if (_selectedDepartment == 'All') return true;
    
    final category = _norm(w['category']);
    final selectedDept = _norm(_selectedDepartment);
    
    // If "Others" is selected, show all categories that are NOT the main 4 departments
    if (selectedDept == 'others') {
      return category != 'carpentry' && 
             category != 'plumbing' && 
             category != 'electrical' && 
             category != 'masonry';
    }
    
    // For specific departments, match exactly
    return category == selectedDept;
  }

  bool _searchMatches(Map<String, dynamic> w) {
    final q = _norm(_searchController.text);
    if (q.isEmpty) return true;

    final createdAt =
        DateTime.tryParse(w['created_at'] ?? '') ?? DateTime.now();
    final dateText = shortDate(createdAt);

    return <String>[
      w['title'] ?? '',
      w['formatted_id'] ?? w['id'] ?? '', // Search by formatted ID for display
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
    // Fixed status list for all tabs
    return [
      'All',
      'Assessed',
      'Assigned',
      'Completed',
      'Pending',
    ];
  }

  List<String> get _deptOptions {
    // Fixed department list
    return [
      'All',
      'Carpentry',
      'Plumbing',
      'Electrical',
      'Masonry',
      'Others',
    ];
  }

  List<TabItem> get _tabs {
    final visible =
        _allRequests
            .where(_statusMatches)
            .where(_departmentMatches)
            .where(_searchMatches)
            .toList();

    int countFor(String type) =>
        visible.where((w) => _norm(w['request_type']) == _norm(type)).length;

    return [
      TabItem(label: 'All', count: visible.length),
      TabItem(label: 'Concern Slip', count: countFor('concern slip')),
      TabItem(label: 'Job Service', count: countFor('job service')),
      TabItem(label: 'Work Order', count: countFor('work order') + countFor('work order permit')),
    ];
  }

  Widget buildCard(Map<String, dynamic> r) {
    final createdAt = DateTime.tryParse(r['created_at'] ?? '') ?? DateTime.now();
    final requestType = (r['request_type'] ?? '').toLowerCase();
    final concernSlipId = r['id'] ?? '';
    final hasMaterialsUsed = r.containsKey('materials_used') && r['materials_used'] != null;

    return RepairCard(
      title: r['title'] ?? 'Untitled Request',
      id: (r['formatted_id'] ?? r['id'] ?? '').toString().substring(0, ((r['formatted_id'] ?? r['id'] ?? '').toString().length > 11 ? 11 : (r['formatted_id'] ?? r['id'] ?? '').toString().length)), // Display up to 16 chars
      createdAt: createdAt,
      statusTag: r['status'] ?? 'pending',
      departmentTag: r['category'],
      priorityTag: r['priority'],
      unitId: r['unit_id'] ?? '',
      requestTypeTag: r['request_type'] ?? 'Concern Slip',
      assignedStaff: r['assigned_staff'],
      staffDepartment: r['staff_department'],
      staffPhotoUrl: r['staff_photo_url'],
      onTap: () {
        if (concernSlipId.isEmpty) return;
        if (hasMaterialsUsed) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JobServiceDetails(
                id: concernSlipId,
                concernSlipId: concernSlipId,
                createdAt: createdAt,
                requestTypeTag: r['request_type'] ?? 'Job Service',
                statusTag: r['status'] ?? 'pending',
                requestedBy: r['assigned_staff'] ?? '',
                unitId: r['unit_id'] ?? '',
                materialsUsed: r['materials_used'],
                // Add other required fields as needed
              ),
            ),
          );
        } 
        else if (requestType.contains('work order')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkOrderDetailsPage(workOrderId: r['id'], selectedTabLabel: ''),
            ),
          );
        }
        else if (requestType.contains('concern slip')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TenantConcernSlipDetailPage(concernSlipId: concernSlipId),
            ),
          );
        } else {
          // Fallback to concern slip details
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TenantConcernSlipDetailPage(concernSlipId: concernSlipId),
            ),
          );
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
        title: 'Work Order Management',
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationPage()),
              );
            },
          ),
        ],
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
                          selectedClassification: _selectedDepartment,
                          classifications: _deptOptions,
                          onStatusChanged: (status) {
                            setState(() {
                              _selectedStatus =
                                  status.trim().isEmpty ? 'All' : status;
                            });
                          },
                          onClassificationChanged: (dept) {
                            setState(() {
                              _selectedDepartment =
                                  dept.trim().isEmpty ? 'All' : dept;
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
              Positioned(
                bottom: 24,
                right: 24,
                child: AddButton(onPressed: () => _showRequestDialog(context)),
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