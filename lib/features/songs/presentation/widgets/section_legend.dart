import 'package:flutter/material.dart';
import 'package:chordly/core/theme/app_theme.dart';

class SectionLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _LegendItem(
          label: 'Intro',
          color: Theme.of(context).colorScheme.introColor,
        ),
        _LegendItem(
          label: 'Verse',
          color: Theme.of(context).colorScheme.verseColor,
        ),
        _LegendItem(
          label: 'Chorus',
          color: Theme.of(context).colorScheme.chorusColor,
        ),
        _LegendItem(
          label: 'Bridge',
          color: Theme.of(context).colorScheme.bridgeColor,
        ),
        _LegendItem(
          label: 'Outro',
          color: Theme.of(context).colorScheme.outroColor,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
