import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/math/hyper_geometry.dart';
import '../../core/models/vpn_state.dart';

/// True Multidimensional Space Background:
/// 1. Continuous Riemannian curved spacetime manifold with potential well geodesics.
/// 2. Phase-space Clifford Strange Attractor quantum dust field.
/// 3. Interactive pointer gravitational perturbation.
/// 4. 100% continuous phase integration (zero jumps, zero leaps) correlated with
///    real-time network throughput and latency.
class MultidimensionalSpace extends StatefulWidget {
  final Widget child;
  final VpnStatus status;
  final bool enableParallax;
  final int trafficBytesPerSec;
  final int? pingMs;

  const MultidimensionalSpace({
    super.key,
    required this.child,
    required this.status,
    this.enableParallax = true,
    this.trafficBytesPerSec = 0,
    this.pingMs,
  });

  @override
  State<MultidimensionalSpace> createState() => _MultidimensionalSpaceState();
}

class _MultidimensionalSpaceState extends State<MultidimensionalSpace>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  final List<Vector4D> _attractorParticles = [];

  // Continuous C¹ Phase Integrators (zero phase jumps)
  final PhaseIntegrator _wavePhase = PhaseIntegrator();
  final PhaseIntegrator _flowPhase = PhaseIntegrator();
  final PhaseIntegrator _particlePhase = PhaseIntegrator();
  final PhaseIntegrator _pulsePhase = PhaseIntegrator();

  // Critically Damped Smoothers for smooth C² state and interaction flows
  final SmoothDamp _gravityXDamp = SmoothDamp(current: 0.5);
  final SmoothDamp _gravityYDamp = SmoothDamp(current: 0.5);
  final SmoothDamp _statusBlendDamp = SmoothDamp(current: 0.0);
  final SmoothDamp _trafficSpeedDamp = SmoothDamp(current: 0.0);

  double _targetGravityX = 0.5;
  double _targetGravityY = 0.5;

  @override
  void initState() {
    super.initState();
    _initCliffordAttractor();
    _ticker = createTicker(_onTick)..start();
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

    // Settle onto the attractor manifold
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

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final dt = _lastElapsed == Duration.zero
        ? 0.016
        : (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    final clampedDt = dt.clamp(0.001, 0.05);

    final isConnected = widget.status.isConnected;
    final isBusy = widget.status.isBusy;

    // Smooth status factor: 0.0 = disconnected, 0.45 = busy, 1.0 = connected
    final double targetStatus = isConnected ? 1.0 : (isBusy ? 0.45 : 0.0);
    _statusBlendDamp.update(targetStatus, 0.28, clampedDt);

    // Smooth real-time network throughput normalization
    final double trafficNorm = widget.trafficBytesPerSec > 0
        ? (log(widget.trafficBytesPerSec + 10) / log(100000000)).clamp(0.0, 1.0)
        : 0.0;
    _trafficSpeedDamp.update(trafficNorm, 0.22, clampedDt);

    final smoothStatus = _statusBlendDamp.current;
    final smoothTraffic = _trafficSpeedDamp.current;

    // 1. Geodesic wave propagation speed
    final double targetWaveSpeed = 0.75 + (isBusy ? 2.5 : 0.0) + smoothStatus * (0.5 + smoothTraffic * 3.2);
    _wavePhase.update(targetWaveSpeed, clampedDt, responsiveness: 3.5);

    // 2. Latitudinal contour depth flow speed
    final double targetFlowSpeed = 0.12 + (isBusy ? 0.45 : 0.0) + smoothStatus * (0.1 + smoothTraffic * 0.7);
    _flowPhase.update(targetFlowSpeed, clampedDt, responsiveness: 3.5);

    // 3. Clifford strange attractor particle speed
    final double targetParticleSpeed = 0.35 + (isBusy ? 1.6 : 0.0) + smoothStatus * (0.3 + smoothTraffic * 1.8);
    _particlePhase.update(targetParticleSpeed, clampedDt, responsiveness: 2.5);

    // 4. Singularity pulse frequency correlated with network ping
    double pulseFreq = 1.6;
    if (widget.pingMs != null && widget.pingMs! > 0) {
      pulseFreq = (1000.0 / (widget.pingMs!.clamp(15, 600) + 240.0)).clamp(1.0, 3.8);
    } else if (isBusy) {
      pulseFreq = 3.6;
    }
    _pulsePhase.update(pulseFreq, clampedDt, responsiveness: 2.0);

    // 5. Critically damped pointer gravity well
    _gravityXDamp.update(_targetGravityX, 0.16, clampedDt);
    _gravityYDamp.update(_targetGravityY, 0.16, clampedDt);

    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onPointerHover(PointerHoverEvent event, Size size) {
    if (!widget.enableParallax || size.width == 0 || size.height == 0) return;
    _targetGravityX = (event.localPosition.dx / size.width).clamp(0.05, 0.95);
    _targetGravityY = (event.localPosition.dy / size.height).clamp(0.05, 0.95);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return MouseRegion(
          onHover: (e) => _onPointerHover(e, size),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                size: size,
                painter: _RiemannianManifoldPainter(
                  wavePhase: _wavePhase.phase,
                  flowPhase: _flowPhase.phase,
                  particlePhase: _particlePhase.phase,
                  pulsePhase: _pulsePhase.phase,
                  statusFactor: _statusBlendDamp.current,
                  trafficFactor: _trafficSpeedDamp.current,
                  particles: _attractorParticles,
                  gravityX: _gravityXDamp.current,
                  gravityY: _gravityYDamp.current,
                ),
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
  final double wavePhase;
  final double flowPhase;
  final double particlePhase;
  final double pulsePhase;
  final double statusFactor;
  final double trafficFactor;
  final List<Vector4D> particles;
  final double gravityX;
  final double gravityY;

  _RiemannianManifoldPainter({
    required this.wavePhase,
    required this.flowPhase,
    required this.particlePhase,
    required this.pulsePhase,
    required this.statusFactor,
    required this.trafficFactor,
    required this.particles,
    required this.gravityX,
    required this.gravityY,
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

    // Compute smooth color interpolation across status transitions
    final primaryColor = statusFactor <= 0.45
        ? Color.lerp(AppColors.deepCyan, AppColors.cyberCyan, (statusFactor / 0.45).clamp(0.0, 1.0))!
        : Color.lerp(AppColors.cyberCyan, AppColors.neonEmerald, ((statusFactor - 0.45) / 0.55).clamp(0.0, 1.0))!;

    // 2. Gravitational Singularity Bloom
    _drawGravitationalLensing(canvas, size, primaryColor);

    // 3. Riemannian Curved Spacetime Coordinate Geodesics
    _drawRiemannianGeodesics(canvas, size, primaryColor);

    // 4. Clifford Strange Attractor Quantum Dust
    _drawAttractorFilaments(canvas, size, primaryColor);

    // 5. Optical Atmosphere Fade
    _drawAtmosphericVignette(canvas, size);
  }

  void _drawGravitationalLensing(Canvas canvas, Size size, Color primaryColor) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.28;

    final pulse = sin(pulsePhase) * 0.15 + 0.85;
    final bloomAlpha = (0.07 + statusFactor * 0.15 + trafficFactor * 0.05) * pulse;

    // Harmonic radial breathing field
    final bloomGradient = RadialGradient(
      center: Alignment.center,
      radius: 0.85,
      colors: [
        primaryColor.withOpacity(bloomAlpha.clamp(0.05, 0.45)),
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

  void _drawRiemannianGeodesics(Canvas canvas, Size size, Color primaryColor) {
    final horizonY = size.height * 0.52;
    final bottomY = size.height;
    final gridHeight = bottomY - horizonY;
    if (gridHeight <= 0) return;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

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

        // Harmonic wave oscillation along geodesic (monotonically continuous, zero jumps)
        final waveZ = sin(depthCurve * 8.0 - wavePhase + u * MathConstants.tau) * (2.8 + statusFactor * 1.5 + trafficFactor * 2.0) * depthCurve;

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

      linePaint.color = primaryColor.withOpacity(alpha * (0.32 + statusFactor * 0.28));
      linePaint.strokeWidth = 0.9;
      canvas.drawPath(path, linePaint);
    }

    // Draw Latitudinal Distance Contours (Curved Horizon Rungs)
    final rungOffset = flowPhase % 1.0;

    for (int j = 0; j < vRungs; j++) {
      final rungT = ((j + rungOffset) / vRungs) % 1.0;
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

        final waveZ = cos(st * MathConstants.tau * 2.0 - wavePhase) * (2.4 + statusFactor * 1.6) * depthCurve;
        final py = currentY + waveZ + (wellPull * 0.6);

        if (first) {
          path.moveTo(baseX, py);
          first = false;
        } else {
          path.lineTo(baseX, py);
        }
      }

      final alpha = (depthCurve * (1.0 - depthCurve * 0.25)).clamp(0.0, 1.0);
      linePaint.color = primaryColor.withOpacity(alpha * (0.20 + statusFactor * 0.25));
      linePaint.strokeWidth = 0.8 + depthCurve * 1.2;
      canvas.drawPath(path, linePaint);
    }
  }

  void _drawAttractorFilaments(Canvas canvas, Size size, Color primaryColor) {
    final particlePaint = Paint()..style = PaintingStyle.fill;
    final speed = particlePhase;

    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];

      // Evolve phase angle along the attractor trajectory monotonically
      final orbitAngle = speed * (1.0 - p.z * 0.5) + p.w * MathConstants.tau;
      final orbitRadius = (0.2 + p.z * 0.35) * size.width;

      final cx = size.width * 0.5;
      final cy = size.height * 0.32;

      final px = cx + cos(orbitAngle) * orbitRadius * (0.8 + p.x * 0.4);
      final py = cy + sin(orbitAngle) * orbitRadius * (0.5 + p.y * 0.4);

      // Depth luminance
      final alpha = (sin(orbitAngle * 2.0) * 0.35 + 0.65) * p.z;
      particlePaint.color = (i % 2 == 0 ? primaryColor : AppColors.neonViolet).withOpacity(alpha.clamp(0.1, 0.85));

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
            ..color = primaryColor.withOpacity((alpha * 0.25).clamp(0.02, 0.4))
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
