import 'package:flutter/material.dart';

import '../utils/tap_guard.dart';

enum AppButtonVariant { primary, secondary, ghost, destructive }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.cooldown = const Duration(milliseconds: 500),
  });

  final Widget child;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? icon;
  final Duration cooldown;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  late TapGuard _tapGuard;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _tapGuard = TapGuard(cooldown: widget.cooldown);
  }

  @override
  void didUpdateWidget(covariant AppButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cooldown != widget.cooldown) {
      _tapGuard = TapGuard(cooldown: widget.cooldown);
    }
  }

  void _setPressed(bool value) {
    if (widget.onPressed == null || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handlePressed() {
    final callback = widget.onPressed;
    if (callback != null) _tapGuard.run(callback);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final onPressed = widget.onPressed == null ? null : _handlePressed;
    final destructiveStyle = FilledButton.styleFrom(
      backgroundColor: colors.error,
      foregroundColor: colors.onError,
    );

    final button = switch (widget.variant) {
      AppButtonVariant.primary => widget.icon == null
          ? FilledButton(onPressed: onPressed, child: widget.child)
          : FilledButton.icon(
              onPressed: onPressed,
              icon: widget.icon!,
              label: widget.child,
            ),
      AppButtonVariant.secondary => widget.icon == null
          ? OutlinedButton(onPressed: onPressed, child: widget.child)
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: widget.icon!,
              label: widget.child,
            ),
      AppButtonVariant.ghost => widget.icon == null
          ? TextButton(onPressed: onPressed, child: widget.child)
          : TextButton.icon(
              onPressed: onPressed,
              icon: widget.icon!,
              label: widget.child,
            ),
      AppButtonVariant.destructive => widget.icon == null
          ? FilledButton(
              onPressed: onPressed,
              style: destructiveStyle,
              child: widget.child,
            )
          : FilledButton.icon(
              onPressed: onPressed,
              style: destructiveStyle,
              icon: widget.icon!,
              label: widget.child,
            ),
    };

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? 0.97 : 1,
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: button,
      ),
    );
  }
}
