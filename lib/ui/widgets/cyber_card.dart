import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class CyberCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final VoidCallback? onTap;

  const CyberCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = Border.all(
      color: borderColor ?? AppColors.border,
      width: 1.0,
    );

    Widget content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppColors.cyberCardGradient,
        border: border,
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            offset: Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        splashColor: AppColors.cyberCyan.withOpacity(0.1),
        highlightColor: AppColors.cyberCyan.withOpacity(0.05),
        child: content,
      );
    }

    return content;
  }
}
