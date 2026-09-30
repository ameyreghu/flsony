import 'package:flutter/material.dart';

import 'theme.dart';

class Section extends StatelessWidget {
  const Section({super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Row(
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  color: Palette.textDim,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.hairline),
      ),
      child: child,
    );
  }
}

class SegmentOption<T> {
  const SegmentOption(this.value, this.label, this.icon);
  final T value;
  final String label;
  final IconData icon;
}

/// Big three-way selector used for the noise-control mode.
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged, required this.enabled});
  final List<SegmentOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _tile(options[i])),
        ],
      ],
    );
  }

  Widget _tile(SegmentOption<T> o) {
    final selected = o.value == value;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged(o.value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 84,
          decoration: BoxDecoration(
            color: selected ? Palette.accent : Palette.surfaceHi,
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? [BoxShadow(color: Palette.accent.withValues(alpha: 0.28), blurRadius: 22, spreadRadius: -4)]
                : const [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(o.icon, size: 24, color: selected ? const Color(0xFF04201A) : Palette.textDim),
              const SizedBox(height: 8),
              Text(
                o.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? const Color(0xFF04201A) : Palette.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ToggleRow extends StatelessWidget {
  const ToggleRow({super.key, required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool? value;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final on = value ?? false;
    return InkWell(
      onTap: value == null ? null : onChanged,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: Palette.surfaceHi, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 19, color: on ? Palette.accent : Palette.textDim),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Palette.textDim)),
                ],
              ),
            ),
            _Switch(on: on, enabled: value != null),
          ],
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.on, required this.enabled});
  final bool on;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(3),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: on ? Palette.accent : Palette.surfaceHi,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: on ? Colors.transparent : Palette.hairline),
        ),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: on ? const Color(0xFF04201A) : Palette.textDim, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class Chip2 extends StatelessWidget {
  const Chip2({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Palette.accent.withValues(alpha: 0.16) : Palette.surfaceHi,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? Palette.accent.withValues(alpha: 0.7) : Colors.transparent),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Palette.accent : Palette.textDim),
          ),
        ),
      ),
    );
  }
}
