import 'dart:async';
import 'dart:io';

class PingService {
  static const String host = '188.120.249.117';
  static const int port = 443;

  static Future<int> checkLatency() async {
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 3),
      );
      sw.stop();
      await socket.close();
      return sw.elapsedMilliseconds;
    } catch (e) {
      // Fallback via HTTPS probe
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 3)
          ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
        sw.reset();
        sw.start();
        final req = await client.getUrl(Uri.parse('https://vless.linkpc.net/'));
        final res = await req.close();
        await res.drain();
        sw.stop();
        return sw.elapsedMilliseconds;
      } catch (_) {
        return -1; // Offline / error
      }
    }
  }
}
