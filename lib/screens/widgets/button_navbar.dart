
import 'package:flutter/material.dart';

class ButtonNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const ButtonNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      child: SizedBox(
        height: 100,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // NAVBAR SHAPE
            CustomPaint(
              size: const Size(double.infinity, 80),
              painter: BottomNavPainter(currentIndex),
              child: const SizedBox(
                height: 80,
                width: double.infinity,
              ),
            ),

            // ITEMS
            Row(
              children: List.generate(
                4,
                (index) => Expanded(
                  child: _NavItem(
                    index: index,
                    currentIndex: currentIndex,
                    onTap: onTap,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= ITEM =================
class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final Function(int) onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = index == currentIndex;

    final icons = [
      Icons.home_outlined,
      Icons.history,
      Icons.person_outline,
      Icons.settings_outlined,
    ];

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 100,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              top: isActive ? -2 : 38,
              child: Container(
                width: isActive ? 58 : 28,
                height: isActive ? 58 : 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? const Color(0xFF1E88FF)
                      : Colors.transparent,
                  border: isActive
                      ? Border.all(
                          color: const Color(0xFFE6F0FF),
                          width: 4,
                        )
                      : null,
                ),
                child: Icon(
                  icons[index],
                  color: Colors.white,
                  size: isActive ? 28 : 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= CUSTOM PAINTER =================
class BottomNavPainter extends CustomPainter {
  final int currentIndex;

  BottomNavPainter(this.currentIndex);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF0D47A1)
      ..style = PaintingStyle.fill;

    final Path path = Path();

    final double width = size.width;
    final double height = size.height;

    final double itemWidth = width / 4;
    final double center = (currentIndex * itemWidth) + (itemWidth / 2);

    // Radius cekungan
    const double notchRadius = 38;
    const double cornerRadius = 28;

    path.moveTo(0, cornerRadius);

    // kiri atas
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    // menuju cekungan
    path.lineTo(center - notchRadius - 18, 0);

    // curve turun kiri
    path.quadraticBezierTo(
      center - notchRadius,
      0,
      center - notchRadius + 8,
      14,
    );

    // cekungan setengah lingkaran
    path.arcToPoint(
      Offset(center + notchRadius - 8, 14),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );

    // naik kanan
    path.quadraticBezierTo(
      center + notchRadius,
      0,
      center + notchRadius + 18,
      0,
    );

    // kanan atas
    path.lineTo(width - cornerRadius, 0);
    path.quadraticBezierTo(width, 0, width, cornerRadius);

    // kanan bawah
    path.lineTo(width, height - cornerRadius);
    path.quadraticBezierTo(width, height, width - cornerRadius, height);

    // kiri bawah
    path.lineTo(cornerRadius, height);
    path.quadraticBezierTo(0, height, 0, height - cornerRadius);

    path.close();

    canvas.drawShadow(path, Colors.black26, 8, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BottomNavPainter oldDelegate) {
    return oldDelegate.currentIndex != currentIndex;
  }
}