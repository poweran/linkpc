import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/vpn_state.dart';

/// Multidimensional interactive space background with 3D perspective grid,
/// floating quantum particles, volumetric energy nebulas, and pointer parallax.
class MultidimensionalSpace extends StatefulWidget {
  final Widget child;
  final VpnStatus status;
  final bool enableParallax;

  const MultidimensionalSpace({
    super.key,
    required this.child,
    required this.status,
    this.enableParallax = true,
  });

  @override
  State<MultidimensionalSpace> createState() => _MultidimensionalSpaceState();
}

class _MultidimensionalSpaceState extends State<MultidimensionalSpace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  final List<_QuantumParticle> _particles = [];
  final Random _rng = Random(42);

  double _tiltX = 0.0;
  double _tiltY = 0.0;
  Offset _pointerOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _initParticles();
  }

  void _initParticles() {
    _particles.clear();
    const count = 46;
    for (int i = 0; i < count; i++) {
      _particles.add(
        _QuantumParticle(
          x: _rng.nextDouble(),
          y: _rng.nextDouble(),
          z: _rng.nextDouble() * 0.8 + 0.2, // Depth factor (0.2 far to 1.0 close)
          size: _rng.nextDouble() * 2.2 + 0.8,
          speed: _rng.nextDouble() * 0.0008 + 0.0004,
          baseAlpha: _rng.nextDouble() * 0.5 + 0.3,
          colorHue: i % 3 == 0
              ? AppColors.cyberCyan
              : (i % 3 == 1 ? AppColors.neonViolet : AppColors.neonEmerald),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onPointerHover(PointerHoverEvent event, Size size) {
    if (!widget.enableParallax || size.width == 0 || size.height == 0) return;
    final normalizedX = (event.localPosition.dx / size.width - 0.5) * 2.0;
    final normalizedY = (event.localPosition.dy / size.height - 0.5) * 2.0;

    setState(() {
      _tiltX = normalizedX.clamp(-1.0, 1.0);
      _tiltY = normalizedY.clamp(-1.0, 1.0);
      _pointerOffset = event.localPosition;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.status.isConnected;
    final isBusy = widget.status.isBusy;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return MouseRegion(
          onHover: (e) => _onPointerHover(e, size),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Living Multidimensional Universe Canvas
              AnimatedBuilder(
                animation: _animController,
                builder: (context, _) {
                  return CustomPaint(
                    size: size,
                    painter: _MultidimensionalSpacePainter(
                      progress: _animController.value,
                      particles: _particles,
                      isConnected: isConnected,
                      isBusy: isBusy,
                      tiltX: _tiltX,
                      tiltY: _tiltY,
                      pointerOffset: _pointerOffset,
                    ),
                  );
                },
              ),

              // Foreground Content
              widget.child,
            ],
          ),
        );
      },
    );
  }
}

class _QuantumParticle {
  double x;
  double y;
  final double z; // 3D depth layer
  final double size;
  final double speed;
  final double baseAlpha;
  final Color colorHue;

  _QuantumParticle({
    required this.x,
    required this.y,
    required this.z,
    required this.size,
    required this.speed,
    required this.baseAlpha,
    required this.colorHue,
  });
}

class _MultidimensionalSpacePainter extends CustomPainter {
  final double progress;
  final List<_QuantumParticle> particles;
  final bool isConnected;
  final bool isBusy;
  final double tiltX;
  final double tiltY;
  final Offset pointerOffset;

  _MultidimensionalSpacePainter({
    required this.progress,
    required this.particles,
    required this.isConnected,
    required this.isBusy,
    required this.tiltX,
    required this.tiltY,
    required this.pointerOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // 1. Deep Space Base
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.voidBlack,
          AppColors.background,
          Color(0xFF040711),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

    // 2. Volumetric Multidimensional Nebulas
    _drawVolumetricNebula(canvas, size);

    // 3. 3D Perspective Hyperspace Grid (Bottom & Horizon)
    _drawPerspectiveGrid(canvas, size);

    // 4. Floating Quantum Particles & Data Streams
    _drawQuantumParticles(canvas, size);

    // 5. Subtle Holographic Vignette & Scanlines
    _drawHolographicVignette(canvas, size);
  }

  void _drawVolumetricNebula(Canvas canvas, Size size) {
    final centerPulse = sin(progress * 2 * pi) * 0.15 + 0.85;

    // Primary Core Nebula (Center / slightly upper behind power button)
    final coreCenter = Offset(
      size.width * 0.5 + (tiltX * 18.0),
      size.height * 0.28 + (tiltY * 18.0),
    );

    final coreColor = isConnected
        ? AppColors.neonEmerald
        : (isBusy ? AppColors.cyberCyan : AppColors.deepCyan);

    final coreGradient = RadialGradient(
      center: Alignment.center,
      radius: 0.85,
      colors: [
        coreColor.withOpacity(isConnected ? 0.18 * centerPulse : 0.09 * centerPulse),
        AppColors.neonViolet.withOpacity(0.06 * centerPulse),
        Colors.transparent,
      ],
      stops: const [0.0, 0.45, 1.0],
    );

    final corePaint = Paint()
      ..shader = coreGradient.createShader(
        Rect.fromCircle(center: coreCenter, radius: size.width * 0.72),
      );
    canvas.drawCircle(coreCenter, size.width * 0.72, corePaint);

    // Secondary Nebula (Bottom Right Quantum Void)
    final subCenter = Offset(size.width * 0.85, size.height * 0.8);
    final subPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isConnected ? AppColors.cyberCyan : AppColors.neonViolet).withOpacity(0.07),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: subCenter, radius: size.width * 0.55));
    canvas.drawCircle(subCenter, size.width * 0.55, subPaint);
  }

  void _drawPerspectiveGrid(Canvas canvas, Size size) {
    final horizonY = size.height * 0.58;
    final bottomY = size.height;
    final gridHeight = bottomY - horizonY;
    if (gridHeight <= 0) return;

    final vanishingPoint = Offset(
      size.width * 0.5 + (tiltX * 36.0),
      horizonY - 20.0,
    );

    // Perspective Lines radiating from vanishing point
    final linePaint = Paint()
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final rayColor = isConnected
        ? AppColors.neonEmerald
        : (isBusy ? AppColors.cyberCyan : AppColors.skyBlue);

    const numRays = 14;
    for (int i = 0; i <= numRays; i++) {
      final t = i / numRays;
      final bottomX = (t - 0.5) * size.width * 2.2 + (size.width * 0.5);

      final alpha = (1.0 - (t - 0.5).abs() * 1.5).clamp(0.05, 0.45);
      linePaint.color = rayColor.withOpacity(alpha * (isConnected ? 0.35 : 0.2));

      canvas.drawLine(vanishingPoint, Offset(bottomX, bottomY), linePaint);
    }

    // Moving Horizontal Rungs (Hyperspace warp motion forward)
    final speedMultiplier = isConnected ? 2.5 : (isBusy ? 4.0 : 0.8);
    final offsetProg = (progress * speedMultiplier) % 1.0;

    const numRungs = 9;
    for (int i = 0; i < numRungs; i++) {
      final rungT = ((i + offsetProg) / numRungs) % 1.0;
      // Exponential perspective curve for genuine 3D depth
      final yCurve = pow(rungT, 2.4).toDouble();
      final currentY = horizonY + yCurve * gridHeight;

      final rungAlpha = (yCurve * (1.0 - yCurve * 0.2)).clamp(0.0, 1.0);
      linePaint.color = rayColor.withOpacity(rungAlpha * (isConnected ? 0.4 : 0.22));
      linePaint.strokeWidth = 0.8 + yCurve * 1.4;

      // Draw horizontal rung across perspective bounds
      final spanHalf = (yCurve * 1.4 + 0.15) * size.width * 0.8;
      final centerX = size.width * 0.5 + (tiltX * 24.0 * (1 - yCurve));

      canvas.drawLine(
        Offset((centerX - spanHalf).clamp(0, size.width), currentY),
        Offset((centerX + spanHalf).clamp(0, size.width), currentY),
        linePaint,
      );
    }

    // Horizon glowing boundary line
    final horizonPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          rayColor.withOpacity(isConnected ? 0.5 : 0.25),
          rayColor.withOpacity(isConnected ? 0.8 : 0.4),
          rayColor.withOpacity(isConnected ? 0.5 : 0.25),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, horizonY - 1, size.width, 2))
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(0, horizonY), Offset(size.width, horizonY), horizonPaint);
  }

  void _drawQuantumParticles(Canvas canvas, Size size) {
    final particlePaint = Paint()..style = PaintingStyle.fill;
    final speedFactor = isConnected ? 2.8 : (isBusy ? 4.0 : 1.0);

    for (final p in particles) {
      // Movement with depth-based speed
      p.y -= p.speed * speedFactor * p.z;
      if (p.y < 0.0) {
        p.y = 1.0;
        p.x = (p.x + (tiltX * 0.1)) % 1.0;
      }

      // Parallax shift based on particle depth Z
      final px = (p.x * size.width + (tiltX * p.z * 32.0)) % size.width;
      final py = (p.y * size.height + (tiltY * p.z * 24.0)) % size.height;

      final pColor = isConnected && p.colorHue != AppColors.neonEmerald
          ? AppColors.neonEmerald
          : p.colorHue;

      final dynamicAlpha = (p.baseAlpha * (0.6 + sin((progress * 4 * pi) + p.x * 10) * 0.4))
          .clamp(0.0, 1.0);

      particlePaint.color = pColor.withOpacity(dynamicAlpha * p.z);
      final radius = p.size * p.z;

      canvas.drawCircle(Offset(px, py), radius, particlePaint);

      // Light trail for connected high-speed state
      if (isConnected && p.z > 0.5) {
        final trailPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              pColor.withOpacity(dynamicAlpha * 0.6),
            ],
          ).createShader(Rect.fromLTWH(px - 1, py, 2, radius * 6))
          ..strokeWidth = radius * 0.8;
        canvas.drawLine(Offset(px, py), Offset(px, py + radius * 6), trailPaint);
      }
    }
  }

  void _drawHolographicVignette(Canvas canvas, Size size) {
    // Top and bottom edge darkening for cinematic multidimensional focus
    final vignettePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.08, 0.88, 1.0],
        colors: [
          Color(0xDD030508),
          Colors.transparent,
          Colors.transparent,
          Color(0xF0030508),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);
  }

  @override
  bool shouldRepaint(covariant _MultidimensionalSpacePainter oldDelegate) {
    return true; // continuous animation for living cosmic backdrop
  }
}
