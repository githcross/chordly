  Text(
    group.name,
    style: Theme.of(context).textTheme.titleMedium,
  ),
  Text(
    group.description,
    style: Theme.of(context).textTheme.bodyMedium,
  ),
  Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceVariant,
      border: Border.all(
        color: Theme.of(context).colorScheme.outline,
      ),
    ),
    child: Text(
      role.name.toUpperCase(),
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
    ),
  ), 