import 'dart:async';

import 'package:flutter/material.dart';

class AppOverlayMessage {
  AppOverlayMessage._();

  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 1400),
    Color backgroundColor = const Color(0xEE232239),
    Color borderColor = const Color(0xFF4B5471),
    Color textColor = Colors.white,
    Color iconColor = const Color(0xFF8AF5A4),
    IconData icon = Icons.info_outline,
    bool showCloseButton = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    hide();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (context) {
        return _AppOverlayMessageView(
          message: message,
          backgroundColor: backgroundColor,
          borderColor: borderColor,
          textColor: textColor,
          iconColor: iconColor,
          icon: icon,
          showCloseButton: showCloseButton,
          actionLabel: actionLabel,
          onAction: () {
            hide();
            onAction?.call();
          },
          onClose: hide,
        );
      },
    );

    _currentEntry = entry;
    overlay.insert(entry);
    _dismissTimer = Timer(duration, hide);
  }

  static void hide() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _AppOverlayMessageView extends StatelessWidget {
  const _AppOverlayMessageView({
    required this.message,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.iconColor,
    required this.icon,
    required this.showCloseButton,
    required this.actionLabel,
    required this.onAction,
    required this.onClose,
  });

  final String message;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color iconColor;
  final IconData icon;
  final bool showCloseButton;
  final String? actionLabel;
  final VoidCallback onAction;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 20,
      right: 20,
      child: IgnorePointer(
        ignoring: false,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: iconColor, size: 16),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: actionLabel != null || showCloseButton
                            ? 220
                            : 280,
                      ),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (actionLabel != null) ...[
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: iconColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          actionLabel!,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                    if (showCloseButton) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: onClose,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: textColor.withValues(alpha: 0.86),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
