class NativeInAppProduct {
  const NativeInAppProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.rawPrice,
    required this.currencyCode,
    required this.currencySymbol,
    required this.type,
  });

  factory NativeInAppProduct.fromMap(Map<String, dynamic> map) {
    return NativeInAppProduct(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: map['price'] as String? ?? '',
      rawPrice: (map['rawPrice'] as num?)?.toDouble() ?? 0,
      currencyCode: map['currencyCode'] as String? ?? '',
      currencySymbol: map['currencySymbol'] as String? ?? '',
      type: map['type'] as String? ?? 'inapp',
    );
  }

  final String id;
  final String title;
  final String description;
  final String price;
  final double rawPrice;
  final String currencyCode;
  final String currencySymbol;
  final String type;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'rawPrice': rawPrice,
      'currencyCode': currencyCode,
      'currencySymbol': currencySymbol,
      'type': type,
    };
  }
}
