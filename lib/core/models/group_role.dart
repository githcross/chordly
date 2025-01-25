enum GroupRole {
  admin,
  editor,
  member;

  static GroupRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return GroupRole.admin;
      case 'editor':
        return GroupRole.editor;
      default:
        return GroupRole.member;
    }
  }
}
