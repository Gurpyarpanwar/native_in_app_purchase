import 'dart:async';

import 'package:flutter/material.dart';
import 'package:native_in_app_purchase/native_in_app_purchase.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const List<String> _productIds = <String>[
    'coins_pack',
    'premium_upgrade',
  ];

  final NativeInAppPurchase _nativeInAppPurchasePlugin = NativeInAppPurchase();

  StreamSubscription<Purchase>? _purchaseSubscription;
  List<NativeInAppProduct> _products = const <NativeInAppProduct>[];
  Purchase? _latestPurchase;
  List<String> _notFoundIds = const <String>[];
  String? _statusMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _purchaseSubscription = _nativeInAppPurchasePlugin.purchaseUpdates.listen(
      _handlePurchaseUpdate,
      onError: _handlePurchaseError,
    );
    _initializeStore();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeStore() async {
    try {
      await _nativeInAppPurchasePlugin.initialize();
      final isAvailable = await _nativeInAppPurchasePlugin.isAvailable();
      final response = await _nativeInAppPurchasePlugin.getProductsResponse(
        _productIds,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _products = response.products;
        _notFoundIds = response.notFoundIds;
        _isLoading = false;
        _statusMessage = !isAvailable
            ? 'Store is not available on this device.'
            : response.products.isEmpty
            ? 'No products found. Configure the same IDs in Play Console or App Store Connect.'
            : 'Store initialized. Tap a product to start purchase flow.';
      });
    } on NativeInAppPurchaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _statusMessage = 'Initialization failed: ${error.message}';
      });
    }
  }

  void _handlePurchaseUpdate(Purchase purchase) {
    if (!mounted) {
      return;
    }
    setState(() {
      _latestPurchase = purchase;
      _statusMessage =
          'Purchase update: ${purchase.status.name} for ${purchase.productId.isEmpty ? 'unknown' : purchase.productId}';
    });

    if (purchase.pendingCompletePurchase) {
      _completePurchase(purchase);
    }
  }

  void _handlePurchaseError(Object error) {
    if (!mounted) {
      return;
    }

    setState(() {
      _statusMessage = 'Purchase stream error: $error';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Native In-App Purchase'),
          actions: <Widget>[
            TextButton(
              onPressed: _restorePurchases,
              child: const Text('Restore'),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refreshProducts,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_statusMessage ?? 'Ready'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Products',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_products.isEmpty)
                      const Text(
                        'No configured products were returned by the store.',
                      )
                    else
                      ..._products.map(
                        (NativeInAppProduct product) => Card(
                          child: ListTile(
                            title: Text(product.title),
                            subtitle: Text(
                              '${product.description}\n${product.id} • ${product.type}',
                            ),
                            trailing: FilledButton(
                              onPressed: () => _buyProduct(product.id),
                              child: Text(product.price),
                            ),
                          ),
                        ),
                      ),
                    if (_notFoundIds.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      Text('Not found: ${_notFoundIds.join(', ')}'),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Latest Purchase Update',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _latestPurchase == null
                              ? 'No purchase events yet.'
                              : '''
status: ${_latestPurchase!.status.name}
productId: ${_latestPurchase!.productId}
transactionId: ${_latestPurchase!.transactionId}
purchaseToken: ${_latestPurchase!.purchaseToken ?? '-'}
serverVerificationData: ${_latestPurchase!.verificationData?.serverVerificationData ?? '-'}
source: ${_latestPurchase!.verificationData?.source ?? '-'}
pendingCompletePurchase: ${_latestPurchase!.pendingCompletePurchase}
error: ${_latestPurchase!.errorMessage ?? '-'}
''',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _refreshProducts() async {
    final response = await _nativeInAppPurchasePlugin.getProductsResponse(
      _productIds,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _products = response.products;
      _notFoundIds = response.notFoundIds;
    });
  }

  Future<void> _buyProduct(String productId) async {
    try {
      await _nativeInAppPurchasePlugin.buyProduct(
        productId,
        isConsumable: productId == 'coins_pack',
      );
    } on NativeInAppPurchaseException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Purchase error: ${error.message}';
      });
    }
  }

  Future<void> _restorePurchases() async {
    try {
      await _nativeInAppPurchasePlugin.restorePurchases();
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Restore requested. Waiting for store updates...';
      });
    } on NativeInAppPurchaseException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Restore failed: ${error.message}';
      });
    }
  }

  Future<void> _completePurchase(Purchase purchase) async {
    try {
      await _nativeInAppPurchasePlugin.completePurchase(purchase);
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage =
            'Purchase completed after delivery for ${purchase.productId}.';
      });
    } on NativeInAppPurchaseException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Complete purchase failed: ${error.message}';
      });
    }
  }
}
