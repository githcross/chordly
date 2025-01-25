import 'package:flutter/foundation.dart';

class LyricDocument {
  final List<LyricLine> lines;

  LyricDocument({required this.lines});

  factory LyricDocument.fromInlineText(String text) {
    final lines = text.split('\n');
    return LyricDocument(
        lines: lines.map((line) => LyricLine.fromInlineText(line)).toList());
  }

  String toInlineFormat() {
    return lines.map((line) => line.toInlineFormat()).join('\n');
  }

  String toTopFormat() {
    return lines.map((line) => line.toTopFormat()).join('\n');
  }
}

class LyricLine {
  final List<ChordLyricPair> pairs;

  LyricLine({required this.pairs});

  factory LyricLine.fromInlineText(String line) {
    if (line.trim().isEmpty) {
      return LyricLine(pairs: [ChordLyricPair(chord: null, text: line)]);
    }

    final List<ChordLyricPair> pairs = [];
    final leadingSpaces = RegExp(r'^\s*').firstMatch(line)?[0] ?? '';

    if (leadingSpaces.isNotEmpty) {
      pairs.add(ChordLyricPair(chord: null, text: leadingSpaces));
    }

    final regex = RegExp(r'\(([^)]+)\)(\S*)|(\S+|\s+)');
    var matches = regex.allMatches(line.substring(leadingSpaces.length));

    for (var match in matches) {
      if (match.group(1) != null) {
        // Es un par acorde-texto
        pairs.add(
            ChordLyricPair(chord: match.group(1), text: match.group(2) ?? ''));
      } else {
        // Es solo texto
        pairs.add(ChordLyricPair(chord: null, text: match.group(3)!));
      }
    }

    return LyricLine(pairs: pairs);
  }

  String toInlineFormat() {
    return pairs.map((pair) => pair.toInlineFormat()).join('');
  }

  String toTopFormat() {
    if (!pairs.any((pair) => pair.chord != null)) {
      return pairs.map((p) => p.text).join('');
    }

    final chordLine = pairs.map((pair) => pair.toTopChordFormat()).join('');
    final textLine = pairs.map((pair) => pair.text).join('');
    return '$chordLine\n$textLine';
  }
}

class ChordLyricPair {
  final String? chord;
  final String text;

  ChordLyricPair({
    this.chord,
    required this.text,
  });

  String toInlineFormat() {
    return chord != null ? '($chord)$text' : text;
  }

  String toTopChordFormat() {
    if (chord == null) return ' ' * text.length;
    final chordText = '($chord)';
    return chordText + ' ' * (text.length > 1 ? text.length - 1 : 0);
  }
}
