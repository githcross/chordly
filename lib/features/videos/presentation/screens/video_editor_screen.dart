@override
void initState() {
  super.initState();
  _videoService = ref.read(videoServiceProvider);
  _descriptionController = TextEditingController();
  _controller = VideoEditorController.file(
    widget.videoFile,
    minDuration: const Duration(seconds: 1),
    maxDuration: const Duration(minutes: 15),
    cacheDirectory: await getTemporaryDirectory(),
  );
  _initializeEditor();
  FFmpegKitConfig.enableLogCallback((log) => debugPrint(log.getMessage()));
  FFmpegKitConfig.enableStatisticsCallback((stats) => debugPrint(stats.toString()));
  // ... resto del código
}

Future<void> _exportVideo() async {
  setState(() => _isProcessing = true);
  
  try {
    final config = VideoFFmpegVideoEditorConfig(
      _controller,
      format: VideoExportFormat.mp4,
      videoCodec: VideoCodec.h264,
      audioCodec: AudioCodec.aac,
      customOptions: '-preset ultrafast -crf 23',
    );
    
    final execute = await config.getExecuteConfig();
    final session = await FFmpegKit.execute(execute.command);
    
    if (await session.getReturnCode().isValueSuccess()) {
      final videoFile = File(execute.outputPath);
      await _uploadVideo(videoFile);
    } else {
      throw Exception('Error en FFmpeg: ${await session.getFailStackTrace()}');
    }
  } catch (e) {
    _showError('Error procesando video: $e');
  } finally {
    if (mounted) setState(() => _isProcessing = false);
  }
} 