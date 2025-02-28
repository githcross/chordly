  ListTile(
    title: Text(
      song.title,
      style: Theme.of(context).textTheme.titleMedium,
    ),
    subtitle: Text(
      song.artist ?? '',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  ); 