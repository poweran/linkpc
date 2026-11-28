import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import '../models/vpn_state.dart';
import 'ping_service.dart';
import 'vpn_service.dart';

enum SpeedTestPhase {
  calibrating,
  download,
  upload,
  completed,
  failed,
}

class SpeedTestProgress {
  final SpeedTestPhase phase;
  final double currentMbps;
  final double progress; // 0.0 to 1.0
  final bool isRunning;
  final String statusText;
  final int? downLatencyMs;
  final int? downJitterMs;
  final int? upLatencyMs;
  final int? upJitterMs;
  final double? downloadMbps;
  final double? uploadMbps;

  bool get isDownloadPhase => phase == SpeedTestPhase.download;
  bool get isUploadPhase => phase == SpeedTestPhase.upload;

  /// Обратная совместимость с кодом, ожидающим latencyMs / jitterMs
  int? get latencyMs => downLatencyMs;
  int? get jitterMs => downJitterMs;

  const SpeedTestProgress({
    this.phase = SpeedTestPhase.calibrating,
    this.currentMbps = 0.0,
    this.progress = 0.0,
    this.isRunning = false,
    this.statusText = '',
    this.downLatencyMs,
    this.downJitterMs,
    this.upLatencyMs,
    this.upJitterMs,
    this.downloadMbps,
    this.uploadMbps,
  });
}

class SpeedTestResult {
  final double downloadSpeedMbps;
  final double uploadSpeedMbps;
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
    this.uploadSpeedMbps = 0.0,
    required this.downLatencyMs,
    this.downJitterMs = 0,
    required this.upLatencyMs,
    this.upJitterMs = 0,
    required this.timestamp,
  });

  String get formattedDownloadMbps => '${downloadSpeedMbps.toStringAsFixed(1)} Мбит/с';
  String get formattedUploadMbps => '${uploadSpeedMbps.toStringAsFixed(1)} Мбит/с';

  String get formattedMbps {
    if (uploadSpeedMbps > 0) {
      return '↓ ${downloadSpeedMbps.toStringAsFixed(1)}  ↑ ${uploadSpeedMbps.toStringAsFixed(1)} Мбит/с';
    }
    return '${downloadSpeedMbps.toStringAsFixed(1)} Мбит/с';
  }

  String get formattedMBps => '${(downloadSpeedMbps / 8).toStringAsFixed(1)} МБ/с';
}

class SpeedTestService {
  static SpeedTestResult? lastResult;
  static HttpClient? _activeClient;
  static int _activeSessionId = 0;
  static bool _isCancelled = false;

  /// Отмена активного замера скорости и мгновенный разрыв всех сокетов
  static void cancelTest() {
    _isCancelled = true;
    _activeSessionId++;
    try {
      _activeClient?.close(force: true);
    } catch (_) {}
    _activeClient = null;
  }

  static bool get isTesting => _activeClient != null;

  static void _reportCancelled(Function(SpeedTestProgress) onProgress) {
    onProgress(const SpeedTestProgress(
      phase: SpeedTestPhase.failed,
      isRunning: false,
      statusText: 'Замер отменён',
    ));
  }

  /// Выполняет двухсторонний замер скорости через зашифрованный туннель:
  /// 1. Калибровка RTT и Jitter для входящего и исходящего каналов.
  /// 2. Замер скорости скачивания (входящий трафик).
  /// 3. Замер скорости загрузки (исходящий трафик).
  static Future<SpeedTestResult?> runTest({
    required Function(SpeedTestProgress) onProgress,
  }) async {
    _isCancelled = false;
    final sessionId = ++_activeSessionId;

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..userAgent =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

    // Маршрутизация через локальный mixed proxy sing-box на 127.0.0.1:2080 при активном туннеле
    if (VpnService.status.isConnected) {
      client.findProxy = (uri) => 'PROXY 127.0.0.1:2080; DIRECT';
    }

    _activeClient = client;

    try {
      if (_isCancelled || _activeSessionId != sessionId) {
        _reportCancelled(onProgress);
        return null;
      }

      onProgress(const SpeedTestProgress(
        phase: SpeedTestPhase.calibrating,
        isRunning: true,
        progress: 0.05,
        statusText: 'Калибровка канала...',
      ));

      // Фаза 1: Высокоточный замер RTT и Jitter
      final pingRes = await PingService.measureLatencyAndJitter(probeCount: 3);
      if (_isCancelled || _activeSessionId != sessionId) {
        _reportCancelled(onProgress);
        return null;
      }
      final downLatency = pingRes?.downLatencyMs ?? 0;
      final downJitter = pingRes?.downJitterMs ?? 0;
      final upLatency = pingRes?.upLatencyMs ?? downLatency;
      final upJitter = pingRes?.upJitterMs ?? downJitter;

      onProgress(SpeedTestProgress(
        phase: SpeedTestPhase.download,
        isRunning: true,
        progress: 0.15,
        statusText: 'Тестирование скачивания...',
        downLatencyMs: downLatency > 0 ? downLatency : null,
        downJitterMs: downJitter > 0 ? downJitter : null,
        upLatencyMs: upLatency > 0 ? upLatency : null,
        upJitterMs: upJitter > 0 ? upJitter : null,
      ));

      // Фаза 2: Замер скорости скачивания (Downlink)
      double finalDownMbps = 0.0;
      int finalDownLatency = downLatency;
      int finalUpLatency = upLatency;

      final downloadUrls = [
        'https://speed.cloudflare.com/__down?bytes=5242880',
        'https://speed.cloudflare.com/__down?bytes=10485760',
        'https://vless.linkpc.net/downloads/sing-box',
      ];

      for (final testUrl in downloadUrls) {
        if (_isCancelled || _activeSessionId != sessionId) break;
        final sw = Stopwatch()..start();
        int receivedBytes = 0;
        const targetBytes = 5242880; // 5 MB эталон speed.cloudflare.com
        int lastReportMs = 0;

        try {
          final req = await client.getUrl(Uri.parse(testUrl)).timeout(const Duration(seconds: 8));
          if (_isCancelled || _activeSessionId != sessionId) break;
          req.headers.set(HttpHeaders.userAgentHeader,
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36');
          req.headers.set(HttpHeaders.acceptHeader, '*/*');
          req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache, no-store');
          final res = await req.close().timeout(const Duration(seconds: 8));
          if (_isCancelled || _activeSessionId != sessionId) break;

          if (res.statusCode != 200 && res.statusCode != 206) {
            throw HttpException('Статус сервера: ${res.statusCode}');
          }

          final responseLatency = sw.elapsedMilliseconds;
          finalDownLatency = downLatency > 0 ? downLatency : responseLatency;
          finalUpLatency = upLatency > 0 ? upLatency : finalDownLatency;
          sw.reset();
          sw.start();

          await for (final chunk in res) {
            if (_isCancelled || _activeSessionId != sessionId) break;
            receivedBytes += chunk.length;
            final elapsedMs = sw.elapsedMilliseconds;
            if (elapsedMs - lastReportMs > 150 && elapsedMs > 50) {
              lastReportMs = elapsedMs;
              final elapsedSec = elapsedMs / 1000.0;
              final currentMbps = (receivedBytes * 8.0 / (1000 * 1000)) / elapsedSec;
              final timeProg = elapsedMs / 7000.0;
              final bytesProg = receivedBytes / targetBytes;
              final prog = (0.15 + max(timeProg, bytesProg) * 0.38).clamp(0.15, 0.53);
              onProgress(SpeedTestProgress(
                phase: SpeedTestPhase.download,
                isRunning: true,
                currentMbps: currentMbps,
                downloadMbps: currentMbps,
                progress: prog,
                statusText: '↓ ${currentMbps.toStringAsFixed(1)} Мбит/с',
                downLatencyMs: finalDownLatency > 0 ? finalDownLatency : null,
                downJitterMs: downJitter > 0 ? downJitter : null,
                upLatencyMs: finalUpLatency > 0 ? finalUpLatency : null,
                upJitterMs: upJitter > 0 ? upJitter : null,
              ));
            }

            if (elapsedMs >= 7000 || receivedBytes >= targetBytes) {
              break;
            }
          }

          sw.stop();
          final totalSec = sw.elapsedMilliseconds / 1000.0;
          finalDownMbps = totalSec > 0.05
              ? (receivedBytes * 8.0 / (1000 * 1000)) / totalSec
              : 0.0;
          break;
        } catch (e) {
          if (_isCancelled || _activeSessionId != sessionId) break;
          VpnService.log('[SpeedTest]: Ошибка скачивания $testUrl -> $e');
          if (testUrl == downloadUrls.last) {
            finalDownMbps = 0.0;
          }
        }
      }

      if (_isCancelled || _activeSessionId != sessionId) {
        _reportCancelled(onProgress);
        return null;
      }

      // Фаза 3: Замер скорости загрузки (Uplink)
      onProgress(SpeedTestProgress(
        phase: SpeedTestPhase.upload,
        isRunning: true,
        currentMbps: 0.0,
        downloadMbps: finalDownMbps,
        progress: 0.55,
        statusText: 'Тестирование загрузки...',
        downLatencyMs: finalDownLatency > 0 ? finalDownLatency : null,
        downJitterMs: downJitter > 0 ? downJitter : null,
        upLatencyMs: finalUpLatency > 0 ? finalUpLatency : null,
        upJitterMs: upJitter > 0 ? upJitter : null,
      ));

      double finalUpMbps = 0.0;
      final uploadUrls = [
        'https://speed.cloudflare.com/__up',
      ];

      for (final uploadUrl in uploadUrls) {
        if (_isCancelled || _activeSessionId != sessionId) break;
        final sw = Stopwatch()..start();
        int sentBytes = 0;
        const targetUploadBytes = 3145728; // 3 MB эталонная порция
        const chunkSize = 32768; // 32 KB chunk
        final chunkData = Uint8List(chunkSize);
        int lastReportMs = 0;

        try {
          final req = await client.postUrl(Uri.parse(uploadUrl)).timeout(const Duration(seconds: 8));
          if (_isCancelled || _activeSessionId != sessionId) break;
          req.headers.set(HttpHeaders.userAgentHeader,
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36');
          req.headers.set(HttpHeaders.contentTypeHeader, 'application/octet-stream');
          req.headers.set(HttpHeaders.acceptHeader, '*/*');
          req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache, no-store');
          req.headers.chunkedTransferEncoding = true;

          Stream<List<int>> uploadStream() async* {
            while (sentBytes < targetUploadBytes) {
              if (_isCancelled || _activeSessionId != sessionId) break;
              sentBytes += chunkSize;
              final elapsedMs = sw.elapsedMilliseconds;
              if (elapsedMs - lastReportMs > 150 && elapsedMs > 50) {
                lastReportMs = elapsedMs;
                final elapsedSec = elapsedMs / 1000.0;
                final currentMbps = (sentBytes * 8.0 / (1000 * 1000)) / elapsedSec;
                final timeProg = elapsedMs / 6000.0;
                final bytesProg = sentBytes / targetUploadBytes;
                final prog = (0.55 + max(timeProg, bytesProg) * 0.40).clamp(0.55, 0.95);
                onProgress(SpeedTestProgress(
                  phase: SpeedTestPhase.upload,
                  isRunning: true,
                  currentMbps: currentMbps,
                  downloadMbps: finalDownMbps,
                  uploadMbps: currentMbps,
                  progress: prog,
                  statusText: '↑ ${currentMbps.toStringAsFixed(1)} Мбит/с',
                  downLatencyMs: finalDownLatency > 0 ? finalDownLatency : null,
                  downJitterMs: downJitter > 0 ? downJitter : null,
                  upLatencyMs: finalUpLatency > 0 ? finalUpLatency : null,
                  upJitterMs: upJitter > 0 ? upJitter : null,
                ));
              }
              yield chunkData;
              if (sw.elapsedMilliseconds >= 6000) {
                break;
              }
            }
          }

          await req.addStream(uploadStream());
          if (_isCancelled || _activeSessionId != sessionId) break;
          final res = await req.close().timeout(const Duration(seconds: 8));
          await res.drain().timeout(const Duration(seconds: 3));

          if (res.statusCode != 200 && res.statusCode != 204) {
            throw HttpException('Статус сервера: ${res.statusCode}');
          }

          sw.stop();
          final totalSec = sw.elapsedMilliseconds / 1000.0;
          finalUpMbps = totalSec > 0.05
              ? (sentBytes * 8.0 / (1000 * 1000)) / totalSec
              : 0.0;
          break;
        } catch (e) {
          if (_isCancelled || _activeSessionId != sessionId) break;
          VpnService.log('[SpeedTest]: Ошибка загрузки (upload) $uploadUrl -> $e');
          finalUpMbps = 0.0;
        }
      }

      if (_isCancelled || _activeSessionId != sessionId) {
        _reportCancelled(onProgress);
        return null;
      }

      if (finalDownMbps <= 0.0 && finalUpMbps <= 0.0) {
        onProgress(SpeedTestProgress(
          phase: SpeedTestPhase.failed,
          isRunning: false,
          statusText: 'Сбой проверки соединения',
          downLatencyMs: finalDownLatency > 0 ? finalDownLatency : null,
          downJitterMs: downJitter > 0 ? downJitter : null,
          upLatencyMs: finalUpLatency > 0 ? finalUpLatency : null,
          upJitterMs: upJitter > 0 ? upJitter : null,
        ));
        return null;
      }

      final resObj = SpeedTestResult(
        downloadSpeedMbps: finalDownMbps,
        uploadSpeedMbps: finalUpMbps,
        downLatencyMs: finalDownLatency,
        downJitterMs: downJitter,
        upLatencyMs: finalUpLatency,
        upJitterMs: upJitter,
        timestamp: DateTime.now(),
      );
      lastResult = resObj;

      onProgress(SpeedTestProgress(
        phase: SpeedTestPhase.completed,
        isRunning: false,
        currentMbps: finalDownMbps,
        downloadMbps: finalDownMbps,
        uploadMbps: finalUpMbps,
        progress: 1.0,
        statusText: finalUpMbps > 0
            ? '↓ ${finalDownMbps.toStringAsFixed(1)}  ↑ ${finalUpMbps.toStringAsFixed(1)} Мбит/с'
            : '${finalDownMbps.toStringAsFixed(1)} Мбит/с',
        downLatencyMs: finalDownLatency > 0 ? finalDownLatency : null,
        downJitterMs: downJitter > 0 ? downJitter : null,
        upLatencyMs: finalUpLatency > 0 ? finalUpLatency : null,
        upJitterMs: upJitter > 0 ? upJitter : null,
      ));

      return resObj;
    } catch (e) {
      if (_isCancelled || _activeSessionId != sessionId) {
        _reportCancelled(onProgress);
        return null;
      }
      VpnService.log('[SpeedTest]: Критическая ошибка замера: $e');
      return null;
    } finally {
      try {
        client.close(force: true);
      } catch (_) {}
      if (_activeClient == client) {
        _activeClient = null;
      }
    }
  }
}
