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

/// High-Precision Network Latency and Jitter Engine matching speed.cloudflare.com:
/// 1. Uses official Cloudflare Speed Test zero-byte probe: https://speed.cloudflare.com/__down?bytes=0
/// 2. Uses persistent HTTP/1.1 Keep-Alive connections to isolate pure network Round-Trip Time (RTT).
/// 3. Extracts server-side execution timing via Server-Timing header (cfReqDur / cfSpeedEdge / cfSpeedWorker).
/// 4. Computes Median Latency (ignoring transient OS spikes) and Consecutive Difference Jitter (RFC 3550).
class PingService {
  static PingResult? lastResult;

  static HttpClient? _persistentClient;
  static bool? _lastConnectedState;

  /// Resets the persistent HTTP client (e.g. when VPN tunnel toggles)
  static void resetClient() {
    _persistentClient?.close(force: true);
    _persistentClient = null;
    _lastConnectedState = null;
  }

  static HttpClient _getClient() {
    final isConnected = VpnService.status.isConnected;
    if (_persistentClient != null && _lastConnectedState == isConnected) {
      return _persistentClient!;
    }
    _persistentClient?.close(force: true);
    _lastConnectedState = isConnected;
    _persistentClient = HttpClient()
      ..idleTimeout = const Duration(seconds: 30)
      ..connectionTimeout = const Duration(milliseconds: 2500)
      ..badCertificateCallback = ((cert, host, port) => true);

    // On desktop platforms with mixed proxy enabled, route via 127.0.0.1:2080
    if ((Platform.isWindows || Platform.isMacOS || Platform.isLinux) && isConnected) {
      _persistentClient!.findProxy = (uri) => 'PROXY 127.0.0.1:2080; DIRECT';
    } else {
      _persistentClient!.findProxy = null;
    }

    return _persistentClient!;
  }

  /// Measures Latency & Jitter exactly as speed.cloudflare.com does.
  static Future<PingResult?> measureLatencyAndJitter({int probeCount = 5}) async {
    final client = _getClient();
    final rawSamples = <double>[];

    // Warm-up probe: Establishes TCP 3-way handshake + TLS 1.3 session so subsequent probes measure pure RTT
    await _singleCloudflareProbe(client, isWarmup: true);

    // Consecutive measurements across the persistent connection
    for (int i = 0; i < probeCount; i++) {
      final rtt = await _singleCloudflareProbe(client, isWarmup: false);
      if (rtt != null && rtt > 0) {
        rawSamples.add(rtt);
      }
      if (i < probeCount - 1) {
        await Future.delayed(const Duration(milliseconds: 25));
      }
    }

    // Fallback probe to cp.cloudflare.com if speed.cloudflare.com was blocked
    if (rawSamples.isEmpty) {
      final fallbackRtt = await _fallbackProbe(client);
      if (fallbackRtt != null && fallbackRtt > 0) {
        rawSamples.add(fallbackRtt);
      }
    }

    if (rawSamples.isEmpty) {
      return null;
    }

    // 1. Jitter calculation (Cloudflare algorithm / RFC 3550):
    // Mean of absolute differences between consecutive measurements
    double jitter = 0.0;
    if (rawSamples.length > 1) {
      double sumDiff = 0.0;
      for (int i = 1; i < rawSamples.length; i++) {
        sumDiff += (rawSamples[i] - rawSamples[i - 1]).abs();
      }
      jitter = sumDiff / (rawSamples.length - 1);
    }

    // 2. Latency calculation (Cloudflare algorithm):
    // Median of samples to eliminate queuing outliers
    final sorted = List<double>.from(rawSamples)..sort();
    final medianLatency = sorted[sorted.length ~/ 2];

    final res = PingResult(
      latencyMs: max(1, medianLatency.round()),
      jitterMs: max(0, jitter.round()),
    );
    lastResult = res;
    return res;
  }

  /// Backward-compatible single latency check.
  static Future<int> checkLatency() async {
    final res = await measureLatencyAndJitter(probeCount: 3);
    return res?.latencyMs ?? -1;
  }

  /// Extracts server processing time reported by Cloudflare in the Server-Timing header.
  /// Matches cfGetServerTime from @cloudflare/speedtest:
  /// First checks cfReqDur / cfRequestDuration, otherwise sums cfSpeed* entries.
  static double _extractServerTime(String? serverTiming) {
    if (serverTiming == null || serverTiming.isEmpty) return 0.0;
    final re = RegExp(r'(?:^|,\s*)cfReq(?:uest)?Dur(?:ation)?;\s*dur=([0-9.]+)', caseSensitive: false)
        .firstMatch(serverTiming);
    if (re != null) {
      final val = double.tryParse(re.group(1) ?? '0') ?? 0.0;
      if (val > 0.01) return val;
    }
    double sum = 0.0;
    final matches = RegExp(r'(?:^|,\s*)cfSpeed[a-zA-Z]*;\s*dur=([0-9.]+)', caseSensitive: false)
        .allMatches(serverTiming);
    for (final m in matches) {
      sum += double.tryParse(m.group(1) ?? '0') ?? 0.0;
    }
    return sum > 0.01 ? sum : 0.0;
  }

  /// Performs a single 0-byte HTTP request against the Cloudflare Speed Test backend.
  /// Deducts server-side execution time via Server-Timing header matching Cloudflare Speedtest.
  static Future<double?> _singleCloudflareProbe(HttpClient client, {required bool isWarmup}) async {
    final sw = Stopwatch()..start();
    try {
      final uri = Uri.parse('https://speed.cloudflare.com/__down?bytes=0');
      final req = await client.getUrl(uri).timeout(const Duration(milliseconds: 2000));

      req.headers.set(HttpHeaders.userAgentHeader,
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36');
      req.headers.set(HttpHeaders.acceptHeader, '*/*');
      req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache, no-store, must-revalidate');
      req.headers.set('Pragma', 'no-cache');

      final res = await req.close().timeout(const Duration(milliseconds: 2000));
      await res.drain();
      sw.stop();

      if (res.statusCode != 200) {
        return null;
      }

      if (isWarmup) {
        return null; // Discard connection initialization overhead
      }

      final elapsedMs = sw.elapsedMicroseconds / 1000.0;
      final serverTiming = res.headers.value('server-timing') ?? res.headers.value('Server-Timing');
      final serverTime = _extractServerTime(serverTiming);

      double ping = elapsedMs - serverTime;
      if (ping <= 1.0) {
        ping = max(1.0, elapsedMs - (serverTime > 0 && serverTime < elapsedMs ? serverTime : 0.0));
      }

      return ping;
    } catch (_) {
      return null;
    }
  }

  /// Secondary fallback probe to Cloudflare edge generate_204 endpoint.
  static Future<double?> _fallbackProbe(HttpClient client) async {
    final sw = Stopwatch()..start();
    try {
      final uri = Uri.parse('https://cp.cloudflare.com/generate_204');
      final req = await client.getUrl(uri).timeout(const Duration(milliseconds: 2000));
      req.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)');
      final res = await req.close().timeout(const Duration(milliseconds: 2000));
      await res.drain();
      sw.stop();
      return res.statusCode == 204 ? sw.elapsedMicroseconds / 1000.0 : null;
    } catch (_) {
      return null;
    }
  }
}
