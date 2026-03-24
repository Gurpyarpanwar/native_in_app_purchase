enum PurchaseStatus {
  pending,
  purchased,
  failed,
  restored;

  static PurchaseStatus fromValue(String value) {
    return PurchaseStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => PurchaseStatus.failed,
    );
  }
}
