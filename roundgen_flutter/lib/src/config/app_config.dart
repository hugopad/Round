class AppConfig {
  static const String appName = 'ROUNDGEN';
  static const String baseUrl = 'https://bolsadetrabajo2.iblogger.org/php_api';
  static const String apkUrl = 'https://bolsadetrabajo2.iblogger.org/roundgen/app-release.apk';
  static const String publicDirectoryUrl = 'https://bolsadetrabajo2.iblogger.org/php_api/doctors/public_profile_page.php';

  static String doctorPublicProfileUrl(int doctorId) => '$publicDirectoryUrl?doctor_id=$doctorId';
}
