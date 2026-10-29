abstract interface class AuthGateway {
  Future<void> signInWithGoogle(String role);
  Future<void> signInWithApple(String role);
}
