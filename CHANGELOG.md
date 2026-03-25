# Changelog

## 0.2.0

- Added an `in_app_purchase`-style API with `InAppPurchase.instance`
- Added `ProductDetails`, `ProductDetailsResponse`, `PurchaseDetails`, and `IAPError`
- Added `buyNonConsumable`, `buyConsumable`, `queryProductDetails`, and `purchaseStream`
- Improved stream handling to avoid stacking native listeners
- Improved restore and pending purchase handling
- Fixed canceled/error purchase state mapping on Android and iOS

## 0.1.0

- Added an `in_app_purchase`-style API with `InAppPurchase.instance`
- Added `ProductDetails`, `ProductDetailsResponse`, `PurchaseDetails`, and `IAPError`
- Added `buyNonConsumable`, `buyConsumable`, `queryProductDetails`, and `purchaseStream`
- Improved Android and iOS canceled/error purchase state handling
- Updated example app to use the new API
- Improved pub.dev package documentation

## 0.0.1

- Initial release of `native_in_app_purchase`
