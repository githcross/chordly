import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/core/theme/text_styles.dart';
import 'package:chordly/core/providers/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool notificationsEnabled = true; // Estado local para las notificaciones

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Configuración',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          ListTile(
            title: Text(
              'Apariencia',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tema',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'light',
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode),
                    ),
                    ButtonSegment(
                      value: 'dark',
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode),
                    ),
                    ButtonSegment(
                      value: 'pink',
                      label: Text('Pink'),
                      icon: Icon(Icons.color_lens),
                    ),
                  ],
                  selected: {themeState.themeName},
                  onSelectionChanged: (Set<String> selection) async {
                    final newTheme = selection.first;
                    if (newTheme != themeState.themeName) {
                      await ref.read(themeProvider.notifier).setTheme(newTheme);
                    }
                  },
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor:
                        Theme.of(context).colorScheme.surface,
                    selectedForegroundColor:
                        Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          SwitchListTile(
            title: Text(
              'Notificaciones',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            value: notificationsEnabled,
            onChanged: (value) => setState(() => notificationsEnabled = value),
            activeTrackColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.3),
            inactiveTrackColor: Theme.of(context).colorScheme.surfaceVariant,
          ),
          // Aquí se pueden agregar más secciones de configuración
        ],
      ),
    );
  }
}
