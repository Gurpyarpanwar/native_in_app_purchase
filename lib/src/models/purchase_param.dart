import 'native_product.dart';

class PurchaseParam {
  const PurchaseParam({
    required this.product,
    this.applicationUserName,
    this.isConsumable = false,
    this.autoConsume = true,
  });

  final NativeInAppProduct product;
  final String? applicationUserName;
  final bool isConsumable;
  final bool autoConsume;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'productId': product.id,
      'applicationUserName': applicationUserName,
      'isConsumable': isConsumable,
      'autoConsume': autoConsume,
    };
  }
}
