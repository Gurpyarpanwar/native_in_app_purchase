# Changelog

## 0.2.1

- Fixed Android sequential purchase routing so purchase updates only process the active product flow.
- Fixed Android purchase cleanup, duplicate token handling, reconnect retries, and restore behavior for consumables.
- Added Android subscription offer selection and exposed `subscriptionOffers` in product metadata.
- Fixed Android `completePurchase()` to be idempotent for already-finished purchases.
- Fixed iOS transaction deduplication, stable transaction keys, overlapping `getProducts()` handling, and subscription auto-finish behavior.
- Fixed iOS restore bookkeeping and made `completePurchase()` idempotent for already-finished transactions.
- Kept Flutter method/channel names backward compatible while improving native restore event ordering.

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
