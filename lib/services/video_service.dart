import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:chordly/core/services/cloudinary_service.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoService {
  static const String cloudName = 'djocon1g7';
  static const String apiKey = '637169452383251';
  static const String apiSecret = 'yj-wBWP1PT-nAiBAtTzF9Q32uF4';

  static Future<Map<String, String>> uploadVideo(File videoFile) async {
    try {
      print('Iniciando subida con credenciales:');
      print('CloudName: $cloudName');
      print('API Key: $apiKey');
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality,
        includeAudio: true,
      );

      if (mediaInfo?.file == null) {
        throw Exception('Error al comprimir el video');
      }

      final thumbnailFile =
          await VideoCompress.getFileThumbnail(videoFile.path);

      final videoUrl = await CloudinaryService.uploadFile(
        file: mediaInfo!.file!,
        folder: 'videos',
        resourceType: 'video',
      );

      final thumbnailUrl = await CloudinaryService.uploadFile(
        file: thumbnailFile,
        folder: 'thumbnails',
        resourceType: 'image',
      );

      return {
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
      };
    } catch (e) {
      throw Exception('Error al subir el video: $e');
    } finally {
      await VideoCompress.deleteAllCache();
    }
  }

  static String _generateSignature(int timestamp, String folder) {
    final params = {
      'folder': folder,
      'timestamp': timestamp.toString(),
    };

    // Ordenar parámetros alfabéticamente
    final sortedParams = params.keys.toList()..sort();
    final paramString =
        sortedParams.map((key) => '$key=${params[key]}').join('&');

    return sha1.convert(utf8.encode('$paramString$apiSecret')).toString();
  }

  static Future<void> saveYoutubeVideo({
    required String originalUrl,
    required String description,
    required String groupId,
  }) async {
    final videoId = YoutubePlayer.convertUrlToId(originalUrl) ?? '';

    await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('videos')
        .add({
      'videoId': videoId,
      'originalUrl': 'https://youtube.com/shorts/$videoId', // Formato corto
      'description': description,
      'type': 'youtube',
      'likes': 0,
      'views': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
