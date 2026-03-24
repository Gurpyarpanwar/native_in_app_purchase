import 'native_product.dart';

class ProductQueryResponse {
  const ProductQueryResponse({
    required this.products,
    required this.notFoundIds,
  });

  factory ProductQueryResponse.fromMap(Map<String, dynamic> map) {
    return ProductQueryResponse(
      products: (map['products'] as List<dynamic>? ?? const <dynamic>[])
          .cast<Map<dynamic, dynamic>>()
          .map(
            (item) =>
                NativeInAppProduct.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
      notFoundIds: (map['notFoundIds'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(),
    );
  }

  final List<NativeInAppProduct> products;
  final List<String> notFoundIds;
}
