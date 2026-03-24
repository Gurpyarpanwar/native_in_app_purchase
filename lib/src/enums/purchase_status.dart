enum PurchaseStatus {
  pending,
  purchased,
  error,
  restored,
  canceled;

  static PurchaseStatus fromValue(String value) {
    switch (value) {
      case 'pending':
        return PurchaseStatus.pending;
      case 'purchased':
        return PurchaseStatus.purchased;
      case 'restored':
        return PurchaseStatus.restored;
      case 'canceled':
        return PurchaseStatus.canceled;
      case 'failed':
      case 'error':
      default:
        return PurchaseStatus.error;
    }
  }
}
