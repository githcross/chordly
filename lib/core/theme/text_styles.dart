import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  // Títulos principales
  static TextStyle appBarTitle(BuildContext context) {
    return GoogleFonts.inter(
      // Inter es muy similar a SF Pro Display
      textStyle: Theme.of(context).textTheme.titleLarge!.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5, // Característico de iOS
            height: 1.2,
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
    );
  }

  // Títulos de secciones
  static TextStyle sectionTitle(BuildContext context) {
    return GoogleFonts.urbanist(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    );
  }

  // Títulos de elementos (grupos, canciones)
  static TextStyle itemTitle(BuildContext context) => GoogleFonts.inter(
        textStyle: Theme.of(context).textTheme.bodyLarge,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.3,
      );

  // Descripciones y subtítulos
  static TextStyle subtitle(BuildContext context) {
    return GoogleFonts.urbanist(
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
      fontSize: 14,
    );
  }

  // Texto de botones y acciones
  static TextStyle buttonText(BuildContext context) => GoogleFonts.inter(
        textStyle: Theme.of(context).textTheme.labelLarge,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
      );

  // Texto de detalles y metadata
  static TextStyle metadata(BuildContext context) => GoogleFonts.inter(
        textStyle: Theme.of(context).textTheme.bodySmall,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );

  // Texto para letras de canciones
  static TextStyle lyrics(BuildContext context) => GoogleFonts.inter(
        textStyle: Theme.of(context).textTheme.bodyLarge,
        height: 1.5,
        letterSpacing: -0.2,
      );

  // Texto para diálogos
  static TextStyle dialogTitle(BuildContext context) => GoogleFonts.inter(
        textStyle: Theme.of(context).textTheme.titleLarge,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      );

  // Texto para campos de entrada
  static TextStyle inputText(BuildContext context) => GoogleFonts.inter(
        textStyle: Theme.of(context).textTheme.bodyLarge,
        letterSpacing: -0.2,
      );
}
