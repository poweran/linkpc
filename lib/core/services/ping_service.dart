import 'dart:async';
import 'dart:io';
import '../models/vpn_state.dart';
import 'vpn_service.dart';

class PingService {
  static const String host = '188.120.249.117';
  static const int port = 443;

  /// Fast, reliable latency check that never hangs or downloads large payloads.
  /// Uses lightweight HTTP HEAD and generate_204 probes.
  static Future<int> checkLatency() async {
    final sw = Stopwatch()..start();

    // Probe 1: Fast HEAD request to the gateway management host
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 1500)
        ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

      if (VpnService.status.isConnected) {
        client.findProxy = (uri) => 'PROXY 127.0.0.1:2080';
      }

      final req = await client
          .openUrl('HEAD', Uri.parse('https://vless.linkpc.net/api/status'))
          .timeout(const Duration(milliseconds: 1500));
      final res = await req.close().timeout(const Duration(milliseconds: 1500));
      await res.drain();
      sw.stop();
      client.close();
      return sw.elapsedMilliseconds;
    } catch (_) {}

    // Probe 2: Standard generate_204 probe (0-byte payload)
    try {
      sw.reset();
      sw.start();
      final client = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 1500);

      if (VpnService.status.isConnected) {
        client.findProxy = (uri) => 'PROXY 127.0.0.1:2080';
      }

      final req = await client
          .getUrl(Uri.parse('https://cp.cloudflare.com/generate_204'))
          .timeout(const Duration(milliseconds: 1500));
      final res = await req.close().timeout(const Duration(milliseconds: 1500));
      await res.drain();
      sw.stop();
      client.close();
      return sw.elapsedMilliseconds;
    } catch (_) {}

    // Probe 3: Raw TCP socket probe as last resort
    try {
      sw.reset();
      sw.start();
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 1500),
      );
      sw.stop();
      await socket.close();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return -1;
    }
  }
}
