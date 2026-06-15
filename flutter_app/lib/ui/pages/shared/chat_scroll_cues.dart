import 'package:flutter/material.dart';

class ChatScrollCues extends StatelessWidget {
  const ChatScrollCues({
    super.key,
    required this.showJumpButton,
    required this.newMessageCount,
    required this.onJumpToLatest,
    required this.color,
  });

  final bool showJumpButton;
  final int newMessageCount;
  final VoidCallback onJumpToLatest;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hasNewMessages = newMessageCount > 0;
    final visible = showJumpButton || hasNewMessages;

    return IgnorePointer(
      ignoring: !visible,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 88,
            child: Center(
              child: AnimatedOpacity(
                opacity: hasNewMessages ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: AnimatedScale(
                  scale: hasNewMessages ? 1 : .78,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: GestureDetector(
                    onTap: onJumpToLatest,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(.28),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Text(
                        newMessageCount == 1
                            ? '1 new message'
                            : '$newMessageCount new messages',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 78,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: AnimatedScale(
                scale: visible ? 1 : .82,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 8,
                  shadowColor: color.withOpacity(.24),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onJumpToLatest,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: color,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
