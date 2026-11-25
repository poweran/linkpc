import 'dart:async';
import 'dart:io';
import '../models/vpn_state.dart';
import 'ping_service.dart';
import 'vpn_service.dart';

class SpeedTestProgress {
  final double currentMbps;
  final double progress; // 0.0 to 1.0
  final bool isRunning;
  final String statusText;
  final int? latencyMs;
  final int? jitterMs;

  const SpeedTestProgress({
    this.currentMbps = 0.0,
    this.progress = 0.0,
    this.isRunning = false,
    this.statusText = '',
    this.latencyMs,
    this.jitterMs,
  });
}

class SpeedTestResult {
  final double downloadSpeedMbps;
  final int latencyMs;
  final int jitterMs;
  final DateTime timestamp;

  const SpeedTestResult({
    required this.downloadSpeedMbps,
    required this.latencyMs,
    this.jitterMs = 0,
    required this.timestamp,
  });

  String get formattedMbps => '${downloadSpeedMbps.toStringAsFixed(1)} Мбит/с';
  String get formattedMBps => '${(downloadSpeedMbps / 8).toStringAsFixed(1)} МБ/с';
}

class SpeedTestService {
  static SpeedTestResult? lastResult;

  /// Runs an active download speed test through the encrypted tunnel.
  /// Measures latency, jitter and bandwidth throughput.
  static Future<SpeedTestResult?> runTest({
    required Function(SpeedTestProgress) onProgress,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4)
      ..userAgent =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

    if ((Platform.isWindows || Platform.isMacOS || Platform.isLinux) && VpnService.status.isConnected) {
      client.findProxy = (uri) => 'PROXY 127.0.0.1:2080; DIRECT';
    }

    onProgress(const SpeedTestProgress(
      isRunning: true,
      progress: 0.05,
      statusText: 'Калибровка канала...',
    ));

    // Phase 1: High-precision real-time Latency & Jitter measurement
    final pingRes = await PingService.measureLatencyAndJitter(probeCount: 3);
    final measuredLatency = pingRes?.latencyMs ?? 0;
    final measuredJitter = pingRes?.jitterMs ?? 0;

    onProgress(SpeedTestProgress(
      isRunning: true,
      progress: 0.15,
      statusText: 'Тестирование входящей линии...',
      latencyMs: measuredLatency > 0 ? measuredLatency : null,
      jitterMs: measuredJitter > 0 ? measuredJitter : null,
    ));

    final testUrls = [
      'https://speed.cloudflare.com/__down?bytes=10485760',
      'https://vless.linkpc.net/downloads/sing-box',
    ];

    for (final testUrl in testUrls) {
      final sw = Stopwatch()..start();
      int receivedBytes = 0;
      const targetBytes = 10485760; // 10 MB payload target
      int lastReportMs = 0;

      try {
        final req = await client.getUrl(Uri.parse(testUrl)).timeout(const Duration(seconds: 4));
        req.headers.set(HttpHeaders.userAgentHeader,
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36');
        final res = await req.close().timeout(const Duration(seconds: 4));

        if (res.statusCode != 200 && res.statusCode != 206) {
          throw HttpException('Статус сервера: ${res.statusCode}');
        }

        final responseLatency = sw.elapsedMilliseconds;
        final finalLatency = measuredLatency > 0 ? measuredLatency : responseLatency;
        sw.reset();
        sw.start();

        await for (final chunk in res) {
          receivedBytes += chunk.length;
          final elapsedMs = sw.elapsedMilliseconds;
          if (elapsedMs - lastReportMs > 150 && elapsedMs > 50) {
            lastReportMs = elapsedMs;
            final elapsedSec = elapsedMs / 1000.0;
            final currentMbps = (receivedBytes * 8.0 / (1000 * 1000)) / elapsedSec;
            final prog = (0.15 + (receivedBytes / targetBytes) * 0.85).clamp(0.15, 0.98);
            onProgress(SpeedTestProgress(
              isRunning: true,
              currentMbps: currentMbps,
              progress: prog,
              statusText: '${currentMbps.toStringAsFixed(1)} Мбит/с',
              latencyMs: finalLatency > 0 ? finalLatency : null,
              jitterMs: measuredJitter > 0 ? measuredJitter : null,
            ));
          }

          if (receivedBytes >= targetBytes) {
            break;
          }
        }

        sw.stop();
        final totalSec = sw.elapsedMilliseconds / 1000.0;
        final finalMbps = totalSec > 0.05
            ? (receivedBytes * 8.0 / (1000 * 1000)) / totalSec
            : 0.0;

        final resObj = SpeedTestResult(
          downloadSpeedMbps: finalMbps,
          latencyMs: finalLatency,
          jitterMs: measuredJitter,
          timestamp: DateTime.now(),
        );
        lastResult = resObj;

        onProgress(SpeedTestProgress(
          isRunning: false,
          currentMbps: finalMbps,
          progress: 1.0,
          statusText: '${finalMbps.toStringAsFixed(1)} Мбит/с',
          latencyMs: finalLatency,
          jitterMs: measuredJitter,
        ));

        client.close();
        return resObj;
      } catch (e) {
        VpnService.log('[SpeedTest]: Ошибка загрузки $testUrl -> $e');
        if (testUrl != testUrls.last) {
          continue;
        }
        onProgress(SpeedTestProgress(
          isRunning: false,
          statusText: 'Ошибка замера: $e',
          latencyMs: measuredLatency > 0 ? measuredLatency : null,
          jitterMs: measuredJitter > 0 ? measuredJitter : null,
        ));
      }
    }

    client.close();
    return null;
  }
}
