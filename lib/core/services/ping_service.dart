import 'dart:async';
import 'dart:io';
import 'dart:math';
import '../models/vpn_state.dart';
import 'vpn_service.dart';

class PingResult {
  /// Downstream (входящий) сетевой RTT и джиттер
  final int downLatencyMs;
  final int downJitterMs;

  /// Upstream (исходящий) сетевой RTT и джиттер
  final int upLatencyMs;
  final int upJitterMs;

  /// Обратная совместимость с компонентами, ожидающими latencyMs / jitterMs
  int get latencyMs => downLatencyMs;
  int get jitterMs => downJitterMs;

  const PingResult({
    required this.downLatencyMs,
    required this.downJitterMs,
    required this.upLatencyMs,
    required this.upJitterMs,
  });

  static const PingResult zero = PingResult(
    downLatencyMs: 0,
    downJitterMs: 0,
    upLatencyMs: 0,
    upJitterMs: 0,
  );

  @override
  String toString() =>
      'PingResult(down: ${downLatencyMs}ms/jitter:${downJitterMs}ms, up: ${upLatencyMs}ms/jitter:${upJitterMs}ms)';
}

/// Высокоточный движок сетевых замеров по методологии speed.cloudflare.com:
/// 1. Входящий канал (Downstream): 0-byte GET на https://speed.cloudflare.com/__down?bytes=0
/// 2. Исходящий канал (Upstream): 0-byte POST на https://speed.cloudflare.com/__up
/// 3. Постоянное HTTP/1.1 Keep-Alive соединение для изоляции чистого сетевого RTT без handshake.
/// 4. Извлечение серверного времени исполнения через заголовок Server-Timing.
/// 5. Расчет задержки (медиана) и джиттера (RFC 3550) для обоих направлений трафика.
class PingService {
  static const String _cfSpeedDownEndpoint = 'https://speed.cloudflare.com/__down?bytes=0';
  static const String _cfSpeedUpEndpoint = 'https://speed.cloudflare.com/__up';
  static const String _cfGen204Endpoint = 'https://cp.cloudflare.com/generate_204';

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  static PingResult? lastResult;

  static HttpClient? _persistentClient;
  static bool? _lastConnectedState;

  /// Сброс HTTP-клиента при переключении состояния VPN
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

    // На десктопных платформах с включенным mixed proxy направляем через 127.0.0.1:2080
    if ((Platform.isWindows || Platform.isMacOS || Platform.isLinux) && isConnected) {
      _persistentClient!.findProxy = (uri) => 'PROXY 127.0.0.1:2080; DIRECT';
    } else {
      _persistentClient!.findProxy = null;
    }

    return _persistentClient!;
  }

  /// Замер входящей и исходящей задержки и джиттера по алгоритму speed.cloudflare.com
  static Future<PingResult?> measureLatencyAndJitter({int probeCount = 3}) async {
    final client = _getClient();
    final downSamples = <double>[];
    final upSamples = <double>[];

    // --- 1. Downstream (Входящий канал: GET) ---
    // Прогревочный запрос: устраняет задержку первого TCP/TLS handshake
    await _singleProbe(client, method: 'GET', url: _cfSpeedDownEndpoint, isWarmup: true);

    for (int i = 0; i < probeCount; i++) {
      final rtt = await _singleProbe(client, method: 'GET', url: _cfSpeedDownEndpoint, isWarmup: false);
      if (rtt != null && rtt > 0) {
        downSamples.add(rtt);
      }
      if (i < probeCount - 1) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }

    // --- 2. Upstream (Исходящий канал: POST 0 байт) ---
    await _singleProbe(client, method: 'POST', url: _cfSpeedUpEndpoint, isWarmup: true);

    for (int i = 0; i < probeCount; i++) {
      final rtt = await _singleProbe(client, method: 'POST', url: _cfSpeedUpEndpoint, isWarmup: false);
      if (rtt != null && rtt > 0) {
        upSamples.add(rtt);
      }
      if (i < probeCount - 1) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }

    // Fallback на cp.cloudflare.com, если основной хост заблокирован
    if (downSamples.isEmpty && upSamples.isEmpty) {
      final fallbackRtt = await _fallbackProbe(client);
      if (fallbackRtt != null && fallbackRtt > 0) {
        downSamples.add(fallbackRtt);
      }
    }

    if (downSamples.isEmpty && upSamples.isEmpty) {
      return null;
    }

    // Взаимный fallback, если одно из направлений было временно недоступно
    final effectiveDown = downSamples.isNotEmpty ? downSamples : upSamples;
    final effectiveUp = upSamples.isNotEmpty ? upSamples : effectiveDown;

    int calcLatency(List<double> samples) {
      if (samples.isEmpty) return 0;
      final sorted = List<double>.from(samples)..sort();
      final median = sorted[sorted.length ~/ 2];
      return max(1, median.round());
    }

    int calcJitter(List<double> samples) {
      if (samples.length <= 1) return 0;
      double sumDiff = 0.0;
      for (int i = 1; i < samples.length; i++) {
        sumDiff += (samples[i] - samples[i - 1]).abs();
      }
      final avg = sumDiff / (samples.length - 1);
      // Если есть микро-разброс задержки (0.05-1.0 мс), отображаем 1 мс
      if (avg > 0.05 && avg < 1.0) {
        return 1;
      }
      return max(0, avg.round());
    }

    final res = PingResult(
      downLatencyMs: calcLatency(effectiveDown),
      downJitterMs: calcJitter(effectiveDown),
      upLatencyMs: calcLatency(effectiveUp),
      upJitterMs: calcJitter(effectiveUp),
    );
    lastResult = res;
    return res;
  }

  /// Быстрый одиночный замер для обратной совместимости
  static Future<int> checkLatency() async {
    final res = await measureLatencyAndJitter(probeCount: 2);
    return res?.downLatencyMs ?? -1;
  }

  /// Парсинг времени обработки запроса на стороне серверов Cloudflare (Server-Timing)
  static double _extractServerTime(List<String>? timingHeaders) {
    if (timingHeaders == null || timingHeaders.isEmpty) return 0.0;
    final combined = timingHeaders.join(', ');

    // 1. Приоритет cfReqDur / cfRequestDuration
    final reReq = RegExp(r'(?:^|,\s*)cfReq(?:uest)?Dur(?:ation)?;\s*dur=([0-9.]+)', caseSensitive: false)
        .firstMatch(combined);
    if (reReq != null) {
      final val = double.tryParse(reReq.group(1) ?? '0') ?? 0.0;
      if (val > 0.01) return val;
    }

    // 2. Сумма cfSpeed* фаз (cfSpeedEdge, cfSpeedWorker)
    double sum = 0.0;
    final matches = RegExp(r'(?:^|,\s*)cfSpeed[a-zA-Z]*;\s*dur=([0-9.]+)', caseSensitive: false)
        .allMatches(combined);
    for (final m in matches) {
      sum += double.tryParse(m.group(1) ?? '0') ?? 0.0;
    }
    return sum > 0.01 ? sum : 0.0;
  }

  /// Одиночный 0-байтный запрос к Cloudflare Speed Test
  static Future<double?> _singleProbe(
    HttpClient client, {
    required String method,
    required String url,
    required bool isWarmup,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final uri = Uri.parse(url);
      final req = await (method == 'POST'
              ? client.postUrl(uri)
              : client.getUrl(uri))
          .timeout(const Duration(milliseconds: 2000));

      req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      req.headers.set(HttpHeaders.acceptHeader, '*/*');
      req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache, no-store, must-revalidate');
      req.headers.set('Pragma', 'no-cache');
      if (method == 'POST') {
        req.headers.set(HttpHeaders.contentLengthHeader, '0');
      }

      final res = await req.close().timeout(const Duration(milliseconds: 2000));
      await res.drain();
      sw.stop();

      if (res.statusCode != 200) {
        return null;
      }

      if (isWarmup) {
        return null; // Прогрев сокета, значение отбрасывается
      }

      final elapsedMs = sw.elapsedMicroseconds / 1000.0;
      final serverTime = _extractServerTime(res.headers['server-timing']);

      double ping = elapsedMs - serverTime;
      if (ping <= 1.0) {
        ping = max(1.0, elapsedMs - (serverTime > 0 && serverTime < elapsedMs ? serverTime : 0.0));
      }

      return ping;
    } catch (_) {
      return null;
    }
  }

  /// Запасной зонд к edge-точке cp.cloudflare.com/generate_204
  static Future<double?> _fallbackProbe(HttpClient client) async {
    final sw = Stopwatch()..start();
    try {
      final uri = Uri.parse(_cfGen204Endpoint);
      final req = await client.getUrl(uri).timeout(const Duration(milliseconds: 2000));
      req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final res = await req.close().timeout(const Duration(milliseconds: 2000));
      await res.drain();
      sw.stop();
      return res.statusCode == 204 ? sw.elapsedMicroseconds / 1000.0 : null;
    } catch (_) {
      return null;
    }
  }
}
