import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/traffic_stats.dart';
import '../../core/models/user_profile.dart';
import '../../core/models/vpn_state.dart';
import '../../core/services/api_service.dart';
import '../../core/services/ping_service.dart';
import '../../core/services/speed_test_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/vpn_service.dart';
import '../../core/utils/formatters.dart';
import '../widgets/connect_power_button.dart';
import '../widgets/cyber_card.dart';
import '../widgets/multidimensional_space.dart';
import '../widgets/status_badge.dart';
import '../widgets/telemetry_bar.dart';
import '../widgets/traffic_card.dart';
import 'import_screen.dart';
import 'logs_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, RouteAware {
  UserProfile _profile = UserProfile.empty();
  VpnStatus _status = VpnStatus.disconnected;
  TrafficStats _traffic = TrafficStats.empty();
  int? _downPingMs;
  int? _downJitterMs;
  int? _upPingMs;
  int? _upJitterMs;
  int? get _pingMs => _downPingMs;
  SpeedTestProgress? _speedTestProgress;
  SpeedTestResult? _lastSpeedTestResult;
  bool _isLoading = true;
  String _routingMode = AppConstants.routeModeSmart;

  StreamSubscription<VpnStatus>? _statusSub;
  StreamSubscription<TrafficStats>? _trafficSub;
  StreamSubscription<String>? _logsSub;
  Timer? _logThrottleTimer;
  List<String> _recentLogs = [];
  Timer? _pingTimer;
  bool _isPingRunning = false;

  // Measurement condition triggers:
  // 1. Window is active (foreground, focused, not hidden or minimized)
  bool _isWindowActive = true;
  // 2. Route is active (HomeScreen is top-most route, not covered by other screens/dialogs)
  bool _isRouteActive = true;
  // 3. TrafficCard is currently visible in viewport (not scrolled out of view)
  bool _isCardVisible = true;

  final GlobalKey _trafficCardKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  /// Замер разрешен исключительно когда туннель подключен, окно активно,
  /// экран открыт и сам виджет с замером находится в видимой области экрана.
  bool get _shouldMeasure =>
      _status.isConnected && _isWindowActive && _isRouteActive && _isCardVisible;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isWindowActive = (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) == AppLifecycleState.resumed;
    _initApp();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkCardVisibility();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null) {
      LinkpcApp.routeObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isActive = state == AppLifecycleState.resumed;
    if (_isWindowActive != isActive) {
      setState(() {
        _isWindowActive = isActive;
      });
      _onMeasurementConditionsChanged();
    }
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkCardVisibility();
      }
    });
  }

  @override
  void didPushNext() {
    // Пользователь перешел на другой экран (Настройки, Логи, Импорт)
    setState(() {
      _isRouteActive = false;
    });
    _onMeasurementConditionsChanged();
  }

  @override
  void didPopNext() {
    // Пользователь вернулся на главный экран
    setState(() {
      _isRouteActive = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkCardVisibility();
        _onMeasurementConditionsChanged();
      }
    });
  }

  void _checkCardVisibility() {
    if (!mounted) return;

    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null && !modalRoute.isCurrent) {
      _updateCardVisibility(false);
      return;
    }

    final cardCtx = _trafficCardKey.currentContext;
    if (cardCtx == null) return;

    final renderBox = cardCtx.findRenderObject();
    if (renderBox is! RenderBox || !renderBox.hasSize || !renderBox.attached) {
      return;
    }

    final cardSize = renderBox.size;
    if (cardSize.width <= 0 || cardSize.height <= 0) {
      _updateCardVisibility(false);
      return;
    }

    final cardGlobalOffset = renderBox.localToGlobal(Offset.zero);
    final cardRect = cardGlobalOffset & cardSize;

    final mediaQuery = MediaQuery.maybeOf(context);
    final screenSize = mediaQuery?.size;
    if (screenSize == null) return;

    final screenRect = Offset.zero & screenSize;
    final intersection = cardRect.intersect(screenRect);

    final isVisible = !intersection.isEmpty && intersection.height > 10 && intersection.width > 10;
    _updateCardVisibility(isVisible);
  }

  void _updateCardVisibility(bool visible) {
    if (_isCardVisible != visible) {
      setState(() {
        _isCardVisible = visible;
      });
      _onMeasurementConditionsChanged();
    }
  }

  void _onMeasurementConditionsChanged() {
    if (!mounted) return;

    if (_shouldMeasure) {
      if (_pingTimer == null || !_pingTimer!.isActive) {
        _startPingTimer();
      }
      _refreshPing();
    } else {
      _stopPingTimer();
      _cancelAndCloseConnections();
    }
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _cancelAndCloseConnections() {
    _isPingRunning = false;
    PingService.stopAndClose();
    SpeedTestService.cancelTest();
  }

  Future<void> _initApp() async {
    _routingMode = StorageService.getRoutingMode();
    _status = VpnService.status;
    _traffic = VpnService.traffic;

    _statusSub = VpnService.statusStream.listen((status) {
      if (mounted) {
        setState(() => _status = status);
        PingService.resetClient();
        if (status.isConnected) {
          _onMeasurementConditionsChanged();
        } else {
          _stopPingTimer();
          _cancelAndCloseConnections();
          setState(() {
            _downPingMs = null;
            _downJitterMs = null;
            _upPingMs = null;
            _upJitterMs = null;
          });
        }
      }
    });

    _trafficSub = VpnService.trafficStream.listen((traffic) {
      if (mounted) setState(() => _traffic = traffic);
    });

    _recentLogs = List.of(VpnService.recentLogs);
    _logsSub = VpnService.logsStream.listen((_) {
      if (mounted && (_logThrottleTimer == null || !_logThrottleTimer!.isActive)) {
        _logThrottleTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _recentLogs = List.of(VpnService.recentLogs);
            });
          }
        });
      }
    });

    final token = StorageService.getToken();
    if (token == null || token.isEmpty) {
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openImportModal();
      });
      return;
    }

    await _loadProfile(token);

    if (_shouldMeasure) {
      _refreshPing();
      _startPingTimer();
    }

    // Auto-connect if enabled
    if (StorageService.getAutoConnect() && _status == VpnStatus.disconnected) {
      _toggleVpn();
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && _shouldMeasure) {
        _refreshPing();
      } else {
        _stopPingTimer();
        _cancelAndCloseConnections();
      }
    });
  }

  Future<void> _refreshPing() async {
    if (_isPingRunning || !_shouldMeasure) return;
    _isPingRunning = true;
    try {
      final res = await PingService.measureLatencyAndJitter(probeCount: 3);
      if (mounted && _shouldMeasure && res != null) {
        setState(() {
          _downPingMs = res.downLatencyMs;
          _downJitterMs = res.downJitterMs;
          _upPingMs = res.upLatencyMs;
          _upJitterMs = res.upJitterMs;
        });
      }
    } finally {
      _isPingRunning = false;
    }
  }

  Future<void> _loadProfile(String token) async {
    setState(() => _isLoading = true);
    try {
      final prof = await ApiService.fetchProfile(token);
      if (mounted) {
        setState(() {
          _profile = prof;
          _isLoading = false;
        });
      }
    } catch (e) {
      final cached = StorageService.getCachedConfig();
      if (cached != null) {
        if (mounted) {
          setState(() {
            _profile = UserProfile(
              token: token,
              clientName: 'linkpc Gateway (Кэш)',
              planName: 'Активный профиль',
              rawSingboxConfig: cached,
            );
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка обновления профиля: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _runSpeedTest() async {
    if (!_shouldMeasure) return;
    await SpeedTestService.runTest(
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _speedTestProgress = progress;
            if (!progress.isRunning && SpeedTestService.lastResult != null) {
              _lastSpeedTestResult = SpeedTestService.lastResult;
            }
          });
        }
      },
    );
  }

  Future<void> _toggleVpn() async {
    if (_profile.rawSingboxConfig.isEmpty && StorageService.getCachedConfig() == null) {
      _openImportModal();
      return;
    }

    if (_status.isConnected) {
      await VpnService.stopTunnel();
    } else if (_status == VpnStatus.disconnected || _status == VpnStatus.error) {
      final config = _profile.rawSingboxConfig.isNotEmpty
          ? _profile.rawSingboxConfig
          : StorageService.getCachedConfig()!;
      await VpnService.startTunnel(config, routingMode: _routingMode);
    }
  }

  void _openImportModal() async {
    final res = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const ImportScreen()),
    );
    if (res == true) {
      final token = StorageService.getToken();
      if (token != null) _loadProfile(token);
    }
  }

  void _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    setState(() {
      _routingMode = StorageService.getRoutingMode();
    });
  }

  void _openLogs() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const LogsScreen()),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LinkpcApp.routeObserver.unsubscribe(this);
    _scrollController.dispose();
    _statusSub?.cancel();
    _trafficSub?.cancel();
    _logsSub?.cancel();
    _logThrottleTimer?.cancel();
    _stopPingTimer();
    _cancelAndCloseConnections();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _status.isConnected;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: MultidimensionalSpace(
        status: _status,
        trafficBytesPerSec: isConnected ? (_traffic.downloadSpeedBytesPerSec + _traffic.uploadSpeedBytesPerSec) : 0,
        pingMs: _pingMs,
        child: SafeArea(
          child: Column(
            children: [
              // Header Bar
              _buildHeader(context),

              // Real-time Telemetry Bar
              TelemetryBar(
                statusText: isConnected
                    ? (_routingMode == AppConstants.routeModeSmart
                        ? 'Умный маршрут • РФ напрямую'
                        : 'Полный туннель • Весь трафик')
                    : 'Шлюз готов к подключению',
              ),

              // Scrollable Main Content
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    _checkCardVisibility();
                    return false;
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),

                      // Central Glowing Power Button
                      Center(
                        child: ConnectPowerButton(
                          status: _status,
                          trafficBytesPerSec: isConnected
                              ? (_traffic.downloadSpeedBytesPerSec + _traffic.uploadSpeedBytesPerSec)
                              : 0,
                          pingMs: _pingMs,
                          onTap: _toggleVpn,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Status Label & Routing Mode Badge
                      Text(
                        _status.label,
                        style: TextStyle(
                          color: isConnected
                              ? AppColors.neonEmerald
                              : (_status.isConnecting ? AppColors.cyberCyan : AppColors.textMuted),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          letterSpacing: 1.2,
                          shadows: [
                            if (isConnected || _status.isConnecting)
                              Shadow(
                                color: (isConnected ? AppColors.neonEmerald : AppColors.cyberCyan).withOpacity(0.6),
                                blurRadius: 10,
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      StatusBadge(
                        label: _routingMode == AppConstants.routeModeSmart
                            ? 'Умная маршрутизация'
                            : 'Полный туннель',
                        color: isConnected ? AppColors.neonEmerald : AppColors.cyberCyan,
                      ),

                      const SizedBox(height: 24),

                      // Live Traffic Card
                      TickerMode(
                        enabled: _isWindowActive && _isRouteActive && _isCardVisible,
                        child: TrafficCard(
                          key: _trafficCardKey,
                          stats: _traffic,
                          isConnected: isConnected,
                          downPingMs: _downPingMs,
                          downJitterMs: _downJitterMs,
                          upPingMs: _upPingMs,
                          upJitterMs: _upJitterMs,
                          speedTestProgress: _speedTestProgress,
                          lastSpeedTestResult: _lastSpeedTestResult,
                          onRunSpeedTest: _runSpeedTest,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Real-time Diagnostics & Console Preview Card
                      _buildDiagnosticsCard(),

                      const SizedBox(height: 14),

                      // Subscription / Gateway Profile Card
                      _buildSubscriptionCard(),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.voidDark.withOpacity(0.88),
        border: const Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.voidBlack.withOpacity(0.6),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & Name
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.voidBlack,
                  border: Border.all(color: AppColors.cyberCyan.withOpacity(0.6), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyberCyan.withOpacity(0.25),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '>_',
                    style: TextStyle(
                      color: AppColors.cyberCyan,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'link',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                            TextSpan(
                              text: 'pc',
                              style: TextStyle(
                                color: AppColors.cyberCyan,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                                shadows: [
                                  Shadow(
                                    color: AppColors.cyberCyan,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.cyberCyan.withOpacity(0.12),
                          border: Border.all(color: AppColors.cyberCyan.withOpacity(0.45), width: 0.8),
                        ),
                        child: Text(
                          AppConstants.displayVersion,
                          style: const TextStyle(
                            color: AppColors.cyberCyan,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    AppConstants.appTagline,
                    style: TextStyle(
                      color: AppColors.skyBlue,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Actions: Prominent Terminal Logs Button & Settings
          Row(
            children: [
              InkWell(
                onTap: _openLogs,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5.5),
                  decoration: BoxDecoration(
                    color: AppColors.cyberCyan.withOpacity(0.12),
                    border: Border.all(color: AppColors.cyberCyan.withOpacity(0.65), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyberCyan.withOpacity(0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.terminal_rounded, color: AppColors.cyberCyan, size: 15),
                      SizedBox(width: 5),
                      Text(
                        'ЛОГИ',
                        style: TextStyle(
                          color: AppColors.cyberCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _openSettings,
                tooltip: 'Настройки',
                icon: const Icon(Icons.tune_rounded, color: AppColors.textSecondary, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsCard() {
    final hasErrors = _recentLogs.any((l) {
      final low = l.toLowerCase();
      return low.contains('error') || low.contains('ошибка') || low.contains('fail');
    });

    return CyberCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _status.isConnected
                          ? AppColors.neonEmerald
                          : (_status == VpnStatus.error || hasErrors ? AppColors.error : AppColors.cyberCyan),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ЖУРНАЛ СОБЫТИЙ',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _openLogs,
                child: const Text(
                  'ЖУРНАЛ →',
                  style: TextStyle(
                    color: AppColors.cyberCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.voidBlack,
              border: Border.all(color: AppColors.border),
            ),
            child: _recentLogs.isEmpty
                ? const Text(
                    'Ожидание сетевой активности шлюза (включите тумблер)...',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace'),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _recentLogs.map((log) {
                      final isErr = log.toLowerCase().contains('error') || log.toLowerCase().contains('ошибка') || log.toLowerCase().contains('fail');
                      final isNet = log.contains('[Network]') || log.contains('[TUN]');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1.5),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9.5,
                            color: isErr
                                ? AppColors.error
                                : (isNet ? AppColors.warning : AppColors.textSecondary),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Записей в буфере: ${VpnService.logHistory.length}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontFamily: 'monospace'),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: VpnService.logHistory.join('\n')));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Все логи скопированы в буфер обмена'),
                      backgroundColor: AppColors.cyberCyan,
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Icon(Icons.copy_rounded, color: AppColors.cyberCyan, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'СКОПИРОВАТЬ',
                      style: TextStyle(color: AppColors.cyberCyan, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    final token = StorageService.getToken();
    final hasToken = token != null && token.isNotEmpty;

    return CyberCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppColors.cyberCyan, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _profile.clientName.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: hasToken ? () => _loadProfile(token) : _openImportModal,
                child: Text(
                  hasToken ? 'ОБНОВИТЬ' : 'ДОБАВИТЬ',
                  style: const TextStyle(
                    color: AppColors.cyberCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ТАРИФ: ${_profile.planName}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'ДО: ${Formatters.formatDate(_profile.expiresAt)}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Multidimensional Traffic Progress Bar
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.voidBlack,
              border: Border.all(color: AppColors.border),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _profile.usagePercent.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _profile.usagePercent > 0.85 ? AppColors.warning : AppColors.deepCyan,
                      _profile.usagePercent > 0.85 ? AppColors.error : AppColors.cyberCyan,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_profile.usagePercent > 0.85 ? AppColors.warning : AppColors.cyberCyan).withOpacity(0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ОСТАТОК: ${_profile.remainingGb.toStringAsFixed(1)} GB',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'ЛИМИТ: ${_profile.trafficTotalGb.toStringAsFixed(0)} GB',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
