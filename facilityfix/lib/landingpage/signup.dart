// lib/widgets/signup.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:facilityfix/tenant/home.dart' as Tenant;
import 'package:facilityfix/staff/home.dart' as Staff;
import 'package:facilityfix/widgets/forms.dart';

import 'package:facilityfix/services/api_services_mobile.dart';
import 'package:facilityfix/config/env.dart';
import 'package:facilityfix/services/auth_storage.dart';

AppRole _toAppRole(String role) {
  switch (role.toLowerCase()) {
    case 'tenant':
      return AppRole.tenant;
    case 'staff':
      return AppRole.staff;
    case 'admin':
      return AppRole.admin;
    default:
      return AppRole.tenant;
  }
}

class SignUp extends StatefulWidget {
  final String role; // 'tenant' | 'staff' | 'admin'
  const SignUp({Key? key, required this.role}) : super(key: key);

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _formKey = GlobalKey<FormState>();

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final birthDateController =
      TextEditingController(); // UI-only text; sent to API as birth_date
  final idController =
      TextEditingController(); // tenant building/unit (format: 0701)
  final emailController = TextEditingController();
  final contactNumberController = TextEditingController();
  final passwordController = TextEditingController();

  // Staff department (renamed from classification)
  String? _selectedStaffDepartment;
  final TextEditingController staffDepartmentOtherController =
      TextEditingController();

  bool _submitted = false;
  bool _loading = false;

  String? _firstNameErr;
  String? _lastNameErr;
  String? _birthDateErr;
  String? _tenantBuildingErr;
  String? _emailErr;
  String? _contactErr;
  String? _passwordErr;
  String? _staffDeptErr;

  bool _obscurePassword = true;

  bool get _isTenant => widget.role.toLowerCase() == 'tenant';
  bool get _isStaff => widget.role.toLowerCase() == 'staff';
  bool get _isAdmin => widget.role.toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final api = APIService(roleOverride: _toAppRole(widget.role));
      final ok = await api.testConnection();
      if (!mounted) return;
      if (!ok) _snack('Server unreachable: ${api.baseUrl}');
    });
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    birthDateController.dispose();
    idController.dispose();
    emailController.dispose();
    contactNumberController.dispose();
    passwordController.dispose();
    staffDepartmentOtherController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      birthDateController.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      setState(() => _birthDateErr = null);
    }
  }

  bool _validate() {
    _firstNameErr = null;
    _lastNameErr = null;
    _birthDateErr = null;
    _tenantBuildingErr = null;
    _emailErr = null;
    _contactErr = null;
    _passwordErr = null;
    _staffDeptErr = null;

    final first = firstNameController.text.trim();
    final last = lastNameController.text.trim();
    final bday = birthDateController.text.trim();
    final email = emailController.text.trim();
    final contact = contactNumberController.text.trim();
    final pass = passwordController.text;

    if (first.isEmpty) _firstNameErr = 'First Name is required.';
    if (last.isEmpty) _lastNameErr = 'Last Name is required.';

    // Birthdate validation (YYYY-MM-DD, logical checks, >= 18yo)
    if (bday.isEmpty) {
      _birthDateErr = 'Birthdate is required.';
    } else {
      final re = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      if (!re.hasMatch(bday)) {
        _birthDateErr = 'Use format YYYY-MM-DD.';
      } else {
        try {
          final parts = bday.split('-').map(int.parse).toList();
          final dt = DateTime(parts[0], parts[1], parts[2]);
          final now = DateTime.now();
          if (dt.isAfter(now)) {
            _birthDateErr = 'Birthdate cannot be in the future.';
          } else {
            int age = now.year - dt.year;
            final hadBirthday =
                (now.month > dt.month) ||
                (now.month == dt.month && now.day >= dt.day);
            if (!hadBirthday) age -= 1;
            if (age < 18) _birthDateErr = 'You must be at least 18 years old.';
          }
        } catch (_) {
          _birthDateErr = 'Enter a valid date.';
        }
      }
    }

    if (_isTenant) {
      final raw = idController.text.trim();
      // validation for pattern only; mapping to backend format occurs on submit
      if (raw.isEmpty) {
        _tenantBuildingErr = 'Floor and Unit No. is required.';
      } else {
        // Must be exactly 4 digits: first 2 digits floor (07-26), last 2 digits unit (01-11)
        if (!RegExp(r'^\d{4}$').hasMatch(raw)) {
          _tenantBuildingErr = 'Use 4 digits only (e.g., 0701).';
        } else {
          try {
            final floor = int.parse(raw.substring(0, 2));
            final unit = int.parse(raw.substring(2, 4));
            final minFloor = 7;
            final maxFloor = 26;
            final minUnit = 1;
            final maxUnit = 11; // floors may have 10 or 11 units
            if (floor < minFloor || floor > maxFloor) {
              _tenantBuildingErr =
                  'Floor must be between 07 and 26 (units only on floors 7+).';
            } else if (unit < minUnit || unit > maxUnit) {
              _tenantBuildingErr = 'Unit must be between 01 and 11.';
            }
          } catch (_) {
            _tenantBuildingErr = 'Enter a valid 4-digit floor+unit code.';
          }
        }
      }
    }

    if (_isStaff) {
      final isOthers = _selectedStaffDepartment == 'Others';
      if (_selectedStaffDepartment == null ||
          _selectedStaffDepartment!.isEmpty) {
        _staffDeptErr = 'Staff Department is required.';
      } else if (isOthers &&
          staffDepartmentOtherController.text.trim().isEmpty) {
        _staffDeptErr = 'Please specify your Staff Department.';
      }
    }

    final emailRe = RegExp(r'^[\w.-]+@([\w-]+\.)+[\w-]{2,}$');
    if (email.isEmpty) {
      _emailErr = 'Email is required.';
    } else if (!emailRe.hasMatch(email)) {
      _emailErr = 'Enter a valid email address.';
    }

    if (contact.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(contact)) {
      _contactErr = 'Enter 10 digits (exclude +63).';
    }

    if (pass.isEmpty) {
      _passwordErr = 'Password is required.';
    } else if (pass.length < 6) {
      _passwordErr = 'Password must be at least 6 characters.';
    }

    _formKey.currentState?.validate();
    setState(() {});
    final basicOk =
        _firstNameErr == null &&
        _lastNameErr == null &&
        _birthDateErr == null &&
        _tenantBuildingErr == null &&
        _emailErr == null &&
        _contactErr == null &&
        _passwordErr == null;

    final staffOk = !_isStaff || _staffDeptErr == null;
    return basicOk && staffOk;
  }

  String _fallbackFromEmail(String? email) {
    if (email == null || email.isEmpty) return 'User';
    final at = email.indexOf('@');
    if (at > 0) {
      final part =
          email.substring(0, at).replaceAll(RegExp(r'[._-]'), ' ').trim();
      if (part.isNotEmpty) return part;
    }
    return email;
  }

  // Helper: get FIRST NAME only for welcome message (with fallbacks)
  String _firstNameFromProfile(Map<String, dynamic>? profile) {
    if (profile == null) return 'User';
    final first = (profile['first_name'] ?? '').toString().trim();
    if (first.isNotEmpty) return first;

    // fallback: try full_name -> first word
    final full = (profile['full_name'] ?? '').toString().trim();
    if (full.isNotEmpty) {
      final parts = full.split(RegExp(r'\s+'));
      if (parts.isNotEmpty && parts.first.isNotEmpty) return parts.first;
    }

    // fallback: email local-part
    final email = (profile['email'] ?? '').toString();
    final at = email.indexOf('@');
    if (at > 0) return email.substring(0, at);

    return 'User';
  }

  Future<void> _onSubmit() async {
    setState(() => _submitted = true);
    if (!_validate()) return;

    setState(() => _loading = true);

    final api = APIService(roleOverride: _toAppRole(widget.role));
    final first = firstNameController.text.trim();
    final last = lastNameController.text.trim();
    final bday = birthDateController.text.trim(); // <-- birthDate value
    final email = emailController.text.trim();
    final pass = passwordController.text;
    final phone =
        contactNumberController.text.trim().isEmpty
            ? null
            : '+63${contactNumberController.text.trim()}';

    try {
      Map<String, dynamic> reg;
      if (_isAdmin) {
        reg = await api.registerAdmin(
          firstName: first,
          lastName: last,
          birthDate: bday, // mapped by APIService to 'birth_date'
          email: email,
          password: pass,
          phoneNumber: phone,
        );
      } else if (_isStaff) {
        final label =
            _selectedStaffDepartment == 'Others'
                ? staffDepartmentOtherController.text.trim()
                : (_selectedStaffDepartment ?? '');
        reg = await api.registerStaff(
          firstName: first,
          lastName: last,
          birthDate: bday, // mapped by APIService to 'birth_date'
          email: email,
          password: pass,
          staffDepartment: label,
          phoneNumber: phone,
        );
      } else {
        final raw = idController.text.trim();
        final buildingUnit = RegExp(r'^\d{4}$').hasMatch(raw) ? 'A-$raw' : raw;
        reg = await api.registerTenant(
          firstName: first,
          lastName: last,
          birthDate: bday, // mapped by APIService to 'birth_date'
          email: email,
          password: pass,
          buildingUnit: buildingUnit,
          phoneNumber: phone,
        );
      }

      final userId = (reg['user_id'] ?? '').toString();
      if (userId.isEmpty) {
        _snack('Registered, but user_id missing. Please log in manually.');
        if (!mounted) return;
        Navigator.pop(context); // Close signup modal
        return;
      }

      // Auto-login
      Map<String, dynamic> loginRes;
      if (_isAdmin) {
        loginRes = await api.loginRoleBased(
          role: 'admin',
          email: email,
          password: pass,
        );
      } else if (_isStaff) {
        loginRes = await api.loginRoleBased(
          role: 'staff',
          email: email,
          password: pass,
        );
      } else {
        loginRes = await api.loginRoleBased(
          role: 'tenant',
          email: email,
          password: pass,
        );
      }

      // Build and save profile + token
      final backendFirst = (loginRes['first_name'] ?? '').toString().trim();
      final backendLast = (loginRes['last_name'] ?? '').toString().trim();
      final backendFull = (loginRes['full_name'] ?? '').toString().trim();

      String finalFullName = '';
      if (backendFull.isNotEmpty) {
        finalFullName = backendFull;
      } else if (backendFirst.isNotEmpty || backendLast.isNotEmpty) {
        finalFullName = '${backendFirst} ${backendLast}'.trim();
      } else if (first.isNotEmpty || last.isNotEmpty) {
        finalFullName = '${first} ${last}'.trim();
      } else {
        finalFullName = _fallbackFromEmail(
          (loginRes['email'] ?? email).toString(),
        );
      }

      final profile = <String, dynamic>{
        'user_id': loginRes['user_id'] ?? userId,
        'first_name': backendFirst.isNotEmpty ? backendFirst : first,
        'last_name': backendLast.isNotEmpty ? backendLast : last,
        'full_name': finalFullName,
        'birth_date': bday, // store snake_case
        'email': loginRes['email'] ?? email,
        'role': (loginRes['role'] ?? widget.role).toString(),
        'building_unit': loginRes['building_unit'] ?? idController.text.trim(),
      };
      await AuthStorage.saveProfile(profile);

      final idToken =
          (loginRes['id_token'] ?? loginRes['token'] ?? '').toString();
      if (idToken.isNotEmpty) await AuthStorage.saveToken(idToken);

      final role = (loginRes['role'] ?? widget.role).toString().toLowerCase();
      Widget destination;
      switch (role) {
        case 'tenant':
          destination = const Tenant.HomePage();
          break;
        case 'staff':
          destination = const Staff.HomePage();
          break;
        default:
          destination = const Tenant.HomePage();
      }

      if (!mounted) return;
      final firstName = _firstNameFromProfile(profile);
      _snack('Welcome $firstName');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: const Color.fromRGBO(0, 0, 0, 0.5),
        body: GestureDetector(
          onTap: () {},
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 600,
              width: double.infinity,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: Color(0xFF005CE7),
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 20),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                InputField(
                                  label: 'First Name',
                                  hintText: 'e.g., Juan',
                                  controller: firstNameController,
                                  isRequired: true,
                                  errorText: _firstNameErr,
                                ),
                                InputField(
                                  label: 'Last Name',
                                  hintText: 'e.g., Dela Cruz',
                                  controller: lastNameController,
                                  isRequired: true,
                                  errorText: _lastNameErr,
                                ),
                                InputField(
                                  label: 'Birthdate',
                                  hintText: 'YYYY-MM-DD',
                                  controller: birthDateController,
                                  isRequired: true,
                                  readOnly: true,
                                  onTap: _pickBirthDate,
                                  errorText: _birthDateErr,
                                  prefixIcon: const Icon(
                                    Icons.calendar_today,
                                    color: Color(0xFF98A2B3),
                                  ),
                                ),

                                if (_isTenant)
                                  InputField(
                                    label: 'Floor and Unit No.',
                                    hintText: 'e.g., 0701 (floor 07, unit 01)',
                                    controller: idController,
                                    isRequired: true,
                                    errorText: _tenantBuildingErr,
                                    prefixIcon: const Icon(
                                      Icons.location_city_outlined,
                                      color: Color(0xFF98A2B3),
                                    ),
                                  ),

                                if (_isStaff) ...[
                                  DropdownField<String>(
                                    label: 'Staff Department',
                                    items: const [
                                      'Maintenance',
                                      'Carpentry',
                                      'Plumbing',
                                      'Electrical',
                                      'Masonry',
                                      'Others',
                                    ],
                                    value: _selectedStaffDepartment,
                                    onChanged:
                                        (v) => setState(() {
                                          _selectedStaffDepartment = v;
                                          if (v != 'Others')
                                            _staffDeptErr = null;
                                        }),
                                    isRequired: _submitted,
                                    requiredMessage:
                                        'Staff Department is required.',
                                    hintText: 'Select department',
                                    otherController:
                                        staffDepartmentOtherController,
                                  ),
                                  if (_staffDeptErr != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _staffDeptErr!,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFFD92D20),
                                        height: 1.0,
                                      ),
                                    ),
                                  ],
                                ],

                                InputField(
                                  label: 'Email',
                                  hintText: 'you@example.com',
                                  controller: emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  isRequired: true,
                                  errorText: _emailErr,
                                  prefixIcon: const Icon(
                                    Icons.mail,
                                    color: Color(0xFF98A2B3),
                                  ),
                                ),
                                InputField(
                                  label: 'Contact Number',
                                  hintText: 'e.g., 9123456789',
                                  controller: contactNumberController,
                                  keyboardType: TextInputType.number,
                                  isRequired: false,
                                  errorText: _contactErr,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  prefixIcon: const Text(
                                    '+63 ',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: Color(0xFF667085),
                                    ),
                                  ),
                                ),
                                InputField(
                                  label: 'Password',
                                  hintText: 'Enter your password',
                                  controller: passwordController,
                                  isRequired: true,
                                  obscureText: _obscurePassword,
                                  errorText: _passwordErr,
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    color: Color(0xFF98A2B3),
                                  ),
                                  suffixIcon: Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTap:
                                          () => setState(
                                            () =>
                                                _obscurePassword =
                                                    !_obscurePassword,
                                          ),
                                      child: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: const Color(0xFF818181),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF005CE7),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _loading ? null : _onSubmit,
                                child:
                                    _loading
                                        ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                        : const Text(
                                          'Sign Up',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Already have an account? '),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context); // Close signup modal
                                  // Role selection modal will show again from the main screen
                                },
                                child: const Text(
                                  'Log in',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
