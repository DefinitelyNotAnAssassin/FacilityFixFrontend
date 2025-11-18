import 'package:facilityfix/services/api_services.dart';
import 'package:facilityfix/config/env.dart';
import 'package:facilityfix/staff/view_details/concern_slip.dart';
import 'package:facilityfix/staff/view_details/job_service_detail.dart';
import 'package:facilityfix/staff/workorder.dart';
import 'package:facilityfix/staff/maintenance.dart';
import 'package:facilityfix/staff/announcement.dart';
import 'package:facilityfix/staff/calendar.dart';
import 'package:facilityfix/staff/inventory.dart';
import 'package:facilityfix/staff/notification.dart';
import 'package:facilityfix/staff/profile.dart';
import 'package:flutter/material.dart';
import 'package:facilityfix/widgets/cards.dart';
import 'package:facilityfix/widgets/modals.dart';
import 'package:facilityfix/widgets/app&nav_bar.dart';
import 'package:facilityfix/services/auth_storage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomeState();
}

class _HomeState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _isLoading = true;

  // runtime user fields (defaults)
  String _userName = 'User';
  String _unitLabel = '—';
  String _userInitials = ' ';

  List<Map<String, dynamic>> _allRequests = [];
  int _activeRequestsCount = 0;
  int _doneRequestsCount = 0;
  List<Map<String, dynamic>> _latestAnnouncements = [];
  int _unreadNotifCount = 0;

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
    _verifyRoleAndLoad();
  }

  Future<void> _verifyRoleAndLoad() async {
    // Verify user role matches staff
    final profile = await AuthStorage.getProfile();
    final role = profile?['role']?.toString().toLowerCase() ?? '';

    if (role.isEmpty) {
      print('[Staff Home] No role found in profile');
      // Continue loading anyway
    } else if (role != 'staff') {
      print('[Staff Home] Invalid role: $role (expected: staff)');
      // Role mismatch - redirect to appropriate home
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Access denied. This page is for staff only.'),
            backgroundColor: Colors.red,
          ),
        );
        // Don't load data, stay in loading state or redirect
        return;
      }
    } else {
      print('[Staff Home] Role verified: staff');
    }

    // Load data
    _loadUserData();
    _loadAllRequests();
    _loadLatestAnnouncements();
    _loadInventoryRequests();
    _loadUnreadNotifCount();
  }

  Future<void> _loadUnreadNotifCount() async {
    try {
      final api = APIService(roleOverride: AppRole.staff);
      final count = await api.getUnreadNotificationCount();
      if (mounted) setState(() => _unreadNotifCount = count);
    } catch (e) {
      print('[Staff Home] Failed to load unread notification count: $e');
    }
  }

  Future<void> _loadAllRequests() async {
    try {
      // Use staff role for API service
      final apiService = APIService(roleOverride: AppRole.staff);
      final allRequests = await apiService.getAllTenantRequests("");

      if (allRequests.isNotEmpty && mounted) {
        setState(() {
          _allRequests = allRequests;

          _activeRequestsCount =
              allRequests.where((data) {
                final status = (data['status'] ?? '').toString().toLowerCase();
                final requestType =
                    (data['request_type'] ?? '').toString().toLowerCase();

                // Exclude completed concern slips (they've been converted to job service/work order)
                if (requestType.contains('concern slip') &&
                    status == 'completed') {
                  return false;
                }

                // Exclude done/completed/closed requests
                return status != 'done' &&
                    status != 'completed' &&
                    status != 'closed';
              }).length;

          _doneRequestsCount =
              allRequests
                  .where(
                    (data) =>
                        (data['status'] ?? '').toString().toLowerCase() ==
                            'done' ||
                        (data['status'] ?? '').toString().toLowerCase() ==
                            'completed' ||
                        (data['status'] ?? '').toString().toLowerCase() ==
                            'closed',
                  )
                  .length;
        });
      }
    } catch (e) {
      print('Error loading all requests: $e');
    }
  }

  Future<void> _loadLatestAnnouncements() async {
    try {
      // Get user profile to determine building
      final profile = await AuthStorage.getProfile();
      final buildingId =
          profile?['building_id']?.toString() ?? 'default_building';

      // Use staff role for API service
      final apiService = APIService(roleOverride: AppRole.staff);

      // Fetch announcements with limit of 3
      final announcements = await apiService.getAllAnnouncements(
        buildingId: buildingId,
        audience: 'all', // Staff can see all announcements
        activeOnly: true,
        limit: 3,
      );

      if (mounted) {
        setState(() {
          _latestAnnouncements = announcements;
        });
      }
    } catch (e) {
      print('Error loading latest announcements: $e');
      // Don't show error to user, just keep empty list
    }
  }

  Future<void> _loadInventoryRequests() async {
    try {
      // Use staff role for API service
      final apiService = APIService(roleOverride: AppRole.staff);

      // Get user profile for building context
      final profile = await AuthStorage.getProfile();
      final buildingId =
          profile?['building_id']?.toString() ?? 'default_building';

      // Fetch all inventory requests for the building
      final requests = await apiService.getInventoryRequests(
        buildingId: buildingId,
      );

      if (mounted && requests.isNotEmpty) {
        // Count by status
        int pendingCount = 0;
        int approvedCount = 0;

        for (final req in requests) {
          final status = (req['status'] ?? '').toString().toLowerCase();
          if (status == 'pending') {
            pendingCount++;
          } else if (status == 'approved' || status == 'fulfilled') {
            approvedCount++;
          }
        }

        print('[Staff Home] Loaded ${requests.length} inventory requests');
        print('[Staff Home] Pending: $pendingCount, Approved: $approvedCount');
      }
    } catch (e) {
      print('Error loading inventory requests: $e');
      // Don't show error to user, just keep empty list
    }
  }

  // Capitalize first name only
  String _titleCaseFirstOnly(String input) {
    final s = input.trim();
    if (s.isEmpty) return s;
    final firstWord = s.split(RegExp(r'\s+')).first;
    final lower = firstWord.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  // Extract initials from full name
  String _getInitials(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'U';

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }

    // Take first letter of first name and last name
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      // Verify role is persisted
      final localProfile = await AuthStorage.getProfile();
      final storedRole = localProfile?['role']?.toString().toLowerCase() ?? '';

      // If role mismatch, redirect to tenant (security measure)
      if (storedRole.isNotEmpty && storedRole != 'staff') {
        print(
          '[Staff Home] Role mismatch detected: $storedRole, expected staff',
        );
        // This shouldn't happen, but if it does, don't continue loading
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      // Try to fetch from backend first with staff role
      final apiService = APIService(roleOverride: AppRole.staff);
      final profileData = await apiService.getUserProfile();

      if (profileData != null) {
        await AuthStorage.saveProfile(profileData);
        _updateUIFromProfile(profileData);
      } else {
        final localProfile = await AuthStorage.getProfile();
        if (localProfile != null) {
          _updateUIFromProfile(localProfile);
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      final localProfile = await AuthStorage.getProfile();
      if (localProfile != null) {
        _updateUIFromProfile(localProfile);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateUIFromProfile(Map<String, dynamic> profile) {
    // ---- Name ----
    String firstName = '';
    String fullNameForInitials = '';
    final firstRaw = (profile['first_name'] ?? '').toString().trim();

    if (firstRaw.isNotEmpty) {
      firstName = _titleCaseFirstOnly(firstRaw);
      // Build full name for initials
      final lastRaw = (profile['last_name'] ?? '').toString().trim();
      fullNameForInitials =
          '$firstRaw ${lastRaw.isNotEmpty ? lastRaw : ''}'.trim();
    } else {
      final fullName = (profile['full_name'] ?? '').toString().trim();
      if (fullName.isNotEmpty) {
        firstName = _titleCaseFirstOnly(fullName);
        fullNameForInitials = fullName;
      }
    }

    // ---- Staff Department (instead of building_unit for staff) ----
    final staffDept = (profile['staff_department'] ?? '').toString().trim();
    final formattedDept =
        staffDept.isNotEmpty ? _formatDepartment(staffDept) : 'Staff';

    if (mounted) {
      setState(() {
        _userName = firstName.isNotEmpty ? firstName : 'User';
        _unitLabel = formattedDept; // Show department for staff
        _userInitials = _getInitials(
          fullNameForInitials.isNotEmpty ? fullNameForInitials : 'User',
        );
      });
    }
  }

  String _formatDepartment(String dept) {
    // Format department name for display
    switch (dept.toLowerCase()) {
      case 'maintenance':
        return 'Maintenance';
      case 'carpentry':
        return 'Carpentry';
      case 'plumbing':
        return 'Plumbing';
      case 'electrical':
        return 'Electrical';
      case 'masonry':
        return 'Masonry';
      default:
        return dept.isEmpty ? 'Staff' : dept;
    }
  }

  void _onTabTapped(int index) {
    if (index == _selectedIndex) return;

    switch (index) {
      case 0:
        if (_selectedIndex != 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WorkOrderPage()),
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
      case 6:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfilePage()),
        ).then((_) {
          _loadUserData();
        });
        break;
    }

    setState(() => _selectedIndex = index);
  }

  Future<void> _refresh() async {
    await _loadUserData();
    await _loadAllRequests();
    await _loadLatestAnnouncements();
    await _loadInventoryRequests();
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    // Determine the request type and format accordingly
    final requestType = request['request_type'] ?? 'Concern Slip';
    final status = request['status'] ?? 'pending';

    // Don't display completed concern slips (they've been converted)
    if (requestType.toLowerCase().contains('concern slip') &&
        status.toLowerCase() == 'completed') {
      return const SizedBox.shrink();
    }

    final priority = request['priority'] ?? 'medium';

    // Format the ID based on request type
    String displayId = request['formatted_id'] ?? request['id'] ?? '';
    if (displayId.isEmpty) {
      switch (requestType.toLowerCase()) {
        case 'concern slip':
          displayId = 'CS-${request['id'] ?? ''}';
          break;
        case 'job service':
          displayId =
              'JS-${(request['id'] ?? '').toString().padLeft(5, '0').substring(0, 5)}';
          break;
        case 'work order':
          displayId = 'WO-${request['id'] ?? ''}';
          break;
        default:
          displayId = (request['id'] ?? '')
              .toString()
              .padLeft(11, '0')
              .substring(0, 11);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // Extract the raw ID from the request data
          // Use the raw ID (not formatted_id) for API calls
          final requestId = request['id']?.toString() ?? '';

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
          if (request['title'].contains('Job Service for:')) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => StaffJobServiceDetailPage(jobServiceId: requestId),
              ),
            ).then((_) {
              // Refresh data when returning from detail page
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
              // Refresh data when returning from detail page
              _loadAllRequests();
            });
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request['title'] ?? 'Untitled Request',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B1D21),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatStatus(status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'ID: $displayId',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(priority).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatPriority(priority),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _getPriorityColor(priority),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _formatDate(request['created_at'] ?? ''),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF667085),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getRequestTypeColor(requestType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    requestType,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _getRequestTypeColor(requestType),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
      case 'done':
        return 'Done';
      case 'approved':
        return 'Approved';
      case 'denied':
        return 'Denied';
      case 'on_hold':
        return 'On Hold';
      default:
        return status;
    }
  }

  String _formatPriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      case 'critical':
        return 'Critical';
      default:
        return priority;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF79009);
      case 'assigned':
      case 'in_progress':
        return const Color(0xFF2563EB);
      case 'done':
      case 'completed':
        return const Color(0xFF24D164);
      case 'approved':
        return const Color(0xFF24D164);
      case 'denied':
        return const Color(0xFFDC2626);
      case 'on_hold':
        return const Color(0xFF9CA3AF);
      default:
        return const Color(0xFF667085);
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'critical':
        return const Color(0xFFDC2626);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'low':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF667085);
    }
  }

  Color _getRequestTypeColor(String requestType) {
    switch (requestType.toLowerCase()) {
      case 'concern slip':
        return const Color(0xFF7C3AED);
      case 'job service':
        return const Color(0xFF0891B2);
      case 'work order':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF667085);
    }
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    final title = announcement['title'] ?? 'Untitled Announcement';
    final content = announcement['content'] ?? '';
    final announcementType = announcement['type'] ?? 'general';
    final priorityLevel = announcement['priority_level'] ?? 'normal';
    final createdAt =
        announcement['date_added'] ?? announcement['created_at'] ?? '';
    final formattedId =
        announcement['formatted_id'] ?? 'ANN-${announcement['id'] ?? ''}';

    // Truncate content for preview
    String contentPreview = content;
    if (content.length > 120) {
      contentPreview = '${content.substring(0, 120)}...';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // Navigate to announcements page or show detail modal
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AnnouncementPage()),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getAnnouncementTypeColor(
                      announcementType,
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getAnnouncementTypeIcon(announcementType),
                    size: 20,
                    color: _getAnnouncementTypeColor(announcementType),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1B1D21),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedId,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
                if (priorityLevel != 'normal')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(priorityLevel).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatPriority(priorityLevel),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getPriorityColor(priorityLevel),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              contentPreview,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF374151),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatAnnouncementDate(createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF667085),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatAnnouncementType(announcementType),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _getAnnouncementTypeColor(announcementType),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getAnnouncementTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'maintenance':
        return Icons.build_outlined;
      case 'reminder':
        return Icons.notifications_outlined;
      case 'event':
        return Icons.event_outlined;
      case 'policy':
        return Icons.policy_outlined;
      case 'emergency':
        return Icons.warning_amber_outlined;
      default:
        return Icons.announcement_outlined;
    }
  }

  Color _getAnnouncementTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'maintenance':
        return const Color(0xFF0891B2);
      case 'reminder':
        return const Color(0xFFF59E0B);
      case 'event':
        return const Color(0xFF7C3AED);
      case 'policy':
        return const Color(0xFF2563EB);
      case 'emergency':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF667085);
    }
  }

  String _formatAnnouncementType(String type) {
    switch (type.toLowerCase()) {
      case 'maintenance':
        return 'Maintenance';
      case 'reminder':
        return 'Reminder';
      case 'event':
        return 'Event';
      case 'policy':
        return 'Policy';
      case 'emergency':
        return 'Emergency';
      case 'general':
        return 'General';
      default:
        return type;
    }
  }

  String _formatAnnouncementDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) {
            return 'Just now';
          }
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _userName.isNotEmpty ? _userName : 'User';
    final displayUnit = _unitLabel.isNotEmpty ? _unitLabel : '—';

    final recentRequests = _allRequests.take(3).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: 'Home',
        leading: IconButton(
          icon: CircleAvatar(
            backgroundColor: const Color(0xFF005CE7),
            radius: 16,
            child: Text(
              _userInitials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            );
          },
        ),
        notificationCount: _unreadNotifCount,
        onNotificationTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationPage()),
          );
          _loadUnreadNotifCount();
        },
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Greeting
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                text: 'Hello, ',
                                style: const TextStyle(
                                  color: Color(0xFF1B1D21),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.5,
                                ),
                                children: [
                                  TextSpan(
                                    text: displayName,
                                    style: const TextStyle(
                                      color: Color(0xFF101828),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayUnit,
                              style: const TextStyle(
                                color: Color(0xFF667085),
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: StatusCard(
                                title: 'Active Request',
                                count: '$_activeRequestsCount',
                                icon: Icons.settings_outlined,
                                iconColor: const Color(0xFFF79009),
                                backgroundColor: const Color(0xFFFFFAEB),
                                borderColor: const Color(0xFFF79009),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatusCard(
                                title: 'Done',
                                count: '$_doneRequestsCount',
                                icon: Icons.check_circle_rounded,
                                iconColor: const Color(0xFF24D164),
                                backgroundColor: const Color(0xFFF0FDF4),
                                borderColor: const Color(0xFF24D164),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Recent Requests
                        SectionHeader(
                          title: 'Recent Requests',
                          actionLabel: 'View all',
                          onActionTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const WorkOrderPage(),
                                ),
                              ),
                        ),
                        const SizedBox(height: 12),

                        recentRequests.isEmpty
                            ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.assignment_outlined,
                                    size: 48,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No recent requests',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Your submitted requests will appear here',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF6B7280),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                            : Column(
                              children:
                                  recentRequests
                                      .map(
                                        (request) => _buildRequestCard(request),
                                      )
                                      .toList(),
                            ),
                        const SizedBox(height: 24),
                        // Latest Announcement
                        SectionHeader(
                          title: 'Latest',
                          actionLabel: 'View all',
                          onActionTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AnnouncementPage(),
                                ),
                              ),
                        ),
                        const SizedBox(height: 12),
                        _latestAnnouncements.isEmpty
                            ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.announcement_outlined,
                                    size: 48,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No announcements',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Building announcements will appear here',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF6B7280),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                            : Column(
                              children:
                                  _latestAnnouncements
                                      .map(
                                        (announcement) =>
                                            _buildAnnouncementCard(
                                              announcement,
                                            ),
                                      )
                                      .toList(),
                            ),
                        const SizedBox(height: 24),
                      ],
                    ),
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
