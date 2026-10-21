import 'package:flutter/material.dart';

import 'theme.dart';

/// Ported from src/components/AppUi.tsx — shared building blocks.

/// Scrollable screen scaffold: centered content with max width 720, gap 16.
class Screen extends StatelessWidget {
  final List<Widget> children;
  final bool scroll;

  const Screen({super.key, required this.children, this.scroll = true});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: children,
      ),
    );

    if (!scroll) {
      return Material(
        color: colors.background,
        child: Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Center(child: content),
        ),
      );
    }

    return Material(
      color: colors.background,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + 16,
          bottom: MediaQuery.paddingOf(context).bottom + 28,
        ),
        child: Center(child: content),
      ),
    );
  }
}

class PageTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? right;

  const PageTitle({super.key, required this.title, this.subtitle, this.right});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 12,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 3,
            children: [
              Text(
                title,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  color: colors.foreground,
                  fontFamily: 'Inter',
                  fontFamilyFallback: const ['NotoSansArabic'],
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    height: 20 / 13,
                    color: colors.mutedForeground,
                    fontFamily: 'Inter',
                    fontFamilyFallback: const ['NotoSansArabic'],
                  ),
                ),
            ],
          ),
        ),
        ?right,
      ],
    );
  }
}

class CardX extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final double? borderRadius;
  final Color? borderColor;

  const CardX({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(17),
    this.backgroundColor,
    this.borderRadius,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.card,
        borderRadius:
            BorderRadius.circular(borderRadius ?? colors.radius + 10),
        border: Border.all(color: borderColor ?? colors.border),
      ),
      child: child,
    );
  }
}

class SectionHeading extends StatelessWidget {
  final String title;
  const SectionHeading({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text(
      title,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: colors.foreground,
        fontFamily: 'Inter',
        fontFamilyFallback: const ['NotoSansArabic'],
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPress;
  final IconData? icon;
  final bool secondary;
  final bool disabled;
  final bool busy;

  const ActionButton({
    super.key,
    required this.label,
    this.onPress,
    this.icon,
    this.secondary = false,
    this.disabled = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final background = secondary ? colors.secondary : colors.primary;
    final foreground =
        secondary ? colors.secondaryForeground : colors.primaryForeground;
    final enabled = !disabled && !busy && onPress != null;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onPress : null,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: disabled ? 0.55 : 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              spacing: 9,
              children: [
                if (busy)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: foreground,
                      strokeWidth: 2.2,
                    ),
                  )
                else if (icon != null)
                  Icon(icon, size: 19, color: foreground),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                      fontFamily: 'Inter',
                      fontFamilyFallback: const ['NotoSansArabic'],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onPress;

  const Pill({super.key, required this.label, this.active = false, this.onPress});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: active ? colors.primary : colors.muted,
      shape: StadiumBorder(
        side: BorderSide(color: active ? colors.primary : colors.border),
      ),
      child: InkWell(
        onTap: onPress,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? colors.primaryForeground : colors.mutedForeground,
              fontFamily: 'Inter',
              fontFamilyFallback: const ['NotoSansArabic'],
            ),
          ),
        ),
      ),
    );
  }
}

/// Standard app text style helper (Inter with Arabic fallback).
TextStyle appText(
  BuildContext context, {
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double? height,
  TextAlign? textAlign,
}) {
  final colors = AppColors.of(context);
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    color: color ?? colors.foreground,
    fontFamily: 'Inter',
    fontFamilyFallback: const ['NotoSansArabic'],
  );
}