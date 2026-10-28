import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// WIPAS mark: rounded square with a "W" stroke and a teal dot.
class WipasLogo extends StatelessWidget {
  const WipasLogo({super.key, this.size = 44, this.inverted = false});

  final double size;

  /// White tile with navy W (splash) instead of navy tile with white W.
  final bool inverted;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Logo WIPAS',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: inverted ? Colors.white : WipasColors.navy,
            borderRadius: BorderRadius.circular(size * 0.27),
          ),
          child: CustomPaint(painter: _WPainter(inverted ? WipasColors.navy : Colors.white)),
        ),
      );
}

class _WPainter extends CustomPainter {
  _WPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(s.width * 0.27, s.height * 0.35)
      ..lineTo(s.width * 0.38, s.height * 0.68)
      ..lineTo(s.width * 0.5, s.height * 0.42)
      ..lineTo(s.width * 0.62, s.height * 0.68)
      ..lineTo(s.width * 0.72, s.height * 0.38);
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width * 0.73, s.height * 0.3), s.width * 0.065, Paint()..color = WipasColors.teal);
  }

  @override
  bool shouldRepaint(covariant _WPainter old) => old.color != color;
}
