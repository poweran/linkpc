import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Holographic Telemetry Bar with animated mini radar sweep and routing readout.
class TelemetryBar extends StatefulWidget {
  final String statusText;

  const TelemetryBar({
    super.key,
    this.statusText = 'Защищенное соединение',
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
        children: [
          // Animated Mini Radar Sweep Scanner
          AnimatedBuilder(
            animation: _radarController,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(18, 18),
                painter: _MiniRadarPainter(
                  sweepAngle: _radarController.value * 2 * pi,
                  hasSignal: true,
                  signalColor: AppColors.neonEmerald,
                ),
              );
            },
          ),

          const SizedBox(width: 10),

          // Telemetry Route Description
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
