import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/storage_service.dart';
import '../widgets/cyber_card.dart';
import 'import_screen.dart';
import 'logs_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _routingMode = AppConstants.routeModeSmart;
  bool _autoConnect = false;

  @override
  void initState() {
    super.initState();
    _routingMode = StorageService.getRoutingMode();
    _autoConnect = StorageService.getAutoConnect();
  }

  Future<void> _setRoutingMode(String mode) async {
    setState(() => _routingMode = mode);
    await StorageService.setRoutingMode(mode);
  }

  Future<void> _toggleAutoConnect(bool val) async {
    setState(() => _autoConnect = val);
    await StorageService.setAutoConnect(val);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.voidDark,
        elevation: 0,
        title: const Text(
          'НАСТРОЙКИ СЕТИ',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            letterSpacing: 0.8,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Routing Section
          const Text(
            'РЕЖИМ МАРШРУТИЗАЦИИ',
            style: TextStyle(
              color: AppColors.cyberCyan,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),

          CyberCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                RadioListTile<String>(
                  value: AppConstants.routeModeSmart,
                  groupValue: _routingMode,
                  onChanged: (v) => v != null ? _setRoutingMode(v) : null,
                  activeColor: AppColors.cyberCyan,
                  title: const Text(
                    'Умный режим (Рекомендуется)',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  subtitle: const Text(
                    'Российские ресурсы (.ru, банки, Госуслуги) идут напрямую без задержки. Зарубежные сервисы и AI идут через шлюз.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                RadioListTile<String>(
                  value: AppConstants.routeModeAll,
                  groupValue: _routingMode,
                  onChanged: (v) => v != null ? _setRoutingMode(v) : null,
                  activeColor: AppColors.cyberCyan,
                  title: const Text(
                    'Полный туннель',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  subtitle: const Text(
                    '100% трафика устройства направляется через зашифрованный шлюз в дата-центре.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Startup & Service Options
          const Text(
            'ПОВЕДЕНИЕ ПРИЛОЖЕНИЯ',
            style: TextStyle(
              color: AppColors.cyberCyan,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),

          CyberCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SwitchListTile(
              value: _autoConnect,
              onChanged: _toggleAutoConnect,
              activeColor: AppColors.cyberCyan,
              title: const Text(
                'Автоподключение',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              subtitle: const Text(
                'Автоматически запускать шлюз при открытии приложения',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Diagnostics & Logs Section
          const Text(
            'ДИАГНОСТИКА И ЛОГИ СЕТИ',
            style: TextStyle(
              color: AppColors.cyberCyan,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),

          CyberCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.terminal_rounded, color: AppColors.cyberCyan, size: 24),
              title: const Text(
                'Терминал логов ядра и Android',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              subtitle: const Text(
                'Просмотр журнала работы sing-box (libbox), сетевых интерфейсов, DNS и ошибок соединения.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace'),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.cyberCyan, size: 14),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const LogsScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Profile Management
          const Text(
            'УПРАВЛЕНИЕ ПОДПИСКОЙ',
            style: TextStyle(
              color: AppColors.cyberCyan,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),

          CyberCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const ImportScreen()),
                    );
                  },
                  icon: const Icon(Icons.key_rounded, size: 16, color: AppColors.cyberCyan),
                  label: const Text(
                    'СМЕНИТЬ ТОКЕН ПОДПИСКИ',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cyberCyan,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text('Сбросить профиль?', style: TextStyle(color: Colors.white, fontFamily: 'monospace')),
                        content: const Text('Все сохраненные данные подписки будут очищены.', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'monospace')),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ОТМЕНА', style: TextStyle(color: AppColors.textMuted))),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('СБРОСИТЬ', style: TextStyle(color: AppColors.error))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await StorageService.clearAll();
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                  label: const Text(
                    'ОЧИСТИТЬ ДАННЫЕ И ВЫЙТИ',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // About & Support
          CyberCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'linkpc Client v1.0.0',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ядро: sing-box (libbox core) • VLESS + XHTTP',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final uri = Uri.parse(AppConstants.supportTelegram);
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.support_agent_rounded, size: 16, color: AppColors.cyberCyan),
                      SizedBox(width: 8),
                      Text(
                        'Поддержка в Telegram: @InfinitySupport',
                        style: TextStyle(color: AppColors.cyberCyan, fontSize: 11.5, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
