                onDismissed: (direction) async {
                  try {
                    // Marcar como archivada en la colección songs
                    await FirebaseFirestore.instance
                        .collection('songs')
                        .doc(song['songId'])
                        .update({'isArchived': true});

                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Canción archivada'),
                        duration: Duration(seconds: 3),
                        margin: EdgeInsets.all(8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        behavior: SnackBarBehavior.floating,
                        action: SnackBarAction(
                          label: 'Deshacer',
                          textColor: Colors.yellow,
                          onPressed: () async {
                            // Restaurar el estado no archivado
                            await FirebaseFirestore.instance
                                .collection('songs')
                                .doc(song['songId'])
                                .update({'isArchived': false});
                          },
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al archivar la canción: $e'),
                        margin: EdgeInsets.all(8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }, 