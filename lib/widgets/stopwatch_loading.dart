import 'dart:math' as math;

import 'package:flutter/material.dart';

class StopwatchLoading extends StatefulWidget {
  final String? label;
  final double size;
  final Color color;

  const StopwatchLoading({
    super.key,
    this.label,
    this.size = 56,
    this.color = const Color(0xFF0A66C2),
  });

  @override
  State<StopwatchLoading> createState() => _StopwatchLoadingState();
}

class _StopwatchLoadingState extends State<StopwatchLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label?.trim() ?? '';
    final iconSize = widget.size;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: iconSize,
          height: iconSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.timer_outlined,
                size: iconSize,
                color: widget.color,
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _controller.value * 2 * math.pi,
                    child: child,
                  );
                },
                child: Transform.translate(
                  offset: Offset(0, -iconSize * 0.18),
                  child: Container(
                    width: iconSize * 0.08,
                    height: iconSize * 0.24,
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF27415F),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
