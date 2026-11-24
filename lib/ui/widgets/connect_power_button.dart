import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/vpn_state.dart';

/// 3D Holographic Dimensional Gateway Power Core with counter-rotating
/// quantum rings, orbital energy nodes, volumetric spherical depth,
/// and responsive 3D perspective plunge on interaction.
class ConnectPowerButton extends StatefulWidget {
  final VpnStatus status;
  final VoidCallback onTap;
  final double size;

  const ConnectPowerButton({
    super.key,
    required this.status,
    required this.onTap,
    this.size = 200.0,
  });

  @override
  State<ConnectPowerButton> createState() => _ConnectPowerButtonState();
}

class _ConnectPowerButtonState extends State<ConnectPowerButton>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;
  late final AnimationController _pressController;

  double _hoverTiltX = 0.0;
  double _hoverTiltY = 0.0;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
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

  void _onPointerHover(PointerHoverEvent event, double buttonSize) {
    final normalizedX = (event.localPosition.dx / buttonSize - 0.5) * 2.0;
    final normalizedY = (event.localPosition.dy / buttonSize - 0.5) * 2.0;

    setState(() {
      _hoverTiltX = normalizedX.clamp(-1.0, 1.0);
      _hoverTiltY = normalizedY.clamp(-1.0, 1.0);
    });
  }

  void _onTapDown(TapDownDetails details) {
    _pressController.forward();
  }

  void _onTapUp(TapUpDetails details) {
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

    final glowColor = isConnected
        ? AppColors.neonEmerald
        : (isBusy ? AppColors.cyberCyan : AppColors.borderFocus);

    final totalSize = widget.size + 44.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _hoverTiltX = 0.0;
        _hoverTiltY = 0.0;
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
            final pressScale = 1.0 - (_pressController.value * 0.08);
            final pulseVal = _pulseController.value;
            final dynamicRot = _rotationController.value * 2 * pi;

            // 3D perspective tilt matrix
            final matrix = Matrix4.identity()
              ..setEntry(3, 2, 0.0018)
              ..rotateX(-_hoverTiltY * 0.18)
              ..rotateY(_hoverTiltX * 0.18)
              ..scale(pressScale);

            return Transform(
              alignment: Alignment.center,
              transform: matrix,
              child: SizedBox(
                width: totalSize,
                height: totalSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Layer 0: Volumetric Halo Shockwave Bloom
                    _buildVolumetricHalo(primaryColor, pulseVal, isConnected, isBusy),

                    // Layer 1: Outer & Counter Rotating Quantum Stargate Rings
                    CustomPaint(
                      size: Size(totalSize, totalSize),
                      painter: _QuantumPortalRingsPainter(
                        rotAngle: dynamicRot,
                        pulse: pulseVal,
                        isConnected: isConnected,
                        isBusy: isBusy,
                        primaryColor: primaryColor,
                        secondaryColor: isConnected ? AppColors.cyberCyan : AppColors.neonViolet,
                      ),
                    ),

                    // Layer 2: 3D Spherical Core Capsule
                    _buildSphericalCore(
                      widget.size,
                      primaryColor,
                      glowColor,
                      isConnected,
                      isBusy,
                      pulseVal,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVolumetricHalo(
    Color primaryColor,
    double pulseVal,
    bool isConnected,
    bool isBusy,
  ) {
    final haloSize = widget.size + (isBusy ? 42.0 * pulseVal : (isConnected ? 28.0 : 12.0));
    final haloAlpha = isConnected
        ? 0.35 + (pulseVal * 0.2)
        : (isBusy ? 0.45 + (pulseVal * 0.25) : (_isHovered ? 0.25 : 0.12));

    return Container(
      width: haloSize,
      height: haloSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(haloAlpha),
            blurRadius: isConnected ? 52.0 : (isBusy ? 64.0 : 28.0),
            spreadRadius: isConnected ? 8.0 : (isBusy ? 12.0 : 2.0),
          ),
          if (isConnected)
            BoxShadow(
              color: AppColors.cyberCyan.withOpacity(0.25),
              blurRadius: 36.0,
              spreadRadius: 4.0,
            ),
        ],
      ),
    );
  }

  Widget _buildSphericalCore(
    double baseSize,
    Color primaryColor,
    Color glowColor,
    bool isConnected,
    bool isBusy,
    double pulseVal,
  ) {
    return Container(
      width: baseSize,
      height: baseSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Multi-level 3D metallic and glass gradient
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 0.95,
          colors: [
            Color.lerp(
              AppColors.surfaceLight,
              primaryColor.withOpacity(0.35),
              isConnected ? 0.4 : (isBusy ? 0.3 : 0.05),
            )!,
            AppColors.surface,
            AppColors.voidDark,
            AppColors.voidBlack,
          ],
          stops: const [0.0, 0.45, 0.85, 1.0],
        ),
        border: Border.all(
          color: isConnected
              ? AppColors.neonEmerald
              : (isBusy
                  ? AppColors.cyberCyan
                  : (_isHovered ? AppColors.borderFocus : AppColors.borderSubtle)),
          width: isConnected ? 2.4 : 1.6,
        ),
        boxShadow: [
          // Inner rim shadow for genuine dimensional concavity
          BoxShadow(
            color: primaryColor.withOpacity(isConnected ? 0.5 : (isBusy ? 0.4 : 0.15)),
            blurRadius: 18.0,
            spreadRadius: isConnected ? 3.0 : 0.5,
          ),
          const BoxShadow(
            color: Color(0xCC000000),
            offset: Offset(0, 10),
            blurRadius: 24.0,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 3D Glass Specular Crescent (Top-Left Highlight)
          Positioned(
            top: baseSize * 0.09,
            left: baseSize * 0.16,
            child: Container(
              width: baseSize * 0.68,
              height: baseSize * 0.32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.elliptical(baseSize * 0.34, baseSize * 0.16)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(isConnected ? 0.28 : 0.14),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // Inner Concentric Energy Chamber
          Container(
            width: baseSize * 0.72,
            height: baseSize * 0.72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.voidBlack.withOpacity(0.92),
              border: Border.all(
                color: primaryColor.withOpacity(isConnected ? 0.45 : 0.2),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(isConnected ? 0.25 : 0.1),
                  blurRadius: 12.0,
                  spreadRadius: 1.0,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Power Glyph with Chromatic Bloom
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isConnected || isBusy)
                      Icon(
                        Icons.power_settings_new_rounded,
                        size: 54,
                        color: primaryColor.withOpacity(0.4),
                      ),
                    Icon(
                      Icons.power_settings_new_rounded,
                      size: 52,
                      color: isConnected
                          ? AppColors.neonEmerald
                          : (isBusy ? AppColors.cyberCyan : AppColors.textMuted),
                      shadows: [
                        Shadow(
                          color: primaryColor.withOpacity(isConnected ? 0.9 : 0.4),
                          blurRadius: isConnected ? 18.0 : 8.0,
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Cyber Status HUD Ticker
                Text(
                  isConnected
                      ? 'АКТИВИРОВАН'
                      : (isBusy ? 'СИНХРОНИЗАЦИЯ...' : 'ВКЛЮЧИТЬ'),
                  style: TextStyle(
                    color: isConnected
                        ? AppColors.neonEmerald
                        : (isBusy ? AppColors.cyberCyan : AppColors.textSecondary),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 3),

                // Micro Dimensional Coordinate Label
                Text(
                  isConnected
                      ? 'DIM: SECURE // 0x7F'
                      : (isBusy ? 'CONNECTING...' : 'GATEWAY: READY'),
                  style: TextStyle(
                    color: isConnected
                        ? AppColors.skyBlue.withOpacity(0.85)
                        : AppColors.textMuted,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    letterSpacing: 0.8,
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

/// Custom painter for multidimensional orbital rings, quantum nodes,
/// radial technical telemetry ticks, and counter-rotating energy segments.
class _QuantumPortalRingsPainter extends CustomPainter {
  final double rotAngle;
  final double pulse;
  final bool isConnected;
  final bool isBusy;
  final Color primaryColor;
  final Color secondaryColor;

  _QuantumPortalRingsPainter({
    required this.rotAngle,
    required this.pulse,
    required this.isConnected,
    required this.isBusy,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final maxRadius = size.width * 0.5 - 2;

    // Outer Ring: Rotating Clockwise with Sci-Fi Segment Arcs
    final outerRadius = maxRadius;
    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = primaryColor.withOpacity(isConnected ? 0.55 : (isBusy ? 0.45 : 0.2));

    // Outer Tech Arcs (3 segments)
    const segments = 3;
    const arcLength = (2 * pi / segments) * 0.65;
    for (int i = 0; i < segments; i++) {
      final startAngle = rotAngle + (i * 2 * pi / segments);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        startAngle,
        arcLength,
        false,
        outerPaint,
      );
    }

    // Outer Quantum Orbital Nodes
    final nodePaint = Paint()..style = PaintingStyle.fill;
    const nodeCount = 3;
    for (int i = 0; i < nodeCount; i++) {
      final nodeAngle = rotAngle + (i * 2 * pi / nodeCount) + (arcLength * 0.5);
      final nx = center.dx + cos(nodeAngle) * outerRadius;
      final ny = center.dy + sin(nodeAngle) * outerRadius;

      nodePaint.color = isConnected ? AppColors.neonEmerald : AppColors.cyberCyan;
      canvas.drawCircle(Offset(nx, ny), isConnected ? 3.0 : 2.2, nodePaint);

      // Node aura glow
      nodePaint.color = (isConnected ? AppColors.neonEmerald : AppColors.cyberCyan).withOpacity(0.35);
      canvas.drawCircle(Offset(nx, ny), isConnected ? 6.0 : 4.5, nodePaint);
    }

    // Middle Ring: Counter-Rotating with Technical Hash Ticks
    final midRadius = outerRadius - 9.0;
    final tickSpeed = isBusy ? -rotAngle * 2.5 : -rotAngle * 0.7;
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const numTicks = 36;
    for (int i = 0; i < numTicks; i++) {
      final angle = tickSpeed + (i * 2 * pi / numTicks);
      final isMajor = i % 6 == 0;
      final tickLength = isMajor ? 5.0 : 2.5;

      final r1 = midRadius;
      final r2 = midRadius - tickLength;

      tickPaint.color = (isMajor ? secondaryColor : primaryColor).withOpacity(
        isMajor
            ? (isConnected ? 0.7 : 0.4)
            : (isConnected ? 0.35 : 0.18),
      );

      final p1 = Offset(center.dx + cos(angle) * r1, center.dy + sin(angle) * r1);
      final p2 = Offset(center.dx + cos(angle) * r2, center.dy + sin(angle) * r2);
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Dynamic Energy Pulse Wave Ring (when connected or busy)
    if (isConnected || isBusy) {
      final waveRadius = midRadius - 8.0 + (pulse * 6.0);
      final wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = primaryColor.withOpacity((1.0 - pulse) * (isConnected ? 0.55 : 0.7));

      canvas.drawCircle(center, waveRadius, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _QuantumPortalRingsPainter oldDelegate) {
    return true;
  }
}
