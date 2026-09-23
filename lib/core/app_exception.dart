/// User-facing errors never contain request bodies, passwords or session tokens.
class AppException implements Exception {
  const AppException(this.message, {this.sessionExpired = false});
  final String message;
  final bool sessionExpired;
  @override
  String toString() => message;
}
