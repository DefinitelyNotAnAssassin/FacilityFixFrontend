import 'package:facilityfix/widgets/forms.dart';
import 'package:flutter/material.dart';

class LogoutButton extends StatelessWidget {
  final VoidCallback onPressed;

  const LogoutButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    const Color brand = Color(0xFF005CE7); // keeps your existing blue
    final Color bg = brand.withOpacity(0.06);
    final BorderRadius radius = BorderRadius.circular(12);

    return Semantics(
      button: true,
      label: 'Logout',
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: Border.all(color: brand, width: 1),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            splashColor: brand.withOpacity(0.12),
            highlightColor: Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: brand, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Logout',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.2,
                    letterSpacing: 0.1,
                    color: Color(0xFF005CE7),
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

/// Password field with toggle visibility
class PasswordInputField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool isRequired;
  final bool readOnly;
  final Widget? prefixIcon;

  const PasswordInputField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText = '',
    this.isRequired = false,
    this.readOnly = false,
    this.prefixIcon,
  });

  @override
  State<PasswordInputField> createState() => _PasswordInputFieldState();
}

class _PasswordInputFieldState extends State<PasswordInputField> {
  bool _obscureText = true;

  void _toggleVisibility() {
    setState(() => _obscureText = !_obscureText);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      readOnly: widget.readOnly,
      obscureText: _obscureText,
      decoration: InputDecoration(
        labelText: widget.label + (widget.isRequired ? ' *' : ''),
        hintText: widget.hintText,
        prefixIcon: widget.prefixIcon,
        suffixIcon: GestureDetector(
          onTap: _toggleVisibility,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
          ),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Settings row item with icon and chevron
class SettingsOption extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  const SettingsOption({
    super.key,
    required this.text,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: const Color(0xFF4B5563)),
              ),
              const SizedBox(width: 10), // ← spacing fixed to 16 px
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card section with optional trailing widget (e.g., edit icon)
class SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final Widget? trailing;

  const SectionCard({
    super.key,
    this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: const Color(0xFFF9FAFB),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null || trailing != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Avatar widget with gradient border and camera badge
class ProfileInfoWidget extends StatelessWidget {
  final ImageProvider? profileImage;
  final String fullName;
  final String staffId;
  final VoidCallback onTap;

  const ProfileInfoWidget({
    super.key,
    this.profileImage,
    required this.fullName,
    required this.staffId,
    required this.onTap,
  });

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final initials = _getInitials(fullName);

    return Row(
      children: [
        // Avatar with camera badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                ),
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                backgroundImage: profileImage,
                child:
                    profileImage == null
                        ? Text(
                          initials,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        )
                        : null,
              ),
            ),
            Positioned(
              bottom: -2,
              right: -2,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                staffId,
                style: textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Display-only row for Personal Details
class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: theme.bodyMedium?.copyWith(
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value.isEmpty ? '—' : value, style: theme.bodyMedium),
        ),
      ],
    );
  }
}

// Date helpers
String formatPrettyFromString(String value) {
  final dt = tryParseYMD(value) ?? tryParsePretty(value);
  return dt != null ? formatPretty(dt) : value;
}

String formatPretty(DateTime dt) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

DateTime? tryParseYMD(String s) {
  try {
    final parts = s.split('-');
    if (parts.length != 3) return null;
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    return DateTime(y, m, d);
  } catch (_) {
    return null;
  }
}

DateTime? tryParsePretty(String s) {
  try {
    final match = RegExp(
      r'^\s*([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})\s*$',
    ).firstMatch(s);
    if (match == null) return null;
    const months = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };
    final mName = match.group(1)!.toLowerCase();
    final d = int.parse(match.group(2)!);
    final y = int.parse(match.group(3)!);
    final m = months[mName];
    if (m == null) return null;
    return DateTime(y, m, d);
  } catch (_) {
    return null;
  }
}

// 1) Role enum
enum UserRole { tenant, staff, admin }

// 2) Edit result model
class EditedProfileData {
  final String fullName;
  final String birthDate;
  final String userEmail;
  final String contactNumber;
  final String? buildingUnitNo; // tenant only
  final String? staffDepartment; // staff only

  const EditedProfileData({
    required this.fullName,
    required this.birthDate,
    required this.userEmail,
    required this.contactNumber,
    this.buildingUnitNo,
    this.staffDepartment,
  });
}

// 3) Edit Modal (enum-based)
class EditProfileModal extends StatefulWidget {
  final String initialFullName;
  final String initialBirthDate;
  final String initialUserEmail;
  final String initialContactNumber;

  // Optional seeds (used depending on role)
  final String? initialBuildingUnitNo; // used when role == tenant
  final String? initialStaffDepartment; // used when role == staff

  final UserRole role;

  const EditProfileModal({
    super.key,
    required this.initialFullName,
    required this.initialBirthDate,
    required this.initialUserEmail,
    required this.initialContactNumber,
    this.initialBuildingUnitNo,
    this.initialStaffDepartment,
    required this.role,
  });

  @override
  State<EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends State<EditProfileModal> {
  final _formKey = GlobalKey<FormState>();

  // Core controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _birthCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;

  // Tenant-only
  TextEditingController? _unitCtrl;
  String? _unitErr;

  // Staff-only (with "Others")
  static const List<String> _deptOptions = <String>[
    'Plumbing',
    'Maintenance',
    'Electrical',
    'Masonry',
    'Others',
  ];
  String? _deptValue;
  TextEditingController? _deptOtherCtrl;

  bool get _isTenant => widget.role == UserRole.tenant;
  bool get _isStaff => widget.role == UserRole.staff;

  @override
  void initState() {
    super.initState();

    _nameCtrl = TextEditingController(text: widget.initialFullName);
    _birthCtrl = TextEditingController(
      text: formatPrettyFromString(widget.initialBirthDate),
    );
    _emailCtrl = TextEditingController(text: widget.initialUserEmail);
    _phoneCtrl = TextEditingController(text: widget.initialContactNumber);

    if (_isTenant) {
      _unitCtrl = TextEditingController(
        text: (widget.initialBuildingUnitNo ?? '').trim(),
      );
    }

    if (_isStaff) {
      final raw = (widget.initialStaffDepartment ?? '').trim();
      if (_deptOptions.contains(raw)) {
        _deptValue = raw;
      } else if (raw.isEmpty) {
        _deptValue = null;
      } else {
        _deptValue = 'Others';
        _deptOtherCtrl = TextEditingController(text: raw);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _birthCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _unitCtrl?.dispose();
    _deptOtherCtrl?.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    DateTime initial = DateTime.now().subtract(const Duration(days: 365 * 21));
    final parsed =
        tryParseYMD(_birthCtrl.text) ?? tryParsePretty(_birthCtrl.text);
    if (parsed != null) initial = parsed;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime.now(),
      helpText: 'Select Birth Date',
    );

    if (picked != null) {
      setState(
        () => _birthCtrl.text = formatPretty(picked),
      ); // "August 23, 2004"
    }
  }

  void _save() {
    final ok = _formKey.currentState?.validate() ?? true;
    if (!ok) return;

    if (_nameCtrl.text.trim().isEmpty ||
        _birthCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete required fields')),
      );
      return;
    }

    String? unitToReturn;
    String? deptToReturn;

    if (_isTenant) {
      final t = _unitCtrl?.text.trim() ?? '';
      unitToReturn = t.isEmpty ? null : t;
      // Validate 4-digit floor+unit (e.g., 0701)
      if (unitToReturn != null) {
        final raw = unitToReturn!;
        // Accept either '0701' (4 digits) or 'A-0701'/'A-701' formats
        String digits;
        final fourDigitReg = RegExp(r'^\d{4}');
        final buildingReg = RegExp(r'^[A-Za-z]-?\d{1,5}');

        if (fourDigitReg.hasMatch(raw)) {
          digits = raw.replaceAll(RegExp(r'\s+'), '').substring(0, 4);
        } else if (buildingReg.hasMatch(raw)) {
          final parts = raw.replaceAll(' ', '').split('-');
          digits =
              parts.length == 2
                  ? parts[1]
                  : parts[0].replaceAll(RegExp(r'^[A-Za-z]'), '');
          if (digits.length < 4) digits = digits.padLeft(4, '0');
        } else {
          _unitErr = 'Building unit must be 4 digits (e.g., 0701) or A-0701';
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid building unit format')),
          );
          setState(() {});
          return;
        }

        try {
          final floor = int.parse(digits.substring(0, 2));
          final unit = int.parse(digits.substring(2, 4));
          final minFloor = 7;
          final maxFloor = 26;
          final minUnit = 1;
          final maxUnit = 11;
          if (floor < minFloor || floor > maxFloor) {
            _unitErr = 'Floor must be between 07 and 26';
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(_unitErr!)));
            setState(() {});
            return;
          }
          if (unit < minUnit || unit > maxUnit) {
            _unitErr = 'Unit must be between 01 and 11';
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(_unitErr!)));
            setState(() {});
            return;
          }
        } catch (_) {
          _unitErr = 'Enter a valid 4-digit floor+unit code.';
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid building unit digits')),
          );
          setState(() {});
          return;
        }
      }
    } else if (_isStaff) {
      if (_deptValue != null) {
        if (_deptValue == 'Others') {
          final custom = _deptOtherCtrl?.text.trim() ?? '';
          deptToReturn = custom.isEmpty ? 'Others' : custom;
        } else {
          deptToReturn = _deptValue;
        }
      }
    }

    Navigator.pop(
      context,
      EditedProfileData(
        fullName: _nameCtrl.text.trim(),
        birthDate: _birthCtrl.text.trim(),
        userEmail: _emailCtrl.text.trim(),
        contactNumber: _phoneCtrl.text.trim(),
        buildingUnitNo: _isTenant ? unitToReturn : null,
        staffDepartment: _isStaff ? deptToReturn : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double maxSheetHeight = MediaQuery.of(context).size.height * 0.7;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Edit Profile',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),

                // Full Name
                InputField(
                  label: 'Full Name',
                  controller: _nameCtrl,
                  hintText: 'Enter full name',
                  isRequired: true,
                  readOnly: false,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 10),

                // Birth Date
                InputField(
                  label: 'Birth Date',
                  controller: _birthCtrl,
                  hintText: 'August 23, 2004',
                  isRequired: true,
                  readOnly: true,
                  keyboardType: TextInputType.datetime,
                  onTap: _pickBirthDate,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.cake_outlined),
                  ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: GestureDetector(
                      onTap: _pickBirthDate,
                      behavior: HitTestBehavior.opaque,
                      child: const Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Tenant: Building / Unit (optional)
                if (_isTenant) ...[
                  InputField(
                    label: 'Building Unit No',
                    controller: _unitCtrl!, // ensured in initState
                    hintText: 'e.g., Bldg 2 • Unit 7C',
                    isRequired: false,
                    readOnly: false,
                    errorText: _unitErr,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.apartment_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Staff: Department (optional)
                if (_isStaff) ...[
                  DropdownField<String>(
                    label: 'Department',
                    value: _deptValue,
                    items: _deptOptions,
                    hintText: 'e.g., Electrical / Plumbing',
                    isRequired: false,
                    // compact, same feel as your 36px text fields
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.work, size: 18),
                    ),
                    // Let the dropdown render "Others" inline input itself
                    otherController:
                        _deptValue == 'Others'
                            ? (_deptOtherCtrl ??= TextEditingController())
                            : null,
                    onChanged: (val) {
                      setState(() {
                        _deptValue = val;
                        if (_deptValue == 'Others') {
                          _deptOtherCtrl ??= TextEditingController();
                        } else {
                          _deptOtherCtrl?.dispose();
                          _deptOtherCtrl = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                ],

                // Email
                InputField(
                  label: 'Email',
                  controller: _emailCtrl,
                  hintText: 'name@example.com',
                  isRequired: true,
                  readOnly: false,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.mail),
                  ),
                ),
                const SizedBox(height: 10),

                // Contact Number
                InputField(
                  label: 'Contact Number',
                  controller: _phoneCtrl,
                  hintText: '+63 9XX XXX XXXX',
                  isRequired: true,
                  readOnly: false,
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, null),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF005CE7),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF005CE7),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(40),
                        ),
                        child: const Text('Save'),
                      ),
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
}
