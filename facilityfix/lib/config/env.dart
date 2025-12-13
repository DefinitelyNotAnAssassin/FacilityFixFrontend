import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

enum AppRole { tenant, staff, admin }

class AppEnv {
  /// When testing on a physical device, set this to your laptop’s LAN IP.
  // static String? lanIp = 'https://lofty-bay-475013-v2-557829776689.europe-west1.run.app';
  static String? lanIp = '192.168.18.10';

  //static const String _WEB_API = 'https://lofty-bay-475013-v2-557829776689.europe-west1.run.app';
  static const String _WEB_API = 'http://192.168.18.10:8000';

  static const Map<AppRole, String> _webHosts = {
    AppRole.tenant: _WEB_API,
    AppRole.staff: _WEB_API,
    AppRole.admin: _WEB_API,
  };

  static const Map<AppRole, String> _androidEmuHosts = {
    AppRole.tenant: 'http://10.0.2.2:8000',
    AppRole.staff: 'http://10.0.2.2:8000',
    AppRole.admin: 'http://10.0.2.2:8000',
  };

  static Map<AppRole, String> _deviceHosts(String ip) => {
    // AppRole.tenant: 'https://lofty-bay-475013-v2-557829776689.europe-west1.run.app',
    // AppRole.staff: 'https://lofty-bay-475013-v2-557829776689.europe-west1.run.app',
    // AppRole.admin: 'https://lofty-bay-475013-v2-557829776689.europe-west1.run.app',
    AppRole.tenant: 'http://192.168.18.10:8000',
    AppRole.staff: 'http://192.168.18.10:8000',
    AppRole.admin: 'http://192.168.18.10:8000',
  };

  /// Default per-platform base URL (localhost for web/desktop, emulator loopback, etc.)
  static String baseUrlFor(AppRole role) {
    if (kIsWeb) return _webHosts[role]!;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator → 10.0.2.2 (maps to host's localhost)
        return _androidEmuHosts[role]!;
      case TargetPlatform.iOS:
        // iOS simulator can use localhost
        return 'http://localhost:8000';
      default:
        // Windows/macOS/Linux desktop apps
        return _webHosts[role]!;
    }
  }

  /// Prefer LAN IP only when explicitly set (for physical devices)
  static String baseUrlWithLan(AppRole role) {
    // On web we must use the web host (usually localhost) because browsers
    // enforce CORS and can't fetch arbitrary LAN IPs reliably. Only prefer
    // the LAN IP when running on a physical device (mobile/desktop).
    if (kIsWeb) return baseUrlFor(role);
    if (lanIp == null || lanIp!.isEmpty) return baseUrlFor(role);
    return _deviceHosts(lanIp!)[role]!;
  }
}
