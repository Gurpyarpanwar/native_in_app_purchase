import '../enums/purchase_status.dart';
import 'purchase_verification_data.dart';

class Purchase {
  const Purchase({
    required this.status,
    required this.productId,
    required this.transactionId,
    this.transactionDate,
    this.purchaseToken,
    this.verificationData,
    this.errorCode,
    this.errorMessage,
    this.pendingCompletePurchase = false,
    this.debugMessage,
    this.isConsumable = false,
  });

  factory Purchase.fromMap(Map<String, dynamic> map) {
    return Purchase(
      status: PurchaseStatus.fromValue(map['status'] as String? ?? 'failed'),
      productId: map['productId'] as String? ?? '',
      transactionId: map['transactionId'] as String? ?? '',
      transactionDate: map['transactionDate'] as String?,
      purchaseToken: map['purchaseToken'] as String?,
      verificationData: map['verificationData'] is Map
          ? PurchaseVerificationData.fromMap(
              Map<String, dynamic>.from(map['verificationData'] as Map),
            )
          : null,
      errorCode: map['errorCode'] as String?,
      errorMessage: map['errorMessage'] as String?,
      pendingCompletePurchase: map['pendingCompletePurchase'] as bool? ?? false,
      debugMessage: map['debugMessage'] as String?,
      isConsumable: map['isConsumable'] as bool? ?? false,
    );
  }

  final PurchaseStatus status;
  final String productId;
  final String transactionId;
  final String? transactionDate;
  final String? purchaseToken;
  final PurchaseVerificationData? verificationData;
  final String? errorCode;
  final String? errorMessage;
  final bool pendingCompletePurchase;
  final String? debugMessage;
  final bool isConsumable;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'status': status.name,
      'productId': productId,
      'transactionId': transactionId,
      'transactionDate': transactionDate,
      'purchaseToken': purchaseToken,
      'verificationData': verificationData?.toMap(),
      'errorCode': errorCode,
      'errorMessage': errorMessage,
      'pendingCompletePurchase': pendingCompletePurchase,
      'debugMessage': debugMessage,
      'isConsumable': isConsumable,
    };
  }
}
