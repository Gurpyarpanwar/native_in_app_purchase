class IAPError {
  const IAPError({
    required this.source,
    required this.code,
    required this.message,
    this.details,
  });

  factory IAPError.fromMap(Map<String, dynamic> map) {
    return IAPError(
      source: map['source'] as String? ?? 'native_in_app_purchase',
      code: map['code'] as String? ?? 'unknown',
      message: map['message'] as String? ?? 'Unknown in-app purchase error.',
      details: map['details'],
    );
  }

  final String source;
  final String code;
  final String message;
  final Object? details;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'source': source,
      'code': code,
      'message': message,
      'details': details,
    };
  }

  @override
  String toString() {
    return 'IAPError(code: $code, source: $source, message: $message, details: $details)';
  }
}
