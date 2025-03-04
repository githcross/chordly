final authProvider = StateNotifierProvider<AuthNotifier, User?>((ref) {
  return AuthNotifier(FirebaseAuth.instance);
});

class AuthNotifier extends StateNotifier<User?> {
  final FirebaseAuth _auth;

  AuthNotifier(this._auth) : super(_auth.currentUser) {
    _auth.authStateChanges().listen((user) {
      state = user;
    });
  }

  Future<void> refreshUser() async {
    await _auth.currentUser?.reload();
    state = _auth.currentUser?.copyWith(
      displayName: _auth.currentUser?.displayName,
      photoURL: _auth.currentUser?.photoURL,
    );
  }
}
