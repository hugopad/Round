class DoctorAccessEmailConfig {
  const DoctorAccessEmailConfig({
    required this.doctorId,
    required this.senderName,
    required this.senderEmail,
    required this.replyToEmail,
    required this.accessSubject,
    required this.accessMessage,
    required this.apkUrl,
    required this.attachApk,
    required this.isActive,
    required this.smtpHost,
    required this.smtpPort,
    required this.smtpUsername,
    required this.smtpPassword,
    required this.smtpEncryption,
  });

  final int doctorId;
  final String senderName;
  final String senderEmail;
  final String replyToEmail;
  final String accessSubject;
  final String accessMessage;
  final String apkUrl;
  final bool attachApk;
  final bool isActive;
  final String smtpHost;
  final int smtpPort;
  final String smtpUsername;
  final String smtpPassword;
  final String smtpEncryption;

  factory DoctorAccessEmailConfig.fromJson(Map<String, dynamic> json) {
    return DoctorAccessEmailConfig(
      doctorId: int.tryParse('${json['doctor_id'] ?? 0}') ?? 0,
      senderName: (json['sender_name'] ?? '').toString(),
      senderEmail: (json['sender_email'] ?? '').toString(),
      replyToEmail: (json['reply_to_email'] ?? '').toString(),
      accessSubject: (json['access_subject'] ?? '').toString(),
      accessMessage: (json['access_message'] ?? '').toString(),
      apkUrl: (json['apk_url'] ?? '').toString(),
      attachApk: json['attach_apk'] == true || '${json['attach_apk']}' == '1',
      isActive: json['is_active'] == true || '${json['is_active']}' == '1',
      smtpHost: (json['smtp_host'] ?? '').toString(),
      smtpPort: int.tryParse('${json['smtp_port'] ?? 587}') ?? 587,
      smtpUsername: (json['smtp_username'] ?? '').toString(),
      smtpPassword: (json['smtp_password'] ?? '').toString(),
      smtpEncryption: (json['smtp_encryption'] ?? 'tls').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'doctor_id': doctorId,
      'sender_name': senderName,
      'sender_email': senderEmail,
      'reply_to_email': replyToEmail,
      'access_subject': accessSubject,
      'access_message': accessMessage,
      'apk_url': apkUrl,
      'attach_apk': attachApk,
      'is_active': isActive,
      'smtp_host': smtpHost,
      'smtp_port': smtpPort,
      'smtp_username': smtpUsername,
      'smtp_password': smtpPassword,
      'smtp_encryption': smtpEncryption,
    };
  }
}
