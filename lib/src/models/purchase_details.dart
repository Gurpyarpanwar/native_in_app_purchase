import '../enums/purchase_status.dart';
import '../errors/iap_error.dart';
import 'purchase_verification_data.dart';

class PurchaseDetails {
  PurchaseDetails({
    this.purchaseID,
    required this.productID,
    required this.verificationData,
    required this.transactionDate,
    required this.status,
    this.purchaseToken,
    this.debugMessage,
    this.isConsumable = false,
    this.error,
    this.pendingCompletePurchase = false,
  });

  factory PurchaseDetails.fromMap(Map<String, dynamic> map) {
    final status = PurchaseStatus.fromValue(
      map['status'] as String? ?? 'error',
    );
    final errorMessage = map['errorMessage'] as String?;
    final errorCode = map['errorCode'] as String?;

    return PurchaseDetails(
      purchaseID: map['transactionId'] as String?,
      productID: map['productId'] as String? ?? '',
      verificationData: map['verificationData'] is Map
          ? PurchaseVerificationData.fromMap(
              Map<String, dynamic>.from(map['verificationData'] as Map),
            )
          : const PurchaseVerificationData(
              localVerificationData: '',
              serverVerificationData: '',
              source: '',
            ),
      transactionDate: map['transactionDate'] as String?,
      status: status,
      purchaseToken: map['purchaseToken'] as String?,
      debugMessage: map['debugMessage'] as String?,
      isConsumable: map['isConsumable'] as bool? ?? false,
      error: errorMessage == null && errorCode == null
          ? null
          : IAPError(
              source: 'native_in_app_purchase',
              code: errorCode ?? 'unknown',
              message: errorMessage ?? 'Unknown purchase error.',
              details: map['debugMessage'],
            ),
      pendingCompletePurchase: map['pendingCompletePurchase'] as bool? ?? false,
    );
  }

  final String? purchaseID;
  final String productID;
  final PurchaseVerificationData verificationData;
  final String? transactionDate;
  PurchaseStatus status;
  IAPError? error;
  bool pendingCompletePurchase;

  final String? purchaseToken;
  final String? debugMessage;
  final bool isConsumable;

  String get productId => productID;
  String get transactionId => purchaseID ?? '';
  String? get errorCode => error?.code;
  String? get errorMessage => error?.message;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'status': status.name,
      'productId': productID,
      'transactionId': purchaseID,
      'transactionDate': transactionDate,
      'purchaseToken': purchaseToken,
      'verificationData': verificationData.toMap(),
      'errorCode': error?.code,
      'errorMessage': error?.message,
      'pendingCompletePurchase': pendingCompletePurchase,
      'debugMessage': debugMessage,
      'isConsumable': isConsumable,
    };
  }
}

typedef Purchase = PurchaseDetails;
