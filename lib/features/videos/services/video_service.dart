Future<void> saveVideoData({
  required String groupId,
  required String videoUrl,
  required String publicId,
  required String description,
}) async {
  await FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .collection('videos')
      .add({
    'videoUrl': videoUrl,
    'publicId': publicId,
    'description': description,
    'createdAt': FieldValue.serverTimestamp(),
    'views': 0,
    'likes': 0,
  });
}
