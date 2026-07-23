class AppUpdateException implements Exception {
  const AppUpdateException(this.userMessage);

  final String userMessage;

  @override
  String toString() => userMessage;
}
