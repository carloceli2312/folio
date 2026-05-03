import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Logo animato di Folio: squircle con lettera "F" serif e cursore lampeggiante.
///
/// Si adatta automaticamente al tema corrente (light/dark).
class AnimatedFolioLogo extends StatefulWidget {
  final double size;

  const AnimatedFolioLogo({super.key, this.size = 120});

  @override
  State<AnimatedFolioLogo> createState() => _AnimatedFolioLogoState();
}

class _AnimatedFolioLogoState extends State<AnimatedFolioLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F0E8);
    final fgColor = isDark ? const Color(0xFFF5F0E8) : const Color(0xFF2C2C2C);
    final cursorColor =
        isDark ? const Color(0xFF8C8278) : const Color(0xFFC4B8A6);
    final borderColor =
        isDark ? const Color(0xFFF5F0E8) : const Color(0xFF2C2C2C);
    final scale = widget.size / 120;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _LogoPainter(
              animation: _controller,
              bgColor: bgColor,
              cursorColor: cursorColor,
              borderColor: borderColor,
              scale: scale,
            ),
          ),
          // "F" in Lora serif — resa come Text widget per garantire il font
          // anche prima che il CustomPainter abbia caricato il typeface.
          Transform.translate(
            offset: Offset(-5 * scale, -4 * scale),
            child: Text(
              'F',
              style: GoogleFonts.lora(
                fontSize: 52 * scale,
                fontWeight: FontWeight.bold,
                color: fgColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Animation<double> animation;
  final Color bgColor;
  final Color cursorColor;
  final Color borderColor;
  final double scale;

  _LogoPainter({
    required this.animation,
    required this.bgColor,
    required this.cursorColor,
    required this.borderColor,
    required this.scale,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final s = scale;

    // Bordo esterno (squircle)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(14 * s, 8 * s, 92 * s, 92 * s),
        Radius.circular(22 * s),
      ),
      Paint()..color = borderColor,
    );

    // Sfondo interno
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(17 * s, 11 * s, 86 * s, 86 * s),
        Radius.circular(19 * s),
      ),
      Paint()..color = bgColor,
    );

    // Cursore: fade-in rapido (15% ciclo) → on → fade-out rapido (15%) → off
    final cursorOpacity = _softBlink(animation.value);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(76 * s, 38 * s, 2.5 * s, 28 * s),
        Radius.circular(1.25 * s),
      ),
      Paint()..color = cursorColor.withValues(alpha: cursorOpacity),
    );
  }

  static double _softBlink(double t) {
    const fadeIn = 0.15;
    const fadeOut = 0.15;
    const onEnd = 0.50;
    if (t < fadeIn) return t / fadeIn;
    if (t < onEnd) return 1.0;
    if (t < onEnd + fadeOut) return (onEnd + fadeOut - t) / fadeOut;
    return 0.0;
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) =>
      bgColor != old.bgColor ||
      cursorColor != old.cursorColor ||
      borderColor != old.borderColor;
}
