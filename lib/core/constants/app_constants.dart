class AppConstants {
  static const String appName = 'linkpc';

  /// Injected at compile-time via: flutter build ... --dart-define=APP_VERSION=v1.0.20
  /// Defaults to latest tag if not provided during build
  static const String rawVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'v1.0.23');

  /// Clean semantic version without 'v' prefix (e.g. '1.0.17')
  static String get appVersion =>
      rawVersion.startsWith('v') ? rawVersion.substring(1) : rawVersion;

  /// Display version with 'v' prefix for UI tags and badges (e.g. 'v1.0.17')
  static String get displayVersion =>
      rawVersion.startsWith('v') ? rawVersion : 'v$rawVersion';

  static const String appTagline = 'HIGH-SPEED SECURE GATEWAY';

  // Endpoints
  static const String defaultBaseUrl = 'https://vless.linkpc.net';
  static const String subscriptionPath = '/sub/';
  static const String apiMePath = '/api/user/me';
  static const String pingTargetHost = 'vless.linkpc.net';
  static const String supportTelegram = 'https://t.me/InfinitySupport';
  static const String webCabinetUrl = 'https://vless.linkpc.net/cabinet';

  // Method Channels (Flutter <-> Native libbox)
  static const String tunnelChannel = 'net.linkpc.client/tunnel';
  static const String eventChannel = 'net.linkpc.client/events';

  // Preferences Keys
  static const String prefUserToken = 'linkpc_user_token';
  static const String prefSubUrl = 'linkpc_sub_url';
  static const String prefRoutingMode = 'linkpc_routing_mode';
  static const String prefAutoConnect = 'linkpc_auto_connect';
  static const String prefCachedConfig = 'linkpc_cached_config';
  static const String prefLastPing = 'linkpc_last_ping';
  static const String prefDesktopMode = 'linkpc_desktop_mode';

  // Desktop Network Modes
  static const String desktopModeTun = 'tun';     // System-wide VPN (TUN, like Hiddify)
  static const String desktopModeProxy = 'proxy'; // System Proxy (Browsers only)

  // macOS Helper Paths
  static const String macOsHelperBinary = '/usr/local/bin/linkpc-sing-box';

  // Routing Modes
  static const String routeModeSmart = 'smart_ru_direct'; // Bypass Russian traffic
  static const String routeModeAll = 'route_all';         // Route all traffic through tunnel
}
