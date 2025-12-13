import 'package:flutter/material.dart';
import '../../popupwidgets/webforgotpassword_popup.dart';
import '../../services/api_service_web.dart';
import 'package:facilityfix/services/profile_service.dart';

class UserProfileDialog extends StatefulWidget {
  final Map<String, dynamic> user;

  const UserProfileDialog({super.key, required this.user});

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();

  // Static method to show the dialog
  static void show(BuildContext context, Map<String, dynamic> user) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return UserProfileDialog(user: user);
      },
    );
  }
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  bool isEditMode = false;
  final ApiService _apiService = ApiService();

  // Controllers for editable fields
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController departmentController; // Single department only

  // Selected department (single selection)
  String selectedDepartment = '';

  // Available department options
  final List<String> availableDepartments = [
    'Carpentry',
    'Plumbing',
    'Electrical',
    'Masonry',
  ];

  bool isFirstNameValid = true;
  bool isLastNameValid = true;
  bool isEmailValid = true;
  bool isPhoneValid = true;
  bool isDepartmentValid = true;

  bool _validateInputs() {
    setState(() {
      isFirstNameValid = firstNameController.text.trim().isNotEmpty;
      isLastNameValid = lastNameController.text.trim().isNotEmpty;
      isEmailValid = RegExp(
        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
      ).hasMatch(emailController.text.trim());
      isPhoneValid = phoneController.text.trim().isNotEmpty;
      isDepartmentValid = true; // Department is optional
    });

    return isFirstNameValid && isLastNameValid && isEmailValid && isPhoneValid;
  }

  @override
  void initState() {
    super.initState();
    final rawUser = widget.user['_raw'] ?? widget.user;

    // Initialize controllers with proper fallback handling
    firstNameController = TextEditingController(
      text: rawUser['first_name'] ?? _extractFirstName(),
    );
    lastNameController = TextEditingController(
      text: rawUser['last_name'] ?? _extractLastName(),
    );
    emailController = TextEditingController(
      text: rawUser['email'] ?? widget.user['email'] ?? '',
    );
    phoneController = TextEditingController(
      text: rawUser['phone_number'] ?? rawUser['phone'] ?? '',
    );
    departmentController = TextEditingController(
      text: rawUser['department'] ?? widget.user['department'] ?? '',
    );

    // Initialize selected departments from user data with better fallback
    _initializeDepartments();
  }

  String _extractFirstName() {
    final fullName = widget.user['name']?.toString() ?? '';
    if (fullName.isNotEmpty) {
      final nameParts = fullName.split(' ');
      return nameParts.isNotEmpty ? nameParts[0] : '';
    }
    return '';
  }

  String _extractLastName() {
    final fullName = widget.user['name']?.toString() ?? '';
    if (fullName.isNotEmpty) {
      final nameParts = fullName.split(' ');
      return nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    }
    return '';
  }

  void _initializeDepartments() {
    final rawUser = widget.user['_raw'] ?? widget.user;

    // Get single department from various sources
    String department =
        rawUser['department'] ??
        rawUser['staff_department'] ??
        widget.user['department'] ??
        widget.user['staff_department'] ??
        '';

    // If no single department, try to get first from departments list
    if (department.isEmpty) {
      final departments =
          rawUser['departments'] ??
          rawUser['staff_departments'] ??
          widget.user['departments'] ??
          widget.user['staff_departments'];

      if (departments is List && departments.isNotEmpty) {
        department = departments[0].toString();
      } else if (departments is String && departments.isNotEmpty) {
        department = departments;
      }
    }

    // Validate that the department exists in our available options
    // If not, reset to empty string
    if (department.isNotEmpty && !availableDepartments.contains(department)) {
      print(
        '[UserProfileDialog] Department "$department" not found in available options, resetting to empty',
      );
      department = '';
    }

    selectedDepartment = department;
    departmentController.text = department;
  }

  @override
  void dispose() {
    // Dispose controllers to prevent memory leaks
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    departmentController.dispose();
    super.dispose();
  }

  String _getUserIdLabel() {
    final role = widget.user['role'] ?? 'Tenant';
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Admin ID';
      case 'staff':
        return 'Staff ID';
      case 'tenant':
      default:
        return 'Tenant ID';
    }
  }

  String _getUserId() {
    return widget.user['id'] ?? widget.user['_raw']?['user_id'] ?? 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile Image Section
                    _buildProfileImage(),
                    const SizedBox(height: 24),

                    // Name Section
                    _buildNameSection(),
                    const SizedBox(height: 8),

                    _buildUserIdSection(),
                    const SizedBox(height: 32),

                    // Personal Details Section
                    _buildPersonalDetailsSection(),
                  ],
                ),
              ),
            ),

            // Footer Section
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  // Header with title, edit toggle and close button
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 32, right: 24, top: 24, bottom: 16),
      child: Row(
        children: [
          const Text(
            'User Profile',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          if (!isEditMode) const SizedBox(width: 8),
          // Edit toggle button
          IconButton(
            onPressed: () => _toggleEditMode(),
            icon: Icon(
              isEditMode ? Icons.save : Icons.edit,
              color: isEditMode ? Colors.green[600] : Colors.blue[600],
              size: 24,
            ),
            tooltip: isEditMode ? 'Save Changes' : 'Edit Profile',
          ),
          const SizedBox(width: 8),
          // Close button
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

  // Profile image with camera icon for editing
  Widget _buildProfileImage() {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue[200]!, width: 3),
          ),
          child: CircleAvatar(
            radius: 58,
            backgroundColor: Colors.grey[100],
            backgroundImage:
                widget.user['profileImage'] != null
                    ? NetworkImage(widget.user['profileImage'])
                    : null,
            child:
                widget.user['profileImage'] == null
                    ? Icon(Icons.person, size: 60, color: Colors.grey[400])
                    : null,
          ),
        ),
        if (isEditMode)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.blue[600],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: IconButton(
                onPressed: () => _changeProfileImage(),
                icon: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 18,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNameSection() {
    return isEditMode
        ? Column(
          children: [
            SizedBox(
              width: 300,
              child: TextFormField(
                controller: firstNameController,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'First Name',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  errorText: !isFirstNameValid ? 'Required' : null,
                ),
                onChanged: (val) {
                  setState(() {
                    isFirstNameValid = val.trim().isNotEmpty;
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 300,
              child: TextFormField(
                controller: lastNameController,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Last Name',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  errorText: !isLastNameValid ? 'Required' : null,
                ),
                onChanged: (val) {
                  setState(() {
                    isLastNameValid = val.trim().isNotEmpty;
                  });
                },
              ),
            ),
          ],
        )
        : Text(
          widget.user['name'] ?? 'No Name',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        );
  }

  Widget _buildUserIdSection() {
    return Text(
      '${_getUserIdLabel()}: ${_getUserId()}',
      style: TextStyle(
        fontSize: 16,
        color: Colors.grey[600],
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildPersonalDetailsSection() {
    final rawUser = widget.user['_raw'] ?? widget.user;
    // Determine role for this user so we can hide department for tenants
    final String role =
        (rawUser['role'] ?? widget.user['role'] ?? 'tenant')
            .toString()
            .toLowerCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title with edit icon
          Row(
            children: [
              const Text(
                'Personal Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (isEditMode)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.edit_note,
                    color: Colors.blue[600],
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Email field
          _buildDetailField(
            'Email',
            emailController,
            rawUser['email'] ?? widget.user['email'] ?? 'Not specified',
            keyboardType: TextInputType.emailAddress,
            isValid: isEmailValid,
            onChanged: (val) {
              setState(() {
                isEmailValid = RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(val);
              });
            },
          ),
          const SizedBox(height: 20),

          // Phone Number field
          _buildDetailField(
            'Phone Number',
            phoneController,
            rawUser['phone_number'] ?? rawUser['phone'] ?? 'Not specified',
            keyboardType: TextInputType.phone,
            isValid: isPhoneValid,
            onChanged: (val) {
              setState(() {
                isPhoneValid = val.trim().isNotEmpty;
              });
            },
          ),
          const SizedBox(height: 20),

          // Department field (single select) - hide for tenants
          if (role != 'tenant') ...[
            _buildDepartmentField(),
            const SizedBox(height: 20),
          ],

          // Role (read-only)
          _buildReadOnlyField('Role', widget.user['role'] ?? 'Tenant'),
          const SizedBox(height: 20),

          // Building ID (if available)
          if ((rawUser['building_id'] != null && rawUser['unit_id'] != null) ||
              rawUser['building_unit'] != null)
            Column(
              children: [
                _buildReadOnlyField(
                  'Building/Unit',
                  ProfileService().formatBuildingUnitDisplay(rawUser).isNotEmpty
                      ? ProfileService().formatBuildingUnitDisplay(rawUser)
                      : 'Not specified',
                ),
                const SizedBox(height: 20),
              ],
            ),

          // Created date (if available)
          if (rawUser['created_at'] != null)
            Column(
              children: [
                _buildReadOnlyField(
                  'Created',
                  _formatDate(rawUser['created_at']),
                ),
                const SizedBox(height: 20),
              ],
            ),

          // Last updated (if available)
          if (rawUser['updated_at'] != null)
            Column(
              children: [
                _buildReadOnlyField(
                  'Last Updated',
                  _formatDate(rawUser['updated_at']),
                ),
                const SizedBox(height: 24),
              ],
            ),

          // Forgot Password link
          _buildForgotPasswordSection(),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Unknown';
    try {
      DateTime date;
      if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        date = dateValue;
      } else {
        return 'Invalid date';
      }

      final local = date.toLocal();
      final datePart =
          '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
      final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final minute = local.minute.toString().padLeft(2, '0');
      final ampm = local.hour >= 12 ? 'PM' : 'AM';
      return '$datePart | ${hour12.toString().padLeft(2, '0')}:$minute $ampm';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _buildDetailField(
    String label,
    TextEditingController controller,
    String displayValue, {
    bool isDate = false,
    TextInputType? keyboardType,
    required bool isValid,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        if (isEditMode)
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: isDate,
            onTap: isDate ? () => _selectDate(controller) : null,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: 'Enter $label',
              border: OutlineInputBorder(
                borderSide: BorderSide(
                  color: isValid ? Colors.grey[300]! : Colors.red,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: isValid ? Colors.grey[300]! : Colors.red,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: isValid ? const Color(0xFF1976D2) : Colors.red,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              suffixIcon:
                  isDate ? const Icon(Icons.calendar_today, size: 20) : null,
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              displayValue,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        if (isEditMode && !isValid)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              "Please enter a valid $label",
              style: TextStyle(fontSize: 12, color: Colors.red[600]),
            ),
          ),
      ],
    );
  }

  Widget _buildDepartmentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Department / Category',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        if (isEditMode)
          DropdownButtonFormField<String>(
            value: selectedDepartment.isEmpty ? '' : selectedDepartment,
            decoration: InputDecoration(
              hintText: 'Select department...',
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF1976D2), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('No department'),
              ),
              ...availableDepartments.map((dept) {
                return DropdownMenuItem<String>(value: dept, child: Text(dept));
              }).toList(),
            ],
            onChanged: (value) {
              setState(() {
                selectedDepartment = value ?? '';
                departmentController.text = selectedDepartment;
              });
            },
          )
        else
          // Display mode
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              selectedDepartment.isEmpty
                  ? 'No department assigned'
                  : selectedDepartment,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // Forgot password section
  Widget _buildForgotPasswordSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.blue[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Password Settings',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _forgotPassword(),
                  child: Text(
                    'Reset password',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[600],
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Footer with action buttons
  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isEditMode) ...[
            // Cancel button (only in edit mode)
            OutlinedButton(
              onPressed: () => _cancelEdit(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey[300]!),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 16),
            // Save button (only in edit mode)
            ElevatedButton(
              onPressed: () => _saveChanges(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                elevation: 0,
              ),
              child: const Text('Save Changes'),
            ),
          ] else ...[
            // Close button (only in view mode)
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                elevation: 0,
              ),
              child: const Text('Close'),
            ),
          ],
        ],
      ),
    );
  }

  // Event handlers and utility methods

  // Toggle between edit and view modes
  void _toggleEditMode() {
    if (isEditMode) {
      _saveChanges();
    } else {
      setState(() {
        isEditMode = true;
      });
    }
  }

  // Cancel editing and revert changes
  void _cancelEdit() {
    final rawUser = widget.user['_raw'] ?? {};
    setState(() {
      isEditMode = false;
      // Reset controllers to original values
      firstNameController.text = rawUser['first_name'] ?? '';
      lastNameController.text = rawUser['last_name'] ?? '';
      emailController.text = rawUser['email'] ?? widget.user['email'] ?? '';
      phoneController.text = rawUser['phone_number'] ?? '';

      // Reset department to original value
      String originalDepartment =
          rawUser['department'] ??
          rawUser['staff_department'] ??
          widget.user['department'] ??
          widget.user['staff_department'] ??
          '';

      // If no single department, try to get first from departments list
      if (originalDepartment.isEmpty) {
        final departments =
            rawUser['departments'] ??
            rawUser['staff_departments'] ??
            widget.user['departments'] ??
            widget.user['staff_departments'];

        if (departments is List && departments.isNotEmpty) {
          originalDepartment = departments[0].toString();
        } else if (departments is String && departments.isNotEmpty) {
          originalDepartment = departments;
        }
      }

      // Validate that the department exists in our available options
      if (originalDepartment.isNotEmpty &&
          !availableDepartments.contains(originalDepartment)) {
        print(
          '[UserProfileDialog] Original department "$originalDepartment" not found in available options, resetting to empty',
        );
        originalDepartment = '';
      }

      selectedDepartment = originalDepartment;
      departmentController.text = originalDepartment;

      // Reset validation flags
      isFirstNameValid = true;
      isLastNameValid = true;
      isEmailValid = true;
      isPhoneValid = true;
      isDepartmentValid = true;
    });
  }

  void _saveChanges() async {
    // Validate first
    if (!_validateInputs()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors before saving'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final userId = widget.user['id'];

      Map<String, dynamic> updateData = {
        'first_name': firstNameController.text.trim(),
        'last_name': lastNameController.text.trim(),
        'email': emailController.text.trim(),
        'phone_number': phoneController.text.trim(),
        // Note: department is added below only for non-tenant roles
      };

      // Add role-specific department fields for backward compatibility
      final role = widget.user['role']?.toString().toLowerCase() ?? 'tenant';
      // Only include department-related fields for non-tenant roles
      if (role != 'tenant') {
        // Include a simple department field for back-compat
        updateData['department'] = selectedDepartment;

        if (role == 'staff') {
          updateData['staff_department'] = selectedDepartment;
          // Also set departments array for backward compatibility
          updateData['staff_departments'] =
              selectedDepartment.isNotEmpty ? [selectedDepartment] : [];
          updateData['departments'] =
              selectedDepartment.isNotEmpty ? [selectedDepartment] : [];
        } else {
          // For other non-tenant roles (e.g., admin), set departments array
          updateData['departments'] =
              selectedDepartment.isNotEmpty ? [selectedDepartment] : [];
        }
      }

      print('[UserProfileDialog] Updating user $userId');
      print('[UserProfileDialog] Update data: $updateData');
      print('[UserProfileDialog] Selected department: $selectedDepartment');

      final response = await _apiService.updateUser(userId, updateData);
      print('[UserProfileDialog] Update response: $response');

      // Update local user data to reflect changes immediately
      final newName =
          '${firstNameController.text.trim()} ${lastNameController.text.trim()}';

      widget.user['name'] = newName;
      widget.user['email'] = emailController.text.trim();
      widget.user['department'] = selectedDepartment;
      widget.user['departments'] =
          selectedDepartment.isNotEmpty ? [selectedDepartment] : [];

      if (widget.user['_raw'] != null) {
        widget.user['_raw']['first_name'] = firstNameController.text.trim();
        widget.user['_raw']['last_name'] = lastNameController.text.trim();
        widget.user['_raw']['email'] = emailController.text.trim();
        widget.user['_raw']['phone_number'] = phoneController.text.trim();
        widget.user['_raw']['department'] = selectedDepartment;
        widget.user['_raw']['departments'] =
            selectedDepartment.isNotEmpty ? [selectedDepartment] : [];

        if (role == 'staff') {
          widget.user['_raw']['staff_department'] = selectedDepartment;
          widget.user['_raw']['staff_departments'] =
              selectedDepartment.isNotEmpty ? [selectedDepartment] : [];
        }
      }

      setState(() {
        isEditMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Close dialog and pass back updated user data
        Navigator.of(context).pop(widget.user);
      }
    } catch (e) {
      print('[v0] Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Date picker for birth date
  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      controller.text =
          "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
    }
  }

  // Change profile image
  void _changeProfileImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile image change coming soon...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // Forgot password handler
  void _forgotPassword() {
    ForgotPasswordDialog.show(context);
  }
}
