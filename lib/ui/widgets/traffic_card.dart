import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/math/hyper_geometry.dart';
import '../../core/models/traffic_stats.dart';
import '../../core/services/speed_test_service.dart';
import '../../core/utils/formatters.dart';
import 'cyber_card.dart';

/// Multidimensional Traffic Card driven by true Fourier spectral decomposition
/// of network stream throughput, caustic wave fills, and golden ratio telemetry.
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
  late final AnimationController _spectralController;

  @override
  void initState() {
    super.initState();
    _spectralController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _spectralController.dispose();
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
          ? AppColors.neonEmerald.withOpacity(0.4)
          : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Mathematical Spectrum Descriptor
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
                                color: AppColors.neonEmerald.withOpacity(0.9),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ФУРЬЕ-СПЕКТР СЕТЕВОГО ПОТОКА',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      letterSpacing: 0.8,
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
                  isConnected ? 'HARMONICS // 1/f' : 'EQUILIBRIUM',
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

          // Speed HUD Capsules
          Row(
            children: [
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

          // Real-time Fourier Harmonic Oscilloscope Screen
          Container(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.voidBlack.withOpacity(0.85),
              border: Border.all(color: AppColors.border.withOpacity(0.7)),
            ),
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _spectralController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _FourierHarmonicVisualizerPainter(
                      progress: _spectralController.value,
                      isConnected: isConnected,
                      downBytesPerSec: downSpeed,
                      upBytesPerSec: upSpeed,
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),

          // Session Duration & Integrated Volume
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

          // Speed Test Module
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
        color: AppColors.voidBlack.withOpacity(0.65),
        border: Border.all(
          color: isActive ? accentColor.withOpacity(0.5) : AppColors.border,
          width: 0.9,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              border: Border.all(color: accentColor.withOpacity(0.35)),
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

/// Custom painter executing real-time Fourier series wave synthesis with caustic fills.
class _FourierHarmonicVisualizerPainter extends CustomPainter {
  final double progress;
  final bool isConnected;
  final int downBytesPerSec;
  final int upBytesPerSec;

  _FourierHarmonicVisualizerPainter({
    required this.progress,
    required this.isConnected,
    required this.downBytesPerSec,
    required this.upBytesPerSec,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height * 0.5;
    final w = size.width;

    // Harmonic Centerline & Grid Coordinates
    final gridPaint = Paint()
      ..color = AppColors.border.withOpacity(0.35)
      ..strokeWidth = 0.6;
    canvas.drawLine(Offset(0, midY), Offset(w, midY), gridPaint);
    canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.5, size.height), gridPaint);

    final time = progress * MathConstants.tau;

    if (!isConnected) {
      // Ethereal Standing Wave Equilibrium: y = A · sin(kx) · cos(ωt)
      final eqPath = Path();
      eqPath.moveTo(0, midY);
      for (double x = 0; x <= w; x += 2) {
        final t = x / w;
        final y = midY + sin(t * MathConstants.tau * 2.0) * cos(time) * 3.5;
        eqPath.lineTo(x, y);
      }
      final eqPaint = Paint()
        ..color = AppColors.cyberCyan.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawPath(eqPath, eqPaint);
      return;
    }

    // Dynamic Fundamental Amplitudes in logarithmic scale
    final downIntensity = (downBytesPerSec > 0
        ? (log(downBytesPerSec + 10) / log(100000000)).clamp(0.2, 1.0)
        : 0.12) * (size.height * 0.38);

    final upIntensity = (upBytesPerSec > 0
        ? (log(upBytesPerSec + 10) / log(100000000)).clamp(0.2, 1.0)
        : 0.12) * (size.height * 0.32);

    // 1. Inbound Fourier Harmonic Ribbon (Cyan with Caustic Fill)
    final downPath = Path();
    final downFillPath = Path();
    downPath.moveTo(0, midY);
    downFillPath.moveTo(0, midY);

    for (double x = 0; x <= w; x += 2.0) {
      final nx = x / w;
      // Multi-harmonic Fourier Synthesis: Fundamental + 4 Harmonics
      final yOffset = FourierFlowHarmonics.evaluate(
        normalizedX: nx,
        time: time,
        baseFrequency: 1.5,
        fundamentalAmp: downIntensity,
        harmonicCount: 4,
      );
      final y = midY - yOffset;
      downPath.lineTo(x, y);
      downFillPath.lineTo(x, y);
    }
    downFillPath.lineTo(w, midY);
    downFillPath.close();

    // Caustic Under-Wave Fill
    final downFillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.cyberCyan.withOpacity(0.22),
          AppColors.cyberCyan.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(downFillPath, downFillPaint);

    final downLinePaint = Paint()
      ..color = AppColors.cyberCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(downPath, downLinePaint);

    // 2. Outbound Harmonic Wave (Neon Emerald)
    final upPath = Path();
    upPath.moveTo(0, midY);
    for (double x = 0; x <= w; x += 2.0) {
      final nx = x / w;
      final yOffset = FourierFlowHarmonics.evaluate(
        normalizedX: nx,
        time: -time * 0.8,
        baseFrequency: 2.0,
        fundamentalAmp: upIntensity,
        harmonicCount: 3,
      );
      final y = midY + yOffset;
      upPath.lineTo(x, y);
    }

    final upLinePaint = Paint()
      ..color = AppColors.neonEmerald.withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(upPath, upLinePaint);
  }

  @override
  bool shouldRepaint(covariant _FourierHarmonicVisualizerPainter oldDelegate) {
    return true;
  }
}
