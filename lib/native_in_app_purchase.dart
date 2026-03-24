import 'package:flutter/services.dart';

import 'src/models/native_product.dart';
import 'src/models/product_query_response.dart';
import 'src/models/purchase_param.dart';
import 'src/models/purchase.dart';

export 'src/enums/purchase_status.dart';
export 'src/models/native_product.dart';
export 'src/models/product_query_response.dart';
export 'src/models/purchase_param.dart';
export 'src/models/purchase.dart';
export 'src/models/purchase_verification_data.dart';

/// Flutter entrypoint for the native in-app purchase plugin.
class NativeInAppPurchase {
  NativeInAppPurchase({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel =
           methodChannel ?? const MethodChannel(_methodChannelName),
       _eventChannel = eventChannel ?? const EventChannel(_eventChannelName);

  static const String _methodChannelName = 'native_in_app_purchase';
  static const String _eventChannelName = 'native_in_app_purchase/events';

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Stream<Purchase>? _purchaseUpdates;

  /// Initializes the native billing clients.
  Future<void> initialize() {
    return _methodChannel.invokeMethod<void>('initialize');
  }

  /// Returns `true` if the underlying store is available.
  Future<bool> isAvailable() async {
    return await _methodChannel.invokeMethod<bool>('isAvailable') ?? false;
  }

  /// Returns products and IDs the store could not resolve.
  Future<ProductQueryResponse> getProductsResponse(
    List<String> productIds,
  ) async {
    final response = await _methodChannel.invokeMapMethod<String, dynamic>(
      'getProducts',
      <String, Object?>{'productIds': productIds},
    );

    return ProductQueryResponse.fromMap(
      response ??
          <String, dynamic>{
            'products': <Object?>[],
            'notFoundIds': <Object?>[],
          },
    );
  }

  /// Returns localized product data for the supplied product identifiers.
  Future<List<NativeInAppProduct>> getProducts(List<String> productIds) async {
    final response = await getProductsResponse(productIds);
    return response.products;
  }

  /// Launches the platform purchase flow for a single product.
  Future<bool> buyProduct(
    String productId, {
    bool isConsumable = false,
    bool autoConsume = true,
    String? applicationUserName,
  }) async {
    return await _methodChannel
            .invokeMethod<bool>('buyProduct', <String, Object?>{
              'productId': productId,
              'isConsumable': isConsumable,
              'autoConsume': autoConsume,
              'applicationUserName': applicationUserName,
            }) ??
        false;
  }

  Future<bool> buy(PurchaseParam param) async {
    return await _methodChannel.invokeMethod<bool>(
          'buyProduct',
          param.toMap(),
        ) ??
        false;
  }

  /// Restores previously purchased items.
  Future<void> restorePurchases({String? applicationUserName}) {
    return _methodChannel.invokeMethod<void>(
      'restorePurchases',
      <String, Object?>{'applicationUserName': applicationUserName},
    );
  }

  /// Completes a pending purchase once content has been delivered and verified.
  Future<void> completePurchase(Purchase purchase) {
    return _methodChannel
        .invokeMethod<void>('completePurchase', <String, Object?>{
          'productId': purchase.productId,
          'transactionId': purchase.transactionId,
          'purchaseToken': purchase.purchaseToken,
          'isConsumable': purchase.isConsumable,
        });
  }

  /// Broadcast stream of native purchase updates.
  Stream<Purchase> get purchaseUpdates {
    return _purchaseUpdates ??= _eventChannel
        .receiveBroadcastStream()
        .map(
          (dynamic event) =>
              Purchase.fromMap(Map<String, dynamic>.from(event as Map)),
        )
        .handleError(
          (Object error) => throw error is PlatformException
              ? NativeInAppPurchaseException.fromPlatformException(error)
              : error,
        )
        .asBroadcastStream();
  }
}

class NativeInAppPurchaseException implements Exception {
  const NativeInAppPurchaseException({
    required this.code,
    required this.message,
    this.details,
  });

  factory NativeInAppPurchaseException.fromPlatformException(
    PlatformException exception,
  ) {
    return NativeInAppPurchaseException(
      code: exception.code,
      message: exception.message ?? 'Unknown platform error.',
      details: exception.details,
    );
  }

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => 'NativeInAppPurchaseException($code, $message)';
}
