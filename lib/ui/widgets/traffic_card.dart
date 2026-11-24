import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/traffic_stats.dart';
import '../../core/services/speed_test_service.dart';
import '../../core/utils/formatters.dart';
import 'cyber_card.dart';

/// Multidimensional Traffic Card with live animated quantum waveform visualizer,
/// high-precision speed metrics, session telemetry, and holographic speed testing.
class TrafficCard extends StatefulWidget {
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
  State<TrafficCard> createState() => _TrafficCardState();
}

class _TrafficCardState extends State<TrafficCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTesting = widget.speedTestProgress?.isRunning ?? false;
    final isConnected = widget.isConnected;

    final downSpeed = widget.stats.downloadSpeedBytesPerSec;
    final upSpeed = widget.stats.uploadSpeedBytesPerSec;

    return CyberCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderColor: isConnected
          ? AppColors.neonEmerald.withOpacity(0.35)
          : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header: Live Waveform Visualizer & Activity Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isConnected ? AppColors.neonEmerald : AppColors.textMuted,
                      shape: BoxShape.circle,
                      boxShadow: isConnected
                          ? [
                              BoxShadow(
                                color: AppColors.neonEmerald.withOpacity(0.8),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ТЕЛЕМЕТРИЯ СКОРОСТИ И ПОТОКА',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isConnected ? AppColors.neonEmerald : AppColors.borderSubtle).withOpacity(0.12),
                  border: Border.all(
                    color: (isConnected ? AppColors.neonEmerald : AppColors.borderSubtle).withOpacity(0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  isConnected ? 'LIVE // REAL-TIME' : 'STANDBY',
                  style: TextStyle(
                    color: isConnected ? AppColors.neonEmerald : AppColors.textMuted,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Speed Metric HUD Gauges
          Row(
            children: [
              // Download Metric
              Expanded(
                child: _buildSpeedCapsule(
                  title: 'ВХОДЯЩИЙ ПОТОК',
                  speedFormatted: isConnected ? Formatters.formatSpeed(downSpeed) : '0.0 Кбит/с',
                  icon: Icons.south_rounded,
                  accentColor: AppColors.cyberCyan,
                  isActive: isConnected && downSpeed > 0,
                ),
              ),

              const SizedBox(width: 12),

              // Upload Metric
              Expanded(
                child: _buildSpeedCapsule(
                  title: 'ИСХОДЯЩИЙ ПОТОК',
                  speedFormatted: isConnected ? Formatters.formatSpeed(upSpeed) : '0.0 Кбит/с',
                  icon: Icons.north_rounded,
                  accentColor: AppColors.skyBlue,
                  isActive: isConnected && upSpeed > 0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Live Holographic Frequency Waveform Canvas
          Container(
            height: 38,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.voidBlack.withOpacity(0.6),
              border: Border.all(color: AppColors.border.withOpacity(0.7)),
            ),
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _TrafficWaveVisualizerPainter(
                      progress: _waveController.value,
                      isConnected: isConnected,
                      downSpeed: downSpeed,
                      upSpeed: upSpeed,
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),

          // Session Duration & Total Session Traffic
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 5),
                  const Text(
                    'СЕССИЯ: ',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace'),
                  ),
                  Text(
                    isConnected ? Formatters.formatDuration(widget.stats.sessionDuration) : '00:00:00',
                    style: const TextStyle(
                      color: AppColors.cyberCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.data_usage_rounded, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 5),
                  const Text(
                    'ТРАФИК: ',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace'),
                  ),
                  Text(
                    isConnected
                        ? Formatters.formatBytes(widget.stats.totalDownloadedBytes + widget.stats.totalUploadedBytes)
                        : '0 B',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Speed Test Module (when connected)
          if (isConnected) ...[
            const SizedBox(height: 10),
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
                        'ЗАМЕР: ${widget.speedTestProgress?.statusText ?? ""}',
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
                    '${((widget.speedTestProgress?.progress ?? 0.0) * 100).toInt()}%',
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
                  value: widget.speedTestProgress?.progress ?? 0.0,
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
                        widget.lastSpeedTestResult != null
                            ? 'РЕЗУЛЬТАТ: ${widget.lastSpeedTestResult!.formattedMbps}'
                            : 'ТЕСТ ПРОПУСКНОЙ СПОСОБНОСТИ',
                        style: TextStyle(
                          color: widget.lastSpeedTestResult != null ? AppColors.neonEmerald : AppColors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: widget.onRunSpeedTest,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cyberCyan.withOpacity(0.12),
                        border: Border.all(color: AppColors.cyberCyan.withOpacity(0.4)),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cyberCyan.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow_rounded, size: 13, color: AppColors.cyberCyan),
                          const SizedBox(width: 4),
                          Text(
                            widget.lastSpeedTestResult != null ? 'ПОВТОРИТЬ' : 'ЗАМЕР',
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

  Widget _buildSpeedCapsule({
    required String title,
    required String speedFormatted,
    required IconData icon,
    required Color accentColor,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.voidBlack.withOpacity(0.55),
        border: Border.all(
          color: isActive ? accentColor.withOpacity(0.45) : AppColors.border,
          width: 0.9,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              border: Border.all(color: accentColor.withOpacity(0.3)),
            ),
            child: Icon(icon, size: 14, color: accentColor),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 8.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  speedFormatted,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    fontFeatures: const [FontFeature.tabularFigures()],
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

/// Custom painter for dynamic cyber wave oscilloscope reflecting live throughput.
class _TrafficWaveVisualizerPainter extends CustomPainter {
  final double progress;
  final bool isConnected;
  final int downSpeed;
  final int upSpeed;

  _TrafficWaveVisualizerPainter({
    required this.progress,
    required this.isConnected,
    required this.downSpeed,
    required this.upSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height * 0.5;
    final width = size.width;

    // Center Baseline
    final basePaint = Paint()
      ..color = AppColors.border.withOpacity(0.5)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(0, midY), Offset(width, midY), basePaint);

    if (!isConnected) {
      // Gentle dormant carrier wave
      final dormantPath = Path();
      dormantPath.moveTo(0, midY);
      for (double x = 0; x <= width; x += 3) {
        final y = midY + sin((x / width * 4 * pi) + (progress * 2 * pi)) * 3.0;
        dormantPath.lineTo(x, y);
      }
      final dormantPaint = Paint()
        ..color = AppColors.cyberCyan.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawPath(dormantPath, dormantPaint);
      return;
    }

    // Dynamic amplitude based on speed values
    final downIntensity = (downSpeed > 0 ? (log(downSpeed) / log(10000000)).clamp(0.2, 1.0) : 0.15) * 12.0;
    final upIntensity = (upSpeed > 0 ? (log(upSpeed) / log(10000000)).clamp(0.2, 1.0) : 0.15) * 10.0;

    // Inbound Wave (Cyan)
    final downPath = Path();
    downPath.moveTo(0, midY);
    for (double x = 0; x <= width; x += 3) {
      final t = x / width;
      final y = midY - (sin((t * 6 * pi) + (progress * 6 * pi)) * downIntensity * sin(t * pi));
      downPath.lineTo(x, y);
    }
    final downPaint = Paint()
      ..color = AppColors.cyberCyan.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(downPath, downPaint);

    // Outbound Wave (Sky Blue)
    final upPath = Path();
    upPath.moveTo(0, midY);
    for (double x = 0; x <= width; x += 3) {
      final t = x / width;
      final y = midY + (cos((t * 5 * pi) - (progress * 5 * pi)) * upIntensity * sin(t * pi));
      upPath.lineTo(x, y);
    }
    final upPaint = Paint()
      ..color = AppColors.neonEmerald.withOpacity(0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(upPath, upPaint);
  }

  @override
  bool shouldRepaint(covariant _TrafficWaveVisualizerPainter oldDelegate) {
    return true;
  }
}
