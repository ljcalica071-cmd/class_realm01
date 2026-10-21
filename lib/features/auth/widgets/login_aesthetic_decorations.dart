import 'package:flutter/material.dart';

/// Botanical lush leaves painter framing the bottom corners.
class LushCornerLeavesPainter extends CustomPainter {
  final bool isDesktop;

  LushCornerLeavesPainter({this.isDesktop = true});

  @override
  void paint(Canvas canvas, Size size) {
    _paintLeftLeaves(canvas, size);
    _paintRightLeaves(canvas, size);
  }

  void _paintLeftLeaves(Canvas canvas, Size size) {
    final baseOrigin = Offset(-10, size.height + 10);
    final scale = isDesktop ? 1.0 : 0.75;

    final leafConfigs = [
      _Leaf(angle: -1.3, length: 140 * scale, width: 44 * scale, darkColor: const Color(0xFF1B4332), lightColor: const Color(0xFF40916C)),
      _Leaf(angle: -1.05, length: 180 * scale, width: 52 * scale, darkColor: const Color(0xFF2D6A4F), lightColor: const Color(0xFF52B788)),
      _Leaf(angle: -0.85, length: 160 * scale, width: 48 * scale, darkColor: const Color(0xFF1B4332), lightColor: const Color(0xFF74C69D)),
      _Leaf(angle: -0.6, length: 195 * scale, width: 56 * scale, darkColor: const Color(0xFF2D6A4F), lightColor: const Color(0xFF52B788)),
      _Leaf(angle: -0.38, length: 165 * scale, width: 50 * scale, darkColor: const Color(0xFF40916C), lightColor: const Color(0xFF95D5B2)),
      _Leaf(angle: -0.15, length: 130 * scale, width: 40 * scale, darkColor: const Color(0xFF1B4332), lightColor: const Color(0xFF52B788)),
      _Leaf(angle: -0.75, length: 110 * scale, width: 36 * scale, darkColor: const Color(0xFF2D6A4F), lightColor: const Color(0xFF74C69D)),
    ];

    for (final leaf in leafConfigs) {
      _drawBotanicalLeaf(canvas, baseOrigin, leaf);
    }
  }

  void _paintRightLeaves(Canvas canvas, Size size) {
    final baseOrigin = Offset(size.width + 10, size.height + 10);
    final scale = isDesktop ? 1.0 : 0.75;

    final leafConfigs = [
      _Leaf(angle: -1.8, length: 140 * scale, width: 44 * scale, darkColor: const Color(0xFF1B4332), lightColor: const Color(0xFF40916C)),
      _Leaf(angle: -2.1, length: 185 * scale, width: 54 * scale, darkColor: const Color(0xFF2D6A4F), lightColor: const Color(0xFF52B788)),
      _Leaf(angle: -2.35, length: 160 * scale, width: 48 * scale, darkColor: const Color(0xFF1B4332), lightColor: const Color(0xFF74C69D)),
      _Leaf(angle: -2.55, length: 195 * scale, width: 56 * scale, darkColor: const Color(0xFF2D6A4F), lightColor: const Color(0xFF52B788)),
      _Leaf(angle: -2.8, length: 165 * scale, width: 50 * scale, darkColor: const Color(0xFF40916C), lightColor: const Color(0xFF95D5B2)),
      _Leaf(angle: -3.0, length: 130 * scale, width: 40 * scale, darkColor: const Color(0xFF1B4332), lightColor: const Color(0xFF52B788)),
      _Leaf(angle: -2.4, length: 115 * scale, width: 38 * scale, darkColor: const Color(0xFF2D6A4F), lightColor: const Color(0xFF74C69D)),
    ];

    for (final leaf in leafConfigs) {
      _drawBotanicalLeaf(canvas, baseOrigin, leaf);
    }
  }

  void _drawBotanicalLeaf(Canvas canvas, Offset origin, _Leaf leaf) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(leaf.angle);

    final path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(leaf.width * 0.7, leaf.length * 0.45, 0, leaf.length);
    path.quadraticBezierTo(-leaf.width * 0.7, leaf.length * 0.45, 0, 0);
    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [leaf.darkColor, leaf.lightColor],
      ).createShader(Rect.fromLTWH(-leaf.width, 0, leaf.width * 2, leaf.length));

    // Soft drop shadow under each leaf
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.25), 4.0, false);
    canvas.drawPath(path, paint);

    // Central leaf vein
    final veinPaint = Paint()
      ..color = leaf.lightColor.withValues(alpha: 0.6)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final veinPath = Path();
    veinPath.moveTo(0, 4);
    veinPath.quadraticBezierTo(leaf.width * 0.05, leaf.length * 0.5, 0, leaf.length * 0.92);
    canvas.drawPath(veinPath, veinPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LushCornerLeavesPainter oldDelegate) =>
      oldDelegate.isDesktop != isDesktop;
}

class _Leaf {
  final double angle;
  final double length;
  final double width;
  final Color darkColor;
  final Color lightColor;

  _Leaf({
    required this.angle,
    required this.length,
    required this.width,
    required this.darkColor,
    required this.lightColor,
  });
}

/// 3D Graduation Mortarboard Cap with Golden Tassel and Cyan Glow Aura
class GraduationCapWidget extends StatelessWidget {
  final double size;

  const GraduationCapWidget({super.key, this.size = 110});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.3,
      height: size * 1.1,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Glowing cyan aura background
          Positioned(
            top: size * 0.1,
            right: size * 0.1,
            child: Container(
              width: size * 0.9,
              height: size * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D2FF).withValues(alpha: 0.75),
                    blurRadius: 40,
                    spreadRadius: 12,
                  ),
                ],
              ),
            ),
          ),
          CustomPaint(
            size: Size(size * 1.3, size * 1.1),
            painter: _GraduationCapPainter(),
          ),
        ],
      ),
    );
  }
}

class _GraduationCapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.48, size.height * 0.42);

    // 1. Skull cap (lower bowl of the hat)
    final skullPath = Path();
    skullPath.moveTo(center.dx - 32, center.dy + 8);
    skullPath.quadraticBezierTo(center.dx, center.dy + 38, center.dx + 34, center.dy + 12);
    skullPath.lineTo(center.dx + 28, center.dy + 4);
    skullPath.quadraticBezierTo(center.dx, center.dy + 26, center.dx - 26, center.dy + 2);
    skullPath.close();

    final skullPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
      ).createShader(Rect.fromLTWH(center.dx - 35, center.dy, 75, 45));

    canvas.drawShadow(skullPath, Colors.black45, 6, true);
    canvas.drawPath(skullPath, skullPaint);

    // 2. Diamond Mortarboard Top (Perspective tilted)
    final topPath = Path();
    topPath.moveTo(center.dx - 58, center.dy - 6);  // Left
    topPath.lineTo(center.dx + 6, center.dy - 32);  // Top
    topPath.lineTo(center.dx + 66, center.dy - 4);  // Right
    topPath.lineTo(center.dx + 2, center.dy + 22);  // Bottom
    topPath.close();

    final topPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF2563EB),
          Color(0xFF1E40AF),
          Color(0xFF1E3A8A),
        ],
      ).createShader(Rect.fromLTWH(center.dx - 60, center.dy - 35, 130, 60));

    canvas.drawShadow(topPath, Colors.black54, 8, true);
    canvas.drawPath(topPath, topPaint);

    // Bevel edge highlight on top surface
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(topPath, highlightPaint);

    // 3. Center golden button
    final buttonCenter = Offset(center.dx + 4, center.dy - 4);
    canvas.drawCircle(
      buttonCenter,
      4.5,
      Paint()..color = const Color(0xFFFBBF24),
    );

    // 4. Golden Tassel draping down to the right
    final tasselPath = Path();
    tasselPath.moveTo(buttonCenter.dx, buttonCenter.dy);
    tasselPath.quadraticBezierTo(center.dx + 35, center.dy - 2, center.dx + 48, center.dy + 16);
    tasselPath.quadraticBezierTo(center.dx + 52, center.dy + 32, center.dx + 50, center.dy + 48);

    final tasselLinePaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(tasselPath, tasselLinePaint);

    // Tassel fringe hanging at the bottom
    final fringeCenter = Offset(center.dx + 50, center.dy + 54);
    final fringePath = Path();
    fringePath.moveTo(fringeCenter.dx - 4, fringeCenter.dy - 6);
    fringePath.lineTo(fringeCenter.dx + 4, fringeCenter.dy - 6);
    fringePath.lineTo(fringeCenter.dx + 6, fringeCenter.dy + 12);
    fringePath.lineTo(fringeCenter.dx - 6, fringeCenter.dy + 12);
    fringePath.close();

    final fringePaint = Paint()..color = const Color(0xFFF59E0B);
    canvas.drawPath(fringePath, fringePaint);

    // Tassel band
    canvas.drawCircle(
      Offset(fringeCenter.dx, fringeCenter.dy - 5),
      3.5,
      Paint()..color = const Color(0xFFD97706),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 3D Closed Blue Hardcover Notebook with Bookmark
class ClosedBook3DWidget extends StatelessWidget {
  final double size;

  const ClosedBook3DWidget({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.15,
      child: Image.asset(
        'assets/images/auth/book.png',
        width: size * 1.5,
        height: size * 1.5,
        fit: BoxFit.contain,
      ),
    );
  }
}

