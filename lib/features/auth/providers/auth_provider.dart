import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chordly/repositories/user_repository.dart';
import 'package:chordly/services/auth_service.dart';
import 'package:chordly/models/user_model.dart';

part 'auth_provider.g.dart';

@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  @override
  FutureOr<User?> build() {
    return ref.watch(authStateProvider.future);
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final credential = await ref.read(authServiceProvider).signInWithGoogle();
      if (credential?.user == null) return null;

      final user = credential!.user!;

      final userModel = UserModel(
        id: user.uid,
        email: user.email!,
        name: user.displayName ?? 'Usuario',
        profilePicture: user.photoURL,
        lastLogin: DateTime.now(),
        joinedGroups: const [],
        notifications: const [],
      );

      await ref.read(userRepositoryProvider).createUser(userModel);
      await ref.read(userRepositoryProvider).updateLastLogin(user.uid);

      return user;
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await ref.read(authServiceProvider).signOut();
      return null;
    });
  }
}
