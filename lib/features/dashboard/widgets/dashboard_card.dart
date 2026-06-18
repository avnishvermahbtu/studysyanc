import 'dart:ui';
import 'package:flutter/material.dart';

class DashboardCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? glowColor;
  final double borderRadius;
  final double borderOpacity;
  final double bgOpacity;

  const DashboardCard({
    super.key,
    required this.child,
    this.onTap,
    this.glowColor,
    this.borderRadius = 24,
    this.borderOpacity = 0.1,
    this.bgOpacity = 0.05,
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
        color: Colors.white.withOpacity(widget.bgOpacity + 0.01),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(widget.borderOpacity),
          width: 1,
        ),
        boxShadow: widget.glowColor != null
            ? [
                BoxShadow(
                  color: widget.glowColor!.withOpacity(0.12),
                  blurRadius: 16,
                  spreadRadius: -4,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: widget.child,
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
