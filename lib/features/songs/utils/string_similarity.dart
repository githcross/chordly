import 'dart:math' show max;

class StringSimilarity {
  static double calculateSimilarity(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    // Convertir a minúsculas y eliminar espacios extras
    s1 = s1.toLowerCase().trim();
    s2 = s2.toLowerCase().trim();

    // Si las cadenas son idénticas antes de limpiar
    if (s1 == s2) return 100.0;

    // Extraer números al inicio
    final numMatch1 = RegExp(r'^(\d+)(.*)$').firstMatch(s1);
    final numMatch2 = RegExp(r'^(\d+)(.*)$').firstMatch(s2);

    // Si al menos una tiene número al inicio
    if (numMatch1 != null || numMatch2 != null) {
      // Obtener número y texto de la primera cadena
      int? num1;
      String text1 = s1;
      if (numMatch1 != null) {
        num1 = int.parse(numMatch1.group(1)!);
        text1 = numMatch1.group(2)?.trim() ?? '';
      }

      // Obtener número y texto de la segunda cadena
      int? num2;
      String text2 = s2;
      if (numMatch2 != null) {
        num2 = int.parse(numMatch2.group(1)!);
        text2 = numMatch2.group(2)?.trim() ?? '';
      }

      // Si ambos tienen números
      if (num1 != null && num2 != null) {
        // Si son solo números
        if (text1.isEmpty && text2.isEmpty) {
          return num1 == num2 ? 100.0 : 0.0;
        }

        // Si los números son iguales, hay similitud base
        if (num1 == num2) {
          // Si además el texto es similar, aumentar la similitud
          final textSimilarity = _calculateSimilarityForStrings(text1, text2);
          if (textSimilarity > 30) {
            return 90.0 + (textSimilarity * 0.1); // Alta similitud
          }
          return 70.0; // Similitud base por número igual
        }

        // Si los números son diferentes, calcular similitud solo del texto
        final textSimilarity = _calculateSimilarityForStrings(text1, text2);
        if (textSimilarity > 90) {
          return textSimilarity; // Alta similitud por texto muy similar
        }
        return 0.0; // Números diferentes y texto no muy similar
      }
    }

    // Obtener versiones limpias para otros casos
    final cleanS1 = _cleanString(s1);
    final cleanS2 = _cleanString(s2);

    // Si ambas cadenas quedan vacías después de limpiar y las originales son iguales
    if (cleanS1.isEmpty && cleanS2.isEmpty) {
      return s1 == s2 ? 100.0 : 0.0;
    }

    // Si una de las cadenas queda vacía, usar las versiones originales
    if (cleanS1.isEmpty || cleanS2.isEmpty) {
      return _calculateSimilarityForStrings(s1, s2);
    }

    // Usar las versiones limpias para el cálculo normal
    return _calculateSimilarityForStrings(cleanS1, cleanS2);
  }

  static double _calculateSimilarityForStrings(String s1, String s2) {
    // Verificar si una cadena contiene a la otra
    if (s1.contains(s2) || s2.contains(s1)) {
      final longerString = s1.length > s2.length ? s1 : s2;
      final shorterString = s1.length > s2.length ? s2 : s1;
      return (shorterString.length / longerString.length) * 100;
    }

    // Dividir en palabras
    final words1 = s1.split(' ');
    final words2 = s2.split(' ');

    // Contar palabras compartidas
    int sharedWords = 0;
    for (var word1 in words1) {
      if (word1.length < 3) continue;
      for (var word2 in words2) {
        if (word2.length < 3) continue;
        if (word1 == word2 || word1.contains(word2) || word2.contains(word1)) {
          sharedWords++;
          break;
        }
      }
    }

    final wordSimilarity =
        (sharedWords * 2) / (words1.length + words2.length) * 100;

    final levenSimilarity = _calculateLevenshteinSimilarity(s1, s2);

    return [wordSimilarity, levenSimilarity].reduce(max);
  }

  // Método para limpiar la cadena de números y caracteres especiales al inicio
  static String _cleanString(String str) {
    // Eliminar números y caracteres especiales al inicio
    str = str.replaceFirst(RegExp(r'^[\d\W]+'), '');

    // Eliminar espacios extras entre palabras
    str = str.replaceAll(RegExp(r'\s+'), ' ').trim();

    return str;
  }

  static double _calculateLevenshteinSimilarity(String s1, String s2) {
    int maxLength = s1.length > s2.length ? s1.length : s2.length;
    int distance = _levenshteinDistance(s1, s2);
    return ((maxLength - distance) / maxLength) * 100;
  }

  static int _levenshteinDistance(String s1, String s2) {
    var m = s1.length, n = s2.length;
    var d = List.generate(m + 1, (i) => List.filled(n + 1, 0));

    for (var i = 1; i <= m; i++) {
      d[i][0] = i;
    }
    for (var j = 1; j <= n; j++) {
      d[0][j] = j;
    }

    for (var j = 1; j <= n; j++) {
      for (var i = 1; i <= m; i++) {
        if (s1[i - 1] == s2[j - 1]) {
          d[i][j] = d[i - 1][j - 1];
        } else {
          d[i][j] = [
            d[i - 1][j] + 1, // deletion
            d[i][j - 1] + 1, // insertion
            d[i - 1][j - 1] + 1 // substitution
          ].reduce((curr, next) => curr < next ? curr : next);
        }
      }
    }
    return d[m][n];
  }
}
