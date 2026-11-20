import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/traffic_stats.dart';
import '../../core/utils/formatters.dart';
import 'cyber_card.dart';

class TrafficCard extends StatelessWidget {
  final TrafficStats stats;
  final bool isConnected;

  const TrafficCard({
    super.key,
    required this.stats,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
    );
  }
}
