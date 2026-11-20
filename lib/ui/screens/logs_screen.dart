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

  @override
  void initState() {
    super.initState();
    _logs.add('--- Консоль диагностики linkpc [v1.0.0] ---');
    _logs.add('--- Ядро: sing-box (libbox), XHTTP Transport ---');
    _logs.addAll(VpnService.logHistory);

    _logSub = VpnService.logsStream.listen((line) {
      if (mounted) {
        setState(() {
          _logs.add(line);
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    });
  }

  void _copyLogs() {
    Clipboard.setData(ClipboardData(text: _logs.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Логи скопированы в буфер обмена'),
        backgroundColor: AppColors.cyberCyan,
      ),
    );
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
      _logs.add('--- Консоль очищена ---');
    });
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      appBar: AppBar(
        backgroundColor: AppColors.voidDark,
        elevation: 0,
        title: const Text(
          'ТЕРМИНАЛ / ЛОГИ',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            letterSpacing: 0.8,
          ),
        ),
        actions: [
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
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(12),
        color: AppColors.voidBlack,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _logs.length,
          itemBuilder: (context, index) {
            final line = _logs[index];
            final isError = line.contains('Error') || line.contains('Ошибка') || line.contains('ERR');
            final isHighlight = line.contains('linkpc') || line.contains('Active') || line.contains('запущен');

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: SelectableText(
                line,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: isError
                      ? AppColors.error
                      : (isHighlight ? AppColors.cyberCyan : AppColors.textSecondary),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
