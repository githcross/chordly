import 'package:flutter/material.dart';

class SnackBarUtils {
  static void showSnackBar(
    BuildContext context, {
    required String message,
    bool isError = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isError
        ? (isDark
            ? Colors.redAccent[700]
            : const Color.fromARGB(255, 255, 255, 255))
        : (isDark
            ? Colors.redAccent[700]
            : const Color.fromARGB(255, 255, 255, 255));

    final textColor = isDark
        ? const Color.fromARGB(255, 0, 0, 0)
        : (isError
            ? const Color.fromARGB(255, 255, 0, 0)
            : const Color.fromARGB(
                255, 251, 251, 251)); // Color del texto siempre visible

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(8),
      ),
    );
  }
}
