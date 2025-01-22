import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  // Títulos principales
  static TextStyle appBarTitle(BuildContext context) => GoogleFonts.montserrat(
        textStyle: Theme.of(context).textTheme.titleLarge,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.primary,
      );

  // Títulos de secciones
  static TextStyle sectionTitle(BuildContext context) => GoogleFonts.poppins(
        textStyle: Theme.of(context).textTheme.titleMedium,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      );

  // Títulos de elementos (grupos, canciones)
  static TextStyle itemTitle(BuildContext context) => GoogleFonts.poppins(
        textStyle: Theme.of(context).textTheme.bodyLarge,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      );

  // Descripciones y subtítulos
  static TextStyle subtitle(BuildContext context) => GoogleFonts.inter(
        textStyle: Theme.of(context).textTheme.bodyMedium,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
      );

  // Texto de botones y acciones
  static TextStyle buttonText(BuildContext context) => GoogleFonts.poppins(
        textStyle: Theme.of(context).textTheme.labelLarge,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      );

  // Texto de detalles y metadata
  static TextStyle metadata(BuildContext context) => GoogleFonts.inter(
        textStyle: Theme.of(context).textTheme.bodySmall,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );

  // Texto para letras de canciones
  static TextStyle lyrics(BuildContext context) => GoogleFonts.robotoMono(
        textStyle: Theme.of(context).textTheme.bodyLarge,
        height: 1.5,
        letterSpacing: 0.5,
      );

  // Texto para diálogos
  static TextStyle dialogTitle(BuildContext context) => GoogleFonts.poppins(
        textStyle: Theme.of(context).textTheme.titleLarge,
        fontWeight: FontWeight.w600,
      );

  // Texto para campos de entrada
  static TextStyle inputText(BuildContext context) => GoogleFonts.inter(
        textStyle: Theme.of(context).textTheme.bodyLarge,
        letterSpacing: 0.2,
      );
}
