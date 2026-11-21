import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/vpn_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final List<String> _logs = [];
  StreamSubscription<String>? _logSub;
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  String _filter = 'all'; // 'all', 'error', 'box', 'network'
  String? _logFilePath;

  @override
  void initState() {
    super.initState();
    _logs.add('--- Консоль диагностики linkpc [v1.0.13] ---');
    _logs.add('--- Ядро: sing-box (libbox), XHTTP Transport ---');
    _logs.addAll(VpnService.logHistory);

    // Fetch native logs from Android background service & log file path
    _loadNativeData();

    _logSub = VpnService.logsStream.listen((line) {
      if (mounted) {
        setState(() {
          if (!_logs.contains(line)) {
            _logs.add(line);
          }
        });
        if (_autoScroll) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
            }
          });
        }
      }
    });
  }

  Future<void> _loadNativeData() async {
    final nativeLogs = await VpnService.getNativeLogs();
    final path = await VpnService.getNativeLogFilePath();
    if (mounted) {
      setState(() {
        _logFilePath = path;
        for (final line in nativeLogs) {
          if (!_logs.contains(line)) {
            _logs.add(line);
          }
        }
      });
      if (_autoScroll) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    }
  }

  void _copyLogs() {
    final textToCopy = _filteredLogs.join('\n');
    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Скопировано ${_filteredLogs.length} строк лога'),
        backgroundColor: AppColors.cyberCyan,
      ),
    );
  }

  Future<void> _clearLogs() async {
    await VpnService.clearLogs();
    if (mounted) {
      setState(() {
        _logs.clear();
        _logs.add('--- Консоль очищена ---');
      });
    }
  }

  List<String> get _filteredLogs {
    if (_filter == 'error') {
      return _logs.where((l) {
        final lower = l.toLowerCase();
        return lower.contains('error') ||
            lower.contains('ошибка') ||
            lower.contains('[err]') ||
            lower.contains('fail') ||
            lower.contains('exception');
      }).toList();
    } else if (_filter == 'box') {
      return _logs.where((l) => l.contains('[box]') || l.contains('[Core]') || l.contains('[Client]')).toList();
    } else if (_filter == 'network') {
      return _logs.where((l) => l.contains('[Network]') || l.contains('[TUN]') || l.contains('[Socket]')).toList();
    }
    return _logs;
  }

  Color _getLineColor(String line) {
    final lower = line.toLowerCase();
    if (lower.contains('error') || lower.contains('ошибка') || lower.contains('[err]') || lower.contains('fail')) {
      return AppColors.error;
    }
    if (line.contains('[Network]') || line.contains('[Socket]')) {
      return AppColors.warning;
    }
    if (line.contains('[TUN]') || line.contains('connected') || line.contains('успешно') || line.contains('Active')) {
      return AppColors.neonEmerald;
    }
    if (line.contains('[box]') || line.contains('linkpc')) {
      return AppColors.cyberCyan;
    }
    return AppColors.textSecondary;
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLogs;

    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      appBar: AppBar(
        backgroundColor: AppColors.voidDark,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ТЕРМИНАЛ / ЛОГИ',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                letterSpacing: 0.8,
              ),
            ),
            Text(
              '${filtered.length} СООБЩЕНИЙ ${_autoScroll ? "• АВТОСКРОЛЛ ВКЛ" : ""}',
              style: const TextStyle(
                color: AppColors.skyBlue,
                fontSize: 9.5,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _autoScroll = !_autoScroll;
              });
              if (_autoScroll && _scrollController.hasClients) {
                _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
              }
            },
            icon: Icon(
              _autoScroll ? Icons.vertical_align_bottom_rounded : Icons.pause_circle_outline_rounded,
              color: _autoScroll ? AppColors.cyberCyan : AppColors.textMuted,
              size: 20,
            ),
            tooltip: _autoScroll ? 'Автопрокрутка активна' : 'Автопрокрутка на паузе',
          ),
          IconButton(
            onPressed: _copyLogs,
            icon: const Icon(Icons.copy_rounded, color: AppColors.cyberCyan, size: 20),
            tooltip: 'Копировать логи',
          ),
          IconButton(
            onPressed: _clearLogs,
            icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.textMuted, size: 20),
            tooltip: 'Очистить',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            color: AppColors.voidDark,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('ВСЕ', 'all'),
                const SizedBox(width: 6),
                _buildFilterChip('ОШИБКИ', 'error'),
                const SizedBox(width: 6),
                _buildFilterChip('ЯДРО (BOX)', 'box'),
                const SizedBox(width: 6),
                _buildFilterChip('СЕТЬ / TUN', 'network'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_logFilePath != null && _logFilePath!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: AppColors.voidDark,
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined, size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Файл: $_logFilePath',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9.5,
                        color: AppColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              color: AppColors.voidBlack,
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'Нет записей в выбранной категории',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace'),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final line = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: SelectableText(
                            line,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10.5,
                              color: _getLineColor(line),
                              height: 1.3,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return InkWell(
      onTap: () {
        setState(() {
          _filter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cyberCyan.withOpacity(0.15) : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.cyberCyan : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.cyberCyan : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
