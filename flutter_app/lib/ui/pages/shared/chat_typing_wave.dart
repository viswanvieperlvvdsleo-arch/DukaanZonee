import 'dart:math' as math;

import 'package:flutter/material.dart';

class ChatTypingWaveCue extends StatefulWidget {
  const ChatTypingWaveCue({
    super.key,
    required this.visible,
    required this.color,
  });

  final bool visible;
  final Color color;

  @override
  State<ChatTypingWaveCue> createState() => _ChatTypingWaveCueState();
}

class _ChatTypingWaveCueState extends State<ChatTypingWaveCue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    if (widget.visible) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant ChatTypingWaveCue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.visible && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topLeft,
      child: SizedBox(
        height: widget.visible ? 30 : 0,
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: widget.visible ? 1 : 0,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 8),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        final phase =
                            (_controller.value * math.pi * 2) + (index * .68);
                        final height = 7 + (math.sin(phase) + 1) * 5;
                        return Container(
                          width: 4,
                          height: height,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: widget.color.withOpacity(.48 + index * .08),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
