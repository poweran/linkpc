import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Holographic Quantum Status Badge with glowing LED beacon and
/// sci-fi corner brackets.
class StatusBadge extends StatefulWidget {
  final String label;
  final Color color;
  final bool showDot;

  const StatusBadge({
    super.key,
    required this.label,
    this.color = AppColors.cyberCyan,
    this.showDot = true,
  });

  @override
  State<StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<StatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beaconController;

  @override
  void initState() {
    super.initState();
    _beaconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _beaconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _beaconController,
      builder: (context, _) {
        final pulse = _beaconController.value;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.08),
            border: Border.all(
              color: widget.color.withOpacity(0.35 + pulse * 0.25),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.12 * pulse),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showDot) ...[
                // Pulsating Quantum LED Beacon
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.rectangle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withOpacity(0.7 + pulse * 0.3),
                        blurRadius: 6 + pulse * 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
