@override
void didUpdateWidget(ProfileScreen oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (widget.user != oldWidget.user) {
    _loadUserData();
  }
}

void _loadUserData() {
  final user = ref.read(authProvider);
  _nameController.text = user?.displayName ?? '';
  _bioController.text = user?.biography ?? '';
  _selectedImage = user?.photoURL;
}
