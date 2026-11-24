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

    // When VPN tunnel is connected, route speed test through sing-box mixed proxy (127.0.0.1:2080)
    // so traffic flows 100% through the encrypted tunnel to the server.
    if (VpnService.status.isConnected) {
      client.findProxy = (uri) => 'PROXY 127.0.0.1:2080';
    }

    onProgress(const SpeedTestProgress(
      isRunning: true,
      progress: 0.05,
      statusText: 'Подключение к тестовому узлу...',
    ));

    final sw = Stopwatch()..start();
    int receivedBytes = 0;
    const targetBytes = 10485760; // 10 MB payload

    try {
      final req = await client
          .getUrl(Uri.parse('https://speed.cloudflare.com/__down?bytes=10485760'))
          .timeout(const Duration(seconds: 6));
      final res = await req.close().timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) {
        throw HttpException('Статус сервера: ${res.statusCode}');
      }

      final latencyMs = sw.elapsedMilliseconds;
      sw.reset();
      sw.start();

      await for (final chunk in res) {
        receivedBytes += chunk.length;
        final elapsedSec = sw.elapsedMilliseconds / 1000.0;
        if (elapsedSec > 0.05) {
          final currentMbps = (receivedBytes * 8.0 / (1024 * 1024)) / elapsedSec;
          final prog = (receivedBytes / targetBytes).clamp(0.05, 0.95);
          onProgress(SpeedTestProgress(
            isRunning: true,
            currentMbps: currentMbps,
            progress: prog,
            statusText: '${currentMbps.toStringAsFixed(1)} Мбит/с',
          ));
        }
      }

      sw.stop();
      final totalSec = sw.elapsedMilliseconds / 1000.0;
      final finalMbps = totalSec > 0.1
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

      return resObj;
    } catch (e) {
      onProgress(SpeedTestProgress(
        isRunning: false,
        statusText: 'Ошибка замера: $e',
      ));
      return null;
    } finally {
      client.close();
    }
  }
}
