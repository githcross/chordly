import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/core/theme/text_styles.dart';
import 'package:chordly/core/providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Configuración',
          style: AppTextStyles.appBarTitle(context),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          ListTile(
            title: Text(
              'Apariencia',
              style: AppTextStyles.sectionTitle(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tema',
                  style: AppTextStyles.subtitle(context),
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
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          // Aquí se pueden agregar más secciones de configuración
        ],
      ),
    );
  }
}
