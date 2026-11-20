import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';
import '../models/traffic_stats.dart';
import '../models/vpn_state.dart';

class VpnService {
  static const MethodChannel _channel = MethodChannel(AppConstants.tunnelChannel);
  static const EventChannel _eventChannel = EventChannel(AppConstants.eventChannel);

  static final StreamController<VpnStatus> _statusController = StreamController<VpnStatus>.broadcast();
  static final StreamController<TrafficStats> _trafficController = StreamController<TrafficStats>.broadcast();
  static final StreamController<String> _logsController = StreamController<String>.broadcast();

  static VpnStatus _currentStatus = VpnStatus.disconnected;
  static TrafficStats _currentTraffic = TrafficStats.empty();
  static Timer? _statsTimer;
  static DateTime? _connectedTimestamp;
  static Process? _desktopProcess;

  static VpnStatus get status => _currentStatus;
  static TrafficStats get traffic => _currentTraffic;
  static Stream<VpnStatus> get statusStream => _statusController.stream;
  static Stream<TrafficStats> get trafficStream => _trafficController.stream;
  static Stream<String> get logsStream => _logsController.stream;

  static void init() {
    if (Platform.isAndroid || Platform.isIOS) {
      _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          _handleNativeEvent(event);
        },
        onError: (dynamic error) {
          _log('[Tunnel Error]: $error');
        },
      );
    }
  }

  static void _handleNativeEvent(dynamic event) {
    if (event is Map) {
      final type = event['type'] as String?;
      if (type == 'status') {
        final stateStr = event['state'] as String? ?? 'disconnected';
        _setStatus(_parseStatus(stateStr));
      } else if (type == 'traffic') {
        final upSpeed = event['up_speed'] as int? ?? 0;
        final downSpeed = event['down_speed'] as int? ?? 0;
        final totalUp = event['total_up'] as int? ?? 0;
        final totalDown = event['total_down'] as int? ?? 0;

        Duration duration = Duration.zero;
        if (_connectedTimestamp != null) {
          duration = DateTime.now().difference(_connectedTimestamp!);
        }

        _currentTraffic = _currentTraffic.copyWith(
          uploadSpeedBytesPerSec: upSpeed,
          downloadSpeedBytesPerSec: downSpeed,
          totalUploadedBytes: totalUp,
          totalDownloadedBytes: totalDown,
          sessionDuration: duration,
        );
        _trafficController.add(_currentTraffic);
      } else if (type == 'log') {
        final msg = event['message'] as String? ?? '';
        _log(msg);
      }
    }
  }

  static VpnStatus _parseStatus(String s) {
    switch (s.toLowerCase()) {
      case 'connected':
        return VpnStatus.connected;
      case 'connecting':
        return VpnStatus.connecting;
      case 'disconnecting':
        return VpnStatus.disconnecting;
      case 'error':
        return VpnStatus.error;
      default:
        return VpnStatus.disconnected;
    }
  }

  static void _setStatus(VpnStatus s) {
    _currentStatus = s;
    if (s == VpnStatus.connected) {
      _connectedTimestamp = DateTime.now();
      _startStatsSimulation();
    } else if (s == VpnStatus.disconnected || s == VpnStatus.error) {
      _connectedTimestamp = null;
      _stopStatsSimulation();
      _currentTraffic = TrafficStats.empty();
      _trafficController.add(_currentTraffic);
    }
    _statusController.add(s);
  }

  static final List<String> _logHistory = [];
  static List<String> get logHistory => List.unmodifiable(_logHistory);

  static void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final entry = '[$timestamp] $message';
    _logHistory.add(entry);
    if (_logHistory.length > 500) _logHistory.removeAt(0);
    _logsController.add(entry);
    // ignore: avoid_print
    print(entry);
  }

  /// Injects inbounds (mixed proxy 2080 + tun) and routing rules into sing-box config
  static String prepareConfig(String rawConfig, {required String routingMode}) {
    try {
      final map = json.decode(rawConfig) as Map<String, dynamic>;

      // Ensure mixed inbound on 127.0.0.1:2080 is always active for system proxy routing
      // Modern sing-box 1.11+: legacy inbound sniff fields are replaced by route rules
      final inbounds = <Map<String, dynamic>>[
        {
          "type": "mixed",
          "tag": "mixed-in",
          "listen": "127.0.0.1",
          "listen_port": 2080,
        }
      ];

      // On mobile (Android / iOS) inject tun interface
      if (Platform.isAndroid || Platform.isIOS) {
        inbounds.add({
          "type": "tun",
          "tag": "tun-in",
          "address": ["172.19.0.1/30"],
          "mtu": 1500,
          "auto_route": true,
          "strict_route": false,
          "stack": "mixed",
          "endpoint_independent_nat": true,
        });
      }

      map['inbounds'] = inbounds;

      // Ensure DNS servers do not have invalid detour: direct (causes fatal error in sing-box)
      // and replace type: local with robust udp DNS (77.88.8.8) on mobile
      final dns = (map['dns'] as Map<String, dynamic>?) ?? {};
      final dnsServers = (dns['servers'] as List<dynamic>?) ?? [];
      for (final srv in dnsServers) {
        if (srv is Map) {
          if (srv['detour'] == 'direct') {
            srv.remove('detour');
          }
          if (srv['type'] == 'local') {
            srv['type'] = 'udp';
            srv['server'] = '77.88.8.8';
          }
        }
      }
      map['dns'] = dns;

      final route = (map['route'] as Map<String, dynamic>?) ?? {};
      route['auto_detect_interface'] = true;
      final rules = (route['rules'] as List<dynamic>?) ?? [];

      // Ensure action: sniff is enabled in routing rules
      bool hasSniff = rules.any((r) => r is Map && r['action'] == 'sniff');
      if (!hasSniff) {
        rules.insert(0, {"action": "sniff"});
      }

      // Ensure DNS hijacking for TUN / transparent proxying so that DNS queries
      // entering the tunnel are resolved through sing-box's internal DNS engine
      bool hasHijackDns = rules.any((r) => r is Map && r['action'] == 'hijack-dns');
      if (!hasHijackDns) {
        final sniffIdx = rules.indexWhere((r) => r is Map && r['action'] == 'sniff');
        final insertIdx = sniffIdx >= 0 ? sniffIdx + 1 : 0;
        rules.insert(insertIdx, {
          "protocol": "dns",
          "action": "hijack-dns"
        });
        rules.insert(insertIdx + 1, {
          "port": 53,
          "action": "hijack-dns"
        });
      }

      // Normalize outbounds transport path for sing-box httpupgrade
      final outbounds = (map['outbounds'] as List<dynamic>?) ?? [];
      for (final ob in outbounds) {
        if (ob is Map && ob['transport'] is Map) {
          final t = ob['transport'] as Map;
          if (t['type'] == 'httpupgrade' && t['path'] == '/xhttp') {
            t['path'] = '/xhttp-up';
          }
        }
      }

      // Smart Mode: Direct routing for Russian domains
      if (routingMode == AppConstants.routeModeSmart) {
        bool hasRuRule = rules.any((r) => r is Map && r['outbound'] == 'direct');
        if (!hasRuRule) {
          final lastDnsIdx = rules.lastIndexWhere((r) => r is Map && (r['action'] == 'hijack-dns' || r['protocol'] == 'dns' || r['port'] == 53));
          final insertIdx = lastDnsIdx >= 0 ? lastDnsIdx + 1 : rules.length;
          rules.insert(insertIdx, {
            "domain_suffix": [".ru", ".su", ".рф", ".xn--p1ai"],
            "outbound": "direct"
          });
        }
      }
      route['rules'] = rules;
      map['route'] = route;

      return const JsonEncoder.withIndent('  ').convert(map);
    } catch (e) {
      return rawConfig;
    }
  }

  /// Locate sing-box binary on desktop, or auto-download if missing
  static Future<String?> _findOrDownloadSingBox() async {
    final exeName = Platform.isWindows ? 'sing-box.exe' : 'sing-box';

    // 1. Check in same folder as running application
    final appDir = File(Platform.resolvedExecutable).parent.path;
    final adjacent = File('$appDir${Platform.pathSeparator}$exeName');
    if (adjacent.existsSync()) {
      if (!Platform.isWindows) {
        try {
          await Process.run('chmod', ['+x', adjacent.path]);
        } catch (_) {}
      }
      return adjacent.path;
    }

    // 2. Check in Application Support / AppData directory
    final appSupportDir = await getApplicationSupportDirectory();
    final localBinary = File('${appSupportDir.path}${Platform.pathSeparator}$exeName');
    if (localBinary.existsSync()) {
      // Validate file size: full sing-box binary is ~40MB - 60MB. Ignore/remove corrupt partial files.
      if (localBinary.lengthSync() > 10000000) {
        if (!Platform.isWindows) {
          try {
            await Process.run('chmod', ['+x', localBinary.path]);
          } catch (_) {}
        }
        return localBinary.path;
      } else {
        try {
          localBinary.deleteSync();
        } catch (_) {}
      }
    }

    // 3. Check system PATH locations on macOS / Linux
    if (!Platform.isWindows) {
      for (final sysPath in ['/opt/homebrew/bin/sing-box', '/usr/local/bin/sing-box', '/usr/bin/sing-box']) {
        if (File(sysPath).existsSync()) {
          return sysPath;
        }
      }
    }

    // 4. Auto-download from linkpc gateway server
    _log('Загрузка ядра sing-box с сервера linkpc...');
    final downloadUrl = Platform.isWindows
        ? 'https://vless.linkpc.net/downloads/sing-box.exe'
        : (Platform.isMacOS
            ? 'https://vless.linkpc.net/downloads/sing-box-darwin'
            : 'https://vless.linkpc.net/downloads/sing-box');

    try {
      final res = await http.get(Uri.parse(downloadUrl));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        await localBinary.parent.create(recursive: true);
        await localBinary.writeAsBytes(res.bodyBytes);
        if (!Platform.isWindows) {
          await Process.run('chmod', ['+x', localBinary.path]);
        }
        _log('Ядро sing-box успешно загружено и подготовлено.');
        return localBinary.path;
      } else {
        _log('Сервер вернул статус ${res.statusCode} при загрузке ядра');
      }
    } catch (e) {
      _log('Не удалось автоматически загрузить ядро: $e');
    }

    return null;
  }

  /// Start VPN Tunnel
  static Future<void> startTunnel(String rawConfig, {required String routingMode}) async {
    if (_currentStatus.isBusy || _currentStatus.isConnected) return;

    _setStatus(VpnStatus.connecting);
    _log('Инициализация защищенного шлюза linkpc...');

    final processedConfig = prepareConfig(rawConfig, routingMode: routingMode);

    // Desktop handling: Windows, macOS, Linux
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await _startDesktopTunnel(processedConfig);
      return;
    }

    // Mobile handling: Android, iOS
    try {
      final res = await _channel.invokeMethod<bool>('start', {
        'config': processedConfig,
      });

      if (res == true) {
        _log('Туннель linkpc успешно запущен.');
        _setStatus(VpnStatus.connected);
      } else {
        _log('Ошибка: не удалось инициализировать туннель.');
        _setStatus(VpnStatus.error);
      }
    } catch (e) {
      _log('Ошибка запуска туннеля: $e');
      _setStatus(VpnStatus.error);
    }
  }

  /// Desktop Tunnel Runner
  static Future<void> _startDesktopTunnel(String configJson) async {
    final binaryPath = await _findOrDownloadSingBox();
    if (binaryPath == null) {
      _log('Ошибка: sing-box не найден. Поместите sing-box.exe рядом с linkpc.exe.');
      _setStatus(VpnStatus.error);
      return;
    }

    // Write config to temporary directory ensuring parent folder exists
    final tempDir = await getTemporaryDirectory();
    final configFile = File('${tempDir.path}${Platform.pathSeparator}linkpc_config.json');
    try {
      if (!configFile.parent.existsSync()) {
        await configFile.parent.create(recursive: true);
      }
      await configFile.writeAsString(configJson);
    } catch (e) {
      _log('Ошибка записи файла конфигурации: $e');
      _setStatus(VpnStatus.error);
      return;
    }

    _log('Запуск sing-box ($binaryPath)...');

    try {
      final workDir = File(binaryPath).parent.path;
      _desktopProcess = await Process.start(
        binaryPath,
        ['run', '-c', configFile.path],
        workingDirectory: workDir,
        mode: ProcessStartMode.normal,
      );

      _desktopProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _log('[core] $line');
      });

      _desktopProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _log('[core] $line');
      });

      bool processExited = false;
      int? earlyExitCode;
      _desktopProcess!.exitCode.then((code) {
        processExited = true;
        earlyExitCode = code;
        _log('Ядро sing-box завершило работу (код $code)');
        if (_currentStatus == VpnStatus.connected) {
          stopTunnel();
        }
      });

      // Allow 700ms for sing-box to bind 127.0.0.1:2080
      await Future.delayed(const Duration(milliseconds: 700));

      if (processExited) {
        _log('Ошибка: ядро sing-box завершилось с кодом $earlyExitCode. Подключение прервано.');
        _setStatus(VpnStatus.error);
        return;
      }

      if (Platform.isWindows) {
        _log('Применение системного прокси Windows (127.0.0.1:2080)...');
        await _setWindowsProxy(enabled: true, proxy: '127.0.0.1:2080');
      } else if (Platform.isMacOS) {
        _log('Применение системного прокси macOS (127.0.0.1:2080)...');
        await _setMacOsProxy(enabled: true, host: '127.0.0.1', port: 2080);
      }

      _log('Шлюз linkpc активен. Трафик защищен и перенаправлен.');
      _setStatus(VpnStatus.connected);
    } catch (e) {
      _log('Ошибка запуска процесса: $e');
      _setStatus(VpnStatus.error);
    }
  }

  /// Stop VPN Tunnel
  static Future<void> stopTunnel() async {
    if (_currentStatus == VpnStatus.disconnected) return;

    _setStatus(VpnStatus.disconnecting);
    _log('Остановка сетевого шлюза linkpc...');

    if (Platform.isWindows) {
      await _setWindowsProxy(enabled: false);
    } else if (Platform.isMacOS) {
      await _setMacOsProxy(enabled: false);
    }

    if (_desktopProcess != null) {
      _desktopProcess!.kill();
      _desktopProcess = null;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await _channel.invokeMethod('stop');
      } catch (_) {}
    }

    _setStatus(VpnStatus.disconnected);
    _log('Шлюз отключен. Трафик возвращен в стандартный сетевой интерфейс.');
  }

  /// Windows System Proxy Configuration via Registry and WinINet API
  static Future<void> _setWindowsProxy({required bool enabled, String proxy = '127.0.0.1:2080'}) async {
    try {
      if (enabled) {
        await Process.run('reg', [
          'add',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
          '/v', 'ProxyEnable',
          '/t', 'REG_DWORD',
          '/d', '1',
          '/f'
        ]);
        await Process.run('reg', [
          'add',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
          '/v', 'ProxyServer',
          '/t', 'REG_SZ',
          '/d', proxy,
          '/f'
        ]);
        await Process.run('reg', [
          'add',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
          '/v', 'ProxyOverride',
          '/t', 'REG_SZ',
          '/d', r'<local>;localhost;127.*;10.*;172.16.*;192.168.*',
          '/f'
        ]);
      } else {
        await Process.run('reg', [
          'add',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
          '/v', 'ProxyEnable',
          '/t', 'REG_DWORD',
          '/d', '0',
          '/f'
        ]);
      }

      // Notify Windows WinINet to immediately apply proxy to all open browsers and apps
      await Process.run('powershell', [
        '-WindowStyle', 'Hidden',
        '-Command',
        r'try { Add-Type -TypeDefinition "using System; using System.Runtime.InteropServices; public class WinINet { [DllImport(\"wininet.dll\")] public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength); }"; [WinINet]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0); [WinINet]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0); } catch {}'
      ]);
    } catch (e) {
      _log('Ошибка изменения настроек прокси Windows: $e');
    }
  }

  /// macOS System Proxy Configuration
  static Future<void> _setMacOsProxy({required bool enabled, String host = '127.0.0.1', int port = 2080}) async {
    try {
      final netRes = await Process.run('networksetup', ['-listnetworkserviceorder']);
      final services = _parseMacNetworkServices(netRes.stdout.toString());

      for (final service in services) {
        if (enabled) {
          _log('Настройка системного прокси macOS для $service ($host:$port)...');
          await Process.run('networksetup', ['-setwebproxy', service, host, port.toString()]);
          await Process.run('networksetup', ['-setsecurewebproxy', service, host, port.toString()]);
          await Process.run('networksetup', ['-setsocksfirewallproxy', service, host, port.toString()]);
        } else {
          _log('Отключение системного прокси macOS для $service...');
          await Process.run('networksetup', ['-setwebproxystate', service, 'off']);
          await Process.run('networksetup', ['-setsecurewebproxystate', service, 'off']);
          await Process.run('networksetup', ['-setsocksfirewallproxystate', service, 'off']);
        }
      }
    } catch (e) {
      _log('Ошибка изменения настроек прокси macOS: $e');
    }
  }

  static List<String> _parseMacNetworkServices(String output) {
    final services = <String>[];
    final lines = output.split('\n');
    final regex = RegExp(r'^\(\d+\)\s+(.+?)(?:\s+\(Hardware Port:.*)?$');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('*')) continue;
      final match = regex.firstMatch(trimmed);
      if (match != null) {
        final name = match.group(1)?.trim();
        if (name != null && name.isNotEmpty && !services.contains(name)) {
          services.add(name);
        }
      }
    }

    final physical = services.where((s) {
      final l = s.toLowerCase();
      return l.contains('wi-fi') || l.contains('ethernet') || l.contains('lan') || l.contains('usb');
    }).toList();

    return physical.isNotEmpty ? physical : (services.isNotEmpty ? services : ['Wi-Fi', 'Ethernet']);
  }

  static void _startStatsSimulation() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentStatus != VpnStatus.connected) return;

      final duration = _connectedTimestamp != null
          ? DateTime.now().difference(_connectedTimestamp!)
          : Duration.zero;

      final dlSpeed = 1024 * 1024 * 3 + (DateTime.now().millisecond * 4000);
      final ulSpeed = 1024 * 320 + (DateTime.now().millisecond * 800);

      _currentTraffic = _currentTraffic.copyWith(
        downloadSpeedBytesPerSec: dlSpeed,
        uploadSpeedBytesPerSec: ulSpeed,
        totalDownloadedBytes: _currentTraffic.totalDownloadedBytes + dlSpeed,
        totalUploadedBytes: _currentTraffic.totalUploadedBytes + ulSpeed,
        sessionDuration: duration,
      );
      _trafficController.add(_currentTraffic);
    });
  }

  static void _stopStatsSimulation() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }
}
