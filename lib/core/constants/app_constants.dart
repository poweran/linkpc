class AppConstants {
  static const String appName = 'linkpc';
  static const String appVersion = '1.0.0';
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

  // Routing Modes
  static const String routeModeSmart = 'smart_ru_direct'; // Bypass Russian traffic
  static const String routeModeAll = 'route_all';         // Route all traffic through tunnel
}
