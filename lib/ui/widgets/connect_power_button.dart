import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/vpn_state.dart';

class ConnectPowerButton extends StatefulWidget {
  final VpnStatus status;
  final VoidCallback onTap;
  final double size;

  const ConnectPowerButton({
    super.key,
    required this.status,
    required this.onTap,
    this.size = 190.0,
  });

  @override
  State<ConnectPowerButton> createState() => _ConnectPowerButtonState();
}

class _ConnectPowerButtonState extends State<ConnectPowerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.status.isConnected;
    final isConnecting = widget.status.isConnecting;
    final isBusy = widget.status.isBusy;

    final primaryGlowColor = isConnected
        ? AppColors.neonEmerald
        : (isConnecting ? AppColors.cyberCyan : AppColors.deepCyan);

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final pulse = isBusy ? (sin(_animController.value * 2 * pi) * 0.15 + 0.85) : 1.0;
        final glowRadius = isConnected ? 28.0 : (isBusy ? 34.0 * pulse : 12.0);

        return GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: widget.size + 40,
            height: widget.size + 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Pulse Ring (when connecting or connected)
                if (isBusy || isConnected)
                  Container(
                    width: widget.size + (isBusy ? 32 * _animController.value : 16),
                    height: widget.size + (isBusy ? 32 * _animController.value : 16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primaryGlowColor.withOpacity(
                          isBusy ? (1.0 - _animController.value) * 0.7 : 0.25,
                        ),
                        width: 1.5,
                      ),
                    ),
                  ),

                // Main Outer Circle with Shadow Glow
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.surfaceLight,
                        AppColors.voidBlack,
                      ],
                    ),
                    border: Border.all(
                      color: isConnected
                          ? AppColors.neonEmerald
                          : (isConnecting ? AppColors.cyberCyan : AppColors.borderSubtle),
                      width: isConnected ? 2.5 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryGlowColor.withOpacity(isConnected ? 0.35 : (isBusy ? 0.45 : 0.1)),
                        blurRadius: glowRadius,
                        spreadRadius: isConnected ? 4 : 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: widget.size - 28,
                      height: widget.size - 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.voidDark,
                        border: Border.all(
                          color: primaryGlowColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.power_settings_new_rounded,
                              size: 58,
                              color: isConnected
                                  ? AppColors.neonEmerald
                                  : (isBusy ? AppColors.cyberCyan : AppColors.textMuted),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isConnected ? 'ПОДКЛЮЧЕНО' : (isBusy ? 'СВЯЗЬ...' : 'НАЖМИТЕ'),
                              style: TextStyle(
                                color: isConnected
                                    ? AppColors.neonEmerald
                                    : (isBusy ? AppColors.cyberCyan : AppColors.textSecondary),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
