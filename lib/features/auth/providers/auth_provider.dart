import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream of the current Firebase User
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Provider to verify the Super Admin 'admin' custom claim
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return false;

  // Force refresh the token to retrieve latest custom claims from the backend
  final idTokenResult = await user.getIdTokenResult(true);
  final bool? adminClaim = idTokenResult.claims?['admin'] as bool?;

  return adminClaim ?? false;
});

/// Notifier to handle Authentication Actions (Dreamflow Proof)
class AuthNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> login(String email, String password) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }
}

final authActionProvider =
    NotifierProvider<AuthNotifier, void>(AuthNotifier.new);
