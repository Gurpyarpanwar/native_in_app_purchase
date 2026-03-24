import 'product_details.dart';

class PurchaseParam {
  const PurchaseParam({
    required this.productDetails,
    this.applicationUserName,
    this.isConsumable = false,
    this.autoConsume = true,
  });

  final ProductDetails productDetails;
  final String? applicationUserName;
  final bool isConsumable;
  final bool autoConsume;

  ProductDetails get product => productDetails;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'productId': productDetails.id,
      'applicationUserName': applicationUserName,
      'isConsumable': isConsumable,
      'autoConsume': autoConsume,
    };
  }
}
