// lib/services/profile_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:facilityfix/services/api_services_mobile.dart';
import 'package:facilityfix/services/auth_storage.dart';
import 'package:facilityfix/services/firebase_config.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final APIService _apiService = APIService();
  Map<String, dynamic>? _cachedProfile;
  DateTime? _lastFetchTime;

  // Cache for Firebase Storage download URLs
  final Map<String, String> _downloadUrlCache = {};
  final Map<String, DateTime> _downloadUrlCacheTime = {};

  /// Get cached profile data if available and recent
  Map<String, dynamic>? get cachedProfile => _cachedProfile;

  /// Check if cached profile is still valid (within 30 minutes)
  bool get isCacheValid {
    if (_lastFetchTime == null || _cachedProfile == null) return false;
    return DateTime.now().difference(_lastFetchTime!).inMinutes < 30;
  }

  /// Fetch current user profile with smart caching
  Future<Map<String, dynamic>?> getCurrentUserProfile({
    bool forceRefresh = false,
  }) async {
    try {
      print('[ProfileService] Fetching fresh profile data...');

      // Fetch from API
      final profile = await _apiService.fetchCurrentUserProfile();

      return profile;
    } catch (e) {
      print('[ProfileService] Error fetching profile: $e');

      // Fallback to local storage
      try {
        final localProfile = await AuthStorage.getProfile();
        if (localProfile != null) {
          _cachedProfile = localProfile;
          return localProfile;
        }
      } catch (storageError) {
        print('[ProfileService] Error accessing local storage: $storageError');
      }

      return null;
    }
  }

  /// Update current user profile
  Future<bool> updateCurrentUserProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? birthDate,
    String? department,
    String? staffDepartment,
    List<String>? departments,
    List<String>? staffDepartments,
    String? buildingId,
    String? unitId,
  }) async {
    try {
      print('[ProfileService] Updating user profile...');

      final result = await _apiService.updateCurrentUserProfile(
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        birthDate: birthDate,
        department: department,
        staffDepartment: staffDepartment,
        departments: departments,
        staffDepartments: staffDepartments,
        buildingId: buildingId,
        unitId: unitId,
      );

      print('[ProfileService] Profile update result: $result');

      // Invalidate cache to force refresh on next access
      _cachedProfile = null;
      _lastFetchTime = null;

      // Immediately refresh the profile
      await getCurrentUserProfile(forceRefresh: true);

      return true;
    } catch (e) {
      print('[ProfileService] Error updating profile: $e');
      return false;
    }
  }

  /// Get user's display name (handles various name field combinations)
  String getDisplayName(Map<String, dynamic>? profile) {
    if (profile == null) return 'User';

    // Try different name field combinations
    final firstName = (profile['first_name']?.toString() ?? '').trim();
    final lastName = (profile['last_name']?.toString() ?? '').trim();
    final fullName = (profile['full_name']?.toString() ?? '').trim();
    final displayName = (profile['display_name']?.toString() ?? '').trim();
    final name = (profile['name']?.toString() ?? '').trim();

    // Prioritize full name fields
    if (fullName.isNotEmpty) return fullName;
    if (displayName.isNotEmpty) return displayName;
    if (name.isNotEmpty) return name;

    // Combine first and last name
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      return '$firstName $lastName'.trim();
    }

    // Fallback to email prefix
    final email = profile['email']?.toString() ?? '';
    if (email.isNotEmpty) {
      final atIndex = email.indexOf('@');
      if (atIndex > 0) {
        return email.substring(0, atIndex);
      }
    }

    // Final fallback
    return 'User';
  }

  /// Get user's identifier (staff ID, tenant ID, etc.)
  String getUserId(Map<String, dynamic>? profile) {
    if (profile == null) return '';

    // Try different ID fields
    final userId = profile['user_id']?.toString() ?? '';
    final staffId = profile['staff_id']?.toString() ?? '';
    final id = profile['id']?.toString() ?? '';
    final uid = profile['uid']?.toString() ?? '';

    return userId.isNotEmpty
        ? userId
        : staffId.isNotEmpty
        ? staffId
        : id.isNotEmpty
        ? id
        : uid;
  }

  /// Get user's role
  String getUserRole(Map<String, dynamic>? profile) {
    if (profile == null) return 'user';
    return (profile['role']?.toString() ?? 'user').toLowerCase();
  }

  /// Get user's department(s)
  List<String> getUserDepartments(Map<String, dynamic>? profile) {
    if (profile == null) return [];

    // Check new multi-select fields first
    final departments = profile['departments'];
    if (departments is List) {
      return departments.whereType<String>().toList();
    }

    final staffDepartments = profile['staff_departments'];
    if (staffDepartments is List) {
      return staffDepartments.whereType<String>().toList();
    }

    // Fallback to legacy single department fields
    final department = (profile['department']?.toString() ?? '').trim();
    final staffDepartment =
        (profile['staff_department']?.toString() ?? '').trim();

    final result = <String>[];
    if (department.isNotEmpty) result.add(department);
    if (staffDepartment.isNotEmpty && !result.contains(staffDepartment)) {
      result.add(staffDepartment);
    }

    return result;
  }

  /// Get user's primary department
  String getPrimaryDepartment(Map<String, dynamic>? profile) {
    final departments = getUserDepartments(profile);
    return departments.isNotEmpty ? departments.first : '';
  }

  /// Get user's contact information
  Map<String, String> getContactInfo(Map<String, dynamic>? profile) {
    if (profile == null) return {};

    return {
      'email': profile['email']?.toString() ?? '',
      'phone_number': profile['phone_number']?.toString() ?? '',
      'phone': profile['phone']?.toString() ?? '',
    };
  }

  /// Get user's building and unit information
  Map<String, String> getBuildingInfo(Map<String, dynamic>? profile) {
    if (profile == null) return {};

    return {
      'building_id': profile['building_id']?.toString() ?? '',
      'unit_id': profile['unit_id']?.toString() ?? '',
      'building_unit': profile['building_unit']?.toString() ?? '',
    };
  }

  /// Return building unit in floor/unit format (e.g., "0701" for floor 07, unit 01)
  /// Strips the building letter prefix (e.g., "A-0701" becomes "0701")
  String formatBuildingUnitDisplay(Map<String, dynamic>? profile) {
    if (profile == null) return '';

    final raw = profile['building_unit']?.toString() ?? '';

    if (raw.isEmpty) return '';

    // If format is "A-0701", extract just the "0701" part
    if (raw.contains('-')) {
      final parts = raw.split('-');
      if (parts.length >= 2) {
        final unitPart = parts[1].trim();
        // Only return if it looks like a valid 4-digit floor+unit code
        if (RegExp(r'^\d{4}$').hasMatch(unitPart)) {
          return unitPart;
        }
      }
    }

    // If already in "0701" format, return as-is
    if (RegExp(r'^\d{4}$').hasMatch(raw)) {
      return raw;
    }

    // For other formats, return the raw value
    return raw;
  }

  /// Format phone number for display
  String formatPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) return '';

    // Remove +63 prefix if present
    if (phone.startsWith('+63')) {
      return phone.substring(3);
    }

    return phone;
  }

  /// Format birth date for display
  String formatBirthDate(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return '';

    try {
      final date = DateTime.parse(birthDate);
      final months = [
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
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return birthDate; // Return as-is if parsing fails
    }
  }

  /// Clear cached profile data (useful for logout)
  void clearCache() {
    _cachedProfile = null;
    _lastFetchTime = null;
    _downloadUrlCache.clear();
    _downloadUrlCacheTime.clear();
  }

  /// Get profile completion percentage
  double getProfileCompletionPercentage(Map<String, dynamic>? profile) {
    if (profile == null) return 0.0;

    final completionScore = profile['completion_score'];
    if (completionScore is Map<String, dynamic>) {
      final percentage = completionScore['percentage'];
      if (percentage is num) {
        return percentage.toDouble();
      }
    }

    // Fallback calculation
    final requiredFields = ['first_name', 'last_name', 'email', 'role'];
    final optionalFields = ['phone_number', 'department', 'building_id'];

    int completed = 0;
    for (final field in requiredFields) {
      if ((profile[field]?.toString() ?? '').isNotEmpty) completed++;
    }
    for (final field in optionalFields) {
      if ((profile[field]?.toString() ?? '').isNotEmpty) completed++;
    }

    return (completed / (requiredFields.length + optionalFields.length)) * 100;
  }

  /// Check if profile is complete
  bool isProfileComplete(Map<String, dynamic>? profile) {
    if (profile == null) return false;

    final completionScore = profile['completion_score'];
    if (completionScore is Map<String, dynamic>) {
      return completionScore['is_complete'] == true;
    }

    // Fallback check
    final requiredFields = ['first_name', 'last_name', 'email', 'role'];
    return requiredFields.every(
      (field) => (profile[field]?.toString() ?? '').isNotEmpty,
    );
  }

  /// Get profile image provider from various sources (async version)
  /// Checks in order: local file, Firebase Storage URL (with proper auth), legacy URLs
  /// Returns null if no valid image source is found
  Future<ImageProvider?> getProfileImageProviderAsync(
    Map<String, dynamic>? profile,
    File? localImageFile,
  ) async {
    if (profile == null) return null;

    print('[ProfileService] Loading profile image...');

    // 1. Check for local file override (recently uploaded)
    if (localImageFile != null && localImageFile.existsSync()) {
      print('[ProfileService] Using local file: ${localImageFile.path}');
      return FileImage(localImageFile);
    }

    // 2. Check for Firebase Storage URL (profile_image_url)
    final imageUrl = profile['profile_image_url']?.toString() ?? '';
    if (imageUrl.isNotEmpty) {
      try {
        // Check if URL is already authenticated (firebasestorage.googleapis.com with token)
        if (imageUrl.contains('firebasestorage.googleapis.com')) {
          print('[ProfileService] Using authenticated Firebase Storage URL');
          return NetworkImage(imageUrl);
        }

        // For unauthenticated URLs, get proper download URL from Firebase Storage
        print('[ProfileService] Fetching authenticated download URL...');

        // Check cache first (URLs expire after 1 hour, so cache for 50 minutes)
        final cachedUrl = _downloadUrlCache[imageUrl];
        final cacheTime = _downloadUrlCacheTime[imageUrl];

        if (cachedUrl != null && cacheTime != null) {
          final minutesSinceCache =
              DateTime.now().difference(cacheTime).inMinutes;
          if (minutesSinceCache < 50) {
            print('[ProfileService] Using cached download URL');
            return NetworkImage(cachedUrl);
          }
        }

        // Fetch new download URL
        final downloadUrl = await FirebaseConfig.getDownloadUrl(imageUrl);

        if (downloadUrl != null) {
          // Cache the download URL
          _downloadUrlCache[imageUrl] = downloadUrl;
          _downloadUrlCacheTime[imageUrl] = DateTime.now();

          print('[ProfileService] Using Firebase Storage download URL');
          return NetworkImage(downloadUrl);
        }
      } catch (e) {
        print('[ProfileService] Error loading Firebase Storage URL: $e');
      }
    }

    // 3. Check for local file path stored in profile
    final photoPath = profile['photo_path']?.toString() ?? '';
    if (photoPath.isNotEmpty) {
      try {
        final file = File(photoPath);
        if (file.existsSync()) {
          print('[ProfileService] Using stored local file: $photoPath');
          return FileImage(file);
        }
      } catch (e) {
        print('[ProfileService] Error loading local file: $e');
      }
    }

    // 4. Check for legacy photo_url (direct URL)
    final photoUrl = profile['photo_url']?.toString() ?? '';
    if (photoUrl.isNotEmpty) {
      try {
        print('[ProfileService] Using legacy photo_url: $photoUrl');
        return NetworkImage(photoUrl);
      } catch (e) {
        print('[ProfileService] Error loading legacy photo URL: $e');
      }
    }

    print('[ProfileService] No valid profile image found');
    return null;
  }

  /// Synchronous version that returns cached data only (for immediate rendering)
  /// Use getProfileImageProviderAsync for fresh data with proper authentication
  ImageProvider? getProfileImageProvider(
    Map<String, dynamic>? profile,
    File? localImageFile,
  ) {
    if (profile == null) return null;

    // 1. Check for local file override (recently uploaded)
    if (localImageFile != null && localImageFile.existsSync()) {
      return FileImage(localImageFile);
    }

    final storageRef = FirebaseStorage.instance.ref();

    // 2. Check for cached authenticated URL
    final imageUrl = profile['profile_image_url']?.toString() ?? '';
    if (imageUrl.isNotEmpty) {
      final cachedUrl = _downloadUrlCache[imageUrl];
      if (cachedUrl != null) {
        return NetworkImage(cachedUrl);
      }

      // If it's already authenticated, use it directly
      if (imageUrl.contains('firebasestorage.googleapis.com')) {
        return NetworkImage(imageUrl);
      }
    }

    // 3. Check for local file path
    final photoPath = profile['photo_path']?.toString() ?? '';
    if (photoPath.isNotEmpty) {
      try {
        final file = File(photoPath);
        if (file.existsSync()) {
          return FileImage(file);
        }
      } catch (_) {}
    }

    // 4. Check for legacy photo_url
    final photoUrl = profile['photo_url']?.toString() ?? '';
    if (photoUrl.isNotEmpty) {
      return NetworkImage(photoUrl);
    }

    return null;
  }

  /// Get user initials for avatar fallback
  String getUserInitials(Map<String, dynamic>? profile) {
    final displayName = getDisplayName(profile);

    if (displayName.isEmpty || displayName == 'User') {
      return '?';
    }

    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      // First and last name initials
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts.first.isNotEmpty) {
      // Just first letter of single name
      return parts.first[0].toUpperCase();
    }

    return '?';
  }
}
