import 'package:facilityfix/utils/ui_format.dart';
import 'package:facilityfix/services/firebase_chat_service.dart';
import 'package:facilityfix/widgets/tag.dart';
import 'package:flutter/material.dart';

class StatusCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData? icon;
  final Color iconColor;
  final Color backgroundColor; // base for gradient
  final Color borderColor;

  const StatusCard({
    super.key,
    required this.title,
    required this.count,
    this.icon,
    this.iconColor = const Color(0xFF475467),
    this.backgroundColor = const Color(0xFFEFF5FF),
    this.borderColor = const Color(0xFF005CE7),
  });

  @override
  Widget build(BuildContext context) {
    final Color gStart = Color.lerp(backgroundColor, Colors.white, 0.88)!;
    final Color gEnd = Color.lerp(backgroundColor, Colors.white, 0.70)!;

    return Material(
      color: Colors.transparent,
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [gStart, gEnd],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor.withOpacity(0.45), width: 1),
          boxShadow: [
            BoxShadow(
              color: borderColor.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias, // ensures glow respects rounded corners
        child: Stack(
          children: [
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14.0,
                vertical: 10.0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Texts
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475467),
                            fontFamily: 'Inter',
                            letterSpacing: -0.2,
                          ),
                        ),
                        const Spacer(),
                        // Count
                        Text(
                          count,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          style: const TextStyle(
                            fontSize: 26,
                            height: 1.0,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF101828),
                            fontFamily: 'Inter',
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Icon (no border, just clean)
                  if (icon != null) ...[
                    const SizedBox(width: 12),
                    Align(
                      alignment: Alignment.topRight,
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: Icon(icon, size: 30, color: iconColor),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Announcement Card

enum AnnStatusFilter { all, unread, read, recent }

class AnnouncementCard extends StatelessWidget {
  final String id;
  final String title;
  final String announcementType;
  final DateTime createdAt;
  final bool isRead;
  final VoidCallback onTap;
  final bool showChevron;

  const AnnouncementCard({
    super.key,
    required this.id,
    required this.title,
    required this.announcementType,
    required this.createdAt,
    required this.isRead,
    required this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(announcementType);
    final accent = style.accent;
    final tint = style.tint;
    final dateStr = UiDateUtils.humanDateTime(createdAt);
    final timeAgo = UiDateUtils.timeAgo(createdAt);

    return Material(
      color: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Stack(
          children: [
            // Card container
            Container(
              decoration: BoxDecoration(
                color: tint,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: accent.withOpacity(0.18)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row: title + right arrow + unread dot
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF101828),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          if (showChevron)
                            Icon(Icons.chevron_right, color: accent, size: 22),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 6, top: 2),
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "ID: $id",
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Type + date
                  Row(
                    children: [
                      AnnouncementType(announcementType),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Created at $dateStr • $timeAgo",
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Left accent bar
            Positioned.fill(
              left: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(width: 4, color: accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Lightweight style system for the card (accent bar & container tint)
class _ClassStyle {
  final Color accent; // strong accent (bar/chevron)
  final Color tint; // soft background

  const _ClassStyle({required this.accent, required this.tint});
}

// Palette map
const Map<String, _ClassStyle> _styles = {
  'utility interruption': _ClassStyle(
    accent: Color(0xFF005CE7),
    tint: Color(0xFFEFF4FF),
  ),
  'power outage': _ClassStyle(
    accent: Color(0xFFF3B40D),
    tint: Color(0xFFFFF7E8),
  ),
  'pest control': _ClassStyle(
    accent: Color(0xFF00A651),
    tint: Color(0xFFE8F7F1),
  ),
  'maintenance': _ClassStyle(
    accent: Color(0xFFF97316),
    tint: Color(0xFFFFF2E8),
  ),
  'general maintenance': _ClassStyle(
    accent: Color(0xFF7A5AF8),
    tint: Color(0xFFF4F5FF),
  ),
  'default': _ClassStyle(accent: Color(0xFF667085), tint: Color(0xFFF2F4F7)),
};

// Synonyms / normalization
String _norm(String s) => s.trim().toLowerCase().replaceAll('_', ' ');
const Map<String, String> _synonyms = {
  'utility_interruption': 'utility interruption',
  'power_outage': 'power outage',
  'pest_control': 'pest control',
  'general_maintenance': 'general maintenance',
};

_ClassStyle _styleFor(String raw) {
  final key = _synonyms[_norm(raw)] ?? _norm(raw);
  return _styles[key] ?? _styles['default']!;
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFF005CE7),
        shape: BoxShape.circle,
      ),
    );
  }
}

// Inventory Card -----------------------------------------
class InventoryCard extends StatefulWidget {
  final String itemName;
  final String stockStatus; // e.g., In Stock | Out of Stock | Critical
  final String itemId;
  final String department; // e.g., Plumbing, Electrical, etc.
  final String quantityInStock; // keep as String to match your source
  final VoidCallback? onTap;

  const InventoryCard({
    super.key,
    required this.itemName,
    required this.stockStatus,
    required this.itemId,
    required this.department,
    required this.quantityInStock,
    this.onTap,
  });

  @override
  State<InventoryCard> createState() => _InventoryCardState();
}

class _InventoryCardState extends State<InventoryCard> {
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap:
            widget.onTap ??
            () => debugPrint('InventoryCard tapped: ${widget.itemId}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: radius,
            border: Border.all(width: 1, color: Colors.black.withOpacity(0.08)),
            // ⬇︎ removed boxShadow
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + Stock status tag
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.itemName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF101828),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StockStatusTag(widget.stockStatus),
                ],
              ),

              const SizedBox(height: 6),

              // Item ID (muted)
              Text(
                'ID: ${widget.itemId}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFF4A5154),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 12),

              // Department tag + Quantity pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DepartmentTag(widget.department),
                  _QuantityPill(quantity: widget.quantityInStock),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small, reusable quantity chip for consistent look
class _QuantityPill extends StatelessWidget {
  final String quantity;
  const _QuantityPill({required this.quantity});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 84),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: StadiumBorder(
          side: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2, size: 14, color: Color(0xFF101828)),
          const SizedBox(width: 6),
          Text(
            quantity,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: Color(0xFF101828),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ========= Inventory Request Card =========
class InventoryRequestCard extends StatelessWidget {
  final String itemName;
  final String requestId;
  final String department; // e.g., "Electrical", "Plumbing"
  final String status; // e.g., "Pending", "Approved", "Rejected"
  final String? maintenanceId; // Maintenance ID if this is a maintenance-related request
  final VoidCallback? onTap;

  const InventoryRequestCard({
    super.key,
    required this.itemName,
    required this.requestId,
    required this.department,
    required this.status,
    this.maintenanceId,
    this.onTap,
  });

  // Visual tokens (aligned with InventoryCard)
  static const _textPrimary = Color(0xFF101828);
  static const _textSecondary = Color(0xFF4A5154);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: radius,
            border: Border.all(width: 1, color: Colors.black.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + Status tag (right)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      itemName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusTag(
                    status: status,
                    width: 96,
                  ), // ← calls your StatusTag
                ],
              ),

              const SizedBox(height: 6),

              // ID line
              Text(
                'ID: $requestId',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: _textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
              ),

              if (maintenanceId != null && maintenanceId!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Maintenance: $maintenanceId',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: _textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Department chip (left-aligned, like InventoryCard)
              DepartmentTag(department),
            ],
          ),
        ),
      ),
    );
  }
}

// Notification Message card
class NotificationMessageCard extends StatelessWidget {
  const NotificationMessageCard({
    super.key,
    required this.title,
    required this.message,
    required this.timeLabel,
    this.isUnread = false,
    this.onTap,
    this.leading,
    this.borderColor = const Color(0xFFE5E7E8),
    this.unreadTint = const Color(0xFFF7F9FF),
    this.titleColor = Colors.black,
    this.subtitleColor = const Color(0xFF515978),
    this.radius = 12,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 16,
    ),
    this.maxMessageLines = 3,
    this.showUnreadDot = true,
  });

  final String title;
  final String message;
  final String timeLabel;
  final bool isUnread;
  final VoidCallback? onTap;
  final Widget? leading;

  final Color borderColor;
  final Color unreadTint;
  final Color titleColor;
  final Color subtitleColor;

  final double radius;
  final EdgeInsets contentPadding;
  final int maxMessageLines;
  final bool showUnreadDot;

  @override
  Widget build(BuildContext context) {
    final cardBg = isUnread ? unreadTint : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          decoration: ShapeDecoration(
            color: cardBg,
            shape: RoundedRectangleBorder(
              side: BorderSide(width: 1, color: borderColor),
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
          padding: contentPadding,
          child: Row(
            // 🔧 DO NOT USE stretch in a ListView/Sliver context
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                // Keep a finite size; never use double.infinity here
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: leading!,
                ),
              ],
              // Text column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Title + Time (+ optional unread dot)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 16,
                              fontFamily: 'Inter',
                              fontWeight:
                                  isUnread ? FontWeight.w700 : FontWeight.w600,
                              height: 1.3,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeLabel,
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 12.5,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                                letterSpacing: 0.1,
                              ),
                            ),
                            if (isUnread && showUnreadDot) ...[
                              const SizedBox(width: 8),
                              const _UnreadDot(),
                            ],
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Message
                    Text(
                      message,
                      maxLines: maxMessageLines,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==== REPAIR CARD =====================================================
class RepairCard extends StatelessWidget {
  // Basic Information
  final String id;
  final DateTime createdAt;
  final DateTime? updatedAt; // mirrors createdAt if null; not shown
  final String requestTypeTag; // "Work Order"
  final String? departmentTag;
  final String?
  resolutionType; // job_service, work_permit, rejected (shown as update on requestType)
  final String? priorityTag; // High | Medium | Low
  final String
  statusTag; // Pending | Scheduled | Assigned | In Progress | On Hold | Done

  // Details
  final String title;
  final String unitId;
  final String? location; // For job services and other requests

  // Staff
  final String? assignedStaff;
  final String? staffDepartment;
  final String? staffPhotoUrl;

  // Actions
  final VoidCallback? onTap;
  final VoidCallback? onChatTap;

  const RepairCard({
    super.key,
    required this.id,
    required this.createdAt,
    this.updatedAt,
    this.requestTypeTag = 'Work Order',
    this.resolutionType,
    this.departmentTag,
    this.priorityTag,
    required this.statusTag,
    required this.title,
    required this.unitId,
    this.location,
    this.assignedStaff,
    this.staffDepartment,
    this.staffPhotoUrl,
    this.onTap,
    this.onChatTap,
  });

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFFFFFFFF);
    const border = Color(0xFFDDDEE0);
    const titleCol = Color(0xFF101828);
    const sub1Color = Color(0xFF4A5154);
    const sub2Color = Color(0xFF667085);

    // Precompute any strings/labels used in children lists
    final createdLabel = _formatCreatedAt(
      createdAt,
    ); // uses UiDateUtils.shortDate
    final requestTypeLabel = _requestTypeLabel();

    // ---- Build assignee DATA (not widgets) so we can compact/collapse cleanly ----
    final assignees = <_AssigneeData>[];

    if ((assignedStaff ?? '').trim().isNotEmpty) {
      assignees.add(
        _AssigneeData(
          name: assignedStaff!.trim(),
          department: staffDepartment?.trim(),
          photoUrl:
              (staffPhotoUrl ?? '').trim().isNotEmpty
                  ? staffPhotoUrl!.trim()
                  : null,
          requestTypeTag: requestTypeTag.trim(),
        ),
      );
    }

    // ---- Left cluster (compact, single-line) ----
    Widget leftCluster;
    if (assignees.isNotEmpty) {
      final extraCount = assignees.length - 1;
      leftCluster = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: _AssigneeLine(
              name: assignees.first.name,
              department: assignees.first.department,
              photoUrl: assignees.first.photoUrl,
              dense: true,
              showName: false, // Don't show name text, only avatar
            ),
          ),
          if (extraCount > 0) ...[
            const SizedBox(width: 6),
            _MoreChip(count: extraCount),
          ],
        ],
      );
    } else {
      leftCluster = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (departmentTag?.trim().isNotEmpty ?? false) ...[
            Flexible(
              child: _EllipsizedTag(
                child: DepartmentTag(departmentTag!.trim()),
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (requestTypeTag.trim().isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: RequestTypeTag(
                requestTypeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                displayCasing: DisplayCasing.title,
              ),
            ),
        ],
      );
    }

    final concernSlipId = resolutionType == 'concern_slip' ? id : null;
    final jobServiceId = resolutionType == 'job_service' ? id : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: ShapeDecoration(
            color: cardBg,
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: border),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + tags (top row)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: titleCol,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (priorityTag != null &&
                            priorityTag!.trim().isNotEmpty)
                          PriorityTag(priority: priorityTag!.trim()),
                        StatusTag(status: statusTag),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Request ID
                Row(
                  children: [
                    const Icon(Icons.tag, size: 14, color: sub1Color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: sub1Color,
                          fontSize: 13,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // Unit or Location (optional)
                if (unitId.trim().isNotEmpty ||
                    (location?.trim().isNotEmpty ?? false))
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: sub2Color,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          (location?.trim().isNotEmpty ?? false)
                              ? location!.trim()
                              : unitId.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: sub2Color,
                            fontSize: 13,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 2),

                // Date (createdAt only) — short form like "Aug 23"
                if (createdLabel.isNotEmpty)
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: sub2Color,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          createdLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: sub2Color,
                            fontSize: 13,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE6E7EA)),
                const SizedBox(height: 12),

                // Footer: assignees (compact) | date | chat — single line, no scroll
                // Chat only available for "assigned" and "in progress" statuses
                Row(
                  children: [
                    leftCluster,
                    const Spacer(),
                    if (_shouldShowChat())
                      IconPill(
                        icon: Icons.chat_bubble_outline,
                        onTap: onChatTap,
                        concernSlipId: concernSlipId,
                        jobServiceId: jobServiceId,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Helpers ----------------------------------------------------------------

  // Check if chat should be shown (only for assigned, in progress, on hold, and to inspect statuses)
  bool _shouldShowChat() {
    if (onChatTap == null) return false;

    // Check if chat should be shown (only for assigned, in progress, on hold, and to inspect statuses)
    // The status check is sufficient to determine if chat should be available

    // Allow chat for these statuses
    final status = statusTag.toLowerCase().trim();
    return status == 'assigned' ||
        status == 'in progress' ||
        status == 'on hold' ||
        status == 'to inspect' ||
        status == 'inspected' ||
        status == 'to be inspect' ||
        status == 'sent to client' ||
        status == 'sent to tenant' ||
        status == 'sent' ||
        status == 'completed';
  }

  // Returns: "Work Order • ..." (kept as-is; only date logic changed per request)
  String _requestTypeLabel() {
    final res = (resolutionType ?? '').trim();
    if (res.isEmpty) return requestTypeTag;

    final pretty = switch (res.toLowerCase()) {
      'concern_slip' => 'Work Permit',
      'job_service' => 'Job Service',
      'rejected' => 'Rejected',
      _ => res,
    };

    return '$requestTypeTag • $pretty';
  }

  /// Accepts DateTime or String; outputs short date like "Aug 23"
  String _formatCreatedAt(Object value) {
    DateTime dt;
    if (value is DateTime) {
      dt = value;
    } else if (value is String && value.trim().isNotEmpty) {
      dt = UiDateUtils.parse(value.trim()); // unified parser
    } else {
      return '';
    }
    return UiDateUtils.shortDate(dt); // shortDate only
  }
}

// ==== MAINTENANCE CARD =====================================================
class MaintenanceCard extends StatelessWidget {
  // Basic Information
  final String id;
  final DateTime createdAt;
  final DateTime? updatedAt; // mirrors createdAt if null; not shown
  final String requestTypeTag; // "Maintenance"
  final String? departmentTag;
  final String? priority; // High | Medium | Low
  final String
  statusTag; // Pending | Scheduled | Assigned | In Progress | On Hold | Done

  // Details
  final String title;
  final String location;

  // Staff
  final String? assignedStaff;
  final String? staffDepartment;
  final String? staffPhotoUrl;

  // Actions
  final VoidCallback? onTap;
  final VoidCallback? onChatTap;

  const MaintenanceCard({
    super.key,
    required this.id,
    required this.createdAt,
    this.updatedAt,
    required this.requestTypeTag,
    this.departmentTag,
    this.priority,
    required this.statusTag,
    required this.title,
    required this.location,
    this.assignedStaff,
    this.staffDepartment,
    this.staffPhotoUrl,
    this.onTap,
    this.onChatTap,
  });

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFFFFFFFF);
    const border = Color(0xFFDDDEE0);
    const titleCol = Color(0xFF101828);
    const sub1Color = Color(0xFF4A5154);
    const sub2Color = Color(0xFF667085);

    final createdLabel = _formatCreatedAt(
      createdAt,
    ); // uses UiDateUtils.shortDate

    // ---- Build assignee DATA (not widgets) ----
    final assignees = <_AssigneeData>[];
    if ((assignedStaff ?? '').trim().isNotEmpty) {
      assignees.add(
        _AssigneeData(
          name: assignedStaff!.trim(),
          department: staffDepartment?.trim(),
          photoUrl:
              (staffPhotoUrl ?? '').trim().isNotEmpty
                  ? staffPhotoUrl!.trim()
                  : null,
          requestTypeTag: requestTypeTag.trim(),
        ),
      );
    }

    // ---- Left cluster ----
    Widget leftCluster;
    if (assignees.isNotEmpty) {
      final extraCount = assignees.length - 1;
      leftCluster = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: _AssigneeLine(
              name: assignees.first.name,
              department: assignees.first.department, // Show department tag
              photoUrl: assignees.first.photoUrl,
              dense: true,
              showName: false, // Don't show name text, only avatar + department
            ),
          ),
          if (extraCount > 0) ...[
            const SizedBox(width: 6),
            _MoreChip(count: extraCount),
          ],
        ],
      );
    } else {
      // No assignee - show empty or minimal info
      leftCluster = const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: ShapeDecoration(
            color: cardBg,
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: border),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + tags
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: titleCol,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (priority != null && priority!.trim().isNotEmpty)
                          PriorityTag(priority: priority!.trim()),
                        StatusTag(status: statusTag),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Request ID
                Row(
                  children: [
                    const Icon(Icons.tag, size: 14, color: sub1Color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: sub1Color,
                          fontSize: 13,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // Location
                if (location.trim().isNotEmpty)
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: sub2Color,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          location.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: sub2Color,
                            fontSize: 13,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 2),

                // Date (shortDate only)
                if (createdLabel.isNotEmpty)
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: sub2Color,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          createdLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: sub2Color,
                            fontSize: 13,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE6E7EA)),
                const SizedBox(height: 12),

                // Footer (no chat button for maintenance cards)
                Row(children: [leftCluster, const Spacer()]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Accepts DateTime or String; outputs short date like "Aug 23"
  String _formatCreatedAt(Object value) {
    DateTime dt;
    if (value is DateTime) {
      dt = value;
    } else if (value is String && value.trim().isNotEmpty) {
      dt = UiDateUtils.parse(value.trim());
    } else {
      return '';
    }
    return UiDateUtils.shortDate(dt);
  }
}

// Ui Helpers

// ==== AVATAR (image -> initials -> icon fallback) ============================

/// Always shows an avatar when `show` is true.
/// If `image` is null/empty, it renders a fallback (initials or person icon).
class AvatarOrFallback extends StatelessWidget {
  final bool show;
  final String? image; // asset path or network URL
  final String? labelForInitials; // e.g. requester/tenant name or title

  const AvatarOrFallback({
    super.key,
    required this.show,
    this.image,
    this.labelForInitials,
  });

  String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.last : '';
    final a = first.isNotEmpty ? first[0] : '';
    final b =
        last.isNotEmpty
            ? last[0]
            : (parts.length == 1 && first.length > 1 ? first[1] : '');
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();

    final hasImage = image != null && image!.trim().isNotEmpty;

    if (hasImage) {
      final isNetwork =
          image!.startsWith('http://') || image!.startsWith('https://');
      return CircleAvatar(
        radius: 14,
        backgroundColor: Colors.transparent,
        backgroundImage:
            isNetwork
                ? NetworkImage(image!)
                : AssetImage(image!) as ImageProvider,
      );
    }

    if (labelForInitials != null && labelForInitials!.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: const Color(0xFFE5E7EB),
        child: Text(
          _initials(labelForInitials!),
          style: const TextStyle(
            color: Color(0xFF344054),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return const CircleAvatar(
      radius: 14,
      backgroundColor: Color(0xFFE5E7EB),
      child: Icon(Icons.person, size: 16, color: Color(0xFF667085)),
    );
  }
}

/// Assignee line: circle avatar (photo or initials) + (optional) DepartmentTag + (optional) requestTypeTagTag
class _AssigneeLine extends StatelessWidget {
  final String name;
  final String? department;
  final String? photoUrl;
  final bool dense;
  final bool showName; // Whether to show the name text

  const _AssigneeLine({
    required this.name,
    this.department,
    this.photoUrl,
    this.dense = false,
    this.showName = true,
  });

  @override
  Widget build(BuildContext context) {
    final double avatarSize = dense ? 34 : 34;

    final widgets = <Widget>[_buildAvatar(photoUrl, name, size: avatarSize)];

    // Only add name text if showName is true
    if (showName) {
      widgets.add(const SizedBox(width: 8));
      widgets.add(
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475467),
            ),
          ),
        ),
      );
    }

    if ((department ?? '').trim().isNotEmpty) {
      widgets.add(const SizedBox(width: 6));
      widgets.add(_EllipsizedTag(child: DepartmentTag(department!.trim())));
    }

    return Row(mainAxisSize: MainAxisSize.min, children: widgets);
  }

  // ---- Avatar helpers ----
  static Widget _buildAvatar(String? url, String name, {double size = 34}) {
    final initials = _initials(name);
    if (url == null || url.trim().isEmpty) {
      return _fallbackCircle(initials, size);
    }

    final u = url.trim();
    Widget image;

    if (u.startsWith('http://') || u.startsWith('https://')) {
      image = Image.network(
        u,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackCircle(initials, size),
      );
    } else if (u.startsWith('assets/')) {
      image = Image.asset(
        u,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackCircle(initials, size),
      );
    } else {
      return _fallbackCircle(initials, size);
    }

    return ClipOval(child: image);
  }

  static Widget _fallbackCircle(String initials, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFD9D9D9),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'Inter',
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36, // scale with avatar
        ),
      ),
    );
  }

  static String _initials(String fullName) {
    final parts =
        fullName
            .trim()
            .split(RegExp(r'\s+'))
            .where((p) => p.isNotEmpty)
            .toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

// --- Small helpers -----------------------------------------------------------

class _AssigneeData {
  final String name;
  final String? department;
  final String? photoUrl;
  final String? requestTypeTag;
  _AssigneeData({
    required this.name,
    this.department,
    this.photoUrl,
    this.requestTypeTag,
  });
}

class _MoreChip extends StatelessWidget {
  final int count;
  const _MoreChip({required this.count});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: ShapeDecoration(
        color: const Color(0xFFEFF1F5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(
        '+$count',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475467),
        ),
      ),
    );
  }
}

/// Clips any tag widget on the right if space is tight (keeps single line).
class _EllipsizedTag extends StatelessWidget {
  final Widget child;
  const _EllipsizedTag({required this.child});
  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}

// UI helper ---------------------

// Avatar
class Avatar extends StatelessWidget {
  final String? avatarUrl;
  const Avatar({super.key, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFD9D9D9);

    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: bg,
        backgroundImage: NetworkImage(avatarUrl!),
      );
    }

    return const CircleAvatar(
      radius: 14,
      backgroundColor: bg,
      child: Icon(Icons.person, size: 14, color: Colors.white),
    );
  }
}

/// Text pill with an icon (for date)
class Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final double iconSize;

  const Pill({
    super.key,
    required this.icon,
    required this.label,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: const Color(0xFF101828)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF101828),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon-only small pill (for chat)
class IconPill extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;

  final String? concernSlipId;
  final String? maintenanceId;
  final String? jobServiceId;

  const IconPill({
    super.key,
    required this.icon,
    this.onTap,
    this.concernSlipId,
    this.maintenanceId,
    this.jobServiceId,
  });

  @override
  State<IconPill> createState() => _IconPillState();
}

class _IconPillState extends State<IconPill> {
  late Stream<int> _unreadStream;

  @override
  void initState() {
    super.initState();
    _unreadStream = FirebaseChatService().getUnreadCountStreamForReference(
      concernSlipId: widget.concernSlipId,
      maintenanceId: widget.maintenanceId,
      jobServiceId: widget.jobServiceId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    return StreamBuilder<int>(
      stream: _unreadStream,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Stack(
          children: [
            InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                width: 40,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(enabled ? 1 : 0.7),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: Icon(
                  widget.icon,
                  size: 18,
                  color:
                      enabled
                          ? const Color(0xFF101828)
                          : const Color(0xFF98A2B3),
                ),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
