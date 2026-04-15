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
  private var processedTransactionIds = Set<String>()
  private var subscriptionProductIds = Set<String>()

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
    productRequestResult?(
      FlutterError(
        code: "request_superseded",
        message: "A newer getProducts request was started.",
        details: nil
      )
    )
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

    processedTransactionIds.removeAll()
    productTypesByIdentifier[productId] = isConsumable
    autoConsumeByIdentifier[productId] = autoConsume

    let payment = SKMutablePayment(product: product)
    payment.applicationUsername = applicationUserName
    SKPaymentQueue.default().add(payment)
    result(true)
  }

  func restorePurchases(
    consumableProductIds: [String] = [],
    result: @escaping FlutterResult
  ) {
    restoreResult = result
    restoreInProgress = true
    processedTransactionIds.removeAll()
    consumableProductIds.forEach { productTypesByIdentifier[$0] = true }
    SKPaymentQueue.default().restoreCompletedTransactions()
  }

  func completePurchase(transactionId: String?, result: @escaping FlutterResult) {
    guard let transactionId, let transaction = pendingTransactions[transactionId] else {
      result(nil)
      return
    }

    SKPaymentQueue.default().finishTransaction(transaction)
    pendingTransactions.removeValue(forKey: transactionId)
    cleanupProduct(transaction.payment.productIdentifier)
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
    guard let currentRequest = productRequest, request === currentRequest else { return }
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency

    let products = response.products.map { product -> [String: Any?] in
      productsByIdentifier[product.productIdentifier] = product
      if product.subscriptionPeriod != nil {
        subscriptionProductIds.insert(product.productIdentifier)
      }
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
    guard let currentRequest = productRequest, request === currentRequest else { return }
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
        let key = transactionKey(transaction)
        guard processedTransactionIds.insert(key).inserted else { continue }
        handleCompletedTransaction(transaction, status: "purchased")
      case .failed:

        delegate?.storeKitManager(self, didUpdatePurchase: failedPurchaseMap(from: transaction))
        queue.finishTransaction(transaction)
        cleanupProduct(transaction.payment.productIdentifier)
      case .restored:
        let key = transactionKey(transaction)
        guard processedTransactionIds.insert(key).inserted else { continue }
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
    processedTransactionIds.removeAll()
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
    processedTransactionIds.removeAll()
  }

  private func purchaseMap(from transaction: SKPaymentTransaction, status: String) -> [String: Any?] {
    let productId = transaction.payment.productIdentifier
    let transactionId = transactionKey(transaction)
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
    let isCancelled =
      error?.domain == SKErrorDomain &&
      error?.code == SKError.paymentCancelled.rawValue

    return [
      "status": isCancelled ? "cancelled" : "error",
      "productId": transaction.payment.productIdentifier,
      "transactionId": transactionKey(transaction),
      "transactionDate": nil,
      "purchaseToken": nil,
      "verificationData": nil,
      "errorCode": isCancelled ? nil : error.map { "\($0.code)" },
      "errorMessage": isCancelled ? "Purchase cancelled." : error?.localizedDescription ?? "Purchase failed.",
      "pendingCompletePurchase": false,
      "debugMessage": nil,
      "isConsumable": productTypesByIdentifier[transaction.payment.productIdentifier] ?? false
    ]
  }

  private func handleCompletedTransaction(_ transaction: SKPaymentTransaction, status: String) {
    let productId = transaction.payment.productIdentifier
    let transactionId = transactionKey(transaction)
    let shouldAutoConsume =
      (productTypesByIdentifier[productId] ?? false) &&
      (autoConsumeByIdentifier[productId] ?? true) &&
      !subscriptionProductIds.contains(productId)

    if shouldAutoConsume {
      delegate?.storeKitManager(
        self,
        didUpdatePurchase: purchaseMap(from: transaction, status: status).merging([
          "pendingCompletePurchase": false
        ]) { _, new in new }
      )
      SKPaymentQueue.default().finishTransaction(transaction)
      cleanupProduct(productId)
      return
    }

    pendingTransactions[transactionId] = transaction
    delegate?.storeKitManager(
      self,
      didUpdatePurchase: purchaseMap(from: transaction, status: status)
    )
  }

  private func cleanupProduct(_ productId: String) {
    productTypesByIdentifier.removeValue(forKey: productId)
    autoConsumeByIdentifier.removeValue(forKey: productId)
  }

  private func transactionKey(_ transaction: SKPaymentTransaction) -> String {
    if let transactionIdentifier = transaction.transactionIdentifier, !transactionIdentifier.isEmpty {
      return transactionIdentifier
    }

    let timestamp = Int64(transaction.transactionDate?.timeIntervalSince1970 ?? 0)
    return "\(transaction.payment.productIdentifier)_\(timestamp)"
  }
}
