import 'package:flutter/material.dart';

import '../utils/tap_guard.dart';

class AppIconButton extends StatefulWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.iconSize,
    this.cooldown = const Duration(milliseconds: 500),
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double? iconSize;
  final Duration cooldown;

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  late TapGuard _tapGuard;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _tapGuard = TapGuard(cooldown: widget.cooldown);
  }

  @override
  void didUpdateWidget(covariant AppIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cooldown != widget.cooldown) {
      _tapGuard = TapGuard(cooldown: widget.cooldown);
    }
  }

  void _setPressed(bool value) {
    if (widget.onPressed == null || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final callback = widget.onPressed;

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? 0.97 : 1,
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: IconButton(
          tooltip: widget.tooltip,
          color: widget.color,
          iconSize: widget.iconSize,
          onPressed: callback == null ? null : () => _tapGuard.run(callback),
          icon: widget.icon,
        ),
      ),
    );
  }
}
