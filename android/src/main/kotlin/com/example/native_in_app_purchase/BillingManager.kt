package com.example.native_in_app_purchase

import android.app.Activity
import android.content.Context
import android.util.Log
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ConsumeParams
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import java.util.concurrent.ConcurrentHashMap

class BillingManager(
    context: Context,
    private val listener: Listener,
) : PurchasesUpdatedListener {

    interface Listener {
        fun onPurchaseUpdate(purchase: Map<String, Any?>)
        fun onPurchaseError(error: PluginError)
    }

    data class PluginError(
        val code: String,
        val message: String,
        val details: Any? = null,
    )

    private val applicationContext = context.applicationContext
    private val cachedProducts = ConcurrentHashMap<String, ProductDetails>()
    private val pendingPurchases = ConcurrentHashMap<String, Purchase>()
    private val consumableProducts = ConcurrentHashMap<String, Boolean>()
    private val autoConsumeProducts = ConcurrentHashMap<String, Boolean>()
    private val billingClient: BillingClient =
        BillingClient.newBuilder(applicationContext)
            .setListener(this)
            .enablePendingPurchases(
                PendingPurchasesParams.newBuilder()
                    .enableOneTimeProducts()
                    .enablePrepaidPlans()
                    .build(),
            )
            .build()

    private var activity: Activity? = null
    private var isInitialized = false
    private var restoreInProgress = false

    fun setActivity(activity: Activity?) {
        this.activity = activity
    }

    fun initialize(callback: (PluginError?) -> Unit) {
        if (billingClient.isReady) {
            isInitialized = true
            callback(null)
            return
        }

        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(billingResult: BillingResult) {
                if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    isInitialized = true
                    logDebug("Billing client connected: ${billingResult.debugMessage}")
                    callback(null)
                } else {
                    callback(
                        billingError(
                            billingResult,
                            fallbackCode = "billing_unavailable",
                            fallbackMessage = "Unable to connect to Google Play Billing.",
                        ),
                    )
                }
            }

            override fun onBillingServiceDisconnected() {
                isInitialized = false
                logDebug("Billing service disconnected.")
            }
        })
    }

    fun isAvailable(callback: (Boolean, PluginError?) -> Unit) {
        initialize { error ->
            callback(error == null && billingClient.isReady, error)
        }
    }

    fun getProducts(
        productIds: List<String>,
        callback: (Map<String, Any?>?, PluginError?) -> Unit,
    ) {
        if (productIds.isEmpty()) {
            callback(
                mapOf(
                    "products" to emptyList<Map<String, Any?>>(),
                    "notFoundIds" to emptyList<String>(),
                ),
                null,
            )
            return
        }

        ensureReady { error ->
            if (error != null) {
                callback(null, error)
                return@ensureReady
            }

            val aggregatedProducts = mutableListOf<Map<String, Any?>>()
            queryProductsForType(
                productIds = productIds,
                productType = BillingClient.ProductType.INAPP,
                collected = aggregatedProducts,
            ) { inAppError ->
                if (inAppError != null) {
                    callback(null, inAppError)
                    return@queryProductsForType
                }

                queryProductsForType(
                    productIds = productIds,
                    productType = BillingClient.ProductType.SUBS,
                    collected = aggregatedProducts,
                ) { subsError ->
                    val resolvedIds = aggregatedProducts
                        .mapNotNull { it["id"] as? String }
                        .toSet()
                    val notFoundIds = productIds
                        .filterNot { resolvedIds.contains(it) }

                    if (subsError != null &&
                        aggregatedProducts.isEmpty()
                    ) {
                        callback(null, subsError)
                    } else {
                        callback(
                            mapOf(
                                "products" to aggregatedProducts.distinctBy { it["id"] as String },
                                "notFoundIds" to notFoundIds,
                            ),
                            null,
                        )
                    }
                }
            }
        }
    }

    fun buyProduct(
        activity: Activity,
        productId: String,
        isConsumable: Boolean,
        autoConsume: Boolean,
        applicationUserName: String?,
        callback: (Boolean, PluginError?) -> Unit,
    ) {
        ensureReady { error ->
            if (error != null) {
                callback(false, error)
                return@ensureReady
            }

            val productDetails = cachedProducts[productId]
            if (productDetails == null) {
                callback(
                    false,
                    PluginError(
                        code = "product_not_loaded",
                        message = "Product details not loaded for $productId. Call getProducts() first.",
                    ),
                )
                return@ensureReady
            }

            consumableProducts[productId] = isConsumable
            autoConsumeProducts[productId] = autoConsume

            val paramsBuilder = BillingFlowParams.ProductDetailsParams.newBuilder()
                .setProductDetails(productDetails)

            productDetails.oneTimePurchaseOfferDetails?.offerToken
                ?.takeIf { it.isNotBlank() }
                ?.let(paramsBuilder::setOfferToken)

            productDetails.subscriptionOfferDetails
                ?.firstOrNull()
                ?.offerToken
                ?.takeIf { it.isNotBlank() }
                ?.let(paramsBuilder::setOfferToken)

            val flowParamsBuilder = BillingFlowParams.newBuilder()
                .setProductDetailsParamsList(listOf(paramsBuilder.build()))
            applicationUserName
                ?.takeIf { it.isNotBlank() }
                ?.let(flowParamsBuilder::setObfuscatedAccountId)

            val flowParams = flowParamsBuilder.build()

            val billingResult = billingClient.launchBillingFlow(activity, flowParams)
            if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                callback(true, null)
            } else if (billingResult.responseCode == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) {
                callback(
                    false,
                    billingError(
                        billingResult,
                        fallbackCode = "item_already_owned",
                        fallbackMessage = "Item is already owned. Call restorePurchases() to sync existing purchases.",
                    ),
                )
            } else {
                callback(
                    false,
                    billingError(
                        billingResult,
                        fallbackCode = "purchase_launch_failed",
                        fallbackMessage = "Unable to launch the billing flow.",
                    ),
                )
            }
        }
    }

    fun restorePurchases(callback: (PluginError?) -> Unit) {
        ensureReady { error ->
            if (error != null) {
                callback(error)
                return@ensureReady
            }

            restoreInProgress = true
            queryOwnedPurchases(BillingClient.ProductType.INAPP) { inAppError ->
                if (inAppError != null) {
                    restoreInProgress = false
                    callback(inAppError)
                    return@queryOwnedPurchases
                }

                queryOwnedPurchases(BillingClient.ProductType.SUBS) { subsError ->
                    restoreInProgress = false
                    callback(subsError)
                }
            }
        }
    }

    fun completePurchase(
        purchaseToken: String?,
        productId: String?,
        isConsumable: Boolean,
        callback: (PluginError?) -> Unit,
    ) {
        ensureReady { error ->
            if (error != null) {
                callback(error)
                return@ensureReady
            }

            val token = purchaseToken?.takeIf { it.isNotBlank() }
            if (token.isNullOrBlank()) {
                callback(
                    PluginError(
                        code = "invalid_purchase_token",
                        message = "A valid purchase token is required to complete the purchase.",
                    ),
                )
                return@ensureReady
            }

            if (isConsumable || consumableProducts[productId] == true) {
                consumePurchase(token, callback)
            } else {
                acknowledgePurchase(token, callback)
            }
        }
    }

    fun dispose() {
        if (billingClient.isReady) {
            billingClient.endConnection()
        }
        activity = null
        isInitialized = false
    }

    override fun onPurchasesUpdated(
        billingResult: BillingResult,
        purchases: MutableList<Purchase>?,
    ) {
        when (billingResult.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                purchases.orEmpty().forEach { purchase ->
                    val shouldAutoConsume = purchase.products.any { autoConsumeProducts[it] == true }
                    if (shouldAutoConsume) {
                        consumePurchase(purchase.purchaseToken) { error ->
                            if (error != null) {
                                listener.onPurchaseError(error)
                            }
                            emitPurchaseUpdate(purchase, wasRestored = false, autoCompleted = error == null)
                        }
                    } else {
                        emitPurchaseUpdate(purchase, wasRestored = false, autoCompleted = false)
                    }
                }
            }

            BillingClient.BillingResponseCode.USER_CANCELED -> {
                listener.onPurchaseUpdate(
                    purchaseMap(
                        status = "canceled",
                        productId = "",
                        transactionId = "",
                        errorCode = "user_canceled",
                        errorMessage = "User canceled the purchase flow.",
                        debugMessage = billingResult.debugMessage,
                    ),
                )
            }

            BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> {
                listener.onPurchaseError(
                    PluginError(
                        code = "item_already_owned",
                        message = "Item is already owned. Call restorePurchases() to sync purchases.",
                        details = mapOf("responseCode" to billingResult.responseCode),
                    ),
                )
            }

            else -> {
                listener.onPurchaseError(
                    billingError(
                        billingResult,
                        fallbackCode = "purchase_failed",
                        fallbackMessage = "Purchase failed.",
                    ),
                )
            }
        }
    }

    private fun queryProductsForType(
        productIds: List<String>,
        productType: String,
        collected: MutableList<Map<String, Any?>>,
        callback: (PluginError?) -> Unit,
    ) {
        val products = productIds.map {
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(it)
                .setProductType(productType)
                .build()
        }

        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(products)
            .build()

        billingClient.queryProductDetailsAsync(params) { billingResult, queryResult ->
            if (billingResult.responseCode != BillingClient.BillingResponseCode.OK) {
                callback(
                    billingError(
                        billingResult,
                        fallbackCode = "query_products_failed",
                        fallbackMessage = "Unable to query product details.",
                    ),
                )
                return@queryProductDetailsAsync
            }

            queryResult.productDetailsList.forEach { details ->
                cachedProducts[details.productId] = details
                collected.add(productToMap(details))
            }

            queryResult.unfetchedProductList.forEach { unfetched ->
                logDebug(
                    "Product ${unfetched.productId} was not fetched. " +
                        "statusCode=${unfetched.statusCode}",
                )
            }

            callback(null)
        }
    }

    private fun queryOwnedPurchases(
        productType: String,
        callback: (PluginError?) -> Unit,
    ) {
        val params = QueryPurchasesParams.newBuilder()
            .setProductType(productType)
            .build()

        billingClient.queryPurchasesAsync(params) { billingResult, purchases ->
            if (billingResult.responseCode != BillingClient.BillingResponseCode.OK) {
                callback(
                    billingError(
                        billingResult,
                        fallbackCode = "restore_failed",
                        fallbackMessage = "Unable to restore purchases.",
                    ),
                )
                return@queryPurchasesAsync
            }

            purchases.forEach { purchase ->
                emitPurchaseUpdate(
                    purchase,
                    wasRestored = restoreInProgress &&
                        purchase.purchaseState == Purchase.PurchaseState.PURCHASED,
                    autoCompleted = false,
                )
            }

            callback(null)
        }
    }

    private fun emitPurchaseUpdate(
        purchase: Purchase,
        wasRestored: Boolean,
        autoCompleted: Boolean,
    ) {
        val status = when {
            purchase.purchaseState == Purchase.PurchaseState.PENDING -> "pending"
            wasRestored -> "restored"
            purchase.purchaseState == Purchase.PurchaseState.PURCHASED -> "purchased"
            else -> "error"
        }

        val transactionId = purchase.orderId ?: purchase.purchaseToken
        pendingPurchases[purchase.purchaseToken] = purchase
        purchase.products.forEach { productId ->
            listener.onPurchaseUpdate(
                purchaseMap(
                    status = status,
                    productId = productId,
                    transactionId = transactionId.orEmpty(),
                    transactionDate = purchase.purchaseTime.toString(),
                    purchaseToken = purchase.purchaseToken,
                    verificationData = verificationDataMap(
                        localVerificationData = purchase.originalJson,
                        serverVerificationData = purchase.purchaseToken,
                        source = "google_play",
                    ),
                    pendingCompletePurchase = purchase.purchaseState == Purchase.PurchaseState.PURCHASED &&
                        !autoCompleted &&
                        !purchase.isAcknowledged,
                    debugMessage = null,
                    isConsumable = consumableProducts[productId] == true,
                ),
            )
        }
    }

    private fun acknowledgePurchase(
        purchaseToken: String,
        callback: (PluginError?) -> Unit,
    ) {
        val purchase = pendingPurchases[purchaseToken]
        if (purchase?.isAcknowledged == true) {
            callback(null)
            return
        }

        val acknowledgeParams = AcknowledgePurchaseParams.newBuilder()
            .setPurchaseToken(purchaseToken)
            .build()

        billingClient.acknowledgePurchase(acknowledgeParams) { billingResult ->
            if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                callback(null)
            } else {
                callback(
                    billingError(
                        billingResult,
                        fallbackCode = "acknowledge_failed",
                        fallbackMessage = "Purchase acknowledgement failed.",
                    ),
                )
            }
        }
    }

    private fun consumePurchase(
        purchaseToken: String,
        callback: (PluginError?) -> Unit,
    ) {
        val params = ConsumeParams.newBuilder()
            .setPurchaseToken(purchaseToken)
            .build()

        billingClient.consumeAsync(params) { billingResult, _ ->
            if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                pendingPurchases.remove(purchaseToken)
                callback(null)
            } else {
                callback(
                    billingError(
                        billingResult,
                        fallbackCode = "consume_failed",
                        fallbackMessage = "Failed to consume purchase.",
                    ),
                )
            }
        }
    }

    private fun verificationDataMap(
        localVerificationData: String,
        serverVerificationData: String,
        source: String,
    ): Map<String, Any?> {
        return mapOf(
            "localVerificationData" to localVerificationData,
            "serverVerificationData" to serverVerificationData,
            "source" to source,
        )
    }

    private fun productToMap(details: ProductDetails): Map<String, Any?> {
        val oneTimeOffer = details.oneTimePurchaseOfferDetails
        val subscriptionPricing = details.subscriptionOfferDetails
            ?.firstOrNull()
            ?.pricingPhases
            ?.pricingPhaseList
            ?.firstOrNull()

        val currencyCode = oneTimeOffer?.priceCurrencyCode ?: subscriptionPricing?.priceCurrencyCode ?: ""
        val formattedPrice = oneTimeOffer?.formattedPrice ?: subscriptionPricing?.formattedPrice ?: ""

        return mapOf(
            "id" to details.productId,
            "title" to details.title,
            "description" to details.description,
            "price" to formattedPrice,
            "rawPrice" to ((oneTimeOffer?.priceAmountMicros ?: subscriptionPricing?.priceAmountMicros ?: 0L) / 1_000_000.0),
            "currencyCode" to currencyCode,
            "currencySymbol" to currencyCode,
            "type" to details.productType,
        )
    }

    private fun purchaseMap(
        status: String,
        productId: String,
        transactionId: String,
        transactionDate: String? = null,
        purchaseToken: String? = null,
        verificationData: Map<String, Any?>? = null,
        errorCode: String? = null,
        errorMessage: String? = null,
        pendingCompletePurchase: Boolean = false,
        debugMessage: String? = null,
        isConsumable: Boolean = false,
    ): Map<String, Any?> {
        return mapOf(
            "status" to status,
            "productId" to productId,
            "transactionId" to transactionId,
            "transactionDate" to transactionDate,
            "purchaseToken" to purchaseToken,
            "verificationData" to verificationData,
            "errorCode" to errorCode,
            "errorMessage" to errorMessage,
            "pendingCompletePurchase" to pendingCompletePurchase,
            "debugMessage" to debugMessage,
            "isConsumable" to isConsumable,
        )
    }

    private fun billingError(
        billingResult: BillingResult,
        fallbackCode: String,
        fallbackMessage: String,
    ): PluginError {
        return PluginError(
            code = fallbackCode,
            message = fallbackMessage,
            details = mapOf(
                "responseCode" to billingResult.responseCode,
                "debugMessage" to billingResult.debugMessage,
            ),
        )
    }

    private fun logDebug(message: String) {
        Log.d(TAG, message)
    }

    companion object {
        private const val TAG = "NativeInAppPurchase"
    }
    private fun ensureReady(callback: (PluginError?) -> Unit) {
        if (billingClient.isReady && isInitialized) {
            callback(null)
            return
        }

        initialize(callback)
    }
}
