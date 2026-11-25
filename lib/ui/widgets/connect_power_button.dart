import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/math/hyper_geometry.dart';
import '../../core/models/vpn_state.dart';

/// 4D Clifford Torus & Hopf Fibration Gateway Core with continuous physical
/// phase integration (zero jumps) and real-time kinetic correlation with live
/// throughput and network latency.
class ConnectPowerButton extends StatefulWidget {
  final VpnStatus status;
  final VoidCallback onTap;
  final double size;
  final int trafficBytesPerSec;
  final int? pingMs;

  const ConnectPowerButton({
    super.key,
    required this.status,
    required this.onTap,
    this.size = 220.0,
    this.trafficBytesPerSec = 0,
    this.pingMs,
  });

  @override
  State<ConnectPowerButton> createState() => _ConnectPowerButtonState();
}

class _ConnectPowerButtonState extends State<ConnectPowerButton>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  // Continuous C¹ Phase Integrators (angular momentum with inertia)
  final PhaseIntegrator _phaseXW = PhaseIntegrator();
  final PhaseIntegrator _phaseYZ = PhaseIntegrator();
  final PhaseIntegrator _phaseZW = PhaseIntegrator();
  final PhaseIntegrator _phasePulse = PhaseIntegrator();

  // Critically Damped Springs for smooth C² pointer and press responses
  final SmoothDamp _tiltXDamp = SmoothDamp();
  final SmoothDamp _tiltYDamp = SmoothDamp();
  final SmoothDamp _pressDamp = SmoothDamp();
  final SmoothDamp _glowDamp = SmoothDamp();

  double _targetTiltX = 0.0;
  double _targetTiltY = 0.0;
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final dt = _lastElapsed == Duration.zero
        ? 0.016
        : (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    // Clamp dt to avoid frame spikes after app pause/resume
    final clampedDt = dt.clamp(0.001, 0.05);

    final isConnected = widget.status.isConnected;
    final isBusy = widget.status.isBusy;

    // Dynamic Angular Velocity correlated with real-time network throughput
    double targetSpeed = 0.45; // Tranquil baseline idle
    if (isBusy) {
      targetSpeed = 3.0; // Rapid quantum synchronization
    } else if (isConnected) {
      // Base speed + logarithmic throughput boost from real-time network bits
      final trafficNorm = widget.trafficBytesPerSec > 0
          ? (log(widget.trafficBytesPerSec + 10) / log(100000000)).clamp(0.0, 1.0)
          : 0.0;
      targetSpeed = 0.9 + trafficNorm * 3.4;
    }

    // Integrate rotation phases continuously: θ(t + dt) = θ(t) + ω(t) · dt
    _phaseXW.update(targetSpeed, clampedDt, responsiveness: 3.5);
    _phaseYZ.update(targetSpeed * MathConstants.invPhi, clampedDt, responsiveness: 3.5);
    _phaseZW.update(targetSpeed * 0.38, clampedDt, responsiveness: 2.5);

    // Pulse frequency correlated with ping latency
    double pulseFreq = 2.2;
    if (widget.pingMs != null && widget.pingMs! > 0) {
      // Lower ping = faster, crisper pulse; higher latency = relaxed pulse
      pulseFreq = (1000.0 / (widget.pingMs!.clamp(20, 600) + 180.0)).clamp(1.2, 4.5);
    }
    _phasePulse.update(pulseFreq, clampedDt, responsiveness: 2.0);

    // Smooth pointer tilt and press depth with critically damped springs
    _tiltXDamp.update(_targetTiltX, 0.12, clampedDt);
    _tiltYDamp.update(_targetTiltY, 0.12, clampedDt);
    _pressDamp.update(_isPressed ? 1.0 : 0.0, 0.07, clampedDt);

    final targetGlow = isConnected ? 1.0 : (isBusy ? 0.8 : (_isHovered ? 0.35 : 0.15));
    _glowDamp.update(targetGlow, 0.25, clampedDt);

    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onPointerHover(PointerHoverEvent event, double totalSize) {
    setState(() {
      _targetTiltX = (event.localPosition.dx / totalSize - 0.5) * 2.0;
      _targetTiltY = (event.localPosition.dy / totalSize - 0.5) * 2.0;
    });
  }

  void _onPointerExit() {
    setState(() {
      _isHovered = false;
      _targetTiltX = 0.0;
      _targetTiltY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.status.isConnected;
    final isBusy = widget.status.isBusy;

    final primaryColor = isConnected
        ? AppColors.neonEmerald
        : (isBusy ? AppColors.cyberCyan : AppColors.deepCyan);

    final totalSize = widget.size + 40.0;

    final smoothTiltX = _tiltXDamp.current;
    final smoothTiltY = _tiltYDamp.current;
    final smoothPress = _pressDamp.current;
    final smoothGlow = _glowDamp.current;
    final pulse = sin(_phasePulse.phase) * 0.5 + 0.5;

    // Build Continuous 4D Rotation Matrix with SO(4) double rotation
    final rotXW = Matrix4D.rotationXW(_phaseXW.phase + smoothTiltX * 0.45);
    final rotYZ = Matrix4D.rotationYZ(_phaseYZ.phase + smoothTiltY * 0.45);
    final rotZW = Matrix4D.rotationZW(_phaseZW.phase);
    final rotYW = Matrix4D.rotationYW(smoothTiltY * 0.3);

    final full4DMatrix = rotYW * rotZW * rotYZ * rotXW;

    // Continuous stereographic pole distance: plunges gracefully on press
    final stereoDist = 1.65 - (smoothPress * 0.35);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => _onPointerExit(),
      onHover: (e) => _onPointerHover(e, totalSize),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: totalSize,
          height: totalSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Layer 0: Volumetric Cosmic Glow Aura (Smoothly Damped)
              _buildHarmonicAura(primaryColor, pulse, smoothGlow, widget.size),

              // Layer 1: Living 4D Clifford Torus & Hopf Fibration Canvas
              RepaintBoundary(
                child: CustomPaint(
                  size: Size(totalSize, totalSize),
                  painter: _HopfFibrationPainter(
                    matrix4D: full4DMatrix,
                    stereoDistance: stereoDist,
                    primaryColor: primaryColor,
                    secondaryColor: isConnected ? AppColors.cyberCyan : AppColors.hologramPurple,
                    isConnected: isConnected,
                    isBusy: isBusy,
                    glowIntensity: smoothGlow,
                    flowSpeed: _phaseXW.currentSpeed,
                    time: _phaseXW.phase,
                  ),
                ),
              ),

              // Layer 2: Central Gravitational Focal Core
              _buildGravitationalCore(
                widget.size * 0.52,
                primaryColor,
                isConnected,
                isBusy,
                smoothPress,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHarmonicAura(Color color, double pulse, double glowIntensity, double baseSize) {
    final auraRadius = baseSize * (0.8 + glowIntensity * 0.25);
    final opacity = (glowIntensity * 0.32 + pulse * 0.1).clamp(0.05, 0.55);

    return Container(
      width: auraRadius,
      height: auraRadius,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(opacity),
            blurRadius: 40.0 + glowIntensity * 28.0,
            spreadRadius: 2.0 + glowIntensity * 6.0,
          ),
          if (glowIntensity > 0.5)
            BoxShadow(
              color: AppColors.cyberCyan.withOpacity(opacity * 0.6),
              blurRadius: 36.0,
              spreadRadius: 2.0,
            ),
        ],
      ),
    );
  }

  Widget _buildGravitationalCore(
    double diameter,
    Color primaryColor,
    bool isConnected,
    bool isBusy,
    double smoothPress,
  ) {
    final scale = 1.0 - (smoothPress * 0.08);

    return Transform.scale(
      scale: scale,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.25, -0.35),
            radius: 0.92,
            colors: [
              Color.lerp(
                AppColors.surfaceLight,
                primaryColor.withOpacity(0.4),
                isConnected ? 0.5 : 0.1,
              )!,
              AppColors.voidDark,
              AppColors.voidBlack,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
          border: Border.all(
            color: primaryColor.withOpacity(isConnected ? 0.8 : (isBusy ? 0.6 : 0.3)),
            width: isConnected ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(isConnected ? 0.45 : 0.12),
              blurRadius: 20.0,
              spreadRadius: 1.0,
            ),
            const BoxShadow(
              color: Color(0xDD000000),
              offset: Offset(0, 8),
              blurRadius: 18.0,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Optical Specular Sheen (Curved Crystal Reflection)
            Positioned(
              top: diameter * 0.12,
              left: diameter * 0.2,
              child: Container(
                width: diameter * 0.6,
                height: diameter * 0.26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(diameter * 0.3, diameter * 0.13),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(isConnected ? 0.3 : 0.12),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Inner Core Glyph and Status
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.power_settings_new_rounded,
                  size: diameter * 0.38,
                  color: isConnected
                      ? AppColors.neonEmerald
                      : (isBusy ? AppColors.cyberCyan : AppColors.textMuted),
                  shadows: [
                    Shadow(
                      color: primaryColor.withOpacity(isConnected ? 0.9 : 0.4),
                      blurRadius: isConnected ? 16.0 : 6.0,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isConnected ? 'АКТИВЕН' : (isBusy ? 'СВЯЗЬ...' : 'СТАРТ'),
                  style: TextStyle(
                    color: isConnected
                        ? AppColors.neonEmerald
                        : (isBusy ? AppColors.cyberCyan : AppColors.textSecondary),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for continuous 4D stereographic projection of Clifford Torus and Hopf fibers.
class _HopfFibrationPainter extends CustomPainter {
  final Matrix4D matrix4D;
  final double stereoDistance;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isConnected;
  final bool isBusy;
  final double glowIntensity;
  final double flowSpeed;
  final double time;

  _HopfFibrationPainter({
    required this.matrix4D,
    required this.stereoDistance,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isConnected,
    required this.isBusy,
    required this.glowIntensity,
    required this.flowSpeed,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.5;
    final fovScale = size.width * 0.38;

    final fiberPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rings = CliffordTorus4D.ringFamilies;
    final hopfFibers = CliffordTorus4D.hopfFibers;

    // 1. Stereographic Clifford Torus Rings
    for (int i = 0; i < rings.length; i++) {
      final ring = rings[i];
      final path = Path();
      bool first = true;
      double avgW = 0.0;

      for (int j = 0; j < ring.length; j++) {
        final v4 = ring[j];
        final rotated = matrix4D.transform(v4);
        avgW += rotated.w;

        final p3 = rotated.projectStereographic(distance: stereoDistance);
        final sx = cx + p3.x * fovScale;
        final sy = cy + p3.y * fovScale;

        if (first) {
          path.moveTo(sx, sy);
          first = false;
        } else {
          path.lineTo(sx, sy);
        }
      }
      path.close();

      avgW /= ring.length;
      final depthAlpha = ((avgW + 1.0) * 0.5).clamp(0.08, 0.95);
      final strokeW = ((avgW + 1.0) * 0.75 + 0.4).clamp(0.5, 1.8);

      final ringColor = Color.lerp(secondaryColor, primaryColor, (i % 2 == 0) ? 0.7 : 0.3)!;
      fiberPaint.color = ringColor.withOpacity(depthAlpha * (0.2 + glowIntensity * 0.45));
      fiberPaint.strokeWidth = strokeW;

      canvas.drawPath(path, fiberPaint);
    }

    // 2. Villarceau Hopf Geodesics
    for (int k = 0; k < hopfFibers.length; k++) {
      final fiber = hopfFibers[k];
      final path = Path();
      bool first = true;
      double avgW = 0.0;

      for (int s = 0; s < fiber.length; s++) {
        final v4 = fiber[s];
        final rotated = matrix4D.transform(v4);
        avgW += rotated.w;

        final p3 = rotated.projectStereographic(distance: stereoDistance);
        final sx = cx + p3.x * fovScale;
        final sy = cy + p3.y * fovScale;

        if (first) {
          path.moveTo(sx, sy);
          first = false;
        } else {
          path.lineTo(sx, sy);
        }
      }

      avgW /= fiber.length;
      final depthAlpha = ((avgW + 1.0) * 0.5).clamp(0.12, 1.0);

      fiberPaint.color = primaryColor.withOpacity(depthAlpha * (0.25 + glowIntensity * 0.5));
      fiberPaint.strokeWidth = isConnected ? 1.2 : 0.8;
      canvas.drawPath(path, fiberPaint);

      // Quantum nodes flowing along geodesics without leaps
      if (isConnected || isBusy) {
        final nodeT = (time * 0.18 + (k / hopfFibers.length)) % 1.0;
        final nodeIndex = (nodeT * (fiber.length - 1)).toInt().clamp(0, fiber.length - 1);
        final nodeV4 = matrix4D.transform(fiber[nodeIndex]);
        final nodeP3 = nodeV4.projectStereographic(distance: stereoDistance);
        final nx = cx + nodeP3.x * fovScale;
        final ny = cy + nodeP3.y * fovScale;

        final nodeAlpha = ((nodeV4.w + 1.0) * 0.5).clamp(0.2, 1.0) * glowIntensity;
        final nodePaint = Paint()
          ..style = PaintingStyle.fill
          ..color = (isConnected ? AppColors.neonEmerald : AppColors.cyberCyan)
              .withOpacity(nodeAlpha);

        canvas.drawCircle(Offset(nx, ny), isConnected ? 2.8 : 2.0, nodePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HopfFibrationPainter oldDelegate) {
    return true;
  }
}
