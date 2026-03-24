import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_in_app_purchase/native_in_app_purchase.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('initialize call completes', (WidgetTester tester) async {
    final NativeInAppPurchase plugin = NativeInAppPurchase();

    await plugin.initialize();

    expect(plugin.purchaseUpdates, isA<Stream<Purchase>>());
  });
}
