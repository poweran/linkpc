class UserProfile {
  final String token;
  final String clientName;
  final String planName;
  final double trafficUsedGb;
  final double trafficTotalGb;
  final DateTime? expiresAt;
  final bool isExpired;
  final String rawSingboxConfig;

  UserProfile({
    required this.token,
    required this.clientName,
    required this.planName,
    this.trafficUsedGb = 0.0,
    this.trafficTotalGb = 100.0,
    this.expiresAt,
    this.isExpired = false,
    this.rawSingboxConfig = '',
  });

  double get remainingGb {
    final rem = trafficTotalGb - trafficUsedGb;
    return rem < 0 ? 0.0 : rem;
  }

  double get usagePercent {
    if (trafficTotalGb <= 0) return 0.0;
    final pct = trafficUsedGb / trafficTotalGb;
    return pct.clamp(0.0, 1.0);
  }

  factory UserProfile.empty() => UserProfile(
        token: '',
        clientName: 'Гость',
        planName: 'Не активирован',
      );
}
