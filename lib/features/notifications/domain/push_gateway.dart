abstract interface class PushGateway {
  Future<String?> requestToken();
  Stream<String> get refreshedTokens;
}
