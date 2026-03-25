import Flutter
import Foundation
import StoreKit

protocol StoreKitManagerDelegate: AnyObject {
  func storeKitManager(_ manager: StoreKitManager, didUpdatePurchase purchase: [String: Any?])
  func storeKitManager(_ manager: StoreKitManager, didFailWith error: FlutterError)
}

final class StoreKitManager: NSObject {
  weak var delegate: StoreKitManagerDelegate?

  private var productsByIdentifier: [String: SKProduct] = [:]
  private var productTypesByIdentifier: [String: Bool] = [:]
  private var autoConsumeByIdentifier: [String: Bool] = [:]
  private var pendingTransactions: [String: SKPaymentTransaction] = [:]
  private var productRequest: SKProductsRequest?
  private var productRequestResult: FlutterResult?
  private var restoreResult: FlutterResult?
  private var isObservingQueue = false
  private var restoreInProgress = false

  func initialize() {
    guard !isObservingQueue else { return }
    SKPaymentQueue.default().add(self)
    isObservingQueue = true
  }

  func isAvailable() -> Bool {
    SKPaymentQueue.canMakePayments()
  }

  func getProducts(productIds: [String], result: @escaping FlutterResult) {
    guard !productIds.isEmpty else {
      result([
        "products": [[String: Any]](),
        "notFoundIds": [String]()
      ])
      return
    }

    productRequest?.cancel()
    productRequestResult = result

    let request = SKProductsRequest(productIdentifiers: Set(productIds))
    request.delegate = self
    productRequest = request
    request.start()
  }

  func buyProduct(
    productId: String,
    applicationUserName: String?,
    isConsumable: Bool,
    autoConsume: Bool,
    result: @escaping FlutterResult
  ) {
    guard SKPaymentQueue.canMakePayments() else {
      result(
        FlutterError(
          code: "payments_disabled",
          message: "In-app purchases are disabled on this device.",
          details: nil
        )
      )
      return
    }

    guard let product = productsByIdentifier[productId] else {
      result(
        FlutterError(
          code: "product_not_loaded",
          message: "Product not loaded. Call getProducts() first.",
          details: nil
        )
      )
      return
    }

    productTypesByIdentifier[productId] = isConsumable
    autoConsumeByIdentifier[productId] = autoConsume

    let payment = SKMutablePayment(product: product)
    payment.applicationUsername = applicationUserName
    SKPaymentQueue.default().add(payment)
    result(true)
  }

  func restorePurchases(result: @escaping FlutterResult) {
    restoreResult = result
    restoreInProgress = true
    SKPaymentQueue.default().restoreCompletedTransactions()
  }

  func completePurchase(transactionId: String?, result: @escaping FlutterResult) {
    guard let transactionId, let transaction = pendingTransactions[transactionId] else {
      result(
        FlutterError(
          code: "transaction_not_found",
          message: "No pending transaction found for completion.",
          details: nil
        )
      )
      return
    }

    SKPaymentQueue.default().finishTransaction(transaction)
    pendingTransactions.removeValue(forKey: transactionId)
    result(nil)
  }

  deinit {
    if isObservingQueue {
      SKPaymentQueue.default().remove(self)
    }
  }
}

extension StoreKitManager: SKProductsRequestDelegate {
  func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency

    let products = response.products.map { product -> [String: Any?] in
      productsByIdentifier[product.productIdentifier] = product
      formatter.locale = product.priceLocale

      return [
        "id": product.productIdentifier,
        "title": product.localizedTitle,
        "description": product.localizedDescription,
        "price": formatter.string(from: product.price) ?? "",
        "rawPrice": product.price.doubleValue,
        "currencyCode": product.priceLocale.currencyCode ?? "",
        "currencySymbol": formatter.currencySymbol ?? product.priceLocale.currencyCode ?? "",
        "type": "inapp"
      ]
    }

    if !response.invalidProductIdentifiers.isEmpty {
      NSLog("NativeInAppPurchase invalid products: \(response.invalidProductIdentifiers)")
    }

    productRequestResult?([
      "products": products,
      "notFoundIds": response.invalidProductIdentifiers
    ])
    productRequestResult = nil
    productRequest = nil
  }

  func request(_ request: SKRequest, didFailWithError error: Error) {
    productRequestResult?(
      FlutterError(
        code: "product_request_failed",
        message: error.localizedDescription,
        details: nil
      )
    )
    productRequestResult = nil
    productRequest = nil
  }
}

extension StoreKitManager: SKPaymentTransactionObserver {
  func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    for transaction in transactions {
      switch transaction.transactionState {
      case .purchased:
        handleCompletedTransaction(transaction, status: "purchased")
      case .failed:

        delegate?.storeKitManager(self, didUpdatePurchase: failedPurchaseMap(from: transaction))
        queue.finishTransaction(transaction)
      case .restored:
        handleCompletedTransaction(
          transaction,
          status: restoreInProgress ? "restored" : "purchased"
        )
      case .deferred:
        delegate?.storeKitManager(self, didUpdatePurchase: purchaseMap(from: transaction, status: "pending"))
      case .purchasing:
        delegate?.storeKitManager(self, didUpdatePurchase: purchaseMap(from: transaction, status: "pending"))
      @unknown default:
        delegate?.storeKitManager(
          self,
          didFailWith: FlutterError(
            code: "unknown_state",
            message: "Encountered an unknown transaction state.",
            details: nil
          )
        )
      }
    }
  }

  func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
    restoreInProgress = false
    restoreResult?(nil)
    restoreResult = nil
  }

  func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
    restoreInProgress = false
    restoreResult?(
      FlutterError(
        code: "restore_failed",
        message: error.localizedDescription,
        details: nil
      )
    )
    restoreResult = nil
  }

  private func purchaseMap(from transaction: SKPaymentTransaction, status: String) -> [String: Any?] {
    let productId = transaction.payment.productIdentifier
    let transactionId = transaction.transactionIdentifier ?? UUID().uuidString
    let receiptData = Bundle.main.appStoreReceiptURL.flatMap { try? Data(contentsOf: $0) }
    let encodedReceipt = receiptData?.base64EncodedString()
    let transactionDate = transaction.transactionDate.map {
      String(Int64($0.timeIntervalSince1970 * 1000))
    }
    let isConsumable = productTypesByIdentifier[productId] ?? false

    return [
      "status": status,
      "productId": productId,
      "transactionId": transactionId,
      "transactionDate": transactionDate,
      "purchaseToken": transactionId,
      "verificationData": [
        "localVerificationData": encodedReceipt ?? "",
        "serverVerificationData": encodedReceipt ?? "",
        "source": "app_store"
      ],
      "errorCode": nil,
      "errorMessage": nil,
      "pendingCompletePurchase": status == "purchased" || status == "restored",
      "debugMessage": nil,
      "isConsumable": isConsumable
    ]
  }

  private func failedPurchaseMap(from transaction: SKPaymentTransaction) -> [String: Any?] {
    let error = transaction.error as NSError?
    let isCanceled =
      error?.domain == SKErrorDomain &&
      error?.code == SKError.paymentCancelled.rawValue

    return [
      "status": isCanceled ? "canceled" : "error",
      "productId": transaction.payment.productIdentifier,
      "transactionId": transaction.transactionIdentifier ?? "",
      "transactionDate": nil,
      "purchaseToken": nil,
      "verificationData": nil,
      "errorCode": isCanceled ? nil : error.map { "\($0.code)" },
      "errorMessage": isCanceled ? "Purchase canceled." : error?.localizedDescription ?? "Purchase failed.",
      "pendingCompletePurchase": false,
      "debugMessage": nil,
      "isConsumable": productTypesByIdentifier[transaction.payment.productIdentifier] ?? false
    ]
  }

  private func handleCompletedTransaction(_ transaction: SKPaymentTransaction, status: String) {
    let productId = transaction.payment.productIdentifier
    let transactionId = transaction.transactionIdentifier ?? UUID().uuidString
    let shouldAutoConsume =
      (productTypesByIdentifier[productId] ?? false) &&
      (autoConsumeByIdentifier[productId] ?? true)

    if shouldAutoConsume {
      delegate?.storeKitManager(
        self,
        didUpdatePurchase: purchaseMap(from: transaction, status: status).merging([
          "pendingCompletePurchase": false
        ]) { _, new in new }
      )
      SKPaymentQueue.default().finishTransaction(transaction)
      return
    }

    pendingTransactions[transactionId] = transaction
    delegate?.storeKitManager(
      self,
      didUpdatePurchase: purchaseMap(from: transaction, status: status)
    )
  }
}
