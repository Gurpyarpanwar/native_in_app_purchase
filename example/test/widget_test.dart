import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:native_in_app_purchase_example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel methodChannel = MethodChannel('native_in_app_purchase');
  const EventChannel eventChannel = EventChannel(
    'native_in_app_purchase/events',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
          switch (call.method) {
            case 'initialize':
              return null;
            case 'isAvailable':
              return true;
            case 'getProducts':
              return <String, Object?>{
                'products': <Map<String, Object?>>[
                  <String, Object?>{
                    'id': 'coins_pack',
                    'title': 'Coins Pack',
                    'description': '100 coins',
                    'price': '\$1.99',
                    'rawPrice': 1.99,
                    'currencyCode': 'USD',
                    'currencySymbol': '\$',
                    'type': 'inapp',
                  },
                ],
                'notFoundIds': <String>[],
              };
            case 'buyProduct':
              return true;
            case 'completePurchase':
            case 'restorePurchases':
              return null;
          }

          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(eventChannel.name, (ByteData? message) async {
          final MethodCall call = const StandardMethodCodec().decodeMethodCall(
            message,
          );

          if (call.method == 'listen' || call.method == 'cancel') {
            return const StandardMethodCodec().encodeSuccessEnvelope(null);
          }

          return const StandardMethodCodec().encodeErrorEnvelope(
            code: 'unimplemented',
            message: 'Unsupported event channel call.',
          );
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(eventChannel.name, null);
  });

  testWidgets('renders products from plugin', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Native In-App Purchase'), findsOneWidget);
    expect(find.text('Coins Pack'), findsOneWidget);
    expect(find.text('\$1.99'), findsOneWidget);
  });
}
