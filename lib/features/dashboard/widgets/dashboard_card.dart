import 'dart:ui';
import 'package:flutter/material.dart';

class GradientBorderPainter extends CustomPainter {
  final double width;
  final double radius;
  final Gradient gradient;

  GradientBorderPainter({
    required this.width,
    required this.radius,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    
    // Define the paint for the border
    final paint = Paint()
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..shader = gradient.createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant GradientBorderPainter oldDelegate) {
    return oldDelegate.width != width ||
        oldDelegate.radius != radius ||
        oldDelegate.gradient != gradient;
  }
}

class DashboardCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? glowColor;
  final double borderRadius;
  final double borderOpacity;
  final double bgOpacity;
  final bool isGlass;
  final List<Color>? gradientBorder;

  const DashboardCard({
    super.key,
    required this.child,
    this.onTap,
    this.glowColor,
    this.borderRadius = 24,
    this.borderOpacity = 0.1,
    this.bgOpacity = 0.05,
    this.isGlass = false,
    this.gradientBorder,
  });

  @override
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      decoration: BoxDecoration(
        color: widget.isGlass
            ? Colors.white.withOpacity(widget.bgOpacity)
            : Colors.white.withOpacity(widget.bgOpacity + 0.01),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: widget.gradientBorder != null
            ? null
            : Border.all(
                color: Colors.white.withOpacity(widget.borderOpacity),
                width: 1,
              ),
        boxShadow: widget.glowColor != null
            ? [
                BoxShadow(
                  color: widget.glowColor!.withOpacity(0.14),
                  blurRadius: 20,
                  spreadRadius: -4,
                  offset: const Offset(0, 6),
                ),
                if (widget.isGlass)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
              ]
            : null,
      ),
      child: widget.isGlass
          ? ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  color: Colors.transparent,
                  child: CustomPaint(
                    painter: widget.gradientBorder != null
                        ? GradientBorderPainter(
                            width: 1.2,
                            radius: widget.borderRadius,
                            gradient: LinearGradient(
                              colors: widget.gradientBorder!,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          )
                        : null,
                    child: widget.child,
                  ),
                ),
              ),
            )
          : CustomPaint(
              painter: widget.gradientBorder != null
                  ? GradientBorderPainter(
                      width: 1.2,
                      radius: widget.borderRadius,
                      gradient: LinearGradient(
                        colors: widget.gradientBorder!,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    )
                  : null,
              child: widget.child,
            ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: (_) => _animController.forward(),
        onTapUp: (_) => _animController.reverse(),
        onTapCancel: () => _animController.reverse(),
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: card,
        ),
      );
    }

    return card;
  }
}
