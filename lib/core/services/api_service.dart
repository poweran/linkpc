import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../constants/app_constants.dart';
import '../models/user_profile.dart';
import 'storage_service.dart';

class ApiService {
  static http.Client get _httpClient {
    final io = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        if (host == 'vless.linkpc.net' || host == '188.120.249.117' || host.endsWith('linkpc.net')) {
          return true;
        }
        return false;
      };
    return IOClient(io);
  }

  static String normalizeToken(String input) {
    var raw = input.trim();
    if (raw.startsWith('linkpc://sub?url=')) {
      raw = Uri.decodeComponent(raw.replaceFirst('linkpc://sub?url=', ''));
    }
    if (raw.contains('/sub/')) {
      final uri = Uri.tryParse(raw);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final idx = uri.pathSegments.indexOf('sub');
        if (idx >= 0 && idx + 1 < uri.pathSegments.length) {
          return uri.pathSegments[idx + 1];
        }
      }
    }
    return raw;
  }

  static String buildSubscriptionUrl(String token) {
    final cleanToken = normalizeToken(token);
    return '${AppConstants.defaultBaseUrl}${AppConstants.subscriptionPath}$cleanToken?format=singbox';
  }

  /// Downloads live sing-box JSON configuration from vless.linkpc.net
  static Future<UserProfile> fetchProfile(String token) async {
    final cleanToken = normalizeToken(token);
    final url = buildSubscriptionUrl(cleanToken);

    final client = _httpClient;
    http.Response response;
    try {
      response = await client.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'linkpc-client/${AppConstants.appVersion}',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
    } finally {
      client.close();
    }

    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки профиля: HTTP ${response.statusCode}');
    }

    final rawJson = response.body;
    if (!rawJson.contains('{') || !rawJson.contains('outbounds')) {
      throw Exception('Неверный формат ответа конфигурации');
    }

    // Cache the config for offline starts
    await StorageService.setCachedConfig(rawJson);
    await StorageService.saveToken(cleanToken);

    // Parse userinfo header if present
    // Example: "upload=1024; download=2048; total=107374182400; expire=1735689600"
    double usedGb = 0.0;
    double totalGb = 100.0;
    DateTime? expires;
    final userInfo = response.headers['subscription-userinfo'];
    if (userInfo != null) {
      final parts = userInfo.split(';');
      int up = 0;
      int down = 0;
      int tot = 0;
      int exp = 0;
      for (final part in parts) {
        final kv = part.trim().split('=');
        if (kv.length == 2) {
          final k = kv[0].trim();
          final v = int.tryParse(kv[1].trim()) ?? 0;
          if (k == 'upload') up = v;
          if (k == 'download') down = v;
          if (k == 'total') tot = v;
          if (k == 'expire') exp = v;
        }
      }
      usedGb = (up + down) / (1024 * 1024 * 1024);
      if (tot > 0) {
        totalGb = tot / (1024 * 1024 * 1024);
      }
      if (exp > 0) {
        expires = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }
    }

    // Extract client name from first outbound tag
    String clientName = 'Защищенный шлюз';
    try {
      final decoded = json.decode(rawJson) as Map<String, dynamic>;
      final outbounds = decoded['outbounds'] as List<dynamic>?;
      if (outbounds != null && outbounds.isNotEmpty) {
        final first = outbounds.first as Map<String, dynamic>;
        clientName = first['tag'] ?? 'linkpc Moscow Gateway';
      }
    } catch (_) {}

    return UserProfile(
      token: cleanToken,
      clientName: clientName,
      planName: 'Выделенный XHTTP канал',
      trafficUsedGb: usedGb,
      trafficTotalGb: totalGb,
      expiresAt: expires,
      rawSingboxConfig: rawJson,
    );
  }
}
