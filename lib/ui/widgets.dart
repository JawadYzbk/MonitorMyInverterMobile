import 'package:flutter/material.dart';

import 'theme.dart';

/// Rounded dark card with an optional title row.
class Panel extends StatelessWidget {
  final String? title;
  final Widget? action;
  final Widget child;
  final EdgeInsets padding;

  const Panel({super.key, this.title, this.action, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || action != null) ...[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (title != null)
                  Text(title!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.text)),
                ?action,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String detail;
  final Color accent;
  final Widget? extra;

  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    required this.detail,
    required this.accent,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: const TextStyle(fontSize: 13, color: C.muted))),
          ]),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w600, color: accent, fontFeatures: tabular)),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(unit!, style: const TextStyle(fontSize: 13, color: C.faint)),
              ],
            ],
          ),
          ?extra,
          const SizedBox(height: 6),
          Text(detail, style: const TextStyle(fontSize: 11.5, color: C.muted), maxLines: 3),
        ],
      ),
    );
  }
}

class Fact extends StatelessWidget {
  final String label;
  final String value;
  final Widget? hint;

  const Fact({super.key, required this.label, required this.value, this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: C.inset, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: C.muted)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: C.text, fontFeatures: tabular)),
          if (hint != null) ...[const SizedBox(height: 2), hint!],
        ],
      ),
    );
  }
}

/// Two-column grid of equally wide children.
class TwoColumn extends StatelessWidget {
  final List<Widget> children;
  final double gap;

  const TwoColumn({super.key, required this.children, this.gap = 10});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: children[i]),
            SizedBox(width: gap),
            Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
          ],
        ),
      ));
      if (i + 2 < children.length) rows.add(SizedBox(height: gap));
    }
    return Column(children: rows);
  }
}

class Legend extends StatelessWidget {
  final List<(String, Color)> items;
  final bool square;

  const Legend({super.key, required this.items, this.square = true});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final (label, color) in items)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(square ? 2 : 5),
              ),
            ),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 11.5, color: C.muted)),
          ]),
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 10.5, letterSpacing: 0.6, fontWeight: FontWeight.w500, color: C.muted)),
      );
}

class Placeholder2 extends StatelessWidget {
  final String text;
  const Placeholder2(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: C.muted)),
      );
}
