import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_in_app_purchase/native_in_app_purchase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel methodChannel = MethodChannel('native_in_app_purchase');
  final List<MethodCall> calls = <MethodCall>[];
  final NativeInAppPurchase plugin = NativeInAppPurchase(
    methodChannel: methodChannel,
    eventChannel: const EventChannel('native_in_app_purchase/events'),
  );

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
          calls.add(call);

          switch (call.method) {
            case 'initialize':
              return null;
            case 'isAvailable':
              return true;
            case 'getProducts':
              return <String, Object?>{
                'products': <Map<String, Object?>>[
                  <String, Object?>{
                    'id': 'coins_pack',
                    'title': 'Coins Pack',
                    'description': '100 coins',
                    'price': '\$1.99',
                    'rawPrice': 1.99,
                    'currencyCode': 'USD',
                    'currencySymbol': '\$',
                    'type': 'inapp',
                  },
                ],
                'notFoundIds': <String>['missing_sku'],
              };
            case 'buyProduct':
              return true;
            case 'completePurchase':
            case 'restorePurchases':
              return null;
            default:
              throw PlatformException(code: 'unimplemented');
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  test('initializes billing', () async {
    await plugin.initialize();

    expect(calls.single.method, 'initialize');
  });

  test('reports store availability', () async {
    expect(await plugin.isAvailable(), isTrue);
  });

  test('queries products and parses result', () async {
    final response = await plugin.getProductsResponse(<String>['coins_pack']);

    expect(response.products, hasLength(1));
    expect(response.products.single.id, 'coins_pack');
    expect(response.products.single.price, '\$1.99');
    expect(response.notFoundIds, <String>['missing_sku']);
  });

  test('parses purchase model values', () {
    final purchase = Purchase.fromMap(<String, Object?>{
      'status': 'purchased',
      'productId': 'coins_pack',
      'transactionId': 'txn_123',
      'transactionDate': '1710921312000',
      'purchaseToken': 'token_123',
      'verificationData': <String, Object?>{
        'localVerificationData': 'signed_payload',
        'serverVerificationData': 'server_payload',
        'source': 'google_play',
      },
      'pendingCompletePurchase': false,
      'isConsumable': true,
    });

    expect(purchase.status, PurchaseStatus.purchased);
    expect(purchase.productId, 'coins_pack');
    expect(purchase.transactionId, 'txn_123');
    expect(purchase.verificationData?.serverVerificationData, 'server_payload');
    expect(purchase.isConsumable, isTrue);
  });
}
