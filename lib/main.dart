import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'app.dart';
import 'core/services/api_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/vpn_service.dart';

class LinkpcHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        if (host == 'vless.linkpc.net' || host == '188.120.249.117' || host.endsWith('linkpc.net')) {
          return true;
        }
        return false;
      };
  }
}

void main() async {
  HttpOverrides.global = LinkpcHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize persistence & VPN service
  await StorageService.init();
  VpnService.init();

  // Ensure system proxy is reverted when application exits
  if (!Platform.isWindows && !Platform.isAndroid && !Platform.isIOS) {
    try {
      ProcessSignal.sigint.watch().listen((_) async {
        await VpnService.stopTunnel();
        exit(0);
      });
      ProcessSignal.sigterm.watch().listen((_) async {
        await VpnService.stopTunnel();
        exit(0);
      });
    } catch (_) {}
  }

  AppLifecycleListener(
    onExitRequested: () async {
      await VpnService.stopTunnel();
      return AppExitResponse.exit;
    },
  );

  // Listen to deep links: linkpc://sub?url=...
  _initDeepLinks();

  runApp(const LinkpcApp());
}

void _initDeepLinks() {
  try {
    final appLinks = AppLinks();

    // Cold start link
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleIncomingUri(uri);
    });

    // Foreground / runtime link
    appLinks.uriLinkStream.listen((uri) {
      _handleIncomingUri(uri);
    });
  } catch (e) {
    debugPrint('Deep links init error: $e');
  }
}

void _handleIncomingUri(Uri uri) {
  if (uri.scheme == 'linkpc') {
    final subUrl = uri.queryParameters['url'];
    final token = uri.queryParameters['token'];
    final target = subUrl ?? token;
    if (target != null && target.isNotEmpty) {
      final clean = ApiService.normalizeToken(target);
      StorageService.saveToken(clean);
      ApiService.fetchProfile(clean);
    }
  }
}
