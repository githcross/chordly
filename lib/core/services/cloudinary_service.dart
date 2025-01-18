import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class CloudinaryService {
  static const String cloudName = 'djocon1g7';
  static const String apiKey = '637169452383251';
  static const String apiSecret = 'yj-wBWP1PT-nAiBAtTzF9Q32uF4';

  static Future<String> uploadImage(File image, String folder) async {
    try {
      // Crear timestamp y firma
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final signature = _generateSignature(timestamp, folder);

      // Preparar request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
      );

      // Añadir campos
      request.fields.addAll({
        'api_key': apiKey,
        'timestamp': timestamp.toString(),
        'signature': signature,
        'folder': folder,
      });

      // Añadir archivo
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          image.path,
        ),
      );

      // Enviar request
      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      final jsonData = jsonDecode(responseString);

      if (response.statusCode != 200) {
        throw Exception(
            'Error al subir imagen: ${jsonData['error']['message']}');
      }

      return jsonData['secure_url'];
    } catch (e) {
      throw Exception('Error al subir imagen: $e');
    }
  }

  static String _generateSignature(int timestamp, String folder) {
    final params = 'folder=$folder&timestamp=$timestamp$apiSecret';
    return sha1.convert(utf8.encode(params)).toString();
  }
}
