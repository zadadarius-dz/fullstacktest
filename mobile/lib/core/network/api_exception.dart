class ApiException implements Exception {
  ApiException(this.message, {this.statusCode = 0, this.errors});

  final String message;
  final int statusCode;
  final Map<String, List<String>>? errors;

  bool get isUnauthorized => statusCode == 401;
  bool get isConflict => statusCode == 409;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}
