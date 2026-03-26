import Flutter
import UIKit

public class NativeInAppPurchasePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let storeKitManager = StoreKitManager()
  private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(
      name: "native_in_app_purchase",
      binaryMessenger: registrar.messenger()
    )
    let eventChannel = FlutterEventChannel(
      name: "native_in_app_purchase/events",
      binaryMessenger: registrar.messenger()
    )

    let instance = NativeInAppPurchasePlugin()
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
  }

  override init() {
    super.init()
    storeKitManager.delegate = self
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      storeKitManager.initialize()
      result(nil)
    case "isAvailable":
      result(storeKitManager.isAvailable())
    case "getProducts":
      guard
        let arguments = call.arguments as? [String: Any],
        let productIds = arguments["productIds"] as? [String]
      else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Expected a productIds array.",
            details: nil
          )
        )
        return
      }

      storeKitManager.getProducts(productIds: productIds, result: result)
    case "buyProduct":
      guard
        let arguments = call.arguments as? [String: Any],
        let productId = arguments["productId"] as? String
      else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Expected a productId value.",
            details: nil
          )
        )
        return
      }

      let applicationUserName = (call.arguments as? [String: Any])?["applicationUserName"] as? String
      let isConsumable = (call.arguments as? [String: Any])?["isConsumable"] as? Bool ?? false
      let autoConsume = (call.arguments as? [String: Any])?["autoConsume"] as? Bool ?? true

      storeKitManager.buyProduct(
        productId: productId,
        applicationUserName: applicationUserName,
        isConsumable: isConsumable,
        autoConsume: autoConsume,
        result: result
      )
    case "completePurchase":
      guard let arguments = call.arguments as? [String: Any] else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Expected completePurchase arguments.",
            details: nil
          )
        )
        return
      }

      storeKitManager.completePurchase(
        transactionId: arguments["transactionId"] as? String,
        result: result
      )
    case "restorePurchases":
      let arguments = call.arguments as? [String: Any]
      let consumableProductIds = arguments?["consumableProductIds"] as? [String] ?? []
      storeKitManager.restorePurchases(
        consumableProductIds: consumableProductIds,
        result: result
      )
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

extension NativeInAppPurchasePlugin: StoreKitManagerDelegate {
  func storeKitManager(_ manager: StoreKitManager, didUpdatePurchase purchase: [String: Any?]) {
    eventSink?(purchase)
  }

  func storeKitManager(_ manager: StoreKitManager, didFailWith error: FlutterError) {
    eventSink?(error)
  }
}
