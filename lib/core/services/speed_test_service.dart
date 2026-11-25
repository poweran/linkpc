import 'dart:async';
import 'dart:io';
import 'dart:math';
import '../models/vpn_state.dart';
import 'ping_service.dart';
import 'vpn_service.dart';

class SpeedTestProgress {
  final double currentMbps;
  final double progress; // 0.0 to 1.0
  final bool isRunning;
  final String statusText;
  final int? downLatencyMs;
  final int? downJitterMs;
  final int? upLatencyMs;
  final int? upJitterMs;

  /// Обратная совместимость с кодом, ожидающим latencyMs / jitterMs
  int? get latencyMs => downLatencyMs;
  int? get jitterMs => downJitterMs;

  const SpeedTestProgress({
    this.currentMbps = 0.0,
    this.progress = 0.0,
    this.isRunning = false,
    this.statusText = '',
    this.downLatencyMs,
    this.downJitterMs,
    this.upLatencyMs,
    this.upJitterMs,
  });
}

class SpeedTestResult {
  final double downloadSpeedMbps;
  final int downLatencyMs;
  final int downJitterMs;
  final int upLatencyMs;
  final int upJitterMs;
  final DateTime timestamp;

  /// Обратная совместимость
  int get latencyMs => downLatencyMs;
  int get jitterMs => downJitterMs;

  const SpeedTestResult({
    required this.downloadSpeedMbps,
    required this.downLatencyMs,
    this.downJitterMs = 0,
    required this.upLatencyMs,
    this.upJitterMs = 0,
    required this.timestamp,
  });

  String get formattedMbps => '${downloadSpeedMbps.toStringAsFixed(1)} Мбит/с';
  String get formattedMBps => '${(downloadSpeedMbps / 8).toStringAsFixed(1)} МБ/с';
}

class SpeedTestService {
  static SpeedTestResult? lastResult;

  /// Выполняет активный тест скорости через зашифрованный туннель.
  /// Калибрует задержку и джиттер для входящего и исходящего каналов.
  static Future<SpeedTestResult?> runTest({
    required Function(SpeedTestProgress) onProgress,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..userAgent =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

    // Route speed test through the active sing-box tunnel via 127.0.0.1:2080 on all platforms.
    // On Android, the app package is excluded from the OS TUN interface to avoid VPN loops,
    // so routing via localhost mixed-proxy is strictly required to measure the true encrypted tunnel speed.
    if (VpnService.status.isConnected) {
      client.findProxy = (uri) => 'PROXY 127.0.0.1:2080; DIRECT';
    }

    onProgress(const SpeedTestProgress(
      isRunning: true,
      progress: 0.05,
      statusText: 'Калибровка канала...',
    ));

    // Фаза 1: Высокоточный замер RTT и Jitter для входящего и исходящего направлений
    final pingRes = await PingService.measureLatencyAndJitter(probeCount: 3);
    final downLatency = pingRes?.downLatencyMs ?? 0;
    final downJitter = pingRes?.downJitterMs ?? 0;
    final upLatency = pingRes?.upLatencyMs ?? downLatency;
    final upJitter = pingRes?.upJitterMs ?? downJitter;

    onProgress(SpeedTestProgress(
      isRunning: true,
      progress: 0.15,
      statusText: 'Тестирование входящей линии...',
      downLatencyMs: downLatency > 0 ? downLatency : null,
      downJitterMs: downJitter > 0 ? downJitter : null,
      upLatencyMs: upLatency > 0 ? upLatency : null,
      upJitterMs: upJitter > 0 ? upJitter : null,
    ));

    final testUrls = [
      'https://speed.cloudflare.com/__down?bytes=5242880',
      'https://speed.cloudflare.com/__down?bytes=10485760',
      'https://vless.linkpc.net/downloads/sing-box',
    ];

    for (final testUrl in testUrls) {
      final sw = Stopwatch()..start();
      int receivedBytes = 0;
      const targetBytes = 5242880; // 5 MB payload target (speed.cloudflare.com baseline)
      int lastReportMs = 0;

      try {
        final req = await client.getUrl(Uri.parse(testUrl)).timeout(const Duration(seconds: 8));
        req.headers.set(HttpHeaders.userAgentHeader,
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36');
        req.headers.set(HttpHeaders.acceptHeader, '*/*');
        req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache, no-store');
        final res = await req.close().timeout(const Duration(seconds: 8));

        if (res.statusCode != 200 && res.statusCode != 206) {
          throw HttpException('Статус сервера: ${res.statusCode}');
        }

        final responseLatency = sw.elapsedMilliseconds;
        final finalDownLatency = downLatency > 0 ? downLatency : responseLatency;
        final finalUpLatency = upLatency > 0 ? upLatency : finalDownLatency;
        sw.reset();
        sw.start();

        await for (final chunk in res) {
          receivedBytes += chunk.length;
          final elapsedMs = sw.elapsedMilliseconds;
          if (elapsedMs - lastReportMs > 150 && elapsedMs > 50) {
            lastReportMs = elapsedMs;
            final elapsedSec = elapsedMs / 1000.0;
            final currentMbps = (receivedBytes * 8.0 / (1000 * 1000)) / elapsedSec;
            final timeProg = elapsedMs / 7000.0;
            final bytesProg = receivedBytes / targetBytes;
            final prog = (0.15 + max(timeProg, bytesProg) * 0.85).clamp(0.15, 0.98);
            onProgress(SpeedTestProgress(
              isRunning: true,
              currentMbps: currentMbps,
              progress: prog,
              statusText: '${currentMbps.toStringAsFixed(1)} Мбит/с',
              downLatencyMs: finalDownLatency > 0 ? finalDownLatency : null,
              downJitterMs: downJitter > 0 ? downJitter : null,
              upLatencyMs: finalUpLatency > 0 ? finalUpLatency : null,
              upJitterMs: upJitter > 0 ? upJitter : null,
            ));
          }

          // Stop after 7 seconds of streaming or when target bytes are reached
          if (elapsedMs >= 7000 || receivedBytes >= targetBytes) {
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
          downLatencyMs: finalDownLatency,
          downJitterMs: downJitter,
          upLatencyMs: finalUpLatency,
          upJitterMs: upJitter,
          timestamp: DateTime.now(),
        );
        lastResult = resObj;

        onProgress(SpeedTestProgress(
          isRunning: false,
          currentMbps: finalMbps,
          progress: 1.0,
          statusText: '${finalMbps.toStringAsFixed(1)} Мбит/с',
          downLatencyMs: finalDownLatency,
          downJitterMs: downJitter,
          upLatencyMs: finalUpLatency,
          upJitterMs: upJitter,
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
          downLatencyMs: downLatency > 0 ? downLatency : null,
          downJitterMs: downJitter > 0 ? downJitter : null,
          upLatencyMs: upLatency > 0 ? upLatency : null,
          upJitterMs: upJitter > 0 ? upJitter : null,
        ));
      }
    }

    client.close();
    return null;
  }
}
