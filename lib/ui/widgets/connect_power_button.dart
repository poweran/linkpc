import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/math/hyper_geometry.dart';
import '../../core/models/vpn_state.dart';

/// Genuine 4D Clifford Torus & Hopf Fibration Gateway Core.
/// Projects higher-dimensional Riemannian manifolds from ℝ⁴ into 2D screen space
/// via continuous SO(4) double rotations, stereographic mapping, and geodesic energy flows.
class ConnectPowerButton extends StatefulWidget {
  final VpnStatus status;
  final VoidCallback onTap;
  final double size;

  const ConnectPowerButton({
    super.key,
    required this.status,
    required this.onTap,
    this.size = 220.0,
  });

  @override
  State<ConnectPowerButton> createState() => _ConnectPowerButtonState();
}

class _ConnectPowerButtonState extends State<ConnectPowerButton>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;
  late final AnimationController _pressController;

  double _mouse4DX = 0.0;
  double _mouse4DY = 0.0;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();

    // Harmonic rotation cycle along the Golden Ratio
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 14000),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _onPointerHover(PointerHoverEvent event, double totalSize) {
    final nx = (event.localPosition.dx / totalSize - 0.5) * 2.0;
    final ny = (event.localPosition.dy / totalSize - 0.5) * 2.0;
    setState(() {
      _mouse4DX = nx.clamp(-1.0, 1.0);
      _mouse4DY = ny.clamp(-1.0, 1.0);
    });
  }

  void _onTapDown(TapDownDetails _) {
    _pressController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _pressController.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.status.isConnected;
    final isBusy = widget.status.isBusy;

    final primaryColor = isConnected
        ? AppColors.neonEmerald
        : (isBusy ? AppColors.cyberCyan : AppColors.deepCyan);

    final totalSize = widget.size + 40.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _mouse4DX = 0.0;
        _mouse4DY = 0.0;
      }),
      onHover: (e) => _onPointerHover(e, totalSize),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _rotationController,
            _pulseController,
            _pressController,
          ]),
          builder: (context, _) {
            final t = _rotationController.value;
            final press = _pressController.value;
            final pulse = _pulseController.value;

            // Angular velocities in SO(4) 4D rotation planes
            final speedMul = isConnected ? 2.2 : (isBusy ? 3.8 : 1.0);
            final thetaXW = t * MathConstants.tau * speedMul;
            final phiYZ = t * MathConstants.tau * speedMul * MathConstants.invPhi;
            final psiZW = t * MathConstants.tau * 0.5;

            // Interactive perturbation from pointer
            final rotXW = Matrix4D.rotationXW(thetaXW + _mouse4DX * 0.6);
            final rotYZ = Matrix4D.rotationYZ(phiYZ + _mouse4DY * 0.6);
            final rotZW = Matrix4D.rotationZW(psiZW);
            final rotYW = Matrix4D.rotationYW(_mouse4DY * 0.4);

            final full4DMatrix = rotYW * rotZW * rotYZ * rotXW;

            // Stereographic pole distance plunges on touch
            final stereoDist = 1.65 - (press * 0.35);

            return SizedBox(
              width: totalSize,
              height: totalSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Layer 0: Volumetric Cosmic Glow Aura
                  _buildHarmonicAura(primaryColor, pulse, isConnected, isBusy),

                  // Layer 1: Living 4D Clifford Torus & Hopf Fibration Canvas
                  CustomPaint(
                    size: Size(totalSize, totalSize),
                    painter: _HopfFibrationPainter(
                      matrix4D: full4DMatrix,
                      stereoDistance: stereoDist,
                      primaryColor: primaryColor,
                      secondaryColor: isConnected ? AppColors.cyberCyan : AppColors.hologramPurple,
                      isConnected: isConnected,
                      isBusy: isBusy,
                      pulse: pulse,
                      time: t * MathConstants.tau,
                    ),
                  ),

                  // Layer 2: Central Gravitational Focal Core
                  _buildGravitationalCore(
                    widget.size * 0.52,
                    primaryColor,
                    isConnected,
                    isBusy,
                    press,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHarmonicAura(Color color, double pulse, bool isConnected, bool isBusy) {
    final auraRadius = widget.size * (isConnected ? 0.95 : (isBusy ? 1.05 : 0.75));
    final opacity = isConnected
        ? 0.28 + pulse * 0.15
        : (isBusy ? 0.35 + pulse * 0.2 : (_isHovered ? 0.18 : 0.08));

    return Container(
      width: auraRadius,
      height: auraRadius,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(opacity),
            blurRadius: isConnected ? 64.0 : 42.0,
            spreadRadius: isConnected ? 8.0 : 2.0,
          ),
          if (isConnected)
            BoxShadow(
              color: AppColors.cyberCyan.withOpacity(0.2),
              blurRadius: 40.0,
              spreadRadius: 4.0,
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
    double press,
  ) {
    final scale = 1.0 - (press * 0.09);

    return Transform.scale(
      scale: scale,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Deep Obsidian Glass with Fresnel rim reflection
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

            // Inner Core Glyph and Topological Status
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

/// Custom painter that executes true 4D stereographic projection
/// of the Clifford Torus Villarceau geodesics and Hopf fibers onto the 2D canvas.
class _HopfFibrationPainter extends CustomPainter {
  final Matrix4D matrix4D;
  final double stereoDistance;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isConnected;
  final bool isBusy;
  final double pulse;
  final double time;

  _HopfFibrationPainter({
    required this.matrix4D,
    required this.stereoDistance,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isConnected,
    required this.isBusy,
    required this.pulse,
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

    // 1. Draw Stereographic Clifford Torus Rings
    for (int i = 0; i < rings.length; i++) {
      final ring = rings[i];
      final path = Path();
      bool first = true;
      double avgW = 0.0;

      for (int j = 0; j < ring.length; j++) {
        final v4 = ring[j];
        // 4D Transformation
        final rotated = matrix4D.transform(v4);
        avgW += rotated.w;

        // Stereographic Projection ℝ⁴ -> ℝ³ -> Screen
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
      // 4th dimension depth modulation
      final depthAlpha = ((avgW + 1.0) * 0.5).clamp(0.08, 0.95);
      final strokeW = ((avgW + 1.0) * 0.75 + 0.4).clamp(0.5, 1.8);

      final ringColor = Color.lerp(secondaryColor, primaryColor, (i % 2 == 0) ? 0.7 : 0.3)!;
      fiberPaint.color = ringColor.withOpacity(depthAlpha * (isConnected ? 0.65 : 0.35));
      fiberPaint.strokeWidth = strokeW;

      canvas.drawPath(path, fiberPaint);
    }

    // 2. Draw Villarceau Hopf Geodesics (Flowing spiral fibers)
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

      fiberPaint.color = primaryColor.withOpacity(depthAlpha * (isConnected ? 0.75 : 0.4));
      fiberPaint.strokeWidth = isConnected ? 1.2 : 0.8;
      canvas.drawPath(path, fiberPaint);

      // Quantum nodes traveling along Villarceau geodesics
      if (isConnected || isBusy) {
        final nodeT = ((time * (isConnected ? 0.4 : 0.7)) + (k / hopfFibers.length)) % 1.0;
        final nodeIndex = (nodeT * (fiber.length - 1)).toInt();
        final nodeV4 = matrix4D.transform(fiber[nodeIndex]);
        final nodeP3 = nodeV4.projectStereographic(distance: stereoDistance);
        final nx = cx + nodeP3.x * fovScale;
        final ny = cy + nodeP3.y * fovScale;

        final nodePaint = Paint()
          ..style = PaintingStyle.fill
          ..color = (isConnected ? AppColors.neonEmerald : AppColors.cyberCyan)
              .withOpacity(((nodeV4.w + 1.0) * 0.5).clamp(0.3, 1.0));

        canvas.drawCircle(Offset(nx, ny), isConnected ? 2.8 : 2.0, nodePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HopfFibrationPainter oldDelegate) {
    return true;
  }
}
