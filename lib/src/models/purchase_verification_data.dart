class PurchaseVerificationData {
  const PurchaseVerificationData({
    required this.localVerificationData,
    required this.serverVerificationData,
    required this.source,
  });

  factory PurchaseVerificationData.fromMap(Map<String, dynamic> map) {
    return PurchaseVerificationData(
      localVerificationData: map['localVerificationData'] as String? ?? '',
      serverVerificationData: map['serverVerificationData'] as String? ?? '',
      source: map['source'] as String? ?? '',
    );
  }

  final String localVerificationData;
  final String serverVerificationData;
  final String source;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'localVerificationData': localVerificationData,
      'serverVerificationData': serverVerificationData,
      'source': source,
    };
  }
}
