package com.example.native_in_app_purchase

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NativeInAppPurchasePlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware,
    BillingManager.Listener {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var applicationContext: Context
    private val mainHandler = Handler(Looper.getMainLooper())

    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    private var billingManager: BillingManager? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        billingManager = BillingManager(applicationContext, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        billingManager?.dispose()
        billingManager = null
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val manager = billingManager
        if (manager == null) {
            result.error("not_ready", "Billing manager is not available.", null)
            return
        }

        when (call.method) {
            "initialize" -> manager.initialize { error ->
                if (error == null) {
                    result.success(null)
                } else {
                    result.error(error.code, error.message, error.details)
                }
            }

            "isAvailable" -> manager.isAvailable { available, error ->
                if (error == null) {
                    result.success(available)
                } else {
                    result.error(error.code, error.message, error.details)
                }
            }

            "getProducts" -> {
                val productIds = call.argument<List<String>>("productIds").orEmpty()
                manager.getProducts(productIds) { payload, error ->
                    if (error == null) {
                        result.success(payload)
                    } else {
                        result.error(error.code, error.message, error.details)
                    }
                }
            }

            "buyProduct" -> {
                val productId = call.argument<String>("productId")
                val isConsumable = call.argument<Boolean>("isConsumable") ?: false
                val autoConsume = call.argument<Boolean>("autoConsume") ?: true
                val applicationUserName = call.argument<String>("applicationUserName")
                if (productId.isNullOrBlank()) {
                    result.error("invalid_product_id", "A non-empty productId is required.", null)
                    return
                }

                val currentActivity = activity
                if (currentActivity == null) {
                    result.error("no_activity", "An attached Activity is required to start a purchase flow.", null)
                    return
                }

                manager.buyProduct(
                    activity = currentActivity,
                    productId = productId,
                    isConsumable = isConsumable,
                    autoConsume = autoConsume,
                    applicationUserName = applicationUserName,
                ) { launched, error ->
                    if (error == null) {
                        result.success(launched)
                    } else {
                        result.error(error.code, error.message, error.details)
                    }
                }
            }

            "completePurchase" -> {
                val purchaseToken = call.argument<String>("purchaseToken")
                val productId = call.argument<String>("productId")
                val isConsumable = call.argument<Boolean>("isConsumable") ?: false
                manager.completePurchase(
                    purchaseToken = purchaseToken,
                    productId = productId,
                    isConsumable = isConsumable,
                ) { error ->
                    if (error == null) {
                        result.success(null)
                    } else {
                        result.error(error.code, error.message, error.details)
                    }
                }
            }

            "restorePurchases" -> manager.restorePurchases { error ->
                if (error == null) {
                    result.success(null)
                } else {
                    result.error(error.code, error.message, error.details)
                }
            }

            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        billingManager?.setActivity(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
        billingManager?.setActivity(null)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        billingManager?.setActivity(binding.activity)
    }

    override fun onDetachedFromActivity() {
        activity = null
        billingManager?.setActivity(null)
    }

    override fun onPurchaseUpdate(purchase: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(purchase)
        }
    }

    override fun onPurchaseError(error: BillingManager.PluginError) {
        mainHandler.post {
            eventSink?.error(error.code, error.message, error.details)
        }
    }

    companion object {
        private const val METHOD_CHANNEL = "native_in_app_purchase"
        private const val EVENT_CHANNEL = "native_in_app_purchase/events"
    }
}
