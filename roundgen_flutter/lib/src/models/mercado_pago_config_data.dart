class MercadoPagoConfigData {
  const MercadoPagoConfigData({
    required this.publicKey,
    required this.accessToken,
    required this.webhookSecret,
    required this.appBaseUrl,
    required this.successUrl,
    required this.failureUrl,
    required this.pendingUrl,
    required this.isActive,
  });

  final String publicKey;
  final String accessToken;
  final String webhookSecret;
  final String appBaseUrl;
  final String successUrl;
  final String failureUrl;
  final String pendingUrl;
  final bool isActive;

  factory MercadoPagoConfigData.fromJson(Map<String, dynamic> json) {
    return MercadoPagoConfigData(
      publicKey: (json['public_key'] ?? '').toString(),
      accessToken: (json['access_token'] ?? '').toString(),
      webhookSecret: (json['webhook_secret'] ?? '').toString(),
      appBaseUrl: (json['app_base_url'] ?? '').toString(),
      successUrl: (json['success_url'] ?? '').toString(),
      failureUrl: (json['failure_url'] ?? '').toString(),
      pendingUrl: (json['pending_url'] ?? '').toString(),
      isActive: (json['is_active'] ?? false).toString() == 'true' || '${json['is_active'] ?? ''}' == '1',
    );
  }
}
