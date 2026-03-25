import 'dart:async';

import 'package:flutter/services.dart';

import 'src/errors/iap_error.dart';
import 'src/models/product_details.dart';
import 'src/models/product_details_response.dart';
import 'src/models/purchase_param.dart';
import 'src/models/purchase_details.dart';

export 'src/enums/purchase_status.dart';
export 'src/errors/iap_error.dart';
export 'src/models/product_details.dart';
export 'src/models/product_details_response.dart';
export 'src/models/purchase_param.dart';
export 'src/models/purchase_details.dart';
export 'src/models/purchase_verification_data.dart';

/// Flutter entrypoint for the native in-app purchase plugin.
class NativeInAppPurchase {
  NativeInAppPurchase({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel =
           methodChannel ?? const MethodChannel(_methodChannelName);

  static const String _methodChannelName = 'native_in_app_purchase';
  static const String _eventChannelName = 'native_in_app_purchase/events';
  static const EventChannel _sharedEventChannel = EventChannel(
    _eventChannelName,
  );

  final MethodChannel _methodChannel;
  static StreamController<PurchaseDetails>? _purchaseUpdatesController;
  static StreamSubscription<dynamic>? _nativePurchaseSubscription;
  static Stream<PurchaseDetails>? _sharedPurchaseUpdates;
  static Stream<List<PurchaseDetails>>? _sharedPurchaseStream;

  /// Initializes the native billing clients.
  Future<void> initialize() {
    return _methodChannel.invokeMethod<void>('initialize');
  }

  /// Returns `true` if the underlying store is available.
  Future<bool> isAvailable() async {
    return await _methodChannel.invokeMethod<bool>('isAvailable') ?? false;
  }

  /// Returns products and IDs the store could not resolve.
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    try {
      final response = await _methodChannel.invokeMapMethod<String, dynamic>(
        'getProducts',
        <String, Object?>{'productIds': identifiers.toList(growable: false)},
      );

      return ProductDetailsResponse.fromMap(
        response ??
            <String, dynamic>{
              'products': <Object?>[],
              'notFoundIds': <Object?>[],
            },
      );
    } on PlatformException catch (error) {
      return ProductDetailsResponse(
        productDetails: const <ProductDetails>[],
        notFoundIDs: identifiers.toList(growable: false),
        error: IAPError(
          source: 'native_in_app_purchase',
          code: error.code,
          message: error.message ?? 'Unable to query product details.',
          details: error.details,
        ),
      );
    }
  }

  Future<ProductDetailsResponse> getProductsResponse(List<String> productIds) {
    return queryProductDetails(productIds.toSet());
  }

  /// Returns localized product data for the supplied product identifiers.
  Future<List<ProductDetails>> getProducts(List<String> productIds) async {
    final response = await getProductsResponse(productIds);
    return response.productDetails;
  }

  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    return await _methodChannel
            .invokeMethod<bool>('buyProduct', <String, Object?>{
              'productId': purchaseParam.productDetails.id,
              'isConsumable': false,
              'autoConsume': false,
              'applicationUserName': purchaseParam.applicationUserName,
            }) ??
        false;
  }

  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    return await _methodChannel
            .invokeMethod<bool>('buyProduct', <String, Object?>{
              'productId': purchaseParam.productDetails.id,
              'isConsumable': true,
              'autoConsume': autoConsume,
              'applicationUserName': purchaseParam.applicationUserName,
            }) ??
        false;
  }

  /// Backward-compatible helper.
  Future<bool> buy(PurchaseParam param) async {
    if (param.isConsumable) {
      return buyConsumable(
        purchaseParam: param,
        autoConsume: param.autoConsume,
      );
    }
    return buyNonConsumable(purchaseParam: param);
  }

  /// Backward-compatible helper.
  Future<bool> buyProduct(
    String productId, {
    bool isConsumable = false,
    bool autoConsume = true,
    String? applicationUserName,
  }) {
    return buy(
      PurchaseParam(
        productDetails: ProductDetails(
          id: productId,
          title: '',
          description: '',
          price: '',
          rawPrice: 0,
          currencyCode: '',
          currencySymbol: '',
        ),
        applicationUserName: applicationUserName,
        isConsumable: isConsumable,
        autoConsume: autoConsume,
      ),
    );
  }

  /// Restores previously purchased items.
  Future<void> restorePurchases({String? applicationUserName}) {
    return _methodChannel.invokeMethod<void>(
      'restorePurchases',
      <String, Object?>{'applicationUserName': applicationUserName},
    );
  }

  /// Completes a pending purchase once content has been delivered and verified.
  Future<void> completePurchase(PurchaseDetails purchase) {
    if (!purchase.pendingCompletePurchase) {
      return Future<void>.value();
    }
    return _methodChannel
        .invokeMethod<void>('completePurchase', <String, Object?>{
          'productId': purchase.productID,
          'transactionId': purchase.purchaseID,
          'purchaseToken': purchase.purchaseToken,
          'isConsumable': purchase.isConsumable,
        });
  }

  Stream<List<PurchaseDetails>> get purchaseStream {
    return _sharedPurchaseStream ??= purchaseUpdates
        .map((PurchaseDetails purchase) => <PurchaseDetails>[purchase])
        .asBroadcastStream();
  }

  /// Broadcast stream of native purchase updates.
  Stream<PurchaseDetails> get purchaseUpdates {
    return _sharedPurchaseUpdates ??= _buildSharedPurchaseUpdates();
  }

  static Stream<PurchaseDetails> _buildSharedPurchaseUpdates() {
    _purchaseUpdatesController ??= StreamController<PurchaseDetails>.broadcast(
      onListen: _ensureNativePurchaseSubscription,
      onCancel: _cancelNativePurchaseSubscriptionIfIdle,
    );

    return _purchaseUpdatesController!.stream;
  }

  static void _ensureNativePurchaseSubscription() {
    if (_nativePurchaseSubscription != null) {
      return;
    }

    _nativePurchaseSubscription = _sharedEventChannel
        .receiveBroadcastStream()
        .listen(
          (dynamic event) {
            if (event is Map) {
              _purchaseUpdatesController?.add(
                PurchaseDetails.fromMap(Map<String, dynamic>.from(event)),
              );
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            final wrapped = error is PlatformException
                ? NativeInAppPurchaseException.fromPlatformException(error)
                : error;
            _purchaseUpdatesController?.addError(wrapped, stackTrace);
          },
          cancelOnError: false,
        );
  }

  static Future<void> _cancelNativePurchaseSubscriptionIfIdle() async {
    if (_purchaseUpdatesController?.hasListener ?? false) {
      return;
    }

    await _nativePurchaseSubscription?.cancel();
    _nativePurchaseSubscription = null;
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

class InAppPurchase {
  InAppPurchase._();

  static InAppPurchase? _instance;

  static InAppPurchase get instance => _instance ??= InAppPurchase._();

  final NativeInAppPurchase _delegate = NativeInAppPurchase();

  Stream<List<PurchaseDetails>> get purchaseStream => _delegate.purchaseStream;

  Future<void> initialize() => _delegate.initialize();

  Future<bool> isAvailable() => _delegate.isAvailable();

  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) {
    return _delegate.queryProductDetails(identifiers);
  }

  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) {
    return _delegate.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) {
    return _delegate.buyConsumable(
      purchaseParam: purchaseParam,
      autoConsume: autoConsume,
    );
  }

  Future<void> completePurchase(PurchaseDetails purchase) {
    return _delegate.completePurchase(purchase);
  }

  Future<void> restorePurchases({String? applicationUserName}) {
    return _delegate.restorePurchases(applicationUserName: applicationUserName);
  }
}
