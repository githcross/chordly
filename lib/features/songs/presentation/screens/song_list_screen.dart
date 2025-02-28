import 'package:cloud_firestore/cloud_firestore.dart';

class SongListScreen extends StatefulWidget {
  // ... (existing code)
}

class _SongListScreenState extends State<SongListScreen> {
  // ... (existing code)

  @override
  Widget build(BuildContext context) {
    // ... (existing code)

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('songs').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        final songs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index].data() as Map<String, dynamic>;

            return ListTile(
              title: Text(
                song['title'],
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                song['artist'] ?? '',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          },
        );
      },
    );
  }
}
