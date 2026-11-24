import 'dart:async';
import 'dart:io';
import '../models/vpn_state.dart';
import 'vpn_service.dart';

class SpeedTestProgress {
  final double currentMbps;
  final double progress; // 0.0 to 1.0
  final bool isRunning;
  final String statusText;

  const SpeedTestProgress({
    this.currentMbps = 0.0,
    this.progress = 0.0,
    this.isRunning = false,
    this.statusText = '',
  });
}

class SpeedTestResult {
  final double downloadSpeedMbps;
  final int latencyMs;
  final DateTime timestamp;

  const SpeedTestResult({
    required this.downloadSpeedMbps,
    required this.latencyMs,
    required this.timestamp,
  });

  String get formattedMbps => '${downloadSpeedMbps.toStringAsFixed(1)} Мбит/с';
  String get formattedMBps => '${(downloadSpeedMbps / 8).toStringAsFixed(1)} МБ/с';
}

class SpeedTestService {
  static SpeedTestResult? lastResult;

  /// Runs an active download speed test through the sing-box encrypted tunnel (127.0.0.1:2080).
  /// Streams progress updates to [onProgress].
  static Future<SpeedTestResult?> runTest({
    required Function(SpeedTestProgress) onProgress,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4)
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

    if (VpnService.status.isConnected) {
      client.findProxy = (uri) => 'PROXY 127.0.0.1:2080; DIRECT';
    }

    onProgress(const SpeedTestProgress(
      isRunning: true,
      progress: 0.05,
      statusText: 'Подключение к тестовому узлу...',
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
        final res = await req.close().timeout(const Duration(seconds: 4));

        if (res.statusCode != 200 && res.statusCode != 206) {
          throw HttpException('Статус сервера: ${res.statusCode}');
        }

        final latencyMs = sw.elapsedMilliseconds;
        sw.reset();
        sw.start();

        await for (final chunk in res) {
          receivedBytes += chunk.length;
          final elapsedMs = sw.elapsedMilliseconds;
          if (elapsedMs - lastReportMs > 180 && elapsedMs > 50) {
            lastReportMs = elapsedMs;
            final elapsedSec = elapsedMs / 1000.0;
            final currentMbps = (receivedBytes * 8.0 / (1024 * 1024)) / elapsedSec;
            final prog = (receivedBytes / targetBytes).clamp(0.05, 0.95);
            onProgress(SpeedTestProgress(
              isRunning: true,
              currentMbps: currentMbps,
              progress: prog,
              statusText: '${currentMbps.toStringAsFixed(1)} Мбит/с',
            ));
          }

          // Complete test early once target bytes are reached
          if (receivedBytes >= targetBytes) {
            break;
          }
        }

        sw.stop();
        final totalSec = sw.elapsedMilliseconds / 1000.0;
        final finalMbps = totalSec > 0.05
            ? (receivedBytes * 8.0 / (1024 * 1024)) / totalSec
            : 0.0;

        final resObj = SpeedTestResult(
          downloadSpeedMbps: finalMbps,
          latencyMs: latencyMs,
          timestamp: DateTime.now(),
        );
        lastResult = resObj;

        onProgress(SpeedTestProgress(
          isRunning: false,
          currentMbps: finalMbps,
          progress: 1.0,
          statusText: '${finalMbps.toStringAsFixed(1)} Мбит/с',
        ));

        client.close();
        return resObj;
      } catch (e) {
        VpnService.log('[SpeedTest]: Ошибка загрузки $testUrl -> $e');
        // Try fallback testUrl if available
        if (testUrl != testUrls.last) {
          continue;
        }
        onProgress(SpeedTestProgress(
          isRunning: false,
          statusText: 'Ошибка замера: $e',
        ));
      }
    }

    client.close();
    return null;
  }
}
