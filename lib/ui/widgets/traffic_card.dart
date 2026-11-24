import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/traffic_stats.dart';
import '../../core/services/speed_test_service.dart';
import '../../core/utils/formatters.dart';
import 'cyber_card.dart';

class TrafficCard extends StatelessWidget {
  final TrafficStats stats;
  final bool isConnected;
  final SpeedTestProgress? speedTestProgress;
  final SpeedTestResult? lastSpeedTestResult;
  final VoidCallback? onRunSpeedTest;

  const TrafficCard({
    super.key,
    required this.stats,
    required this.isConnected,
    this.speedTestProgress,
    this.lastSpeedTestResult,
    this.onRunSpeedTest,
  });

  @override
  Widget build(BuildContext context) {
    final isTesting = speedTestProgress?.isRunning ?? false;

    return CyberCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderColor: isConnected ? AppColors.neonEmerald.withOpacity(0.3) : AppColors.border,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Download Speed
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.cyberCyan.withOpacity(0.1),
                        border: Border.all(color: AppColors.cyberCyan.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.arrow_downward_rounded, size: 16, color: AppColors.cyberCyan),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'СКОРОСТЬ ВХОД',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          isConnected ? Formatters.formatSpeed(stats.downloadSpeedBytesPerSec) : '0 KB/s',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Upload Speed
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.skyBlue.withOpacity(0.1),
                        border: Border.all(color: AppColors.skyBlue.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, size: 16, color: AppColors.skyBlue),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'СКОРОСТЬ ИСХОД',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          isConnected ? Formatters.formatSpeed(stats.uploadSpeedBytesPerSec) : '0 KB/s',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'ВРЕМЯ СЕССИИ: ',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace'),
                  ),
                  Text(
                    isConnected ? Formatters.formatDuration(stats.sessionDuration) : '00:00:00',
                    style: const TextStyle(
                      color: AppColors.cyberCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text(
                    'ТРАФИК СЕССИИ: ',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace'),
                  ),
                  Text(
                    isConnected
                        ? Formatters.formatBytes(stats.totalDownloadedBytes + stats.totalUploadedBytes)
                        : '0 B',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Active Speed Test Row (when connected)
          if (isConnected) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            if (isTesting) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.neonEmerald,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ЗАМЕР: ${speedTestProgress?.statusText ?? ""}',
                        style: const TextStyle(
                          color: AppColors.neonEmerald,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${((speedTestProgress?.progress ?? 0.0) * 100).toInt()}%',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: speedTestProgress?.progress ?? 0.0,
                  minHeight: 3,
                  backgroundColor: AppColors.surface,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.neonEmerald),
                ),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.speed_rounded, size: 14, color: AppColors.cyberCyan),
                      const SizedBox(width: 6),
                      Text(
                        lastSpeedTestResult != null
                            ? 'РЕЗУЛЬТАТ: ${lastSpeedTestResult!.formattedMbps}'
                            : 'ТЕСТ СКОРОСТИ СОЕДИНЕНИЯ',
                        style: TextStyle(
                          color: lastSpeedTestResult != null ? AppColors.neonEmerald : AppColors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: onRunSpeedTest,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cyberCyan.withOpacity(0.12),
                        border: Border.all(color: AppColors.cyberCyan.withOpacity(0.4)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow_rounded, size: 13, color: AppColors.cyberCyan),
                          const SizedBox(width: 4),
                          Text(
                            lastSpeedTestResult != null ? 'ПОВТОРИТЬ' : 'ЗАМЕР',
                            style: const TextStyle(
                              color: AppColors.cyberCyan,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
