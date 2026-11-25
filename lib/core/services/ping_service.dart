import 'dart:async';
import 'dart:io';
import 'dart:math';
import '../models/vpn_state.dart';
import 'vpn_service.dart';

class PingResult {
  final int latencyMs;
  final int jitterMs;

  const PingResult({
    required this.latencyMs,
    required this.jitterMs,
  });

  static const PingResult zero = PingResult(latencyMs: 0, jitterMs: 0);
}

class PingService {
  static const String host = '188.120.249.117';
  static const int port = 443;

  static PingResult? lastResult;

  /// Fast, accurate network probe measuring true Round-Trip Time (Latency) and Jitter (RFC 3550).
  /// Performs consecutive lightweight zero-byte probes to measure delay variance.
  static Future<PingResult?> measureLatencyAndJitter({int probeCount = 3}) async {
    final samples = <int>[];

    for (int i = 0; i < probeCount; i++) {
      final sample = await _singleProbe();
      if (sample > 0) {
        samples.add(sample);
      }
      if (i < probeCount - 1) {
        await Future.delayed(const Duration(milliseconds: 30));
      }
    }

    if (samples.isEmpty) {
      return null;
    }

    // Minimum latency represents true physical RTT without transient queuing delay
    final minLatency = samples.reduce(min);

    // Jitter calculation: average absolute difference between consecutive packets
    int jitter = 0;
    if (samples.length > 1) {
      int sumDiff = 0;
      for (int i = 1; i < samples.length; i++) {
        sumDiff += (samples[i] - samples[i - 1]).abs();
      }
      jitter = (sumDiff / (samples.length - 1)).round();
    }

    final res = PingResult(latencyMs: minLatency, jitterMs: jitter);
    lastResult = res;
    return res;
  }

  /// Backward-compatible single latency check.
  static Future<int> checkLatency() async {
    final res = await measureLatencyAndJitter(probeCount: 2);
    return res?.latencyMs ?? -1;
  }

  static Future<int> _singleProbe() async {
    final sw = Stopwatch()..start();

    // Strategy 1: Fast HTTP generate_204 probe
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 1200)
        ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

      // On desktop platforms with mixed proxy enabled, route via 127.0.0.1:2080
      if ((Platform.isWindows || Platform.isMacOS || Platform.isLinux) && VpnService.status.isConnected) {
        client.findProxy = (uri) => 'PROXY 127.0.0.1:2080; DIRECT';
      }

      final req = await client
          .getUrl(Uri.parse('https://cp.cloudflare.com/generate_204'))
          .timeout(const Duration(milliseconds: 1200));
      final res = await req.close().timeout(const Duration(milliseconds: 1200));
      await res.drain();
      sw.stop();
      client.close();
      return sw.elapsedMilliseconds;
    } catch (_) {}

    // Strategy 2: Fast secondary Google connectivity probe
    try {
      sw.reset();
      sw.start();
      final client = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 1200)
        ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

      if ((Platform.isWindows || Platform.isMacOS || Platform.isLinux) && VpnService.status.isConnected) {
        client.findProxy = (uri) => 'PROXY 127.0.0.1:2080; DIRECT';
      }

      final req = await client
          .getUrl(Uri.parse('https://connectivitycheck.gstatic.com/generate_204'))
          .timeout(const Duration(milliseconds: 1200));
      final res = await req.close().timeout(const Duration(milliseconds: 1200));
      await res.drain();
      sw.stop();
      client.close();
      return sw.elapsedMilliseconds;
    } catch (_) {}

    // Strategy 3: Direct TCP socket connect to the gateway server
    try {
      sw.reset();
      sw.start();
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 1200),
      );
      sw.stop();
      await socket.close();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return -1;
    }
  }
}
