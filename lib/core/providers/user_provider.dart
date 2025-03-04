import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/user/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final userServiceProvider = Provider<UserService>((ref) {
  return UserService(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  );
});
