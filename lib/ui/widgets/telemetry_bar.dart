import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Holographic Quantum Telemetry Bar with animated mini 3D radar sweep,
/// server latency scanner, and futuristic HUD routing readout.
class TelemetryBar extends StatefulWidget {
  final int? pingMs;
  final String statusText;
  final VoidCallback? onRefreshPing;

  const TelemetryBar({
    super.key,
    this.pingMs,
    this.statusText = 'DIM-LINK // МОСКВА → ЕРЕВАН // VLESS-XHTTP',
    this.onRefreshPing,
  });

  @override
  State<TelemetryBar> createState() => _TelemetryBarState();
}

class _TelemetryBarState extends State<TelemetryBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPing = widget.pingMs != null && widget.pingMs! > 0;
    final pingColor = (hasPing && widget.pingMs! < 80)
        ? AppColors.neonEmerald
        : (hasPing && widget.pingMs! < 180 ? AppColors.cyberCyan : AppColors.warning);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.voidDark.withOpacity(0.85),
        border: Border(
          top: BorderSide(color: AppColors.cyberCyan.withOpacity(0.18), width: 1),
          bottom: BorderSide(color: AppColors.cyberCyan.withOpacity(0.25), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyberCyan.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Animated Radar Scanner + Routing Telemetry Text
          Expanded(
            child: Row(
              children: [
                // Mini 3D Radar Sweep Scanner
                AnimatedBuilder(
                  animation: _radarController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: const Size(18, 18),
                      painter: _MiniRadarPainter(
                        sweepAngle: _radarController.value * 2 * pi,
                        hasSignal: hasPing,
                        signalColor: pingColor,
                      ),
                    );
                  },
                ),

                const SizedBox(width: 10),

                // Telemetry Route Description
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.cyberCyan.withOpacity(0.12),
                          border: Border.all(color: AppColors.cyberCyan.withOpacity(0.35), width: 0.6),
                        ),
                        child: const Text(
                          'HUD',
                          style: TextStyle(
                            color: AppColors.cyberCyan,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.statusText,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.skyBlue,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Right: Latency Badge with Glow & Interactive Refresh
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onRefreshPing,
              splashColor: AppColors.cyberCyan.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pingColor.withOpacity(0.08),
                  border: Border.all(color: pingColor.withOpacity(0.4), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: hasPing ? pingColor : AppColors.textMuted,
                        shape: BoxShape.circle,
                        boxShadow: hasPing
                            ? [
                                BoxShadow(
                                  color: pingColor.withOpacity(0.8),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasPing ? '${widget.pingMs} ms' : '--- ms',
                      style: TextStyle(
                        color: hasPing ? pingColor : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      Icons.refresh_rounded,
                      size: 13,
                      color: pingColor.withOpacity(0.8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini radar sweep painter with rotating beam and glowing blip.
class _MiniRadarPainter extends CustomPainter {
  final double sweepAngle;
  final bool hasSignal;
  final Color signalColor;

  _MiniRadarPainter({
    required this.sweepAngle,
    required this.hasSignal,
    required this.signalColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = size.width * 0.5 - 1.0;

    // Outer Reticle Ring
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = AppColors.cyberCyan.withOpacity(0.35);
    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawCircle(center, radius * 0.5, ringPaint);

    // Crosshairs
    final crossPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = AppColors.cyberCyan.withOpacity(0.25);
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), crossPaint);

    // Rotating Sweep Beam Sector
    final sweepPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: pi * 0.45,
        colors: [
          signalColor.withOpacity(0.4),
          signalColor.withOpacity(0.0),
        ],
        transform: GradientRotation(sweepAngle - pi * 0.45),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);

    // Signal Blip (Center Node)
    final blipPaint = Paint()..style = PaintingStyle.fill;
    blipPaint.color = hasSignal ? signalColor : AppColors.textMuted;
    canvas.drawCircle(center, 2.0, blipPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniRadarPainter oldDelegate) {
    return true;
  }
}
