import 'package:flutter/material.dart';
import 'package:eventflow/core/theme/app_theme.dart';

/// TicketBadge represents a badge shaped like a ticket with side notches,
/// per Ticketto Brand Concept 1.0.
class TicketBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final Widget? icon;

  const TicketBadge({
    super.key,
    required this.label,
    this.backgroundColor = AppColors.lime,
    this.textColor = AppColors.ink,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const TicketClipper(cornerRadius: 4, notchRadius: 3),
      child: Container(
        color: backgroundColor,
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              icon!,
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// TicketClipper cuts inward semicircles on the left and right edges.
class TicketClipper extends CustomClipper<Path> {
  final double cornerRadius;
  final double notchRadius;

  const TicketClipper({this.cornerRadius = 4.0, this.notchRadius = 3.0});

  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final cr = cornerRadius;
    final nr = notchRadius;
    final midY = h / 2;

    path.moveTo(cr, 0);
    path.lineTo(w - cr, 0);
    path.arcToPoint(Offset(w, cr), radius: Radius.circular(cr));

    path.lineTo(w, midY - nr);
    path.arcToPoint(Offset(w, midY + nr), radius: Radius.circular(nr), clockwise: false);
    path.lineTo(w, h - cr);
    path.arcToPoint(Offset(w - cr, h), radius: Radius.circular(cr));

    path.lineTo(cr, h);
    path.arcToPoint(Offset(0, h - cr), radius: Radius.circular(cr));

    path.lineTo(0, midY + nr);
    path.arcToPoint(Offset(0, midY - nr), radius: Radius.circular(nr), clockwise: false);
    path.lineTo(0, cr);
    path.arcToPoint(Offset(cr, 0), radius: Radius.circular(cr));

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant TicketClipper oldClipper) =>
      oldClipper.cornerRadius != cornerRadius || oldClipper.notchRadius != notchRadius;
}
