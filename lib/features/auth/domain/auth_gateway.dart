abstract interface class AuthGateway {
  Future<void> signInWithGoogle(String role);
  Future<void> signInWithApple(String role);
  Future<void> sendPhoneCode(String phone);
  Future<void> confirmPhoneCode(String code, String role);
}
