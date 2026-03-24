# native_in_app_purchase

A Flutter plugin for native in-app purchases on Android and iOS using:

- `MethodChannel("native_in_app_purchase")`
- `EventChannel("native_in_app_purchase/events")`
- Google Play Billing on Android
- StoreKit on iOS

The package exposes a small Dart API with native-backed product queries,
purchase flows, restore flows, purchase stream updates, consumable support,
and manual purchase completion.

## Features

- Query products with `products` and `notFoundIds`
- Buy consumable and non-consumable products
- Restore previous purchases
- Listen to real-time purchase updates
- Complete pending purchases after backend verification
- Return purchase token / receipt verification payloads for server validation

## Installation

Add the dependency to your app:

```yaml
dependencies:
  native_in_app_purchase: ^0.0.1
```

Then run:

```bash
flutter pub get
```

## Usage

```dart
import 'dart:async';

import 'package:native_in_app_purchase/native_in_app_purchase.dart';

final NativeInAppPurchase iap = NativeInAppPurchase();
StreamSubscription<Purchase>? purchaseSubscription;

Future<void> initializeStore() async {
  await iap.initialize();

  final bool isAvailable = await iap.isAvailable();
  if (!isAvailable) {
    return;
  }

  purchaseSubscription = iap.purchaseUpdates.listen((Purchase purchase) async {
    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      // Verify the purchase on your backend before unlocking entitlement.
      if (purchase.pendingCompletePurchase) {
        await iap.completePurchase(purchase);
      }
    }
  });

  final ProductQueryResponse response = await iap.getProductsResponse(
    <String>['coins_pack', 'premium_upgrade'],
  );

  for (final NativeInAppProduct product in response.products) {
    print('${product.id}: ${product.price}');
  }
}

Future<void> buyPremium(NativeInAppProduct product) async {
  await iap.buy(
    PurchaseParam(
      product: product,
      isConsumable: false,
    ),
  );
}

Future<void> restorePurchases() async {
  await iap.restorePurchases();
}
```

## API Overview

### Main methods

- `initialize()`
- `isAvailable()`
- `getProducts(List<String> productIds)`
- `getProductsResponse(List<String> productIds)`
- `buy(PurchaseParam param)`
- `buyProduct(String productId, {bool isConsumable = false, bool autoConsume = true})`
- `restorePurchases()`
- `completePurchase(Purchase purchase)`
- `purchaseUpdates`

### Models

- `NativeInAppProduct`
- `ProductQueryResponse`
- `Purchase`
- `PurchaseParam`
- `PurchaseVerificationData`
- `PurchaseStatus`

## Purchase Verification

`Purchase.verificationData` contains:

- `localVerificationData`
- `serverVerificationData`
- `source`

Use these fields for backend verification before granting durable entitlement.

Platform details:

- Android: `serverVerificationData` is the Google Play purchase token
- iOS: `serverVerificationData` is the base64 App Store receipt

## Platform Setup

### Android

1. Create products in Google Play Console.
2. Use the same product IDs in your Flutter app.
3. Add tester accounts in Play Console.
4. Install the app from an internal or closed testing track for real billing flows.

Notes:

- Billing library version: `8.3.0`
- Consumables can be auto-consumed or completed manually

### iOS

1. Create in-app purchases in App Store Connect.
2. Use the same product IDs in your Flutter app.
3. Test with a Sandbox account.
4. Optionally attach a `.storekit` configuration in Xcode for local StoreKit testing.

## Example App

The package includes a working example in [example/lib/main.dart](example/lib/main.dart) that demonstrates:

- store initialization
- product loading
- purchase flow
- restore flow
- purchase stream listening
- manual purchase completion

Run it with:

```bash
cd example
flutter run
```

## Development

Run package checks:

```bash
flutter test
flutter analyze
cd example && flutter test && flutter analyze
```

## License

This package is available under the MIT License. See [LICENSE](LICENSE).
