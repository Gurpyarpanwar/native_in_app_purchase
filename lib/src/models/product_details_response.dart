import '../errors/iap_error.dart';
import 'product_details.dart';

class ProductDetailsResponse {
  const ProductDetailsResponse({
    required this.productDetails,
    required this.notFoundIDs,
    this.error,
  });

  factory ProductDetailsResponse.fromMap(
    Map<String, dynamic> map, {
    IAPError? error,
  }) {
    return ProductDetailsResponse(
      productDetails: (map['products'] as List<dynamic>? ?? const <dynamic>[])
          .cast<Map<dynamic, dynamic>>()
          .map(
            (item) => ProductDetails.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
      notFoundIDs: (map['notFoundIds'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(),
      error: error,
    );
  }

  final List<ProductDetails> productDetails;
  final List<String> notFoundIDs;
  final IAPError? error;

  List<ProductDetails> get products => productDetails;
  List<String> get notFoundIds => notFoundIDs;
}

typedef ProductQueryResponse = ProductDetailsResponse;
