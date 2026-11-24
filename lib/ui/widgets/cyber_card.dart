import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

/// Multidimensional CyberCard with interactive 3D perspective tilt,
/// sci-fi corner reticle brackets, specular glassmorphic sheen,
/// and layered volumetric depth.
class CyberCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool enableTilt;
  final bool showCornerReticles;

  const CyberCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.borderColor,
    this.onTap,
    this.enableTilt = true,
    this.showCornerReticles = true,
  });

  @override
  State<CyberCard> createState() => _CyberCardState();
}

class _CyberCardState extends State<CyberCard>
    with SingleTickerProviderStateMixin {
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  bool _isHovered = false;

  void _onPointerHover(PointerHoverEvent event, Size size) {
    if (!widget.enableTilt || size.width == 0 || size.height == 0) return;
    final normalizedX = (event.localPosition.dx / size.width - 0.5) * 2.0;
    final normalizedY = (event.localPosition.dy / size.height - 0.5) * 2.0;

    setState(() {
      _tiltX = normalizedX.clamp(-1.0, 1.0);
      _tiltY = normalizedY.clamp(-1.0, 1.0);
    });
  }

  void _onPointerExit() {
    setState(() {
      _isHovered = false;
      _tiltX = 0.0;
      _tiltY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeBorderColor = widget.borderColor ?? AppColors.border;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardSize = Size(constraints.maxWidth, 200);

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => _onPointerExit(),
          onHover: (e) => _onPointerHover(e, cardSize),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: _tiltX),
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            builder: (context, smoothTiltX, child) {
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: _tiltY),
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                builder: (context, smoothTiltY, _) {
                  // 3D Perspective Matrix Tilt
                  final matrix = Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateX(-smoothTiltY * 0.065)
                    ..rotateY(smoothTiltX * 0.065);

                  return Transform(
                    alignment: Alignment.center,
                    transform: matrix,
                    child: Container(
                      margin: widget.margin,
                      decoration: BoxDecoration(
                        // Deep Volumetric Frosted Glass
                        gradient: LinearGradient(
                          begin: Alignment(-0.8 - smoothTiltX * 0.3, -1.0 - smoothTiltY * 0.3),
                          end: const Alignment(0.8, 1.0),
                          colors: [
                            Color.lerp(
                              const Color(0xF210192A),
                              AppColors.cyberCyan.withOpacity(0.08),
                              _isHovered ? 0.4 : 0.0,
                            )!,
                            const Color(0xF7080D17),
                            const Color(0xFA05070E),
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                        // Border with Specular Dynamic Glow
                        border: Border.all(
                          color: _isHovered
                              ? Color.lerp(activeBorderColor, AppColors.cyberCyan, 0.5)!
                              : activeBorderColor,
                          width: _isHovered ? 1.2 : 1.0,
                        ),
                        boxShadow: [
                          // Base ambient shadow
                          const BoxShadow(
                            color: Color(0x88000000),
                            offset: Offset(0, 10),
                            blurRadius: 28,
                            spreadRadius: -2,
                          ),
                          // Subtle neon aura on hover or active
                          if (_isHovered)
                            BoxShadow(
                              color: AppColors.cyberCyan.withOpacity(0.12),
                              offset: Offset(smoothTiltX * 6, smoothTiltY * 6),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Custom Painter for Sci-Fi Corner Reticles & Laser Brackets
                          if (widget.showCornerReticles)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _CyberCardReticlesPainter(
                                  reticleColor: _isHovered
                                      ? AppColors.cyberCyan
                                      : activeBorderColor.withOpacity(0.8),
                                ),
                              ),
                            ),

                          // Top Specular Light Bleed
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 1.5,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    AppColors.cyberCyan.withOpacity(_isHovered ? 0.8 : 0.45),
                                    AppColors.neonViolet.withOpacity(_isHovered ? 0.6 : 0.25),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.25, 0.75, 1.0],
                                ),
                              ),
                            ),
                          ),

                          // Interactive InkWell & Main Content
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.onTap,
                              splashColor: AppColors.cyberCyan.withOpacity(0.08),
                              highlightColor: AppColors.cyberCyan.withOpacity(0.04),
                              child: Padding(
                                padding: widget.padding,
                                child: widget.child,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// Sci-Fi corner reticles painter for high-tech holographic HUD framing.
class _CyberCardReticlesPainter extends CustomPainter {
  final Color reticleColor;

  _CyberCardReticlesPainter({required this.reticleColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = reticleColor
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    const cornerLength = 8.0;

    // Top-Left Reticle
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // Top-Right Reticle
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Bottom-Left Reticle
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLength), paint);

    // Bottom-Right Reticle
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant _CyberCardReticlesPainter oldDelegate) {
    return oldDelegate.reticleColor != reticleColor;
  }
}
