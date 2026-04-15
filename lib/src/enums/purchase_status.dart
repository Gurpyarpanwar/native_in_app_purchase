enum PurchaseStatus {
  pending,
  purchased,
  error,
  restored,
  cancelled;

  static PurchaseStatus fromValue(String value) {
    switch (value) {
      case 'pending':
        return PurchaseStatus.pending;
      case 'purchased':
        return PurchaseStatus.purchased;
      case 'restored':
        return PurchaseStatus.restored;
      case 'cancelled':
        return PurchaseStatus.cancelled;
      case 'canceled':
        return PurchaseStatus.cancelled;
      case 'failed':
      case 'error':
      default:
        return PurchaseStatus.error;
    }
  }
}
