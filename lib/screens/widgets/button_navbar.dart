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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: SizedBox(
        height: 100, // lebih tinggi supaya ada ruang untuk icon aktif
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // NAVBAR SHAPE — mulai dari y=20 ke bawah
            Positioned(
              left: 0,
              right: 0,
              top: 20, // geser shape ke bawah, beri ruang icon aktif di atas
              bottom: 0,
              child: CustomPaint(
                painter: BottomNavPainter(currentIndex),
              ),
            ),

            // ITEMS
            SizedBox(
              height: 100,
              child: Row(
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
              top: isActive ? 0 : 42, // sesuaikan posisi dengan tinggi baru
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  width: isActive ? 58 : 28,
                  height: isActive ? 58 : 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        isActive ? const Color(0xFF1E88FF) : Colors.transparent,
                    border: isActive
                        ? Border.all(
                            color: const Color(0xFFE6F0FF),
                            width: 4,
                          )
                        : null,
                  ),
                  child: Icon(
                    icons[index],
                    color: isActive ? Colors.white : Colors.white70,
                    size: isActive ? 28 : 22,
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

// ================= CUSTOM PAINTER =================
class BottomNavPainter extends CustomPainter {
  final int currentIndex;

  BottomNavPainter(this.currentIndex);

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    const double notchRadius = 36.0;
    const double cornerRadius = 28.0;

    final double itemWidth = width / 4;
    final double center = ((currentIndex * itemWidth) + (itemWidth / 2))
        .clamp(notchRadius + 22, width - notchRadius - 22);

    // Clip canvas ke rounded rect supaya sudut tidak bocor keluar
    final RRect clipRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      const Radius.circular(cornerRadius),
    );
    canvas.clipRRect(clipRect);

    final Paint paint = Paint()
      ..color = const Color(0xFF0D47A1)
      ..style = PaintingStyle.fill;

    final Path path = Path();

    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    path.lineTo(center - notchRadius - 18, 0);
    path.quadraticBezierTo(
      center - notchRadius,
      0,
      center - notchRadius + 8,
      14,
    );

    path.arcToPoint(
      Offset(center + notchRadius - 8, 14),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );

    path.quadraticBezierTo(
      center + notchRadius,
      0,
      center + notchRadius + 18,
      0,
    );

    path.lineTo(width - cornerRadius, 0);
    path.quadraticBezierTo(width, 0, width, cornerRadius);

    path.lineTo(width, height);
    path.lineTo(0, height);

    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BottomNavPainter oldDelegate) {
    return oldDelegate.currentIndex != currentIndex;
  }
}
