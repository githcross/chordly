import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class CloudinaryService {
  static const String cloudName = 'dxkuoxqzs';
  static const String apiKey = '653841673249878';
  static const String apiSecret = 'gFlewu1V8scWo_Rl1rT-CWWVyCA';

  static Future<String> uploadFile({
    required File file,
    required String folder,
    required String resourceType,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final signature = _generateSignature(timestamp, folder);

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
            'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload'),
      );

      request.fields.addAll({
        'api_key': apiKey,
        'timestamp': timestamp.toString(),
        'signature': signature,
        'folder': folder,
      });

      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      final jsonData = jsonDecode(responseString);

      if (response.statusCode != 200) {
        throw Exception('Error: ${jsonData['error']['message']}');
      }

      return jsonData['secure_url'];
    } catch (e) {
      throw Exception('Error al subir archivo: $e');
    }
  }

  static String _generateSignature(int timestamp, String folder) {
    final params = 'folder=$folder&timestamp=$timestamp$apiSecret';
    return sha1.convert(utf8.encode(params)).toString();
  }
}
