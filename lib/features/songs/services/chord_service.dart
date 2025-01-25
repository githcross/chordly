import 'package:cloud_firestore/cloud_firestore.dart';

class ChordService {
  final FirebaseFirestore _firestore;

  ChordService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Datos iniciales organizados por categoría
  static const Map<String, List<String>> _initialChords = {
    'Mayores': [
      'C',
      'C#',
      'D',
      'Eb',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'Bb',
      'B',
    ],
    'Menores': [
      'Cm',
      'C#m',
      'Dm',
      'Ebm',
      'Em',
      'Fm',
      'F#m',
      'Gm',
      'G#m',
      'Am',
      'Bbm',
      'Bm',
    ],
    'Séptima': [
      'C7',
      'C#7',
      'D7',
      'Eb7',
      'E7',
      'F7',
      'F#7',
      'G7',
      'G#7',
      'A7',
      'Bb7',
      'B7',
    ],
    'Menor Séptima': [
      'Cm7',
      'C#m7',
      'Dm7',
      'Ebm7',
      'Em7',
      'Fm7',
      'F#m7',
      'Gm7',
      'G#m7',
      'Am7',
      'Bbm7',
      'Bm7',
    ],
    'Suspendidas': [
      'Csus2',
      'C#sus2',
      'Dsus2',
      'Ebsus2',
      'Esus2',
      'Fsus2',
      'F#sus2',
      'Gsus2',
      'G#sus2',
      'Asus2',
      'Bbsus2',
      'Bsus2',
      'Csus4',
      'C#sus4',
      'Dsus4',
      'Ebsus4',
      'Esus4',
      'Fsus4',
      'F#sus4',
      'Gsus4',
      'G#sus4',
      'Asus4',
      'Bbsus4',
      'Bsus4',
    ],
    'Aumentadas y Disminuidas': [
      'Caum',
      'C#aum',
      'Daum',
      'Ebaum',
      'Eaum',
      'Faum',
      'F#aum',
      'Gaum',
      'G#aum',
      'Aaum',
      'Bbaum',
      'Baum',
      'Cdim',
      'C#dim',
      'Ddim',
      'Ebdim',
      'Edim',
      'Fdim',
      'F#dim',
      'Gdim',
      'G#dim',
      'Adim',
      'Bbdim',
      'Bdim',
    ],
  };

  String _getChordCategory(String chord) {
    if (chord.endsWith('m7')) return 'Menor Séptima';
    if (chord.endsWith('7')) return 'Séptima';
    if (chord.endsWith('m')) return 'Menores';
    return 'Mayores';
  }

  Future<void> _initializeChords() async {
    final batch = _firestore.batch();

    // Crear un documento para cada categoría
    _initialChords.forEach((category, chords) {
      final docRef = _firestore.collection('chords').doc(category);
      batch.set(
          docRef,
          {
            'notes': chords,
            'order': _getCategoryOrder(category),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(
              merge: true)); // Usar merge para no sobrescribir datos existentes
    });

    await batch.commit();
  }

  int _getCategoryOrder(String category) {
    switch (category) {
      case 'Mayores':
        return 1;
      case 'Menores':
        return 2;
      case 'Séptima':
        return 3;
      case 'Menor Séptima':
        return 4;
      default:
        // Para categorías personalizadas, usar el timestamp como orden
        return 1000;
    }
  }

  Future<Map<String, List<String>>> getChordCategories() async {
    try {
      final snapshot = await _firestore.collection('chords').get();

      if (snapshot.docs.isEmpty) {
        print('Initializing chord collection...');
        await _initializeChords();
        return _initialChords;
      }

      final Map<String, List<String>> categories = {};

      // Ordenar primero por order y luego por createdAt
      final sortedDocs = snapshot.docs.toList()
        ..sort((a, b) {
          final orderA = a.data()['order'] as int;
          final orderB = b.data()['order'] as int;
          if (orderA != orderB) return orderA.compareTo(orderB);

          final timeA = a.data()['createdAt'] as Timestamp?;
          final timeB = b.data()['createdAt'] as Timestamp?;
          if (timeA == null || timeB == null) return 0;
          return timeA.compareTo(timeB);
        });

      for (var doc in sortedDocs) {
        final data = doc.data();
        if (data.containsKey('notes') && data['notes'] is List) {
          categories[doc.id] = List<String>.from(data['notes'] as List);
        }
      }

      if (categories.isEmpty) {
        print('No chords found in Firestore');
        throw Exception('No chords available');
      }

      return categories;
    } catch (e) {
      print('Error fetching chords: $e');
      return _initialChords;
    }
  }

  // Método para agregar una nueva categoría de acordes
  Future<void> addChordCategory(
      String categoryName, List<String> chords) async {
    try {
      await _firestore.collection('chords').doc(categoryName).set({
        'notes': chords,
        'order': _getCategoryOrder(categoryName),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding chord category: $e');
      throw Exception('Failed to add chord category');
    }
  }

  // Método para actualizar acordes en una categoría
  Future<void> updateCategoryChords(
      String categoryName, List<String> chords) async {
    try {
      await _firestore.collection('chords').doc(categoryName).update({
        'notes': chords,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating chord category: $e');
      throw Exception('Failed to update chord category');
    }
  }

  // Mapeo de notas para transposición
  final Map<String, List<String>> _noteSequence = {
    'mayores': [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B'
    ],
    'menores': [
      'Cm',
      'C#m',
      'Dm',
      'D#m',
      'Em',
      'Fm',
      'F#m',
      'Gm',
      'G#m',
      'Am',
      'A#m',
      'Bm'
    ],
    'septima': [
      'C7',
      'C#7',
      'D7',
      'D#7',
      'E7',
      'F7',
      'F#7',
      'G7',
      'G#7',
      'A7',
      'A#7',
      'B7'
    ],
    'menor_septima': [
      'Cm7',
      'C#m7',
      'Dm7',
      'D#m7',
      'Em7',
      'Fm7',
      'F#m7',
      'Gm7',
      'G#m7',
      'Am7',
      'A#m7',
      'Bm7'
    ]
  };

  String transposeUp(String chord) {
    // Extraer la nota base y los modificadores
    final baseNote = _extractBaseNote(chord);
    final modifiers = chord.substring(baseNote.length);

    // Encontrar la secuencia correcta basada en los modificadores
    final sequence = _getSequenceForChord(chord);
    if (sequence != null) {
      final index = sequence.indexOf(chord);
      if (index != -1) {
        return sequence[(index + 1) % sequence.length];
      }
    }

    // Si no encontramos una secuencia específica, transponer solo la nota base
    final majorSequence = _noteSequence['mayores']!;
    final baseIndex = majorSequence.indexOf(baseNote);
    if (baseIndex != -1) {
      final newBase = majorSequence[(baseIndex + 1) % majorSequence.length];
      return newBase + modifiers;
    }

    return chord;
  }

  String transposeDown(String chord) {
    // Extraer la nota base y los modificadores
    final baseNote = _extractBaseNote(chord);
    final modifiers = chord.substring(baseNote.length);

    // Encontrar la secuencia correcta basada en los modificadores
    final sequence = _getSequenceForChord(chord);
    if (sequence != null) {
      final index = sequence.indexOf(chord);
      if (index != -1) {
        return sequence[(index - 1 + sequence.length) % sequence.length];
      }
    }

    // Si no encontramos una secuencia específica, transponer solo la nota base
    final majorSequence = _noteSequence['mayores']!;
    final baseIndex = majorSequence.indexOf(baseNote);
    if (baseIndex != -1) {
      final newBase = majorSequence[
          (baseIndex - 1 + majorSequence.length) % majorSequence.length];
      return newBase + modifiers;
    }

    return chord;
  }

  String _extractBaseNote(String chord) {
    if (chord.length >= 2 && chord[1] == '#') {
      return chord.substring(0, 2);
    }
    return chord.substring(0, 1);
  }

  List<String>? _getSequenceForChord(String chord) {
    if (chord.endsWith('m7')) return _noteSequence['menor_septima'];
    if (chord.endsWith('7')) return _noteSequence['septima'];
    if (chord.endsWith('m')) return _noteSequence['menores'];
    if (_noteSequence['mayores']!.contains(chord))
      return _noteSequence['mayores'];
    return null;
  }
}
