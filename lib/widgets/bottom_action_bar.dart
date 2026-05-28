import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surfaceLowest,
        border: Border(top: BorderSide(color: AppColors.surfaceVariant)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(children: children),
      ),
    );
  }
}

class BottomActionButton extends StatelessWidget {
  const BottomActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(label),
            ],
          );

    final style = outlined
        ? OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
            side: const BorderSide(color: AppColors.outline),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          )
        : FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          );

    return SizedBox(
      height: 52,
      width: double.infinity,
      child: outlined
          ? OutlinedButton(onPressed: onPressed, style: style, child: child)
          : FilledButton(onPressed: onPressed, style: style, child: child),
    );
  }
}
