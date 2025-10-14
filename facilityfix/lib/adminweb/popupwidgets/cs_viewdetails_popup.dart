import 'package:flutter/material.dart';

class ConcernSlipDetailDialog extends StatelessWidget {
  final Map<String, dynamic> task;

  const ConcernSlipDetailDialog({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Section
            _buildHeader(context),

            // Content Section
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      task['title'] ?? 'No Title',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Details Grid
                    _buildDetailsGrid(),
                    const SizedBox(height: 16),

                    Divider(color: Colors.grey[300], thickness: 1, height: 1),
                    const SizedBox(height: 16),

                    // Work Description Section
                    _buildWorkDescription(),
                    
                    // Staff Assessment Section (if available)
                    if (task['rawData']?['staff_assessment'] != null || 
                        task['rawData']?['staff_recommendation'] != null) ...[
                      const SizedBox(height: 32),
                      Divider(color: Colors.grey[300], thickness: 1, height: 1),
                      const SizedBox(height: 32),
                      _buildStaffAssessmentSection(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 32, right: 24, top: 24, bottom: 16),
      child: Row(
        children: [
          const Text(
            'Concern Slip',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.grey, size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsGrid() {
    return Column(
      children: [
        // First Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildDetailItem('REFERENCE NUMBER', task['id'] ?? 'N/A'),
            ),
            const SizedBox(width: 48),
            Expanded(
              child: _buildDetailItem(
                'DATE REQUESTED',
                task['dateRequested'] ?? 'N/A',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(color: Colors.grey[300], thickness: 1, height: 1),
        const SizedBox(height: 16),

        // Priority and Status Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PRIORITY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPriorityChip(task['priority'] ?? 'Low'),
                ],
              ),
            ),
            const SizedBox(width: 48),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STATUS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildStatusChip(task['status'] ?? 'Pending'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Resolution Type Row (if set)
        if (task['rawData']?['resolution_type'] != null) ...[
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RESOLUTION TYPE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildResolutionTypeChip(
                      task['rawData']['resolution_type'],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
        const SizedBox(height: 32),

        // Second Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildDetailItem('REQUESTED BY', 'Erika De Guzman'),
            ),
            const SizedBox(width: 48),
            Expanded(
              child: _buildDetailItem(
                'DEPARTMENT',
                task['department'] ?? 'N/A',
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Third Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildDetailItem(
                'BLDG & UNIT NO.',
                _formatBuildingUnit(task['buildingUnit'] ?? 'N/A'),
              ),
            ),
            const SizedBox(width: 48),
            Expanded(
              child: _buildDetailItem(
                'SCHEDULE AVAILABILITY',
                task['dateRequested'] ?? 'N/A',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Work Description',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          task['description'] ??
              'The kitchen faucet has been continuously leaking since last night. Water is dripping even when the handle is fully closed, which may lead to water waste and higher utility bills. Please inspect and repair as soon as possible.',
          style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildStaffAssessmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Staff Assessment',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 24),
        
        // Assessment and Recommendation in a row layout
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Staff Assessment
            if (task['rawData']?['staff_assessment'] != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ASSESSMENT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Text(
                        task['rawData']['staff_assessment'],
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Spacing between assessment and recommendation
            if (task['rawData']?['staff_assessment'] != null && 
                task['rawData']?['staff_recommendation'] != null)
              const SizedBox(width: 24),
            
            // Staff Recommendation
            if (task['rawData']?['staff_recommendation'] != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RECOMMENDATION',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Text(
                        task['rawData']['staff_recommendation'],
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriorityChip(String priority) {
    Color bgColor;
    Color textColor;
    switch (priority.toLowerCase()) {
      case 'high':
        bgColor = const Color(0xFFFFEBEE);
        textColor = const Color(0xFFD32F2F);
        break;
      case 'medium':
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFFF8F00);
        break;
      case 'low':
        bgColor = const Color(0xFFE8F5E8);
        textColor = const Color(0xFF2E7D32);
        break;
      default:
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFFF8F00);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$priority Priority',
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;
    switch (status.toLowerCase()) {
      case 'in progress':
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFFF8F00);
        break;
      case 'pending':
        bgColor = const Color(0xFFFFEBEE);
        textColor = const Color(0xFFD32F2F);
        break;
      case 'completed':
        bgColor = const Color(0xFFE8F5E8);
        textColor = const Color(0xFF2E7D32);
        break;
      case 'cancelled':
        bgColor = const Color(0xFFF5F5F5);
        textColor = const Color(0xFF616161);
        break;
      default:
        bgColor = const Color(0xFFE8F4FD);
        textColor = const Color(0xFF1976D2);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status == 'pending' ? 'Pending Review' : status,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildResolutionTypeChip(String resolutionType) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String displayText;
    
    switch (resolutionType.toLowerCase()) {
      case 'job_service':
        bgColor = const Color(0xFFE3F2FD);
        textColor = const Color(0xFF1976D2);
        icon = Icons.engineering;
        displayText = 'Job Service';
        break;
      case 'work_order':
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFFF8F00);
        icon = Icons.assignment;
        displayText = 'Work Order';
        break;
      default:
        bgColor = Colors.grey[100]!;
        textColor = Colors.grey[700]!;
        icon = Icons.help_outline;
        displayText = resolutionType;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            displayText,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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

  // Static method to show the dialog
  static void show(BuildContext context, Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConcernSlipDetailDialog(task: task);
      },
    );
  }
}
