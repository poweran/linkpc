import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/math/hyper_geometry.dart';
import '../../core/models/vpn_state.dart';

/// True Multidimensional Space Background:
/// 1. Riemannian curved spacetime manifold with potential well geodesics.
/// 2. Phase-space Clifford Strange Attractor quantum dust field.
/// 3. Interactive pointer gravitational perturbation.
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
  final List<Vector4D> _attractorParticles = [];

  double _gravityWellX = 0.5;
  double _gravityWellY = 0.5;
  double _targetGravityX = 0.5;
  double _targetGravityY = 0.5;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    _initCliffordAttractor();
  }

  /// Generate points on the Clifford Strange Attractor:
  /// x_{n+1} = sin(a y_n) + c cos(a x_n)
  /// y_{n+1} = sin(b x_n) + d cos(b y_n)
  void _initCliffordAttractor() {
    _attractorParticles.clear();
    const a = -1.4;
    const b = 1.6;
    const c = 1.0;
    const d = 0.7;

    double x = 0.1;
    double y = 0.1;

    // Settle onto the attractor attractor manifold
    for (int i = 0; i < 100; i++) {
      final nx = sin(a * y) + c * cos(a * x);
      final ny = sin(b * x) + d * cos(b * y);
      x = nx;
      y = ny;
    }

    const count = 72;
    for (int i = 0; i < count; i++) {
      final nx = sin(a * y) + c * cos(a * x);
      final ny = sin(b * x) + d * cos(b * y);
      x = nx;
      y = ny;

      // Map to normalized [0, 1] bounds with depth z and phase offset w
      final normX = (x + 2.5) / 5.0;
      final normY = (y + 2.5) / 5.0;
      final depth = (i / count);
      final phase = (i * MathConstants.invPhi) % 1.0;

      _attractorParticles.add(Vector4D(normX, normY, depth, phase));
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onPointerHover(PointerHoverEvent event, Size size) {
    if (!widget.enableParallax || size.width == 0 || size.height == 0) return;
    setState(() {
      _targetGravityX = (event.localPosition.dx / size.width).clamp(0.05, 0.95);
      _targetGravityY = (event.localPosition.dy / size.height).clamp(0.05, 0.95);
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
              AnimatedBuilder(
                animation: _animController,
                builder: (context, _) {
                  // Smoothly interpolate gravity well toward cursor
                  _gravityWellX += (_targetGravityX - _gravityWellX) * 0.08;
                  _gravityWellY += (_targetGravityY - _gravityWellY) * 0.08;

                  return CustomPaint(
                    size: size,
                    painter: _RiemannianManifoldPainter(
                      progress: _animController.value,
                      particles: _attractorParticles,
                      gravityX: _gravityWellX,
                      gravityY: _gravityWellY,
                      isConnected: isConnected,
                      isBusy: isBusy,
                    ),
                  );
                },
              ),
              widget.child,
            ],
          ),
        );
      },
    );
  }
}

/// Custom painter for Riemannian curved spacetime manifold and Clifford attractor dust.
class _RiemannianManifoldPainter extends CustomPainter {
  final double progress;
  final List<Vector4D> particles;
  final double gravityX;
  final double gravityY;
  final bool isConnected;
  final bool isBusy;

  _RiemannianManifoldPainter({
    required this.progress,
    required this.particles,
    required this.gravityX,
    required this.gravityY,
    required this.isConnected,
    required this.isBusy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Vacuum Void Canvas
    final voidPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF020408),
          AppColors.background,
          Color(0xFF03060E),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), voidPaint);

    // 2. Gravitational Singularity Bloom
    _drawGravitationalLensing(canvas, size);

    // 3. Riemannian Curved Spacetime Coordinate Geodesics
    _drawRiemannianGeodesics(canvas, size);

    // 4. Clifford Strange Attractor Quantum Dust
    _drawAttractorFilaments(canvas, size);

    // 5. Optical Atmosphere Fade
    _drawAtmosphericVignette(canvas, size);
  }

  void _drawGravitationalLensing(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.28;

    final primaryColor = isConnected
        ? AppColors.neonEmerald
        : (isBusy ? AppColors.cyberCyan : AppColors.deepCyan);

    final pulse = sin(progress * MathConstants.tau) * 0.15 + 0.85;

    // Harmonic radial breathing field
    final bloomGradient = RadialGradient(
      center: Alignment.center,
      radius: 0.85,
      colors: [
        primaryColor.withOpacity((isConnected ? 0.22 : (isBusy ? 0.18 : 0.08)) * pulse),
        AppColors.neonViolet.withOpacity(0.05 * pulse),
        Colors.transparent,
      ],
      stops: const [0.0, 0.45, 1.0],
    );

    final bloomPaint = Paint()
      ..shader = bloomGradient.createShader(
        Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.75),
      );
    canvas.drawCircle(Offset(cx, cy), size.width * 0.75, bloomPaint);
  }

  void _drawRiemannianGeodesics(Canvas canvas, Size size) {
    final horizonY = size.height * 0.52;
    final bottomY = size.height;
    final gridHeight = bottomY - horizonY;
    if (gridHeight <= 0) return;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final waveSpeed = progress * MathConstants.tau * (isConnected ? 2.5 : 1.0);
    final primaryAccent = isConnected ? AppColors.neonEmerald : AppColors.cyberCyan;

    // Grid resolution
    const int uLines = 16; // Radial longitude geodesics
    const int vRungs = 11; // Latitudinal distance contours

    // Draw Longitude Geodesics bending around the gravitational center
    for (int i = 0; i <= uLines; i++) {
      final u = i / uLines;
      final path = Path();
      bool first = true;

      for (int step = 0; step <= 24; step++) {
        final t = step / 24.0;
        final depthCurve = pow(t, 2.2).toDouble();
        final currentY = horizonY + depthCurve * gridHeight;

        // Perspective fan-out
        final baseX = (u - 0.5) * (size.width * (1.2 + depthCurve * 1.8)) + (size.width * 0.5);

        // Curvature perturbation from interactive gravity well
        final dx = baseX - (gravityX * size.width);
        final dy = currentY - (gravityY * size.height);
        final distSq = (dx * dx + dy * dy) / (size.width * size.width);
        final wellPull = exp(-distSq * 9.0) * 18.0 * (1.0 - depthCurve * 0.4);

        // Harmonic wave oscillation along geodesic
        final waveZ = sin(depthCurve * 8.0 - waveSpeed + u * MathConstants.tau) * 3.5 * depthCurve;

        final px = baseX - (dx / (sqrt(distSq) + 0.1) * wellPull * 0.35);
        final py = currentY + waveZ + (wellPull * 0.6);

        if (first) {
          path.moveTo(px, py);
          first = false;
        } else {
          path.lineTo(px, py);
        }
      }

      final centerDist = (u - 0.5).abs();
      final alpha = (1.0 - centerDist * 1.6).clamp(0.04, 0.38);

      linePaint.color = primaryAccent.withOpacity(alpha * (isConnected ? 0.6 : 0.35));
      linePaint.strokeWidth = 0.9;
      canvas.drawPath(path, linePaint);
    }

    // Draw Latitudinal Distance Contours (Curved Horizon Rungs)
    final flowOffset = (progress * (isConnected ? 2.0 : 0.8)) % 1.0;

    for (int j = 0; j < vRungs; j++) {
      final rungT = ((j + flowOffset) / vRungs) % 1.0;
      final depthCurve = pow(rungT, 2.2).toDouble();
      final currentY = horizonY + depthCurve * gridHeight;

      final path = Path();
      bool first = true;

      const segments = 24;
      for (int s = 0; s <= segments; s++) {
        final st = s / segments;
        final baseX = st * size.width;

        final dx = baseX - (gravityX * size.width);
        final dy = currentY - (gravityY * size.height);
        final distSq = (dx * dx + dy * dy) / (size.width * size.width);
        final wellPull = exp(-distSq * 9.0) * 18.0;

        final waveZ = cos(st * MathConstants.tau * 2.0 - waveSpeed) * 3.0 * depthCurve;
        final py = currentY + waveZ + (wellPull * 0.6);

        if (first) {
          path.moveTo(baseX, py);
          first = false;
        } else {
          path.lineTo(baseX, py);
        }
      }

      final alpha = (depthCurve * (1.0 - depthCurve * 0.25)).clamp(0.0, 1.0);
      linePaint.color = primaryAccent.withOpacity(alpha * (isConnected ? 0.45 : 0.22));
      linePaint.strokeWidth = 0.8 + depthCurve * 1.2;
      canvas.drawPath(path, linePaint);
    }
  }

  void _drawAttractorFilaments(Canvas canvas, Size size) {
    final particlePaint = Paint()..style = PaintingStyle.fill;
    final primary = isConnected ? AppColors.neonEmerald : AppColors.cyberCyan;
    final speed = progress * MathConstants.tau * (isConnected ? 1.8 : 0.8);

    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];

      // Evolve phase angle along the attractor trajectory
      final orbitAngle = speed * (1.0 - p.z * 0.5) + p.w * MathConstants.tau;
      final orbitRadius = (0.2 + p.z * 0.35) * size.width;

      final cx = size.width * 0.5;
      final cy = size.height * 0.32;

      final px = cx + cos(orbitAngle) * orbitRadius * (0.8 + p.x * 0.4);
      final py = cy + sin(orbitAngle) * orbitRadius * (0.5 + p.y * 0.4);

      // Depth luminance
      final alpha = (sin(orbitAngle * 2.0) * 0.35 + 0.65) * p.z;
      particlePaint.color = (i % 2 == 0 ? primary : AppColors.neonViolet).withOpacity(alpha.clamp(0.1, 0.85));

      final radius = 1.0 + p.z * 1.8;
      canvas.drawCircle(Offset(px, py), radius, particlePaint);

      // Connective manifold filament lines between adjacent phase points
      if (i > 0 && i % 3 == 0) {
        final prev = particles[i - 1];
        final prevAngle = speed * (1.0 - prev.z * 0.5) + prev.w * MathConstants.tau;
        final prevR = (0.2 + prev.z * 0.35) * size.width;
        final ppx = cx + cos(prevAngle) * prevR * (0.8 + prev.x * 0.4);
        final ppy = cy + sin(prevAngle) * prevR * (0.5 + prev.y * 0.4);

        final dist = (px - ppx) * (px - ppx) + (py - ppy) * (py - ppy);
        if (dist < 4500) {
          final filamentPaint = Paint()
            ..color = primary.withOpacity((alpha * 0.25).clamp(0.02, 0.4))
            ..strokeWidth = 0.6;
          canvas.drawLine(Offset(px, py), Offset(ppx, ppy), filamentPaint);
        }
      }
    }
  }

  void _drawAtmosphericVignette(Canvas canvas, Size size) {
    final vignettePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.1, 0.86, 1.0],
        colors: [
          Color(0xF0020408),
          Colors.transparent,
          Colors.transparent,
          Color(0xF8020408),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);
  }

  @override
  bool shouldRepaint(covariant _RiemannianManifoldPainter oldDelegate) {
    return true;
  }
}
