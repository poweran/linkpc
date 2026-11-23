import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/traffic_stats.dart';
import '../../core/models/user_profile.dart';
import '../../core/models/vpn_state.dart';
import '../../core/services/api_service.dart';
import '../../core/services/ping_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/vpn_service.dart';
import '../../core/utils/formatters.dart';
import '../widgets/connect_power_button.dart';
import '../widgets/cyber_card.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  UserProfile _profile = UserProfile.empty();
  VpnStatus _status = VpnStatus.disconnected;
  TrafficStats _traffic = TrafficStats.empty();
  int? _pingMs;
  bool _isLoading = true;
  String _routingMode = AppConstants.routeModeSmart;

  StreamSubscription<VpnStatus>? _statusSub;
  StreamSubscription<TrafficStats>? _trafficSub;
  StreamSubscription<String>? _logsSub;
  Timer? _logThrottleTimer;
  List<String> _recentLogs = [];
  Timer? _pingTimer;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    _routingMode = StorageService.getRoutingMode();
    _status = VpnService.status;
    _traffic = VpnService.traffic;

    _statusSub = VpnService.statusStream.listen((status) {
      if (mounted) setState(() => _status = status);
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
    _refreshPing();

    _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _refreshPing();
    });

    // Auto-connect if enabled
    if (StorageService.getAutoConnect() && _status == VpnStatus.disconnected) {
      _toggleVpn();
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

  Future<void> _refreshPing() async {
    final ms = await PingService.checkLatency();
    if (mounted) {
      setState(() => _pingMs = ms > 0 ? ms : null);
    }
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
    _statusSub?.cancel();
    _trafficSub?.cancel();
    _logsSub?.cancel();
    _logThrottleTimer?.cancel();
    _pingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _status.isConnected;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            _buildHeader(context),

            // Real-time Telemetry Bar
            TelemetryBar(
              pingMs: _pingMs,
              onRefreshPing: _refreshPing,
            ),

            // Scrollable Main Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // Central Glowing Power Button
                    Center(
                      child: ConnectPowerButton(
                        status: _status,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        letterSpacing: 1.0,
                      ),
                    ),

                    const SizedBox(height: 8),

                    StatusBadge(
                      label: _routingMode == AppConstants.routeModeSmart
                          ? 'УМНЫЙ МАРШРУТ (RU НАПРЯМУЮ)'
                          : 'ПОЛНЫЙ ТУННЕЛЬ (ВЕСЬ ТРАФИК)',
                      color: isConnected ? AppColors.neonEmerald : AppColors.cyberCyan,
                    ),

                    const SizedBox(height: 24),

                    // Live Traffic Card
                    TrafficCard(
                      stats: _traffic,
                      isConnected: isConnected,
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.voidDark,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & Name
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.voidBlack,
                  border: Border.all(color: AppColors.cyberCyan.withOpacity(0.5)),
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
                          ),
                        ),
                      ],
                    ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.cyberCyan.withOpacity(0.12),
                    border: Border.all(color: AppColors.cyberCyan.withOpacity(0.6), width: 1),
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
                    'ДИАГНОСТИКА И ЛОГИ СЕТИ',
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
                  'ТЕРМИНАЛ →',
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
          // Traffic Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.zero,
            child: LinearProgressIndicator(
              value: _profile.usagePercent,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                _profile.usagePercent > 0.85 ? AppColors.warning : AppColors.cyberCyan,
              ),
              minHeight: 6,
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
