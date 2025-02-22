import 'package:flutter/material.dart';
import 'song_section.dart';

List<SongSection> parseSongStructure(
    String lyrics, List<Map<String, dynamic>> sectionsConfig) {
  final sections = <SongSection>[];
  if (lyrics.isEmpty) return sections;

  final lines = lyrics.split('\n');
  final sectionRegex = RegExp(
      r'^\[(.*?)\]$'); // Solo coincide con líneas que solo contengan el tag
  bool hasSections = false;
  String currentType = 'Letra';
  Color currentColor = Colors.grey.shade200;
  StringBuffer currentContent = StringBuffer();

  for (final line in lines) {
    if (sectionRegex.hasMatch(line.trim())) {
      hasSections = true;

      // Solo agregar la sección anterior si tiene contenido
      if (currentContent.isNotEmpty) {
        sections.add(SongSection(
          type: currentType,
          content: currentContent.toString().trim(),
          color: currentColor,
        ));
        currentContent.clear();
      }

      // Actualizar el tipo actual
      currentType = sectionRegex.firstMatch(line.trim())!.group(1)!;
      currentColor = _getColorForSection(currentType, sectionsConfig);
    } else {
      // Ignorar líneas vacías entre secciones
      if (line.trim().isNotEmpty || currentContent.isNotEmpty) {
        currentContent.writeln(line);
      }
    }
  }

  // Agregar última sección solo si tiene contenido
  if (currentContent.isNotEmpty) {
    sections.add(SongSection(
      type: hasSections ? currentType : 'Letra',
      content: currentContent.toString().trim(),
      color: currentColor,
    ));
  }

  // Si no hay secciones, asegurar al menos una sección "Letra"
  if (sections.isEmpty) {
    sections.add(SongSection(
      type: 'Letra',
      content: lyrics.trim(),
      color: Colors.grey.shade200,
    ));
  }

  return sections;
}

Color _getColorForSection(
    String type, List<Map<String, dynamic>> sectionsConfig) {
  final baseType = type
      .replaceAll(RegExp(r'[-_]?\d+.*'), '') // Elimina números y sufijos
      .toLowerCase()
      .trim();

  // Buscar coincidencia en la configuración de Firestore
  final section = sectionsConfig.firstWhere(
    (s) => s['name'].toString().toLowerCase() == baseType,
    orElse: () => {'defaultColor': '#00BCD4'}, // Fallback
  );

  return _parseColor(section['defaultColor']);
}

Color _parseColor(String hex) => Color(int.parse(hex.replaceAll('#', '0xFF')));
