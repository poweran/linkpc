import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class TelemetryBar extends StatelessWidget {
  final int? pingMs;
  final String statusText;
  final VoidCallback? onRefreshPing;

  const TelemetryBar({
    super.key,
    this.pingMs,
    this.statusText = 'UPTIME: 99.98% // МОСКВА -> ЕРЕВАН // XHTTP',
    this.onRefreshPing,
  });

  @override
  Widget build(BuildContext context) {
    final hasPing = pingMs != null && pingMs! > 0;
    final pingColor = (pingMs != null && pingMs! > 0 && pingMs! < 80)
        ? AppColors.neonEmerald
        : (pingMs != null && pingMs! < 180 ? AppColors.cyberCyan : AppColors.warning);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.voidDark,
        border: Border.all(color: AppColors.cyberCyan.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  color: AppColors.neonEmerald,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.cyberCyan,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onRefreshPing,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '● ',
                  style: TextStyle(color: hasPing ? pingColor : AppColors.textMuted, fontSize: 10),
                ),
                Text(
                  hasPing ? '$pingMs ms' : '--- ms',
                  style: TextStyle(
                    color: hasPing ? pingColor : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.refresh,
                  size: 13,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
