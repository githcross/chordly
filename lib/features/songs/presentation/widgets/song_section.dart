import 'package:flutter/material.dart';

class SongSection {
  final String type;
  final String content;
  final Color? color;

  const SongSection({
    required this.type,
    required this.content,
    this.color,
  });

  @override
  String toString() =>
      'SongSection(type: $type, content: ${content.length} chars)';
}
